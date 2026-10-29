# Push notifications: design

Status: agreed direction (Tom, 2026-10-29), not built. Epic #37.

## Shape

Two ways to learn about new mail:

1. **On the phone (zero setup).** The app checks in the background when the operating system lets it, and shows a local notification. Unreliable on iOS, needs nothing else. This ships first and stays as the fallback.
2. **Watcher plus push hub (real push).** A small watcher runs where the BBS is reachable (the user's network, beside BPQ), polls the BBS, and asks a thin hub to push to the user's phones through APNs and FCM. The hub never holds a BBS login and never connects inward to anything; everything dials out, so it works behind CGNAT and inside a tailnet.

| | Holds | Sees |
|---|---|---|
| Phone app | BBS login, watcher pairing secret, push token | everything |
| Watcher (user's network) | the user's BBS login (handed over by the phone at pairing), one scoped push credential per paired phone | listings and message headers |
| Hub | device tokens, per-device credential hashes, last-seen times | timing, counts |
| Apple / Google | the payload | payload and token |

## Pairing

1. The watcher shows a QR code (its LAN URL, its TLS key pin, a one-time code), or a short typed code for people who won't scan.
2. The app connects over TLS pinned to that key, proves the code, and gets a long-lived pairing secret.
3. The app registers with the hub: push token, platform, install ID, and an App Attest or Play Integrity assertion. The hub returns a credential for that one device.
4. The app hands the watcher only that credential. The watcher can then notify that phone and nothing else; it is not a trusted party.

5. The app hands the watcher the BBS login for each connection to watch, over the same pinned TLS channel, so the watcher checks the mailbox as the user (Tom, 2026-10-29: fundamental). The user is told plainly before it happens ("The watcher will log in to GB7RDG as M0LTE to check for new mail"). Once granted, it is delegated: there is no ongoing per-connection management, just a manual Revoke in the app that makes the watcher delete the logins.

The watcher stores those logins encrypted at rest, never logs them, and deletes them on unpair or when the user revokes from the app. When the user changes a password in the app, the app updates the watcher. The watcher never uses a login for anything but listing.

## Notifying

The watcher calls `POST /v1/devices/{device_id}/notify` with its credential and `{count, connection, collapse_key}`. Payloads carry no subject or sender: "2 new messages at GB7RDG". The phone fetches when opened. No badge numbers from the watcher (it can't know what the user has already read); the app sets the badge itself.

## The hub

The whole risk surface, so kept boring:

- Every request is scoped to one device; a raw push token is never authorisation.
- Strict payload schema: count, connection name with a length cap, no URLs, no deep links from the caller.
- Enrolment gated by App Attest / Play Integrity and rate limits. Sideloaded APKs (GitHub releases) fail Play Integrity, so they get UnifiedPush/ntfy, or enrolment without attestation under a tight rate limit.
- Collapse per connection (apns-collapse-id, FCM collapse_key), never a backlog of buzzes.
- Unused credentials expire after 60 to 90 days unless refreshed; APNs 410 and FCM UNREGISTERED revoke at once. Hub-side forget on unpair.
- Stores only token, credential hash and timestamps.
- Runs on the OARC box beside the feedback receiver, same TLS and deployment pattern.

## The watcher

- Written in Dart on mail_core, so it reuses the drivers, parsers and recorded sessions; `dart compile exe` in a small Docker image next to BPQ. One parser, two consumers.
- **Logs in as the user**, with the login from pairing; never reads, sends or kills.
- **Listing only, never reading.** `R` marks mail read. Listing is not entirely free of side effects either: BPQ's per-user "last listed" marker moves with `L` (list new), which would hide new mail from the user's own terminal. The watcher must use listings that leave the marker alone; confirm on the test BBS before building.
- **Two logins at once.** The watcher and the app may be logged in as the same user together; BPQ's behaviour then is untested, and session limits or interlocks (as on GB7RDG) could block the user or forwarding. Long poll interval with jitter and backoff, and step aside while the app is connected.
- Persists the highest notified message number per connection across restarts. One watcher per household, many paired phones. No inbound port except pairing. Personal mail first; subscribed bulletins later (needs the subscription list synced to the watcher).
- Heartbeats to the hub so the app can say "your watcher hasn't been seen for two days".

## Another trigger: sysop-side

LinBPQ builds with MQTT. A sysop-run watcher could listen for message-stored events and notify the right phones, with no polling and no user logins. Needs a sysop's buy-in; worth keeping as a second source of triggers.

## What users will need

A health view in the app: last poll, last notification, hub acknowledgement, watcher last seen, and a "send test notification" button. The chain is watcher, router, hub, APNs or FCM, phone; when it breaks the user must be able to see which link died. Visible alerts arrive on iOS even after a force-quit; only silent pushes don't.

## Obligations

Running the hub makes Tom the controller of push tokens and IP addresses: the App Privacy and Data safety answers change from "nothing" to "identifiers, not linked to you, encrypted in transit", with a deletion path (unpair, hub forget). Privacy policy, store answers and docs/plan.md change together. The hub becomes a small uptime promise.

## Decided

- No subject or sender in notifications.
- The hub stores nothing beyond token, credential hash and timestamps.
- Pairing fallback: a short typed code.
- No watcher means on-phone notifications; that path stays.
