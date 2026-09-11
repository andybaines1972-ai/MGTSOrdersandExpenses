-- ============================================================
-- MGTS Request & Expenses Hub — migration v10
-- Adds a new "finance_approval" role (Ruth) that performs the finance
-- AUTHORISATION step (Approved -> Authorised), while the existing
-- "finance" role becomes the processing team (Authorised -> Processed).
--
-- Without this migration you CANNOT save a user with the new role, and —
-- critically — Row-Level-Security would block a finance_approval user from
-- reading/updating records. Run this ONCE in the Supabase SQL editor.
-- ============================================================

-- 1) Allow the new role value on user_roles
ALTER TABLE public.user_roles DROP CONSTRAINT IF EXISTS user_roles_role_check;
ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('requestor','authoriser','finance','finance_approval'));

-- 2) Let finance_approval (Ruth) manage users too (Admin tab)
DROP POLICY IF EXISTS "Finance can manage roles" ON public.user_roles;
CREATE POLICY "Finance can manage roles"
ON public.user_roles FOR ALL TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('finance','finance_approval'))
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('finance','finance_approval'))
);

-- 3) Give finance_approval the same record read/update access as authoriser + finance
--    (otherwise Ruth can't see or authorise anything).

-- Purchase Requests
DROP POLICY IF EXISTS "Requestors see own purchase requests" ON public.purchase_requests;
CREATE POLICY "Requestors see own purchase requests"
ON public.purchase_requests FOR SELECT TO authenticated
USING (
  requested_by_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval'))
);

DROP POLICY IF EXISTS "Authorisers can update purchase requests" ON public.purchase_requests;
CREATE POLICY "Authorisers can update purchase requests"
ON public.purchase_requests FOR UPDATE TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval'))
);

-- Expense Claims
DROP POLICY IF EXISTS "Expense claims select" ON public.expense_claims;
CREATE POLICY "Expense claims select"
ON public.expense_claims FOR SELECT TO authenticated
USING (
  employee_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval'))
);

DROP POLICY IF EXISTS "Expense claims update" ON public.expense_claims;
CREATE POLICY "Expense claims update"
ON public.expense_claims FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval')));

-- Mileage Claims
DROP POLICY IF EXISTS "Mileage claims select" ON public.mileage_claims;
CREATE POLICY "Mileage claims select"
ON public.mileage_claims FOR SELECT TO authenticated
USING (
  employee_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval'))
);

DROP POLICY IF EXISTS "Mileage claims update" ON public.mileage_claims;
CREATE POLICY "Mileage claims update"
ON public.mileage_claims FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance','finance_approval')));

-- 4) After running this: in Admin → Users, set Ruth's role to "Finance Approval (Ruth)"
--    and set the finance team members to "Finance (Processing Team)".
