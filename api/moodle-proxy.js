// Server-to-server proxy for the Moodle REST web service.
//
// Why this exists: Moodle's webservice/rest/server.php does not send
// Access-Control-Allow-Origin headers by default, so browsers block
// direct fetch() calls to it from the Beacon dashboard (or anywhere
// else). Calling Moodle from here instead — server to server — has no
// CORS restriction at all, and as a bonus the Moodle token never has
// to be typed into or stored by the browser: it lives only as a
// Vercel environment variable.
//
// Required Vercel env vars (Project Settings → Environment Variables):
//   MOODLE_URL        e.g. https://mgts.moodle.school.uk  (no trailing slash)
//   MOODLE_TOKEN       the Moodle web service token
//   MOODLE_PROXY_KEY   a key you make up yourself — shared secret so random
//                       visitors who find this URL can't query your Moodle data.
//                       Put the same value into the Beacon dashboard's
//                       Live API tab under "Proxy key".

const MOODLE_URL = (process.env.MOODLE_URL || '').replace(/\/+$/, '');
const MOODLE_TOKEN = process.env.MOODLE_TOKEN;
const MOODLE_PROXY_KEY = process.env.MOODLE_PROXY_KEY;

// Allow-list of Moodle web service functions this proxy will call.
// Keeping this explicit means a leaked proxy key can only be used to
// read grade/enrolment data, not to call arbitrary admin functions.
const ALLOWED_FUNCTIONS = new Set([
  'core_webservice_get_site_info',
  'core_enrol_get_users_courses',
  'core_enrol_get_enrolled_users',
  'gradereport_user_get_grade_items'
]);

module.exports = async (req, res) => {
  // CORS — the dashboard can be opened from anywhere (a local file, a
  // different host, etc.), so this responds to any origin. The real
  // access control is the proxy key, not the origin.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-proxy-key');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!MOODLE_URL || !MOODLE_TOKEN || !MOODLE_PROXY_KEY) {
    return res.status(500).json({ error: 'MOODLE_URL / MOODLE_TOKEN / MOODLE_PROXY_KEY not set in Vercel' });
  }

  const suppliedKey = req.headers['x-proxy-key'];
  if (!suppliedKey || suppliedKey !== MOODLE_PROXY_KEY) {
    return res.status(403).json({ error: 'Invalid or missing proxy key' });
  }

  const { fn, params } = req.body || {};
  if (!fn || !ALLOWED_FUNCTIONS.has(fn)) {
    return res.status(400).json({ error: 'Unknown or disallowed Moodle function: ' + fn });
  }

  const qs = new URLSearchParams({
    wstoken: MOODLE_TOKEN,
    wsfunction: fn,
    moodlewsrestformat: 'json'
  });
  Object.entries(params || {}).forEach(([k, v]) => qs.append(k, v));

  try {
    const moodleRes = await fetch(MOODLE_URL + '/webservice/rest/server.php?' + qs.toString());
    const data = await moodleRes.json();
    if (data && data.exception) {
      return res.status(502).json({ error: data.message || data.exception });
    }
    return res.status(200).json(data);
  } catch (err) {
    return res.status(502).json({ error: 'Could not reach Moodle: ' + err.message });
  }
};
