//! Admission control: connections overall, per source address, and per
//! source address per minute. IPv6 addresses count per /64.

use std::collections::{HashMap, VecDeque};
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone, Debug)]
pub struct GuardLimits {
    pub max_connections: usize,
    pub max_per_ip: usize,
    pub connects_per_minute: usize,
}

/// Why a connection was turned away.
#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Refusal {
    Full,
    PerIp,
    Rate,
}

impl Refusal {
    pub fn as_str(self) -> &'static str {
        match self {
            Refusal::Full => "connections overall",
            Refusal::PerIp => "connections per address",
            Refusal::Rate => "connection rate per address",
        }
    }
}

const WINDOW: Duration = Duration::from_secs(60);
/// Addresses remembered at once; beyond this, idle entries are pruned.
const MAX_TRACKED: usize = 10_000;

#[derive(Default)]
struct Entry {
    active: usize,
    recent: VecDeque<Instant>,
}

#[derive(Default)]
struct State {
    total: usize,
    per_ip: HashMap<IpAddr, Entry>,
}

#[derive(Clone)]
pub struct Guard {
    limits: GuardLimits,
    state: Arc<Mutex<State>>,
}

/// Held for the life of a connection; frees its slot when dropped.
pub struct Permit {
    key: IpAddr,
    state: Arc<Mutex<State>>,
}

impl Drop for Permit {
    fn drop(&mut self) {
        let mut s = self.state.lock().unwrap_or_else(|e| e.into_inner());
        s.total = s.total.saturating_sub(1);
        if let Some(e) = s.per_ip.get_mut(&self.key) {
            e.active = e.active.saturating_sub(1);
        }
    }
}

fn key(ip: IpAddr) -> IpAddr {
    match ip {
        IpAddr::V6(v6) => match v6.to_ipv4_mapped() {
            Some(v4) => IpAddr::V4(v4),
            None => {
                let s = v6.segments();
                IpAddr::V6(std::net::Ipv6Addr::new(s[0], s[1], s[2], s[3], 0, 0, 0, 0))
            }
        },
        v4 => v4,
    }
}

impl Guard {
    pub fn new(limits: GuardLimits) -> Self {
        Guard {
            limits,
            state: Arc::new(Mutex::new(State::default())),
        }
    }

    pub fn active(&self) -> usize {
        self.state.lock().unwrap_or_else(|e| e.into_inner()).total
    }

    pub fn admit(&self, ip: IpAddr, now: Instant) -> Result<Permit, Refusal> {
        let k = key(ip);
        let mut s = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if s.per_ip.len() >= MAX_TRACKED && !s.per_ip.contains_key(&k) {
            s.per_ip.retain(|_, e| {
                e.active > 0
                    || e.recent
                        .back()
                        .is_some_and(|t| now.duration_since(*t) < WINDOW)
            });
        }
        if s.total >= self.limits.max_connections
            || (s.per_ip.len() >= MAX_TRACKED && !s.per_ip.contains_key(&k))
        {
            return Err(Refusal::Full);
        }
        let limits = self.limits.clone();
        let e = s.per_ip.entry(k).or_default();
        while e
            .recent
            .front()
            .is_some_and(|t| now.duration_since(*t) >= WINDOW)
        {
            e.recent.pop_front();
        }
        if e.active >= limits.max_per_ip {
            return Err(Refusal::PerIp);
        }
        if e.recent.len() >= limits.connects_per_minute {
            return Err(Refusal::Rate);
        }
        e.active += 1;
        e.recent.push_back(now);
        s.total += 1;
        Ok(Permit {
            key: k,
            state: self.state.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn guard() -> Guard {
        Guard::new(GuardLimits {
            max_connections: 3,
            max_per_ip: 2,
            connects_per_minute: 3,
        })
    }

    #[test]
    fn per_ip_total_and_rate() {
        let g = guard();
        let t = Instant::now();
        let a: IpAddr = "192.0.2.1".parse().unwrap();
        let b: IpAddr = "192.0.2.2".parse().unwrap();
        let p1 = g.admit(a, t).unwrap();
        let _p2 = g.admit(a, t).unwrap();
        assert_eq!(g.admit(a, t).err(), Some(Refusal::PerIp));
        let _p3 = g.admit(b, t).unwrap();
        assert_eq!(g.admit(b, t).err(), Some(Refusal::Full));
        drop(p1);
        assert_eq!(g.active(), 2);
        let p4 = g.admit(a, t).unwrap();
        drop(p4);
        assert_eq!(g.admit(a, t).err(), Some(Refusal::Rate));
        assert!(g.admit(a, t + WINDOW).is_ok());
    }

    #[test]
    fn ipv6_counts_per_64() {
        let g = guard();
        let t = Instant::now();
        let _a = g.admit("2001:db8::1".parse().unwrap(), t).unwrap();
        let _b = g.admit("2001:db8::2".parse().unwrap(), t).unwrap();
        assert_eq!(
            g.admit("2001:db8::3".parse().unwrap(), t).err(),
            Some(Refusal::PerIp)
        );
    }
}
