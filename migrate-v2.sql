-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request Hub — v2 Migration
--  Run in: Supabase Dashboard → SQL Editor
--  Safe to run multiple times (uses ADD COLUMN IF NOT EXISTS)
-- ═══════════════════════════════════════════════════════════════════

-- ── PURCHASE REQUESTS ─────────────────────────────────────────────
ALTER TABLE purchase_requests
  ADD COLUMN IF NOT EXISTS department       text,
  ADD COLUMN IF NOT EXISTS authoriser_email text,
  ADD COLUMN IF NOT EXISTS supplier_address text,
  ADD COLUMN IF NOT EXISTS supplier_tel     text,
  ADD COLUMN IF NOT EXISTS supplier_fax     text,
  ADD COLUMN IF NOT EXISTS supplier_ref     text;

-- ── EXPENSE CLAIMS ────────────────────────────────────────────────
ALTER TABLE expense_claims
  ADD COLUMN IF NOT EXISTS department       text,
  ADD COLUMN IF NOT EXISTS authoriser_email text;

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('purchase_requests','expense_claims')
  AND column_name IN ('department','authoriser_email','supplier_address',
                      'supplier_tel','supplier_fax','supplier_ref')
ORDER BY table_name, column_name;
