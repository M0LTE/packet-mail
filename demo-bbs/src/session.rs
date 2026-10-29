//! One visitor's session: the FBB-port login, then the BPQMail user commands
//! Packet Mail uses, answered with BPQ's exact strings (docs/bpq-protocol.md).
//!
//! Pure and synchronous: a line goes in, bytes come out. All state lives in
//! the session, so nothing one visitor does can reach another.

use crate::dates::{day_month, day_month_time};
use crate::mail::{Mailbox, Message, WpEntry, BBS_CALL, BBS_HOME};
use crate::seed::{seed, ROBOT_CALL, USER_CALL};

pub const LOGIN_USER: &[u8] = b"demo";
pub const LOGIN_PASSWORD: &[u8] = b"demo";

const NODE_HEADER: &str = "DEMO:Q0DEMO} ";
const SID: &str = "[BPQ-6.0.26.1-B2FWIHJM$]\r";
const PROMPT: &[u8] = b"de Q0DEMO>\r";
const SIGNOFF: &str = "73 de Q0DEMO\r";
/// BPQ discards login lines longer than this.
const MAX_LOGIN_LINE: usize = 256;
const MAX_LOGIN_FAILURES: u32 = 5;
const MAX_COMMAND_ERRORS: u32 = 5;
/// BPQ's highest message number for listing arguments.
const MAX_NUMBER: u64 = 100_000;
const MAX_TITLE: usize = 59;
const MAX_NAME: usize = 17;
const MAX_BID: usize = 12;
const MAX_VIA: usize = 40;
const ROBOT_QUOTE_LINES: usize = 20;
/// Message numbers one R or K command may name, to bound one reply's size.
const MAX_NUMBERS_PER_COMMAND: usize = 20;

#[derive(Clone, Debug)]
pub struct SessionLimits {
    /// Largest message body a visitor may send, in bytes as stored.
    pub max_message_bytes: usize,
    /// Messages a visitor may send in one session.
    pub max_messages: usize,
}

impl Default for SessionLimits {
    fn default() -> Self {
        SessionLimits {
            max_message_bytes: 16 * 1024,
            max_messages: 20,
        }
    }
}

/// What to send back for one line.
#[derive(Debug, Default)]
pub struct Reply {
    pub out: Vec<u8>,
    /// Close the connection after sending `out`.
    pub close: bool,
    /// A limit was hit; worth one log line.
    pub limit: Option<&'static str>,
}

impl Reply {
    fn say(&mut self, s: &str) {
        self.out.extend_from_slice(s.as_bytes());
    }
}

struct Draft {
    kind: u8,
    to: String,
    via: String,
    bid: String,
    title: Vec<u8>,
    body: Vec<u8>,
    too_big: bool,
}

enum State {
    User,
    Password,
    Node,
    Name,
    Command,
    Title(Draft),
    Body(Draft),
    Closed,
}

pub struct Session {
    state: State,
    login_failures: u32,
    errors: u32,
    mail: Mailbox,
    name: Vec<u8>,
    home: String,
    last_listed: i64,
    sent: usize,
    limits: SessionLimits,
}

impl Session {
    pub fn new(now: i64, limits: SessionLimits) -> Self {
        let mail = seed(now);
        // A new BPQ user's "last listed" starts 20 behind the latest message.
        let last_listed = mail.latest() as i64 - 20;
        Session {
            state: State::User,
            login_failures: 0,
            errors: 0,
            mail,
            name: Vec::new(),
            home: BBS_HOME.into(),
            last_listed,
            sent: 0,
            limits,
        }
    }

    /// True once the visitor has logged in and entered the BBS.
    pub fn in_bbs(&self) -> bool {
        matches!(
            self.state,
            State::Name | State::Command | State::Title(_) | State::Body(_)
        )
    }

    pub fn is_closed(&self) -> bool {
        matches!(self.state, State::Closed)
    }

    /// Handles one input line (without its line end). `now` is Unix seconds.
    pub fn handle(&mut self, line: &[u8], now: i64) -> Reply {
        let mut r = Reply::default();
        let state = std::mem::replace(&mut self.state, State::Closed);
        self.state = match state {
            State::User => self.on_user(line, &mut r),
            State::Password => self.on_password(line, &mut r),
            State::Node => self.on_node(line, &mut r),
            State::Name => self.on_name(line, &mut r),
            State::Command => self.on_command(line, &mut r),
            State::Title(d) => self.on_title(line, d, &mut r),
            State::Body(d) => self.on_body(line, d, now, &mut r),
            State::Closed => State::Closed,
        };
        r.close |= self.is_closed();
        r
    }

    // Login, as LinBPQ's FBB port: nothing is ever prompted unless it fails.

    fn login_failed(&mut self, r: &mut Reply, again: State, prompt: &[u8]) -> State {
        self.login_failures += 1;
        if self.login_failures >= MAX_LOGIN_FAILURES {
            r.say("Too many attempts - Disconnected\r\n");
            r.limit = Some("login attempts");
            return State::Closed;
        }
        r.out.extend_from_slice(prompt);
        again
    }

    fn on_user(&mut self, line: &[u8], r: &mut Reply) -> State {
        if line.is_empty() || line == [0] || line.len() > MAX_LOGIN_LINE {
            return State::User;
        }
        if line == LOGIN_USER {
            return State::Password;
        }
        self.login_failed(r, State::User, b"user:")
    }

    fn on_password(&mut self, line: &[u8], r: &mut Reply) -> State {
        if line.is_empty() || line == [0] || line.len() > MAX_LOGIN_LINE {
            return State::Password;
        }
        if line == LOGIN_PASSWORD {
            return State::Node;
        }
        self.login_failed(r, State::Password, b"password:")
    }

    /// Node command level: only `BBS` does anything.
    fn on_node(&mut self, line: &[u8], r: &mut Reply) -> State {
        if line.len() > 100 {
            return State::Node;
        }
        let text = String::from_utf8_lossy(line).to_ascii_uppercase();
        let cmd = text.split(';').next().unwrap_or("").trim();
        let word = cmd.split_whitespace().next().unwrap_or("");
        match word {
            "" => State::Node,
            "BBS" => {
                r.say(NODE_HEADER);
                r.say("Connected to BBS\r");
                r.say(SID);
                if self.name.is_empty() {
                    r.say("Please enter your Name\r>\r");
                    State::Name
                } else {
                    self.welcome(r);
                    State::Command
                }
            }
            "B" | "BYE" => State::Closed,
            _ => {
                r.say(NODE_HEADER);
                r.say("Invalid command - Enter ? for command list\r");
                State::Node
            }
        }
    }

    fn on_name(&mut self, line: &[u8], r: &mut Reply) -> State {
        self.name = clean(line);
        self.name.truncate(MAX_NAME);
        self.welcome(r);
        State::Command
    }

    fn welcome(&self, r: &mut Reply) {
        r.out.extend_from_slice(b"Hello ");
        r.out.extend_from_slice(&self.name);
        r.say(&format!(
            ". Latest Message is {}, Last listed is {}\r",
            self.mail.latest(),
            self.last_listed
        ));
        if self.home.is_empty() {
            r.say("Please enter your Home BBS using the Home command.\rYou may also enter your QTH and ZIP/Postcode using qth and zip commands.\r");
        }
        r.out.extend_from_slice(PROMPT);
    }

    // Command level.

    fn on_command(&mut self, line: &[u8], r: &mut Reply) -> State {
        if line == [0] || line.first() == Some(&b';') {
            return State::Command;
        }
        if session_killer(line) {
            return State::Closed;
        }
        let text = String::from_utf8_lossy(line).into_owned();
        let toks: Vec<&str> = text.split([' ', '\t']).filter(|t| !t.is_empty()).collect();
        let Some(first) = toks.first() else {
            r.out.extend_from_slice(PROMPT);
            return State::Command;
        };
        let word = first.to_ascii_uppercase();
        let args = &toks[1..];
        let w = word.as_str();

        if w.starts_with('L') && !w.starts_with("LIS") {
            let out = self.list(w, args);
            r.out.extend_from_slice(&out);
        } else if matches!(w, "B" | "BY" | "BYE") {
            r.say(SIGNOFF);
            return State::Closed;
        } else if w == "NODE" {
            r.say(SIGNOFF);
            r.say(&format!(
                "Returned to Node {}\r",
                NODE_HEADER.trim_end().trim_end_matches('}')
            ));
            return State::Node;
        } else if w.starts_with('K') {
            self.kill(w, args, r);
        } else if w.starts_with('I') {
            self.info(w, args, r);
        } else if matches!(w, "H" | "HE" | "HEL" | "HELP" | "?") {
            r.say(HELP);
        } else if w.len() >= 2 && "HOMEBBS".starts_with(w) {
            self.home_bbs(args, r);
        } else if w.starts_with("OP") && args.first().is_none_or(|a| *a == "0") {
            // Paging is always off here, so there is nothing to change.
            r.say("Page Length is 0\r");
        } else if w.starts_with('R') {
            self.read(w, args, r);
        } else if w.starts_with('S') {
            return self.send(w, args, r);
        } else {
            // Unknown or unsupported: never acted on.
            self.errors += 1;
            r.say("Invalid Command\r");
            if self.errors >= MAX_COMMAND_ERRORS {
                r.say("Too many errors - closing\r");
                r.limit = Some("command errors");
                return State::Closed;
            }
        }
        r.out.extend_from_slice(PROMPT);
        State::Command
    }

    fn me(&self) -> &str {
        USER_CALL
    }

    fn visible(&self, m: &Message) -> bool {
        m.status != b'K'
            && m.status != b'H'
            && (m.kind != b'P' || m.to == self.me() || m.from == self.me())
    }

    // L: listing. docs/bpq-protocol.md section 7.

    fn list(&mut self, word: &str, args: &[&str]) -> Vec<u8> {
        if word == "LC" {
            return Vec::new();
        }
        let (mut oldest_first, mut last_n, mut to_me) = (false, false, false);
        let (mut kind, mut status) = (None, None);
        let (mut want_from, mut want_to, mut want_at) = (false, false, false);
        let mut plain = true;
        for c in word.chars().skip(1) {
            match c {
                'R' => oldest_first = true,
                'P' | 'B' | 'T' => kind = kind.or(Some(c as u8)),
                'N' | 'Y' | 'F' | '$' | 'D' => status = status.or(Some(c as u8)),
                'H' | 'K' => return b"LH or LK can only be used by SYSOP\r".to_vec(),
                '<' => want_from = true,
                '>' => want_to = true,
                '@' => want_at = true,
                'M' => to_me = true,
                'L' => last_n = true,
                _ => {}
            }
            if c != 'R' {
                plain = false;
            }
        }
        let mut args = args.iter();
        let mut take_call = |wanted: bool| -> Result<Option<String>, ()> {
            if !wanted {
                return Ok(None);
            }
            args.next().map(|a| Some(a.to_ascii_uppercase())).ok_or(())
        };
        let (Ok(from), Ok(to), Ok(at)) =
            (take_call(want_from), take_call(want_to), take_call(want_at))
        else {
            return Vec::new();
        };

        let latest = self.mail.latest() as u64;
        let (mut lo, mut hi, mut count) = (1u64, latest, None);
        if last_n {
            count = args.next().map(|a| atoi(a) as usize);
        } else if let Some(a) = args.next() {
            plain = false;
            if let Some((x, y)) = a.split_once('-') {
                lo = atoi(x);
                hi = if y.is_empty() { latest } else { atoi(y) };
            } else {
                lo = atoi(a);
                hi = args.next().map_or(lo, |b| atoi(b));
            }
            if lo > MAX_NUMBER || hi > MAX_NUMBER {
                return b"Message Number too high\r".to_vec();
            }
        }
        if plain {
            lo = (self.last_listed + 1).max(1) as u64;
        }

        let mut found: Vec<&Message> = self
            .mail
            .messages
            .iter()
            .filter(|m| (lo..=hi).contains(&(m.number as u64)) && self.visible(m))
            .filter(|m| kind.is_none_or(|k| m.kind == k))
            .filter(|m| status.is_none_or(|s| m.status == s))
            .filter(|m| from.as_ref().is_none_or(|f| &m.from == f))
            .filter(|m| to.as_ref().is_none_or(|t| &m.to == t))
            .filter(|m| at.as_ref().is_none_or(|a| m.via.starts_with(a.as_str())))
            .filter(|m| !to_me || m.to == self.me())
            .collect();
        found.sort_by_key(|m| std::cmp::Reverse(m.number));
        if let Some(n) = count {
            found.truncate(n);
        }
        if oldest_first {
            found.reverse();
        }

        let mut out = Vec::new();
        for m in &found {
            out.extend_from_slice(&listing_line(m));
        }
        if plain {
            if found.is_empty() {
                out.extend_from_slice(b"No New Messages\r");
            }
            self.last_listed = latest as i64;
        }
        out
    }

    // R: reading. Section 8.

    fn read(&mut self, word: &str, args: &[&str], r: &mut Reply) {
        if word == "R" {
            for a in args.iter().take(MAX_NUMBERS_PER_COMMAND) {
                self.read_one(atoi(a), r);
            }
        } else if word.starts_with("RM") {
            let mut numbers: Vec<u32> = self
                .mail
                .messages
                .iter()
                .filter(|m| m.to == self.me() && m.status == b'N' && self.visible(m))
                .map(|m| m.number)
                .collect();
            if word != "RMR" {
                numbers.reverse();
            }
            for n in numbers {
                self.read_one(n as u64, r);
            }
        } else {
            r.say(&format!(
                "*** Error: Invalid Read option {}\r",
                second_char(word)
            ));
        }
    }

    fn read_one(&mut self, number: u64, r: &mut Reply) {
        let me = self.me().to_string();
        let Some(m) = u32::try_from(number).ok().and_then(|n| self.mail.get(n)) else {
            r.say(&format!("Message {} not found\r", number));
            return;
        };
        if !self.visible(m) {
            r.say(&format!("Message {} not for you\r", number));
            return;
        }
        r.say(&format!(
            "From: {}\rTo: {}\rType/Status: {}{}\rDate/Time: {}\rBid: {}\rTitle: ",
            m.from,
            m.to,
            m.kind as char,
            m.status as char,
            day_month_time(m.date),
            m.bid
        ));
        r.out.extend_from_slice(&m.title);
        r.say("\r\r");
        r.out.extend_from_slice(&crlf_to_cr(&m.body));
        r.say(&format!(
            "\r\r[End of Message #{} from {}]\r",
            m.number, m.from
        ));
        let n = m.number;
        if let Some(m) = self.mail.get_mut(n) {
            if m.to == me && !matches!(m.status, b'K' | b'H' | b'F' | b'D') {
                m.status = b'Y';
            }
        }
    }

    // K: kill. Section 10.

    fn kill(&mut self, word: &str, args: &[&str], r: &mut Reply) {
        let me = self.me().to_string();
        match word {
            "K" => {
                for a in args.iter().take(MAX_NUMBERS_PER_COMMAND) {
                    let n = atoi(a);
                    let m = u32::try_from(n).ok().and_then(|n| self.mail.get_mut(n));
                    match m {
                        None => r.say(&format!("Message {} not found\r", n)),
                        Some(m) if m.status == b'K' => r.say(&format!("Message {} not found\r", n)),
                        Some(m) => {
                            let allowed = match m.kind {
                                b'P' => m.from == me || m.to == me,
                                b'B' => m.from == me,
                                _ => true,
                            };
                            if allowed {
                                m.status = b'K';
                                r.say(&format!("Message #{} Killed\r", n));
                            } else {
                                r.say("Not your message\r");
                            }
                        }
                    }
                }
            }
            "KM" => {
                for m in self.mail.messages.iter_mut() {
                    if m.kind == b'P' && m.to == me && m.status == b'Y' {
                        m.status = b'K';
                        r.say(&format!("Message #{} Killed\r", m.number));
                    }
                }
            }
            _ => r.say(&format!(
                "*** Error: Invalid Kill option {}\r",
                second_char(word)
            )),
        }
    }

    // I: info and White Pages. Section 11.

    fn info(&mut self, word: &str, args: &[&str], r: &mut Reply) {
        let Some(arg) = args.first() else {
            if word == "I" || word == "INFO" {
                r.say(INFO);
            } else {
                r.say(&format!("Invalid I command option {}\r", second_char(word)));
            }
            return;
        };
        let pattern = arg.to_ascii_uppercase();
        let mut entries = vec![WpEntry {
            call: self.me().to_string(),
            home: self.home.clone(),
            name: String::from_utf8_lossy(&self.name).into_owned(),
            zip: String::new(),
            qth: String::new(),
            local: true,
        }];
        entries.extend(self.mail.wp.iter().cloned());
        let matches: fn(&WpEntry, &str) -> bool = match word {
            "I" => |e, p| wild(&e.call, p),
            "I@" => |e, p| wild(e.home.split('.').next().unwrap_or(""), p),
            "IH" => |e, p| e.home.split('.').any(|el| wild(el, p)),
            "IZ" => |e, p| wild(&e.zip, p),
            _ => {
                r.say(&format!("Invalid I command option {}\r", second_char(word)));
                return;
            }
        };
        for e in entries.iter().filter(|e| matches(e, &pattern)) {
            r.say(&format!(
                "{}  {} {} {} {}\r",
                e.call, e.home, e.name, e.zip, e.qth
            ));
        }
    }

    fn home_bbs(&mut self, args: &[&str], r: &mut Reply) {
        if let Some(a) = args.first() {
            self.home = a
                .to_ascii_uppercase()
                .chars()
                .filter(|c| c.is_ascii_graphic())
                .take(MAX_VIA)
                .collect();
        }
        r.say(&format!("HomeBBS is {}\r", self.home));
        if !args.is_empty() && !self.home.contains('.') {
            r.say(
                "Please enter HA with HomeBBS eg g8bpq.gbr.eu - this will help message routing\r",
            );
        }
    }

    // S: sending. Section 9.

    fn send(&mut self, word: &str, args: &[&str], r: &mut Reply) -> State {
        let refuse = |r: &mut Reply, s: &str| {
            r.say(s);
            r.out.extend_from_slice(PROMPT);
            State::Command
        };
        let kind = match word.as_bytes().get(1) {
            None | Some(b'P') => b'P',
            Some(b'B') => b'B',
            Some(_) => {
                return refuse(
                    r,
                    &format!("*** Error: Invalid Send option {}\r", second_char(word)),
                )
            }
        };
        if self.sent >= self.limits.max_messages {
            r.limit = Some("messages per session");
            return refuse(
                r,
                &format!(
                    "*** Error: The demo BBS takes {} messages per session. Log in again to send more.\r",
                    self.limits.max_messages
                ),
            );
        }

        let (mut to, mut via, mut bid) = (None::<String>, String::new(), String::new());
        let mut toks = args.iter();
        while let Some(t) = toks.next() {
            let t = t.to_ascii_uppercase();
            if !t.chars().all(|c| c.is_ascii_graphic()) || t.contains(';') {
                return refuse(r, "*** Error: Invalid Format\r");
            }
            if t == "@" {
                match toks.next() {
                    Some(v) => via = v.to_ascii_uppercase(),
                    None => return refuse(r, "*** Error: Invalid Format\r"),
                }
            } else if let Some(v) = t.strip_prefix('@') {
                via = v.to_string();
            } else if let Some(b) = t.strip_prefix('$') {
                bid = b.chars().take(MAX_BID).collect();
            } else if t.starts_with('<') {
                return refuse(r, "*** < can only be used by a BBS\r");
            } else if to.is_none() {
                let (call, v) = t.split_once(['@', '!']).unwrap_or((t.as_str(), ""));
                if !v.is_empty() {
                    via = v.to_string();
                }
                to = Some(
                    call.split('-')
                        .next()
                        .unwrap_or("")
                        .chars()
                        .take(6)
                        .collect(),
                );
            } else {
                return refuse(r, "*** Error: Invalid Format\r");
            }
        }
        let to = match to {
            Some(t) if !t.is_empty() => t,
            _ => return refuse(r, "*** Error: The 'TO' callsign is missing\r"),
        };
        if !via.chars().all(|c| c.is_ascii_graphic()) {
            return refuse(r, "*** Error: Invalid Format\r");
        }
        via.truncate(MAX_VIA);
        if !bid.is_empty() && self.duplicate_bid(kind, &to, &bid) {
            return refuse(r, "*** Error- Duplicate BID\r");
        }
        if kind == b'P' && via.is_empty() && to != "SYSOP" {
            if to == self.me() {
                via = self.home.clone();
                r.say(&format!("Address @{} added from HomeBBS\r", via));
            } else if let Some(e) = self.mail.wp_entry(&to) {
                via = e.home.clone();
                let from = if e.local { "HomeBBS" } else { "WP" };
                r.say(&format!("Address @{} added from {}\r", via, from));
            }
        }
        r.say("Enter Title (only):\r");
        State::Title(Draft {
            kind,
            to,
            via,
            bid,
            title: Vec::new(),
            body: Vec::new(),
            too_big: false,
        })
    }

    fn duplicate_bid(&self, kind: u8, to: &str, bid: &str) -> bool {
        self.mail.messages.iter().any(|m| {
            m.bid == bid
                && (kind == b'B' && m.kind == b'B'
                    || kind == b'P'
                        && m.kind == b'P'
                        && m.to == to
                        && matches!(m.status, b'N' | b'Y' | b'H'))
        })
    }

    fn on_title(&mut self, line: &[u8], mut d: Draft, r: &mut Reply) -> State {
        if session_killer(line) {
            return State::Closed;
        }
        if line.is_empty() {
            r.say("*** Message Cancelled\r");
            r.out.extend_from_slice(PROMPT);
            return State::Command;
        }
        d.title = clean(line);
        d.title.truncate(MAX_TITLE);
        r.say("Enter Message Text (end with /ex or ctrl/z)\r");
        State::Body(d)
    }

    fn on_body(&mut self, line: &[u8], mut d: Draft, now: i64, r: &mut Reply) -> State {
        if session_killer(line) {
            return State::Closed;
        }
        if line.eq_ignore_ascii_case(b"/ex") {
            return self.finish(d, now, r);
        }
        let (text, last) = match line.iter().position(|&b| b == 0x1A) {
            Some(_) if line.len() <= 2 => return self.finish(d, now, r),
            Some(i) => (&line[..i], true),
            None => (line, false),
        };
        if d.body.len() + text.len() + 2 > self.limits.max_message_bytes {
            d.too_big = true;
        } else if !d.too_big {
            d.body.extend_from_slice(text);
            d.body.extend_from_slice(b"\r\n");
        }
        if last {
            return self.finish(d, now, r);
        }
        State::Body(d)
    }

    fn is_local(&self, call: &str) -> bool {
        call == self.me() || call == "SYSOP" || self.mail.wp_entry(call).is_some_and(|e| e.local)
    }

    fn finish(&mut self, d: Draft, now: i64, r: &mut Reply) -> State {
        if d.too_big {
            r.limit = Some("message size");
            r.say(&format!(
                "*** Error: Message too long for the demo BBS (limit {} bytes) - not sent\r",
                self.limits.max_message_bytes
            ));
            r.out.extend_from_slice(PROMPT);
            return State::Command;
        }
        let first_via = d.via.split('.').next().unwrap_or("").to_string();
        let size = d.body.len();
        let to_robot = d.kind == b'P' && d.to == ROBOT_CALL;
        let local = self.is_local(&d.to);
        let msg = Message {
            number: 0,
            kind: d.kind,
            status: if to_robot { b'Y' } else { b'N' },
            to: d.to,
            via: d.via,
            from: self.me().to_string(),
            title: d.title,
            bid: d.bid,
            date: now,
            body: d.body,
        };
        let n = self.mail.add(msg);
        self.sent += 1;
        let bid = self.mail.get(n).map(|m| m.bid.clone()).unwrap_or_default();
        r.say(&format!("Message: {} Bid:  {} Size: {}\r", n, bid, size));
        let elsewhere = !first_via.is_empty() && first_via != BBS_CALL;
        if d.kind == b'B' && !first_via.is_empty() || d.kind == b'P' && elsewhere {
            r.say(
                "@BBS specified, but no forwarding info is available - msg may not be delivered\r",
            );
        } else if d.kind == b'P' && !local && first_via.is_empty() {
            r.say("Message is not for a local user, and no forwarding info is available - msg may not be delivered\r");
        }
        if to_robot {
            self.robot_reply(n, now);
        }
        r.out.extend_from_slice(PROMPT);
        State::Command
    }

    /// The demo robot answers at once, so the reply is there at the next list.
    fn robot_reply(&mut self, original: u32, now: i64) {
        let Some(m) = self.mail.get(original) else {
            return;
        };
        let mut title = b"Re: ".to_vec();
        if m.title.len() >= 3 && m.title[..3].eq_ignore_ascii_case(b"re:") {
            title.clear();
        }
        title.extend_from_slice(&m.title);
        title.truncate(MAX_TITLE);
        let name = if self.name.is_empty() {
            b"there".to_vec()
        } else {
            self.name.clone()
        };

        let mut body = b"Hello ".to_vec();
        body.extend_from_slice(&name);
        body.extend_from_slice(
            b",\r\n\r\nThanks for your message. This is an automatic reply from the\r\n\
demo BBS robot, so no person has read it. Everything you send\r\n\
here is private to your session and is thrown away when you\r\n\
log off.\r\n\r\nYou wrote:\r\n\r\n",
        );
        let lines: Vec<&[u8]> = m
            .body
            .split(|&b| b == b'\n')
            .map(|l| l.strip_suffix(b"\r").unwrap_or(l))
            .collect();
        let lines = &lines[..lines.len().saturating_sub(1)];
        for l in lines.iter().take(ROBOT_QUOTE_LINES) {
            body.extend_from_slice(b"> ");
            body.extend_from_slice(&l[..l.len().min(70)]);
            body.extend_from_slice(b"\r\n");
        }
        if lines.len() > ROBOT_QUOTE_LINES {
            body.extend_from_slice(b"> ...\r\n");
        }
        body.extend_from_slice(b"\r\n73 de Q0BOT, the demo robot\r\n");

        let reply = Message {
            number: 0,
            kind: b'P',
            status: b'N',
            to: self.me().to_string(),
            via: self.home.clone(),
            from: ROBOT_CALL.to_string(),
            title,
            bid: String::new(),
            date: now,
            body,
        };
        self.mail.add(reply);
    }
}

/// Lines BPQ acts on even mid-message by dropping the session (section 9.5).
fn session_killer(line: &[u8]) -> bool {
    const KILLERS: [&[u8]; 3] = [
        b"ALREADY CONNECTED",
        b"INVALID COMMAND",
        b"*** PROTOCOL ERROR",
    ];
    KILLERS
        .iter()
        .any(|k| line.len() >= k.len() && line[..k.len()].eq_ignore_ascii_case(k))
}

/// The listing line, as BPQ's ListMessage formats it.
fn listing_line(m: &Message) -> Vec<u8> {
    let via = m.via.split('.').next().unwrap_or("");
    let head = if via.is_empty() {
        format!(
            "{:<6} {} {}{}   {:>5} {:<7}        {:<6} ",
            m.number,
            day_month(m.date),
            m.kind as char,
            m.status as char,
            m.body.len(),
            m.to,
            m.from
        )
    } else {
        format!(
            "{:<6} {} {}{}   {:>5} {:<7}@{:<6} {:<6} ",
            m.number,
            day_month(m.date),
            m.kind as char,
            m.status as char,
            m.body.len(),
            m.to,
            via,
            m.from
        )
    };
    let mut out = head.into_bytes();
    out.extend_from_slice(&m.title);
    out.push(b'\r');
    out
}

/// C's atoi, saturating: leading digits, or 0.
fn atoi(s: &str) -> u64 {
    s.bytes()
        .take_while(|b| b.is_ascii_digit())
        .fold(0u64, |n, b| {
            n.saturating_mul(10).saturating_add((b - b'0') as u64)
        })
}

fn second_char(word: &str) -> char {
    word.chars().nth(1).unwrap_or(' ')
}

/// Drops control characters (BPQ strips NULs; we drop the rest too).
fn clean(line: &[u8]) -> Vec<u8> {
    line.iter()
        .copied()
        .filter(|&b| b >= 32 && b != 127)
        .collect()
}

fn crlf_to_cr(body: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(body.len());
    let mut i = 0;
    while i < body.len() {
        if body[i] == b'\r' && body.get(i + 1) == Some(&b'\n') {
            out.push(b'\r');
            i += 2;
        } else {
            out.push(body[i]);
            i += 1;
        }
    }
    out
}

/// White Pages patterns: `X`, `X*`, `*X`, `*X*`.
fn wild(value: &str, pattern: &str) -> bool {
    let (starts, rest) = match pattern.strip_prefix('*') {
        Some(r) => (false, r),
        None => (true, pattern),
    };
    let (ends, core) = match rest.strip_suffix('*') {
        Some(c) => (false, c),
        None => (true, rest),
    };
    match (starts, ends) {
        (true, true) => value == core,
        (true, false) => value.starts_with(core),
        (false, true) => value.ends_with(core),
        (false, false) => value.contains(core),
    }
}

const HELP: &str = "Commands on the demo BBS:\r\
L    list new messages        LM   list mail to you\r\
LB   list bulletins           L< CALL  list mail from CALL\r\
LL n list the last n          R n  read message n\r\
SP CALL   send personal mail  SB CAT @ AREA  send a bulletin\r\
K n  delete message n         I CALL  White Pages lookup\r\
HOMEBBS   show your home BBS  B    log off\r";

const INFO: &str = "Q0DEMO is a demonstration BBS for the Packet Mail app.\r\
Everything here is made up. Your session has its own private copy of\r\
the BBS: nothing you send is seen by anyone else, and it is all thrown\r\
away when you log off. Send personal mail to Q0BOT for a reply.\r";

#[cfg(test)]
mod tests;
