# Reply to App Review (Guideline 2.1, information needed)

Paste the reply below into App Store Connect, attach the screen recording, and put the same text in App Review Information, Notes.

---

**1. Screen recording**

Attached: a recording on an iPhone running the latest iOS. It starts at launch and shows first-run setup, connecting to our demo BBS, reading mail and bulletins, sending a message and receiving the automatic reply, the address book, and Report a problem.

The app has no account registration or deletion. Users sign in to an existing packet radio BBS that they already have an account on, run by its own operator; the app never creates accounts. It has no paid content and no in-app purchases.

**2. Purpose and audience**

Packet Mail is an email-style client for amateur (ham) radio packet BBSes. Packet radio bulletin board systems carry personal mail and bulletins between licensed radio amateurs over radio and the internet. Today they are used mostly through text terminals with typed commands. Packet Mail gives these users a familiar mail app instead: an inbox, sent items, a bulletins browser and an address book, with addresses checked as you type. The audience is licensed radio amateurs who already have an account on a packet BBS (LinBPQ or XRouter).

**3. How to access the main features**

The app needs a BBS to connect to, so we run a public demo BBS with sample content:

1. Launch the app. Enter the callsign Q0YOU, any name, and the home BBS Q0DEMO.#42.GBR.EURO, and tap Continue.
2. Add a connection: host packet-mail-app.m0lte.compute.oarc.uk, port 8011, BBS type LinBPQ, FBB port, login demo, password demo. Tap Test connection, then Save.
3. The Mail tab syncs and shows the inbox. Open a message to read it; switch between Readable and As sent.
4. Tap compose, send a message to Q0BOT; pull down to sync again and its automatic reply arrives.
5. The Bulletins tab lists bulletins by category or date; open one, or subscribe to a category.
6. Contacts holds the address book. Settings has connections and Report a problem.

Each visitor to the demo BBS gets a private copy of the sample mail for 30 minutes.

**4. External services**

- The user's own packet BBS, reached directly over TCP at the address the user enters. These are run by independent radio amateurs (software such as LinBPQ or XRouter), not by us.
- Our demo BBS (packet-mail-app.m0lte.compute.oarc.uk), for trying the app.
- Our feedback server (packet-mail.m0lte.uk), used only when the user chooses to send a problem report.

No authentication services, analytics, advertising, payment processors or AI services.

**5. Regional differences**

None. The app works the same in every region. Its interface is in English.

**6. Regulation and third-party material**

The app does not transmit on radio and needs no licence itself: it connects over the internet or the user's own network to a BBS. Any radio transmission is made by the BBS station, whose operator holds the amateur radio licence that requires. Users of these BBSes are licensed amateurs. The app contains no third-party copyrighted material; mail and bulletins come from the user's own BBS account.

---

## Recording script (about 2 minutes)

On an iPhone with the latest iOS: Settings, Control Centre, add Screen Recording. Delete Packet Mail first so it starts fresh, install the build under review from TestFlight, then record:

1. Start recording, then launch Packet Mail from the home screen.
2. First run: callsign Q0YOU, a name, home BBS Q0DEMO.#42.GBR.EURO, Continue.
3. Add connection with the demo details above; Test connection (show the success line); Save.
4. Inbox fills in. Open a message; toggle Readable / As sent; go back.
5. Compose to Q0BOT, short subject and text, Send. Pull to refresh until the reply arrives; open it.
6. Bulletins: show the list, open one, subscribe to a category.
7. Contacts: open one, show the home BBS.
8. Settings: show the connection, then Report a problem (show the screen; no need to send).
9. Stop recording. Trim the start if needed.

Apple asks for any content reporting and blocking to be shown too; see the note in the chat about whether to add block and report before resubmitting.
