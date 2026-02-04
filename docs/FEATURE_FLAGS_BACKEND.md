# Feature flags backend (Vercel)

The app can fetch feature-flag overrides from a backend. This repo includes a Vercel-deployable API so you can update flags without shipping a new app version.

## Deploying the backend

1. **Link the repo in Vercel**: In the [Vercel dashboard](https://vercel.com), create a new project and import this GitHub repo. Use the repo root as the project root (do not set a subdirectory).

2. **Deploy**: Vercel will detect the `api/` folder and deploy each file as a serverless function. The flags endpoint will be available at:
   ```
   https://<your-project>.vercel.app/api/flags
   ```

3. **Configure the app**: Set this URL in the app’s **Info.plist** under the key `FeatureFlagBackendURL` (in `Fonsters/Info.plist`). Replace the placeholder with your deployed URL, e.g. `https://fonsters.vercel.app/api/flags`.

4. **Update flags**: Edit `api/flags.json` in the repo (keys must match `FeatureFlag` raw values in the app, e.g. `show_birthday_overlay`, `creature_glow_effect`). Push to GitHub; Vercel will redeploy and the new values will be used on the next app fetch (typically next launch).

## Lock-on-read behavior

Each flag’s value is **locked on first read** for the rest of the app session:

- When the app launches it may fetch overrides from the backend.
- The first time code calls `featureFlags.isEnabled(.someFlag)` in that session, the store resolves the value (remote → local → default), caches it in memory, and returns it.
- Every later read of that same flag in the same session returns the cached value, even if the backend is fetched again or returns different data.
- Locks clear only when the app process ends (e.g. next launch).

So you can change `api/flags.json` and redeploy; the new values apply only to flags that have not yet been read in an already-running app, and to all flags on the next app launch.

## API format

**GET** `/api/flags` returns a JSON object mapping flag keys (strings) to booleans, for example:

```json
{
  "show_birthday_overlay": true,
  "creature_glow_effect": false
}
```

The app ignores keys it doesn’t recognize and uses bundled defaults for any flag missing from the response.
