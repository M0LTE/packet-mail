//! BPQ-style dates from Unix seconds, always UTC. No date crate needed.

const MONTHS: [&str; 12] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/// (year, month 1-12, day, hour, minute) for Unix seconds.
pub fn civil(secs: i64) -> (i64, u32, u32, u32, u32) {
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    let year = yoe + era * 400 + if month <= 2 { 1 } else { 0 };
    (
        year,
        month,
        day,
        (rem / 3600) as u32,
        ((rem % 3600) / 60) as u32,
    )
}

/// `28-Oct`, as in a listing.
pub fn day_month(secs: i64) -> String {
    let (_, m, d, _, _) = civil(secs);
    format!("{:02}-{}", d, MONTHS[m as usize - 1])
}

/// `28-Oct 14:05Z`, as in a read header.
pub fn day_month_time(secs: i64) -> String {
    let (_, m, d, h, min) = civil(secs);
    format!("{:02}-{} {:02}:{:02}Z", d, MONTHS[m as usize - 1], h, min)
}

/// `261028/1405Z`, as in an R: routing line.
pub fn routing_stamp(secs: i64) -> String {
    let (y, m, d, h, min) = civil(secs);
    format!("{:02}{:02}{:02}/{:02}{:02}Z", y % 100, m, d, h, min)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_dates() {
        // 2026-10-28 14:05 UTC
        let t = 1_793_196_300;
        assert_eq!(civil(t), (2026, 10, 28, 14, 5));
        assert_eq!(day_month(t), "28-Oct");
        assert_eq!(day_month_time(t), "28-Oct 14:05Z");
        assert_eq!(routing_stamp(t), "261028/1405Z");
        assert_eq!(civil(0), (1970, 1, 1, 0, 0));
        assert_eq!(day_month(951_782_400), "29-Feb"); // 2000-02-29
    }
}
