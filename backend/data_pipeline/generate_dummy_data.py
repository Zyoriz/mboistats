"""
Synthetic Data Generator for MBOISSTATS+ PKL
Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)

Menghasilkan 1.000+ log aktivitas realistis (cold-start) dan profil pengguna sintetis.
Output disimpan secara lokal ke CSV (dan opsional ke Supabase).
"""

import argparse
import csv
import json
import os
import random
import uuid
from datetime import datetime, timedelta, timezone

# 7 Kategori Sektoral Utama BPS Kota Malang
CATEGORIES = {
    1: {"name": "Perekonomian", "key": "perekonomian"},
    2: {"name": "Kemiskinan", "key": "kemiskinan"},
    3: {"name": "Ketenagakerjaan", "key": "ketenagakerjaan"},
    4: {"name": "IPM", "key": "ipm"},
    5: {"name": "Kependudukan", "key": "kependudukan"},
    6: {"name": "Pertanian", "key": "pertanian"},
    7: {"name": "Kesejahteraan", "key": "kesejahteraan"},
}

# Master Jurusan & Sektor Relevan (Smart Default)
MAJORS = [
    {"id": 1, "name": "Teknik Informatika", "sectors": [1, 3]},
    {"id": 2, "name": "Sistem Informasi", "sectors": [1, 3]},
    {"id": 3, "name": "Sains Data", "sectors": [1, 4, 2]},
    {"id": 4, "name": "Ilmu Komputer", "sectors": [1, 3]},
    {"id": 5, "name": "Ekonomi Pembangunan", "sectors": [1, 2, 7]},
    {"id": 6, "name": "Manajemen", "sectors": [1, 3, 7]},
    {"id": 7, "name": "Akuntansi", "sectors": [1, 7]},
    {"id": 8, "name": "Statistika", "sectors": [1, 4, 5]},
    {"id": 9, "name": "Matematika", "sectors": [1, 4]},
    {"id": 10, "name": "Teknik Sipil", "sectors": [1, 5]},
    {"id": 11, "name": "Perencanaan Wilayah & Kota (PWK)", "sectors": [1, 5]},
    {"id": 12, "name": "Ilmu Komunikasi", "sectors": [5, 7]},
    {"id": 13, "name": "Administrasi Publik", "sectors": [2, 4, 7]},
    {"id": 14, "name": "Sosiologi", "sectors": [2, 5, 7]},
    {"id": 15, "name": "Pendidikan / Keguruan", "sectors": [4, 7]},
    {"id": 16, "name": "Pertanian / Agribisnis", "sectors": [6, 1]},
    {"id": 17, "name": "Kesehatan Masyarakat", "sectors": [4, 7]},
    {"id": 18, "name": "Pariwisata / Perhotelan", "sectors": [1, 7]},
    {"id": 19, "name": "Hukum", "sectors": [2, 7]},
    {"id": 20, "name": "Umum", "sectors": [1, 5]},
]

# Katalog Konten BPS Kota Malang per Kategori
CONTENT_CATALOG = [
    # Perekonomian (ID 1)
    {"id": str(uuid.uuid4()), "title": "Perkembangan Indeks Harga Konsumen / Inflasi Kota Malang 2024", "category_id": 1, "type": "brs", "module": "brs", "cover": "cover_inflasi.jpg", "url": "https://malangkota.bps.go.id/brs/inflasi_2024.pdf"},
    {"id": str(uuid.uuid4()), "title": "Produk Domestik Regional Bruto Kota Malang Menurut Lapangan Usaha 2023", "category_id": 1, "type": "publikasi", "module": "publikasi", "cover": "cover_pdrb.jpg", "url": "https://malangkota.bps.go.id/pub/pdrb_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Tingkat Penghunian Kamar Hotel Kota Malang Semester I 2024", "category_id": 1, "type": "infografis", "module": "infografis", "cover": "cover_hotel.jpg", "url": "https://malangkota.bps.go.id/info/hotel_2024.png"},
    {"id": str(uuid.uuid4()), "title": "Laju Pertumbuhan Ekonomi (LPE) Kota Malang Triwulan II 2024", "category_id": 1, "type": "brs", "module": "brs", "cover": "cover_lpe.jpg", "url": "https://malangkota.bps.go.id/brs/lpe_tw2.pdf"},

    # Kemiskinan (ID 2)
    {"id": str(uuid.uuid4()), "title": "Profil Kemiskinan Kota Malang Tahun 2023", "category_id": 2, "type": "brs", "module": "brs", "cover": "cover_kemiskinan.jpg", "url": "https://malangkota.bps.go.id/brs/kemiskinan_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Indeks Kedalaman dan Keparahan Kemiskinan Kota Malang 2019-2023", "category_id": 2, "type": "publikasi", "module": "publikasi", "cover": "cover_indeks_kemiskinan.jpg", "url": "https://malangkota.bps.go.id/pub/indeks_kemiskinan.pdf"},
    {"id": str(uuid.uuid4()), "title": "Garis Kemiskinan dan Jumlah Penduduk Miskin Kota Malang", "category_id": 2, "type": "infografis", "module": "infografis", "cover": "cover_garis_kemiskinan.jpg", "url": "https://malangkota.bps.go.id/info/garis_miskin.png"},

    # Ketenagakerjaan (ID 3)
    {"id": str(uuid.uuid4()), "title": "Keadaan Ketenagakerjaan Kota Malang Agustus 2023", "category_id": 3, "type": "brs", "module": "brs", "cover": "cover_naker.jpg", "url": "https://malangkota.bps.go.id/brs/naker_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Tingkat Pengangguran Terbuka (TPT) Berdasarkan Tingkat Pendidikan Kota Malang", "category_id": 3, "type": "publikasi", "module": "publikasi", "cover": "cover_tpt.jpg", "url": "https://malangkota.bps.go.id/pub/tpt_pendidikan.pdf"},
    {"id": str(uuid.uuid4()), "title": "Tingkat Partisipasi Angkatan Kerja (TPAK) Kota Malang", "category_id": 3, "type": "infografis", "module": "infografis", "cover": "cover_tpak.jpg", "url": "https://malangkota.bps.go.id/info/tpak.png"},

    # IPM (ID 4)
    {"id": str(uuid.uuid4()), "title": "Indeks Pembangunan Manusia (IPM) Kota Malang 2023", "category_id": 4, "type": "brs", "module": "brs", "cover": "cover_ipm.jpg", "url": "https://malangkota.bps.go.id/brs/ipm_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Angka Harapan Hidup dan Harapan Lama Sekolah Kota Malang 2023", "category_id": 4, "type": "publikasi", "module": "publikasi", "cover": "cover_ahh.jpg", "url": "https://malangkota.bps.go.id/pub/ahh_hls.pdf"},
    {"id": str(uuid.uuid4()), "title": "Infografis Capaian IPM Kota Malang Tertinggi di Jawa Timur", "category_id": 4, "type": "infografis", "module": "infografis", "cover": "cover_ipm_jatim.jpg", "url": "https://malangkota.bps.go.id/info/ipm_capaian.png"},

    # Kependudukan (ID 5)
    {"id": str(uuid.uuid4()), "title": "Kota Malang Dalam Angka 2024", "category_id": 5, "type": "publikasi", "module": "publikasi", "cover": "cover_mda_2024.jpg", "url": "https://malangkota.bps.go.id/pub/mda_2024.pdf"},
    {"id": str(uuid.uuid4()), "title": "Hasil Sensus Penduduk dan Proyeksi Penduduk Menurut Kecamatan 2023", "category_id": 5, "type": "publikasi", "module": "publikasi", "cover": "cover_penduduk.jpg", "url": "https://malangkota.bps.go.id/pub/penduduk_kec.pdf"},
    {"id": str(uuid.uuid4()), "title": "Kepadatan dan Piramida Penduduk Kota Malang", "category_id": 5, "type": "infografis", "module": "infografis", "cover": "cover_piramida.jpg", "url": "https://malangkota.bps.go.id/info/piramida.png"},

    # Pertanian (ID 6)
    {"id": str(uuid.uuid4()), "title": "Luas Panen dan Produksi Padi di Kota Malang 2023 (Angka Tetap)", "category_id": 6, "type": "brs", "module": "brs", "cover": "cover_padi.jpg", "url": "https://malangkota.bps.go.id/brs/padi_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Statistik Pertanian, Peternakan, dan Hortikultura Kota Malang 2023", "category_id": 6, "type": "publikasi", "module": "publikasi", "cover": "cover_pertanian.jpg", "url": "https://malangkota.bps.go.id/pub/pertanian_2023.pdf"},

    # Kesejahteraan (ID 7)
    {"id": str(uuid.uuid4()), "title": "Tingkat Ketimpangan Pengeluaran Penduduk (Gini Ratio) Kota Malang 2023", "category_id": 7, "type": "brs", "module": "brs", "cover": "cover_gini.jpg", "url": "https://malangkota.bps.go.id/brs/gini_2023.pdf"},
    {"id": str(uuid.uuid4()), "title": "Statistik Kesejahteraan Rakyat dan Pengeluaran Konsumsi Kota Malang 2023", "category_id": 7, "type": "publikasi", "module": "publikasi", "cover": "cover_kesra.jpg", "url": "https://malangkota.bps.go.id/pub/kesra_2023.pdf"},
]

# Fitur Interaktif Tambahan
FEATURE_PAGES = [
    {"title": "Penduduk Bekerja (IPM)", "category_id": 4, "module": "fitur"},
    {"title": "Usia Harapan Hidup", "category_id": 4, "module": "fitur"},
    {"title": "Harapan Lama Sekolah", "category_id": 4, "module": "fitur"},
    {"title": "Penduduk Menurut Jenis Kelamin", "category_id": 5, "module": "fitur"},
    {"title": "Penduduk Menurut Kecamatan", "category_id": 5, "module": "fitur"},
    {"title": "Laju Pertumbuhan Ekonomi", "category_id": 1, "module": "fitur"},
    {"title": "Produk Domestik Regional Bruto (PDRB)", "category_id": 1, "module": "fitur"},
    {"title": "Inflasi Bulanan Kota Malang", "category_id": 1, "module": "fitur"},
    {"title": "Tingkat Kemiskinan", "category_id": 2, "module": "fitur"},
    {"title": "Indeks Kedalaman Kemiskinan", "category_id": 2, "module": "fitur"},
    {"title": "Tingkat Pengangguran Terbuka", "category_id": 3, "module": "fitur"},
    {"title": "Gini Rasio Kota Malang", "category_id": 7, "module": "fitur"},
    {"title": "Produksi Padi & Beras", "category_id": 6, "module": "fitur"},
]

NAMES = [
    "Ahmad Fauzi", "Budi Santoso", "Citra Lestari", "Dewi Anggraini", "Eko Prasetyo",
    "Fajar Nugroho", "Gita Permata", "Hadi Wijaya", "Indah Sari", "Joko Susilo",
    "Kartika Putri", "Lukman Hakim", "Maya Safitri", "Nurul Hidayah", "Oki Setiawan",
    "Putri Handayani", "Rian Pratama", "Siti Rahmawati", "Taufik Hidayat", "Wahyu Utomo",
    "Yolanda Fransiska", "Zulfa Azizah", "Dimas Arya", "Nabila Syahrani", "Rizky Firmansyah"
]


def generate_users(num_users=50):
    """Menghasilkan list pengguna sintetis."""
    users = []
    for i in range(num_users):
        user_uuid = str(uuid.uuid4())
        name = f"{random.choice(NAMES)} {i+1}"
        email = f"user_{i+1}_{name.lower().replace(' ', '_')}@example.com"
        is_student = random.random() < 0.75  # 75% mahasiswa, 25% umum
        user_type = "mahasiswa" if is_student else "umum"
        
        major = random.choice(MAJORS) if is_student else MAJORS[-1]
        
        # User interests (kategori favorit dari jurusan + 1 random)
        interests = list(major["sectors"])
        if random.random() < 0.4:
            extra = random.randint(1, 7)
            if extra not in interests:
                interests.append(extra)
        
        users.append({
            "id_user": user_uuid,
            "device_id": f"device_{user_uuid[:8]}",
            "name": name,
            "email": email,
            "type_user": user_type,
            "major_id": major["id"],
            "major_name": major["name"],
            "interests": interests,
            "created_at": (datetime.now(timezone.utc) - timedelta(days=random.randint(30, 90))).isoformat()
        })
    return users


def generate_activity_logs(users, num_logs=1000, days_range=60):
    """
    Menghasilkan data log aktivitas realistis dengan variasi aksi,
    preferensi jurusan, dan distribusi tanggal time-decay.
    """
    logs = []
    now = datetime.now(timezone.utc)
    
    # Distribusi aksi
    # view_page: 55%, view_pdf: 30%, download_file: 15%
    action_types = ["view_page", "view_pdf", "download_file"]
    action_weights = [0.55, 0.30, 0.15]
    
    platforms = ["android", "ios"]
    platform_weights = [0.80, 0.20]

    for _ in range(num_logs):
        user = random.choice(users)
        user_id = user["email"] if random.random() < 0.5 else user["device_id"]
        
        # Pengguna cenderung mengakses kategori yang sesuai minat jurusannya (70% probability)
        if random.random() < 0.70 and user["interests"]:
            chosen_category_id = random.choice(user["interests"])
        else:
            chosen_category_id = random.randint(1, 7)
            
        action_type = random.choices(action_types, weights=action_weights)[0]
        platform = random.choices(platforms, weights=platform_weights)[0]
        
        # Waktu log: Menggunakan power law / exponential decay agar log terbaru lebih banyak
        # (menggambarkan user retention & time decay)
        decay_factor = random.random() ** 1.8  # bias ke angka kecil (hari-hari terkini)
        days_ago = decay_factor * days_range
        seconds_offset = random.randint(0, 86400)
        log_time = now - timedelta(days=days_ago, seconds=seconds_offset)
        
        # Konten atau Fitur
        is_content = action_type in ["view_pdf", "download_file"] or random.random() < 0.6
        content_items = [c for c in CONTENT_CATALOG if c["category_id"] == chosen_category_id]
        feature_items = [f for f in FEATURE_PAGES if f["category_id"] == chosen_category_id]
        
        content_id = None
        if is_content and content_items:
            item = random.choice(content_items)
            title = item["title"]
            module_name = item["module"]
            content_id = item["id"]
        elif feature_items:
            item = random.choice(feature_items)
            title = item["title"]
            module_name = item["module"]
        else:
            title = f"Statistik {CATEGORIES[chosen_category_id]['name']}"
            module_name = "fitur"

        logs.append({
            "id": str(uuid.uuid4()),
            "action_type": action_type,
            "title": title,
            "platform": platform,
            "user_id": user_id,
            "timestamp": log_time.isoformat(),
            "contents_id_content": content_id if content_id else "",
            "youtube_streams_id_streams": "",
            "category_id": chosen_category_id,
            "module_name": module_name
        })

    # Urutkan berdasarkan waktu (kronologis)
    logs.sort(key=lambda x: x["timestamp"])
    return logs


def save_to_csv(data, filepath, fieldnames):
    """Menyimpan list dict ke file CSV."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"-> Berhasil menyimpan {len(data)} baris data ke: {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Synthetic Data Generator MBOISSTATS+")
    parser.add_argument("--count", type=int, default=1000, help="Jumlah baris log aktivitas yang ingin di-generate")
    parser.add_argument("--users", type=int, default=50, help="Jumlah profil pengguna dummy")
    parser.add_argument("--output-dir", type=str, default=os.path.join("backend", "data"), help="Direktori penyimpanan CSV")
    parser.add_argument("--seed", type=int, default=42, help="Random seed untuk reprodusibilitas")
    
    args = parser.parse_args()
    random.seed(args.seed)

    print("=================================================================")
    print("[*] GENERATOR DATA SINTETIS (ORANG 1 - DATA ARCHITECTURE LEAD)")
    print("=================================================================")
    print(f"Target Log       : {args.count:,} baris")
    print(f"Target Pengguna  : {args.users} profil")
    print(f"Direktori Output : {args.output_dir}")
    print("-----------------------------------------------------------------")

    # 1. Generate Users
    users = generate_users(args.users)
    users_csv_path = os.path.join(args.output_dir, "users.csv")
    users_fieldnames = ["id_user", "device_id", "name", "email", "type_user", "major_id", "major_name", "interests", "created_at"]
    
    # Format interests list as JSON string for CSV
    users_for_csv = []
    for u in users:
        u_copy = u.copy()
        u_copy["interests"] = json.dumps(u_copy["interests"])
        users_for_csv.append(u_copy)
    save_to_csv(users_for_csv, users_csv_path, users_fieldnames)

    # 2. Generate Content Catalog
    catalog_csv_path = os.path.join(args.output_dir, "contents_catalog.csv")
    catalog_fieldnames = ["id", "title", "category_id", "type", "module", "cover", "url"]
    save_to_csv(CONTENT_CATALOG, catalog_csv_path, catalog_fieldnames)

    # 3. Generate Activity Logs
    logs = generate_activity_logs(users, num_logs=args.count)
    logs_csv_path = os.path.join(args.output_dir, "raw_activity_logs.csv")
    logs_fieldnames = [
        "id", "action_type", "title", "platform", "user_id",
        "timestamp", "contents_id_content", "youtube_streams_id_streams",
        "category_id", "module_name"
    ]
    save_to_csv(logs, logs_csv_path, logs_fieldnames)

    print("-----------------------------------------------------------------")
    print("[+] Pembangkitan data sintetis selesai!")
    print(f"   1. {logs_csv_path} ({len(logs)} logs)")
    print(f"   2. {users_csv_path} ({len(users)} users)")
    print(f"   3. {catalog_csv_path} ({len(CONTENT_CATALOG)} catalog items)")
    print("=================================================================")


if __name__ == "__main__":
    main()
