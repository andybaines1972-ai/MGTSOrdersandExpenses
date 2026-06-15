-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request Hub — v4 Migration
--  Run in: Supabase Dashboard → SQL Editor
--  Adds invoice_number to purchase_requests
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE purchase_requests
  ADD COLUMN IF NOT EXISTS invoice_number text;

-- ── VERIFY ────────────────────────────────────────────────
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'purchase_requests'
  AND column_name = 'invoice_number';
