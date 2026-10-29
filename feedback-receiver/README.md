# Feedback receiver

Takes problem reports from Packet Mail's "Report a problem" screen and files each one as an issue in the private repo `m0lte/packet-mail-feedback`, labelled `in-app`. The report's traffic file is committed to that repo as `reports/<date>-<id>.jsonl` and linked from the issue.

Reports can hold real mail, so they only ever go to that private repo. The receiver keeps nothing itself.

## What the deployer provides

- A host with Docker.
- A public HTTPS URL in front of it (a reverse proxy or tunnel that terminates TLS and forwards to the container's port 8080). That URL plus `/v1/report` is compiled into the app as `reportEndpoint` in `lib/report.dart`.
- A fine-grained GitHub token for `m0lte/packet-mail-feedback` only, with **Contents: read and write** and **Issues: read and write**. Nothing else.

## Run it

```sh
docker build -t packet-mail-feedback-receiver feedback-receiver
docker run -d --name feedback-receiver --restart unless-stopped \
  --read-only --cap-drop ALL --security-opt no-new-privileges --memory 128m --pids-limit 64 \
  -e FEEDBACK_GITHUB_TOKEN \
  -e FEEDBACK_TRUST_PROXY=true \
  -p 127.0.0.1:8080:8080 packet-mail-feedback-receiver
```

Put the token in the environment of the shell that runs this (or use `--env-file` with a file only root can read). Never put it in this repo.

Check it with `curl http://127.0.0.1:8080/healthz`, which answers `ok`.

## Settings

All by environment variable. Only the token is required.

| Variable | Default | What |
|---|---|---|
| `FEEDBACK_GITHUB_TOKEN` | (none) | The GitHub token. The receiver won't start without it |
| `FEEDBACK_REPO` | `m0lte/packet-mail-feedback` | Where issues and traffic files go |
| `FEEDBACK_LISTEN` | `0.0.0.0:8080` | Address and port |
| `FEEDBACK_MAX_BODY_BYTES` | 524288 | Largest report, in bytes. Bigger ones get 413 |
| `FEEDBACK_MAX_DESCRIPTION_CHARS` | 4000 | Longest description |
| `FEEDBACK_PER_IP_PER_HOUR` | 5 | Reports per address per hour (IPv6 per /64) |
| `FEEDBACK_GLOBAL_PER_HOUR` | 60 | Reports per hour from everyone together |
| `FEEDBACK_REQUEST_TIMEOUT_SECONDS` | 30 | Longest a request may take, including the calls to GitHub |
| `FEEDBACK_MAX_CONNECTIONS` | 50 | Connections at once; more are dropped |
| `FEEDBACK_TRUST_PROXY` | off | Set to `true` behind a TLS proxy, so limits count the address the proxy puts last in `X-Forwarded-For`. Leave off if anything can reach the port directly |
| `FEEDBACK_GITHUB_API` | `https://api.github.com` | Only changed by the tests |

Request headers must arrive within 10 seconds.

## The API

`POST /v1/report` with a JSON body:

```json
{
  "description": "Message 4490 looks odd.",
  "includeMessageText": false,
  "appVersion": "0.1.0",
  "build": "12",
  "platform": "ios",
  "osVersion": "18.1",
  "bbsBanners": ["[BPQ-6.0.26.1-IHJM$]"],
  "traffic": "{\"t\": 0.12, \"dir\": \"rx\", \"data\": \"...\"}\n"
}
```

`traffic` is the recording format from `packages/mail_core/lib/src/transport/recording.dart`: JSON lines, with `#` comment lines. Unknown fields are ignored.

Replies:

- 200 `{"id": "2026-10-29-1a2b3c4d", "issue": 7}`: filed.
- 400 `{"error": "..."}`: not a valid report.
- 413: too big.
- 429 with `Retry-After`: too many reports.
- 502: GitHub couldn't be reached or refused. Try again later.

`GET /healthz` answers `ok`.

## Logs

One line per request: method, path, status, time taken, size, and the report id. Never the description, the traffic or the sender's address. A failed GitHub call adds one line with the step and the HTTP status.

## Tests

```sh
cd feedback-receiver
cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
```

The tests run the receiver against a mocked GitHub API, so they need no token or network.
