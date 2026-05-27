-- ══════════════════════════════════════════════════════
-- MIGRATION: Criar tabela link_categories + migrar dados
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════

-- 1. Criar tabela link_categories
CREATE TABLE IF NOT EXISTS public.link_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  position   INT  NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT link_categories_name_key UNIQUE (name)
);

ALTER TABLE public.link_categories ENABLE ROW LEVEL SECURITY;

-- Todos autenticados podem LER categorias
CREATE POLICY "link_categories_read" ON public.link_categories
  FOR SELECT USING (auth.role() = 'authenticated');

-- Só admin pode INSERIR, ATUALIZAR, DELETAR
CREATE POLICY "link_categories_admin_insert" ON public.link_categories
  FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "link_categories_admin_update" ON public.link_categories
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "link_categories_admin_delete" ON public.link_categories
  FOR DELETE USING (public.is_admin());


-- 2. Migrar categorias existentes da tabela links
INSERT INTO public.link_categories (name, position)
SELECT DISTINCT category, ROW_NUMBER() OVER (ORDER BY category) - 1
FROM public.links
WHERE category IS NOT NULL AND category != ''
ON CONFLICT (name) DO NOTHING;


-- 3. (Opcional) Se quiser garantir categorias padrão mesmo sem links existentes:
INSERT INTO public.link_categories (name, position) VALUES
  ('3D Warehouse',  0),
  ('Revestimentos', 1),
  ('Mobiliário',    2),
  ('Paisagismo',    3),
  ('Fornecedores',  4),
  ('Referências',   5),
  ('Geral',         6)
ON CONFLICT (name) DO NOTHING;
