-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request Hub — v5 Migration
--  Run in: Supabase Dashboard → SQL Editor
--  Fixes ref number generation to be RLS-safe (uses server-side counter)
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Counter table (one row per prefix) ────────────────────────
CREATE TABLE IF NOT EXISTS ref_counters (
  prefix  text PRIMARY KEY,
  current integer NOT NULL DEFAULT 0
);

-- Seed with the highest existing refs across all three tables so
-- newly generated refs don't collide with old data.
INSERT INTO ref_counters (prefix, current)
VALUES
  ('PRQ', (SELECT COALESCE(MAX(CAST(regexp_replace(ref_number,'[^0-9]','','g') AS integer)),0) FROM purchase_requests)),
  ('EXP', (SELECT COALESCE(MAX(CAST(regexp_replace(ref_number,'[^0-9]','','g') AS integer)),0) FROM expense_claims)),
  ('MIL', (SELECT COALESCE(MAX(CAST(regexp_replace(ref_number,'[^0-9]','','g') AS integer)),0) FROM mileage_claims))
ON CONFLICT (prefix) DO UPDATE SET current = EXCLUDED.current;

-- ── 2. RPC function (SECURITY DEFINER bypasses RLS) ──────────────
CREATE OR REPLACE FUNCTION next_ref(p_prefix text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next integer;
BEGIN
  INSERT INTO ref_counters (prefix, current) VALUES (p_prefix, 1)
  ON CONFLICT (prefix) DO UPDATE
    SET current = ref_counters.current + 1
  RETURNING current INTO v_next;
  RETURN p_prefix || lpad(v_next::text, 4, '0');
END;
$$;

-- Grant execute to all authenticated users
GRANT EXECUTE ON FUNCTION next_ref(text) TO authenticated;

-- RLS: allow all authenticated users to see ref_counters (read-only)
ALTER TABLE ref_counters ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read counters"
  ON ref_counters FOR SELECT TO authenticated USING (true);

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT prefix, current, next_ref(prefix) AS would_generate FROM ref_counters;
-- Roll back the verify calls so they don't waste numbers:
-- (the verify SELECT above calls next_ref which increments — run in a transaction
--  and rollback, or just check current values instead)
SELECT prefix, current FROM ref_counters;
