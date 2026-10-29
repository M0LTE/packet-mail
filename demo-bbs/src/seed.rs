//! The demo content every session starts with. All callsigns use the
//! unallocated Q0 prefix and all names are made up.

use crate::dates::routing_stamp;
use crate::mail::{
    body_from_text, first_new_number, Mailbox, Message, WpEntry, BBS_CALL, BBS_HOME,
};

/// The callsign the `demo` login uses.
pub const USER_CALL: &str = "Q0YOU";
/// The robot that answers personal mail sent to it.
pub const ROBOT_CALL: &str = "Q0BOT";

const FIRST_NUMBER: u32 = 1001;

struct Seed {
    /// Minutes before the session started.
    age: i64,
    kind: u8,
    status: u8,
    to: &'static str,
    via: &'static str,
    from: &'static str,
    title: &'static str,
    /// Where it came from, for R: lines. Empty for mail written here.
    origin: &'static str,
    body: &'static str,
}

const MAIL: &[Seed] = &[
    Seed {
        age: 8460,
        kind: b'B',
        status: b'F',
        to: "WX",
        via: "GBR",
        from: "Q0WX",
        title: "Regional weather outlook",
        origin: "Q0NTH.#07.GBR.EURO",
        body: "Q0WX regional outlook for the coming days.

Day        Wind       Temp   Rain
---------  ---------  -----  -----
Monday     SW 20 kt   13 C   80 %
Tuesday    W  15 kt   12 C   40 %
Wednesday  NW 10 kt   11 C   10 %

Unsettled at first, then drier. Secure any loose wire antennas
before Monday night.
",
    },
    Seed {
        age: 7200,
        kind: b'P',
        status: b'Y',
        to: "Q0ADA",
        via: BBS_HOME,
        from: USER_CALL,
        title: "Thanks for the welcome",
        origin: "",
        body: "Hi Ada,

Thanks for the welcome message. I'm finding my way around the
BBS. See you on the Thursday net.

73
",
    },
    Seed {
        age: 6900,
        kind: b'B',
        status: b'N',
        to: "ALL",
        via: "WW",
        from: "Q0SYS",
        title: "Welcome to the Q0DEMO demo BBS",
        origin: "",
        body: "Welcome to Q0DEMO, a demonstration BBS for the Packet Mail app.

Everything here is made up: the stations, the names, the mail and
the bulletins. Nothing you send leaves this BBS, and nobody else can
see it. When you log off, your copy of the BBS is thrown away and
the next login starts fresh.

Things to try:

  - Read your personal mail and bulletins.
  - Send a personal message to Q0BOT. The demo robot replies
    within a few seconds.
  - Post a bulletin, for example to ALL @ GBR.
  - Delete a message.

73 de Q0SYS, demo sysop
",
    },
    Seed {
        age: 5800,
        kind: b'P',
        status: b'F',
        to: "Q0FRA",
        via: "Q0WST.#11.GBR.EURO",
        from: USER_CALL,
        title: "Packet node meeting",
        origin: "",
        body: "Hello Frank,

Are you going to the packet node meeting next month? I could
bring the spare TNC if anyone wants to borrow it.

73
",
    },
    Seed {
        age: 5600,
        kind: b'P',
        status: b'Y',
        to: "Q0BEN",
        via: BBS_HOME,
        from: "Q0ADA",
        title: "Club accounts",
        origin: "",
        body: "Ben, the club accounts are ready for the meeting.\n",
    },
    Seed {
        age: 4400,
        kind: b'B',
        status: b'$',
        to: "DX",
        via: "WW",
        from: "Q0DX",
        title: "Weekly DX summary",
        origin: "Q0WST.#11.GBR.EURO",
        body: "Weekly DX summary

Band   Mode   Station   Country          UTC
-----  -----  --------  ---------------  -----
20 m   CW     Q0AAA     Fictionland      0715
17 m   FT8    Q0BBB     Nowhere Island   1230
15 m   SSB    Q0CCC     Imaginaria       1545
10 m   FT8    Q0DDD     Utopia           1610

Conditions were good on the higher bands most afternoons.
",
    },
    Seed {
        age: 4300,
        kind: b'B',
        status: b'N',
        to: "SALE",
        via: "GBR",
        from: "Q0BEN",
        title: "For sale: 2 m handheld and charger",
        origin: "",
        body: "For sale: a 2 m handheld with its charger, a spare battery
and a short whip. Works well. Collection from Brookfield, or
bring it to the club on Thursday.

Reply by packet mail to Q0BEN.
",
    },
    Seed {
        age: 3000,
        kind: b'P',
        status: b'Y',
        to: USER_CALL,
        via: BBS_HOME,
        from: "Q0CAT",
        title: "Re: Antenna for the loft",
        origin: "",
        body: "Hi,

> I have about four metres of loft space. Is a dipole for
> 2 m worth trying, or should I go straight for a J-pole?

A dipole is a fine start and costs almost nothing. Keep it
away from the water tank and any wiring, and put a choke at
the feed point.

> Any tips on coax?

Use the best you can afford for the run down to the shack.
The loss adds up quickly at 2 m.

73 Cath
",
    },
    Seed {
        age: 2900,
        kind: b'B',
        status: b'N',
        to: "TECH",
        via: "EURO",
        from: "Q0EVE",
        title: "Notes on a 9600 baud TNC",
        origin: "Q0NTH.#07.GBR.EURO",
        body: "Some notes from getting 9600 baud working on our link.

1. The radio needs a flat audio path: use the data port, not
   the microphone socket.
2. Set the deviation carefully. Too much is worse than too
   little.
3. TXDELAY of 100 ms was enough for our radios.

With that done the link carries mail about six times faster
than at 1200 baud.

Eve
",
    },
    Seed {
        age: 1500,
        kind: b'B',
        status: b'N',
        to: "SATS",
        via: "WW",
        from: "Q0FRA",
        title: "Satellite passes this week",
        origin: "Q0WST.#11.GBR.EURO",
        body: "Passes for Brookfield this week (times UTC, elevation in degrees)

Satellite   Day   Rise    Max El   Set
----------  ----  -----   ------   -----
DEMOSAT-1   Mon   0912    41       0923
DEMOSAT-1   Wed   1035    67       1047
DEMOSAT-2   Thu   1821    22       1830
DEMOSAT-2   Sat   0750    55       0802

Frank
",
    },
    Seed {
        age: 1440,
        kind: b'P',
        status: b'N',
        to: USER_CALL,
        via: BBS_HOME,
        from: "Q0EVE",
        title: "Hello from the north",
        origin: "Q0NTH.#07.GBR.EURO",
        body: "Hello,

I saw your call in the White Pages and thought I'd say hello
from up north. Our BBS is Q0NTH, linked to yours each evening.

What sort of station do you run?

73 Eve
",
    },
    Seed {
        age: 700,
        kind: b'B',
        status: b'N',
        to: "NEWS",
        via: "EU",
        from: "Q0SYS",
        title: "Packet news: new node on Hilltop",
        origin: "",
        body: "A new packet node is on the air on Hilltop, giving better
coverage to the east of the region. It links to Q0DEMO on 2 m
at 1200 baud and on 70 cm at 9600 baud.

Thanks to everyone who helped carry the mast up the hill.
",
    },
    Seed {
        age: 400,
        kind: b'B',
        status: b'N',
        to: "WX",
        via: "GBR",
        from: "Q0WX",
        title: "Regional weather outlook",
        origin: "Q0NTH.#07.GBR.EURO",
        body: "Q0WX regional outlook for the coming days.

Day        Wind       Temp   Rain
---------  ---------  -----  -----
Thursday   S   5 kt   12 C    5 %
Friday     SE 10 kt   13 C   10 %
Saturday   E  10 kt   14 C    0 %

Settled and dry. Good conditions for portable operating at the
weekend.
",
    },
    Seed {
        age: 240,
        kind: b'B',
        status: b'N',
        to: "ALL",
        via: "GBR",
        from: "Q0ADA",
        title: "Club meeting Thursday 7.30pm",
        origin: "",
        body: "The next club meeting is on Thursday at 7.30pm in the
village hall. Ben will talk about getting started with packet
radio, and there will be tea.

Ada, club secretary
",
    },
    Seed {
        age: 90,
        kind: b'P',
        status: b'N',
        to: USER_CALL,
        via: BBS_HOME,
        from: "Q0BEN",
        title: "Club net tonight",
        origin: "",
        body: "Hi,

The club net is tonight at 8pm on the usual frequency. If you
can't make it on voice, check in by packet mail instead and
I'll read your message out.

73 Ben
",
    },
    Seed {
        age: 30,
        kind: b'P',
        status: b'N',
        to: USER_CALL,
        via: BBS_HOME,
        from: "Q0ADA",
        title: "Welcome to Q0DEMO",
        origin: "",
        body: "Hello and welcome!

This is a demo BBS, so feel free to try anything. Some ideas:

  - Reply to this message.
  - Send a message to Q0BOT, the demo robot. It answers every
    personal message it gets.
  - Delete mail you've read.

Nothing you do here is seen by anyone else, and it's all reset
when you log off.

73 Ada
",
    },
];

fn wp(call: &str, home: &str, name: &str, qth: &str, local: bool) -> WpEntry {
    WpEntry {
        call: call.into(),
        home: home.into(),
        name: name.into(),
        zip: String::new(),
        qth: qth.into(),
        local,
    }
}

/// A fresh copy of the demo BBS for one session that started at `now`.
pub fn seed(now: i64) -> Mailbox {
    let mut messages = Vec::new();
    for (i, s) in MAIL.iter().enumerate() {
        let number = FIRST_NUMBER + i as u32;
        let date = now - s.age * 60;
        let mut body = Vec::new();
        if !s.origin.is_empty() {
            // As forwarded mail arrives: the far BBS's R: line, then ours.
            let far_number = 52_000 + number * 7;
            body.extend_from_slice(
                format!(
                    "R:{} {}@{} BPQ6.0.26\r\n",
                    routing_stamp(date + 120),
                    number,
                    BBS_HOME
                )
                .as_bytes(),
            );
            body.extend_from_slice(
                format!(
                    "R:{} {}@{} BPQ6.0.26\r\n\r\n",
                    routing_stamp(date),
                    far_number,
                    s.origin
                )
                .as_bytes(),
            );
        }
        body.extend_from_slice(&body_from_text(s.body));
        messages.push(Message {
            number,
            kind: s.kind,
            status: s.status,
            to: s.to.into(),
            via: s.via.into(),
            from: s.from.into(),
            title: s.title.as_bytes().to_vec(),
            bid: if s.origin.is_empty() {
                format!("{}_{}", number, BBS_CALL)
            } else {
                format!(
                    "{}_{}",
                    52_000 + number * 7,
                    s.origin.split('.').next().unwrap_or("")
                )
            },
            date,
            body,
        });
    }
    let nth = "Q0NTH.#07.GBR.EURO";
    let wst = "Q0WST.#11.GBR.EURO";
    Mailbox {
        next_number: first_new_number(now),
        messages,
        wp: vec![
            wp(ROBOT_CALL, BBS_HOME, "Demo Robot", "Brookfield", true),
            wp("Q0SYS", BBS_HOME, "Demo Sysop", "Brookfield", true),
            wp("Q0ADA", BBS_HOME, "Ada Parkes", "Brookfield", true),
            wp("Q0BEN", BBS_HOME, "Ben Hartley", "Brookfield", true),
            wp("Q0CAT", BBS_HOME, "Cath Morley", "Little Brookfield", true),
            wp("Q0WX", BBS_HOME, "Weather Desk", "Brookfield", true),
            wp("Q0DX", wst, "DX Desk", "Westcombe", false),
            wp("Q0EVE", nth, "Eve Lindqvist", "Northam", false),
            wp("Q0FRA", wst, "Frank Dobson", "Westcombe", false),
        ],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seed_is_in_number_and_date_order_and_ascii() {
        let m = seed(1_793_196_300);
        for w in m.messages.windows(2) {
            assert_eq!(w[1].number, w[0].number + 1);
            assert!(w[1].date >= w[0].date);
        }
        for msg in &m.messages {
            assert!(msg.body.is_ascii() && msg.title.is_ascii());
            assert!(
                msg.title.len() <= 59,
                "{}",
                String::from_utf8_lossy(&msg.title)
            );
            assert!(msg.to.len() <= 6 && msg.from.len() <= 6);
        }
    }
}
