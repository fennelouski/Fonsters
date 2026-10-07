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

## Owner-approved refresh and installation

Nathan explicitly approved refreshing this development profile with the existing valid certificate, paired phone, and shared-data group. The first constrained manual-profile check failed because Xcode managed profiles cannot be selected as manually managed profiles; its global CLI profile override also mismatched the iMessage extension. A second attempt with an explicit SHA-1 identity conflicted with automatic signing. Neither attempt changed source signing settings or installed the app.

The configured automatic signing build with `-allowProvisioningUpdates CODE_SIGN_IDENTITY='Apple Development'` then **passed** (`evidence/phone-approved-managed-refresh.log`). It used the existing development certificate SHA-1 above. The embedded refreshed main profile is UUID `957e1bfc-fa8f-4196-83bc-8ff299789dd8`, expires 2027-10-07, includes the paired phone and `group.com.nathanfennel.Fonsters`, and contains the existing development certificate. The signed app retains the App Group, CloudKit service/container, associated domain, development push entitlement, team, and bundle identifier. A post-build Keychain identity check still found the same three valid identities; no new local signing identity was created or revoked. The existing iMessage extension also built and signed with this existing development identity.

`devicectl device install app` **succeeded** on To the Max (`evidence/phone-install.log`, `.json`). A read-only installed-app query independently confirmed `com.nathanfennel.Fonsters` at the same new installation URL. No uninstall, data deletion, certificate revocation, new device registration, or source capability changes were performed. User-data preservation is the normal in-place installation behavior; existing phone records have not been inspected for a before/after comparison.

The launch attempt was **blocked by the phone lock** (`evidence/phone-launch.log`, `.json`, `FBSOpenApplicationErrorDomain` error 7). iOS reported it could not unlock the device. Nathan was asked to unlock and keep it awake. Physical launch, on-screen behavior, and phone gesture exercise remain unverified until that succeeds. No App Store or TestFlight upload occurred.

The fuzzy world and social prototype are currently under macOS compile guards. A successful build of the existing iOS app would currently show the existing native 2D Fonsters functionality; it would not prove that the new Mac 3D prototype runs on the phone. That port and physical touch behavior remain unverified.
