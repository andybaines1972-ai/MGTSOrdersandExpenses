-- migrate-v6.sql
-- Two-level authorisation: adds finance authorisation fields
-- Run this in Supabase Dashboard → SQL Editor → New Query

-- Purchase Requests
ALTER TABLE purchase_requests
  ADD COLUMN IF NOT EXISTS finance_authorised_by TEXT,
  ADD COLUMN IF NOT EXISTS finance_authorised_date DATE,
  ADD COLUMN IF NOT EXISTS finance_authoriser_notes TEXT;

-- Expense Claims
ALTER TABLE expense_claims
  ADD COLUMN IF NOT EXISTS finance_authorised_by TEXT,
  ADD COLUMN IF NOT EXISTS finance_authorised_date DATE,
  ADD COLUMN IF NOT EXISTS finance_authoriser_notes TEXT;

-- Mileage Claims
ALTER TABLE mileage_claims
  ADD COLUMN IF NOT EXISTS finance_authorised_by TEXT,
  ADD COLUMN IF NOT EXISTS finance_authorised_date DATE,
  ADD COLUMN IF NOT EXISTS finance_authoriser_notes TEXT;

-- Migrate any existing "Authorised" records that were approved under the old
-- single-level flow: copy the authoriser info into the finance fields so the
-- audit trail is preserved, then set status to "Authorised" (no change needed
-- since they already are). These records effectively had both levels done by
-- the same person under the old flow.
UPDATE purchase_requests
  SET finance_authorised_by    = authorised_by,
      finance_authorised_date  = authorised_date,
      finance_authoriser_notes = ''
  WHERE status IN ('Authorised','Processed')
    AND finance_authorised_by IS NULL
    AND authorised_by IS NOT NULL;

UPDATE expense_claims
  SET finance_authorised_by    = authorised_by,
      finance_authorised_date  = authorised_date,
      finance_authoriser_notes = ''
  WHERE status IN ('Authorised','Processed')
    AND finance_authorised_by IS NULL
    AND authorised_by IS NOT NULL;

UPDATE mileage_claims
  SET finance_authorised_by    = authorised_by,
      finance_authorised_date  = authorised_date,
      finance_authoriser_notes = ''
  WHERE status IN ('Authorised','Processed')
    AND finance_authorised_by IS NULL
    AND authorised_by IS NOT NULL;
