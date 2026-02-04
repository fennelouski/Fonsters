/**
 * Vercel serverless function: GET /api/flags
 * Returns feature-flag overrides as JSON. Keys must match FeatureFlag raw values in the app.
 * Edit config/flags.json and push to update flags (redeploys automatically).
 *
 * Flags JSON lives in config/ (not api/) to avoid Vercel path conflicts:
 * api/flags.js and api/flags.json would both map to /api/flags.
 */

const path = require('path');
const fs = require('fs');

function getFlagsPath() {
  const configPath = path.join(process.cwd(), 'config', 'flags.json');
  if (fs.existsSync(configPath)) return configPath;
  // Fallback for local dev if config/ is elsewhere
  return path.join(__dirname, '..', 'config', 'flags.json');
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
