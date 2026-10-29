//! The demo BBS server. Every connection gets its own private session that
//! lives only in memory and is dropped when the connection ends.

use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use demo_bbs::guard::{Guard, GuardLimits};
use demo_bbs::lines::{Line, LineReader};
use demo_bbs::sandbox::{Registry, RegistryLimits};
use demo_bbs::session::{Now, Session, SessionLimits};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::time::timeout;

#[derive(Clone, Debug)]
struct Config {
    listen: String,
    guard: GuardLimits,
    session: SessionLimits,
    registry: RegistryLimits,
    max_line: usize,
    login_secs: u64,
    idle_secs: u64,
    session_secs: u64,
}

fn env_num(name: &str, default: usize) -> usize {
    match std::env::var(name) {
        Ok(v) => v.trim().parse().unwrap_or_else(|_| {
            eprintln!("{name}={v} is not a number, using {default}");
            default
        }),
        Err(_) => default,
    }
}

impl Config {
    fn from_env() -> Self {
        Config {
            listen: std::env::var("DEMO_BBS_LISTEN").unwrap_or_else(|_| "0.0.0.0:8011".into()),
            guard: GuardLimits {
                max_connections: env_num("DEMO_BBS_MAX_CONNECTIONS", 50),
                max_per_ip: env_num("DEMO_BBS_MAX_PER_IP", 3),
                connects_per_minute: env_num("DEMO_BBS_CONNECTS_PER_MINUTE", 30),
            },
            session: SessionLimits {
                max_message_bytes: env_num("DEMO_BBS_MAX_MESSAGE_BYTES", 16 * 1024),
                max_messages: env_num("DEMO_BBS_MAX_MESSAGES", 20),
                max_in_bytes: env_num("DEMO_BBS_MAX_IN_BYTES", 256 * 1024),
                max_out_bytes: env_num("DEMO_BBS_MAX_OUT_BYTES", 4 * 1024 * 1024),
            },
            registry: RegistryLimits {
                max_sandboxes: env_num("DEMO_BBS_MAX_SANDBOXES", 200),
                keep_idle: Duration::from_secs(
                    env_num("DEMO_BBS_SANDBOX_IDLE_SECONDS", 1800) as u64
                ),
                max_age: Duration::from_secs(env_num("DEMO_BBS_SANDBOX_MAX_SECONDS", 7200) as u64),
            },
            max_line: env_num("DEMO_BBS_MAX_LINE", 1024),
            login_secs: env_num("DEMO_BBS_LOGIN_SECONDS", 60) as u64,
            idle_secs: env_num("DEMO_BBS_IDLE_SECONDS", 600) as u64,
            session_secs: env_num("DEMO_BBS_SESSION_SECONDS", 1800) as u64,
        }
    }
}

#[tokio::main]
async fn main() {
    let cfg = Config::from_env();
    let listener = match TcpListener::bind(&cfg.listen).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("cannot listen on {}: {e}", cfg.listen);
            std::process::exit(1);
        }
    };
    eprintln!("demo BBS listening on {} (login demo / demo)", cfg.listen);
    let guard = Guard::new(cfg.guard.clone());
    let registry = Registry::new(cfg.registry.clone());

    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("signal handler");
    loop {
        let accepted = tokio::select! {
            a = listener.accept() => a,
            _ = term.recv() => break,
            _ = tokio::signal::ctrl_c() => break,
        };
        let (stream, peer) = match accepted {
            Ok(x) => x,
            Err(_) => {
                // Out of file descriptors or similar; back off briefly.
                tokio::time::sleep(Duration::from_millis(100)).await;
                continue;
            }
        };
        let _ = stream.set_nodelay(true);
        match guard.admit(peer.ip(), Instant::now()) {
            Ok(permit) => {
                let cfg = cfg.clone();
                let registry = registry.clone();
                let active = guard.active();
                tokio::spawn(async move {
                    eprintln!("connect {} active={}", peer.ip(), active);
                    let started = Instant::now();
                    let reason = serve(stream, peer, &cfg, registry).await;
                    eprintln!(
                        "disconnect {} secs={} reason={}",
                        peer.ip(),
                        started.elapsed().as_secs(),
                        reason
                    );
                    drop(permit);
                });
            }
            Err(why) => {
                eprintln!("limit {} {}", peer.ip(), why.as_str());
                tokio::spawn(async move {
                    let mut stream = stream;
                    let _ = timeout(
                        Duration::from_secs(2),
                        stream.write_all(b"No Free Sessions\r\n"),
                    )
                    .await;
                });
            }
        }
    }
    eprintln!("demo BBS stopping");
}

/// Runs one session to its end and says why it ended.
async fn serve(
    stream: TcpStream,
    peer: SocketAddr,
    cfg: &Config,
    registry: Arc<Registry>,
) -> &'static str {
    let mut session = Session::new(registry, peer.ip(), cfg.session.clone());
    let reason = run(stream, peer, cfg, &mut session).await;
    // The sandbox's idle time starts now.
    session.end(Instant::now());
    reason
}

async fn run(
    mut stream: TcpStream,
    peer: SocketAddr,
    cfg: &Config,
    session: &mut Session,
) -> &'static str {
    let mut reader = LineReader::new(cfg.max_line);
    let mut buf = vec![0u8; 4096];
    let mut lines: Vec<Line> = Vec::new();
    let started = Instant::now();
    let end_of_life = started + Duration::from_secs(cfg.session_secs);
    let login_by = started + Duration::from_secs(cfg.login_secs);
    // Only a complete line counts as activity, so a trickle of bytes
    // without a line end does not keep a session alive.
    let mut last_line = Instant::now();

    let limit = |what: &'static str| {
        eprintln!("limit {} {}", peer.ip(), what);
        what
    };

    loop {
        let mut deadline = (last_line + Duration::from_secs(cfg.idle_secs)).min(end_of_life);
        if !session.in_bbs() {
            deadline = deadline.min(login_by);
        }
        let now = Instant::now();
        if now >= deadline {
            let what = if now >= end_of_life {
                "session lifetime"
            } else if !session.in_bbs() && now >= login_by {
                "login time"
            } else {
                "idle time"
            };
            let _ = timeout(
                Duration::from_secs(2),
                stream.write_all(b"\rDemo session timed out\r"),
            )
            .await;
            return limit(what);
        }
        let n = match timeout(deadline - now, stream.read(&mut buf)).await {
            Err(_) => continue, // the deadline check above says which
            Ok(Err(_)) => return "error",
            Ok(Ok(0)) => return "closed by client",
            Ok(Ok(n)) => n,
        };
        if let Some(what) = session.count_bytes(n, 0) {
            let _ = timeout(
                Duration::from_secs(2),
                stream.write_all(b"\rDemo session limit reached\r"),
            )
            .await;
            return limit(what);
        }
        reader.push(&buf[..n], &mut lines);
        for line in lines.drain(..) {
            last_line = Instant::now();
            if line.truncated {
                limit("line length");
            }
            let reply = session.handle(&line.bytes, Now::system());
            if let Some(what) = reply.limit {
                limit(what);
            }
            if let Some(what) = session.count_bytes(0, reply.out.len()) {
                let _ = timeout(
                    Duration::from_secs(2),
                    stream.write_all(b"\rDemo session limit reached\r"),
                )
                .await;
                return limit(what);
            }
            if !reply.out.is_empty() {
                // A client that stops reading cannot hold the session open.
                match timeout(Duration::from_secs(30), stream.write_all(&reply.out)).await {
                    Ok(Ok(())) => {}
                    _ => return "write stalled",
                }
            }
            if reply.close {
                let _ = stream.shutdown().await;
                return "logged off";
            }
        }
    }
}
