"""
Synthetic Data Augmenter for MBOISSTATS+ PKL
Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)

REVISI (2 Sep 2026): Versi sebelumnya mengarang sendiri daftar 20 jurusan dan
20 konten dummy dengan ID yang TIDAK COCOK dengan data live di Supabase
(50 jurusan resmi, 733 konten resmi). Versi ini membaca master data
(categories, major, major_recommendations, contents, contents_has_categories,
user_all, user_interests) langsung dari export CSV live di
`backend/data/real_export/`, sehingga seluruh ID yang dipakai untuk log
sintetis benar-benar merujuk ke baris yang ada di Supabase.

Log aktivitas sintetis di sini bersifat AUGMENTASI, bukan pengganti:
`activity_logs_rows.csv` real (per 2 Sep 2026) baru berisi 265 baris untuk
295 user terdaftar -- terlalu tipis untuk melatih model rekomendasi. Output
`raw_activity_logs.csv` menggabungkan log real + log sintetis, dengan kolom
tambahan `source` ('real' / 'synthetic') agar keduanya bisa dibedakan dan
proporsi augmentasi tetap transparan untuk laporan PKL.

User yang dipakai untuk log sintetis adalah user REAL dari user_all
(bukan user fiktif) -- interest-nya diturunkan dari user_interests jika ada,
atau dari major_recommendations berdasarkan major_id_major user tsb.
Ini penting: kalau log sintetis ini nanti diinsert ke Supabase, foreign key
ke user_all dan contents akan valid, bukan UUID karangan yang menggantung.
"""

import argparse
import csv
import os
import random
import uuid
from datetime import datetime, timedelta, timezone
from collections import defaultdict

REAL_EXPORT_DIR = os.path.join("backend", "data", "real_export")


def load_categories(real_dir):
    """id_category -> nama kategori (persis nilai live, contoh: 'tenaga_kerja')."""
    path = os.path.join(real_dir, "categories_rows.csv")
    categories = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            categories[int(row["id_category"])] = row["category"]
    return categories


def load_majors(real_dir):
    """id_major -> nama jurusan (50 baris resmi)."""
    path = os.path.join(real_dir, "major_rows.csv")
    majors = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            majors[int(row["id_major"])] = row["major"]
    return majors


def load_major_recommendations(real_dir):
    """id_major -> list of category_id (Smart Default Onboarding, 114 baris resmi)."""
    path = os.path.join(real_dir, "major_recommendations_rows.csv")
    mapping = defaultdict(list)
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            mapping[int(row["major_id"])].append(int(row["category_id"]))
    return dict(mapping)


def load_contents_catalog(real_dir):
    """
    Gabungkan contents_rows.csv + contents_has_categories_rows.csv menjadi katalog
    konten dengan category_id. 14 konten punya >1 kategori di data real; untuk
    keperluan log sintetis kita pakai kategori pertama yang muncul per konten
    (cukup untuk keperluan sampling per-sektor, bukan sumber utama relasi many-to-many).
    """
    content_to_categories = defaultdict(list)
    rel_path = os.path.join(real_dir, "contents_has_categories_rows.csv")
    with open(rel_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            content_to_categories[row["contents_id_content"]].append(int(row["categories_id_category"]))

    catalog = []
    contents_path = os.path.join(real_dir, "contents_rows.csv")
    with open(contents_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cats = content_to_categories.get(row["id"], [])
            if not cats:
                continue  # konten tanpa kategori tidak berguna untuk sampling per-sektor
            catalog.append({
                "id": row["id"],
                "title": row["title"],
                "category_id": cats[0],
                "all_category_ids": cats,
                "type": row["content_type"],
                "module": row["content_type"],
                "url": row["content_url"],
            })
    return catalog


def load_real_users(real_dir):
    """id_user -> dict profil user real dari user_all (295 baris)."""
    path = os.path.join(real_dir, "user_all_rows.csv")
    users = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            major_raw = row.get("major_id_major", "").strip()
            users[row["id_user"]] = {
                "id_user": row["id_user"],
                "email": row["email"],
                "name": row["name"],
                "type_user": row["type_user"],
                "major_id": int(major_raw) if major_raw else None,
            }
    return users


def load_user_interests(real_dir):
    """user_id -> list category_id, dari user_interests real (baru 12 baris -- masih tipis)."""
    path = os.path.join(real_dir, "user_interests_rows.csv")
    interests = defaultdict(list)
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            interests[row["user_id"]].append(int(row["category_id"]))
    return dict(interests)


def load_real_activity_logs(real_dir):
    """Baca activity_logs_rows.csv real apa adanya, tandai source='real'."""
    path = os.path.join(real_dir, "activity_logs_rows.csv")
    logs = []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            logs.append({
                "id": row["id"],
                "action_type": row["action_type"],
                "title": row["title"],
                "platform": row["platform"],
                "user_id": row["user_id"],
                "timestamp": row["timestamp"],
                "contents_id_content": row["contents_id_content"],
                "youtube_streams_id_streams": row["youtube_streams_id_streams"],
                "category_id": row["category_id"],
                "module_name": row["module_name"],
                "source": "real",
            })
    return logs


# Fitur interaktif non-konten (tidak ada di tabel `contents`, murni halaman fitur di app).
# category_id sudah memakai skema live (1=perekonomian, 2=tenaga_kerja, 3=ipm,
# 4=kemiskinan, 5=kependudukan, 6=pertanian, 7=kesejahteraan).
FEATURE_PAGES = [
    {"title": "Penduduk Bekerja (IPM)", "category_id": 3, "module": "fitur"},
    {"title": "Usia Harapan Hidup", "category_id": 3, "module": "fitur"},
    {"title": "Harapan Lama Sekolah", "category_id": 3, "module": "fitur"},
    {"title": "Penduduk Menurut Jenis Kelamin", "category_id": 5, "module": "fitur"},
    {"title": "Penduduk Menurut Kecamatan", "category_id": 5, "module": "fitur"},
    {"title": "Laju Pertumbuhan Ekonomi", "category_id": 1, "module": "fitur"},
    {"title": "Produk Domestik Regional Bruto (PDRB)", "category_id": 1, "module": "fitur"},
    {"title": "Inflasi Bulanan Kota Malang", "category_id": 1, "module": "fitur"},
    {"title": "Tingkat Kemiskinan", "category_id": 4, "module": "fitur"},
    {"title": "Indeks Kedalaman Kemiskinan", "category_id": 4, "module": "fitur"},
    {"title": "Tingkat Pengangguran Terbuka", "category_id": 2, "module": "fitur"},
    {"title": "Gini Rasio Kota Malang", "category_id": 7, "module": "fitur"},
    {"title": "Produksi Padi & Beras", "category_id": 6, "module": "fitur"},
]


def build_user_profiles(real_users, user_interests, major_recommendations):
    """
    Bangun profil interest per user REAL:
      1. Pakai user_interests eksplisit kalau ada (onboarding manual).
      2. Kalau tidak ada, turunkan dari major_recommendations berdasarkan major_id_major.
      3. Kalau major juga tidak ada (user tipe 'umum' tanpa jurusan), interest kosong
         -> nanti di-treat sebagai eksplorasi acak saat generate log.
    """
    profiles = {}
    for uid, u in real_users.items():
        if uid in user_interests:
            interests = user_interests[uid]
        elif u["major_id"] and u["major_id"] in major_recommendations:
            interests = major_recommendations[u["major_id"]]
        else:
            interests = []
        profiles[uid] = {**u, "interests": interests}
    return profiles


def generate_synthetic_logs(user_profiles, content_catalog, num_logs, days_range, seed):
    """
    Augmentasi log aktivitas sintetis di atas user & konten REAL.
    Distribusi & time-decay bias sama seperti versi awal, tapi seluruh ID
    (user_id, contents_id_content, category_id) sekarang menunjuk ke baris
    yang benar-benar ada di Supabase.
    """
    rng = random.Random(seed)
    logs = []
    now = datetime.now(timezone.utc)

    user_pool = list(user_profiles.values())
    content_by_category = defaultdict(list)
    for c in content_catalog:
        content_by_category[c["category_id"]].append(c)

    action_types = ["view_page", "view_pdf", "download_file"]
    action_weights = [0.55, 0.30, 0.15]
    platforms = ["android", "ios"]
    platform_weights = [0.80, 0.20]

    for _ in range(num_logs):
        user = rng.choice(user_pool)

        if user["interests"] and rng.random() < 0.70:
            chosen_category_id = rng.choice(user["interests"])
        else:
            chosen_category_id = rng.randint(1, 7)

        action_type = rng.choices(action_types, weights=action_weights)[0]
        platform = rng.choices(platforms, weights=platform_weights)[0]

        decay_factor = rng.random() ** 1.8  # bias ke hari-hari terkini
        days_ago = decay_factor * days_range
        seconds_offset = rng.randint(0, 86400)
        log_time = now - timedelta(days=days_ago, seconds=seconds_offset)

        is_content = action_type in ["view_pdf", "download_file"] or rng.random() < 0.6
        candidates = content_by_category.get(chosen_category_id, [])
        feature_candidates = [f for f in FEATURE_PAGES if f["category_id"] == chosen_category_id]

        content_id = ""
        if is_content and candidates:
            item = rng.choice(candidates)
            title = item["title"]
            module_name = item["module"]
            content_id = item["id"]
        elif feature_candidates:
            item = rng.choice(feature_candidates)
            title = item["title"]
            module_name = item["module"]
        else:
            title = f"Statistik kategori {chosen_category_id}"
            module_name = "fitur"

        logs.append({
            "id": str(uuid.uuid4()),
            "action_type": action_type,
            "title": title,
            "platform": platform,
            "user_id": user["id_user"],
            "timestamp": log_time.isoformat(),
            "contents_id_content": content_id,
            "youtube_streams_id_streams": "",
            "category_id": chosen_category_id,
            "module_name": module_name,
            "source": "synthetic",
        })

    logs.sort(key=lambda x: x["timestamp"])
    return logs


def save_to_csv(data, filepath, fieldnames):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"-> Berhasil menyimpan {len(data)} baris data ke: {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Synthetic Data Augmenter MBOISSTATS+ (berbasis data real)")
    parser.add_argument("--count", type=int, default=1000, help="Jumlah baris log SINTETIS tambahan yang di-generate")
    parser.add_argument("--days-range", type=int, default=60, help="Rentang hari ke belakang untuk timestamp sintetis")
    parser.add_argument("--output-dir", type=str, default=os.path.join("backend", "data"), help="Direktori penyimpanan CSV output")
    parser.add_argument("--real-export-dir", type=str, default=REAL_EXPORT_DIR, help="Direktori CSV export live Supabase")
    parser.add_argument("--seed", type=int, default=42, help="Random seed untuk reprodusibilitas")
    parser.add_argument("--no-real-logs", action="store_true", help="Kalau di-set, output HANYA log sintetis (tanpa menggabungkan 265 log real)")

    args = parser.parse_args()

    print("=================================================================")
    print("[*] AUGMENTASI DATA SINTETIS BERBASIS DATA REAL (ORANG 1)")
    print("=================================================================")
    print(f"Sumber data real   : {args.real_export_dir}")
    print(f"Target log sintetis: {args.count:,} baris")
    print(f"Direktori Output   : {args.output_dir}")
    print("-----------------------------------------------------------------")

    categories = load_categories(args.real_export_dir)
    majors = load_majors(args.real_export_dir)
    major_recs = load_major_recommendations(args.real_export_dir)
    content_catalog = load_contents_catalog(args.real_export_dir)
    real_users = load_real_users(args.real_export_dir)
    user_interests = load_user_interests(args.real_export_dir)

    print(f"-> {len(categories)} kategori, {len(majors)} jurusan dimuat.")
    print(f"-> {len(major_recs)}/{len(majors)} jurusan punya smart-default recommendation (dari major_recommendations_rows.csv).")
    print(f"-> {len(content_catalog)} konten (dengan kategori) dimuat dari contents_rows.csv.")
    print(f"-> {len(real_users)} user real dimuat dari user_all_rows.csv.")
    print(f"-> {len(user_interests)} user punya interest eksplisit di user_interests_rows.csv.")

    user_profiles = build_user_profiles(real_users, user_interests, major_recs)
    users_with_derived_interest = sum(1 for u in user_profiles.values() if u["interests"])
    print(f"-> {users_with_derived_interest} user punya profil interest (eksplisit atau turunan jurusan) untuk sampling.")

    # 1. Generate log sintetis (augmentasi)
    synthetic_logs = generate_synthetic_logs(
        user_profiles, content_catalog, num_logs=args.count,
        days_range=args.days_range, seed=args.seed,
    )

    # 2. Gabungkan dengan log real (kecuali diminta --no-real-logs)
    if args.no_real_logs:
        combined_logs = synthetic_logs
    else:
        real_logs = load_real_activity_logs(args.real_export_dir)
        combined_logs = real_logs + synthetic_logs
        combined_logs.sort(key=lambda x: x["timestamp"])
        print(f"-> Menggabungkan {len(real_logs)} log REAL + {len(synthetic_logs)} log SINTETIS.")

    logs_fieldnames = [
        "id", "action_type", "title", "platform", "user_id",
        "timestamp", "contents_id_content", "youtube_streams_id_streams",
        "category_id", "module_name", "source",
    ]
    logs_csv_path = os.path.join(args.output_dir, "raw_activity_logs.csv")
    save_to_csv(combined_logs, logs_csv_path, logs_fieldnames)

    # 3. Simpan katalog konten real (dipakai data_loader.py, format kompatibel dengan versi lama)
    catalog_csv_path = os.path.join(args.output_dir, "contents_catalog.csv")
    catalog_fieldnames = ["id", "title", "category_id", "type", "module", "url"]
    catalog_for_csv = [{k: c[k] for k in catalog_fieldnames} for c in content_catalog]
    save_to_csv(catalog_for_csv, catalog_csv_path, catalog_fieldnames)

    # 4. Simpan profil user real + interest (format kompatibel dengan users.csv versi lama)
    users_csv_path = os.path.join(args.output_dir, "users.csv")
    users_fieldnames = ["id_user", "device_id", "name", "email", "type_user", "major_id", "major_name", "interests", "created_at"]
    users_for_csv = []
    for u in user_profiles.values():
        users_for_csv.append({
            "id_user": u["id_user"],
            "device_id": "",  # tidak relevan lagi -- log real memakai id_user/email sebagai user_id
            "name": u["name"],
            "email": u["email"],
            "type_user": u["type_user"],
            "major_id": u["major_id"] if u["major_id"] else "",
            "major_name": majors.get(u["major_id"], "") if u["major_id"] else "",
            "interests": str(u["interests"]),
            "created_at": "",
        })
    save_to_csv(users_for_csv, users_csv_path, users_fieldnames)

    print("-----------------------------------------------------------------")
    print("[+] Augmentasi data selesai!")
    print(f"   1. {logs_csv_path} ({len(combined_logs)} logs total)")
    print(f"   2. {catalog_csv_path} ({len(content_catalog)} konten real)")
    print(f"   3. {users_csv_path} ({len(user_profiles)} user real)")
    print("=================================================================")


if __name__ == "__main__":
    main()
