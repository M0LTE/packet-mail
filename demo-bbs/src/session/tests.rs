use super::*;
use crate::sandbox::RegistryLimits;
use proptest::prelude::*;
use std::time::Duration;

const NOW: i64 = 1_793_196_300; // 2026-10-28 14:05 UTC
/// The first new message's number at NOW: 2000 plus seconds into the day.
const N1: u32 = 52_700;
const N2: u32 = 52_701;

fn t() -> Now {
    static BASE: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
    Now {
        unix: NOW,
        mono: *BASE.get_or_init(Instant::now),
    }
}

fn at(secs: u64) -> Now {
    Now {
        unix: NOW + secs as i64,
        mono: t().mono + Duration::from_secs(secs),
    }
}

fn registry() -> Arc<Registry> {
    Registry::new(RegistryLimits::default())
}

const HOME_IP: &str = "192.0.2.1";

fn connect(r: &Arc<Registry>, ip: &str, limits: SessionLimits) -> Session {
    Session::new(r.clone(), ip.parse().unwrap(), limits)
}

fn session() -> Session {
    connect(&registry(), HOME_IP, SessionLimits::default())
}

fn say(s: &mut Session, line: &str) -> String {
    String::from_utf8(s.handle(line.as_bytes(), t()).out).unwrap()
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
        assert_eq!(say(&mut s, "no body"), "user:");
    }
    let r = s.handle(b"no body", t());
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
    let r = s.handle(b"QTH somewhere", t());
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
    let r = s.handle(b"B", t());
    assert_eq!(r.out, b"73 de Q0DEMO\r");
    assert!(r.close);
}

#[test]
fn limits_on_size_and_count() {
    let mut s = connect(
        &registry(),
        HOME_IP,
        SessionLimits {
            max_message_bytes: 20,
            max_messages: 1,
            ..SessionLimits::default()
        },
    );
    for l in ["demo", "demo", "BBS", "Me"] {
        say(&mut s, l);
    }
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    say(&mut s, "This line is far too long for the limit");
    let r = s.handle(b"/ex", t());
    assert_eq!(r.limit, Some("message size"));
    assert!(String::from_utf8(r.out).unwrap().contains("not sent"));
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    say(&mut s, "Short");
    assert!(say(&mut s, "/ex").starts_with(&format!("Message: {N1} ")));
    let r = s.handle(b"SP Q0ADA", t());
    assert_eq!(r.limit, Some("messages per visitor"));
}

#[test]
fn session_killers_drop_the_session_mid_message() {
    let mut s = logged_in();
    say(&mut s, "SP Q0ADA");
    say(&mut s, "Title");
    assert!(s.handle(b"invalid command here", t()).close);
}

/// Logs in on a new connection to an existing registry; returns the welcome.
fn reconnect(r: &Arc<Registry>, ip: &str, now: Now) -> (Session, String) {
    let mut s = connect(r, ip, SessionLimits::default());
    s.handle(b"demo", now);
    s.handle(b"demo", now);
    let hello = String::from_utf8(s.handle(b"BBS", now).out).unwrap();
    (s, hello)
}

fn send(s: &mut Session, cmd: &str, title: &str) -> String {
    say(s, cmd);
    say(s, title);
    say(s, "Body.");
    say(s, "/ex")
}

#[test]
fn a_visitor_s_connections_share_one_sandbox() {
    let r = registry();
    let (mut a, hello) = reconnect(&r, HOME_IP, t());
    assert!(hello.ends_with("Please enter your Name\r>\r"));
    say(&mut a, "Tess");
    assert!(send(&mut a, "SP Q0BOT", "Hello robot").starts_with(&format!("Message: {N1} ")));
    say(&mut a, "K 1016");
    a.end(at(10).mono);

    // The app opens the robot's reply on a new connection.
    let (mut b, hello) = reconnect(&r, HOME_IP, at(20));
    assert!(
        hello.starts_with("DEMO:Q0DEMO} Connected to BBS\r[BPQ-6.0.26.1-B2FWIHJM$]\rHello Tess."),
        "{hello}"
    );
    let reply = say(&mut b, &format!("R {N2}"));
    assert!(
        reply.contains("Title: Re: Hello robot\r") && reply.contains("Hello Tess,"),
        "{reply}"
    );
    assert_eq!(
        say(&mut b, "R 1016"),
        "Message 1016 not for you\rde Q0DEMO>\r"
    );
    assert!(!say(&mut b, "LM").contains("Welcome to Q0DEMO"));
    assert!(say(&mut b, "L< Q0YOU").contains("Hello robot"));
    b.end(at(30).mono);
}

#[test]
fn the_message_limit_spans_connections() {
    let r = registry();
    let limits = SessionLimits {
        max_messages: 1,
        ..SessionLimits::default()
    };
    let mut a = connect(&r, HOME_IP, limits.clone());
    for l in ["demo", "demo", "BBS", "Me"] {
        say(&mut a, l);
    }
    assert!(send(&mut a, "SP Q0ADA", "One").starts_with("Message: "));
    a.end(at(1).mono);
    let mut b = connect(&r, HOME_IP, limits);
    for l in ["demo", "demo", "BBS"] {
        say(&mut b, l);
    }
    let reply = b.handle(b"SP Q0ADA", t());
    assert_eq!(reply.limit, Some("messages per visitor"));
}

#[test]
fn another_user_name_gets_its_own_sandbox() {
    let r = registry();
    let (mut a, _) = reconnect(&r, HOME_IP, t());
    say(&mut a, "Ann");
    say(&mut a, "K 1016");
    let mut b = connect(&r, HOME_IP, SessionLimits::default());
    for l in ["reviewer2", "demo", "BBS", "Bob"] {
        say(&mut b, l);
    }
    assert!(say(&mut b, "LM").contains("Welcome to Q0DEMO"));
}

#[test]
fn other_addresses_never_see_a_sandbox() {
    let r = registry();
    let (mut a, _) = reconnect(&r, HOME_IP, t());
    say(&mut a, "Ann");
    say(&mut a, "K 1016");
    send(&mut a, "SB ALL @ GBR", "Secret");
    let (mut b, hello) = reconnect(&r, "198.51.100.7", t());
    assert!(hello.ends_with("Please enter your Name\r>\r"));
    say(&mut b, "Bob");
    let all = say(&mut b, "LL 100");
    assert!(all.contains("Welcome to Q0DEMO") && !all.contains("Secret"));
}

#[test]
fn a_sandbox_expires_after_half_an_hour_idle() {
    let r = registry();
    let (mut a, _) = reconnect(&r, HOME_IP, t());
    say(&mut a, "Ann");
    say(&mut a, "K 1016");
    a.end(t().mono);
    let (mut b, hello) = reconnect(&r, HOME_IP, at(30 * 60));
    assert!(hello.ends_with("Please enter your Name\r>\r"), "{hello}");
    say(&mut b, "Ann");
    assert!(say(&mut b, "LM").contains("Welcome to Q0DEMO"));
}

#[test]
fn a_full_registry_turns_visitors_away() {
    let r = Registry::new(RegistryLimits {
        max_sandboxes: 1,
        ..RegistryLimits::default()
    });
    let (_a, _) = reconnect(&r, HOME_IP, t());
    let mut b = connect(&r, "198.51.100.7", SessionLimits::default());
    b.handle(b"demo", t());
    let reply = b.handle(b"demo", t());
    assert_eq!(
        reply.out,
        b"Sorry, the demo BBS is full. Please try again later.\r"
    );
    assert!(reply.close);
    assert_eq!(reply.limit, Some("sandboxes"));
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
        let mut s = connect(&registry(), HOME_IP, SessionLimits { max_message_bytes: 2048, max_messages: 5, ..SessionLimits::default() });
        if login {
            for l in ["demo", "demo", "BBS", "Visitor"] {
                s.handle(l.as_bytes(), t());
            }
        }
        let mut closed = false;
        for l in &lines {
            let r = s.handle(l, t());
            if closed {
                prop_assert!(r.out.is_empty() && r.close);
            }
            // The biggest reply is a full listing or a few long messages.
            prop_assert!(r.out.len() < 64 * 1024);
            closed |= r.close;
        }
        prop_assert!(s.with_sandbox(|sb| sb.mail.messages.len()) <= 16 + 2 * 5);
        prop_assert!(s.with_sandbox(|sb| sb.mail.messages.iter().all(|m| m.body.len() <= 4096)));
    }
}
