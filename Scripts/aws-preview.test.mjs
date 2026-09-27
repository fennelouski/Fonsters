import assert from "node:assert/strict";
import { previewRequest, previewResponse } from "./aws-preview.mjs";

const password = "test-only-password-with-at-least-32-characters";
const handle = new Function("event", previewRequest(password) + "return event.request;");
for (const uri of ["/", "/api/executive-orders", "/_next/static/chunk.js", "/opengraph-image"]) {
  assert.equal(handle({ request: { uri, headers: {} } }).statusCode, 401);
  assert.equal(handle({ request: { uri, headers: { authorization: { value: "wrong" } } } }).statusCode, 401);
  const request = { uri, headers: { authorization: { value: `Basic ${Buffer.from(`preview:${password}`).toString("base64")}` } } };
  assert.equal(handle({ request }).uri, uri);
  assert.equal(request.headers.authorization, undefined);
}
assert.throws(() => previewRequest(""));
const response = new Function("event", previewResponse + "return event.response;")({
  request: { uri: "/api/executive-orders" }, response: { headers: {} },
});
assert.equal(response.headers["x-robots-tag"].value, "noindex, nofollow");
console.log("AWS preview access and headers passed.");
