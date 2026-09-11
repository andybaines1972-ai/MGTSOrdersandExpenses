-- ============================================================
-- MGTS Request & Expenses Hub — migration v9
-- Purchase Requests: A104 number, Trading/Charity company, goods-received tracking.
-- Mileage Claims:     store commute deducted + payable miles for the claim.
--
-- Run this ONCE in the Supabase SQL editor BEFORE deploying this build,
-- otherwise saving a purchase request / mileage claim will error on the new columns.
-- ============================================================

alter table public.purchase_requests
  add column if not exists a104_number         text,
  add column if not exists company              text,      -- 'Trading' | 'Charity'
  add column if not exists goods_received       boolean not null default false,
  add column if not exists goods_received_date  date,
  add column if not exists goods_received_by    text;

alter table public.mileage_claims
  add column if not exists commute_deducted     numeric,   -- miles deducted (home-to-work commute)
  add column if not exists payable_mileage       numeric;   -- business miles after commute deduction

-- No changes required for expense_claims:
--   * expense claim printing is client-side only (printExpenseClaim already exists)
--   * mileage editable rate uses the existing mileage_rate column
