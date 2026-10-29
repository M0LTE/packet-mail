//! The receiver against a mocked GitHub API.

use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

use axum::extract::{Request, State};
use axum::http::StatusCode;
use axum::routing::any;
use axum::{Json, Router};
use base64::Engine;
use feedback_receiver::{serve, Config};
use serde_json::{json, Value};
use tokio::net::TcpListener;

#[derive(Clone, Debug)]
struct Call {
    method: String,
    path: String,
    auth: String,
    body: Value,
}

#[derive(Clone, Default)]
struct Mock {
    calls: Arc<Mutex<Vec<Call>>>,
    fail: Arc<Mutex<bool>>,
}

async fn mock_handler(State(mock): State<Mock>, req: Request) -> (StatusCode, Json<Value>) {
    let method = req.method().to_string();
    let path = req.uri().path().to_string();
    let auth = req
        .headers()
        .get("authorization")
        .map(|v| v.to_str().unwrap().to_string())
        .unwrap_or_default();
    let bytes = axum::body::to_bytes(req.into_body(), usize::MAX)
        .await
        .unwrap();
    let body: Value = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    mock.calls.lock().unwrap().push(Call {
        method: method.clone(),
        path: path.clone(),
        auth,
        body,
    });
    if *mock.fail.lock().unwrap() {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"message": "boom"})),
        );
    }
    if method == "PUT" {
        let file = path.split("/contents/").nth(1).unwrap().to_string();
        (
            StatusCode::CREATED,
            Json(json!({"content": {"html_url": format!("https://github.test/blob/main/{file}")}})),
        )
    } else {
        (StatusCode::CREATED, Json(json!({"number": 7})))
    }
}

async fn start(extra: &[(&str, &str)]) -> (String, Mock) {
    let mock = Mock::default();
    let gh = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let gh_addr = gh.local_addr().unwrap();
    let app = Router::new()
        .fallback(any(mock_handler))
        .with_state(mock.clone());
    tokio::spawn(async move { axum::serve(gh, app).await.unwrap() });

    let api = format!("http://{gh_addr}");
    let mut pairs: Vec<(String, String)> = vec![
        ("FEEDBACK_GITHUB_TOKEN".into(), "test-token".into()),
        ("FEEDBACK_REPO".into(), "m0lte/packet-mail-feedback".into()),
        ("FEEDBACK_GITHUB_API".into(), api),
        ("FEEDBACK_LISTEN".into(), "127.0.0.1:0".into()),
    ];
    pairs.extend(extra.iter().map(|(k, v)| (k.to_string(), v.to_string())));
    let config = Config::from_lookup(|k| {
        pairs
            .iter()
            .rev()
            .find(|(pk, _)| pk == k)
            .map(|(_, v)| v.clone())
    })
    .unwrap();
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr: SocketAddr = listener.local_addr().unwrap();
    tokio::spawn(serve(listener, config, std::future::pending()));
    (format!("http://{addr}"), mock)
}

fn report() -> Value {
    json!({
        "description": "Message 4490 looks odd.",
        "includeMessageText": false,
        "appVersion": "0.1.0",
        "build": "12",
        "platform": "ios",
        "osVersion": "18.1",
        "bbsBanners": ["[BPQ-6.0.26.1-IHJM$]"],
        "traffic": "# GB7RDG\n{\"t\":0.1,\"dir\":\"rx\",\"data\":\"hello\\r\"}\n",
    })
}

async fn post(base: &str, body: &Value) -> reqwest::Response {
    reqwest::Client::new()
        .post(format!("{base}/v1/report"))
        .json(body)
        .send()
        .await
        .unwrap()
}

#[tokio::test]
async fn files_an_issue_with_the_traffic_committed() {
    let (base, mock) = start(&[]).await;
    let resp = post(&base, &report()).await;
    assert_eq!(resp.status(), 200);
    let reply: Value = resp.json().await.unwrap();
    let id = reply["id"].as_str().unwrap().to_string();
    assert_eq!(reply["issue"], 7);

    let calls = mock.calls.lock().unwrap().clone();
    assert_eq!(calls.len(), 2);
    let put = &calls[0];
    assert_eq!(put.method, "PUT");
    assert_eq!(
        put.path,
        format!("/repos/m0lte/packet-mail-feedback/contents/reports/{id}.jsonl")
    );
    assert_eq!(put.auth, "Bearer test-token");
    let content = base64::engine::general_purpose::STANDARD
        .decode(put.body["content"].as_str().unwrap())
        .unwrap();
    assert_eq!(
        String::from_utf8(content).unwrap(),
        report()["traffic"].as_str().unwrap()
    );

    let issue = &calls[1];
    assert_eq!(issue.method, "POST");
    assert_eq!(issue.path, "/repos/m0lte/packet-mail-feedback/issues");
    assert_eq!(issue.body["labels"], json!(["in-app"]));
    assert_eq!(
        issue.body["title"],
        "In-app report: Message 4490 looks odd."
    );
    let body = issue.body["body"].as_str().unwrap();
    assert!(body.contains("Message 4490 looks odd."));
    assert!(body.contains("Platform: ios 18.1"));
    assert!(body.contains(&format!(
        "(https://github.test/blob/main/reports/{id}.jsonl)"
    )));
}

#[tokio::test]
async fn health() {
    let (base, _) = start(&[]).await;
    let resp = reqwest::get(format!("{base}/healthz")).await.unwrap();
    assert_eq!(resp.status(), 200);
    assert_eq!(resp.text().await.unwrap(), "ok");
}

#[tokio::test]
async fn refuses_bad_reports_without_calling_github() {
    let (base, mock) = start(&[
        ("FEEDBACK_MAX_BODY_BYTES", "2000"),
        ("FEEDBACK_PER_IP_PER_HOUR", "100"),
    ])
    .await;

    let mut big = report();
    big["traffic"] = json!(format!("{{\"data\":\"{}\"}}", "x".repeat(3000)));
    assert_eq!(post(&base, &big).await.status(), 413);

    let resp = reqwest::Client::new()
        .post(format!("{base}/v1/report"))
        .body("not json")
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), 400);

    let mut bad = report();
    bad["platform"] = json!("");
    let resp = post(&base, &bad).await;
    assert_eq!(resp.status(), 400);
    assert_eq!(
        resp.json::<Value>().await.unwrap()["error"],
        "platform is empty"
    );

    let mut missing = report();
    missing.as_object_mut().unwrap().remove("traffic");
    assert_eq!(post(&base, &missing).await.status(), 400);

    assert!(mock.calls.lock().unwrap().is_empty());
}

#[tokio::test]
async fn limits_each_address() {
    let (base, mock) = start(&[("FEEDBACK_PER_IP_PER_HOUR", "2")]).await;
    assert_eq!(post(&base, &report()).await.status(), 200);
    assert_eq!(post(&base, &report()).await.status(), 200);
    let resp = post(&base, &report()).await;
    assert_eq!(resp.status(), 429);
    assert!(resp.headers().get("retry-after").is_some());
    assert_eq!(mock.calls.lock().unwrap().len(), 4);
}

#[tokio::test]
async fn limits_overall() {
    let (base, _) = start(&[
        ("FEEDBACK_GLOBAL_PER_HOUR", "1"),
        ("FEEDBACK_PER_IP_PER_HOUR", "10"),
    ])
    .await;
    assert_eq!(post(&base, &report()).await.status(), 200);
    assert_eq!(post(&base, &report()).await.status(), 429);
}

#[tokio::test]
async fn behind_a_trusted_proxy_limits_by_forwarded_address() {
    let (base, _) = start(&[
        ("FEEDBACK_PER_IP_PER_HOUR", "1"),
        ("FEEDBACK_TRUST_PROXY", "true"),
    ])
    .await;
    let send = |ip: &'static str| {
        let base = base.clone();
        async move {
            reqwest::Client::new()
                .post(format!("{base}/v1/report"))
                .header("x-forwarded-for", ip)
                .json(&report())
                .send()
                .await
                .unwrap()
                .status()
        }
    };
    assert_eq!(send("203.0.113.1").await, 200);
    assert_eq!(send("203.0.113.2").await, 200);
    assert_eq!(send("203.0.113.1").await, 429);
}

#[tokio::test]
async fn github_failure_is_a_502() {
    let (base, mock) = start(&[]).await;
    *mock.fail.lock().unwrap() = true;
    let resp = post(&base, &report()).await;
    assert_eq!(resp.status(), 502);
    assert_eq!(mock.calls.lock().unwrap().len(), 1);
}

#[tokio::test]
async fn unknown_paths_are_404() {
    let (base, _) = start(&[]).await;
    assert_eq!(
        reqwest::get(format!("{base}/")).await.unwrap().status(),
        404
    );
}
