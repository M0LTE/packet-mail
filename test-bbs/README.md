# Test BBS

A throwaway LinBPQ for recordings and end-to-end tests, using Tom's published image. Not on air: telnet only. Callsigns use the unallocated Q0 prefix; the passwords are the user names.

```
./run.sh        # starts it on 127.0.0.1, FBB port 18011, telnet 18010, web 18008
docker rm -f packet-mail-test-bbs
```

Users: `sysop` (Q0SYS, SYSOP), `user` (Q0USR) and `other` (Q0OTH), normal users.

`./record-all.sh` records the standard scenario (new users, personal and bulletin send, cancel, read, kill, White Pages, telnet port) into `packages/mail_core/test/fixtures/bpq-local/`. Start a fresh BBS first: message numbers depend on it.

`linmail.cfg` is LinBPQ's default with `DontHoldNewUsers = 1` (otherwise a new user's mail is held where nobody can see it) and `SYSOPCall = "Q0SYS"`. It must not contain any `BBSUsers` entries beyond the BBS itself, or state leaks between runs.
