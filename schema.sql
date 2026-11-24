-- ==============================================================================
-- SIMAK 2.0: ELECTORAL & POLITICAL INTELLIGENCE DATABASE SCHEMA
-- PostgreSQL + pgvector Schema Extension
-- ==============================================================================

-- 1. Enable pgvector extension for LLM Semantic RAG
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Master Table: Indonesian Regions (BPS & Kemendagri Standardization)
CREATE TABLE IF NOT EXISTS public.regions (
    id VARCHAR(10) PRIMARY KEY, -- e.g., '33' (Jawa Tengah), '35' (Jawa Timur)
    name VARCHAR(120) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('provinsi', 'kabupaten_kota')),
    parent_id VARCHAR(10) REFERENCES public.regions(id) ON DELETE CASCADE,
    projected_dpt_2029 BIGINT NOT NULL DEFAULT 0,
    gen_z_millennial_ratio NUMERIC(5, 2) NOT NULL DEFAULT 50.0, -- percentage
    kpu_margin_2024 NUMERIC(5, 2) NOT NULL DEFAULT 0.0, -- percentage lead
    battleground_status VARCHAR(30) NOT NULL DEFAULT 'neutral' CHECK (battleground_status IN ('critical_battleground', 'lean_support', 'stronghold', 'neutral', 'contested')),
    cultural_nu_affinity NUMERIC(5, 2) NOT NULL DEFAULT 50.0, -- index 0-100
    cultural_muhammadiyah_base NUMERIC(5, 2) NOT NULL DEFAULT 50.0, -- index 0-100
    active_affiliated_media_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Table: Uploaded Documents for AI Baseline Training
CREATE TABLE IF NOT EXISTS public.uploaded_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'survei_elektoral',
        'kepuasan_publik',
        'data_kpu_bps',
        'data_sektoral_mbg_dapodik',
        'riset_kualitatif_fgd'
    )),
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    storage_url TEXT NOT NULL,
    uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    extraction_status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (extraction_status IN (
        'pending',
        'processing',
        'verified_ai',
        'needs_review',
        'failed'
    )),
    accuracy_score NUMERIC(5, 2) DEFAULT 0.0,
    extracted_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Table: Electoral Surveys & Quantitative Metrics
CREATE TABLE IF NOT EXISTS public.electoral_surveys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES public.uploaded_documents(id) ON DELETE CASCADE,
    survey_institute VARCHAR(120) NOT NULL,
    survey_wave VARCHAR(50) NOT NULL, -- e.g., 'Gelombang IV - Nov 2026'
    release_date DATE NOT NULL,
    sample_size INT NOT NULL,
    margin_of_error NUMERIC(4, 2) NOT NULL DEFAULT 2.5,
    region_id VARCHAR(10) REFERENCES public.regions(id) ON DELETE SET NULL,
    awareness_score NUMERIC(5, 2) NOT NULL, -- percentage
    likability_score NUMERIC(5, 2) NOT NULL, -- percentage
    electability_score NUMERIC(5, 2) NOT NULL, -- percentage
    public_satisfaction_score NUMERIC(5, 2) NOT NULL, -- percentage
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Table: Regional Sectoral Indicators (MBG, Dapodik, Infrastruktur)
CREATE TABLE IF NOT EXISTS public.regional_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id VARCHAR(10) NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
    total_schools_count INT NOT NULL DEFAULT 0,
    revitalized_schools_count INT NOT NULL DEFAULT 0,
    mbg_kitchen_units_count INT NOT NULL DEFAULT 0,
    mbg_student_beneficiaries BIGINT NOT NULL DEFAULT 0,
    honorer_teachers_count INT NOT NULL DEFAULT 0,
    top_pain_points JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Table: Knowledge Vector Embeddings (Semantic RAG for Brief Generator)
CREATE TABLE IF NOT EXISTS public.knowledge_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES public.uploaded_documents(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL,
    content_chunk TEXT NOT NULL,
    embedding vector(1536) NOT NULL, -- OpenAI ada-002 / text-embedding-3 or Gemini 1536
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb, -- holds category, region_id, tags
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for Fast Approximate Nearest Neighbor Search
CREATE INDEX IF NOT EXISTS knowledge_embeddings_vector_idx 
ON public.knowledge_embeddings 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- 7. Table: AI Generated Operational Briefs (Distributed to 200 Media Accounts)
CREATE TABLE IF NOT EXISTS public.ai_generated_briefs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    target_region_id VARCHAR(10) REFERENCES public.regions(id) ON DELETE SET NULL,
    target_segment VARCHAR(100) NOT NULL, -- e.g., 'Warga Nahdliyin Kultural', 'Gen Z Perkotaan'
    issue_id UUID REFERENCES public.issues(id) ON DELETE SET NULL,
    narrative_angle TEXT NOT NULL,
    hook_3sec TEXT NOT NULL,
    key_facts JSONB NOT NULL DEFAULT '[]'::jsonb,
    tone_rules TEXT NOT NULL,
    taboo_words TEXT NOT NULL,
    distributed_media_count INT NOT NULL DEFAULT 0,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploaded_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electoral_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.regional_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_generated_briefs ENABLE ROW LEVEL SECURITY;

-- Read policies for authenticated users
CREATE POLICY "Authenticated users can read regions" ON public.regions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read electoral surveys" ON public.electoral_surveys FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read regional indicators" ON public.regional_indicators FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff and admin manage documents" ON public.uploaded_documents FOR ALL TO authenticated USING (
    public.has_simak_role(auth.uid(), ARRAY['admin', 'admin_strategy', 'analis'])
);
CREATE POLICY "Staff and admin manage AI briefs" ON public.ai_generated_briefs FOR ALL TO authenticated USING (
    public.has_simak_role(auth.uid(), ARRAY['admin', 'admin_strategy', 'editor_approver', 'analis'])
);
