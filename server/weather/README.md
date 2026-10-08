# Shared private weather service

The cache engine is shared by the owner's apps (Fonsters and Golfmoji), not a public weather resale API. No dependency installation is needed: `node --test server/weather/service.test.mjs`.

A hit requires **both** an original observation timestamp no older than two hours and a spherical distance no greater than 30 km. Reuse never refreshes timestamps. Expired records are purged during reads. There is no location/user tracking or permanent weather history. Concurrent nearby misses within one process share a provider call. A provider failure consumes its reserved quota slot to avoid retry storms. Quota reservations are atomic through the supplied store, shared across client apps, and paced against an explicitly supplied billing-cycle start/end rather than a guessed renewal date. The allowance never purchases credits.

Production deliberately fails closed until the owner supplies:

- An existing authenticated API/account route; never embed the shared test or server key in an app.
- An existing WeatherKit server credential location and approved provider adapter.
- A shared durable store implementing atomic `transaction(fn)` across every deployed instance. `LocalWeatherStore` is only an in-process test fixture; it is not a distributed production cache.
- The membership's actual credit-cycle boundaries and aggregate use from other WeatherKit callers. The default 500,000 allowance is a cap, not a claim that all membership credits remain available.

The provider contract accepts Apple current-weather metadata `readTime`, condition code, temperature, daylight, and attribution (official service name, mark asset URL and legal-page URL). Verify the live contract with the existing credentials before enabling it. Released clients must show Apple's supplied mark and legal attribution when displaying weather, with a modification notice when weather inspires transformed scenery. Severe alerts need their own unchanged text, agency and link handling; this engine does not request or expose alerts.

The current protected Fonsters release disables third-party requests. A parent math task is not account authentication or verifiable parental consent and cannot switch on a third-party weather client. Live app wiring remains disabled pending the authenticated route and product privacy approval. No location permission, upstream calls, new credentials or deployment occurred in this change.

Apple's WeatherKit terms permit limited temporary performance caching and prohibit building a secondary weather database. Permanent history accumulation and calls solely to harvest unused quota are intentionally excluded. See https://developer.apple.com/support/terms/apple-developer-program-license-agreement/ (WeatherKit attachment) and https://developer.apple.com/weatherkit/.
