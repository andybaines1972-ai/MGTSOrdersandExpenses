-- ═══════════════════════════════════════════════════════════════
--  MGTS Request & Expenses Hub — Create / Confirm Users + Roles
--  Run in: Supabase Dashboard → SQL Editor
--
--  Safe to run multiple times (uses upsert / ON CONFLICT).
--  Handles existing unconfirmed accounts created by setup-users.js.
--  Default password for all test users: Mgts2025!
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── STEP 1: confirm + reset password for users created via signUp ─
-- (Supabase SQL Editor = service role, bypasses RLS)
UPDATE auth.users
SET
  email_confirmed_at = COALESCE(email_confirmed_at, now()),
  encrypted_password = crypt('Mgts2025!', gen_salt('bf')),
  updated_at         = now()
WHERE email IN (
  'andrew.baines@mgts.co.uk',
  'authoriser@mgts.co.uk',
  'requestor@mgts.co.uk'
);

-- ── STEP 2: create any users that don't exist yet ─────────────────
INSERT INTO auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(), 'authenticated', 'authenticated',
  u.email,
  crypt('Mgts2025!', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  json_build_object('name', u.name),
  now(), now(), '', '', '', ''
FROM (VALUES
  ('andrew.baines@mgts.co.uk', 'Andrew Baines'),
  ('authoriser@mgts.co.uk',    'Test Authoriser'),
  ('requestor@mgts.co.uk',     'Test Requestor')
) AS u(email, name)
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = u.email
);

-- ── STEP 3: create / update user roles ───────────────────────────
INSERT INTO public.user_roles (email, name, role, is_active)
VALUES
  ('andrew.baines@mgts.co.uk', 'Andrew Baines',  'finance',    true),
  ('authoriser@mgts.co.uk',    'Test Authoriser', 'authoriser', true),
  ('requestor@mgts.co.uk',     'Test Requestor',  'requestor',  true)
ON CONFLICT (email) DO UPDATE
  SET name      = EXCLUDED.name,
      role      = EXCLUDED.role,
      is_active = EXCLUDED.is_active;

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT
  au.email,
  ur.name,
  ur.role,
  CASE WHEN au.email_confirmed_at IS NOT NULL THEN 'confirmed' ELSE 'UNCONFIRMED' END AS status
FROM auth.users au
JOIN public.user_roles ur ON ur.email = au.email
ORDER BY ur.role;

-- Expected: 3 rows, all status = confirmed
