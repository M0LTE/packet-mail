# Working on Packet Mail

How this project is built and run, for coding agents and anyone else picking it up. Read this first, then `docs/plan.md`.

## The project

- **What it is:** a Flutter phone app (iPhone and Android) for packet radio BBS mail, with an ordinary email feel. Owner: Tom, M0LTE. Licence MPL-2.0.
- **Layout:**
  - `lib/`: the app's screens.
  - `packages/mail_core/`: everything below the screens, in plain Dart with no Flutter dependency (addresses, drivers, transports, store, sync).
  - `test-bbs/`: local LinBPQ and XRouter in Docker.
  - `demo-bbs/`: the public demo BBS, in Rust.
  - `feedback-receiver/`: the problem-report endpoint, in Rust.
  - `site/`: the website.
  - `docs/`: plan, protocol notes, deployment, releasing, store material.
- **Decisions live in `docs/plan.md`,** `docs/push-design.md` and the issues. Don't reopen a decision Tom has made; if something seems wrong, say so and ask.

## Ground rules

- **No em dashes or en dashes, anywhere:** code, comments, UI text, docs, commits, issue text. Use a hyphen, comma, semicolon or a new sentence. Output that can reach a terminal stays plain ASCII.
- **User-facing text is plain, friendly and short:** one line saying what's wrong and what to do. No jargon.
- **No settings Tom didn't ask for.** Pick sensible fixed behaviour instead. The agreed exceptions are listed in the plan (for example, when personal mail downloads).
- **Match the code around you:** naming, comment density and idiom. Visual work follows the Logbook theme in `lib/theme.dart`.
- **Never commit secrets, passwords or tokens.** Recordings store `PASSWORD` in place of the real one; check before committing.
- **Never commit other people's private mail.** If a recording holds real personal mail, replace the body with neutral text and say so in the fixture's header comment.
- **Private feedback stays private.** TestFlight feedback and problem reports live in the private repo `m0lte/packet-mail-feedback`. Don't quote them or copy their screenshots into this public repo; refer to "TestFlight feedback" neutrally.

## BBS safety

- **BPQ matches commands by their first letter.** Never send free text at a BBS prompt: build every command from checked parts (callsigns, numbers, parsed addresses). `XYZZY` once toggled a real user's expert mode.
- **Reading a personal message marks it read on the BBS.** Listing doesn't, but BPQ's `L` moves the user's "last listed" marker. Think before reading or listing on anyone's real account.
- **Only connect to the local test BBSes (`test-bbs/`) or the demo BBS,** unless Tom says otherwise. GB7RDG is Tom's live node.
- **Escape body lines the BBS would act on mid-message.** See `docs/bpq-protocol.md` 9.5 and `docs/xrouter-protocol.md`.
- **XRouter:** never mention BPQ in anything that may reach Paula, G8PZT (XRouter's author), such as issues on packethacking repos.

## How work is done

- **Work through GitHub issues.** Each milestone has an epic, with stories attached as sub-issues (`gh api -X POST repos/m0lte/packet-mail/issues/<epic>/sub_issues -F sub_issue_id=<id>`). Tick checklists as items land, comment with findings, and close stories when done. Close an epic when all its stories are closed. Keep issues current so work can be handed over at any point.
- **Commit straight to `master`** in small, regular commits. When several agents work at once, each uses its own worktree: `git worktree add .claude/worktrees/<name> -b <name> origin/master`, then push with `git pull --rebase origin master && git push origin <name>:master`. Remove the worktree when finished. `.claude/` is ignored locally through `.git/info/exclude`.
- **Commit messages:** a short subject, then a body of unwrapped paragraphs (no hard wrapping), a `Refs #N` or `Closes #N`, and this trailer:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- **Review:** significant logic (sync, sending, drivers) gets a fresh reviewer that reads only, never the author. Findings go back to the author to fix, each with a regression test.
- **A bug fix comes with a test** that fails without the fix.

## Testing

- **Before every push:** `flutter analyze` is clean, and `flutter test` plus `cd packages/mail_core && dart test` pass. After pushing, check CI (`gh run list -L 1`, `gh run watch`) and fix anything red you caused.
- **Drivers are built from recordings of real sessions,** never from guesses:
  - Record with `dart run mail_core:record` in `packages/mail_core`.
  - Driver scenarios run live against `test-bbs/` and replayed from recordings. See `test-bbs/README.md` for running them and refreshing recordings (`RECORD_FIXTURES=1`).
  - Live tests need a fresh test BBS, because message numbers depend on it.
- **CI runs** the unit tests, the drivers against a real LinBPQ and a real XRouter, the demo BBS and the feedback receiver, and Android and iOS builds on every push.

## Releasing

- **Follow `docs/releasing.md`.** In short:
  - Pushes to `master` only build and test.
  - A release is a three-part tag (`v1.0.4`), placed on the full SHA of a commit whose CI is green.
  - The tag uploads to TestFlight, builds the signed Android bundle and APK, and publishes a GitHub release named the way the stores show it, for example "Packet Mail 1.0.3 (98)".
- **Never move or reuse a pushed tag.** If a release run fails, fix it on master and release the next version.
- **Tom has approved tagging releases without his review** once requested work is done and CI is green.

## Feedback

- TestFlight feedback is imported daily into `m0lte/packet-mail-feedback` (workflow "Import TestFlight feedback"; run it by hand to fetch now). In-app reports arrive there too, labelled `in-app`.
- To work feedback: read the issue and look at its screenshot, fix in this repo, then close the feedback issue with a short comment once the fix is on master with CI green.

## Servers

- `debian@packet-mail-app.m0lte.compute.oarc.uk` hosts three things:
  - the demo BBS, on port 8011
  - the feedback receiver, behind nginx with TLS
  - the website
- The web side is public as `https://packet-mail.m0lte.uk`, through an OARC load balancer.
- See `docs/deployment.md`. Redeploy the site with `./deploy-site.sh`.
- Tom has given standing permission to deploy the site and these services. Leave everything else on the box alone.

## Contacts and addresses

- **Public support address:** app-support@tomfanning.name. Use it in the privacy policy, the store forms and app text.
- **The App Store and Play store material** is in `docs/store/`.
