import mlflow
import mlflow.sklearn
import os

EXPERIMENT_NAME = "MBOIS_Recommendation_Engine"

def setup_mlflow():
    """Mengonfigurasi MLflow tracking server dengan SQLite database backend."""
    mlflow.set_tracking_uri("sqlite:///mlflow.db")
    mlflow.set_experiment(EXPERIMENT_NAME)
    print(f"[MLflow] Experiment set to: '{EXPERIMENT_NAME}' using SQLite db")

def log_experiment_run(run_name, params, metrics, model=None, artifact_paths=None):
    """
    Mencatat satu run eksperimen ke MLflow:
    - run_name: Nama run (misal: SVD_K5_Recommendation)
    - params: Dictionary hyperparameter
    - metrics: Dictionary metrik evaluasi (Precision@K, Recall@K, NDCG@K, F1@K)
    - model: Object model sklearn/SVD untuk dicatat ke model registry
    - artifact_paths: List file lokal untuk disimpan sebagai artefak MLflow
    """
    setup_mlflow()
    
    with mlflow.start_run(run_name=run_name) as run:
        # 1. Log Hyperparameters
        for key, value in params.items():
            mlflow.log_param(key, value)
            
        # 2. Log Metrics
        for key, value in metrics.items():
            mlflow.log_metric(key, float(value))
            
        # 3. Log Artifacts (seperti file CSV/JSON hasil prediksi)
        if artifact_paths:
            for filepath in artifact_paths:
                if os.path.exists(filepath):
                    mlflow.log_artifact(filepath)
                    
        # 4. Log Model to Registry
        if model is not None:
            mlflow.sklearn.log_model(
                sk_model=model,
                artifact_path="recommendation_model",
                registered_model_name="MBOIS_SVD_Recommendation_Model"
            )
            print(f"[MLflow] Model registered under name 'MBOIS_SVD_Recommendation_Model'")
            
        print(f"[MLflow] Run '{run_name}' successfully logged! Run ID: {run.info.run_id}")
        return run.info.run_id
