#!/bin/bash
# Records the standard scenario against a freshly started test XRouter into
# packages/mail_core/test/fixtures/xrouter-local/. Run ./run.sh first.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
out=$root/packages/mail_core/test/fixtures/xrouter-local
mkdir -p "$out"
cd "$root/packages/mail_core"
rec() { name=$1; shift; dart run bin/record.dart 127.0.0.1 18023 "$out/$name.jsonl" "$@" >/dev/null; echo "recorded $name"; }

# Telnet login, the PMS command, its help and paging.
rec login Q0USR user PMS NP 'NP 0' NP '? **' NI B B
rec bad-password Q0USR wrong
rec bad-callsign NOTACALL

# user sends a local personal message, one for another BBS and a bulletin,
# cancels two, then lists.
rec user-send Q0USR user PMS 'NP 0' \
  'SP Q0OTH' 'Hello from user' 'First line' '' 'Third line after a blank.' '/EX' \
  'SP Q0OTH @ GB7XYZ.#42.GBR.EURO' 'For another BBS' 'Body.' '/EX' \
  'SB ALL @ GBR' 'Test bulletin' 'Bulletin body.' '/EX' \
  'SP Q0OTH' '' \
  'SP Q0OTH' 'Abandoned' 'Some text' '/QQ' \
  L LB 'L< Q0USR' M LM B B

# Which body lines end or abort a message, and which are just text.
rec body-lines Q0USR user PMS 'NP 0' 'SP Q0OTH' 'Body lines' \
  '/EX  ' '  /ex' '/exit' '/QQ ' 'R:261029/0000Z @:GB7AAA' 'Date: x' 'SP Q0ZZZ' '[1] prompt look-alike >' '/ex' \
  'R 4' B B

# other reads and kills the local message, reads the bulletin, tries to kill
# it and user's remote message, and looks people up.
rec other-read-kill Q0OTH other PMS 'NP 0' LM LN 'R 1' 'RH 1' LM 'K 1' 'K 1' 'R 1' \
  LB 'RH 3' 'K 3' 'RH 2' 'K 2' 'U 2' LN 'I Q0USR' 'I G8PZT' 'NH Q0XR' 'I Q0OTH' B B

# user sees what is left, kills own bulletin, and tries a BID.
rec user-after Q0USR user PMS 'NP 0' 'L< Q0USR' LB 'K 3' LB 'SP Q0OTH $BID123'
