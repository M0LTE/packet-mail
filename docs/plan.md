# Packet Mail: plan

Status: planning, agreed 2026-10-28. Nothing built yet.

## What it is

A phone app for iPhone and Android, released on both app stores, that gives packet radio BBS mail the feel of an ordinary email client: inbox, outbox, sent items, a bulletins browser and an address book. It hides how it reaches the BBS. The first connection type is LinBPQ (BPQMail) over the LAN; later ones could run over the packet network itself or talk to other BBS software. The experience is the same whichever connection is used.

## Decisions

| Area | Decision |
|---|---|
| Framework | Flutter, one codebase for both platforms |
| Licence | MPL-2.0 |
| How we talk to a BBS | As a user, the same way a person would at a terminal. Not as a forwarding partner, so no sysop setup is needed |
| LinBPQ ports | Both the telnet port and the FBB port (the cleaner machine-to-machine port QtTermTCP uses) |
| NTS traffic | Out of scope. Any type T message received shows as ordinary mail |
| Sync | The app keeps its own copy. Opening marks read on the BBS, deleting kills on the BBS, Sent lives in the app |
| Identity | Separate from connections. One identity in v1 |
| Background sync | Later |
| Away from home | Documented as Tailscale; a one-line warning when the host isn't a private or Tailscale address |
| Repo | `m0lte/packet-mail` on Tom's own account, not part of packet-net |
| App ID | `m0lte.packetmail` (Android doesn't allow hyphens; it can never change after first publish) |
| Demo BBS | Tom hosts a public one of his own hardened design, wire compatible with BPQ, reached through the LinBPQ driver's FBB port |

Fixed behaviour throughout: no settings beyond what is listed here.

## Layers

From top to bottom:

1. **Screens.** Flutter UI only, no protocol knowledge.
2. **Mail store.** Local SQLite database (drift) holding messages, folders, contacts, subscriptions and outgoing queue. Everything the screens show comes from here, so the app works offline.
3. **Sync engine.** Runs a sync session over one connection: send the outbox, fetch new personal mail, fetch subscribed bulletins, apply pending kills and read marks. Same logic for every driver.
4. **Drivers.** One per BBS type. Each offers the same actions and says which it can't do.
5. **Transports.** A byte stream to the BBS. v1 is TCP. Later: AX.25 over Bluetooth KISS to a TNC, built on an ax25sdl Dart generator.

A **connection** is a driver plus a transport plus its settings.

### Driver actions

| Action | Notes |
|---|---|
| connect / log in | Uses the identity's callsign and the connection's login |
| list personal | Number, from, to, subject, date, size, status |
| list bulletins | Same, plus category, area and bulletin ID |
| read | Full text and headers by message number |
| send personal | To a full address |
| send bulletin | To a category at an area, with an optional bulletin ID |
| kill | Personal mail only |
| look up address | White Pages lookup of a callsign's home BBS, where the BBS supports it |
| disconnect | Clean logout |

Capability flags let the app hide what a driver can't do (for example, no White Pages lookup).

### LinBPQ driver

- Telnet port: answer the user and password prompts, then enter the BBS.
- FBB port: send the user and password with no prompts, as QtTermTCP does.
- Turn paging off at the start of each session so listings arrive in full.
- Use the standard BPQMail commands for list (personal, new, bulletins), read, send personal, send bulletin and kill.
- Parse by recognising the BBS prompt, never by timing.
- All of the above to be confirmed against recorded real sessions before writing the parser (milestone 0).

## Data model

- **Identity:** callsign, name, home BBS full address (for example `GB7RDG.#42.GBR.EURO`).
- **Connection:** display name, BBS type, host, port, port kind (telnet or FBB), login name, password (in the phone's secure storage, never in the database).
- **Message:** connection, BBS message number, type (personal, bulletin, traffic), from, to, address, subject, date, body, bulletin ID or message ID, local state (unread, read, starred, deleted pending kill).
- **Outgoing message:** recipients, subject, body, per-recipient status (queued, sent, failed with reason).
- **Contact:** callsign, name, home BBS full address, notes, where it came from (typed, received mail, White Pages).
- **Bulletin subscription:** category and area, each optional (so "all WX" or "everything at GBR").

## Sync rules

- **Personal mail:** fetched in full. Opening a message marks it read on the BBS at the next sync. Deleting kills it on the BBS at the next sync and removes it from the app once confirmed.
- **Sent:** kept in the app only.
- **Bulletins:** headers for everything listed; bodies for subscribed categories. The BBS decides how long they live: a bulletin stays in the app while the BBS still lists it, and is removed locally once it drops off, unless starred. Never killed on the BBS. The same bulletin ID is stored once, even if seen through two connections.
- **On the LAN** everything subscribed is fetched in one go. The sync engine fetches headers and bodies as separate steps, so a slow radio link can fetch bodies only when opened.
- **Sync** runs on opening the app, on pull-to-refresh and after sending.

## Addressing

- Understands the hierarchical form `CALL@BBS.#REGION.COUNTRY.CONTINENT`, for example `G8BPQ@GB7BPQ.#23.GBR.EURO`.
- Validates as you type: callsign shape, BBS callsign, the order of the parts, the `#` on regions, known country and continent codes.
- **Bare callsign:** looks it up in the address book, then White Pages, before sending. If it can't be resolved, the message is held in the outbox with a clear reason rather than sent unroutable.
- **Bulletin addresses** are a category at a flood area (`ALL@WW`, `WX@GBR`, `KEPS@EURO`, regional `#` areas). Compose offers a known list of each, plus free entry.
- **Address book** fills itself from the From lines of received mail and from White Pages answers. Entries you've edited are never overwritten.

## Screens

- **First run:** create the identity, then add a connection (type, host, port, login), with a "test connection" button.
- **Mailboxes:** Inbox, Outbox, Sent, Starred, Bulletins. Unread counts.
- **Message list:** from, subject, date, unread dot, swipe to delete or star.
- **Message view:** headers (with the full route on tap), body, reply, forward, add sender to contacts. A toggle switches between two presentations, and the choice is remembered:
  - **As sent:** monospace, exactly the lines the BBS delivered.
  - **Readable:** proportional font, hard-wrapped lines rejoined into paragraphs, quoted text shown as indented blocks, links and callsigns tappable. Blocks that look laid out (tables, ASCII art, columns of figures, lines with runs of spaces) stay monospace so they don't break.
- **Compose:** To with address book autocomplete and validation, subject with remaining characters, body. Personal or bulletin switch; bulletin mode swaps To for category and area pickers.
- **Bulletins browser:** grouped by category, then by area. Subscribe from any group. Headers-only entries show a "fetch" action.
- **Address book:** list, search, edit, "look up home BBS".
- **Connections:** list, add, edit, delete, last sync result.
- **Sync status:** a small bar showing what is happening and the last error in plain words.

## Compose rules

- **Plain ASCII on send.** Curly quotes, long dashes, ellipses and similar become their ASCII equivalents. Anything else unmappable is flagged before sending.
- **Line wrapping:** the body is wrapped to 72 characters on send. Packet mail is read on 80-column terminals, and 72 leaves room for a few levels of `> ` quoting before a reply overflows a line.
- **Subject:** capped at 60 characters.
- **No CC.** Several recipients means one copy each. Sent shows it as one item with a status per recipient.
- **No attachments in v1.**
- **Reply:** quotes the original with `>` and prefixes `Re:`, once.

## Testing

- **Recorded sessions:** real LinBPQ sessions over both ports, saved as text and replayed against the driver in unit tests. Each new BBS type starts the same way.
- **Live container:** a LinBPQ container from the packet-net fork, run in CI, for end-to-end sync tests.
- **Address parser:** table-driven tests built from real addresses seen on GB7RDG.
- **Store:** sync engine tests against a fake driver, covering interrupted sessions and repeat syncs.

## Build and release

- GitHub Actions: Android builds on Linux, iOS on the macOS runner (no Mac needed).
- Store builds are signed in CI with secrets that Tom adds.
- Apple's reviewers need a BBS they can reach from the internet with a demo login. Tom's public demo BBS provides this, so the FBB port path must be solid by milestone 4.
- Privacy policy: the app collects nothing; data stays on the phone and the user's own BBS.

## Milestones

0. **Capture.** Record LinBPQ sessions on both ports covering every action. Confirm the prompts and command set.
1. **Core.** Data model, store, address parser, LinBPQ driver against recordings, sync engine. No UI beyond a debug screen.
2. **Mail client.** First run, connections, Inbox, Outbox, Sent, message view, compose, delete and star.
3. **Bulletins and contacts.** Bulletins browser, subscriptions, address book, White Pages lookup.
4. **Release.** Store listings, demo BBS, privacy policy, TestFlight and Play internal testing, then public release.

## Later

- Background sync and notifications.
- Packet radio transport over Bluetooth KISS, via an ax25sdl Dart generator.
- Drivers for other BBS software (FBB, JNOS and others).
- More than one identity.
- Attachments, if a sensible on-air format is chosen.

## Open questions

None at present.
