-- ==============================================================================
-- SKEMA DATABASE SUPABASE & ROW LEVEL SECURITY (RLS) - MBOISSTATS+ PKL
-- Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)
-- ==============================================================================

-- 1. TABEL MASTER KATEGORI SEKTORAL (7 Sektor Utama BPS Kota Malang)
CREATE TABLE IF NOT EXISTS public.categories (
  id_category SERIAL PRIMARY KEY,
  category TEXT NOT NULL UNIQUE
);

-- Seed Data 7 Sektor Utama
INSERT INTO public.categories (id_category, category) VALUES
  (1, 'Perekonomian'),
  (2, 'Kemiskinan'),
  (3, 'Ketenagakerjaan'),
  (4, 'IPM'),
  (5, 'Kependudukan'),
  (6, 'Pertanian'),
  (7, 'Kesejahteraan')
ON CONFLICT (id_category) DO UPDATE 
SET category = EXCLUDED.category;

-- Reset sequence id_category
SELECT setval('categories_id_category_seq', (SELECT MAX(id_category) FROM public.categories));


-- 2. TABEL MASTER JURUSAN (MAJOR)
CREATE TABLE IF NOT EXISTS public.major (
  id_major SERIAL PRIMARY KEY,
  major TEXT NOT NULL UNIQUE
);

-- Seed Data Master Jurusan
INSERT INTO public.major (id_major, major) VALUES
  (1, 'Teknik Informatika'),
  (2, 'Sistem Informasi'),
  (3, 'Sains Data'),
  (4, 'Ilmu Komputer'),
  (5, 'Ekonomi Pembangunan'),
  (6, 'Manajemen'),
  (7, 'Akuntansi'),
  (8, 'Statistika'),
  (9, 'Matematika'),
  (10, 'Teknik Sipil'),
  (11, 'Perencanaan Wilayah & Kota (PWK)'),
  (12, 'Ilmu Komunikasi'),
  (13, 'Administrasi Publik'),
  (14, 'Sosiologi'),
  (15, 'Pendidikan / Keguruan'),
  (16, 'Pertanian / Agribisnis'),
  (17, 'Kesehatan Masyarakat / Kedokteran'),
  (18, 'Pariwisata / Perhotelan'),
  (19, 'Hukum'),
  (20, 'Umum / Lainnya')
ON CONFLICT (id_major) DO UPDATE 
SET major = EXCLUDED.major;

SELECT setval('major_id_major_seq', (SELECT MAX(id_major) FROM public.major));


-- 3. TABEL PEMETAAN JURUSAN KE KATEGORI REKOMENDASI (Smart Default Onboarding)
CREATE TABLE IF NOT EXISTS public.major_recommendations (
  id SERIAL PRIMARY KEY,
  major_id INTEGER NOT NULL REFERENCES public.major(id_major) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES public.categories(id_category) ON DELETE CASCADE,
  CONSTRAINT uq_major_category UNIQUE (major_id, category_id)
);

-- Seed Pemetaan Relevansi Jurusan -> Kategori Sektor
-- ID Kategori: 1:Ekonomi, 2:Kemiskinan, 3:TenagaKerja, 4:IPM, 5:Penduduk, 6:Pertanian, 7:Kesejahteraan
INSERT INTO public.major_recommendations (major_id, category_id) VALUES
  (1, 1), (1, 3),        -- TI -> Perekonomian, Ketenagakerjaan
  (2, 1), (2, 3),        -- SI -> Perekonomian, Ketenagakerjaan
  (3, 1), (3, 4), (3, 2),-- Sains Data -> Perekonomian, IPM, Kemiskinan
  (4, 1), (4, 3),        -- Ilmu Komputer -> Perekonomian, Ketenagakerjaan
  (5, 1), (5, 2), (5, 7),-- Ekonomi -> Perekonomian, Kemiskinan, Kesejahteraan
  (6, 1), (6, 3), (6, 7),-- Manajemen -> Perekonomian, Ketenagakerjaan, Kesejahteraan
  (7, 1), (7, 7),        -- Akuntansi -> Perekonomian, Kesejahteraan
  (8, 1), (8, 4), (8, 5),-- Statistika -> Perekonomian, IPM, Kependudukan
  (9, 1), (9, 4),        -- Matematika -> Perekonomian, IPM
  (10, 1), (10, 5),      -- Teknik Sipil -> Perekonomian, Kependudukan
  (11, 1), (11, 5),      -- PWK -> Perekonomian, Kependudukan
  (12, 5), (12, 7),      -- Komunikasi -> Kependudukan, Kesejahteraan
  (13, 2), (13, 4), (13, 7), -- Adm Publik -> Kemiskinan, IPM, Kesejahteraan
  (14, 2), (14, 5), (14, 7), -- Sosiologi -> Kemiskinan, Kependudukan, Kesejahteraan
  (15, 4), (15, 7),      -- Pendidikan -> IPM, Kesejahteraan
  (16, 6), (16, 1),      -- Pertanian -> Pertanian, Perekonomian
  (17, 4), (17, 7),      -- Kesehatan -> IPM, Kesejahteraan
  (18, 1), (18, 7),      -- Pariwisata -> Perekonomian, Kesejahteraan
  (19, 2), (19, 7),      -- Hukum -> Kemiskinan, Kesejahteraan
  (20, 1), (20, 5)       -- Umum -> Perekonomian, Kependudukan
ON CONFLICT DO NOTHING;


-- 4. TABEL PROFIL PENGGUNA (USER_ALL)
CREATE TABLE IF NOT EXISTS public.user_all (
  id_user UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  name TEXT,
  phone TEXT,
  type_user TEXT DEFAULT 'umum', -- 'umum' | 'mahasiswa' | 'peneliti' | 'asn'
  institution_id TEXT,
  university_id TEXT,
  education_id TEXT,
  work_id TEXT,
  major_id_major INTEGER REFERENCES public.major(id_major),
  age INTEGER,
  gender TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 5. TABEL PREFERENSI MINAT PENGGUNA (USER_INTERESTS)
CREATE TABLE IF NOT EXISTS public.user_interests (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.user_all(id_user) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES public.categories(id_category) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT uq_user_category UNIQUE (user_id, category_id)
);


-- 6. TABEL MASTER KONTEN STATISTIK BPS (CONTENTS)
CREATE TABLE IF NOT EXISTS public.contents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL UNIQUE,
  action_type TEXT NOT NULL DEFAULT 'view_pdf',
  cover_url TEXT,
  content_url TEXT,
  content_type TEXT CHECK (content_type = ANY (ARRAY['brs'::text, 'publikasi'::text, 'infografis'::text])),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 7. TABEL RELASI KONTEN KE KATEGORI (CONTENTS_HAS_CATEGORIES)
CREATE TABLE IF NOT EXISTS public.contents_has_categories (
  id SERIAL PRIMARY KEY,
  contents_id_content UUID NOT NULL REFERENCES public.contents(id) ON DELETE CASCADE,
  categories_id_category INTEGER NOT NULL REFERENCES public.categories(id_category) ON DELETE CASCADE,
  CONSTRAINT uq_content_category UNIQUE (contents_id_content, categories_id_category)
);


-- 8. TABEL YOUTUBE STREAMS (LIVE / ARCHIVE BPS)
CREATE TABLE IF NOT EXISTS public.youtube_streams (
  id SERIAL PRIMARY KEY,
  video_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  thumbnail_url TEXT,
  published_at TIMESTAMP WITH TIME ZONE,
  is_live BOOLEAN DEFAULT false,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 9. TABEL LOG AKTIVITAS (ACTIVITY_LOGS)
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type TEXT NOT NULL, -- 'view_page', 'view_pdf', 'download_file', 'click_menu', 'search'
  title TEXT NOT NULL,
  platform TEXT NOT NULL,    -- 'android', 'ios', 'web', 'unknown'
  user_id TEXT,              -- Device ID (anon) atau User UUID / Email (login)
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  contents_id_content UUID REFERENCES public.contents(id) ON DELETE SET NULL,
  youtube_streams_id_streams INTEGER REFERENCES public.youtube_streams(id) ON DELETE SET NULL,
  category_id INTEGER REFERENCES public.categories(id_category) ON DELETE SET NULL,
  module_name TEXT DEFAULT 'fitur'
);

-- Indexing untuk query analitik & time-decay
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON public.activity_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_activity_logs_category_id ON public.activity_logs(category_id);


-- 10. TABEL PROFIL BUKU TAMU BPS (USERS_BUKU_TAMU - Integrasi CustomerApiService)
CREATE TABLE IF NOT EXISTS public.users_buku_tamu (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  gender TEXT,
  age INTEGER,
  work_name TEXT,
  education_name TEXT,
  university_name TEXT,
  institution_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 11. TABEL TARGET HASIL PREDIKSI ML (USER_RECOMMENDATIONS - Untuk Orang 2 & 3)
CREATE TABLE IF NOT EXISTS public.user_recommendations (
  id SERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,             -- device_id atau user email / id
  content_id UUID REFERENCES public.contents(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES public.categories(id_category),
  predicted_score NUMERIC(6,4) NOT NULL,
  model_version TEXT DEFAULT 'v1.0-svd',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT uq_user_rec_item UNIQUE (user_id, content_id)
);

CREATE INDEX IF NOT EXISTS idx_user_recommendations_user_id ON public.user_recommendations(user_id);


-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Mengizinkan akses publik/anonim untuk logging & onboarding tanpa blokir SSO
-- ==============================================================================

-- A. Aktifkan RLS
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_all ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.major ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.major_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_buku_tamu ENABLE ROW LEVEL SECURITY;

-- B. Policy Master Read-Only (Categories, Major, Contents, Streams)
CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Public read major" ON public.major FOR SELECT USING (true);
CREATE POLICY "Public read major_recommendations" ON public.major_recommendations FOR SELECT USING (true);
CREATE POLICY "Public read contents" ON public.contents FOR SELECT USING (true);
CREATE POLICY "Public read contents_has_categories" ON public.contents_has_categories FOR SELECT USING (true);
CREATE POLICY "Public read youtube_streams" ON public.youtube_streams FOR SELECT USING (true);

-- C. Policy Activity Logs (Public Insert & Select per user)
CREATE POLICY "Public insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Public select activity_logs" ON public.activity_logs FOR SELECT USING (true);

-- D. Policy User & Onboarding (Public Upsert)
CREATE POLICY "Public upsert user_all" ON public.user_all FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public upsert user_interests" ON public.user_interests FOR ALL USING (true) WITH CHECK (true);

-- E. Policy User Recommendations (ML Prediction Sync)
CREATE POLICY "Public read user_recommendations" ON public.user_recommendations FOR SELECT USING (true);
CREATE POLICY "Service insert user_recommendations" ON public.user_recommendations FOR ALL USING (true) WITH CHECK (true);

-- F. Policy Buku Tamu
CREATE POLICY "Public read users_buku_tamu" ON public.users_buku_tamu FOR SELECT USING (true);
