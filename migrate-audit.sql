-- ── MGTS Request Hub — Audit Log Migration ──────────────────────────────────
-- Run this once in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- Adds the audit_log table for the Change Log and Debug features.

CREATE TABLE IF NOT EXISTS audit_log (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  user_email  TEXT        NOT NULL,
  user_name   TEXT,
  action      TEXT        NOT NULL,
  record_type TEXT,
  record_id   UUID,
  ref_number  TEXT,
  details     JSONB       DEFAULT '{}'::jsonb
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Finance can read all audit entries
CREATE POLICY "finance_read_audit" ON audit_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE email = auth.email() AND role = 'finance'
    )
  );

-- Any authenticated user can write their own audit entries
CREATE POLICY "auth_insert_audit" ON audit_log
  FOR INSERT WITH CHECK (auth.email() = user_email);

-- Index for fast lookups by ref and date
CREATE INDEX IF NOT EXISTS idx_audit_ref    ON audit_log (ref_number);
CREATE INDEX IF NOT EXISTS idx_audit_user   ON audit_log (user_email);
CREATE INDEX IF NOT EXISTS idx_audit_date   ON audit_log (created_at DESC);
