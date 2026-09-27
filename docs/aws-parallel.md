# Fonsters AWS parallel deployment

Mode: parallel. Production Vercel URLs remain unchanged. Target AWS cutover is
22 October 2026 at 07:00 UTC, subject to the root AGENTS.md readiness rules.
The `fonsters` and `fonsters-pzgc` Vercel projects share this repository and the
same flags. One AWS endpoint serves both during migration.

Install Node 24, Python 3, GitHub CLI and AWS CLI. Sign into GitHub and AWS
account 074861507225, commit changes, then run `npm run deploy:parallel`.
Use `-- --profile YOUR_PROFILE` if the local AWS profile differs from fishbowl-head.
Prefer an idle owned computer over the active computer. The command runs on the
selected machine, checks source/account/cutoff, installs dependencies, runs tests,
pushes for Vercel, deploys AWS and tests the AWS endpoint. Verify both Vercel
projects' statuses independently. GitHub Actions is not required.

AWS uses SST app `fonstersflags`, stage `parallel`, region `us-west-2`.
CloudFront protects a Lambda function with origin access control. The Lambda
adapter calls the existing `api/flags.js` handler and packages `config/flags.json`;
it does not create a second copy of the flags logic. No database is added.
GET `/` and `/api/flags` return the flags with the existing no-store and CORS
headers. Other methods return 405. Unknown paths return 404.

The preview username is `preview`. The SST `PreviewPassword` secret supplies the
password and automated checks. Keep secret files ignored and mode 0600. Do not
put preview credentials into a production app build. The preview is noindex.

Run `npm run test:aws` for adapter/protection/deployment-guard tests. The release
command also verifies live flags, methods, cache/CORS, routing and protection.
Before cutover, verify the native app against AWS, prove rollback, configure
production routing and remove preview protection from the production path.
Disable both Vercel projects' automatic deployments and provide a tested AWS-only
release command. The parallel command refuses to run after the cutoff.

Redeploy a known verified revision to roll back. Do not delete the SST stage;
resources are retained and removal is protected. Review cancellation on 23 October
before renewal on 24 October at 07:00 UTC, only after all required apps are ready.
