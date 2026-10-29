use std::net::SocketAddr;
use std::time::Duration;

/// Settings, all from environment variables. See README.md.
#[derive(Clone, Debug)]
pub struct Config {
    pub listen: SocketAddr,
    pub token: String,
    /// `owner/name` of the repo that gets the issues and traffic files.
    pub repo: String,
    pub github_api: String,
    pub max_body_bytes: usize,
    pub max_description_chars: usize,
    pub per_ip_per_hour: u32,
    pub global_per_hour: u32,
    pub request_timeout: Duration,
    pub max_connections: usize,
    /// Take the client address from the last X-Forwarded-For entry, for
    /// when a TLS proxy sits in front. Only safe if nothing else can reach us.
    pub trust_proxy: bool,
}

impl Config {
    pub fn from_env() -> Result<Config, String> {
        Config::from_lookup(|k| std::env::var(k).ok())
    }

    pub fn from_lookup(get: impl Fn(&str) -> Option<String>) -> Result<Config, String> {
        let token = get("FEEDBACK_GITHUB_TOKEN")
            .filter(|t| !t.trim().is_empty())
            .ok_or("FEEDBACK_GITHUB_TOKEN is not set")?
            .trim()
            .to_string();
        let repo = get("FEEDBACK_REPO").unwrap_or_else(|| "m0lte/packet-mail-feedback".into());
        let parts: Vec<&str> = repo.split('/').collect();
        if parts.len() != 2 || parts.iter().any(|p| p.is_empty()) {
            return Err(format!("FEEDBACK_REPO must be owner/name, not {repo}"));
        }
        let num = |key: &str, default: u64| -> Result<u64, String> {
            match get(key) {
                None => Ok(default),
                Some(v) => v
                    .trim()
                    .parse::<u64>()
                    .ok()
                    .filter(|n| *n > 0)
                    .ok_or(format!("{key} must be a whole number above 0, not {v}")),
            }
        };
        let listen = get("FEEDBACK_LISTEN").unwrap_or_else(|| "0.0.0.0:8080".into());
        Ok(Config {
            listen: listen.parse().map_err(|_| {
                format!("FEEDBACK_LISTEN must be an address and port, not {listen}")
            })?,
            token,
            repo,
            github_api: get("FEEDBACK_GITHUB_API")
                .unwrap_or_else(|| "https://api.github.com".into())
                .trim_end_matches('/')
                .to_string(),
            max_body_bytes: num("FEEDBACK_MAX_BODY_BYTES", 512 * 1024)? as usize,
            max_description_chars: num("FEEDBACK_MAX_DESCRIPTION_CHARS", 4000)? as usize,
            per_ip_per_hour: num("FEEDBACK_PER_IP_PER_HOUR", 5)? as u32,
            global_per_hour: num("FEEDBACK_GLOBAL_PER_HOUR", 60)? as u32,
            request_timeout: Duration::from_secs(num("FEEDBACK_REQUEST_TIMEOUT_SECONDS", 30)?),
            max_connections: num("FEEDBACK_MAX_CONNECTIONS", 50)? as usize,
            trust_proxy: matches!(
                get("FEEDBACK_TRUST_PROXY").as_deref().map(str::trim),
                Some("1" | "true" | "yes")
            ),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn config(pairs: &[(&str, &str)]) -> Result<Config, String> {
        let map: HashMap<String, String> = pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect();
        Config::from_lookup(|k| map.get(k).cloned())
    }

    #[test]
    fn needs_a_token() {
        assert!(config(&[]).unwrap_err().contains("FEEDBACK_GITHUB_TOKEN"));
        assert!(config(&[("FEEDBACK_GITHUB_TOKEN", " ")]).is_err());
    }

    #[test]
    fn defaults() {
        let c = config(&[("FEEDBACK_GITHUB_TOKEN", "t")]).unwrap();
        assert_eq!(c.repo, "m0lte/packet-mail-feedback");
        assert_eq!(c.max_body_bytes, 512 * 1024);
        assert_eq!(c.listen.port(), 8080);
        assert!(!c.trust_proxy);
    }

    #[test]
    fn rejects_bad_values() {
        assert!(config(&[("FEEDBACK_GITHUB_TOKEN", "t"), ("FEEDBACK_REPO", "nope")]).is_err());
        assert!(config(&[
            ("FEEDBACK_GITHUB_TOKEN", "t"),
            ("FEEDBACK_PER_IP_PER_HOUR", "0")
        ])
        .is_err());
        assert!(config(&[("FEEDBACK_GITHUB_TOKEN", "t"), ("FEEDBACK_LISTEN", "x")]).is_err());
    }
}
