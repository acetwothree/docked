# Docked — App Store submission checklist

Everything in the codebase that App Review needs is now in place. What's left is
account/portal work only you can do. Ordered roughly by when you'll need it.

## Code / build side — DONE

- [x] `Docked/PrivacyInfo.xcprivacy` — privacy manifest. Declares **no tracking**,
      **no data collected**, and the one required-reason API we touch
      (`UserDefaults`, reason `CA92.1`). Bundled automatically by the synchronized
      project group.
- [x] `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` — skips the export-compliance
      question every submission.
- [x] `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.entertainment`.
- [x] `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` — set (doodle "Save Image").
- [x] iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), deployment target iOS 17.0.
- [x] No networking, no analytics, no third-party SDKs, no ATS exceptions.
- [x] Developer-only tools (Unlock Plus toggle, debug overlay, data wipe) are
      hidden in normal builds — reveal them by tapping the **Version** row in
      Settings seven times.
- [x] Privacy policy is live: <https://acetwothree.github.io/docked/privacy/>

## One code TODO left for you

- [ ] **Fill the support email** in `docs/privacy/index.html` line 52 —
      currently `REPLACE-WITH-YOUR-SUPPORT-EMAIL`. Use whatever address you'll put
      as the App Store "Support URL"/contact. Commit + push; Pages redeploys in ~1 min.

## App Store Connect — you

### The app record
- [ ] Create the app in App Store Connect (Bundle ID must match the project).
- [ ] Primary language, name ("Docked"), subtitle, category **Entertainment**.
- [ ] **Support URL** and **Marketing URL** (the GitHub Pages site is fine for both,
      or a mailto page).

### Privacy (nutrition label)
- [ ] App Privacy section → **"Data Not Collected."** Answer *No* to every
      collection question and *No* to tracking. This must match the manifest above.
- [ ] Privacy Policy URL: `https://acetwothree.github.io/docked/privacy/`

### Subscription (Docked Plus)
- [ ] Confirm the **auto-renewable subscription** product exists, is in a
      subscription group, has a price, a localized display name + description, and
      a review screenshot.
- [ ] Its product identifier must match what the app requests (see
      `Docked.storekit` / `StoreManager.swift`).
- [ ] Add the **Paid Applications agreement** (Agreements, Tax, and Banking) — IAP
      won't load for reviewers until this is active.
- [ ] Subscription needs its own short review note (how to reach the paywall:
      Settings → Docked Plus, or a locked activity).

### Age rating
- [ ] Complete the questionnaire. Note: **simulated gambling** — Blackjack, Draw
      Poker and Lucky Scratch use play-money chips only, no real currency, no
      prizes. Answer the gambling question as "simulated gambling" → this pushes
      the rating to **17+**. There is no way around that with these activities in
      the app; if you'd rather stay 12+, the three Gambling activities would need
      to come out.

### Assets
- [ ] **Screenshots**: 6.7" (1290×2796) required; 6.9" recommended. iPhone only.
- [ ] App icon is in the asset catalog already — make sure the 1024 marketing
      icon slot is filled (no alpha).
- [ ] Description, keywords, promotional text.
- [ ] "What's New" text for 1.0 (can be simple).

### Review notes (Notes for the reviewer)
- [ ] Explain the core interaction, because it's non-obvious:
      > Docked is a companion dashboard for iPhone Picture-in-Picture. Start any
      > video that supports PiP (e.g. Safari, YouTube web, Apple TV), swipe up to
      > Home so it becomes a floating window, then open Docked — the floating
      > video sits over the app and every control stays clear of it. Doodle,
      > Notes and the mini-activities work with or without a video playing.
- [ ] Mention the play-money chips (no real-money gambling).
- [ ] If IAP: "Docked Plus unlocks the premium activities; tap Settings → Docked
      Plus to see the paywall. Sandbox purchase works without charge."
- [ ] Optional but helps: a 15–20s screen recording showing the PiP hand-off.

### Build
- [ ] The `[deploy]` push builds, archives and uploads to TestFlight via GitHub
      Actions. Once processed, attach that build to the App Store version.
- [ ] TestFlight → run through each activity once on a device (the CI can't catch
      runtime layout/crash issues).
- [ ] Submit for review.

## Things reviewers commonly reject — pre-checked

- No sign-in wall, no account required → fine.
- No private API, no background modes we don't use.
- PiP: we don't *start* PiP ourselves, so no `UIBackgroundModes` needed. If you
  ever add a "play this for me" button, that changes.
- Simulated gambling is allowed on the App Store but **must** be 17+ and must not
  imply real-money reward — current copy ("play-money chips", "chips can't run
  out") is fine.
