const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY   = process.env.SUPABASE_SERVICE_ROLE_KEY;

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No auth token' });

  if (!SERVICE_KEY) return res.status(500).json({ error: 'SERVICE_KEY not configured' });

  // Verify caller is finance
  const caller = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });
  const { data: { user }, error: authErr } = await caller.auth.getUser();
  if (authErr || !user) return res.status(401).json({ error: 'Not authenticated' });

  const { data: roleRow } = await caller.from('user_roles').select('role').eq('email', user.email).maybeSingle();
  if (!roleRow || roleRow.role !== 'finance') return res.status(403).json({ error: 'Finance role required' });

  const { id, name, email, role, is_active, old_email } = req.body;
  if (!name || !email || !role) return res.status(400).json({ error: 'name, email and role required' });

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  const normEmail = email.toLowerCase().trim();

  // Update or insert user_roles
  if (id) {
    const { error } = await admin.from('user_roles')
      .update({ name, email: normEmail, role, is_active: is_active ?? true })
      .eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
  } else {
    const { error } = await admin.from('user_roles')
      .upsert({ name, email: normEmail, role, is_active: is_active ?? true }, { onConflict: 'email' });
    if (error) return res.status(500).json({ error: error.message });
  }

  // Sync to Supabase Auth — find user by old email (or current if no change)
  const lookupEmail = (old_email || normEmail).toLowerCase();
  let authSynced = false;
  let authWarning = null;

  try {
    const { data: { users }, error: listErr } = await admin.auth.admin.listUsers({ perPage: 1000 });
    if (!listErr) {
      const authUser = users.find(u => u.email?.toLowerCase() === lookupEmail);
      if (authUser) {
        const updates = { user_metadata: { full_name: name } };
        if (normEmail !== authUser.email?.toLowerCase()) updates.email = normEmail;
        const { error: updErr } = await admin.auth.admin.updateUserById(authUser.id, updates);
        if (updErr) authWarning = 'Role saved but auth not synced: ' + updErr.message;
        else authSynced = true;
      }
    }
  } catch (e) {
    authWarning = 'Auth lookup failed: ' + e.message;
  }

  res.status(200).json({ ok: true, authSynced, authWarning });
};
