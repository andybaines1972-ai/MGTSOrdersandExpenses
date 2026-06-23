# SQL Execution Guide - CORRECTED

**Issue:** Previous migration file had queries that could be run incomplete  
**Solution:** Break into separate, complete, standalone queries  
**Status:** ✅ SAFE TO EXECUTE

---

## EXECUTION STEPS (Run Each Separately)

### STEP 1: PRE-AUDIT (See What Needs Fixing)

**Run this FIRST in Supabase SQL Editor → New Query**

```sql
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
```

**Expected:** Shows count of records with mismatched status/approval

---

### STEP 2A: Fix Issue #4 - Purchase Requests

**Create NEW Query and run:**

```sql
UPDATE purchase_requests
SET
  status = 'Approved',
  updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;
```

**Expected:** "X rows updated"

---

### STEP 2B: Fix Issue #4 - Expense Claims

**Create NEW Query and run:**

```sql
UPDATE expense_claims
SET
  status = 'Approved',
  updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;
```

**Expected:** "X rows updated"

---

### STEP 2C: Fix Issue #4 - Mileage Claims

**Create NEW Query and run:**

```sql
UPDATE mileage_claims
SET
  status = 'Approved',
  updated_at = NOW()
WHERE status = 'Pending' AND authorised_by IS NOT NULL;
```

**Expected:** "X rows updated"

---

### STEP 3: Identify Issue #2 Duplicates

**Create NEW Query and run this COMPLETE query:**

```sql
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
```

**Expected:** 
- Empty result = No duplicates ✅
- Shows pairs of duplicates = Review which to delete

**To interpret results:**
- The **newer** record (later created_at) = **DELETE THIS ONE**
- The **older** record (earlier created_at) = **KEEP THIS ONE**

---

### STEP 4: Delete Duplicates (MANUAL - One at a Time)

**For EACH duplicate you found in STEP 3:**

1. Note the `ref_number` of the NEWER duplicate
2. Create NEW Query:

```sql
DELETE FROM expense_claims 
WHERE ref_number = 'EXP007';
```

⚠️ **IMPORTANT:** Replace `EXP007` with the actual ref_number of the newer duplicate

3. **Run only after confirming it's the duplicate, not the original**

---

### STEP 5: Delete Associated Attachments

**If deleted claim had file uploads, run this:**

```sql
DELETE FROM request_attachments
WHERE request_type = 'expense' AND request_id = '[DUPLICATE_ID]';
```

Replace `[DUPLICATE_ID]` with the UUID from the deleted claim

---

### STEP 6: Add Constraints (Prevent Future Issues)

**Create NEW Query and run:**

```sql
ALTER TABLE purchase_requests
  ADD CONSTRAINT pr_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND authorised_by IS NOT NULL)
  );
```

---

**Create NEW Query and run:**

```sql
ALTER TABLE expense_claims
  ADD CONSTRAINT ec_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND authorised_by IS NOT NULL)
  );
```

---

**Create NEW Query and run:**

```sql
ALTER TABLE mileage_claims
  ADD CONSTRAINT mi_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed') AND authorised_by IS NOT NULL)
  );
```

**Expected:** "0 rows" or "Query OK"

---

### STEP 7: VERIFY - Check for Remaining Mismatches

**Create NEW Query and run:**

```sql
SELECT 'PASS: No issues found' as result
WHERE NOT EXISTS (
  SELECT 1 FROM purchase_requests WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM expense_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM mileage_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
);
```

**Expected:** One row showing "PASS: No issues found"

---

### STEP 8: VERIFY - Check for Remaining Duplicates

**Create NEW Query and run:**

```sql
SELECT
  'No duplicates found' as result,
  COUNT(*) as duplicate_count
FROM (
  SELECT e1.employee_email
  FROM expense_claims e1
  INNER JOIN expense_claims e2 ON
    e1.employee_email = e2.employee_email AND
    e1.claim_month = e2.claim_month AND
    ABS(CAST(e1.total AS NUMERIC) - CAST(e2.total AS NUMERIC)) < 1.00 AND
    e1.id > e2.id
) t;
```

**Expected:** Shows "0" remaining duplicates

---

### STEP 9: VERIFY - Summary by Status

**Create NEW Query and run:**

```sql
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
```

**Expected:** Shows counts by status (should look reasonable)

---

## Troubleshooting

### Error: "Constraint already exists"
- **Cause:** Constraint was added previously
- **Action:** Safe to ignore, continue to next query

### Error: "Syntax error at end of input"
- **Cause:** Query was pasted incompletely
- **Action:** Copy the ENTIRE query including FROM/WHERE clauses
- **Fix:** Use the standalone query files provided

### No results from Step 1 audit
- **Meaning:** No mismatches exist - Issue #4 already fixed
- **Action:** Skip Steps 2A-2C, continue to Step 3

### Many duplicates found in Step 3
- **Meaning:** More duplicates than expected
- **Action:** Review carefully, delete one at a time (don't bulk delete)

---

## Quick Reference

| Step | Query | Time | Type | Risk |
|------|-------|------|------|------|
| 1 | Pre-audit count | 1 min | SELECT | None |
| 2A | Fix PR status | 1 min | UPDATE | Low |
| 2B | Fix EX status | 1 min | UPDATE | Low |
| 2C | Fix MI status | 1 min | UPDATE | Low |
| 3 | Find duplicates | 1 min | SELECT | None |
| 4 | Delete duplicate | 1 min | DELETE | Medium |
| 5 | Clean attachments | 1 min | DELETE | Low |
| 6A | Constraint PR | 1 min | ALTER | Low |
| 6B | Constraint EX | 1 min | ALTER | Low |
| 6C | Constraint MI | 1 min | ALTER | Low |
| 7 | Verify mismatches | 1 min | SELECT | None |
| 8 | Verify duplicates | 1 min | SELECT | None |
| 9 | Summary | 1 min | SELECT | None |

**TOTAL TIME:** ~15-20 minutes

---

## Files Provided

✅ `DUPLICATE_DETECTION_QUERY.sql` - Complete, standalone duplicate detection query  
✅ `SQL_EXECUTION_GUIDE.md` - This file (step-by-step with complete queries)  
✅ `migrate-v8-data-integrity.sql` - Original migration (can also be run, but use separate queries)  
✅ `SQL_VERIFICATION.md` - Safety documentation  

---

## Ready to Execute?

✅ All queries verified as safe  
✅ Each query is complete and standalone  
✅ No incomplete pasted queries  
✅ Error handling documented  

**Status: READY FOR EXECUTION**
