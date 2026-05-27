-- ══════════════════════════════════════════════════════
-- SCHEMA iGUi Prancha System — rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- ── 1. PROFILES (extensão de auth.users) ────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email     TEXT,
  name      TEXT,
  role      TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  active    BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Função auxiliar para verificar se o usuário é administrador (SECURITY DEFINER para evitar recursão RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado lê seu próprio perfil
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Admin lê todos os perfis
CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (public.is_admin());

-- Admin atualiza qualquer perfil
CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (public.is_admin());

-- Usuário atualiza só o próprio nome
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ── Trigger: criar profile automaticamente ao criar usuário
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  default_role TEXT := 'user';
BEGIN
  IF NEW.email IN ('victorlourencoprojetos@gmail.com', 'projeto@igui.com') THEN
    default_role := 'admin';
  END IF;

  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)), 
    default_role
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ── 2. PROJECTS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_name  TEXT,
  project_code TEXT,
  city         TEXT,
  store        TEXT,
  model        TEXT,
  proj_date    TEXT,
  session_data JSONB NOT NULL DEFAULT '{}',
  thumbnail_url TEXT,
  created_by   TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Usuário vê e gerencia SÓ os próprios projetos
CREATE POLICY "projects_own" ON projects
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admin vê todos
CREATE POLICY "projects_admin_all" ON projects
  FOR SELECT USING (public.is_admin());

-- Trigger: updated_at automático
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS projects_updated_at ON projects;
CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ── 3. LINKS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS links (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  url         TEXT NOT NULL,
  description TEXT,
  category    TEXT NOT NULL DEFAULT 'Geral',
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE links ENABLE ROW LEVEL SECURITY;

-- Todos os autenticados LÊEM
CREATE POLICY "links_read_all" ON links
  FOR SELECT USING (auth.role() = 'authenticated');

-- Só admin INSERE, ATUALIZA, EXCLUI
CREATE POLICY "links_admin_insert" ON links
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "links_admin_update" ON links
  FOR UPDATE USING (public.is_admin());
CREATE POLICY "links_admin_delete" ON links
  FOR DELETE USING (public.is_admin());

DROP TRIGGER IF EXISTS links_updated_at ON links;
CREATE TRIGGER links_updated_at
  BEFORE UPDATE ON links
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ══════════════════════════════════════════════════════
-- STORAGE — rodar no Supabase Dashboard > Storage
-- ══════════════════════════════════════════════════════
-- 1. Criar bucket: igui-files  (private)
-- 2. Rodar as policies abaixo:

INSERT INTO storage.buckets (id, name, public)
VALUES ('igui-files', 'igui-files', false)
ON CONFLICT (id) DO NOTHING;

-- Usuário faz upload SÓ na própria pasta
CREATE POLICY "storage_upload_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'igui-files'
    AND auth.uid()::text = (string_to_array(name, '/'))[1]
  );

-- Usuário lê SÓ os próprios arquivos
CREATE POLICY "storage_read_own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'igui-files'
    AND auth.uid()::text = (string_to_array(name, '/'))[1]
  );

-- Usuário deleta SÓ os próprios arquivos
CREATE POLICY "storage_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'igui-files'
    AND auth.uid()::text = (string_to_array(name, '/'))[1]
  );

-- Admin lê tudo no storage
CREATE POLICY "storage_admin_read_all" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'igui-files'
    AND public.is_admin()
  );


-- ══════════════════════════════════════════════════════
-- PRIMEIRO ADMIN — substituir pelo seu e-mail
-- ══════════════════════════════════════════════════════
-- Rode APÓS criar sua conta no sistema:
-- UPDATE profiles SET role = 'admin' WHERE email = 'seu@email.com';
