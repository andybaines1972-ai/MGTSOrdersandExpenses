-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request & Expenses Hub — Supabase Setup
--  Run in: Supabase Dashboard → SQL Editor
--
--  BEFORE RUNNING:
--    1. Create a new Supabase project for MGTS (same account, new project)
--    2. Copy the project URL + anon key into index.html
--    3. Run this entire script once
--    4. Create Storage bucket manually (see bottom of file)
-- ═══════════════════════════════════════════════════════════════════


-- ── USER ROLES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
  id        uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  email     text    UNIQUE NOT NULL,
  name      text    NOT NULL,
  role      text    NOT NULL CHECK (role IN ('requestor','authoriser','finance')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT NOW()
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view roles" ON user_roles;
DROP POLICY IF EXISTS "Finance can manage roles" ON user_roles;

CREATE POLICY "Users can view roles"
ON user_roles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Finance can manage roles"
ON user_roles FOR ALL TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role = 'finance')
)
WITH CHECK (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role = 'finance')
);


-- ── PURCHASE REQUESTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS purchase_requests (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_number          text        UNIQUE NOT NULL,
  requested_by        text        NOT NULL,
  requested_by_email  text,
  request_date        date        NOT NULL DEFAULT CURRENT_DATE,
  site                text,
  supplier            text,
  items               jsonb       NOT NULL DEFAULT '[]',
  delivery_cost       numeric(10,2) NOT NULL DEFAULT 0,
  subtotal            numeric(10,2) NOT NULL DEFAULT 0,
  total               numeric(10,2) NOT NULL DEFAULT 0,
  reason              text,
  status              text        NOT NULL DEFAULT 'Pending'
                      CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed')),
  authorised_by       text,
  authorised_date     date,
  authoriser_notes    text,
  po_number           text,
  nl_code             text,
  pl_account          text,
  payment_method      text,
  finance_notes       text,
  created_at          timestamptz NOT NULL DEFAULT NOW(),
  updated_at          timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Requestors see own purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Authorisers see all purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Finance sees all purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Requestors can insert purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Authorisers can update purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Finance can update purchase requests" ON purchase_requests;
DROP POLICY IF EXISTS "Requestors can delete own pending requests" ON purchase_requests;

CREATE POLICY "Requestors see own purchase requests"
ON purchase_requests FOR SELECT TO authenticated
USING (
  requested_by_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance'))
);

CREATE POLICY "Requestors can insert purchase requests"
ON purchase_requests FOR INSERT TO authenticated
WITH CHECK (requested_by_email = auth.jwt()->>'email');

CREATE POLICY "Authorisers can update purchase requests"
ON purchase_requests FOR UPDATE TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance'))
);

CREATE POLICY "Requestors can delete own pending requests"
ON purchase_requests FOR DELETE TO authenticated
USING (requested_by_email = auth.jwt()->>'email' AND status = 'Pending');


-- ── EXPENSE CLAIMS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expense_claims (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_number      text        UNIQUE NOT NULL,
  employee_name   text        NOT NULL,
  employee_email  text,
  claim_month     text        NOT NULL,
  items           jsonb       NOT NULL DEFAULT '[]',
  total           numeric(10,2) NOT NULL DEFAULT 0,
  total_vat       numeric(10,2) NOT NULL DEFAULT 0,
  total_ex_vat    numeric(10,2) NOT NULL DEFAULT 0,
  status          text        NOT NULL DEFAULT 'Pending'
                  CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed')),
  authorised_by   text,
  authorised_date date,
  authoriser_notes text,
  finance_notes   text,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  updated_at      timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE expense_claims ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Expense claims select" ON expense_claims;
DROP POLICY IF EXISTS "Expense claims insert" ON expense_claims;
DROP POLICY IF EXISTS "Expense claims update" ON expense_claims;
DROP POLICY IF EXISTS "Expense claims delete" ON expense_claims;

CREATE POLICY "Expense claims select"
ON expense_claims FOR SELECT TO authenticated
USING (
  employee_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance'))
);
CREATE POLICY "Expense claims insert"
ON expense_claims FOR INSERT TO authenticated
WITH CHECK (employee_email = auth.jwt()->>'email');
CREATE POLICY "Expense claims update"
ON expense_claims FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance')));
CREATE POLICY "Expense claims delete"
ON expense_claims FOR DELETE TO authenticated
USING (employee_email = auth.jwt()->>'email' AND status = 'Pending');


-- ── MILEAGE CLAIMS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mileage_claims (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_number            text        UNIQUE NOT NULL,
  employee_name         text        NOT NULL,
  employee_email        text,
  claim_month           text        NOT NULL,
  vehicle_reg           text,
  vehicle_type          text,
  mileage_rate          numeric(5,4),
  month_start_mileage   integer     NOT NULL DEFAULT 0,
  month_end_mileage     integer     NOT NULL DEFAULT 0,
  total_mileage         integer     NOT NULL DEFAULT 0,
  business_mileage      integer     NOT NULL DEFAULT 0,
  private_mileage       integer     NOT NULL DEFAULT 0,
  commute_miles         numeric(6,1),
  journeys              jsonb       NOT NULL DEFAULT '[]',
  overnight_stays       integer     NOT NULL DEFAULT 0,
  overnight_rate        numeric(6,2) NOT NULL DEFAULT 35.00,
  overnight_total       numeric(8,2) NOT NULL DEFAULT 0,
  mileage_total         numeric(8,2) NOT NULL DEFAULT 0,
  total_claim           numeric(8,2) NOT NULL DEFAULT 0,
  status                text        NOT NULL DEFAULT 'Pending'
                        CHECK (status IN ('Pending','Approved','Authorised','Rejected','Processed')),
  authorised_by         text,
  authorised_date       date,
  authoriser_notes      text,
  finance_notes         text,
  created_at            timestamptz NOT NULL DEFAULT NOW(),
  updated_at            timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE mileage_claims ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Mileage claims select" ON mileage_claims;
DROP POLICY IF EXISTS "Mileage claims insert" ON mileage_claims;
DROP POLICY IF EXISTS "Mileage claims update" ON mileage_claims;
DROP POLICY IF EXISTS "Mileage claims delete" ON mileage_claims;

CREATE POLICY "Mileage claims select"
ON mileage_claims FOR SELECT TO authenticated
USING (
  employee_email = auth.jwt()->>'email'
  OR EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance'))
);
CREATE POLICY "Mileage claims insert"
ON mileage_claims FOR INSERT TO authenticated
WITH CHECK (employee_email = auth.jwt()->>'email');
CREATE POLICY "Mileage claims update"
ON mileage_claims FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM user_roles WHERE email = auth.jwt()->>'email' AND role IN ('authoriser','finance')));
CREATE POLICY "Mileage claims delete"
ON mileage_claims FOR DELETE TO authenticated
USING (employee_email = auth.jwt()->>'email' AND status = 'Pending');


-- ── REQUEST ATTACHMENTS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS request_attachments (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id   uuid        NOT NULL,
  request_type text        NOT NULL CHECK (request_type IN ('purchase','expense','mileage')),
  file_name    text        NOT NULL,
  file_path    text        NOT NULL,
  uploaded_by  text,
  uploaded_at  timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE request_attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Attachments select" ON request_attachments;
DROP POLICY IF EXISTS "Attachments insert" ON request_attachments;
DROP POLICY IF EXISTS "Attachments delete" ON request_attachments;

CREATE POLICY "Attachments select" ON request_attachments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Attachments insert" ON request_attachments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Attachments delete" ON request_attachments FOR DELETE TO authenticated USING (true);


-- ── SEED TEST USERS (edit emails to match your Supabase Auth users) ──
-- Run this AFTER creating the auth users in Supabase Auth → Users
-- INSERT INTO user_roles (email, name, role) VALUES
--   ('requestor@mgts.co.uk',  'Test Requestor',  'requestor'),
--   ('authoriser@mgts.co.uk', 'Test Authoriser',  'authoriser'),
--   ('finance@mgts.co.uk',    'Test Finance',     'finance');


-- ═══════════════════════════════════════════════════════════════════
--  STORAGE BUCKET — must be done via Supabase Dashboard UI
--  Storage → New Bucket → name: "mgts-attachments" → Public: ON
--  Then add a policy:  authenticated users → SELECT + INSERT + DELETE
-- ═══════════════════════════════════════════════════════════════════

-- ── VERIFY ────────────────────────────────────────────────────────
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
