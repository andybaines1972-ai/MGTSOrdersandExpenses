const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY   = process.env.SUPABASE_SERVICE_ROLE_KEY;

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // ── Verify caller is an authenticated finance user ──────────────────────
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No auth token' });

  const caller = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });

  const { data: { user }, error: authErr } = await caller.auth.getUser();
  if (authErr || !user) return res.status(401).json({ error: 'Not authenticated' });

  const { data: roleRow, error: roleErr } = await caller
    .from('user_roles')
    .select('role')
    .eq('email', user.email.toLowerCase())
    .maybeSingle();

  if (roleErr || !roleRow || roleRow.role !== 'finance') {
    return res.status(403).json({ error: 'Finance role required' });
  }

  // ── Build admin client ───────────────────────────────────────────────────
  if (!SERVICE_KEY) return res.status(500).json({ error: 'SUPABASE_SERVICE_ROLE_KEY not configured in Vercel' });

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  const { name, email, role } = req.body;
  if (!name || !email || !role) return res.status(400).json({ error: 'name, email and role are required' });

  const normalEmail = email.toLowerCase().trim();

  // ── Send Supabase invite ─────────────────────────────────────────────────
  const { data: inviteData, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(normalEmail, {
    data: { full_name: name }
  });

  if (inviteErr) {
    // If already exists, that's OK — just update user_roles
    if (!inviteErr.message.toLowerCase().includes('already')) {
      return res.status(400).json({ error: inviteErr.message });
    }
  }

  // ── Upsert into user_roles ───────────────────────────────────────────────
  const { error: upsertErr } = await admin
    .from('user_roles')
    .upsert({ name, email: normalEmail, role, is_active: true }, { onConflict: 'email' });

  if (upsertErr) return res.status(500).json({ error: upsertErr.message });

  res.status(200).json({ ok: true, invited: !inviteErr });
};
