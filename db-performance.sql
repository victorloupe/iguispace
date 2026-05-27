-- ══════════════════════════════════════════════════════════════════
-- db-performance.sql — Otimizações de performance
-- Rodar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. MARCAR is_admin() como STABLE ────────────────────────────
-- Sem STABLE, o PostgreSQL chama a função uma vez por linha avaliada
-- na policy de RLS. Com STABLE, o resultado é cacheado dentro de
-- cada query — reduz chamadas à tabela profiles drasticamente.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN STABLE SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND active = true
  );
END;
$$ LANGUAGE plpgsql;

-- ── 2. ÍNDICES NA TABELA projects ────────────────────────────────
-- Acelera a busca por dono (RLS policy projects_own usa auth.uid() = user_id)
CREATE INDEX IF NOT EXISTS idx_projects_user_id
  ON projects(user_id);

-- Acelera o ORDER BY updated_at DESC na listagem
CREATE INDEX IF NOT EXISTS idx_projects_updated_at
  ON projects(updated_at DESC);

-- ── 3. ÍNDICE NA TABELA profiles ────────────────────────────────
-- is_admin() filtra por id + role + active — índice composto cobre tudo
CREATE INDEX IF NOT EXISTS idx_profiles_admin_check
  ON profiles(id, role, active);

-- ── 4. VERIFICAR RESULTADO ──────────────────────────────────────
-- Rode após aplicar e confira se os índices aparecem:
-- SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('projects','profiles');
