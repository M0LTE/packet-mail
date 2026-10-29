//! Splits incoming bytes into lines the way BPQMail does: CR, LF or CRLF all
//! end a line. A line longer than the limit keeps only its first bytes, so a
//! client can never make us buffer more than the limit.

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Line {
    pub bytes: Vec<u8>,
    /// True when the line was cut at the limit.
    pub truncated: bool,
}

pub struct LineReader {
    buf: Vec<u8>,
    max: usize,
    truncated: bool,
    after_cr: bool,
}

impl LineReader {
    pub fn new(max: usize) -> Self {
        LineReader {
            buf: Vec::new(),
            max: max.max(1),
            truncated: false,
            after_cr: false,
        }
    }

    /// Feeds bytes in and appends every completed line to `out`.
    pub fn push(&mut self, data: &[u8], out: &mut Vec<Line>) {
        for &b in data {
            if b == b'\n' && self.after_cr {
                self.after_cr = false;
                continue;
            }
            self.after_cr = b == b'\r';
            if b == b'\r' || b == b'\n' {
                out.push(Line {
                    bytes: std::mem::take(&mut self.buf),
                    truncated: self.truncated,
                });
                self.truncated = false;
            } else if self.buf.len() < self.max {
                self.buf.push(b);
            } else {
                self.truncated = true;
            }
        }
    }

    /// Bytes waiting for a line end.
    pub fn pending(&self) -> usize {
        self.buf.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    fn lines(chunks: &[&[u8]], max: usize) -> Vec<Vec<u8>> {
        let mut r = LineReader::new(max);
        let mut out = Vec::new();
        for c in chunks {
            r.push(c, &mut out);
        }
        out.into_iter().map(|l| l.bytes).collect()
    }

    #[test]
    fn all_line_ends() {
        assert_eq!(
            lines(&[b"a\rb\nc\r\nd\r"], 10),
            vec![b"a".to_vec(), b"b".to_vec(), b"c".to_vec(), b"d".to_vec()]
        );
        assert_eq!(
            lines(&[b"a\r", b"\nb\r"], 10),
            vec![b"a".to_vec(), b"b".to_vec()]
        );
        assert_eq!(lines(&[b"\r\r"], 10), vec![b"".to_vec(), b"".to_vec()]);
        assert_eq!(lines(&[b"\n\r"], 10), vec![b"".to_vec(), b"".to_vec()]);
    }

    #[test]
    fn long_lines_are_cut() {
        let mut r = LineReader::new(4);
        let mut out = Vec::new();
        r.push(b"abcdefgh\rxy\r", &mut out);
        assert_eq!(
            out[0],
            Line {
                bytes: b"abcd".to_vec(),
                truncated: true
            }
        );
        assert_eq!(
            out[1],
            Line {
                bytes: b"xy".to_vec(),
                truncated: false
            }
        );
        r.push(&[b'z'; 10_000], &mut out);
        assert_eq!(r.pending(), 4);
    }

    proptest! {
        #[test]
        fn never_over_the_limit_and_chunking_does_not_matter(
            data in proptest::collection::vec(prop_oneof![Just(b'\r'), Just(b'\n'), any::<u8>()], 0..2000),
            split in 0usize..2000,
            max in 1usize..64,
        ) {
            let split = split.min(data.len());
            let whole = lines(&[&data], max);
            let parts = lines(&[&data[..split], &data[split..]], max);
            prop_assert_eq!(&whole, &parts);
            for l in &whole {
                prop_assert!(l.len() <= max);
                prop_assert!(!l.contains(&b'\r') && !l.contains(&b'\n'));
            }
        }
    }
}
