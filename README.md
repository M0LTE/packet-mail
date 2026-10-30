# Packet Mail

Packet radio BBS mail on your phone, for iPhone and Android.

Packet Mail gives BBS mail the feel of an ordinary email client: an inbox, outbox and sent items, a bulletins browser and an address book. You add a connection to your BBS much as you would add an account to a mail app, and the app works the same whichever kind of connection it is.

It talks to LinBPQ (BPQMail) over your network, through either its telnet port or its FBB port, and to the mailbox built into an XRouter node through its telnet port. Later connection types may run over the packet network itself, or talk to other BBS software.

**Status:** in testing. On Android, install the APK from the [latest release](https://github.com/m0lte/packet-mail/releases/latest); iPhone builds go to TestFlight testers.

## Documents

- [Plan](docs/plan.md): what we're building and the decisions behind it.
- [AGENTS.md](AGENTS.md): how the project is worked on (for people and coding agents).
- [Releasing](docs/releasing.md): how to tag a release for TestFlight and Android.
- [Look and feel options](docs/look-and-feel/options.png)

## Building

You need [Flutter](https://docs.flutter.dev/get-started/install) (see `FLUTTER_VERSION` in `.github/workflows/ci.yml`).

```
flutter pub get
flutter test
(cd packages/mail_core && dart test)
flutter run
```

Every push to `master` builds an Android APK and an unsigned iOS app; find them under the Actions tab.

## Layout

- `lib/`: the Flutter app (screens).
- `packages/mail_core/`: everything below the screens (messages, addressing, BBS drivers, sync), in plain Dart with no Flutter dependency.
- `docs/`: plan and design notes, including the [BPQMail protocol reference](docs/bpq-protocol.md) and the [XRouter mailbox reference](docs/xrouter-protocol.md).
- `test-bbs/`: a local LinBPQ and a local XRouter for recordings and tests.

## Licence

[Mozilla Public License 2.0](LICENSE).

## Test BBS

`test-bbs/` runs a throwaway LinBPQ in Docker for recordings and end-to-end tests; see its README.

## Test builds

Pushing a version tag such as `v0.2.0` uploads a build to TestFlight and makes a signed Android bundle, with the tag as the version name. Pushes to `master` only build and test. See [Releasing](docs/releasing.md) for the steps.
