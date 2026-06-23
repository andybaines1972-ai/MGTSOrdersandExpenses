# Data Integrity Cleanup Guide

**Date:** 23 June 2026  
**Status:** REQUIRES MANUAL EXECUTION  
**Audience:** Finance Admin (Admin Access Required)

---

## Overview

Two data integrity issues have been identified and require manual cleanup before deploying to production:

1. **Issue #2:** Duplicate expense claims appearing as pending
2. **Issue #4:** Expense claims showing "approved by Manager" but status still "Pending"

This guide provides step-by-step instructions to identify and fix these issues.

---

## Issue #4: Approval State Mismatches (AUTOMATED FIX)

**Problem:** Some claims have `authorised_by` field populated but status is still 'Pending'

**Root Cause:** Two-level authorisation system was added (migrate-v6.sql), but existing records may have inconsistent state

**Fix:** Automated - Run migration script

### Step 1: Identify Affected Records

Before making changes, review what needs fixing:

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Create a **New Query** and paste this:

```sql
SELECT
  'purchase_requests' as table_name,
  COUNT(*) as affected_records
FROM purchase_requests
WHERE status = 'Pending' AND authorised_by IS NOT NULL
UNION ALL
SELECT 'expense_claims', COUNT(*)
FROM expense_claims
WHERE status = 'Pending' AND authorised_by IS NOT NULL
UNION ALL
SELECT 'mileage_claims', COUNT(*)
FROM mileage_claims
WHERE status = 'Pending' AND authorised_by IS NOT NULL;
```

3. **Execute** and note how many records have this issue

### Step 2: Apply the Automatic Fix

1. In Supabase SQL Editor, create a **New Query**
2. Copy the entire content from: `migrate-v8-data-integrity.sql` (lines 1-60, the first section)
3. **Execute**
4. **Expected Result:**
   - Records with `status='Pending'` and `authorised_by` populated will have status changed to `'Approved'`
   - These records can now proceed to finance authorisation

### Step 3: Verify the Fix

Run this verification query:

```sql
-- Should return 0 if fix was successful
SELECT COUNT(*) as mismatch_count
FROM (
  SELECT 1 FROM purchase_requests WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM expense_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
  UNION ALL
  SELECT 1 FROM mileage_claims WHERE status = 'Pending' AND authorised_by IS NOT NULL
) t;
```

**Expected:** Should show `0`

---

## Issue #2: Duplicate Expense Claims (MANUAL REVIEW + CLEANUP)

**Problem:** Two identical or near-identical expense claims appearing from same employee for same month

**Root Cause:** Accidental double-submission or double-insert bug

**Fix:** Requires manual review to identify "real" vs "duplicate"

### Step 1: Identify Duplicates

1. In Supabase SQL Editor, create a **New Query**
2. Paste the duplicate detection query:

```sql
-- Find potential duplicates: same employee, same month, similar amounts
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

3. **Execute**
4. **Review Results:**
   - If empty result = No duplicates found ✅
   - If results show duplicate pairs:
     - **The OLDER record** (earlier `created_at`) = Original
     - **The NEWER record** (later `created_at`) = Duplicate to delete

### Step 2: Decide Which Records to Delete

For each duplicate pair:

```
Original (KEEP):  EXP006, Janet, June 2026, £127.50, created 2026-06-15 10:30
Duplicate (DELETE): EXP007, Janet, June 2026, £127.50, created 2026-06-15 10:35
```

**Decision Rule:**
- **KEEP** the record that was approved/authorised first
- **DELETE** the newer record with duplicate data

### Step 3: Delete Duplicates

For each duplicate identified:

1. Note the `ref_number` of the duplicate (e.g., `EXP007`)
2. In Supabase SQL Editor, create a **New Query**:

```sql
-- DELETE THE DUPLICATE (NOT THE ORIGINAL!)
DELETE FROM expense_claims WHERE ref_number = 'EXP007';
```

3. **Important:** Double-check you're deleting the newer duplicate, not the original!

### Step 4: Delete Associated Attachments (If Any)

If the duplicate claim had file uploads:

```sql
-- Get the ID of the deleted claim first
SELECT id FROM expense_claims WHERE ref_number = 'EXP007';
-- If it returns nothing, it's already deleted. Get the ID from the query results above.

-- Then delete attachments
DELETE FROM request_attachments
WHERE request_type = 'expense' AND request_id = '[DUPLICATE_CLAIM_ID]';
```

### Step 5: Verify Cleanup

Run the duplicate detection query again - should now show fewer or no results.

---

## Issue #3: Prevent Future Problems

To prevent these issues from recurring, add database constraints:

1. In Supabase SQL Editor, create a **New Query**
2. Paste these constraint additions:

```sql
-- Ensure Pending records don't have approval metadata
ALTER TABLE purchase_requests
  ADD CONSTRAINT pr_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );

ALTER TABLE expense_claims
  ADD CONSTRAINT ec_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );

ALTER TABLE mileage_claims
  ADD CONSTRAINT mi_status_approval_sync CHECK (
    (status = 'Pending' AND authorised_by IS NULL) OR
    (status IN ('Approved','Authorised','Rejected','Processed'))
  );
```

3. **Execute**
4. **Result:** Database will now reject any inserts/updates that violate these rules

---

## Complete Verification Checklist

After completing all cleanup:

- [ ] Issue #4 fix executed (approval state mismatches corrected)
- [ ] Issue #2 duplicates identified (ran detection query)
- [ ] Duplicate records reviewed (identified which are originals vs duplicates)
- [ ] Duplicates deleted (removed all newer duplicates)
- [ ] Attachments cleaned up (removed files from deleted claims)
- [ ] Constraints added (prevent future mismatches)
- [ ] Final verification passed (no remaining issues)

---

## Rollback Instructions (If Needed)

If something goes wrong, you can undo the fixes:

### Undo Issue #4 Fix
```sql
-- Revert status changes (if you have a backup)
-- This would require knowing which records were changed
-- Best practice: Keep notes of the count from Step 1
```

### Undo Issue #2 Deletions
```sql
-- Restore from backup (manual, outside database)
-- PostgreSQL doesn't have easy UNDELETE
-- Ensure you have backups before deleting!
```

**Recommendation:** Create a Supabase backup before running any cleanup

---

## Timeline

- **Issue #4 Fix:** ~5 minutes (automated query)
- **Issue #2 Detection:** ~5 minutes (manual review)
- **Issue #2 Cleanup:** ~10-15 minutes per duplicate (careful deletion)
- **Constraints:** ~2 minutes
- **Verification:** ~5 minutes

**Total Expected Time:** 30-40 minutes

---

## Contact

If you encounter:
- **SQL errors:** Check the query syntax and Supabase documentation
- **Data confusion:** Review the migration file comments for context
- **Unable to proceed:** Create a Supabase support ticket with the error message

---

## Notes

- **Always test on a development database first** if you have one
- **Keep records of what you delete** in case of audit questions
- **Log any actions** in your change management system
- **Update the team** once cleanup is complete
