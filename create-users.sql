-- ═══════════════════════════════════════════════════════════════
--  MGTS Request & Expenses Hub — Create Auth Users + Roles
--  Run in: Supabase Dashboard → SQL Editor
--
--  Creates 3 test users in auth.users (email-confirmed, no invite)
--  then inserts their roles.
--
--  Default password for all: Mgts2025!
--  Change after first login via Supabase Auth → Users
-- ═══════════════════════════════════════════════════════════════

-- ── ENABLE pgcrypto (needed for crypt/gen_salt) ───────────────────
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── CREATE AUTH USERS ─────────────────────────────────────────────
-- (Supabase SQL Editor runs with service role — can write auth.users)

DO $$
DECLARE
  uid_finance    uuid := gen_random_uuid();
  uid_authoriser uuid := gen_random_uuid();
  uid_requestor  uuid := gen_random_uuid();
BEGIN

  -- ── 1. Finance / Admin (Andy Baines) ──
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    uid_finance, 'authenticated', 'authenticated',
    'andrew.baines@mgts.co.uk',
    crypt('Mgts2025!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Andrew Baines"}',
    now(), now(), '', '', '', ''
  )
  ON CONFLICT (email) DO NOTHING;

  INSERT INTO user_roles (email, name, role)
  VALUES ('andrew.baines@mgts.co.uk', 'Andrew Baines', 'finance')
  ON CONFLICT (email) DO NOTHING;

  -- ── 2. Authoriser ──
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    uid_authoriser, 'authenticated', 'authenticated',
    'authoriser@mgts.co.uk',
    crypt('Mgts2025!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Test Authoriser"}',
    now(), now(), '', '', '', ''
  )
  ON CONFLICT (email) DO NOTHING;

  INSERT INTO user_roles (email, name, role)
  VALUES ('authoriser@mgts.co.uk', 'Test Authoriser', 'authoriser')
  ON CONFLICT (email) DO NOTHING;

  -- ── 3. Requestor ──
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    uid_requestor, 'authenticated', 'authenticated',
    'requestor@mgts.co.uk',
    crypt('Mgts2025!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Test Requestor"}',
    now(), now(), '', '', '', ''
  )
  ON CONFLICT (email) DO NOTHING;

  INSERT INTO user_roles (email, name, role)
  VALUES ('requestor@mgts.co.uk', 'Test Requestor', 'requestor')
  ON CONFLICT (email) DO NOTHING;

END $$;

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT au.email, ur.name, ur.role, ur.is_active
FROM auth.users au
JOIN user_roles ur ON ur.email = au.email
ORDER BY ur.role;

-- Expected: 3 rows — andrew.baines@, authoriser@, requestor@
-- All with role: finance / authoriser / requestor
