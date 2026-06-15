const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY   = process.env.SUPABASE_SERVICE_ROLE_KEY;

const TABLE = { PRQ: 'purchase_requests', EXP: 'expense_claims', MIL: 'mileage_claims' };

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Verify caller is authenticated
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No auth token' });

  const { prefix } = req.body;
  if (!prefix || !TABLE[prefix]) return res.status(400).json({ error: 'Invalid prefix' });

  if (!SERVICE_KEY) return res.status(500).json({ error: 'SUPABASE_SERVICE_ROLE_KEY not set in Vercel' });

  // Admin client bypasses RLS — sees ALL rows across all users
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  // Verify token is a real authenticated user
  const anon = createClient(SUPABASE_URL, SUPABASE_ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });
  const { data: { user }, error: authErr } = await anon.auth.getUser();
  if (authErr || !user) return res.status(401).json({ error: 'Not authenticated' });

  // Count all records in the table (bypasses RLS via admin client)
  const { count, error } = await admin
    .from(TABLE[prefix])
    .select('*', { count: 'exact', head: true });

  if (error) return res.status(500).json({ error: error.message });

  const ref = prefix + String((count || 0) + 1).padStart(4, '0');
  return res.status(200).json({ ref });
};
