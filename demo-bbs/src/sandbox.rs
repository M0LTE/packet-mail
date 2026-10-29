//! Visitor sandboxes: a private copy of the demo mail per source address and
//! login, held in memory so the app's separate connections (sync, open a
//! message, delete) see one consistent mailbox. A sandbox is dropped a while
//! after its last connection ends, and at a hard maximum age. Nothing is ever
//! written to disk.

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::guard::address_key;
use crate::mail::{Mailbox, BBS_HOME};
use crate::seed::seed;

/// One visitor's state, shared by all of that visitor's connections.
#[derive(Default)]
pub struct Sandbox {
    pub mail: Mailbox,
    pub name: Vec<u8>,
    pub home: String,
    pub last_listed: i64,
    /// Messages sent, and bytes in and out, over all its connections.
    pub sent: usize,
    pub bytes_in: usize,
    pub bytes_out: usize,
}

impl Sandbox {
    pub fn new(unix_now: i64) -> Self {
        let mail = seed(unix_now);
        // A new BPQ user's "last listed" starts 20 behind the latest message.
        let last_listed = mail.latest() as i64 - 20;
        Sandbox {
            mail,
            name: Vec::new(),
            home: BBS_HOME.into(),
            last_listed,
            ..Default::default()
        }
    }
}

#[derive(Clone, Debug)]
pub struct RegistryLimits {
    /// Sandboxes held at once.
    pub max_sandboxes: usize,
    /// How long a sandbox is kept after its last connection ends.
    pub keep_idle: Duration,
    /// Oldest a sandbox may get, however busy.
    pub max_age: Duration,
}

impl Default for RegistryLimits {
    fn default() -> Self {
        RegistryLimits {
            max_sandboxes: 200,
            keep_idle: Duration::from_secs(30 * 60),
            max_age: Duration::from_secs(2 * 60 * 60),
        }
    }
}

type Key = (IpAddr, Vec<u8>);

struct Entry {
    sandbox: Arc<Mutex<Sandbox>>,
    created: Instant,
    active: usize,
    last_end: Instant,
}

/// The registry is full and every sandbox in it is in use.
#[derive(Debug, PartialEq, Eq)]
pub struct Full;

pub struct Registry {
    limits: RegistryLimits,
    entries: Mutex<HashMap<Key, Entry>>,
}

/// One connection's hold on a sandbox. Release it when the connection ends.
pub struct Lease {
    pub sandbox: Arc<Mutex<Sandbox>>,
    key: Key,
    registry: Arc<Registry>,
    released: bool,
}

impl Lease {
    pub fn release(mut self, now: Instant) {
        self.release_at(now);
    }

    fn release_at(&mut self, now: Instant) {
        if self.released {
            return;
        }
        self.released = true;
        let mut map = self
            .registry
            .entries
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        if let Some(e) = map.get_mut(&self.key) {
            // Only if the entry is still ours, not a newer one for the same key.
            if Arc::ptr_eq(&e.sandbox, &self.sandbox) {
                e.active = e.active.saturating_sub(1);
                e.last_end = now;
            }
        }
    }
}

impl Drop for Lease {
    fn drop(&mut self) {
        self.release_at(Instant::now());
    }
}

impl Registry {
    pub fn new(limits: RegistryLimits) -> Arc<Self> {
        Arc::new(Registry {
            limits,
            entries: Mutex::new(HashMap::new()),
        })
    }

    pub fn len(&self) -> usize {
        self.entries.lock().unwrap_or_else(|e| e.into_inner()).len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// The sandbox for this address and login, made fresh if there is none.
    pub fn acquire(
        self: &Arc<Self>,
        ip: IpAddr,
        user: &[u8],
        now: Instant,
        unix_now: i64,
    ) -> Result<Lease, Full> {
        let key: Key = (address_key(ip), user.to_vec());
        let mut map = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        let l = &self.limits;
        let too_old = |e: &Entry| now.saturating_duration_since(e.created) >= l.max_age;
        map.retain(|_, e| {
            e.active > 0 || (now.saturating_duration_since(e.last_end) < l.keep_idle && !too_old(e))
        });

        if let Some(e) = map.get_mut(&key) {
            if !too_old(e) {
                e.active += 1;
                return Ok(self.lease(key, e.sandbox.clone()));
            }
            // Too old but still in use: its connections keep their copy; this one starts afresh.
            map.remove(&key);
        }
        if map.len() >= l.max_sandboxes {
            let oldest_idle = map
                .iter()
                .filter(|(_, e)| e.active == 0)
                .min_by_key(|(_, e)| e.last_end)
                .map(|(k, _)| k.clone());
            match oldest_idle {
                Some(k) => {
                    map.remove(&k);
                }
                None => return Err(Full),
            }
        }
        let sandbox = Arc::new(Mutex::new(Sandbox::new(unix_now)));
        map.insert(
            key.clone(),
            Entry {
                sandbox: sandbox.clone(),
                created: now,
                active: 1,
                last_end: now,
            },
        );
        Ok(self.lease(key, sandbox))
    }

    fn lease(self: &Arc<Self>, key: Key, sandbox: Arc<Mutex<Sandbox>>) -> Lease {
        Lease {
            sandbox,
            key,
            registry: self.clone(),
            released: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const UNIX: i64 = 1_793_196_300;

    fn registry(max: usize) -> Arc<Registry> {
        Registry::new(RegistryLimits {
            max_sandboxes: max,
            keep_idle: Duration::from_secs(1800),
            max_age: Duration::from_secs(7200),
        })
    }

    fn ip(s: &str) -> IpAddr {
        s.parse().unwrap()
    }

    #[test]
    fn same_key_shares_and_expires_after_idle() {
        let r = registry(10);
        let t = Instant::now();
        let a = r.acquire(ip("192.0.2.1"), b"demo", t, UNIX).unwrap();
        a.sandbox.lock().unwrap().sent = 3;
        a.release(t);
        let b = r
            .acquire(
                ip("192.0.2.1"),
                b"demo",
                t + Duration::from_secs(1799),
                UNIX,
            )
            .unwrap();
        assert_eq!(b.sandbox.lock().unwrap().sent, 3);
        b.release(t + Duration::from_secs(1799));
        let c = r
            .acquire(
                ip("192.0.2.1"),
                b"demo",
                t + Duration::from_secs(1799 + 1800),
                UNIX,
            )
            .unwrap();
        assert_eq!(c.sandbox.lock().unwrap().sent, 0);
    }

    #[test]
    fn different_keys_never_share() {
        let r = registry(10);
        let t = Instant::now();
        let a = r.acquire(ip("192.0.2.1"), b"demo", t, UNIX).unwrap();
        let b = r.acquire(ip("192.0.2.2"), b"demo", t, UNIX).unwrap();
        let c = r.acquire(ip("192.0.2.1"), b"other", t, UNIX).unwrap();
        assert!(!Arc::ptr_eq(&a.sandbox, &b.sandbox));
        assert!(!Arc::ptr_eq(&a.sandbox, &c.sandbox));
        // IPv6 addresses in one /64 are one visitor.
        let d = r.acquire(ip("2001:db8::1"), b"demo", t, UNIX).unwrap();
        let e = r.acquire(ip("2001:db8::2"), b"demo", t, UNIX).unwrap();
        assert!(Arc::ptr_eq(&d.sandbox, &e.sandbox));
    }

    #[test]
    fn hard_maximum_age_even_when_busy() {
        let r = registry(10);
        let t = Instant::now();
        let a = r.acquire(ip("192.0.2.1"), b"demo", t, UNIX).unwrap();
        let b = r
            .acquire(
                ip("192.0.2.1"),
                b"demo",
                t + Duration::from_secs(7200),
                UNIX,
            )
            .unwrap();
        assert!(!Arc::ptr_eq(&a.sandbox, &b.sandbox));
        // The old connection ending does not disturb the new sandbox.
        a.release(t + Duration::from_secs(7201));
        let c = r
            .acquire(
                ip("192.0.2.1"),
                b"demo",
                t + Duration::from_secs(7202),
                UNIX,
            )
            .unwrap();
        assert!(Arc::ptr_eq(&b.sandbox, &c.sandbox));
    }

    #[test]
    fn full_evicts_oldest_idle_or_refuses() {
        let r = registry(2);
        let t = Instant::now();
        let a = r.acquire(ip("192.0.2.1"), b"demo", t, UNIX).unwrap();
        let b = r.acquire(ip("192.0.2.2"), b"demo", t, UNIX).unwrap();
        assert!(r.acquire(ip("192.0.2.3"), b"demo", t, UNIX).is_err());
        let a_box = a.sandbox.clone();
        a.release(t + Duration::from_secs(5));
        b.release(t + Duration::from_secs(10));
        let _c = r
            .acquire(ip("192.0.2.3"), b"demo", t + Duration::from_secs(20), UNIX)
            .unwrap();
        assert_eq!(r.len(), 2);
        // a was the oldest idle one, so it went; b is still there.
        let b2 = r
            .acquire(ip("192.0.2.2"), b"demo", t + Duration::from_secs(21), UNIX)
            .unwrap();
        assert_eq!(r.len(), 2);
        drop(b2);
        let a2 = r.acquire(ip("192.0.2.1"), b"demo", t + Duration::from_secs(22), UNIX);
        assert!(a2.is_ok_and(|l| !Arc::ptr_eq(&l.sandbox, &a_box)));
    }
}
