# Mapped public landmarks

This first integration imports a bounded **public named area** from OpenStreetMap, caches it, and supplies the same versioned snapshot to the native renderer. It does not infer or transmit anyone's location, request location permission, create accounts, or contact a provider at runtime from the protected app. The current demo is **Zaanse Schans and Zaandijk**, not the user's current location. No production deployment or new hosted access was performed.

The actual import on 2026-10-09 yielded **14 windmills, 8 playgrounds, and 30 waterway ways**, saved in `Fonsters/Playroom/Resources/MappedWorldDemo.json`. Windmills use `man_made=windmill`, playgrounds use `leisure=playground`, and waterway ways use `river`, `stream`, `canal`, `ditch`, or `drain`. These tags are not exhaustive: building-only historic mills, equipment subfeatures, riverbank polygons, lakes/oceans, and untagged or unmapped objects are outside this first import. Playground decoration is illustrative unless specific equipment is separately mapped. Waterway width uses mapped `width` when supplied; an aesthetic fallback must not be represented as measured width.

Geometry keeps original lon/lat coordinates, polygon rings, and individual waterway vertices; relation members stay separate lines. It never joins across missing vertices. Native code must project the anchor and **clip to the area bounds**: an OSM way intersecting the requested box can extend beyond it. Fresh source results have `coverage.status=mapped_partial`, `exhaustive=false`, `surveyedAbsence=false`; even an empty result does not prove absence. Without a usable snapshot, coverage is `unknown`. Expired cached data remains useful offline but is labeled stale and retains the original retrieval date.

## Local operation

No dependencies or credentials are needed:

```sh
node --test server/landmarks/service.test.mjs
node server/landmarks/dev.js
curl -sS http://127.0.0.1:4319/api/landmarks -H 'Content-Type: application/json' -d '{}'
curl -sS http://127.0.0.1:4319/api/landmarks -H 'Content-Type: application/json' -d '{"areaId":"zaanse-schans"}'
```

The dev server binds loopback only, serves already imported public snapshots, accepts POST bodies up to 1 KB, rejects query strings/location fields, and never performs an upstream import. `api/landmarks.js` exposes the same read-only contract but defaults to 503 unless `LANDMARK_PREVIEW_ENABLED=true` is explicitly configured. Neither the protected app nor this change enables that setting. Public cached data is not account authentication or permission to send private location.

To refresh the public demo deliberately, run `node server/landmarks/import.js` from the repository root. This operator tool alone enables upstream import. It uses `.prototype-build/landmarks` for durable snapshots and aggregate budget accounting, never logs queries, and writes the checked-in native JSON only after a usable import. A cached snapshot younger than seven days avoids another request. Existing cache filenames include a hash of the full area definition, so a changed bounding box cannot accidentally reuse a different area's data.

The importer defaults to 12 requests and 8 MB **aggregate per day per cache directory**, one upstream request at a time, 30-second network timeout and 2 MB per response. It reserves the full response allowance before fetching; failures consume reservations conservatively. Calls within a process queue; an atomic shared-directory lock prevents concurrent importer processes from overspending the same budget. A crashed process leaves the lock and subsequent imports fail closed; an operator must inspect/recover that import lock. Do not point separately deployed instances at different caches and assume their limits are shared. The directory is a local/shared-filesystem implementation, **not a distributed serverless database**. All consumers of the same upstream allowance need one coordinated ingestion owner.

## Native/backend contract

Version 1 has `area:{id,name,bounds:{south,west,north,east},anchor:{latitude,longitude}}`, ISO8601 `fetchedAt` (null for unknown), `coverage`, `source`, and `features`.

Each feature has a stable **public OSM object identifier**, `kind` (`windmill`, `playground`, `waterway`), source-derived `name`, `sourceURL`, and GeoJSON-style `geometry:{type,coordinates}`. Coordinate order is always **longitude, latitude**. Types are `Point`, `LineString`, `Polygon`, `MultiLineString`. Waterways optionally carry `widthMeters` and `waterwayType`. No seed, email, owner identifier, camera data, care state, or private user label is included. Saved waypoint metadata should retain the feature ID and public source URL without treating absence as proof of empty terrain.

A deliberate native demo selection can use the bundled file offline; it should suppress fabricated geographic scenery, show the named area and retrieval/coverage status, and offer return to the generated world. Runtime location-based requests remain disabled. Expansion needs a reviewed area catalog/data pipeline; the public Overpass instance is not an unlimited real-time map backend.

## Source policy and license

Display **© OpenStreetMap contributors** with a readily accessible [copyright/license link](https://www.openstreetmap.org/copyright) wherever this geographic world is shown. Preserve attribution and ODbL licensing with distributed snapshots. Any adapted geographic database distributed later must meet ODbL share-alike obligations; artistic Fonster assets remain independently original. The snapshot contains geographic data, not OpenStreetMap map tiles.

Official references: [OSM windmill tagging](https://wiki.openstreetmap.org/wiki/Tag:man_made%3Dwindmill), [playground tagging](https://wiki.openstreetmap.org/wiki/Tag:leisure%3Dplayground), [Overpass bounding boxes and geometry](https://dev.overpass-api.de/overpass-doc/en/full_data/bbox.html), [Overpass commons/load policy](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html), [regular shared-instance guidance](https://wiki.openstreetmap.org/wiki/Overpass_API), and [OSMF attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines). The stricter regular-use guidance is under 100 requests and 10 MB/day across all app users; these local defaults stay below that. Availability and coverage are not guaranteed. For broad production geography, use licensed regional extracts/self-managed ingestion and an authenticated shared cache rather than fanning mobile clients out to public Overpass.
