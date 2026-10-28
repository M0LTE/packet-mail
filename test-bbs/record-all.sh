#!/bin/bash
# Records the standard scenario against a freshly started test BBS into
# packages/mail_core/test/fixtures/bpq-local/. Run ./run.sh first.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/packages/mail_core/test/fixtures/bpq-local
mkdir -p "$out"
cd "$root/packages/mail_core"
rec() { name=$1; shift; dart run bin/record.dart 127.0.0.1 "${PORT:-18011}" "$out/$name.jsonl" "$@" >/dev/null; echo "recorded $name"; }

# A new user: name prompt, then home BBS.
rec user-first-login user user BBS 'Tom User' 'HOMEBBS Q0TST.#42.GBR.EURO' B
rec other-first-login other other BBS 'Olive Other' 'HOMEBBS Q0TST.#42.GBR.EURO' B

# user sends a personal message, a bulletin, cancels one, and lists.
rec user-send user user BBS \
  'SP Q0OTH@Q0TST.#42.GBR.EURO' 'Hello from user' 'First line' '' 'Third line after a blank.' '/EX' \
  'SB ALL@GBR' 'Test bulletin' 'Bulletin body.' '/EX' \
  'SP Q0OTH' '' \
  LM LB L B

# other reads and kills the personal message, reads the bulletin, tries to kill it.
# Messages 1 and 2 are the BBS's own new-user notices to the sysop, so user's mail is 3 and 4.
rec other-read-kill other other BBS LM LN 'LL 5' 'R 3' LM 'K 3' 'K 3' LB 'R 4' LN 'K 4' 'R 1' 'I Q0USR' B

# user sees the bulletin but not other's killed mail, then kills own bulletin.
rec user-after user user BBS LM LB 'R 3' 'R 4' 'K 4' LB B

# The plain telnet port, for comparison: telnet negotiation, prompts and CRLF line ends.
PORT=18010 rec telnet-login user user BBS LB B B
