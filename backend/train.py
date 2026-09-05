import os
import math
import json
import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.decomposition import TruncatedSVD
from mlflow_config import log_experiment_run

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

def load_datasets():
    """Memuat dataset interaksi dari folder backend/data/"""
    user_item_path = os.path.join(DATA_DIR, "user_item_matrix.csv")
    catalog_path = os.path.join(DATA_DIR, "contents_catalog.csv")
    
    df_user_item = pd.read_csv(user_item_path)
    df_catalog = pd.read_csv(catalog_path)
    
    return df_user_item, df_catalog

def calculate_ndcg_at_k(actual, predicted, k=5):
    """Menghitung Normalized Discounted Cumulative Gain (NDCG@K)"""
    predicted = predicted[:k]
    dcg = 0.0
    for i, p in enumerate(predicted):
        if p in actual:
            dcg += 1.0 / math.log2(i + 2)
            
    ideal_hits = min(len(actual), k)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(ideal_hits))
    
    return dcg / idcg if idcg > 0 else 0.0

def evaluate_predictions(user_item_pivot, predicted_matrix, k=5, threshold=0.05):
    """
    Evaluasi performa prediksi rekomendasi menggunakan metrik MLOps:
    - Precision@K
    - Recall@K
    - F1-Score@K
    - NDCG@K
    """
    precisions = []
    recalls = []
    ndcgs = []
    
    n_users, n_items = user_item_pivot.shape
    
    for u_idx in range(n_users):
        actual_scores = user_item_pivot.iloc[u_idx].values
        actual_relevant_indices = np.where(actual_scores > threshold)[0]
        if len(actual_relevant_indices) == 0:
            continue
            
        pred_scores = predicted_matrix[u_idx]
        top_k_pred_indices = np.argsort(pred_scores)[::-1][:k]
        
        hits = len(set(top_k_pred_indices).intersection(set(actual_relevant_indices)))
        
        precision = hits / float(k)
        recall = hits / float(len(actual_relevant_indices))
        ndcg = calculate_ndcg_at_k(actual_relevant_indices, top_k_pred_indices, k=k)
        
        precisions.append(precision)
        recalls.append(recall)
        ndcgs.append(ndcg)
        
    mean_precision = np.mean(precisions) if precisions else 0.0
    mean_recall = np.mean(recalls) if recalls else 0.0
    mean_ndcg = np.mean(ndcgs) if ndcgs else 0.0
    
    f1_score = (2 * mean_precision * mean_recall / (mean_precision + mean_recall)) if (mean_precision + mean_recall) > 0 else 0.0
    
    return {
        "precision_at_k": round(float(mean_precision), 4),
        "recall_at_k": round(float(mean_recall), 4),
        "f1_score_at_k": round(float(f1_score), 4),
        "ndcg_at_k": round(float(mean_ndcg), 4)
    }

def train_user_based_cf(pivot_df):
    """Collaborative Filtering berbasis Kemiripan Pengguna (User-Based Cosine CF)"""
    user_sim = cosine_similarity(pivot_df.values)
    # Menghindari pembagian dengan nol
    sim_sum = np.array([np.abs(user_sim).sum(axis=1)]).T
    sim_sum[sim_sum == 0] = 1e-9
    predicted_matrix = np.dot(user_sim, pivot_df.values) / sim_sum
    return predicted_matrix

def train_item_based_cf(pivot_df):
    """Collaborative Filtering berbasis Kemiripan Item (Item-Based Cosine CF)"""
    item_sim = cosine_similarity(pivot_df.values.T)
    sim_sum = np.array([np.abs(item_sim).sum(axis=1)])
    sim_sum[sim_sum == 0] = 1e-9
    predicted_matrix = np.dot(pivot_df.values, item_sim) / sim_sum
    return predicted_matrix, item_sim

def train_svd_cf(pivot_df, n_components=8):
    """Collaborative Filtering berbasis SVD Matrix Factorization"""
    n_comp = min(n_components, pivot_df.shape[1] - 1)
    svd = TruncatedSVD(n_components=n_comp, random_state=42)
    user_factors = svd.fit_transform(pivot_df.values)
    item_factors = svd.components_
    reconstructed_matrix = np.dot(user_factors, item_factors)
    return reconstructed_matrix, svd

def run_collaborative_filtering_pipeline():
    print("=" * 60)
    print("[INFO] Collaborative Filtering ML Recommendation Engine")
    print("=" * 60)
    
    # 1. Load Data
    df_user_item, df_catalog = load_datasets()
    print(f"[DATA] Loaded {len(df_user_item)} interaction rows across {df_user_item['user_id'].nunique()} users.")
    
    # 2. Pivot Matrix (User x Item)
    pivot_df = df_user_item.pivot(
        index='user_id',
        columns='contents_id_content',
        values='interaction_score'
    ).fillna(0.0)
    
    k_eval = 5
    
    # 3. Latih & Evaluasi 3 Metode Collaborative Filtering
    print("\n[TRAINING] Comparing Collaborative Filtering Approaches...")
    
    # A. User-Based CF
    user_cf_pred = train_user_based_cf(pivot_df)
    metrics_user_cf = evaluate_predictions(pivot_df, user_cf_pred, k=k_eval)
    print(f"   [User-Based CF]  Precision@5: {metrics_user_cf['precision_at_k']} | Recall@5: {metrics_user_cf['recall_at_k']} | NDCG@5: {metrics_user_cf['ndcg_at_k']}")
    
    # B. Item-Based CF
    item_cf_pred, item_sim = train_item_based_cf(pivot_df)
    metrics_item_cf = evaluate_predictions(pivot_df, item_cf_pred, k=k_eval)
    print(f"   [Item-Based CF]  Precision@5: {metrics_item_cf['precision_at_k']} | Recall@5: {metrics_item_cf['recall_at_k']} | NDCG@5: {metrics_item_cf['ndcg_at_k']}")
    
    # C. SVD Matrix Factorization CF
    svd_pred, svd_model = train_svd_cf(pivot_df, n_components=10)
    metrics_svd = evaluate_predictions(pivot_df, svd_pred, k=k_eval)
    print(f"   [SVD Matrix CF]  Precision@5: {metrics_svd['precision_at_k']} | Recall@5: {metrics_svd['recall_at_k']} | NDCG@5: {metrics_svd['ndcg_at_k']}")
    
    # 4. Pilih Model Terbaik Berdasarkan F1-Score / NDCG
    models_eval = [
        ("Item-Based CF", metrics_item_cf, item_cf_pred),
        ("User-Based CF", metrics_user_cf, user_cf_pred),
        ("SVD Matrix Factorization", metrics_svd, svd_pred)
    ]
    
    models_eval.sort(key=lambda x: x[1]['ndcg_at_k'], reverse=True)
    best_name, best_metrics, best_pred_matrix = models_eval[0]
    
    print(f"\n[CHAMPION] Champion Model Selected: '{best_name}'")
    print(f"   - Precision@5 : {best_metrics['precision_at_k']}")
    print(f"   - Recall@5    : {best_metrics['recall_at_k']}")
    print(f"   - F1-Score@5  : {best_metrics['f1_score_at_k']}")
    print(f"   - NDCG@5      : {best_metrics['ndcg_at_k']}")
    
    # 5. Export Prediksi Rekomendasi
    recommendations_output = {}
    item_ids = list(pivot_df.columns)
    
    for u_idx, user_id in enumerate(pivot_df.index):
        pred_scores = best_pred_matrix[u_idx]
        top_k_indices = np.argsort(pred_scores)[::-1][:k_eval]
        top_items = [item_ids[i] for i in top_k_indices]
        recommendations_output[user_id] = top_items
        
    output_path = os.path.join(DATA_DIR, "ml_recommendations.json")
    with open(output_path, "w") as f:
        json.dump(recommendations_output, f, indent=2)
        
    print(f"[EXPORT] Exported predictions to '{output_path}'")
    
    # 6. Log Ke MLflow
    params = {
        "algorithm": best_name,
        "eval_k": k_eval,
        "user_count": len(pivot_df),
        "item_count": len(pivot_df.columns)
    }
    
    log_experiment_run(
        run_name=f"{best_name.replace(' ', '_')}_Run",
        params=params,
        metrics=best_metrics,
        model=svd_model if best_name == "SVD Matrix Factorization" else None,
        artifact_paths=[output_path]
    )
    
    print("=" * 60)
    print("[SUCCESS] Collaborative Filtering Pipeline Completed!")
    print("=" * 60)

if __name__ == "__main__":
    run_collaborative_filtering_pipeline()
