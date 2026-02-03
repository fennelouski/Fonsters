# Fonsters iMessage Extension

This folder contains the source for a **dynamic iMessage app extension** that shows the user's own Fonsters (from SwiftData/CloudKit) as stickers, generated at runtime.

## What’s included

- **MessagesViewController.swift** – Loads Fonsters from SwiftData, generates 408×408 PNGs via `writeCreatureStickerPNG`, and presents them in an `MSStickerBrowserViewController`.
- **Info.plist** – NSExtension with `com.apple.message-payload-provider` and principal class.
- **Fonsters iMessage Extension.entitlements** – CloudKit (same container as main app) so the extension sees synced Fonsters.
- **Assets.xcassets** – Messages App Icon set (add PNGs for 60×45@2x/3x, 67×50@2x, 74×55@2x, 27×20, 32×24@2x, 1024×768).

Sticker image generation uses the shared helpers in **Fonsters/CreatureAvatar/CreatureRaster.swift**: `creatureImage(for:)`, `scaleImage(_:toSideLength:)`, and `writeCreatureStickerPNG(seed:to:sideLength:)`.

## Adding the target in Xcode

The extension is not yet wired into the project (manual project edits can break the project with current Xcode). Add it like this:

1. **File → New → Target…**
2. Choose **iOS → iMessage Extension**, click **Next**.
3. Product Name: **Fonsters iMessage Extension**.  
   Team and Bundle ID as you prefer (e.g. `com.nathanfennel.Fonsters.iMessageExtension`).  
   Uncheck “Include full application” if you’re only adding the extension. Click **Finish**.
4. **Replace** the generated `MessagesViewController.swift` with the one in this folder (or copy its logic into the new file).
5. **Replace** the generated `Info.plist` and entitlements with the ones in this folder (or set Extension Point, principal class, and CloudKit in the UI).
6. **Add shared code to the extension target**  
   In the Project navigator, select the **Fonsters** group (the main app folder). In the File inspector, under **Target Membership**, check **Fonsters iMessage Extension** for:
   - **Fonster.swift**
   - **CreatureAvatar/CreatureHash.swift**
   - **CreatureAvatar/CreatureConstants.swift**
   - **CreatureAvatar/CreatureTypes.swift**
   - **CreatureAvatar/CreatureGenerator.swift**
   - **CreatureAvatar/CreatureRaster.swift**  
   Leave all other files unchecked for the extension target.
7. **Embed the extension in the main app**  
   Select the **Fonsters** app target → **General** → **Frameworks, Libraries, and Embedded Content** (or **Embedded App Extensions**). Click **+** and add **Fonsters iMessage Extension.appex**.
8. **Messages App Icon**  
   Add the required icon images to the extension’s **Messages App Icon** in its asset catalog (see Apple’s docs for sizes). Stickers may not show if icon slots are empty.

Build and run the **Fonsters** app on an iOS device or simulator, then open Messages and use the Fonsters app in the app drawer to see your Fonsters as stickers.
