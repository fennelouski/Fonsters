//
//  ShareLoadHelpers.swift
//  Fonsters
//
//  Share and import helpers using the same URL format as the web app:
//  https://nathanfennel.com/games/creature-avatar?cards=<base64url(JSON array of seeds)>
//
//  Works: building share URL from seeds; parsing seeds from URL; length check.
//  Import is done via the Import sheet (paste URL). Opening the app from a
//  shared URL is supported via the fonsters:// URL scheme (and universal links
//  if Associated Domains and server AASA are configured).
//

import Foundation

private let shareURLBase = "https://nathanfennel.com/games/creature-avatar"
private let shareURLMaxLength = 2000

/// Base64url encode (no +//, no padding) for URL-safe query values.
func base64urlEncode(_ data: Data) -> String {
    let b64 = data.base64EncodedString()
    return b64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// Base64url decode; adds padding if needed.
func base64urlDecode(_ str: String) -> Data? {
    var b64 = str
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let pad = b64.count % 4
    if pad > 0 {
        b64 += String(repeating: "=", count: 4 - pad)
    }
    return Data(base64Encoded: b64)
}

/// Build share URL from seeds array (same format as web). Returns nil if encoding fails or URL would exceed shareURLMaxLength.
func buildShareURL(seeds: [String]) -> String? {
    guard let json = try? JSONSerialization.data(withJSONObject: seeds),
          !json.isEmpty else { return nil }
    let encoded = base64urlEncode(json)
    let url = "\(shareURLBase)?cards=\(encoded)"
    return url.count <= shareURLMaxLength ? url : nil
}

/// Parse seeds from a share URL string (e.g. pasted). Expects query param "cards" with base64url(JSON array of strings). Returns nil if missing or invalid.
func parseSeedsFromShareURL(_ urlString: String) -> [String]? {
    guard let url = URL(string: urlString),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let encoded = components.queryItems?.first(where: { $0.name == "cards" })?.value else {
        return nil
    }
    guard let data = base64urlDecode(encoded),
          let seeds = try? JSONSerialization.jsonObject(with: data) as? [String],
          !seeds.isEmpty else {
        return nil
    }
    return seeds
}

/// True if the share URL for the given seeds would exceed the max length (e.g. 2000); used to show a warning before share.
func isShareURLTooLong(seeds: [String]) -> Bool {
    guard let url = buildShareURL(seeds: seeds) else { return true }
    return url.count > shareURLMaxLength
}
