use super::*;
use proptest::prelude::*;

const NOW: i64 = 1_793_196_300; // 2026-10-28 14:05 UTC
/// The first new message's number at NOW: 2000 plus seconds into the day.
const N1: u32 = 52_700;
const N2: u32 = 52_701;

fn session() -> Session {
    Session::new(NOW, SessionLimits::default())
}

fn say(s: &mut Session, line: &str) -> String {
    String::from_utf8(s.handle(line.as_bytes(), NOW).out).unwrap()
}

fn logged_in() -> Session {
    let mut s = session();
    assert_eq!(say(&mut s, "demo"), "");
    assert_eq!(say(&mut s, "demo"), "");
    assert_eq!(
        say(&mut s, "BBS"),
        "DEMO:Q0DEMO} Connected to BBS\r[BPQ-6.0.26.1-B2FWIHJM$]\rPlease enter your Name\r>\r"
    );
    assert_eq!(
        say(&mut s, "Tom User"),
        "Hello Tom User. Latest Message is 1016, Last listed is 996\rde Q0DEMO>\r"
    );
    s
}

#[test]
fn bad_password_then_pipelined_bbs_is_another_attempt() {
    let mut s = session();
    assert_eq!(say(&mut s, "demo"), "");
    assert_eq!(say(&mut s, "wrong"), "password:");
    assert_eq!(say(&mut s, "BBS"), "password:");
    assert!(!s.in_bbs());
}

#[test]
fn five_failures_disconnect() {
    let mut s = session();
    for _ in 0..4 {
        assert_eq!(say(&mut s, "nobody"), "user:");
    }
    let r = s.handle(b"nobody", NOW);
    assert_eq!(r.out, b"Too many attempts - Disconnected\r\n");
    assert!(r.close);
    assert_eq!(r.limit, Some("login attempts"));
}

#[test]
fn listing_lines_match_bpq() {
    let mut s = logged_in();
    let lm = say(&mut s, "LM");
    assert!(lm.starts_with("1016   28-Oct PN     "), "{lm}");
    assert!(
        lm.contains(" Q0YOU  @Q0DEMO Q0ADA  Welcome to Q0DEMO\r"),
        "{lm}"
    );
    assert!(lm.ends_with("de Q0DEMO>\r"));
    let lb = say(&mut s, "LB");
    assert!(lb.contains(" BN    "), "{lb}");
    assert!(
        lb.contains(" ALL    @GBR    Q0ADA  Club meeting Thursday 7.30pm\r"),
        "{lb}"
    );
    // Other people's personal mail never shows.
    assert!(!say(&mut s, "LL 100").contains("Club accounts"));
}

#[test]
fn plain_l_lists_new_then_nothing() {
    let mut s = logged_in();
    assert!(say(&mut s, "L").contains("Welcome to Q0DEMO"));
    assert_eq!(say(&mut s, "L"), "No New Messages\rde Q0DEMO>\r");
}

#[test]
fn listing_by_sender_needs_the_space() {
    let mut s = logged_in();
    let sent = say(&mut s, "L< Q0YOU");
    assert!(
        sent.contains("Thanks for the welcome") && sent.contains("Packet node meeting"),
        "{sent}"
    );
    assert!(sent.contains(" PF ") && sent.contains(" PY "), "{sent}");
    assert_eq!(say(&mut s, "L<Q0YOU"), "de Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "L 999999"),
        "Message Number too high\rde Q0DEMO>\r"
    );
    assert_eq!(
        say(&mut s, "LK"),
        "LH or LK can only be used by SYSOP\rde Q0DEMO>\r"
    );
}

#[test]
fn read_marks_read_and_refuses_others() {
    let mut s = logged_in();
    let m = say(&mut s, "R 1016");
    assert!(m.starts_with("From: Q0ADA\rTo: Q0YOU\rType/Status: PN\rDate/Time: 28-Oct 13:35Z\rBid: 1016_Q0DEMO\rTitle: Welcome to Q0DEMO\r\rHello and welcome!\r"), "{m}");
    assert!(
        m.ends_with("73 Ada\r\r\r[End of Message #1016 from Q0ADA]\rde Q0DEMO>\r"),
        "{m}"
    );
    assert!(say(&mut s, "LM").contains("1016   28-Oct PY"));
    assert_eq!(
        say(&mut s, "R 1005"),
        "Message 1005 not for you\rde Q0DEMO>\r"
    );
    assert_eq!(say(&mut s, "R 5"), "Message 5 not found\rde Q0DEMO>\r");
    assert_eq!(say(&mut s, "R"), "de Q0DEMO>\r");
}

#[test]
fn forwarded_mail_has_routing_lines() {
    let mut s = logged_in();
    let m = say(&mut s, "R 1011");
    assert!(m.contains("Title: Hello from the north\r\rR:261027/1407Z 1011@Q0DEMO.#42.GBR.EURO BPQ6.0.26\rR:261027/1405Z 59077@Q0NTH.#07.GBR.EURO BPQ6.0.26\r\rHello,\r"), "{m}");
}

#[test]
fn send_personal_with_bid_and_duplicate() {
    let mut s = logged_in();
    assert_eq!(
        say(&mut s, "SP Q0ADA @ Q0DEMO.#42.GBR.EURO $DUP1"),
        "Enter Title (only):\r"
    );
    assert_eq!(
        say(&mut s, "Hi Ada"),
        "Enter Message Text (end with /ex or ctrl/z)\r"
    );
    assert_eq!(say(&mut s, "First line"), "");
    assert_eq!(say(&mut s, ""), "");
    assert_eq!(
        say(&mut s, "/EX"),
        format!("Message: {N1} Bid:  DUP1 Size: 14\rde Q0DEMO>\r")
    );
    assert_eq!(
        say(&mut s, "SP Q0ADA @ Q0DEMO.#42.GBR.EURO $DUP1"),
        "*** Error- Duplicate BID\rde Q0DEMO>\r"
    );
    let r = say(&mut s, &format!("R {N1}"));
    assert!(
        r.contains(&format!(
            "Title: Hi Ada\r\rFirst line\r\r\r\r[End of Message #{N1} from Q0YOU]\r"
        )),
        "{r}"
    );
}

#[test]
fn bare_address_filled_in_and_cancel() {
    let mut s = logged_in();
    assert_eq!(
        say(&mut s, "SP Q0ADA"),
        "Address @Q0DEMO.#42.GBR.EURO added from HomeBBS\rEnter Title (only):\r"
    );
    assert_eq!(say(&mut s, ""), "*** Message Cancelled\rde Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "SP Q0EVE"),
        "Address @Q0NTH.#07.GBR.EURO added from WP\rEnter Title (only):\r"
    );
    assert_eq!(say(&mut s, ""), "*** Message Cancelled\rde Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "SP"),
        "*** Error: The 'TO' callsign is missing\rde Q0DEMO>\r"
    );
    assert_eq!(
        say(&mut s, "SX Q0ADA"),
        "*** Error: Invalid Send option X\rde Q0DEMO>\r"
    );
}

#[test]
fn bulletin_gets_no_forwarding_note() {
    let mut s = logged_in();
    say(&mut s, "SB ALL @ GBR");
    say(&mut s, "My bulletin");
    say(&mut s, "Body.");
    assert_eq!(
        say(&mut s, "/ex"),
        format!("Message: {N1} Bid:  {N1}_Q0DEMO Size: 7\r@BBS specified, but no forwarding info is available - msg may not be delivered\rde Q0DEMO>\r")
    );
    assert!(say(&mut s, "LB").contains(&format!(
        "{N1}  28-Oct BN       7 ALL    @GBR    Q0YOU  My bulletin\r"
    )));
    assert_eq!(
        say(&mut s, &format!("K {N1}")),
        format!("Message #{N1} Killed\rde Q0DEMO>\r")
    );
    assert_eq!(say(&mut s, "K 1014"), "Not your message\rde Q0DEMO>\r");
}

#[test]
fn robot_replies() {
    let mut s = logged_in();
    say(&mut s, "SP Q0BOT @ Q0DEMO.#42.GBR.EURO");
    say(&mut s, "Testing the app");
    say(&mut s, "Hello robot");
    assert_eq!(
        say(&mut s, "/EX"),
        format!("Message: {N1} Bid:  {N1}_Q0DEMO Size: 13\rde Q0DEMO>\r")
    );
    let lm = say(&mut s, "LM");
    assert!(lm.starts_with(&format!("{N2}  28-Oct PN    ")), "{lm}");
    assert!(
        lm.contains("Q0YOU  @Q0DEMO Q0BOT  Re: Testing the app\r"),
        "{lm}"
    );
    let r = say(&mut s, &format!("R {N2}"));
    assert!(
        r.contains("Hello Tom User,\r") && r.contains("> Hello robot\r"),
        "{r}"
    );
    // The robot read it.
    assert!(say(&mut s, "L< Q0YOU").contains(&format!("{N1}  28-Oct PY")));
}

#[test]
fn kill_rules() {
    let mut s = logged_in();
    assert_eq!(say(&mut s, "K 1016"), "Message #1016 Killed\rde Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "K 1016"),
        "Message 1016 not found\rde Q0DEMO>\r"
    );
    assert_eq!(
        say(&mut s, "R 1016"),
        "Message 1016 not for you\rde Q0DEMO>\r"
    );
    assert_eq!(say(&mut s, "K 1005"), "Not your message\rde Q0DEMO>\r");
    assert_eq!(say(&mut s, "KM"), "Message #1008 Killed\rde Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "KH"),
        "*** Error: Invalid Kill option H\rde Q0DEMO>\r"
    );
}

#[test]
fn white_pages_and_home() {
    let mut s = logged_in();
    assert_eq!(
        say(&mut s, "I Q0ADA"),
        "Q0ADA  Q0DEMO.#42.GBR.EURO Ada Parkes  Brookfield\rde Q0DEMO>\r"
    );
    assert_eq!(say(&mut s, "I G8BPQ"), "de Q0DEMO>\r");
    assert_eq!(
        say(&mut s, "I Q0YOU"),
        "Q0YOU  Q0DEMO.#42.GBR.EURO Tom User  \rde Q0DEMO>\r"
    );
    assert_eq!(say(&mut s, "IH #07").matches('\r').count(), 2);
    assert_eq!(
        say(&mut s, "HOMEBBS"),
        "HomeBBS is Q0DEMO.#42.GBR.EURO\rde Q0DEMO>\r"
    );
}

#[test]
fn unknown_commands_change_nothing_and_five_close() {
    let mut s = logged_in();
    let before = say(&mut s, "LL 100");
    for _ in 0..4 {
        assert_eq!(say(&mut s, "XYZZY"), "Invalid Command\rde Q0DEMO>\r");
    }
    assert_eq!(say(&mut s, "LL 100"), before);
    let r = s.handle(b"QTH somewhere", NOW);
    assert_eq!(r.out, b"Invalid Command\rToo many errors - closing\r");
    assert!(r.close);
}

#[test]
fn bye_and_node() {
    let mut s = logged_in();
    assert_eq!(
        say(&mut s, "NODE"),
        "73 de Q0DEMO\rReturned to Node DEMO:Q0DEMO\r"
    );
    assert_eq!(
        say(&mut s, "BBS"),
        "DEMO:Q0DEMO} Connected to BBS\r[BPQ-6.0.26.1-B2FWIHJM$]\rHello Tom User. Latest Message is 1016, Last listed is 996\rde Q0DEMO>\r"
    );
    let r = s.handle(b"B", NOW);
    assert_eq!(r.out, b"73 de Q0DEMO\r");
    assert!(r.close);
}

#[test]
fn limits_on_size_and_count() {
    let mut s = Session::new(
        NOW,
        SessionLimits {
            max_message_bytes: 20,
            max_messages: 1,
        },
    );
    for l in ["demo", "demo", "BBS", "Me"] {
        say(&mut s, l);
    }
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    say(&mut s, "This line is far too long for the limit");
    let r = s.handle(b"/ex", NOW);
    assert_eq!(r.limit, Some("message size"));
    assert!(String::from_utf8(r.out).unwrap().contains("not sent"));
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    say(&mut s, "Short");
    assert!(say(&mut s, "/ex").starts_with(&format!("Message: {N1} ")));
    let r = s.handle(b"SP Q0ADA", NOW);
    assert_eq!(r.limit, Some("messages per session"));
}

#[test]
fn session_killers_drop_the_session_mid_message() {
    let mut s = logged_in();
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    assert!(s.handle(b"invalid command here", NOW).close);
}

#[test]
fn sessions_do_not_share_anything() {
    let mut a = logged_in();
    let mut b = logged_in();
    say(&mut a, "K 1016");
    say(&mut a, "SB ALL @ GBR");
    say(&mut a, "Secret");
    say(&mut a, "x");
    say(&mut a, "/ex");
    let lb = say(&mut b, "LL 100");
    assert!(lb.contains("Welcome to Q0DEMO") && !lb.contains("Secret"));
}

fn line_strategy() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        proptest::collection::vec(any::<u8>(), 0..80),
        proptest::sample::select(vec![
            "L",
            "LM",
            "LB",
            "LL 3",
            "L< Q0YOU",
            "L>",
            "L 1-2000",
            "LR",
            "LN",
            "LP",
            "L@ GBR",
            "R 1016",
            "R 1",
            "RM",
            "RMR",
            "RX",
            "K 1016",
            "K 1001",
            "KM",
            "K",
            "I",
            "I Q0*",
            "I *A*",
            "IZ",
            "I@ Q0DEMO",
            "HO",
            "HOMEBBS Q0XYZ",
            "SP Q0BOT",
            "SP Q0ADA @ Q0DEMO $X",
            "SB ALL @ GBR",
            "SB",
            "S",
            "/ex",
            "\u{1a}",
            "",
            "title",
            "body line",
            "NODE",
            "BBS",
            "demo",
            "OP",
            "?",
            ";comment",
            "[SID]",
        ])
        .prop_map(|s| s.as_bytes().to_vec()),
        "[ -~]{0,40}".prop_map(|s| s.into_bytes()),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(512))]

    /// Any sequence of lines: no panic, output bounded, and once closed it stays closed.
    #[test]
    fn any_input_is_safe(lines in proptest::collection::vec(line_strategy(), 0..120), login in any::<bool>()) {
        let mut s = Session::new(NOW, SessionLimits { max_message_bytes: 2048, max_messages: 5 });
        if login {
            for l in ["demo", "demo", "BBS", "Visitor"] {
                s.handle(l.as_bytes(), NOW);
            }
        }
        let mut closed = false;
        for l in &lines {
            let r = s.handle(l, NOW);
            if closed {
                prop_assert!(r.out.is_empty() && r.close);
            }
            // The biggest reply is a full listing or a few long messages.
            prop_assert!(r.out.len() < 64 * 1024);
            closed |= r.close;
        }
        prop_assert!(s.mail.messages.len() <= 16 + 2 * 5);
        prop_assert!(s.mail.messages.iter().all(|m| m.body.len() <= 4096));
    }
}
