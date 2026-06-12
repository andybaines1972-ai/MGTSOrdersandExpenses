-- ═══════════════════════════════════════════════════════════════════
--  MGTS Request Hub — Storage Policies
--  Run in: Supabase Dashboard → SQL Editor
--
--  The mgts-attachments bucket must already exist (Public: ON).
--  This script adds the INSERT / DELETE policies so authenticated
--  users can upload and remove files.
-- ═══════════════════════════════════════════════════════════════════

-- Allow any authenticated user to upload to this bucket
CREATE POLICY "Authenticated users can upload attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'mgts-attachments');

-- Allow any authenticated user to delete files in this bucket
CREATE POLICY "Authenticated users can delete attachments"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'mgts-attachments');

-- Allow anyone (public) to read/download files (public bucket)
CREATE POLICY "Public can read attachments"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'mgts-attachments');

-- ── VERIFY ────────────────────────────────────────────────
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'objects' AND schemaname = 'storage'
  AND policyname LIKE '%attachment%';
