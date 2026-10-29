# Store forms: answers to copy in

Drafts for Tom. They assume problem reports go to the developer's own feedback server (#53) and that the app has no analytics, ads, accounts or tracking. Check them against the final app before submitting.

## Privacy policy URL

https://github.com/m0lte/packet-mail/blob/master/docs/privacy.md

## Apple: App Privacy ("nutrition label")

App Store Connect, App Privacy, Get Started.

**Do you or your third-party partners collect data from this app?** Choose one:

- **No, we do not collect data from this app** (recommended). Apple lets you leave out data that meets all of its optional-disclosure criteria: collected only infrequently, not part of the app's main purpose, optional for the user, and the user is clearly told what is sent at the moment they send it. "Report a problem" meets all of these: it is used rarely, it is separate from reading and sending mail, nothing is sent unless the user taps Send, and the user sees exactly what is sent first.
- If you would rather be cautious, answer **Yes** and declare only:
  - **Diagnostics, Other Diagnostic Data** (app version, OS version, BBS traffic log). Used for App Functionality. Linked to the user: Yes (the log can contain their callsign). Tracking: No.
  - **User Content, Customer Support** (the description they type). Same answers.

Mail, bulletins, contacts, callsigns and passwords stay on the phone or go only to the BBS the user chose, so they are not "collected" in Apple's sense.

## Apple: other questions

- **Export compliance:** the app uses no non-exempt encryption (already declared in the build with ITSAppUsesNonExemptEncryption = NO; the feedback upload uses HTTPS from the operating system, which is exempt).
- **Content rights:** the app does not contain, show or access third-party content it doesn't have rights to. (Mail it shows comes from the user's own BBS.)
- **Age rating:** answer None to every content question. Unrestricted web access: No (links in messages open in the browser, the app has no browser of its own). User-generated content: the app is a mail client for the user's own BBS; there is no shared feed inside the app. Expected rating 4+.
- **Category:** Utilities; secondary Productivity.
- **Sign-in required for review:** Yes. Provide the demo BBS details (#35): server, port, user, password, and these notes:

  > Packet Mail is a mail client for amateur (ham) radio packet BBSes. It needs a BBS to connect to, so we run a demo BBS for review. On first launch enter the callsign Q0YOU, any name, and the home BBS Q0DEMO.#42.GBR.EURO, then add a connection with the details above (BBS type LinBPQ, FBB port, login name demo, password demo). The demo BBS has sample mail and bulletins and a robot user, Q0BOT, that replies to any personal message you send it. Your copy of the demo mail is private to you, kept for 30 minutes after you last connect, then reset.

  The full notes text is in `demo-bbs/README.md`.

## Google Play: Data safety

Play Console, App content, Data safety.

- **Does your app collect or share any of the required user data types?** Yes (Google counts any data sent off the device, even optional reports).
- **Is all of the user data collected by your app encrypted in transit?** Yes (HTTPS).
- **Do you provide a way for users to request that their data is deleted?** Yes: by emailing app-support@tomfanning.name.
- **Data types collected:**
  - **App info and performance, Diagnostics.** Collected, not shared. Optional (user chooses to send a report). Purpose: App functionality. Processed ephemerally: No.
  - **Messages, Other in-app messages** (the description and, only if the user ticks the box, message text in the traffic log). Collected, not shared. Optional. Purpose: App functionality.
- Nothing else: no location, contacts from the phone, identifiers, financial or health data. Callsigns and mail go only to the user's own BBS, which Google does not count as the developer collecting them.

## Google Play: other forms

- **Content rating (IARC):** category Utility, productivity, communication or other. Answer No to violence, sexuality, language, controlled substances and gambling. Users can interact or exchange content: Yes (it is a mail client), no sharing of location, no digital purchases. Expected rating: Everyone / PEGI 3, possibly with a "Users interact" note.
- **Target audience:** 18 and over is simplest (amateur radio licence holders); avoids the Families policy.
- **Ads:** No ads.
- **App access:** All or some functionality is restricted; give the same demo BBS details and notes as for Apple.
- **Government app, financial features, health:** No.
