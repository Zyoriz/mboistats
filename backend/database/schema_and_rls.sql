-- ==============================================================================
-- SKEMA DATABASE SUPABASE & ROW LEVEL SECURITY (RLS) - MBOISSTATS+ PKL
-- Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)
-- ==============================================================================
--
-- !! JANGAN DIJALANKAN ULANG DI SQL EDITOR SUPABASE !!
--
-- Status per 2 Sep 2026: seluruh tabel di bawah SUDAH ADA dan SUDAH BERISI
-- data live di project Supabase (nramd/mboistats). File ini murni DOKUMENTASI
-- REFERENSI (struktur skema + seed data yang sudah diverifikasi cocok
-- dengan export CSV live), bukan skrip migrasi yang harus/boleh dieksekusi.
--
-- Alasan tidak boleh dijalankan ulang:
--   1. RLS di project ini saat ini DISABLED pada tabel-tabel utama
--      (dicek langsung di dashboard: Database > Policies, 2 Sep 2026).
--      Policy INSERT/SELECT/DELETE yang benar-benar aktif sekarang punya
--      nama berbeda (bahasa Indonesia, mis. "Izinkan Insert Log Publik")
--      dari yang didefinisikan di file ini -- artinya file ini TIDAK PERNAH
--      dieksekusi terhadap project ini sebelumnya.
--   2. CREATE POLICY di bawah akan ERROR jika policy dengan nama sama
--      sudah ada di database.
--   3. Blok INSERT ... ON CONFLICT DO UPDATE pada tabel master (categories,
--      major, major_recommendations) akan MENIMPA data live jika value-nya
--      berbeda dari yang sudah ada.
--
-- Nilai seed di bawah (categories, major, major_recommendations) sudah
-- disinkronkan ulang agar identik dengan hasil export live CSV per 2 Sep 2026
-- (categories_rows.csv / major_rows.csv / major_recommendations_rows.csv),
-- menggantikan versi awal yang salah (ID sektor 2/3/4 tertukar, dan daftar
-- major berisi 20 jurusan buatan yang tidak cocok dengan 50 jurusan resmi).
-- ==============================================================================

-- 1. TABEL MASTER KATEGORI SEKTORAL (7 Sektor Utama BPS Kota Malang)
CREATE TABLE IF NOT EXISTS public.categories (
  id_category SERIAL PRIMARY KEY,
  category TEXT NOT NULL UNIQUE
);

-- CATEGORIES (exact values from categories_rows.csv, 7 rows)
INSERT INTO public.categories (id_category, category) VALUES
  (1, 'perekonomian'),
  (2, 'tenaga_kerja'),
  (3, 'ipm'),
  (4, 'kemiskinan'),
  (5, 'kependudukan'),
  (6, 'pertanian'),
  (7, 'kesejahteraan')
ON CONFLICT (id_category) DO UPDATE SET category = EXCLUDED.category;

-- 2. TABEL MASTER JURUSAN (MAJOR)
CREATE TABLE IF NOT EXISTS public.major (
  id_major SERIAL PRIMARY KEY,
  major TEXT NOT NULL UNIQUE
);

-- MAJOR (exact values from major_rows.csv, 50 rows)
INSERT INTO public.major (id_major, major) VALUES
  (1, 'Teknik Informatika'),
  (2, 'Ilmu Komputer'),
  (3, 'Sains Data'),
  (4, 'Sistem Informasi'),
  (5, 'Teknologi Informasi'),
  (6, 'Teknik Sipil'),
  (7, 'Perencanaan Wilayah & Kota (PWK)'),
  (8, 'Teknik Industri'),
  (9, 'Teknik Mesin'),
  (10, 'Teknik Elektro'),
  (11, 'Teknik Kimia'),
  (12, 'Teknik Lingkungan'),
  (13, 'Ekonomi Pembangunan'),
  (14, 'Ilmu Ekonomi'),
  (15, 'Manajemen'),
  (16, 'Bisnis'),
  (17, 'Kewirausahaan'),
  (18, 'Akuntansi'),
  (19, 'Keuangan'),
  (20, 'Statistika'),
  (21, 'Matematika'),
  (22, 'Fisika'),
  (23, 'Kimia'),
  (24, 'Biologi'),
  (25, 'Hukum'),
  (26, 'Ilmu Administrasi Publik'),
  (27, 'Ilmu Administrasi Bisnis'),
  (28, 'Ilmu Komunikasi'),
  (29, 'Hubungan Internasional'),
  (30, 'Sosiologi'),
  (31, 'Psikologi'),
  (32, 'Antropologi'),
  (33, 'Pendidikan / Keguruan'),
  (34, 'Pertanian'),
  (35, 'Agribisnis'),
  (36, 'Kehutanan'),
  (37, 'Peternakan'),
  (38, 'Kedokteran'),
  (39, 'Kesehatan Masyarakat'),
  (40, 'Farmasi'),
  (41, 'Keperawatan'),
  (42, 'Gizi'),
  (43, 'Pariwisata'),
  (44, 'Perhotelan'),
  (45, 'Desain Komunikasi Visual (DKV)'),
  (46, 'Arsitektur'),
  (47, 'Sastra / Bahasa'),
  (48, 'Seni & Kriya'),
  (49, 'Lainnya'),
  (50, 'Umum')
ON CONFLICT (id_major) DO UPDATE SET major = EXCLUDED.major;

-- 3. TABEL PEMETAAN JURUSAN KE KATEGORI REKOMENDASI (Smart Default Onboarding)
CREATE TABLE IF NOT EXISTS public.major_recommendations (
  id SERIAL PRIMARY KEY,
  major_id INTEGER NOT NULL REFERENCES public.major(id_major) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES public.categories(id_category) ON DELETE CASCADE,
  CONSTRAINT uq_major_category UNIQUE (major_id, category_id)
);

-- MAJOR_RECOMMENDATIONS (exact values from major_recommendations_rows.csv, 114 rows)
INSERT INTO public.major_recommendations (major_id, category_id) VALUES
  (50, 1),
  (49, 1),
  (48, 1),
  (46, 1),
  (45, 1),
  (44, 1),
  (43, 1),
  (37, 1),
  (36, 1),
  (35, 1),
  (34, 1),
  (29, 1),
  (27, 1),
  (23, 1),
  (22, 1),
  (21, 1),
  (20, 1),
  (19, 1),
  (18, 1),
  (17, 1),
  (16, 1),
  (15, 1),
  (14, 1),
  (13, 1),
  (12, 1),
  (11, 1),
  (10, 1),
  (9, 1),
  (8, 1),
  (7, 1),
  (6, 1),
  (5, 1),
  (4, 1),
  (3, 1),
  (2, 1),
  (1, 1),
  (45, 2),
  (44, 2),
  (27, 2),
  (17, 2),
  (16, 2),
  (15, 2),
  (11, 2),
  (10, 2),
  (9, 2),
  (8, 2),
  (5, 2),
  (4, 2),
  (2, 2),
  (1, 2),
  (47, 3),
  (42, 3),
  (41, 3),
  (40, 3),
  (39, 3),
  (38, 3),
  (33, 3),
  (31, 3),
  (24, 3),
  (23, 3),
  (22, 3),
  (21, 3),
  (20, 3),
  (12, 3),
  (3, 3),
  (42, 4),
  (39, 4),
  (32, 4),
  (30, 4),
  (26, 4),
  (25, 4),
  (20, 4),
  (14, 4),
  (13, 4),
  (7, 4),
  (3, 4),
  (50, 5),
  (49, 5),
  (47, 5),
  (46, 5),
  (32, 5),
  (30, 5),
  (29, 5),
  (28, 5),
  (26, 5),
  (25, 5),
  (12, 5),
  (7, 5),
  (6, 5),
  (37, 6),
  (36, 6),
  (35, 6),
  (34, 6),
  (24, 6),
  (48, 7),
  (43, 7),
  (42, 7),
  (41, 7),
  (40, 7),
  (39, 7),
  (38, 7),
  (33, 7),
  (32, 7),
  (31, 7),
  (30, 7),
  (28, 7),
  (26, 7),
  (25, 7),
  (19, 7),
  (18, 7),
  (16, 7),
  (15, 7),
  (14, 7),
  (13, 7)
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
