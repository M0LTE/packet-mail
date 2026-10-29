use std::time::Duration;

use base64::Engine;
use serde_json::{json, Value};

/// The few GitHub REST calls the receiver makes.
pub struct GitHub {
    http: reqwest::Client,
    api: String,
    repo: String,
    token: String,
}

/// A failed call. Holds the status only, never the response text.
#[derive(Debug)]
pub struct GitHubError(pub String);

impl GitHub {
    pub fn new(api: &str, repo: &str, token: &str) -> GitHub {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(20))
            .user_agent("packet-mail-feedback-receiver")
            .build()
            .expect("HTTP client");
        GitHub {
            http,
            api: api.to_string(),
            repo: repo.to_string(),
            token: token.to_string(),
        }
    }

    async fn send(&self, req: reqwest::RequestBuilder, what: &str) -> Result<Value, GitHubError> {
        let resp = req
            .bearer_auth(&self.token)
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .send()
            .await
            .map_err(|e| {
                GitHubError(format!(
                    "{what}: {}",
                    if e.is_timeout() {
                        "timed out"
                    } else {
                        "no connection"
                    }
                ))
            })?;
        let status = resp.status();
        if !status.is_success() {
            return Err(GitHubError(format!("{what}: HTTP {}", status.as_u16())));
        }
        resp.json()
            .await
            .map_err(|_| GitHubError(format!("{what}: unreadable reply")))
    }

    /// Commits a new file and returns its web address.
    pub async fn create_file(
        &self,
        path: &str,
        content: &[u8],
        message: &str,
    ) -> Result<String, GitHubError> {
        let url = format!("{}/repos/{}/contents/{}", self.api, self.repo, path);
        let body = json!({
            "message": message,
            "content": base64::engine::general_purpose::STANDARD.encode(content),
        });
        let v = self
            .send(self.http.put(url).json(&body), "commit traffic")
            .await?;
        v["content"]["html_url"]
            .as_str()
            .map(str::to_string)
            .ok_or(GitHubError("commit traffic: no html_url in reply".into()))
    }

    /// Files an issue and returns its number.
    pub async fn create_issue(
        &self,
        title: &str,
        body: &str,
        label: &str,
    ) -> Result<u64, GitHubError> {
        let url = format!("{}/repos/{}/issues", self.api, self.repo);
        let v = self
            .send(
                self.http
                    .post(url)
                    .json(&json!({"title": title, "body": body, "labels": [label]})),
                "file issue",
            )
            .await?;
        v["number"]
            .as_u64()
            .ok_or(GitHubError("file issue: no number in reply".into()))
    }
}
