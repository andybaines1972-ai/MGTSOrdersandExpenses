-- DUPLICATE DETECTION QUERY - ISSUE #2
-- Copy and paste THIS ENTIRE query into Supabase SQL Editor
-- This is the COMPLETE, standalone query (not from migration file)

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
  e1.id > e2.id
ORDER BY e1.employee_name, e1.claim_month, e1.created_at;
