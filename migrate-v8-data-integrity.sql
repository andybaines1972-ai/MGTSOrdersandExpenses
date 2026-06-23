-- migrate-v8-data-integrity.sql
-- Fix data integrity issues: duplicate expense claims and approval state mismatches
-- Run this in Supabase Dashboard → SQL Editor → New Query

-- ════════════════════════════════════════════════════════════════════════════════
-- ISSUE #4: Fix approval state mismatches
-- When status='Pending' but authorised_by has a value, update status to 'Approved'
-- ════════════════════════════════════════════════════════════════════════════════

-- Check how many records have this issue BEFORE fixing
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

-- FIX: Update purchase_requests
UPDATE purchase_requests
SET
  status = 'Approved',
  updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;

-- FIX: Update expense_claims
UPDATE expense_claims
SET
  status = 'Approved',
  updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;

-- FIX: Update mileage_claims
UPDATE mileage_claims
SET
  status = 'Approved',
  updated_at = NOW()
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

-- Add check constraint to prevent Pending status with approvals
-- (This ensures status and approver fields stay in sync)
ALTER TABLE purchase_requests
  ADD CONSTRAINT pr_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND (authorised_by IS NOT NULL OR status = 'Pending'))
  );

ALTER TABLE expense_claims
  ADD CONSTRAINT ec_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND (authorised_by IS NOT NULL OR status = 'Pending'))
  );

ALTER TABLE mileage_claims
  ADD CONSTRAINT mi_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND (authorised_by IS NOT NULL OR status = 'Pending'))
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
