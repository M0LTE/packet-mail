# XRouter mailbox (PMS) user protocol reference

How a client talks to the mailbox built into XRouter (G8PZT's packet node) as an ordinary user, over the node's telnet port. Everything marked **[S]** was seen in sessions recorded against XRouter 505p in `test-bbs/xrouter` (recordings in `packages/mail_core/test/fixtures/xrouter-local/` and `xrouter-driver/`). Everything marked **[D]** comes from XRouter's own documentation as shipped in the container image (`HELP/PMS/*.HLP`, `MAN/PMS*.MAN`, `MAN/USERPASS.SYS.MAN`, `ACCESS.SYS`) and was not tried.

Strings are quoted as sent, with `\r\n` for CR LF.

## 1. What it is

XRouter calls it the PMS (Personal Message System). It is more than the name suggests: a "mini-BBS" with private mail, bulletins, White Pages, hierarchical addresses and MBL forwarding to and from full BBSes **[D]** (`MAN PMS(9)`). In its default mode (`PMSTYPE=1`) it only forwards by being polled (reverse forwarding) **[D]**. Mode 4 makes it a full BBS reached with the `BBS` node command **[D]**, see 9.4.

For Packet Mail's purposes it has everything the LinBPQ driver uses: personal mail, bulletins, kill, mail from us (`L<`) and a White Pages lookup (`I call`). What it lacks is listed in section 8.

## 2. Telnet login

| Step | What happens | |
|---|---|---|
| Connect | `\r\nXrouter v505p\r\n\r\nCallsign: ` (no CR after the prompt). No telnet negotiation. | [S] |
| Send callsign | `Q0USR\r`, case-insensitive (`q0usr` worked). | [S] |
| Not a callsign | `NOTACALL` or `NOCALL`: the node closes the connection without a word. | [S] |
| Password wanted | `\r\nPassword: ` (no CR after it). | [S] |
| No password wanted | No prompt: straight to the welcome. | [S] |
| Bad password, or a callsign with no password set | `\r\nBad password!\r\n`, then the node closes. | [S] |
| Good password | The node's CTEXT, if any, else `Type ? for list of commands\r\n...`, and possibly `You have 30 unread messages in PMS\r\n`. | [S] |

Whether a password is asked for depends on the caller's IP address, from `ACCESS.SYS`: flag 1 callsign only, 2 password required, 4 guest (password `guest`, read-only) **[D]**. The shipped sample asks only Internet callers for a password. Passwords live in `USERPASS.SYS` as `CALL password`, callsign without SSID, no spaces, not case-sensitive **[D]**. The login name has to be a callsign.

**The node has no prompt.** After a good password the welcome is free text with no end marker, so there is nothing to wait for. The driver sends `PMS\r` straight after the password (or the callsign, when no password is asked for). After a bad password the node has already hung up and the line goes nowhere **[S]**.

## 3. Entering the mailbox

`PMS\r` at the node gives **[S]**:

```
\r\nQ0XR:XRTEST} Connected to PMS\r\n
[XR-505p-BFHM$]\r\n
Welcome to Q0XR's PMS\r\n
You have 0 new messages\r\n
Please use the 'NH' command to set your 'home' BBS.\r\n
\r\n
[0] B,H,I,J,K,KM,L,LM,LN,M,N,R,SB,SP,SR,U,? >\r\n
```

- The `[XR-...]` line is the mailbox's SID. A client must not answer it with a SID of its own (that would make it a forwarding partner) **[D]**.
- There is no name prompt for new users; the name is set with `N name` if wanted **[S]**.
- The node header `ALIAS:CALL} ` begins every node reply **[S]**.
- If the sysop has defined a command alias or application called `PMS`, it takes the place of the mailbox **[D]**. The driver checks for `Connected to PMS` before going on.

## 4. The prompt and line endings

- Every line ends CR LF **[S]**. The driver reads through the same filter as a BPQ telnet port, so it sees CR alone.
- The prompt is `[n] B,H,I,J,K,KM,L,LM,LN,M,N,R,SB,SP,SR,U,? >\r\n`, where `n` is the last message read (0 after a kill) **[S]**. The command list may differ for a sysop **[D]**. The driver matches `[digits] ...>` at the start of a line.
- Commands are case-insensitive and nothing is echoed **[S]**.
- Paging is on by default, 25 lines per page, and is stored per user **[S]**. `NP 0\r` turns it off (`Pagination is OFF`); the driver sends it at every login.
- Even with paging off, listings repeat their column headings every 20 or so lines **[S]**.

## 5. Listing

| Command | Lists | |
|---|---|---|
| `LM` | All mail addressed to you, read or not | [S] |
| `LN` | Unread mail addressed to you (status N only, so not `$` mail addressed to you) | [S] |
| `LB [n]` | Bulletins, newest first, at most n, **default 25** | [S] |
| `L< call` | Mail from a callsign; private mail shown only to its sender or addressee | [S] |
| `M` | Mail you sent | [S] |
| `L` | Mail since you last used `L` (everything, the first time) | [S][D] |

Other `L` variants (`L>`, `L@`, `LL n`, `LS text`, ...) are in `H L` **[D]**. The driver uses `LM`, `LB 99999` and `L< CALL`.

An empty listing is `No messages found\r\n` **[S]**. Otherwise **[S]**:

```
 Msg# TS Rcvd  Size  To      At     From   Subject
    1 PN 07:49  311  Q0OTH          Q0USR  Hello from user
    2 P$ 07:50  297  Q0OTH  @GB7XYZ Q0USR  For another BBS
    3 B$ 07:50  286  ALL    @GBR    Q0USR  Test bulletin
    5 BN 14/10  205  WX             Q0OTH  Local bull
```

- **TS**: type (P private, B bulletin, T traffic) and status. Statuses seen: `N` unread, `R` read, `$` waiting to be forwarded. Documented also: `F` forwarded, `H` held, and a space for unread local mail **[D]** (a space was never seen; unread local mail showed `N`).
- **Rcvd**: `hh:mm` for today, `dd/mm` for earlier days, no year **[S]**. It is the node's local time. The driver puts a time on the day that brings it closest to the phone's clock, and gives a day the most recent year that doesn't put it in the future.
- **At**: blank for local mail, else `@` and only the first part of the address **[S]**.
- **Subject is cut to 34 characters** **[S]**. Reading the message gives the whole subject (up to 60).

## 6. Reading

`R n` (or just `n`) reads without routing lines; `RH n` shows them **[S]**. Several numbers may be given **[D]**. The driver uses `RH`:

```
Msg#: 2  Type: P$  Size: 297\r\n
Rcvd: 29/10/26 at 07:50   Created: 29/10/26 at 07:50Z\r\n
From: Q0USR\r\n
To:   Q0OTH @ GB7XYZ.#42.GBR.EURO\r\n
MID:  AE2FAAE020XR\r\n
Subj: For another BBS\r\n
\r\n
R:261029/0750Z @:Q0XR.#42.GBR.EURO [] #:2 XrLin505p\r\n
Date: Thu, 29 Oct 2026 07:50:06 +0000\r\n
From: q0usr@q0xr.#42.gbr.euro <q0usr@q0xr-2.#42.gbr.euro>\r\n
To: q0oth@gb7xyz.#42.gbr.euro\r\n
Subject: For another BBS\r\n
Message-ID: <AE2FAAE020XR>\r\n
\r\n
Body.\r\n
\r\n
[ end of message 2 ]\r\n
\r\n
[2] B,H,...,? >\r\n
```

- Bulletins have `BID:` where private mail has `MID:` **[S]**.
- Dates carry a two-digit year. `Created` is UTC (`Z`); `Rcvd` is the node's local time **[S]**. The driver uses `Rcvd`, as listings do.
- Mail written on an XRouter carries an RFC 822 style block (Date, From, To, Subject, Message-ID) and a blank line after its R: line **[S]**. `R` hides it, leaving a blank line; the driver drops it from `RH` output. A body line such as `Date: next Tuesday` is kept unless it starts a whole block ending in `Message-ID`.
- Reading your own mail to someone else leaves it unread for them **[S]**. Reading mail addressed to you marks it `R` **[S]**; `U n` marks it unread again **[S]**.
- Not there: `Msg 99 not found` **[S]**. Someone else's private mail: `Access to message 80 denied` **[S]**.

## 7. Sending

`SP call [@ address]`, `SB category [@ area]`. The dialogue **[S]**:

```
> SP Q0OTH @ GB7XYZ.#42.GBR.EURO
To: Q0OTH @ GB7XYZ.#42.GBR.EURO\r\n
Enter subject (or empty line to abort):\r\n
> For another BBS
\r\nEnter message, ending ctrl-Z or /EX (/QQ to abort)\r\n
> Body.
> /EX
\r\n*** Message 2 saved\r\n\r\n[0] ...? >\r\n
```

- The `To:` line shows the address the mailbox will use. `SP Q0OTH` alone, or with this mailbox's own address, becomes `Q0OTH @ Q0XR` **[S]**. White Pages fills in an incomplete address **[D]**.
- An empty subject gives `Operation aborted` and the prompt **[S]**. The number it would have had is used up **[S]**.
- Subjects are stored up to 60 characters; longer ones are cut **[S]**.
- Body lines are stored as sent, any length (300 characters went through) **[S]**. 8-bit bytes come back unchanged **[S]**.
- A line that is exactly `/EX` or `/ex` ends the message; exactly `/QQ` (any case) abandons it; ctrl-Z ends it **[S]**. `/EX  ` with trailing spaces, `  /ex`, `/exit`, `/QQ ` are plain text **[S]**. The driver gives `/ex` and `/qq` lines a leading space whatever their spacing, and turns control characters into spaces.
- Lines starting `R:`, `SP ...`, or looking like the prompt are plain text in a body **[S]**.
- Nothing is validated: `SP NOTACALL` became `NOTACA`, `SB TOOLONGCAT` became `TOOLON`, and any `@` text is taken **[S]**. The driver checks callsigns, categories (1 to 6 letters or digits) and addresses before sending.
- The size the mailbox reports includes the headers it adds **[S]**.

## 8. Killing, White Pages and leaving

- `K n`: `Msg 1 deleted`, `Msg 1 not found`, or `Permission denied` **[S]**. You may kill mail you sent or that is addressed to you **[D][S]**: an addressee killed `$` mail to them, a sender killed their own bulletin, a non-sender could not kill a bulletin.
- `KM` kills your read mail **[S]**.
- `I call` **[S]**:
  - known with a home BBS: `\r\nQ0XR last seen on 29/10/26 at Q0XR.#42.GBR.EURO\r\nName: ?   QTH: ?   Zip: ?   Src: U\r\n`
  - known without one: `... at ?`
  - unknown: `\r\nNo packet address for G8PZT\r\n`
  - wildcards (`I Q0*`) list several, one per line **[S]**; the driver only sends checked callsigns.
- `NH call` sets your home BBS, but only accepts one the mailbox can verify from its White Pages **[S]**.
- `B` leaves the mailbox (`  - Logged off`, then `Q0XR:XRTEST} Welcome back`); `B` again at the node ends the session (`Q0XR:XRTEST} Goodbye`, then close) **[S]**.

## 9. Gotchas

1. **Never send `$` with a send command.** `SP Q0OTH $BID123` gets `NO - Protocol violation (no SID)` and throws the session out of the mailbox to the node **[S]**. Everything typed after that is a node command (`L` lists AX.25 links, `X` tries SLIP or PPP, `B` hangs up) **[S]**. So the mailbox takes no BID or MID from a user, and **cannot refuse a second copy** of a message. The driver ignores the ID the app offers; the sync engine, for a send it isn't sure about, looks for the copy in `L<` before sending again (matching addressee and the start of the subject), and never retries at once.
2. **The node has no prompt.** See section 2.
3. **Listings cut subjects to 34 characters**, so a listed subject may be the start of the stored one.
4. **Mode 4.** With `PMSTYPE=4` the mailbox is a full BBS reached with `BBS`; through `PMS` it shows only personal mail (`LB` lists nothing) **[S]**. The driver always uses `PMS`, because on other nodes `BBS` is often an alias that connects somewhere else, so on a mode 4 node the app shows no bulletins.
5. **Message numbers may change.** Housekeeping can renumber the whole message base when `AutoRenumber` is set in `PMS.CFG` **[D]**. The sync engine already treats a number with a different sender, addressee or subject as a new message.
6. **Languages.** XRouter has language files (`LANGS.SYS`, French, Spanish, Dutch) and a per-user `LANG` command **[D]**. The driver expects English replies.
7. **Sysops** see and can kill everything, and their prompt lists more commands **[D]**. Use an ordinary account.
8. **Other ways in.** AX.25 to `PMSCALL`, NetRom to `PMSALIAS`, NetRomX service 2, an HTTP interface and REST and MQTT interfaces exist **[D]**; only telnet is used here.

## 10. The test XRouter

`test-bbs/xrouter/run.sh` starts `ghcr.io/packethacking/xrouter:505p-amd64` with a loopback-only config, node `Q0XR`, mailbox `Q0XR-2` at `.#42.GBR.EURO`, telnet on `127.0.0.1:18023`, passwords required from every address, users `Q0USR` (password `user`) and `Q0OTH` (`other`). XRouter refuses to start without a `LOCATOR` and at least one interface, hence the loopback port. `record-all.sh` records the scenarios in `fixtures/xrouter-local/`.
