const { Resend } = require('resend');
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Verify caller is a signed-in hub user — without this the endpoint is
  // an open relay anyone can use to send mail from @mgts.co.uk
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No auth token' });

  const anon = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });
  const { data: { user }, error: authErr } = await anon.auth.getUser();
  if (authErr || !user) return res.status(401).json({ error: 'Not authenticated' });

  const { to, subject, html } = req.body;
  if (!to || !subject || !html) return res.status(400).json({ error: 'Missing fields' });

  const resend = new Resend(process.env.RESEND_API_KEY);
  try {
    await resend.emails.send({
      from: 'MGTS Hub <noreply@mgts.co.uk>',
      to,
      subject,
      html
    });
    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('Resend error:', err);
    res.status(500).json({ error: err.message });
  }
};
