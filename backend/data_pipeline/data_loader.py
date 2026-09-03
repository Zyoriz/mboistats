"""
Data Loader & Time-Decay Preprocessing Engine - MBOISSTATS+ PKL
Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)

Modul ini bertanggung jawab untuk:
1. Membaca data log aktivitas mentah (dari CSV lokal atau Supabase).
2. Menghitung Implicit Action Weighting (view_page=1, view_pdf=3, download=5).
3. Menghitung Exponential Time-Decay: Score = Weight * exp(-lambda * delta_t).
4. Menggabungkan preferensi eksplisit Onboarding (Jurusan) dengan aktivitas implisit (Warm-Up Blending).
5. Menghasilkan User-Category Matrix & User-Item Matrix yang siap dilatih oleh Orang 2 (train.py).
"""

import argparse
import json
import math
import os
from datetime import datetime, timezone
import numpy as np
import pandas as pd

# Default Weights & Decay Configuration
DEFAULT_ACTION_WEIGHTS = {
    "view_page": 1.0,
    "view_pdf": 3.0,
    "download_file": 5.0,
    "click_menu": 0.5,
    "search": 0.8,
}

# Sumber kebenaran: tabel `categories` live di Supabase (categories_rows.csv export).
# id 2/3/4 sengaja BUKAN urutan alfabetis - ikuti persis nilai di database.
SECTOR_MAP = {
    1: "perekonomian",
    2: "tenaga_kerja",
    3: "ipm",
    4: "kemiskinan",
    5: "kependudukan",
    6: "pertanian",
    7: "kesejahteraan"
}

SECTOR_NAMES = {
    "perekonomian": 1,
    "tenaga_kerja": 2,
    "ipm": 3,
    "kemiskinan": 4,
    "kependudukan": 5,
    "pertanian": 6,
    "kesejahteraan": 7
}


class DataLoader:
    def __init__(
        self,
        data_dir=os.path.join("backend", "data"),
        lambda_decay=0.05,
        action_weights=None,
    ):
        """
        Inisialisasi DataLoader.
        :param data_dir: Direktori penyimpanan dataset CSV.
        :param lambda_decay: Konstanta penyusutan waktu exponential (default: 0.05).
        :param action_weights: Dictionary pembobotan aksi implisit.
        """
        self.data_dir = data_dir
        self.lambda_decay = lambda_decay
        self.action_weights = action_weights or DEFAULT_ACTION_WEIGHTS

        self.raw_logs_path = os.path.join(self.data_dir, "raw_activity_logs.csv")
        self.users_path = os.path.join(self.data_dir, "users.csv")
        self.catalog_path = os.path.join(self.data_dir, "contents_catalog.csv")

    def load_raw_data(self):
        """Memuat dataset mentah dari file CSV."""
        if not os.path.exists(self.raw_logs_path):
            raise FileNotFoundError(
                f"File log tidak ditemukan di {self.raw_logs_path}. "
                "Jalankan generate_dummy_data.py terlebih dahulu."
            )
        
        df_logs = pd.read_csv(self.raw_logs_path)
        df_users = pd.read_csv(self.users_path) if os.path.exists(self.users_path) else None
        df_catalog = pd.read_csv(self.catalog_path) if os.path.exists(self.catalog_path) else None

        return df_logs, df_users, df_catalog

    def apply_time_decay_and_weights(self, df_logs, reference_time=None):
        """
        Mengaplikasikan bobot aksi dan exponential time-decay ke setiap baris log:
          delta_t = (reference_time - log_time) dalam hari
          decay_factor = exp(-lambda * delta_t)
          weighted_score = action_weight * decay_factor
        """
        df = df_logs.copy()
        
        # Parse timestamp ke datetime UTC.
        # format="mixed" wajib di sini: log REAL dari Supabase pakai separator spasi
        # ("2026-08-19 17:14:49.747336+00"), sedangkan log SINTETIS pakai ISO 'T'
        # (datetime.isoformat()) -- dua format berbeda tercampur di kolom yang sama.
        df["dt"] = pd.to_datetime(df["timestamp"], utc=True, format="mixed")
        ref_time = reference_time or datetime.now(timezone.utc)
        
        # 1. Action Weighting (Implicit Rating)
        df["action_weight"] = df["action_type"].map(
            lambda a: self.action_weights.get(str(a).lower(), 1.0)
        )

        # 2. Delta t (dalam satuan hari)
        df["delta_days"] = (ref_time - df["dt"]).dt.total_seconds() / 86400.0
        df["delta_days"] = df["delta_days"].clip(lower=0.0)

        # 3. Exponential Time-Decay Factor
        df["decay_factor"] = np.exp(-self.lambda_decay * df["delta_days"])

        # 4. Final Weighted Score per log entry
        df["weighted_score"] = df["action_weight"] * df["decay_factor"]

        return df

    def compute_user_category_matrix(self, df_processed, df_users=None):
        """
        Menghasilkan matriks skor preferensi pengguna terhadap 7 Sektor Utama.
        Menggabungkan skor interaksi implisit (time-decay) dengan preferensi eksplisit (onboarding).
        """
        # Agregasi skor per user dan category_id
        grouped = df_processed.groupby(["user_id", "category_id"]).agg(
            raw_clicks=("id", "count"),
            total_weighted_score=("weighted_score", "sum"),
            last_interaction=("dt", "max")
        ).reset_index()

        # Pivot menjadi bentuk tabel (User x 7 Sektor)
        matrix = grouped.pivot(
            index="user_id",
            columns="category_id",
            values="total_weighted_score"
        ).fillna(0.0)

        # Pastikan seluruh 7 kolom kategori (1-7) ada
        for cat_id in range(1, 8):
            if cat_id not in matrix.columns:
                matrix[cat_id] = 0.0
        matrix = matrix[[1, 2, 3, 4, 5, 6, 7]]

        # Normalisasi skor per user (Min-Max atau Softmax per baris) ke range [0, 1]
        row_max = matrix.max(axis=1)
        row_max = row_max.replace(0, 1.0)
        normalized_matrix = matrix.div(row_max, axis=0)

        # Rename columns to category key names
        normalized_matrix.columns = [SECTOR_MAP.get(c, f"sector_{c}") for c in normalized_matrix.columns]

        # Gabungkan dengan preferensi eksplisit Onboarding jika ada data user
        if df_users is not None:
            user_interest_dict = {}
            for _, u in df_users.iterrows():
                # `activity_logs.user_id` di data real mayoritas berisi id_user (UUID),
                # sebagian kecil (bug lama di logger) berisi email. Daftarkan keduanya
                # sebagai kunci agar warm-up blending tetap mencocokkan kedua kasus.
                u_id_uuid = str(u.get("id_user", ""))
                u_id_email = str(u.get("email", ""))
                try:
                    interests = json.loads(str(u.get("interests", "[]")))
                except Exception:
                    interests = []
                if u_id_uuid and u_id_uuid != "nan":
                    user_interest_dict[u_id_uuid] = interests
                if u_id_email and u_id_email != "nan":
                    user_interest_dict[u_id_email] = interests

            # Warm-up blending
            total_clicks_per_user = df_processed.groupby("user_id")["id"].count().to_dict()

            for user_id in normalized_matrix.index:
                n_clicks = total_clicks_per_user.get(user_id, 0)
                # Tentukan bobot eksplisit vs implisit berdasarkan fase interaksi
                if n_clicks == 0:
                    w_exp, w_imp = 1.0, 0.0
                elif n_clicks < 10:
                    w_exp, w_imp = 0.5, 0.5
                else:
                    w_exp, w_imp = 0.2, 0.8

                user_interests = user_interest_dict.get(user_id, [])
                for cat_id, cat_key in SECTOR_MAP.items():
                    exp_score = 1.0 if cat_id in user_interests else 0.0
                    imp_score = normalized_matrix.loc[user_id, cat_key]
                    blended = (w_exp * exp_score) + (w_imp * imp_score)
                    normalized_matrix.loc[user_id, cat_key] = round(blended, 4)

        return normalized_matrix

    def compute_user_item_matrix(self, df_processed):
        """
        Menghasilkan matriks interaksi User x Content Item (untuk Collaborative Filtering / SVD Orang 2).
        Hanya menyertakan interaksi yang memiliki `contents_id_content`.
        """
        df_content_logs = df_processed[
            df_processed["contents_id_content"].notna() &
            (df_processed["contents_id_content"] != "")
        ]

        if df_content_logs.empty:
            return pd.DataFrame()

        item_matrix = df_content_logs.groupby(["user_id", "contents_id_content"]).agg(
            interaction_score=("weighted_score", "sum"),
            views_count=("id", "count"),
            last_view=("dt", "max")
        ).reset_index()

        return item_matrix

    def run_pipeline(self):
        """Menjalankan seluruh pipeline preprocessing dan menyimpan hasilnya."""
        print("=================================================================")
        print("[*] PREPROCESSING TIME-DECAY & DATA INGESTION (ORANG 1)")
        print("=================================================================")
        print(f"Direktori Data : {self.data_dir}")
        print(f"Decay Rate (lambda) : {self.lambda_decay} (Half-life ~ {round(math.log(2)/self.lambda_decay, 1)} hari)")
        print("-" * 65)

        # 1. Load Data
        df_logs, df_users, df_catalog = self.load_raw_data()
        print(f"-> Membaca {len(df_logs):,} log aktivitas mentah.")

        # 2. Apply Time-Decay & Weights
        df_processed = self.apply_time_decay_and_weights(df_logs)
        processed_csv_path = os.path.join(self.data_dir, "processed_interactions.csv")
        df_processed.to_csv(processed_csv_path, index=False)
        print(f"-> Log terbobot disimpan ke: {processed_csv_path}")

        # 3. Compute User-Category Preference Matrix (7 Sektor)
        user_cat_matrix = self.compute_user_category_matrix(df_processed, df_users)
        cat_matrix_path = os.path.join(self.data_dir, "user_category_matrix.csv")
        user_cat_matrix.to_csv(cat_matrix_path)
        print(f"-> User-Category Matrix disimpan ke: {cat_matrix_path} ({user_cat_matrix.shape})")

        # 4. Compute User-Item Matrix (Untuk CF/SVD Orang 2)
        user_item_matrix = self.compute_user_item_matrix(df_processed)
        item_matrix_path = os.path.join(self.data_dir, "user_item_matrix.csv")
        user_item_matrix.to_csv(item_matrix_path, index=False)
        print(f"-> User-Item Matrix disimpan ke: {item_matrix_path} ({len(user_item_matrix)} pairs)")

        print("-----------------------------------------------------------------")
        print("[+] Preprocessing Time-Decay selesai!")
        print("\nContoh Cuplikan User-Category Matrix (5 baris teratas):")
        print(user_cat_matrix.head().to_string())
        print("=================================================================")

        return {
            "processed_logs": df_processed,
            "user_category_matrix": user_cat_matrix,
            "user_item_matrix": user_item_matrix
        }


def main():
    parser = argparse.ArgumentParser(description="Data Loader & Time-Decay Preprocessing Engine")
    parser.add_argument("--data-dir", type=str, default=os.path.join("backend", "data"), help="Path direktori data CSV")
    parser.add_argument("--lambda-decay", type=float, default=0.05, help="Konstanta exponential time decay")
    
    args = parser.parse_args()
    loader = DataLoader(data_dir=args.data_dir, lambda_decay=args.lambda_decay)
    loader.run_pipeline()


if __name__ == "__main__":
    main()
