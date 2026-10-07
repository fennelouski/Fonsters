# Phone installation approval packet — 2026-10-07

The selected Air reached the only available paired iPhone, **To the Max**, an iPhone 15 Pro Max running iOS 26.5.2 over the local network. Pairing, the tunnel, Developer Mode, and developer disk image services were already available. The phone has `com.nathanfennel.Fonsters`, version 1.0 (1), installed. No phone app or user data was removed, overwritten, or installed by this attempt.

The existing scheme's signed development build failed before compilation. `evidence/phone-build.log` records the failures. It used the configured bundle identifier and team, without `-allowProvisioningUpdates` or any new certificate/profile creation:

- Bundle identifier: `com.nathanfennel.Fonsters`.
- Team: `EJLR2RPSV2`.
- Required existing App Group: `group.com.nathanfennel.Fonsters`.
- Current valid development identity: `Apple Development: Nathan Fennel (8QUK9W66Y7)`, certificate SHA-1 `00EA34AC631E2D988CAFF6C17889A8AB3F811812`.
- Cached iOS profile: `iOS Team Provisioning Profile: com.nathanfennel.Fonsters`, UUID `a4b547dd-27ee-4cc5-aa34-e9a959bf5a19`, expires 2027-02-04. It includes the paired phone but has **no App Group entitlement**, and its two development certificates do not match the current installed identity.
- The cached tvOS profile has the existing App Group, but is for tvOS, does not include this iPhone, and also references older certificates. It cannot be selected for an iOS build.

Both current and legacy local provisioning directories were checked read-only. There is no other matching cached iOS profile that can resolve this through selection alone. The current signing certificate is valid; replacing or revoking certificates is unnecessary.

The minimal authorized next change would be to refresh the **iOS development provisioning profile** for this existing bundle ID/team, selecting the existing current development certificate, existing paired phone, and existing App Group. The live Apple App ID capability association must be checked before that profile is regenerated. If the existing App Group is not already associated with the iOS App ID, enabling that association is an additional capability change that needs approval. Keep the existing CloudKit/iCloud entitlements and check the refreshed profile against the complete existing entitlement file. Do not remove App Groups, change the bundle identifier, use an unrelated profile, or drop persistence capabilities to bypass the failure.

Creating/updating provisioning or changing a capability is outside the current delegated signing permission. No such change has been attempted. A separate owner-approved profile refresh, or an owner-performed refresh in Xcode Signing & Capabilities, is the remaining step before a signed build/install can continue. No App Store/TestFlight distribution is needed.

The fuzzy world and social prototype are currently under macOS compile guards. A successful build of the existing iOS app would currently show the existing native 2D Fonsters functionality; it would not prove that the new Mac 3D prototype runs on the phone. That port and physical touch behavior remain unverified.
