-- ============================================================
-- MGTS Request & Expenses Hub — migration v12  (HOTFIX)
-- Fixes login: "Your account has no role assigned".
--
-- migrate-v10 re-created a policy ON user_roles whose condition itself
-- SELECTs FROM user_roles. Postgres rejects that as infinite recursion,
-- so every logged-in read of user_roles fails and the app can't find the
-- user's role. This replaces that self-referential check with a
-- SECURITY DEFINER helper function (which bypasses RLS internally, so no
-- recursion). Run ONCE in the Supabase SQL editor.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_finance_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE email = auth.jwt()->>'email'
      AND role IN ('finance','finance_approval')
      AND is_active
  );
$$;

DROP POLICY IF EXISTS "Finance can manage roles" ON public.user_roles;
CREATE POLICY "Finance can manage roles"
ON public.user_roles FOR ALL TO authenticated
USING ( public.is_finance_admin() )
WITH CHECK ( public.is_finance_admin() );

-- "Users can view roles" (USING true) is unchanged and still lets any signed-in
-- user read roles, so login works again immediately after this runs.
