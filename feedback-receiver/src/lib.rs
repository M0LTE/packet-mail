//! Takes problem reports from Packet Mail and files each as an issue in a
//! private GitHub repo, with the traffic committed alongside. See README.md.

pub mod config;
pub mod github;
pub mod limits;
pub mod report;

use std::collections::hash_map::RandomState;
use std::future::Future;
use std::hash::BuildHasher;
use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use axum::body::Bytes;
use axum::extract::{ConnectInfo, DefaultBodyLimit, Request, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use hyper_util::rt::{TokioIo, TokioTimer};
use serde_json::json;
use tokio::net::TcpListener;
use tokio::sync::Semaphore;
use tower::Service;

pub use config::Config;
use github::GitHub;
use limits::RateLimiter;
use report::Report;

/// The label every in-app report gets.
pub const LABEL: &str = "in-app";

struct AppState {
    config: Config,
    limiter: RateLimiter,
    github: GitHub,
}

/// Set on a response so the request log line can name the report.
#[derive(Clone)]
struct ReportId(String);

pub fn router(config: Config) -> Router {
    let state = Arc::new(AppState {
        limiter: RateLimiter::new(
            Duration::from_secs(3600),
            config.per_ip_per_hour,
            config.global_per_hour,
        ),
        github: GitHub::new(&config.github_api, &config.repo, &config.token),
        config,
    });
    Router::new()
        .route("/v1/report", post(receive))
        .route("/healthz", get(|| async { "ok" }))
        .layer(DefaultBodyLimit::max(state.config.max_body_bytes))
        .layer(middleware::from_fn_with_state(
            state.clone(),
            log_and_time_out,
        ))
        .with_state(state)
}

fn error(status: StatusCode, message: &str) -> Response {
    (status, Json(json!({ "error": message }))).into_response()
}

fn too_many(wait: Duration) -> Response {
    let mut r = error(
        StatusCode::TOO_MANY_REQUESTS,
        "too many reports, try again later",
    );
    r.headers_mut()
        .insert("Retry-After", HeaderValue::from(wait.as_secs().max(1)));
    r
}

/// Where the request came from: the peer, or behind a trusted proxy the
/// last X-Forwarded-For entry (the one the proxy added).
fn client_ip(peer: SocketAddr, headers: &HeaderMap, trust_proxy: bool) -> IpAddr {
    if trust_proxy {
        let forwarded = headers
            .get_all("x-forwarded-for")
            .iter()
            .filter_map(|v| v.to_str().ok())
            .flat_map(|v| v.split(','))
            .last()
            .and_then(|v| v.trim().parse::<IpAddr>().ok());
        if let Some(ip) = forwarded {
            return ip;
        }
    }
    peer.ip()
}

async fn receive(
    State(state): State<Arc<AppState>>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let now = Instant::now();
    let ip = client_ip(peer, &headers, state.config.trust_proxy);
    if let Err(wait) = state.limiter.check_ip(ip, now) {
        return too_many(wait);
    }
    let report: Report = match serde_json::from_slice(&body) {
        Ok(r) => r,
        Err(_) => return error(StatusCode::BAD_REQUEST, "not a valid report"),
    };
    if let Err(why) = report.validate(state.config.max_description_chars) {
        return error(StatusCode::BAD_REQUEST, &why);
    }
    if let Err(wait) = state.limiter.check_global(now) {
        return too_many(wait);
    }

    let (date, time) = utc_now();
    let id = format!("{date}-{}", random_hex());
    let path = format!("reports/{id}.jsonl");
    let tag = |mut r: Response| {
        r.extensions_mut().insert(ReportId(id.clone()));
        r
    };
    let url = match state
        .github
        .create_file(&path, report.traffic.as_bytes(), &format!("Report {id}"))
        .await
    {
        Ok(url) => url,
        Err(e) => {
            println!("report {id}: {}", e.0);
            return tag(error(
                StatusCode::BAD_GATEWAY,
                "could not store the report, try again later",
            ));
        }
    };
    let body = report.issue_body(&format!("{date} {time} UTC"), &path, &url);
    match state
        .github
        .create_issue(&report.title(), &body, LABEL)
        .await
    {
        Ok(number) => {
            tag((StatusCode::OK, Json(json!({ "id": id, "issue": number }))).into_response())
        }
        Err(e) => {
            println!("report {id}: {}", e.0);
            tag(error(
                StatusCode::BAD_GATEWAY,
                "could not store the report, try again later",
            ))
        }
    }
}

/// One log line per request: method, path, status, time, size. Never the
/// body, never the address.
async fn log_and_time_out(
    State(state): State<Arc<AppState>>,
    req: Request,
    next: Next,
) -> Response {
    let started = Instant::now();
    let method = req.method().clone();
    let path = req.uri().path().chars().take(64).collect::<String>();
    let size = req
        .headers()
        .get("content-length")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("0")
        .to_string();
    let resp = match tokio::time::timeout(state.config.request_timeout, next.run(req)).await {
        Ok(r) => r,
        Err(_) => error(StatusCode::REQUEST_TIMEOUT, "took too long"),
    };
    let id = resp
        .extensions()
        .get::<ReportId>()
        .map(|r| format!(" id={}", r.0))
        .unwrap_or_default();
    println!(
        "{method} {path} {} {}ms {size}B{id}",
        resp.status().as_u16(),
        started.elapsed().as_millis()
    );
    resp
}

/// Serves until [shutdown] completes. Connections over the limit are
/// dropped straight away; request headers must arrive within 10 seconds.
pub async fn serve(listener: TcpListener, config: Config, shutdown: impl Future<Output = ()>) {
    let connections = Arc::new(Semaphore::new(config.max_connections));
    let app = router(config);
    tokio::pin!(shutdown);
    loop {
        let (stream, peer) = tokio::select! {
            _ = &mut shutdown => return,
            r = listener.accept() => match r {
                Ok(c) => c,
                Err(_) => {
                    tokio::time::sleep(Duration::from_millis(100)).await;
                    continue;
                }
            },
        };
        let Ok(permit) = connections.clone().try_acquire_owned() else {
            drop(stream);
            continue;
        };
        let app = app.clone();
        tokio::spawn(async move {
            let service = hyper::service::service_fn(
                move |mut req: hyper::Request<hyper::body::Incoming>| {
                    req.extensions_mut().insert(ConnectInfo(peer));
                    app.clone().call(req)
                },
            );
            let _ = hyper::server::conn::http1::Builder::new()
                .timer(TokioTimer::new())
                .header_read_timeout(Duration::from_secs(10))
                .serve_connection(TokioIo::new(stream), service)
                .await;
            drop(permit);
        });
    }
}

/// Today's date (YYYY-MM-DD) and time (HH:MM) in UTC.
pub fn utc_now() -> (String, String) {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    utc_parts(secs)
}

pub fn utc_parts(secs: u64) -> (String, String) {
    let days = (secs / 86400) as i64;
    let rem = secs % 86400;
    // Civil date from days since 1970-01-01 (Howard Hinnant's algorithm).
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
    (
        format!("{y:04}-{m:02}-{d:02}"),
        format!("{:02}:{:02}", rem / 3600, rem % 3600 / 60),
    )
}

/// Eight hex digits, different every call.
fn random_hex() -> String {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u64;
    format!("{:08x}", (RandomState::new().hash_one(nanos)) as u32)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dates() {
        assert_eq!(utc_parts(0), ("1970-01-01".into(), "00:00".into()));
        assert_eq!(
            utc_parts(951_782_400),
            ("2000-02-29".into(), "00:00".into())
        );
        assert_eq!(
            utc_parts(1_793_277_000),
            ("2026-10-29".into(), "12:30".into())
        );
    }

    #[test]
    fn ids_differ() {
        assert_ne!(random_hex(), random_hex());
        assert_eq!(random_hex().len(), 8);
    }

    #[test]
    fn forwarded_for_only_when_trusted() {
        let peer: SocketAddr = "10.0.0.1:5000".parse().unwrap();
        let mut h = HeaderMap::new();
        h.insert("x-forwarded-for", "1.2.3.4, 203.0.113.9".parse().unwrap());
        assert_eq!(
            client_ip(peer, &h, false),
            "10.0.0.1".parse::<IpAddr>().unwrap()
        );
        assert_eq!(
            client_ip(peer, &h, true),
            "203.0.113.9".parse::<IpAddr>().unwrap()
        );
        assert_eq!(
            client_ip(peer, &HeaderMap::new(), true),
            "10.0.0.1".parse::<IpAddr>().unwrap()
        );
    }
}
