//! One session's private mail store: messages and White Pages.

/// The demo BBS's callsign and full hierarchical address.
pub const BBS_CALL: &str = "Q0DEMO";
pub const BBS_HOME: &str = "Q0DEMO.#42.GBR.EURO";

#[derive(Clone, Debug)]
pub struct Message {
    pub number: u32,
    /// `P` personal, `B` bulletin, `T` traffic.
    pub kind: u8,
    /// `N`, `Y`, `F`, `$`, `K` ...
    pub status: u8,
    pub to: String,
    /// The @BBS or flood area, possibly hierarchical. Empty for none.
    pub via: String,
    pub from: String,
    pub title: Vec<u8>,
    pub bid: String,
    /// Unix seconds.
    pub date: i64,
    /// Stored with CRLF line ends, as BPQ stores it.
    pub body: Vec<u8>,
}

#[derive(Clone, Debug)]
pub struct WpEntry {
    pub call: String,
    pub home: String,
    pub name: String,
    pub zip: String,
    pub qth: String,
    /// A user of this BBS, so a bare address gets "added from HomeBBS".
    pub local: bool,
}

#[derive(Clone, Debug, Default)]
pub struct Mailbox {
    /// In number order.
    pub messages: Vec<Message>,
    pub wp: Vec<WpEntry>,
    /// The lowest number the next new message may take.
    pub next_number: u32,
}

impl Mailbox {
    pub fn latest(&self) -> u32 {
        self.messages.last().map_or(0, |m| m.number)
    }

    pub fn get(&self, number: u32) -> Option<&Message> {
        self.messages
            .binary_search_by_key(&number, |m| m.number)
            .ok()
            .map(|i| &self.messages[i])
    }

    pub fn get_mut(&mut self, number: u32) -> Option<&mut Message> {
        match self.messages.binary_search_by_key(&number, |m| m.number) {
            Ok(i) => Some(&mut self.messages[i]),
            Err(_) => None,
        }
    }

    /// Stores a message under the next number and returns that number.
    pub fn add(&mut self, mut m: Message) -> u32 {
        m.number = (self.latest() + 1).max(self.next_number);
        if m.bid.is_empty() {
            m.bid = format!("{}_{}", m.number, BBS_CALL);
        }
        let n = m.number;
        self.messages.push(m);
        n
    }

    pub fn wp_entry(&self, call: &str) -> Option<&WpEntry> {
        self.wp.iter().find(|e| e.call == call)
    }
}

/// Where a session's new messages start numbering. Each connection gets a
/// fresh copy of the demo, and the app keeps what it downloaded, so a number
/// must not come back with different mail in a later connection. Basing it
/// on the time of day keeps numbers apart without any shared state. Stays
/// under BPQ's 100000 limit for listing arguments.
pub fn first_new_number(now: i64) -> u32 {
    2000 + now.rem_euclid(86_400) as u32
}

/// Converts text with `\n` line ends into a stored body: CRLF after every line.
pub fn body_from_text(text: &str) -> Vec<u8> {
    let mut out = Vec::new();
    for line in text.trim_end_matches('\n').split('\n') {
        out.extend_from_slice(line.as_bytes());
        out.extend_from_slice(b"\r\n");
    }
    out
}
