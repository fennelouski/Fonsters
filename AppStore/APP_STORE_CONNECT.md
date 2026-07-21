# Fonsters — App Store Connect submission guide

Everything that needs to be entered into App Store Connect for the 1.0 release, plus
the build/asset state of the repo at the time of writing.

> **Read the [Open items before you can submit](#open-items-before-you-can-submit)
> section first.** A few things still require your Apple Developer account or an
> administrator password and cannot be completed from the repo alone.

---

## 1. App identity

| Field | Value |
|---|---|
| **App name** (≤30 chars) | `Fonsters` |
| **Subtitle** (≤30 chars) | `Pixel creatures from words` |
| **Bundle ID** | `com.nathanfennel.Fonsters` |
| **SKU** | `fonsters-001` (any unique string; not user visible) |
| **Primary language** | English (U.S.) |
| **Version** | `1.0` (`MARKETING_VERSION`) |
| **Build** | `1` (`CURRENT_PROJECT_VERSION`) |
| **Copyright** | `2026 Nathan Fennel` |
| **Primary category** | Entertainment |
| **Secondary category** | Graphics & Design |
| **Age rating** | 4+ (see [Age rating](#5-age-rating) for one caveat) |

### Bundle IDs in the project

| Target | Bundle ID |
|---|---|
| iOS / macOS / tvOS / visionOS app | `com.nathanfennel.Fonsters` |
| Watch app | `com.nathanfennel.Fonsters.watchkitapp` |
| Watch complication | `com.nathanfennel.Fonsters.watchkitapp.clock` |
| iMessage extension | `com.nathanfennel.Fonsters.Fonsters-iMessage-Extension` |
| iCloud container | `iCloud.com.nathanfennel.Fonsters` |
| App group | `group.com.nathanfennel.Fonsters` |

---

## 2. Store copy

### Promotional text (≤170 chars, editable without a new build)

```
Type anything and a tiny pixel creature appears. The same words always make the
same creature, so your name or your favourite lyric has one that is only yours.
```

### Description (≤4000 chars)

```
Fonsters turns words into creatures.

Type anything — your name, a lyric, a quote, an inside joke — and Fonsters draws a
small pixel creature from it. There is no randomness and no AI: the text is hashed,
and every decision about the creature's body, eyes, colours and limbs comes from that
hash. The same words always produce exactly the same creature, on every device, for
everyone. Change one letter and you get a completely different one.

That determinism is the whole point. Your creature is genuinely yours, it is
reproducible, and you can share it as a link that rebuilds it on the other end
instead of sending a picture.

WHAT YOU CAN DO

• Create a collection — Make as many Fonsters as you like, name them, and keep them
  in a list you can scroll through.
• Type to transform — Edit the source text and watch the creature change as you type.
• Get random — Pull a quote, some words, a code or sample text when you want a
  starting point. Works offline with a built-in fallback.
• Watch it evolve — Press Play to animate the creature growing letter by letter, one
  frame per character, at whatever speed you like.
• Export — Save any creature as a PNG, or export the whole evolution as an animated
  GIF. On Mac you can also export JPEG.
• Share links — Send a link that contains the seeds. Whoever opens it gets the exact
  same creatures, not a screenshot.
• Tap for a reaction — Tap a creature and it blinks, wiggles, spins, rains or
  explodes. Which animation it does is decided by its seed, so each creature always
  reacts in its own way.
• Send them as stickers — A Messages extension puts your creatures in the iMessage
  sticker drawer.

ACROSS YOUR DEVICES

Your Fonsters sync through your own private iCloud, so the collection you build on
iPhone is already on your iPad, Mac and Apple Watch. On Apple Watch there is also a
Clock Fonster driven by the current time — it becomes a new creature every second —
and a complication that puts it on your watch face.

PRIVATE BY DEFAULT

Fonsters does not have accounts, ads, analytics or tracking, and it collects nothing.
Creatures are drawn on your device. Your collection lives in your own iCloud account,
where only you can see it.
```

### Keywords (≤100 chars total, comma separated, no spaces after commas)

```
pixel,avatar,creature,monster,generator,identicon,seed,gif,sticker,retro,8bit,art,profile
```

### What's New in This Version

```
First release.
```

### URLs

| Field | Value | Required? |
|---|---|---|
| **Support URL** | `https://nathanfennel.com` | Required |
| **Marketing URL** | `https://nathanfennel.com/games/creature-avatar` | Optional |
| **Privacy Policy URL** | **You must supply this** — see open items | Required |

---

## 3. App Privacy questionnaire

Answer **"No, we do not collect data from this app."**

Justification, in case review asks:

- Creatures are generated on-device from text the user types. Nothing is uploaded.
- The collection is stored with SwiftData in the user's **own private CloudKit
  database**. Apple does not treat data in the user's personal iCloud as collected by
  the developer.
- Two outbound requests exist, and neither sends user content:
  - random text (quote / words / uuid / lorem) used only when the user taps **Get
    random**, with an offline fallback bundled in the app;
  - a feature-flag lookup to `https://fonsters-pzgc.vercel.app/api/flags`.
- No ads, no analytics SDKs, no third-party trackers, no account system.

### Privacy manifest

`Fonsters/PrivacyInfo.xcprivacy` is committed and declares:

- `NSPrivacyTracking` → `false`, no tracking domains, no collected data types.
- One required-reason API: **UserDefaults** (`NSPrivacyAccessedAPICategoryUserDefaults`)
  with reason **`CA92.1`** — used for the first-launch seeding flag, feature-flag
  overrides, onboarding state and the selected creature-name font, all readable only
  by this app and its app group.

---

## 4. Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `Fonsters/Info.plist`, so App
Store Connect will stop asking on every upload. The app only uses standard HTTPS/TLS
via `URLSession`, which is exempt.

---

## 5. Age rating

**4+.** No violence, no mature themes, no user accounts, no ads, no in-app purchases.

One caveat to be aware of when filling in the questionnaire: **Get random → Quote**
fetches a short quotation from a third-party API, so that text is not authored or
curated by you. It is plain text only, no images and no links, and it cannot be
browsed — it just becomes the seed for a creature. If you would rather avoid the
question entirely, answer the web-content questions as "No" and mention the quote API
in the review notes (drafted below).

---

## 6. Screenshots

Screenshots produced by this repo live in `AppStore/screenshots/` (deliberately not
committed — they are large binaries and are regenerated on demand).

### What has been captured

| Folder | Size | Files | Status |
|---|---|---|---|
| `iphone-6.9/` | 1320 × 2868 | `01-creature`, `02-list`, `03-creature-alt`, `04-edit` | ✅ correct size, ready to upload |
| `ipad-13/` | 2064 × 2752 | `01-creature`, `04-edit` | ✅ correct size, ready to upload |
| `appletv/` | 3840 × 2160 | `01-creature` | ✅ correct size (tvOS is not in the current ship set) |
| `mac/` | — | — | ❌ blocked on Mac provisioning (open item 2) |
| `watch/` | — | — | ❌ blocked on unmounted watchOS runtime (open item 3) |
| `vision/` | — | — | ❌ blocked on unmounted visionOS runtime (open item 3) |

Two polish notes before uploading these as-is:

- The iPad shots kept the simulator's real clock instead of 9:41 — the status-bar
  override has to be re-applied after the device is erased or rebooted. Re-run the
  `simctl status_bar override` command above and recapture if you want it uniform.
- `04-edit` shows the auto-generated first-launch seed, which is raw device info
  (`ram:25769803776_storage_avail:…`). It is honest but not attractive marketing. For
  store-quality shots, add a step to the UI test that types something charming into
  the source-text field before capturing.

### How to regenerate

`FonstersUITests/FonstersScreenshotTests.swift` drives the app and captures each
screen as a test attachment:

```bash
xcodebuild test -scheme Fonsters \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:FonstersUITests/FonstersScreenshotTests \
  -resultBundlePath /tmp/shots.xcresult

xcrun xcresulttool export attachments \
  --path /tmp/shots.xcresult --output-path AppStore/screenshots/iphone-6.9
```

Set a clean status bar first:

```bash
xcrun simctl status_bar <UDID> override \
  --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```

### Sizes App Store Connect expects

| Platform | Required size | Simulator to use |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | iPhone 17 Pro Max |
| iPad 13" | 2064 × 2752 | iPad Pro 13-inch (M5) |
| Mac | 2880 × 1800 (or 1280 × 800) | run the Mac app and use ⌘⇧4 |
| Apple TV | 3840 × 2160 or 1920 × 1080 | Apple TV 4K (3rd gen) |
| Apple Watch | 410 × 502 (Series 11 46mm) | Apple Watch Series 11 (46mm) |
| Apple Vision Pro | 3840 × 2160 | Apple Vision Pro |

You only need to upload the largest size for each device family; App Store Connect
scales the rest.

---

## 7. Review notes

Paste into **App Review Information → Notes**:

```
No account or login is required — all features are available immediately on launch.

Fonsters generates a pixel creature deterministically from whatever text you type,
by hashing the text. There is no randomness and no AI. Typing the same text always
produces the same creature.

To try the main feature: open any creature, tap Edit, and type in the "Source text"
field — the creature redraws as you type. Tap Play to animate it growing one letter
at a time. Tap the creature itself for a short reaction animation.

"Get random" fetches a short piece of plain text (a quote, some words, a UUID or
lorem ipsum) from a public API purely to use as a seed. If the device is offline the
app falls back to text bundled in the app. No user data is sent in these requests.

The app stores creatures in the user's own private iCloud (CloudKit) database so the
collection syncs across their devices. Nothing is sent to any server we control, and
the app collects no data.
```

---

## 8. Build & warning state

Verified on Xcode 26.5 with a `Release` configuration:

| Platform | Builds | Compiler warnings | Screenshots |
|---|---|---|---|
| iOS (iPhone) | ✅ | 0 | ✅ |
| iPadOS | ✅ | 0 | ✅ |
| tvOS | ✅ | 0 | ✅ |
| macOS | ⚠️ compiles, cannot sign locally | 0 | ❌ blocked |
| watchOS | ❌ blocked | — | ❌ blocked |
| visionOS | ❌ blocked | — | ❌ blocked |

The only remaining line matching `warning:` in a build log is this, twice:

```
appintentsmetadataprocessor[...] warning: Metadata extraction skipped.
No AppIntents.framework dependency found.
```

That is a log line printed by Apple's `appintentsmetadataprocessor` tool, not a
compiler diagnostic. It does not appear in Xcode's issue navigator, does not fail the
build, and has no effect on submission. `ENABLE_APP_INTENTS_METADATA_EXTRACTION` is
already `NO` on every target; Xcode 26 runs the tool regardless.

---

## Open items before you can submit

These need your developer account, an administrator password, or a product decision —
they could not be done from the repo.

### Blocking

1. **Privacy Policy URL.** App Store Connect requires one for every app. The app
   collects nothing, so the policy can be short, but the URL must exist and be live.

2. **Register this Mac / create a Mac provisioning profile.** The macOS build fails
   signing with: *"Device 'MacBook Pro van Nathan' isn't registered in your developer
   account"* and *"No profiles for 'com.nathanfennel.Fonsters' were found."* Until the
   Mac is registered in the developer portal, the Mac app cannot be run or
   screenshotted locally. The code itself compiles cleanly for macOS.

3. **Mount the watchOS and visionOS simulator runtimes.** Both were downloaded
   successfully, but their disk images are unmounted, so Xcode still reports the
   platforms as not installed and neither can be built or screenshotted. Mounting is a
   privileged operation. Fix by opening Xcode once and letting it finish installing
   components when it asks for your password, or:

   ```bash
   sudo xcodebuild -runFirstLaunch
   ```

   Then confirm with `xcrun simctl list runtimes` — watchOS and visionOS should be
   listed alongside iOS and tvOS.

### Should fix before release

4. **The iMessage extension's deployment target is iOS 26.2, but the app's is 18.6.**
   Anyone on iOS 18.6–26.1 can install Fonsters but will not get the sticker
   extension. Either lower `IPHONEOS_DEPLOYMENT_TARGET` on the
   *Fonsters iMessage Extension* target to `18.6`, or raise the app's minimum
   deliberately. The same mismatch exists for the Watch app (10.6 vs 11.0), macOS
   (14.6 vs 26.2) and visionOS (2.6 vs 26.2).

5. **`aps-environment` is `development`** in `Fonsters/Fonsters.entitlements`. Xcode
   normally rewrites this to `production` when you archive for App Store
   distribution, but confirm it in the exported `.ipa` — if it ships as `development`,
   CloudKit push (used to sync creatures between devices) will not work for real
   users.

6. **Set `LSApplicationCategoryType`** for the Mac build. The Mac App Store requires
   an application category in `Info.plist`; `public.app-category.entertainment`
   matches the chosen primary category.

7. **Universal links are declared but may not resolve.** The entitlements request
   `applinks:nathanfennel.com`. Universal links only work if an
   `apple-app-site-association` file is served from that domain. If it is not hosted,
   the `fonsters://` scheme still works and nothing breaks — but the declared
   capability will silently do nothing.

### Worth knowing

8. **CloudKit schema must be deployed to Production.** The app syncs with SwiftData +
   CloudKit. Schema changes made while developing live in the CloudKit *Development*
   environment; you must deploy the schema to *Production* in the CloudKit Console
   before a public release, or sync will fail for App Store users.
