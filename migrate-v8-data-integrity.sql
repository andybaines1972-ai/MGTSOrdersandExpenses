-- migrate-v8-data-integrity.sql
-- Fix data integrity issues: status constraint, duplicates, approval mismatches
-- Run this in Supabase Dashboard → SQL Editor → New Query
--
-- !! RUN THIS FIRST — BEFORE ANYTHING ELSE !!
-- The original tables only allow ('Pending','Authorised','Rejected','Processed')
-- but the two-level auth system (v6) introduced 'Approved' as an intermediate
-- status. This constraint must be updated BEFORE any status='Approved' updates.

-- ════════════════════════════════════════════════════════════════════════════════
-- STEP 0: Fix the status CHECK constraint to include 'Approved'
-- Without this, ANY update that sets status='Approved' will fail with:
--   "new row violates check constraint expense_claims_status_check"
-- ════════════════════════════════════════════════════════════════════════════════

-- Purchase Requests
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS purchase_requests_status_check;
ALTER TABLE purchase_requests ADD CONSTRAINT purchase_requests_status_check
  CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed'));

-- Expense Claims
ALTER TABLE expense_claims DROP CONSTRAINT IF EXISTS expense_claims_status_check;
ALTER TABLE expense_claims ADD CONSTRAINT expense_claims_status_check
  CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed'));

-- Mileage Claims
ALTER TABLE mileage_claims DROP CONSTRAINT IF EXISTS mileage_claims_status_check;
ALTER TABLE mileage_claims ADD CONSTRAINT mileage_claims_status_check
  CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed'));


-- ════════════════════════════════════════════════════════════════════════════════
-- STEP 1: Create system_settings table (for Rates & Settings admin panel)
-- ════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS system_settings (
  setting_key   text PRIMARY KEY,
  setting_value text NOT NULL DEFAULT '{}',
  updated_at    timestamptz DEFAULT NOW()
);

ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read settings"
ON system_settings FOR SELECT TO authenticated USING (true);

CREATE POLICY "Finance can manage settings"
ON system_settings FOR ALL TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role = 'finance')
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role = 'finance')
);


-- ════════════════════════════════════════════════════════════════════════════════
-- STEP 2: Pre-audit — see how many records have mismatched status/approval
-- ════════════════════════════════════════════════════════════════════════════════

SELECT
  'purchase_requests' as table_name,
  COUNT(*) as affected_records
FROM purchase_requests
WHERE status = 'Pending' AND authorised_by IS NOT NULL
UNION ALL
SELECT
  'expense_claims',
  COUNT(*)
FROM expense_claims
WHERE status = 'Pending' AND authorised_by IS NOT NULL
UNION ALL
SELECT
  'mileage_claims',
  COUNT(*)
FROM mileage_claims
WHERE status = 'Pending' AND authorised_by IS NOT NULL;


-- ════════════════════════════════════════════════════════════════════════════════
-- STEP 3: Fix Issue #4 — approval state mismatches
-- Records with authorised_by populated but still status='Pending'
-- NOW SAFE because Step 0 added 'Approved' to the allowed values
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE purchase_requests
SET status = 'Approved', updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;

UPDATE expense_claims
SET status = 'Approved', updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;

UPDATE mileage_claims
SET status = 'Approved', updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;


-- ════════════════════════════════════════════════════════════════════════════════
-- ISSUE #2: Identify potential duplicate expense claims
-- Find claims with same employee, month, and very similar total amounts (within £1)
-- ════════════════════════════════════════════════════════════════════════════════

-- Query to identify duplicates (review results manually before deleting)
SELECT
  e1.id,
  e1.ref_number,
  e1.employee_name,
  e1.claim_month,
  e1.total,
  e1.status,
  e1.created_at,
  e1.updated_at,
  'DUPLICATE OF → ' || e2.ref_number as note
FROM expense_claims e1
INNER JOIN expense_claims e2 ON
  e1.employee_email = e2.employee_email AND
  e1.claim_month = e2.claim_month AND
  ABS(CAST(e1.total AS NUMERIC) - CAST(e2.total AS NUMERIC)) < 1.00 AND
  e1.id > e2.id -- e1 is the newer record (higher ID)
ORDER BY e1.employee_name, e1.claim_month, e1.created_at;

-- ════════════════════════════════════════════════════════════════════════════════
-- MANUAL CLEANUP INSTRUCTIONS FOR ISSUE #2
-- ════════════════════════════════════════════════════════════════════════════════
--
-- After running the above query, review the results:
-- 1. Identify which duplicate is the "real" one (usually older date = original)
-- 2. Delete the duplicate(s) by running:
--
--    DELETE FROM expense_claims WHERE ref_number = '[DUPLICATE_REF]';
--
-- 3. If attachments were uploaded, also delete from request_attachments:
--
--    DELETE FROM request_attachments
--    WHERE request_type = 'expense' AND request_id = '[DUPLICATE_ID]';
--
-- 4. Run the verification query below to confirm duplicates are gone
-- ════════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════════
-- ADD CONSTRAINTS TO PREVENT FUTURE ISSUES
-- ════════════════════════════════════════════════════════════════════════════════

-- Optional: Add approval-sync constraint to prevent Pending + approver mismatch
-- Only add AFTER all data is cleaned up (Steps 2-3 above)
-- These are SEPARATE from the status CHECK constraint updated in Step 0

ALTER TABLE purchase_requests
  DROP CONSTRAINT IF EXISTS pr_status_approval_sync;
ALTER TABLE purchase_requests
  ADD CONSTRAINT pr_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );

ALTER TABLE expense_claims
  DROP CONSTRAINT IF EXISTS ec_status_approval_sync;
ALTER TABLE expense_claims
  ADD CONSTRAINT ec_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );

ALTER TABLE mileage_claims
  DROP CONSTRAINT IF EXISTS mi_status_approval_sync;
ALTER TABLE mileage_claims
  ADD CONSTRAINT mi_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );


-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES - Run after fixing to confirm all is well
-- ════════════════════════════════════════════════════════════════════════════════

-- Verify no more Pending records with approvals
SELECT 'PASS: No Pending+Approved mismatches' as status
WHERE NOT EXISTS (
  SELECT 1 FROM purchase_requests WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM expense_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM mileage_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
);

-- Verify duplicate removal
SELECT
  'Duplicate expense claims remaining: ' || COUNT(*) as status
FROM (
  SELECT e1.employee_email, e1.claim_month
  FROM expense_claims e1
  INNER JOIN expense_claims e2 ON
    e1.employee_email = e2.employee_email AND
    e1.claim_month = e2.claim_month AND
    ABS(CAST(e1.total AS NUMERIC) - CAST(e2.total AS NUMERIC)) < 1.00 AND
    e1.id > e2.id
) t;

-- Summary of all claims by status
SELECT status, COUNT(*) as count
FROM (
  SELECT status FROM purchase_requests
  UNION ALL
  SELECT status FROM expense_claims
  UNION ALL
  SELECT status FROM mileage_claims
) all_claims
GROUP BY status
ORDER BY status;
