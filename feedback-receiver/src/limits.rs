use std::collections::{HashMap, VecDeque};
use std::net::IpAddr;
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// Addresses tracked at once. Past this, expired entries are dropped, and if
/// that isn't enough every new address is turned away until some expire.
const MAX_TRACKED: usize = 100_000;

/// Sliding-window limits: so many per address, and so many overall, per window.
pub struct RateLimiter {
    window: Duration,
    per_ip: u32,
    global: u32,
    inner: Mutex<Inner>,
}

#[derive(Default)]
struct Inner {
    by_ip: HashMap<IpAddr, VecDeque<Instant>>,
    global: VecDeque<Instant>,
}

/// The address a limit counts against: IPv6 by /64, since one user usually
/// has a whole /64.
pub fn limit_key(ip: IpAddr) -> IpAddr {
    match ip {
        IpAddr::V4(_) => ip,
        IpAddr::V6(v6) => match v6.to_ipv4_mapped() {
            Some(v4) => IpAddr::V4(v4),
            None => {
                let s = v6.segments();
                IpAddr::V6([s[0], s[1], s[2], s[3], 0, 0, 0, 0].into())
            }
        },
    }
}

fn expire(q: &mut VecDeque<Instant>, now: Instant, window: Duration) {
    while q.front().is_some_and(|t| now.duration_since(*t) >= window) {
        q.pop_front();
    }
}

fn retry_after(q: &VecDeque<Instant>, now: Instant, window: Duration) -> Duration {
    q.front()
        .map_or(window, |t| window.saturating_sub(now.duration_since(*t)))
}

impl RateLimiter {
    pub fn new(window: Duration, per_ip: u32, global: u32) -> RateLimiter {
        RateLimiter {
            window,
            per_ip,
            global,
            inner: Mutex::new(Inner::default()),
        }
    }

    /// Counts a request from [ip]. Err holds how long until it would be let in.
    pub fn check_ip(&self, ip: IpAddr, now: Instant) -> Result<(), Duration> {
        let key = limit_key(ip);
        let mut inner = self.inner.lock().unwrap();
        if inner.by_ip.len() >= MAX_TRACKED && !inner.by_ip.contains_key(&key) {
            let window = self.window;
            inner.by_ip.retain(|_, q| {
                expire(q, now, window);
                !q.is_empty()
            });
            if inner.by_ip.len() >= MAX_TRACKED {
                return Err(self.window);
            }
        }
        let q = inner.by_ip.entry(key).or_default();
        expire(q, now, self.window);
        if q.len() >= self.per_ip as usize {
            return Err(retry_after(q, now, self.window));
        }
        q.push_back(now);
        Ok(())
    }

    /// Counts one report against the overall limit.
    pub fn check_global(&self, now: Instant) -> Result<(), Duration> {
        let mut inner = self.inner.lock().unwrap();
        let q = &mut inner.global;
        expire(q, now, self.window);
        if q.len() >= self.global as usize {
            return Err(retry_after(q, now, self.window));
        }
        q.push_back(now);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const HOUR: Duration = Duration::from_secs(3600);

    #[test]
    fn per_ip_limit_and_window() {
        let r = RateLimiter::new(HOUR, 2, 100);
        let t = Instant::now();
        let a: IpAddr = "192.0.2.1".parse().unwrap();
        let b: IpAddr = "192.0.2.2".parse().unwrap();
        assert!(r.check_ip(a, t).is_ok());
        assert!(r.check_ip(a, t + Duration::from_secs(10)).is_ok());
        assert_eq!(
            r.check_ip(a, t + Duration::from_secs(20)),
            Err(HOUR - Duration::from_secs(20))
        );
        assert!(r.check_ip(b, t).is_ok());
        assert!(r.check_ip(a, t + HOUR).is_ok());
    }

    #[test]
    fn ipv6_counts_by_64() {
        let r = RateLimiter::new(HOUR, 1, 100);
        let t = Instant::now();
        assert!(r.check_ip("2001:db8:1:2::1".parse().unwrap(), t).is_ok());
        assert!(r
            .check_ip("2001:db8:1:2::ffff".parse().unwrap(), t)
            .is_err());
        assert!(r.check_ip("2001:db8:1:3::1".parse().unwrap(), t).is_ok());
    }

    #[test]
    fn mapped_ipv4_is_ipv4() {
        assert_eq!(
            limit_key("::ffff:192.0.2.1".parse().unwrap()),
            "192.0.2.1".parse::<IpAddr>().unwrap()
        );
    }

    #[test]
    fn global_limit() {
        let r = RateLimiter::new(HOUR, 10, 2);
        let t = Instant::now();
        assert!(r.check_global(t).is_ok());
        assert!(r.check_global(t).is_ok());
        assert!(r.check_global(t).is_err());
        assert!(r.check_global(t + HOUR).is_ok());
    }
}
