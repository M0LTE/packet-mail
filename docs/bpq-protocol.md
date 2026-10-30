# BPQMail user protocol reference

How a client talks to LinBPQ's mail BBS (BPQMail) as an ordinary user, over the node's Telnet FBB port. Everything here was read from the LinBPQ C source in `/home/tf/src/linbpq` (m0lte fork of G8BPQ LinBPQ, 2026-10 master). No live system was used.

File references are `file:line` in that tree. Each statement is marked:

- **[C]** certain: read directly from the code path.
- **[I]** inferred: follows from the code but depends on something not traced to the end, or on typical configuration.

Strings are quoted exactly as they appear in C source, so `\r` means a single CR byte (0x0D).

## 1. Transport and login (Telnet FBB port)

### 1.1 Connect

| Step | Behaviour | Ref |
|---|---|---|
| TCP connect | Any listening Telnet port other than the main `TCPPORT` (and other than the HTTP, API, sync, DRATS, relay and Trimode ports) is an FBB-mode port. **[C]** | TelnetV6.c:3462-3463 |
| Banner | Nothing is sent: no telnet negotiation, no login prompt. (The normal telnet port sends IAC negotiation and `LoginMsg`.) **[C]** | TelnetV6.c:3509-3513 |
| No free session | `No Free Sessions\r\n` then close. **[C]** | TelnetV6.c:3528 |

### 1.2 Username and password

The client sends `username\r` then `password\r`. Nothing is echoed. A lone LF at the start of a line is dropped, and a bare CR is skipped. **[C]** (TelnetV6.c:4655-4686)

| Event | What the client receives | Ref |
|---|---|---|
| Username matches a `USER=` entry | Nothing. State moves to "awaiting password". **[C]** | TelnetV6.c:4901-4946 |
| Unknown username | `LoginMsg`, default `user:` (no CR). The next line is again treated as a username. So a bad username followed by a pipelined password produces `user:` twice. **[C]** | TelnetV6.c:4950-4962, 1499-1500 |
| Good password | Nothing from the telnet layer. No CTEXT: the FBB path calls `ProcessIncommingConnect(..., FALSE)` and, unlike the normal telnet path, never sends `cfgCTEXT`. The node sends no prompt either (BPQ nodes have no command prompt). **[C]** | TelnetV6.c:4989, compare 4108-4124 |
| Bad password | `PasswordMsg`, default `password:` (no CR). State stays at "awaiting password", so the next line is another password attempt. **[C]** | TelnetV6.c:5079-5091, 1501-1502 |
| 5th failure (username or password) | `Too many attempts - Disconnected\r\n` then close after 1 s. On the username path the send uses `sizeof`, so a trailing NUL byte follows. **[C]** | TelnetV6.c:128, 4952-4956, 5081-5085 |
| No more than 256 bytes | While logging in, any buffer over 256 bytes is silently discarded. **[C]** | TelnetV6.c:4646-4653 |

Notes:

- Username and password comparisons are case-sensitive `strcmp`. **[C]** (TelnetV6.c:4914, 5011)
- A `USER=ANON,...` entry accepts any username as the callsign (uppercased). **[C]** (TelnetV6.c:4908-4913)
- The BBS identity is the **callsign field of the USER line** (third field), not the username. The BBS strips any SSID and keys its user record on the base call. **[C]** (TelnetV6.c:4918; BBSUtilities.c:10843-10851)
- `LoginMsg` and `PasswordMsg` are configurable with `LOGINPROMPT` and `PASSWORDPROMPT` in the Telnet port config. **[C]** (TelnetV6.c:643-655). A client should treat "the first bytes received after sending the password, within a short timeout" as failure, rather than matching the literal text.

### 1.3 The USER line's application field

`USER=name,password,callsign,appl,secure`. If `appl` is set (for example `BBS`), the node is sent `appl\r\n` right after a good password, so the user lands in the BBS without typing anything. **[C]** (TelnetV6.c:777-806, 5072-5075)

Order matters: any bytes the client pipelined after the password line are sent to the node **before** the `appl` command. **[C]** (TelnetV6.c:5029-5069)

Client consequence **[I]**: if the account auto-starts the BBS and the client also sends `BBS\r`, that line reaches the BBS as a command and gets `Invalid Command` (and counts towards the 5-error limit, section 14). Safer: after the password, wait about 2 s; if a BBS SID or `Connected to` line has arrived, do not send `BBS`.

### 1.4 Secure accounts

If the USER line's `secure` field is set **and** the BBS user record has the SYSOP flag, the BBS session runs with sysop rights. **[C]** (TelnetV6.c:4995; BBSUtilities.c:10932-10937). A sysop sees killed and held messages in listings, can read anything, and can kill anything. A client should use a non-sysop account or expect K and H status lines.

## 2. Entering the BBS

The client sends the application command, usually `BBS\r` (the name is whatever `APPLICATION n,NAME,...` says in bpq32.cfg). The node command parser uppercases the line, ends it at CR **or `;`**, and ignores lines over about 100 bytes. **[C]** (Cmd.c:5021-5026, 5250-5262)

Node replies (each starts with the node header, `ALIAS:CALL} `, built from the node alias and call plus `HEADERCHAR`, default `}`) **[C]** (Cmd.c:4980-4996, cMain.c:260):

| Situation | Reply | Ref |
|---|---|---|
| Attached | `ALIAS:CALL} Connected to BBS\r` (BPQMail registers with `MSG_TO_USER`, flag 2) | Cmd.c:1136-1140; LinBPQ.c:1760; cheaders.h:184 |
| BBS streams all busy | `... Sorry, All BBS Ports are in use - Please try later\r` | Cmd.c:1102 |
| BBS not running | `... Sorry, Application BBS is not running - Please try later\r` | Cmd.c:1104 |
| Typo | `... Invalid command - Enter ? for command list\r` | Cmd.c:98 |

`BBS S` (stay flag) makes the node return the user to node command level when the BBS disconnects, instead of closing the session. **[C]** (Cmd.c:1030-1031, L4Code.c:1068-1072)

### 2.1 What the BBS sends on connect

In order (BBSUtilities.c `Connected()`, 10727-11069):

1. Possible silent refusal, then disconnect **[C]**: `OnlyKnown` set and the call is unknown (10856-10865); user has the Exclude flag (10941-10947). Fork only: if the port is interlocked with a partner forwarding session, `Sorry, mail forwarding in progress on this channel. Please try later\r` then disconnect (BBSSessionControl.c:257).
2. Only for callsigns ending `-T` or `-R`: `;WL2K-Radio/Internet_Network\r` **[C]** (11027-11028).
3. The SID, format `"[%s%d.%d.%d.%d-%s%s%s%sIH%sM$]\r"` with `"BPQ-"`, the version, then optional `B`, `1`, `2`, `FW`, then `J` unless `-R`. Example: `[BPQ-6.0.25.41-B2FWIHJM$]`. Exact flags vary by user record. **[C]** (MailDataDefs.c:113, BBSUtilities.c:11031-11034). The client must ignore this and must **not** answer with its own SID (see 13.2).
4. Either the new-user name prompt or the welcome:
   - If the user record has no name (and `AllowAnon` is off): `Please enter your Name\r>\r` **[C]** (MailDataDefs.c:117, BBSUtilities.c:11048-11052). The next line, whatever it is, becomes the name (truncated to 17 bytes), then the welcome follows **[C]** (12715-12727). An empty line sets an empty name, so the prompt reappears next login **[I]**. With `AllowAnon`, the name is set to the callsign and no prompt is sent **[C]** (11042-11043).
   - Welcome (`SendWelcomeMsg`, 1932-1947): one of three configurable texts, chosen by expert flag, then new-user, then normal. Default for normal and new users: `Hello $I. Latest Message is $L, Last listed is $Z\r\n`; default expert welcome is empty. **[C]** (10464-10489)
5. Unless `DontNeedHomeBBS` is set, users with no home BBS get: `Please enter your Home BBS using the Home command.\rYou may also enter your QTH and ZIP/Postcode using qth and zip commands.\r` **[C]** (1941-1942)
6. The prompt (section 3).

There are **no** separate QTH or home BBS prompts for new users; only the name is prompted for. **[C]**

Welcome and prompt texts expand `$` codes **[C]** (ExpandAndSendMessage, 2543-2637): `$I` name, `$L` latest message number, `$N` number of active messages, `$U` callsign, `$W` CR, `$Z` user's last-listed message number, `$X` messages to the user, `$x` unread messages to the user, `$F` messages to forward. Any other `$c` becomes `$`. After expansion, every CRLF becomes CR and NULs are removed (`RemoveLF`, 4710-4740).

A brand new user record also gets **[C]** (10870-10910): `F_HOLDMAIL` unless `DontHoldNewUsers` (so their sent messages are held, see 8.6), `lastmsg = LatestMsg - 20` (so `L` lists only the last 20), and the sysop is mailed if `SendNewUserMessage`.

## 3. The prompt

`SendPrompt` (BBSUtilities.c:1950-1960) sends one of three configurable prompts: `ExpertPrompt` if the user has expert mode, else `NewPrompt` during a new user's first session, else `Prompt`. Config keys: `Prompt`, `NewUserPrompt`, `ExpertPrompt` (10494-10520). **[C]**

- Default for all three: `"de %s>\r\n"` with `BBSName` (the BBS callsign), so `de GB7RDG>\r\n`. **[C]** (10499-10519)
- `TidyPrompt` forces every prompt to end with `>` then CRLF (13588-13609); `ExpandAndSendMessage` then turns CRLF into CR. **On the wire the prompt is always a line whose last character before CR is `>`.** **[C]**
- It may contain `$` codes, so its text can change between commands (for example `$x`), and `$W` makes it multi-line. **[C]**
- The prompt is suppressed while a listing is paused (section 4). **[C]** (1952-1953)

Reliable recognition **[I]**:

1. Sending an empty line (`\r`) at command level produces exactly one prompt and nothing else (12766-12770) **[C]**. So after entering the BBS, send `\r` and record the line that comes back: that is this BBS's prompt for this user.
2. A response is complete when a CR-terminated line ending in `>` arrives and no further bytes follow within a short quiet period. Do not rely on `>` alone: the paging prompts also end in `>`, but they are **not** followed by CR (section 4), and the new-user name prompt is `>\r`.
3. If the BBS uses `$` codes in the prompt, match on the suffix `>` plus CR rather than the exact text.

Every command handler that completes normally sends the prompt; a few (`S` in progress, `PG`) do not until the dialogue ends. **[C]**

## 4. Paging

Per-user page length, stored in the user record, default 0 (off) for new records. **[C]** (530-545, 10979-10980)

| Command | Effect | Reply | Ref |
|---|---|---|---|
| `OP` | Show | `Page Length is %d\r` | 13113-13142 |
| `OP n` (n >= 10) | Set, saved permanently | `Page Length is %d\r` | same |
| `OP 0` | Turn paging off, saved permanently | `Page Length is 0\r` | same |
| `OP n` (1..9) | Refused | `Page Length %d is too short\r` | 13127 |

There is no session-only setting. `OP 0` changes the user's stored record, so it also affects the user's own terminal sessions. **[C]** A polite client can send `OP` first, parse the number, send `OP 0`, and restore `OP n` before `B`. **[I]**

Two paging mechanisms exist:

1. **General output paging** (Flush, 3356-3461): counts CRs sent; at `PageLen` lines it stops and sends `<A>bort, <CR> Continue..>` with **no CR after it**. **[C]** (3434) Any input line that starts with `A`/`a` (and is longer than just CR) clears the queue and sends `\rOutput aborted\r` then the prompt; any other line, including an empty one, continues. **[C]** (12737-12757, MailDataDefs.c:138)
2. **Listing paging** (ListMessage, 3826-3836): during `L` commands, when the listed line count reaches `PageLen - 1`, it sends `<A>bort, <R Msg(s)>, <CR> = Continue..>` (no CR) and suspends the listing. The prompt is not sent. Replies (ProcessSuspendedListCommand, 13859-13908) **[C]**:
   - line starting `A`: abandon the listing, send the prompt.
   - `R n [n ...]`: read those messages, then the pause text again.
   - `C` or empty line: continue listing; prompt at the end.
   - anything else: `<A>bort, <R Message>, <CR> = Continue..>` (note the different wording).

## 5. Per-user flags that change output

| Flag | Set by | Effect | Ref |
|---|---|---|---|
| Expert | `X` toggles it, saved permanently. Replies `Expert Mode\r` or `Expert Mode off\r` | Only changes which welcome text and prompt are used (default expert welcome is empty; default expert prompt is the same `de CALL>`). No other output changes. **[C]** | 13372-13383, 1932-1960; no other `F_Expert` uses in BBS code |
| Page length | `OP` | Section 4 | |
| Sysop | User record flag plus secure session | Sees all messages, extra help lines, extra commands | 10915-10922 |
| Hold mail | Sysop, or automatically on new users | Messages the user sends get status H | 5554-5559 |
| No bulls | Sysop | `SB` refused | 5098-5102 |

`N name` sets the name (17 bytes max) and then re-sends the welcome and prompt; `N` alone just re-sends them. **[C]** (13095-13110)

## 6. Command parsing rules

Input lines end with CR, LF or CRLF (any of them). **[C]** (11399-11466). The line is split on space, tab and CR. Matching is case-insensitive and mostly by **prefix**, in this order, and the first match wins (ProcessLine, 12582-13447). Consequences a client must know **[C]**:

| Typed | Means | Why |
|---|---|---|
| anything starting `L` (except `LIS...`) | List | 12913 |
| anything starting `A` | Abort output | 12938 |
| `B`, `BY`, `BYE`, `ELSE` | Log off | 12951 |
| `NODE` | Return to node | 12965 |
| anything starting `K` | Kill | 12999 |
| anything starting `I` | Info file, or WP lookup if an argument follows | 13059 |
| `N`, `NA`, `NAM`, `NAME` | Set name | 13095 |
| anything starting `OP` | Page length | 13113 |
| `Q`, `QT`, `QTH` | QTH (not quit) | 13145 |
| `P`, `PA`, `PAS`, `PASS` | Set BBS password (`P` alone replies `Must specify a password\r`) | 13210 |
| anything starting `R` (after `READ...` and `REROUTEMSGS`) | Read | 13232 |
| anything starting `S` (after `SHOWRMSPOLL`, `SETNEXTMESSAGENUMBER`) | Send | 13239 |
| `H`, `HE`, `HEL`, `HELP`, `?` | Help | 13246 |
| `HO`.. `HOMEBBS` | Home BBS | 13326 |
| anything starting `X` | Toggle expert | 13372 |

There is no `NH`, `NQ`, `NZ`, `WP` or `P call` command in BPQMail; they produce `Invalid Command`. Home BBS, QTH and postcode are `HOMEBBS`, `QTH` and `ZIP`. **[C]**

## 7. Listing

### 7.1 Who can see what

`CheckUserMsg` (4558-4580) **[C]**. For a non-sysop:

- Status K (killed) and H (held) messages are never shown.
- Types B (bulletin) and T (NTS traffic) are shown to everyone.
- Type P (personal) is shown only if `to` or `from` equals the user's call (case-insensitive, base call without SSID).

### 7.2 Options

The command word is parsed as a set of letters after the leading `L`; most combine (DoListCommand, 3842-4112) **[C]**:

| Letter | Meaning |
|---|---|
| (none) `L` | New: from the user's last-listed number to the latest. If there is nothing new: `No New Messages\r`. Updates "last listed" only when the listing runs to the end (not when aborted or paused). Saved to the user record on the next non-`L` command or at disconnect. |
| `R` | Oldest first (default is newest first). `LR` = list new, oldest first. |
| `P` / `B` / `T` | Only that type (first match in order T, P, B). |
| `N` `Y` `F` `$` `D` | Only that status (first match in order N, Y, F, $, H, K, D). `H` and `K` are sysop only: `LH or LK can only be used by SYSOP\r`. |
| `<` call | From that call (exact). |
| `>` call | To that call (exact; for bulletins, the category). |
| `@` text | `via` starts with text (prefix match). |
| `M` | To me (exact `to` match). Also excludes killed even for sysops. |
| `L` n | The last n matching messages (`LL 20`, `LLB 20`). |
| `V` | Verbose: append the email part to From. |
| `C` (alone, `LC`) | List bulletin categories (separate format). |

Arguments **[C]** (3982-4045):

- `L n`: only message n.
- `L n-m` or `L n m`: range n to m inclusive. `L n-`: n to latest.
- With `<`, `>` or `@`, the first argument is the call, then an optional range.
- Any number over 100000: `Message Number too high\r`.
- Without arguments, any option other than plain `L`/`LR` scans the **whole** message base (1 to latest). `LB` alone lists every visible bulletin.
- No matches: no output at all, just the prompt.

### 7.3 Line format

From ListMessage (3784-3824) **[C]**. Four variants, chosen by address:

```
"%-6d %s %c%c   %5d %-7s@%-6s %-6s %-s\r"     to + via   (via cut at first '.')
"%-6d %s %c%c   %5d %-7s        %-6s %-s\r"    to, no via
"%-6d %s %c%c   %5d %-7s %-6s %-s\r"           to RMS (prints "RMS:" + via) or smtp ("smtp:" + via)
```

Fields: number, date, type, status, size, to, (@via), from, title.

- Date: `"%02d-%3s"` from `FormatDateAndTime(..., TRUE)`, for example `28-Oct`, UTC, **no year**. **[C]** (5049-5067)
- Size: bytes of the stored body, CRLF counted as 2. **[C]**
- Example (constructed from the format, not captured): `12345  28-Oct BN     1234 ALL    @WW     G8BPQ  Weekly news`
- The columns are only nominally fixed: numbers over 6 digits, sizes over 5 digits, via over 6 chars or long From values (RMS/SMTP senders, `LV`) push later fields right. Parse by whitespace, not by column **[I]**. Suggested pattern: `^(\d+)\s+(\d\d-\w{3})\s+(\S)(\S)\s+(\d+)\s+(\S+)\s*(?:@(\S+))?\s+(\S+) ?(.*)$`. Note `to` and `@via` are separated by padding spaces. The title can be empty.
- Via in the listing is only the first element (`GB7RDG` from `GB7RDG.#42.GBR.EURO`). The full hierarchical address is not available to a normal user from `L` or `R` **[C]**, except via R: lines in forwarded message bodies.

Type letters **[C]**: `P` personal, `B` bulletin, `T` NTS traffic.

Status letters **[C]** (assignments across BBSUtilities.c, FBBRoutines.c, MBLRoutines.c):

| Status | Meaning |
|---|---|
| `N` | New. For P: not yet read by the addressee. For B: no forwarding pending (not "unread"). |
| `Y` | Read by the addressee (personal). |
| `$` | Bulletin with forwarding still pending. |
| `F` | Forwarded to all BBSs that should get it. |
| `H` | Held (sysop must release). Hidden from normal users. |
| `K` | Killed. Hidden from normal users. |
| `D` | NTS message flagged delivered. |

The BBS keeps no per-user read state for bulletins; the only per-user marker is "last listed". **[C]**

## 8. Reading

### 8.1 Commands

| Command | Behaviour | Ref |
|---|---|---|
| `R n [n ...]` | Read each listed number | 4660-4675 |
| `R` | Nothing (no error), prompt | same |
| `RM` | Read every message whose `to` is my call **and** status is `N`, newest first | 4677-4700 |
| `RMR` | Same, oldest first | same |
| `RN` and anything else | `*** Error: Invalid Read option %c\r` | 4705 |

### 8.2 Output

ReadMessage (4768-4966) **[C]**:

```
"From: %s%s\rTo: %s\rType/Status: %c%c\rDate/Time: %s\rBid: %s\rTitle: %s\r\r"
```

- From is the call plus the stored email part (for example `@WINLINK.ORG` style, often empty).
- To is the bare `to` field; the @BBS (via) is **not** shown. For RMS mail it shows `RMS:` + via; for SMTP mail `smtp:` + via.
- Date/Time is `"%02d-%3s %02d:%02dZ"`, for example `28-Oct 14:05Z`, UTC, no year (5049-5067).
- Type/Status shows the status **before** this read changes it.
- Then the body exactly as stored, with CRLF turned into CR (bare LFs left alone). There are no extra header lines: R: routing lines appear only because they are the first lines of a forwarded message's body. Locally entered messages have none (the BBS adds R: lines when forwarding, not when storing) **[I]**.
- Then `"\r\r[End of Message #%d from %s%s]\r"`. Since stored bodies end with a line break, the client sees the body, two empty lines, then the end marker **[I]**. Strip those two empty lines.
- Winlink (B2) messages: if they have attachments, `Message has Attachments\r\r`, the body, then for each file either `\rAttachment %s\r\r` plus text, or `\rAttachment %s is a binary file\r`. Without attachments the output starts at the stored `Body:` line, so that header line appears in the text. **[C]**

Errors: `Message %d not found\r` (no such number), `Message %d not for you\r` (exists but not visible, including killed or held), `File for Message %d not found\r`. **[C]**

### 8.3 Side effects

Status becomes `Y` only when **all** of these hold **[C]** (4944-4959): the message `to` equals the reader's call (or the reader is sysop and `to` is SYSOP), and the current status is not K, H, F or D. So reading your own sent mail, someone else's, or a bulletin changes nothing. Reading a bulletin addressed to your own callsign would mark it Y.

## 9. Sending

### 9.1 Commands

DoSendCommand (5072-5223) **[C]**:

| Command | Meaning |
|---|---|
| `S to ...`, `SP to ...` | Personal |
| `SB to ...` | Bulletin (falls through to the same code). Refused with `*** Error: This system doesn't allow sending Bulls\r` (`RefuseBulls`) or `*** Error: You are not allowed to send Bulls\r` (user flag). |
| `ST to ...` | NTS traffic |
| `SR n` | Reply to n: to = original sender, title `Re:` + first 57 chars, skips the title prompt |
| `SC n to ...` | Copy n to someone: title `Fwd:` + first 56 chars, original appended after the new text as `\r\n\r\nOriginal Message:\r\n\r\n` + old body |
| `S` with any other second letter | `*** Error: Invalid Send option %c\r` |
| missing to | `*** Error: The 'TO' callsign is missing\r` |

### 9.2 Address syntax

DecodeSendParams (5316-5510) **[C]**:

```
SP G8BPQ
SP G8BPQ@GB7BPQ.#23.GBR.EURO
SP G8BPQ @ GB7BPQ.#23.GBR.EURO $MYBID01
SB ALL @ WW $BID123
SP G8BPQ!GB7BPQ                 (source route; becomes via)
SP G8BPQ;G4ABC@GB7XXX           (several addressees, separated by ';')
```

- `@` either joined (`call@bbs`) or as its own token (`@ bbs`). The via is uppercased and cut to 40 bytes.
- `$BID` is a separate token starting `$`. `< call` is refused for users: `*** < can only be used by a BBS\r`. Any other token: `*** Error: Invalid Format\r`.
- Joined `to@via` is treated as an internet email address (prefixed `rms:` or `smtp:` if those gateways exist) when the to part is longer than 6 characters, or the last element of via is not a continent, a known country code, `MARS`, `USA` or `WW` (`CheckifPacket`, lzhuf32.c:739-778). Keep categories to 6 characters, and when in doubt use the spaced `@ via` form, which skips this check **[C]**.
- To: SSID removed, uppercased, cut to **6** characters (so `SB WEATHER @ GBR` is stored as `WEATHE`). **[C]** (5694-5698)
- With no @ given, for a known local user with a home BBS the BBS adds it and says `Address @%s added from HomeBBS\r`; otherwise from White Pages: `Address @%s added from WP\r`; for users flagged for Winlink redirect, `Redirecting to winlink.org\r`. **[C]** (5458-5506)
- To `SYSOP` is always local. **[C]** Confirmed on the test BBS: `SP SYSOP` is accepted with no address note and lists as `SYSOP` with no `@` (recorded 2026-10-30 in `user-reports-to-sysop.jsonl`, #67). The app's Report sends there.

### 9.3 Dialogue

| Step | Server sends | Client sends | Ref |
|---|---|---|---|
| 1 | (any address notes above) then `Enter Title (only):\r` | Title line | 5743 |
| 1a | If the title line is empty: `*** Message Cancelled\r` then prompt. This is the **only** clean cancel. | | 5756-5760 |
| 2 | `Enter Message Text (end with /ex or ctrl/z)\r` | Body lines, no per-line response or echo | 5783 |
| 3 | | End marker (below) | 5798 |
| 4 | Possibly `*** Warning Message length exceeds sysop-defined maximum of %d - Message will be held\r` | | 6409 |
| 5 | `Message: %d Bid:  %s Size: %d\r` (two spaces after `Bid:`) | | 6493 |
| 6 | Possibly `@BBS specified, but no forwarding info is available - msg may not be delivered\r` or `Message is not for a local user, and no forwarding info is available - msg may not be delivered\r` | | 6501, 6507 |
| 7 | Prompt | | 6509-6510 |

Messages to an internal server (for example REQDIR, REQFIL) instead get `Message %d to Server Processed and Killed.\r` then the prompt. **[C]** (6426)

End of body **[C]** (5798, 6116-6140):

- A line that is exactly `/ex` (any case) followed by CR.
- A line consisting of Ctrl-Z (0x1A), up to 2 bytes plus CR.
- Any line containing Ctrl-Z: the Ctrl-Z becomes CR, the line is kept, and the message ends.

There is **no `/ABORT`** or other cancel during body entry. Dropping the connection discards the unfinished message (it is only created at the end marker) **[C]** (Disconnected, 11072-11232: no partial save for text mode).

If no BID is given, the BBS assigns `"%d_%s"` with the message number and BBS call, for example `1235_GB7RDG`. **[C]** (6214-6215)

### 9.4 Limits

| Field | Limit | Behaviour | Ref |
|---|---|---|---|
| Title | 59 bytes | Silently truncated | 5763-5765 |
| To | 6 chars | Silently truncated after SSID removal | 5697 |
| Via (@BBS) | 40 bytes | Silently truncated | 5704-5707 |
| From | 6 chars | Always the logged-in call | 5719-5721 |
| BID | 12 bytes | Silently truncated. Duplicate bulletin BID, or duplicate personal BID for the same `to` still at N/Y/H: `*** Error- Duplicate BID\r` (no space before the hyphen) | 5568-5630 |
| Body size | `MaxTXSize` (BBS config) | Accepted but held, with the warning above | 6403-6410 |
| Line length | No limit in BPQMail's text input (the buffer grows) **[I]**. Keep lines under 80 characters for other BBSs and terminals. | | 11258-11262 |
| Filters | Reject filters: `*** Error - Message Filters prevent sending this message\r` | | 5536 |

### 9.5 Lines the body must never contain

`ProcessLine` checks these **before** it checks for message entry, so they act even in the middle of a message body (case-insensitive prefixes) **[C]** (12589-12636):

| Body line starts with | Effect |
|---|---|
| `Already Connected` | Immediate disconnect, message lost |
| `Invalid Command` | Immediate disconnect, message lost |
| `*** Protocol Error` | Immediate disconnect, message lost |
| `POSYNCLOGON` / `POSYNCHELLO` | Session switches to sync mode |

Also a line equal to `/ex` ends the message early. A client should escape such lines, for example by prefixing a space. **[I]**

### 9.6 Held mail

If the user record has the hold flag (new users get it unless the sysop sets `DontHoldNewUsers`), every message they send is stored with status H. The confirmation still appears, but the user can no longer list or read it, and the sysop gets a notification. Other hold causes: bad words, hold filters, invalid From call, too large. **[C]** (5554-5559, 6330-6370, 6403-6407)

## 10. Kill

DoKillCommand (3619-3704), OkToKillMessage (3746-3760) **[C]**:

| Command | Behaviour |
|---|---|
| `K n [n ...]` | Kill each. Replies `Message #%d Killed\r`, `Message %d not found\r` (missing or already killed) or `Not your message\r` |
| `K` | Nothing, prompt |
| `KM` | Kill every **personal** message to me with status `Y`; one `Message #%d Killed\r` line each, nothing if none |
| `KH`, `K>`, `K<` | Sysop only; others get `*** Error: Invalid Kill option %c\r` |

Who may kill (non-sysop):

| Type | Allowed if |
|---|---|
| P | You are the sender or the addressee |
| B | You are the sender. You cannot kill other people's bulletins. |
| T | Anyone, unless the BBS sets `UserCantKillT` |

Killing sets status K; the message stays in the database until housekeeping. **[C]** (3482-3510)

## 11. White Pages and home BBS

| Command | Output | Ref |
|---|---|---|
| `I call` | One line per match: `"%s  %s %s %s %s\r"` = call, two spaces, home BBS (full hierarchical), name, postcode, QTH. Wildcards: `*X`, `X*`, `*X*`. No match: no lines. | WPRoutines.c:1240-1266 |
| `I@ bbs` | Same format, matching the first element of home BBS. Due to a missing `break`, it then also runs the `IH` search, so results may repeat. | WPRoutines.c:1268-1283 |
| `IH elem` | Match any hierarchical element (for example `GBR`) | WPRoutines.c:1285-1310 |
| `IZ zip` | Match postcode | WPRoutines.c:1312-1325 |
| `I` or `INFO` alone | The sysop's `info.txt`, or `SYSOP has not created an INFO file\r` | BBSUtilities.c:13059-13091 |
| Other `Ix arg` | `Invalid I command option %c\r` | WPRoutines.c:1327 |
| `HOMEBBS` | `HomeBBS is %s\r` | 13326-13342 |
| `HOMEBBS bbs` | Sets it (uppercased, 40 bytes); without a `.` also `Please enter HA with HomeBBS eg g8bpq.gbr.eu - this will help message routing\r` | same |
| `QTH text`, `ZIP code` | `QTH is %s\r` (60 bytes), `ZIP is %s\r` (8 bytes, uppercased) | 13145-13187 |

Empty fields print as empty strings, so a WP line may have extra spaces. **[C]**

## 12. Logging out

`B`/`BYE` **[C]** (12951-12963): sends `SignoffMsg` (default `"73 de %s\r"` with the BBS call, configurable, `$` codes expanded; BBSUtilities.c:10429-10430), waits 1 s, disconnects the BBS stream.

Then the node **[C]**:

- If the user entered the BBS with `BBS S`: `Returned to Node ALIAS:CALL\r` and back to node command level (L4Code.c:560-575).
- Otherwise the node session closes. On the FBB port no `*** Disconnected from Stream` line is sent (TelnetV6.c:2463-2467). Then, if the Telnet config has `DisconnectOnClose=1`, the socket closes after 1 s; otherwise the telnet layer sends `Disconnected from Node - Telnet Session kept\r\n` (note CRLF) and keeps the socket open (TelnetV6.c:2524-2533). The client should close the socket itself after seeing the sign-off. **[I]**

`NODE` sends the sign-off and returns to node level without disconnecting. **[C]** (12965-12977)

Idle timeout: the BBS sets the session idle time to 900 s (`USERIDLETIME`); the user can change it with `IDLETIME`. **[C]** (65, 10828)

## 13. Bytes on the wire

### 13.1 Line endings and character set

- **BBS to client on the FBB port: CR only.** BPQMail writes `\r` line ends, strips LF after CR in stored text and config texts, and the FBB-mode telnet path sends bytes unchanged (no CR to CRLF). **[C]** (TelnetV6.c:6792-6833; on the normal telnet port every CR becomes CRLF, 6834-6852). The one exception seen is the telnet layer's own `Disconnected from Node - Telnet Session kept\r\n`.
- **Client to BBS:** CR, LF or CRLF all work at the BBS (11399-11466). The node command parser before entering the BBS splits on CR (and `;`). Send CR. **[C]**
- **Character set: none.** The UTF-8 conversion in TelnetV6.c (6769-6789) only runs when `sockptr->UTF8` is set, which only the BPQTermTCP monitor control line does; it is reset to 0 on every new socket (3412). BPQMail stores and returns message bytes unchanged. **[C]** So message text is whatever the author's software sent: UTF-8 from modern clients, Latin-1, CP1252 or CP437 from older ones. Decode as UTF-8 when valid, otherwise fall back to CP1252 **[I]**. Send UTF-8 **[I]**.
- Length limits (title 59, name 17, QTH 60) are in **bytes**, so truncation can split a UTF-8 character. **[C]**
- NUL bytes in output texts are removed; a single NUL input line is ignored. **[C]**

### 13.2 Input lines with special meaning at command level

- A line starting `;` is ignored with no reply and **no prompt** (WL2K comment). **[C]** (12807-12850)
- A line of the form `[...]` is taken as a SID if the user record is a BBS, PMS or Winlink-client record, and new users get the Winlink-client flag automatically (10904-10906). This would switch the session into forwarding. Never send a line that starts with `[` and ends with `]`. **[C]** (12854-12890)
- A line starting `ARQ:FILE:` enters FLARQ mode. **[C]** (12774-12805)

## 14. Messages a client must recognise

| Text | When |
|---|---|
| `user:` / `password:` (configurable) | Login failure |
| `Too many attempts - Disconnected\r\n` | 5 login failures |
| `ALIAS:CALL} Connected to BBS\r` | Entered the BBS |
| `... Sorry, Application BBS is not running - Please try later\r` | BBS down |
| `... Sorry, All BBS Ports are in use - Please try later\r` | BBS busy |
| `[BPQ-...]` | SID, ignore |
| `Please enter your Name\r>\r` | New user |
| `Invalid Command\r` | Unknown command. The 5th in one session gives `Too many errors - closing\r` and a disconnect about 2 s later; the count never resets during a session. **[C]** (479-489, 12899-12905, 13437-13443) |
| `No New Messages\r` | `L` with nothing new |
| `Message %d not found\r` | Read or kill of a missing number |
| `Message %d not for you\r` | Read of a message you may not see |
| `Not your message\r` | Kill refused |
| `Message Number too high\r` | Number over 100000 |
| `*** Error: ...` / `*** Error- Duplicate BID\r` / `*** Error - ...` | Send refused (three different spellings in the source) |
| `*** Message Cancelled\r` | Empty title |
| `Message: %d Bid:  %s Size: %d\r` | Message stored |
| `<A>bort, <CR> Continue..>` | Output paging (no CR) |
| `<A>bort, <R Msg(s)>, <CR> = Continue..>` | Listing paused (no CR) |
| `\rOutput aborted\r` | After `A` |
| `73 de CALL\r` (configurable) | Sign-off |

## 15. Suggested client sequence

**[I]**, based on the above:

1. Connect, send `user\r`, `password\r`. Wait about 2 s. Any `user:`/`password:`-style reply means failure.
2. If no BBS output has arrived, send `BBS\r`. Wait for `Connected to`, then the SID and either the name prompt or the welcome plus prompt.
3. If the name prompt appears, send the identity's name.
4. Send `\r` and capture the prompt line.
5. `OP` to read the page length, then `OP 0`.
6. Work: `LM`/`LLP n` for personal mail, `LB n-m` or `LLB n` for bulletins, `R n`, `SP`/`SB`, `K n`.
7. Restore `OP n` if it was non-zero, `B`, close the socket.

## 16. Open questions for a live session

1. The exact SID and welcome text for an existing non-BBS user on GB7RDG (flag letters, any custom welcome or prompt with `$` codes).
2. Whether the node header on `Connected to BBS` is `ALIAS:CALL}` in practice, and whether anything arrives between it and the SID.
3. What the telnet layer does on the FBB port after `B` when `DisconnectOnClose` is off: does the socket stay usable for a second `BBS`?
4. The actual `MaxTXSize` on the target BBS, and whether a default applies when unset (the config loader returns 0, which taken literally would hold every message).
5. Whether reading a P message addressed to `CALL` from a session logged in as `CALL-n` marks it read (the code compares base calls, so it should).
6. How message bodies from other BBSs look in practice: R: line format and the character sets seen.
7. Whether `L` re-shows the last-listed message (the range is inclusive of the stored last-listed number, so it appears to).

## 17. Seen live on GB7RDG

Recorded 2026-10-28 on LinBPQ 6.0.26.1 over the FBB port, logged in as `tf` (SYSOP, expert mode on). The recordings are in `packages/mail_core/test/fixtures/bpq-fbb/`. These answer some of the open questions above.

- **Login** is silent, as the source says: nothing at all comes back for the username or password.
- **Entering the BBS** gives `READNG:GB7RDG} Connected to BBS\r`, then `[BPQ-6.0.26.1-IHJM$]\rde GB7RDG>\r`. With expert mode on there is no welcome text between the SID and the prompt. (Open questions 1 and 2.)
- **After `B`** the BBS sends `73 de GB7RDG\r` then `Disconnected from Node - Telnet Session kept\r\n` and the socket stays open at the node. `NODE` gives `73 de GB7RDG\r` then `Returned to Node READNG:GB7RDG\r`. The client should close the socket itself. (Open question 3.)
- **No paging** was seen: a listing of about 75 lines came in one go for this user.
- **Prefix matching bites:** `XYZZY` was taken as `X` and toggled expert mode (`Expert Mode off`, then `Expert Mode` when toggled back). The client must never send free text at the prompt, and must never send `X`.
- **Listing line**, for example `4485   28-Oct PN    1279 M0LTE  @GB7RDG G4APL  Re: CIP access`. As SYSOP, `LN` and `LL` include SYSOP mail and killed messages (status `K`).
- **Read header**: `From:`, `To:`, `Type/Status:` (the status before this read), `Date/Time: 28-Oct 05:20Z`, `Bid:`, `Title:`, a blank line, then `R:` routing lines. Mail that came through an internet gateway also has `T:From:`, `T:To:` and `T:Message-Id:` lines. Some messages have a `Body: <size>` line before the `R:` lines. The message ends `[End of Message #4485 from G4APL]\r` and then the prompt.
- **Reading marks read:** unread personal 4485 went from `PN` to `PY` in `LM` after `R 4485`.
- **Not found:** `Message 99999 not found\r`.
- **White Pages:** `I G8BPQ` gives `G8BPQ  GB7BPQ.#76.GBR.EU   \r`. `HOMEBBS` with none set gives `HomeBBS is \r`.
- **Send to a bare callsign** fills in the address from White Pages: `SP M0LTE` gave `Address @M9YYY.#42.GBR.EURO added from WP\r` (a stale entry), then `Enter Title (only):\r`, then `Enter Message Text (end with /ex or ctrl/z)\r`. After `/EX`: `Message: 4491 Bid:  4491_GB7RDG Size: 99\r` (note the two spaces after `Bid:`). The client should look the address up itself and send the full address, so a stale WP entry is visible to the user before sending.
- **Kill:** `Message #4491 Killed\r`; a second kill gives `Message 4491 not found\r`.

## 18. Seen on a local test BBS as normal users

Recorded 2026-10-28 with `test-bbs/record-all.sh` against Tom's `m0lte/linbpq:6.0.26.1` image; fixtures in `packages/mail_core/test/fixtures/bpq-local/`.

- **First login** asks `Please enter your Name\r>\r`; the reply is taken as the name whatever it is (a command sent here becomes the name). Then `Hello <name>. Latest Message is N, Last listed is M\r`, a nudge to set a home BBS, and the prompt. The client must handle the name prompt before sending any command.
- **New-user mail is held by default.** With `DontHoldNewUsers = 0` a new user's messages get a normal `Message: N` confirmation but status H, so nobody else sees them and the sender can't list them. The app should tell the user, once, when their sent mail never appears for anyone.
- **The BBS's own notices use message numbers**: each new user creates a notice to the sysop, so numbers are not predictable from what a user can see.
- **`LM` lists mail to me only**, not mail I sent. `L` lists new mail including what I sent.
- **`L< CALL` lists mail from CALL**, personal and bulletins, newest first, with their status letters (a personal message to a local user stays `PN` until read). The space matters: `L<CALL` lists nothing. Any user can list anyone's, but personal mail only shows to its sender or addressee. The sender can read their own message with `R n`, which does not change its status. The app's Sent uses this, merged with its own copies.
- **Reading a bulletin changes nothing on the BBS**: it stays `BN` and stays in `LN`. Bulletin read state is the app's own.
- **Kill rights**: the recipient can kill personal mail; the author can kill their own bulletin; anyone else gets `Not your message\r`. After a kill, `R n` gives `Message n not for you\r` to a normal user (not "not found").
- **Bare callsign**: `SP Q0OTH` gave `Address @Q0TST.#42.GBR.EURO added from HomeBBS\r` (compare `added from WP` on GB7RDG).
- **Cancel**: an empty title gives `*** Message Cancelled\r`.
- **Bulletin to an area with no forwarding** adds `@BBS specified, but no forwarding info is available - msg may not be delivered\r` after the confirmation.
- **Read output** ends with a blank line or two, then `[End of Message #N from CALL]\r`, then the prompt. Locally written messages have no `R:` lines.
- **Telnet port** differs only at the start: telnet negotiation bytes (IAC WILL SUPPRESS-GO-AHEAD, IAC WILL ECHO), `user:` and `password:` prompts with no line end, `\r\nConnected to Q0TST's Telnet Server\r\n\r\n`, and CRLF line ends throughout. The FBB port uses CR only.
