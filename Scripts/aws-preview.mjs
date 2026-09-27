export function previewRequest(password) {
  if (password.length < 32) throw new Error("Preview password must contain at least 32 characters.");
  const authorization = `Basic ${Buffer.from(`preview:${password}`).toString("base64")}`;
  return `
    var previewAuthorization = event.request.headers.authorization;
    if (!previewAuthorization || previewAuthorization.value !== ${JSON.stringify(authorization)}) {
      return {
        statusCode: 401,
        statusDescription: "Unauthorized",
        headers: {
          "www-authenticate": { value: 'Basic realm="AWS parallel preview", charset="UTF-8"' },
          "cache-control": { value: "no-store" },
          "x-robots-tag": { value: "noindex, nofollow" }
        }
      };
    }
    delete event.request.headers.authorization;
  `;
}

export const previewResponse = `
  event.response.headers["x-robots-tag"] = { value: "noindex, nofollow" };
`;
