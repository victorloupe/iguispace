-- ══════════════════════════════════════════════════════
-- FIX: Permissões de escrita para admin em projects e storage
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- 1. Admin pode INSERT / UPDATE / DELETE em qualquer projeto
--    (a policy existente "projects_admin_all" só cobre SELECT)
DROP POLICY IF EXISTS "projects_admin_write" ON projects;
CREATE POLICY "projects_admin_write" ON projects
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 2. Admin pode fazer upload/update de arquivos no storage de qualquer usuário
DROP POLICY IF EXISTS "storage_admin_write_all" ON storage.objects;
CREATE POLICY "storage_admin_write_all" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'igui-files'
    AND public.is_admin()
  );

DROP POLICY IF EXISTS "storage_admin_update_all" ON storage.objects;
CREATE POLICY "storage_admin_update_all" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'igui-files'
    AND public.is_admin()
  );

-- 3. Garantir que is_admin() seja STABLE para cache eficiente
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN STABLE SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND active = true
  );
END;
$$ LANGUAGE plpgsql;
