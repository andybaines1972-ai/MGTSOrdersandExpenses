-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request Hub — v3 Migration
--  Run in: Supabase Dashboard → SQL Editor
--  Safe to run multiple times (uses ADD COLUMN IF NOT EXISTS)
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE purchase_requests
  ADD COLUMN IF NOT EXISTS supplier_email text,
  ADD COLUMN IF NOT EXISTS supplier_link  text;

-- ── VERIFY ────────────────────────────────────────────────
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'purchase_requests'
  AND column_name IN ('supplier_email','supplier_link')
ORDER BY column_name;
