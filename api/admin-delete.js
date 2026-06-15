const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY   = process.env.SUPABASE_SERVICE_ROLE_KEY;

const TABLES = { purchase_requests: true, expense_claims: true, mileage_claims: true };
const REF_COL = { purchase_requests: 'ref_number', expense_claims: 'ref_number', mileage_claims: 'ref_number' };

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No auth token' });

  const { table, ref_number } = req.body;
  if (!table || !TABLES[table]) return res.status(400).json({ error: 'Invalid table' });
  if (!ref_number)               return res.status(400).json({ error: 'ref_number required' });

  if (!SERVICE_KEY) return res.status(500).json({ error: 'SERVICE_KEY not configured' });

  // Verify caller is finance
  const caller = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });
  const { data: { user }, error: authErr } = await caller.auth.getUser();
  if (authErr || !user) return res.status(401).json({ error: 'Not authenticated' });

  const { data: roleRow } = await caller.from('user_roles').select('role').eq('email', user.email).maybeSingle();
  if (!roleRow || roleRow.role !== 'finance') return res.status(403).json({ error: 'Finance role required' });

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  const { data: found, error: findErr } = await admin
    .from(table)
    .select('id')
    .eq(REF_COL[table], ref_number.toUpperCase())
    .maybeSingle();

  if (findErr) return res.status(500).json({ error: findErr.message });
  if (!found)  return res.status(404).json({ error: `${ref_number} not found in ${table}` });

  const { error: delErr } = await admin.from(table).delete().eq('id', found.id);
  if (delErr) return res.status(500).json({ error: delErr.message });

  res.status(200).json({ ok: true, deleted: ref_number });
};
