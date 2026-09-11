-- ============================================================
-- MGTS Request & Expenses Hub — migration v11
-- Saved baskets: reusable Purchase Request line-item / supplier templates.
-- Each basket is private to its owner, unless saved as 'shared' (visible to all).
-- Run ONCE in the Supabase SQL editor before this build can save/load baskets.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_baskets (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_email      text        NOT NULL,
  name             text        NOT NULL,
  scope            text        NOT NULL DEFAULT 'private' CHECK (scope IN ('private','shared')),
  items            jsonb       NOT NULL DEFAULT '[]',
  supplier         text,
  supplier_tel     text,
  supplier_email   text,
  supplier_ref     text,
  supplier_link    text,
  supplier_address text,
  created_at       timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_baskets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Baskets select own or shared" ON public.order_baskets;
DROP POLICY IF EXISTS "Baskets insert own"           ON public.order_baskets;
DROP POLICY IF EXISTS "Baskets update own"           ON public.order_baskets;
DROP POLICY IF EXISTS "Baskets delete own"           ON public.order_baskets;

-- Everyone can read their own baskets plus any shared ones
CREATE POLICY "Baskets select own or shared"
ON public.order_baskets FOR SELECT TO authenticated
USING (owner_email = auth.jwt()->>'email' OR scope = 'shared');

-- You can only create baskets under your own email
CREATE POLICY "Baskets insert own"
ON public.order_baskets FOR INSERT TO authenticated
WITH CHECK (owner_email = auth.jwt()->>'email');

-- You can only change / delete your own baskets (incl. shared ones you created)
CREATE POLICY "Baskets update own"
ON public.order_baskets FOR UPDATE TO authenticated
USING (owner_email = auth.jwt()->>'email');

CREATE POLICY "Baskets delete own"
ON public.order_baskets FOR DELETE TO authenticated
USING (owner_email = auth.jwt()->>'email');
