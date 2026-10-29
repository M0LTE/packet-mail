# Demo BBS

A small BBS that anyone can reach over the internet to try Packet Mail without a real BBS: App Store and Play reviewers, and curious users. It speaks the same bytes as LinBPQ's FBB port and the BPQMail user commands the app uses (see `docs/bpq-protocol.md`), so the app connects to it as an ordinary LinBPQ BBS.

It is not a real BBS. Every station, name, message and bulletin on it is made up, using the unallocated Q0 prefix. It never forwards mail and never connects anywhere.

## What a visitor sees

- Login `demo`, password `demo`. Any other simple user name (up to 16 characters, no spaces) works too, with the same password, and gets its own copy. Every login is the station **Q0YOU**, whose home BBS is `Q0DEMO.#42.GBR.EURO`.
- Four personal messages (one with routing lines, one a quoted reply), two sent messages, and a dozen bulletins in several categories and areas (ALL, WX, NEWS, DX, SALE, TECH, SATS at GBR, WW, EU, EURO), including laid-out tables.
- **Q0BOT**, the demo robot, answers any personal message sent to it straight away. The reply is in the inbox at the next list.
- White Pages answers for the made-up stations (`I Q0ADA`).

Commands: `L`, `LM`, `LB`, `L< CALL`, `LN`, `LL n` and the other listing options, `R n`, `RM`, `SP`, `SB` (with `@ area`, `$BID`, duplicate-BID refusal and the empty-title cancel), `K n`, `KM`, `I CALL`, `HOMEBBS`, `OP`, `B` and `NODE`. Anything else gets BPQ's `Invalid Command` and changes nothing.

## Safety model

**Each visitor gets a private copy of the demo mail, its sandbox, kept only in memory.** A visitor is a public IP address (IPv6: a /64) plus a login name. Visitors behind the same public IP using the same login share a sandbox for up to 30 minutes after their last connection; everyone else never sees it. Nothing is ever written to disk.

- The app makes a new connection to sync, to open a message and to delete, so the sandbox carries over between connections: a deleted message stays deleted, and the robot's reply can be opened later.
- A sandbox is thrown away 30 minutes after its last connection ends, and in any case 2 hours after it was made. The next visit starts fresh.
- At most 200 sandboxes are held. When that is full the oldest idle one is dropped; if none is idle, a new visitor gets `Sorry, the demo BBS is full. Please try again later.` and is disconnected.
- No forwarding, no outbound connections, no file or shell access.
- New messages are numbered from the time of day, so a later sandbox never reuses a number the app already holds for different mail.
- Logs are one line each for a connect, a disconnect and a limit hit, with the source address. Never user names, passwords or message text.
- The image is a single static binary on an empty image (no shell), running as an unprivileged user.

## Limits

Set with environment variables; the defaults are below. A connection turned away gets `No Free Sessions` and is closed.

| Variable | Default | What |
|---|---|---|
| `DEMO_BBS_LISTEN` | `0.0.0.0:8011` | Address and port |
| `DEMO_BBS_MAX_CONNECTIONS` | 50 | Connections at once, overall |
| `DEMO_BBS_MAX_PER_IP` | 3 | Connections at once per address (IPv6 per /64) |
| `DEMO_BBS_CONNECTS_PER_MINUTE` | 30 | New connections per address per minute (the app connects once per sync and once per message opened) |
| `DEMO_BBS_LOGIN_SECONDS` | 60 | Time to log in and enter the BBS |
| `DEMO_BBS_IDLE_SECONDS` | 600 | Time without a complete line before closing. Bytes without a line end don't count, so a slow trickle can't hold a connection |
| `DEMO_BBS_SESSION_SECONDS` | 1800 | Longest connection |
| `DEMO_BBS_MAX_LINE` | 1024 | Bytes kept per line; the rest of a longer line is dropped |
| `DEMO_BBS_MAX_MESSAGE_BYTES` | 16384 | Largest message a visitor can send |
| `DEMO_BBS_MAX_MESSAGES` | 20 | Messages a visitor can send, over all connections to one sandbox |
| `DEMO_BBS_MAX_IN_BYTES` | 262144 | Bytes received per sandbox |
| `DEMO_BBS_MAX_OUT_BYTES` | 4194304 | Bytes sent per sandbox |
| `DEMO_BBS_MAX_SANDBOXES` | 200 | Sandboxes held at once |
| `DEMO_BBS_SANDBOX_IDLE_SECONDS` | 1800 | How long a sandbox is kept after its last connection ends |
| `DEMO_BBS_SANDBOX_MAX_SECONDS` | 7200 | Oldest a sandbox can get |

Fixed, as on BPQ: 5 failed logins or 5 unknown commands close the connection, and one `R` or `K` takes at most 20 numbers.

## Running it

```
docker build -t packet-mail-demo-bbs demo-bbs
docker run -d --name demo-bbs --restart unless-stopped \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --memory 128m --pids-limit 64 \
  -p 8011:8011 packet-mail-demo-bbs
```

Try it with `nc HOST 8011`, then type `demo`, `demo`, `BBS`, a name, and `?` for the commands. Lines end with CR, so in a terminal press Enter as usual.

**Hosting needs:** one small container (tens of MB of memory at most, under 1 MB image) and one TCP port open to the internet. Nothing else: no volume, no database, no outbound access.

For local tests, `./run.sh` builds the image and starts it on `127.0.0.1:18111`. Then in `packages/mail_core`: `PACKET_MAIL_DEMO_BBS=1 dart test test/driver_demo_test.dart`. CI does the same on every push.

`cargo test` runs the server's own tests, including property tests that feed random input to the line reader and the command handler.

## App Review notes

Replace `HOST` with the public host name once it is hosted.

```
Packet Mail needs a packet radio BBS. We run a demo BBS on the internet
for review. All its stations, names and mail are made up, and nothing
you send is seen by anyone else.

1. First screen, your station:
   Callsign: Q0YOU
   Name: anything
   Home BBS: Q0DEMO.#42.GBR.EURO
2. Your BBS:
   BBS type: LinBPQ    Port kind: FBB port
   Host: HOST          Port: 8011
   Login name: demo    Password: demo
3. Sync. The inbox shows four messages and Bulletins shows a dozen.
4. Write a message to Q0BOT. After the next sync, a reply from the demo
   robot is in the inbox.

Your copy of the demo mail is kept for 30 minutes after you last
connect, then reset.
```
