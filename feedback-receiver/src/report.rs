use serde::Deserialize;

/// What the app sends. Unknown fields are ignored so a newer app still works.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Report {
    pub description: String,
    pub include_message_text: bool,
    pub app_version: String,
    pub build: String,
    pub platform: String,
    pub os_version: String,
    #[serde(default)]
    pub bbs_banners: Vec<String>,
    pub traffic: String,
}

const MAX_SHORT: usize = 100;
const MAX_BANNERS: usize = 20;
const MAX_BANNER: usize = 200;

fn has_control(s: &str, allow_lines: bool) -> bool {
    s.chars()
        .any(|c| c.is_control() && !(allow_lines && matches!(c, '\n' | '\r' | '\t')))
}

fn short(name: &str, value: &str) -> Result<(), String> {
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    if value.chars().count() > MAX_SHORT || has_control(value, false) {
        return Err(format!("{name} is not valid"));
    }
    Ok(())
}

impl Report {
    pub fn validate(&self, max_description_chars: usize) -> Result<(), String> {
        if self.description.chars().count() > max_description_chars {
            return Err(format!(
                "description is longer than {max_description_chars} characters"
            ));
        }
        if has_control(&self.description, true) {
            return Err("description has control characters".into());
        }
        short("appVersion", &self.app_version)?;
        short("build", &self.build)?;
        short("platform", &self.platform)?;
        short("osVersion", &self.os_version)?;
        if self.bbs_banners.len() > MAX_BANNERS {
            return Err("too many bbsBanners".into());
        }
        if self
            .bbs_banners
            .iter()
            .any(|b| b.chars().count() > MAX_BANNER || has_control(b, false))
        {
            return Err("bbsBanners is not valid".into());
        }
        for (n, line) in self.traffic.lines().enumerate() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            match serde_json::from_str::<serde_json::Value>(line) {
                Ok(v) if v.is_object() => {}
                _ => return Err(format!("traffic line {} is not a JSON object", n + 1)),
            }
        }
        Ok(())
    }

    pub fn title(&self) -> String {
        let first = self
            .description
            .lines()
            .map(str::trim)
            .find(|l| !l.is_empty());
        match first {
            None => "In-app report (no description)".into(),
            Some(l) => {
                let mut t: String = l.chars().filter(|c| !c.is_control()).take(70).collect();
                if l.chars().count() > 70 {
                    t.push_str("...");
                }
                format!("In-app report: {t}")
            }
        }
    }

    /// The issue text. Everything the app sent sits inside code fences, so
    /// it can't ping anyone or inject markdown.
    pub fn issue_body(&self, received: &str, traffic_path: &str, traffic_url: &str) -> String {
        let description = if self.description.trim().is_empty() {
            "(No description)".to_string()
        } else {
            self.description.trim().to_string()
        };
        let banners = if self.bbs_banners.is_empty() {
            "none seen".to_string()
        } else {
            self.bbs_banners.join(" ")
        };
        let details = format!(
            "App: Packet Mail {} (build {})\nPlatform: {} {}\nBBS: {}\nMessage text: {}\nReceived: {}",
            self.app_version,
            self.build,
            self.platform,
            self.os_version,
            banners,
            if self.include_message_text { "included" } else { "removed" },
            received,
        );
        let lines = self
            .traffic
            .lines()
            .filter(|l| !l.trim().is_empty() && !l.trim_start().starts_with('#'))
            .count();
        format!(
            "{}\n\n{}\n\nTraffic: [{}]({}) ({} events)\n",
            fenced(&description),
            fenced(&details),
            traffic_path,
            traffic_url,
            lines
        )
    }
}

/// [text] in a code fence longer than any run of backticks inside it.
pub fn fenced(text: &str) -> String {
    let mut longest = 0;
    let mut run = 0;
    for c in text.chars() {
        if c == '`' {
            run += 1;
            longest = longest.max(run);
        } else {
            run = 0;
        }
    }
    let fence = "`".repeat((longest + 1).max(3));
    format!("{fence}text\n{text}\n{fence}")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn report() -> Report {
        Report {
            description: "Message 4490 looks odd.\nSecond line".into(),
            include_message_text: false,
            app_version: "0.1.0".into(),
            build: "12".into(),
            platform: "ios".into(),
            os_version: "18.1".into(),
            bbs_banners: vec!["[BPQ-6.0.26.1-IHJM$]".into()],
            traffic: "# GB7RDG\n{\"t\":0.1,\"dir\":\"rx\",\"data\":\"hello\\r\"}\n\n{\"t\":0.2,\"dir\":\"close\"}\n".into(),
        }
    }

    #[test]
    fn a_good_report_passes() {
        assert_eq!(report().validate(4000), Ok(()));
    }

    #[test]
    fn rejects_bad_fields() {
        let mut r = report();
        r.description = "x".repeat(11);
        assert!(r.validate(10).is_err());

        let mut r = report();
        r.description = "nul\0".into();
        assert!(r.validate(4000).is_err());

        let mut r = report();
        r.platform = "".into();
        assert!(r.validate(4000).is_err());

        let mut r = report();
        r.os_version = "x".repeat(101);
        assert!(r.validate(4000).is_err());

        let mut r = report();
        r.build = "1\n2".into();
        assert!(r.validate(4000).is_err());

        let mut r = report();
        r.bbs_banners = vec!["b".into(); 21];
        assert!(r.validate(4000).is_err());

        let mut r = report();
        r.traffic = "{\"ok\":1}\nnot json\n".into();
        assert_eq!(
            r.validate(4000),
            Err("traffic line 2 is not a JSON object".into())
        );
    }

    #[test]
    fn title_uses_the_first_line() {
        assert_eq!(report().title(), "In-app report: Message 4490 looks odd.");
        let mut r = report();
        r.description = " \n".into();
        assert_eq!(r.title(), "In-app report (no description)");
        r.description = "y".repeat(80);
        assert!(r.title().ends_with("yyy..."));
    }

    #[test]
    fn body_fences_what_the_app_sent() {
        let mut r = report();
        r.description = "see ``` and @someone".into();
        let body = r.issue_body(
            "2026-10-29 12:00 UTC",
            "reports/x.jsonl",
            "https://example/x",
        );
        assert!(body.starts_with("````text\nsee ``` and @someone\n````\n"));
        assert!(body.contains("App: Packet Mail 0.1.0 (build 12)\nPlatform: ios 18.1\nBBS: [BPQ-6.0.26.1-IHJM$]\nMessage text: removed\n"));
        assert!(body.contains("Traffic: [reports/x.jsonl](https://example/x) (2 events)"));
    }
}
