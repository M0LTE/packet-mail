# Test BBS

A throwaway LinBPQ for recordings and end-to-end tests, using Tom's published image. Not on air: telnet only. Callsigns use the unallocated Q0 prefix; the passwords are the user names.

```
./run.sh        # starts it on 127.0.0.1, FBB port 18011, telnet 18010, web 18008
docker rm -f packet-mail-test-bbs
```

Users: `sysop` (Q0SYS, SYSOP), `user` (Q0USR) and `other` (Q0OTH), normal users.

`./record-all.sh` records the standard scenario (new users, personal and bulletin send, cancel, read, kill, White Pages, telnet port) into `packages/mail_core/test/fixtures/bpq-local/`. Start a fresh BBS first: message numbers depend on it.

`linmail.cfg` is LinBPQ's default with `DontHoldNewUsers = 1` (otherwise a new user's mail is held where nobody can see it) and `SYSOPCall = "Q0SYS"`. It must not contain any `BBSUsers` entries beyond the BBS itself, or state leaks between runs.

The driver's live tests also run against it: `PACKET_MAIL_TEST_BBS=1 dart test test/driver_live_test.dart` in `packages/mail_core`, on a fresh BBS. Add `RECORD_FIXTURES=1` to refresh the recordings the replay test uses; CI runs the live tests on every push.

## XRouter

`xrouter/` holds a test XRouter (G8PZT's node, from `ghcr.io/packethacking/xrouter`) whose built-in mailbox the XRouter driver talks to. Loopback only, no radio ports, telnet on 127.0.0.1:18023.

```
xrouter/run.sh        # starts a fresh one
xrouter/run.sh bbs    # and one set up as a full BBS (PMSTYPE=4), telnet on 127.0.0.1:18024
docker rm -f packet-mail-test-xrouter packet-mail-test-xrouter-bbs
```

Node `Q0XR`, users `Q0USR` (password `user`) and `Q0OTH` (`other`). `xrouter/record-all.sh` records the standard scenario into `packages/mail_core/test/fixtures/xrouter-local/`. The driver's live tests: `PACKET_MAIL_TEST_XROUTER=1 dart test test/xrouter_live_test.dart` in `packages/mail_core`, on a fresh XRouter of each kind, with `RECORD_FIXTURES=1` to refresh the replay recordings. See docs/xrouter-protocol.md.
