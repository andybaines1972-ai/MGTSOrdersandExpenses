-- migrate-v7.sql
-- Finance delegation & holiday cover
-- Run this in Supabase Dashboard → SQL Editor → New Query

CREATE TABLE IF NOT EXISTS finance_delegations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  delegate_email TEXT NOT NULL,
  delegate_name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  created_by_email TEXT NOT NULL,
  created_by_name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: finance users can manage delegations, delegates can read their own
ALTER TABLE finance_delegations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Finance can manage delegations"
  ON finance_delegations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.email = auth.jwt()->>'email'
        AND user_roles.role = 'finance'
    )
  );

CREATE POLICY "Delegates can read own active delegations"
  ON finance_delegations FOR SELECT
  USING (
    delegate_email = auth.jwt()->>'email'
    AND is_active = true
  );
