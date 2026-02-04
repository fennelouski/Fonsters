/**
 * Vercel serverless function: GET /api/flags
 * Returns feature-flag overrides as JSON. Keys must match FeatureFlag raw values in the app.
 * Edit api/flags.json and push to update flags (redeploys automatically).
 */

const path = require('path');
const fs = require('fs');

function getFlagsPath() {
  // Prefer same directory as this file (works when deployed)
  const here = path.join(__dirname, 'flags.json');
  if (fs.existsSync(here)) return here;
  return path.join(process.cwd(), 'api', 'flags.json');
}

module.exports = function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Access-Control-Allow-Origin', '*');

  try {
    const flagsPath = getFlagsPath();
    const raw = fs.readFileSync(flagsPath, 'utf8');
    const data = JSON.parse(raw);
    return res.status(200).json(data);
  } catch (err) {
    console.error('flags API error:', err);
    return res.status(500).json({ error: 'Failed to read flags' });
  }
};
