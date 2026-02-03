# Universal Links: Hosting the AASA File on nathanfennel.com

This document explains how to host the **Apple App Site Association (AASA)** file on nathanfennel.com so that links like `https://nathanfennel.com/games/creature-avatar?cards=...` can open the Fonsters app on iOS and macOS when the app is installed (universal links).

The Fonsters app is already configured for universal links on the app side (Associated Domains entitlement with `applinks:nathanfennel.com`). The remaining step is to serve the AASA file from your website.

---

## 1. What is the AASA file?

Apple requires a JSON file on your web server to verify that your domain is associated with your app. When a user taps or clicks a link to your site, the system fetches this file to decide whether to open the link in your app or in the browser. No signature is required when the file is served over HTTPS with the correct content type.

**Requirements (all must be met):**

- Served over **HTTPS** (no redirects).
- Reachable at one of these URLs:
  - `https://nathanfennel.com/apple-app-site-association`
  - `https://nathanfennel.com/.well-known/apple-app-site-association`
- **Content-Type** response header: `application/json`.
- **Filename:** `apple-app-site-association` with **no file extension** (not `.json`).
- **Size:** Uncompressed file must be **128 KB or less**.

If you use both `nathanfennel.com` and `www.nathanfennel.com` for the same content, both must serve the same AASA file at one of the paths above.

---

## 2. Get your Apple Team ID

The AASA file must include your app’s **app ID**, which is:

```text
<TeamID>.<BundleID>
```

- **Bundle ID:** `com.nathanfennel.Fonsters` (from the Fonsters Xcode project).
- **Team ID:** Your Apple Developer Team ID (10 characters, e.g. `ABCD123456`).

**How to find your Team ID:**

1. Go to [Apple Developer → Account → Membership](https://developer.apple.com/account/#/membership/).
2. Sign in with the Apple ID used for the Fonsters app.
3. Under **Membership details**, find **Team ID** (or **Membership type** / **Organization** and the ID shown there).

Alternatively, in Xcode: select the Fonsters project → select the **Fonsters** target → **Signing & Capabilities**; the Team is shown there. The Team ID is in [Developer → Membership](https://developer.apple.com/account/#/membership/) for that team.

---

## 3. Create the AASA file

Create a file named **`apple-app-site-association`** (no extension). Put this JSON inside (replace `YOUR_TEAM_ID` with your 10-character Team ID):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_TEAM_ID.com.nathanfennel.Fonsters",
        "paths": [
          "/games/creature-avatar",
          "/games/creature-avatar/*"
        ]
      }
    ]
  }
}
```

**Notes:**

- **`apps`** must be present and must be an empty array `[]`.
- **`appID`** is exactly `TeamID.bundleID` (e.g. `ABCD123456.com.nathanfennel.Fonsters`). No spaces, no `https://`.
- **`paths`** are only the path part of the URL (no query string). The system matches the path; the full URL (including `?cards=...`) is still passed to the app.  
  - `/games/creature-avatar` matches that exact path.  
  - `/games/creature-avatar/*` matches that path and anything under it.
- Paths are **case-sensitive**.

If you want the app to handle every path on the domain (not recommended for a shared site), you could use `"paths": ["*"]`. For Fonsters, limiting to `/games/creature-avatar` is appropriate.

---

## 4. Where to host the file

You can use either (or both) of these locations; Apple checks both:

| URL |
|-----|
| `https://nathanfennel.com/apple-app-site-association` |
| `https://nathanfennel.com/.well-known/apple-app-site-association` |

The **`.well-known`** location is the common convention and is a good default.

**Important:**

- The URL must return the file **directly** (HTTP 200). No **redirects** (301/302) to another URL—Apple may not follow them for AASA.
- The response must include:  
  **`Content-Type: application/json`**
- The file must be served over **HTTPS** (valid certificate).

---

## 5. Server configuration examples

### Apache

1. Save the file as `.well-known/apple-app-site-association` in your site root (or map that path to the file).
2. Ensure the filename has no `.json` extension.
3. Add a rule so this path is served with the correct content type and without redirects. For example, in the relevant `VirtualHost` or in `.htaccess` for the site root:

```apache
<Files "apple-app-site-association">
    Header set Content-Type "application/json"
</Files>
```

If the file lives in `.well-known/`, ensure that directory is allowed and not redirected.

### Nginx

1. Save the file as e.g. `/var/www/html/.well-known/apple-app-site-association` (or your site root).
2. In the server block for `nathanfennel.com`:

```nginx
location /.well-known/apple-app-site-association {
    default_type application/json;
    add_header Content-Type application/json;
    # Optional: avoid caching during testing
    # add_header Cache-Control "no-cache";
}
```

Ensure there is no redirect from `/.well-known/` to another host or path.

### Static hosting (e.g. Netlify, Vercel, GitHub Pages)

1. Put the file in your project as:
   - **`.well-known/apple-app-site-association`**  
   (include the leading dot in `.well-known`).
2. Ensure the platform does **not** add a `.json` extension and does **not** redirect this URL.
3. Set **Content-Type** to `application/json`:
   - **Netlify:** Add a `_headers` file or a `[[headers]]` in `netlify.toml` for `/.well-known/apple-app-site-association` with `Content-Type: application/json`.
   - **Vercel:** Use a `vercel.json` header for that path, or a serverless function that returns the JSON with `Content-Type: application/json`. This setup has been verified for nathanfennel.com on Vercel (see [§6.4 Verified setup (Vercel)](#64-verified-setup-vercel)).
   - **GitHub Pages:** You may need a redirect rule or a small script to serve the file with the correct header; many static hosts allow custom headers per path.

### CDN / reverse proxy

If a CDN or reverse proxy sits in front of the origin:

- Ensure `https://nathanfennel.com/.well-known/apple-app-site-association` (and optionally the root path) is **not** redirected and returns HTTP 200 with body identical to your AASA file.
- Ensure the origin sends `Content-Type: application/json` (or the CDN overwrites the response to add it).
- Be aware that Apple’s CDN may cache the file for a period (often up to 24 hours); after changing the file, re-validation may take time.

---

## 6. Verify the file

### 6.1 Fetch the URL

From a terminal:

```bash
curl -v https://nathanfennel.com/.well-known/apple-app-site-association
```

Check:

- HTTP status is **200**.
- Response header includes **`Content-Type: application/json`**.
- Body is valid JSON and includes your `appID` and `paths`.

### 6.2 Apple’s validator (optional)

- Use [Apple’s App Search Validation Tool](https://search.developer.apple.com/appsearch-validation-tool/) and enter your AASA URL, or  
- Rely on the fact that Apple will fetch the same URL you tested with `curl` when validating your app’s associated domain.

### 6.3 Test on a device

1. Install the Fonsters app on a physical iOS device (universal links do not work in the Simulator).
2. Send yourself a link, e.g. `https://nathanfennel.com/games/creature-avatar?cards=...` (with a valid `cards` value), via Messages or Mail.
3. Long-press the link and choose **Open in Fonsters**, or tap the link and confirm it opens in the app instead of Safari.

If it opens in Safari, re-check the AASA URL with `curl`, the Team ID and bundle ID in the file, and the Associated Domains entitlement in the app (`applinks:nathanfennel.com`).

### 6.4 Verified setup (Vercel)

This AASA setup has been verified for **nathanfennel.com** hosted on **Vercel**. A successful response looks like this:

**Headers (relevant lines):**
```text
< HTTP/2 200
< content-type: application/json
< server: Vercel
```

**Body:**
```json
{"applinks":{"apps":[],"details":[{"appID":"EJLR2RPSV2.com.nathanfennel.Fonsters","paths":["/games/creature-avatar","/games/creature-avatar/*"]}]}}
```

Key points: HTTP 200, no redirect, `Content-Type: application/json`, and valid JSON with `applinks.apps` empty and `applinks.details` containing the app ID (Team ID `EJLR2RPSV2` + bundle ID `com.nathanfennel.Fonsters`) and the paths above.

---

## 7. Caching and updates

- Apple’s servers cache the AASA file. After you add or change the file, it can take **up to 24 hours** for the new file to be used everywhere.
- To see changes sooner during development, you can temporarily add a cache-busting query string when testing (e.g. in a browser), but Apple fetches the canonical URL without query parameters; the only way to “refresh” is to wait for the cache to expire or to use a new domain/path once.
- Keep the file under 128 KB. If you add more apps or paths later, keep the JSON valid and the `applinks` structure as above.

---

## 8. Summary checklist

- [ ] Team ID retrieved from Apple Developer (Membership) or Xcode.
- [ ] File created with name `apple-app-site-association` (no `.json`), valid JSON, and `appID` = `TeamID.com.nathanfennel.Fonsters`.
- [ ] Paths include `/games/creature-avatar` and optionally `/games/creature-avatar/*`.
- [ ] File hosted at `https://nathanfennel.com/.well-known/apple-app-site-association` (or root) with **no redirects**.
- [ ] Response has **Content-Type: application/json** and **HTTPS**.
- [ ] `curl -v` shows 200 and correct body and headers.
- [ ] After deployment, test on a real device with a share link; allow up to 24 hours for Apple’s cache to update if needed.

Once the AASA file is live and valid, universal links for `https://nathanfennel.com/games/creature-avatar?cards=...` will work with the existing Fonsters app (which already has the Associated Domains entitlement and URL handling in place).
