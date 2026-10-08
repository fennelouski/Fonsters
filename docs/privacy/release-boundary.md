# Protected play release boundary

Implementation version 1 · research checked 8 October 2026

## Preserved baseline

The fuzzy local lobby/care/dance/imitation experience is retained from main
`f4c75fd3eb0e0a42a2820de13ee3d19f80963f74` (PR #8). The frozen 2D renderer,
seed identity, original link decoder, exports and SwiftData schema remain intact.
Saved records are neither removed nor converted. iCloud keeps its existing
private-library behavior. New native safeguards gate sharing/device inputs and
stop external random-text, remote flags and external agent handoffs.

`ProtectedPlayPolicy` is the authority for the product capability boundary, not
remote feature flags or a birthday preference. Accounts, external agents and
public social profiles remain false. Missing/invalid age is protected; a US age
under 13 is protected; US 13+ requires a separate account-release review; any
unreviewed country requires country review. No age/country/DOB is requested or
persisted because the current build offers the same protected play to everyone.
Do not interpret this evaluator as legal authorization to open an account.

## Scope prepared now

US-first review is the working scope pending the owner's release-country answer.
This is preparation, **not a declaration that any country is legally cleared**.
No App Store availability, Kids category, age rating, entitlements, consent
permissions or production policy website is changed by this native implementation.
Other countries remain in protected play; an unknown jurisdiction never enables
sign-up. A future account experience should use reviewed age-range attributes
rather than collecting exact birthdays wherever practical.

| Region | Relevant boundary | Product decision now |
| --- | --- | --- |
| United States | COPPA concerns children below 13. Child-directed services generally protect all visitors; only qualifying mixed-audience services can use the narrower age-screen exception. | Protected play for everyone; no child accounts or DOB collection. Audience classification and updated COPPA rule applicability require release review. |
| EU/EEA | GDPR Article 8 uses 16 as its default for consent to directly offered information society services; member states may lower it to 13. It is not a universal social-network minimum. | No blanket “13 worldwide” rule or country allowlist. Review individual country law, lawful basis and child/social requirements before account release. |
| UK | UK GDPR's relevant consent age is 13; the ICO Children's Code addresses services likely accessed by under-18s more broadly. | Country review required; 13 alone does not clear a social product. |
| Other/unknown | Consent, child-account, age assurance and social-service rules differ. | Protected play; no automatic region inference from language, device locale, SIM or IP address. |

## Remaining public release work

1. Confirm operator name/address/privacy email/telephone and fill both the native
   notice and [policy draft](protected-play-policy.md).
2. Publish the matching child notice at the existing policy URL through the
   website owner workflow; review that site's logs/analytics/link landing page
   independently. Native privacy promises do not cover the existing website.
3. Review private iCloud use, recipient disclosures, local camera/body processing,
   support and deletion processes for the intended child audience and countries.
   A grown-up math task and an OS permission prompt are not legally verifiable
   parental consent. Do not add data collection on that assumption.
4. Review age assurance/significant-change requirements where applicable, DPIA
   obligations, audience classification, App Store age-rating questionnaire and
   Kids category band/parental gates. Apple's September 2026 social-capability
   declaration applies regardless of app category; a future lower-rated release
   with under-13 social disabled needs Declared Age Range at minimum. The current
   local-only boundary does not implement that API or clear a future social release.
   Don't claim approval from a code change.
5. Exercise hardware camera/microphone and all release platforms. Simulator
   fixtures prove routing/gates, not recognition accuracy or permission behavior.
6. Keep the protected boundary and its regressions in future releases. A separate
   adult/account product must not silently replace the child experience.

## Future account handoff

Nathan will specify real signup separately. No credentials, account backend,
OAuth, public social upload or location reflection is implemented here. Before
enabling any of it, define region-specific eligibility, privacy-preserving age
assurance, parental consent/revocation where needed, data minimization, retention,
account deletion, moderation and permission-scoped agent access. “Everything” in
the earlier local prototype agent scope does not override the protected boundary.

The [social product/backend plan](../product/social-fonsters-plan.md) records
proposed phases, identity choices, private diary/status boundaries and release
gates. It is review material, not authorization to provision or transmit data.

## Primary sources

- [FTC COPPA FAQ, child-directed/mixed audience and neutral screening](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions).
- [FTC 2025 COPPA amendments](https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data).
- [GDPR, Article 8](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679).
- [ICO guidance on ISS and children's consent](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/children-and-the-uk-gdpr/what-are-the-rules-about-an-iss-and-consent/).
- [Apple review guidelines 1.3 and 5.1](https://developer.apple.com/app-store/review/guidelines/).
- [Apple child experiences, Declared Age Range, PermissionKit and parental tasks](https://developer.apple.com/kids/).
- [Apple September 2026 social-capability declaration requirements](https://developer.apple.com/news/?id=0d2gpmml).

These sources inform implementation/release preparation; this document does not
certify international legal compliance or Apple review acceptance.
