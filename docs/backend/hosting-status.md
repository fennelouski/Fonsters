# Interest backend hosting exception — 8 October 2026

Mode: incomplete parallel developer preview. This is not a completed hosted API
release or a production account service. Native app delivery is outside the
repository's hosted migration policy.

Verified source revision: `978506143c2194e346a7a0147ea4397d533ae78f`, on
`codex/accessible-interest-editor`, [PR 12](https://github.com/fennelouski/Fonsters/pull/12).
The subsequent documentation-only revision records this exception.

## Completed verification

- `npm run test:interests`: seven tests passed.
- `npm run lint`: syntax checks passed.
- `npm run test:aws`: synthetic adapter, preview-gate and deployment-guard
  checks passed. These do not establish a live AWS deployment.
- Live local Jev category routing and Wikipedia lookup passed. The authenticated
  loopback API passed cache, ID lookup, contact-data rejection and authentication
  checks. Newly matched records remain unapproved and absent from recipient data.
- Both Vercel Git build statuses passed for this source revision. Their branch
  preview URLs are:
  - <https://fonsters-git-codex-accessible-in-3caf1d-nathan-fennels-projects.vercel.app>
  - <https://fonsters-pzgc-git-codex-accessib-2a187d-nathan-fennels-projects.vercel.app>

Vercel build success is not live authenticated interest-API verification and does
not establish parity with AWS. Unauthenticated status-route requests on both
previews returned HTTP 200 HTML rather than an interest-API JSON response;
neither service was verified by that read. Hosted adapters remain closed without their
explicit developer-preview configuration. The native app uses its bundled
catalog and is not connected to this service.

## Incomplete deployment

`npm run deploy:parallel` has not run for this revision. No AWS URL has been
verified for the interest service. At the last access check on this Air,
`fishbowl-head` was absent; the existing `default` profile returned
`InvalidClientTokenId`. The owner updated AWS CLI to 2.37.10 and was given the
browser-login command for existing account `074861507225`, region `us-west-2`.
The repo's pinned SST dependency installation awaits the owner's approval.

Next checks, after access and installation approval:

1. Confirm `aws sts get-caller-identity --profile fishbowl-head` reports the
   existing account, without creating accounts, keys or permission changes.
2. Configure existing server secrets securely for both hosts; never ship preview
   credentials in the native app. Review provider access and intended reuse.
3. Run the repository's parallel deployment command from a clean committed
   revision, then verify both Vercel projects and AWS at that same revision.
4. Exercise the outer AWS Basic gate together with the independent interest
   token, API routes, unavailable-provider states and recipient approval boundary.
5. Record verified URLs, revision, repeat-deploy and rollback results.

Production domains and routing are unchanged. No cutover has occurred; actual
cutover time is unset. Durable account storage, scoped account authorization,
shared quotas and approved-entity publication remain separate account-release
work. Provider limitations are documented in [interests.md](interests.md).

Local test logs, live responses, native screenshots and device-install results
are in the gitignored `evidence/interest-editor/` directory. Credentials and
generated evidence are not committed.
