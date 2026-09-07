"""
benchmark_search.py -- Evaluasi 3 metode search: Baseline vs BM25 vs Hybrid
Metrik: Precision@5, Recall@5, MRR@5, NDCG@5
Output: backend/data/benchmark_results.json + tabel terminal
"""
import os, json, re, math
import pandas as pd
from tabulate import tabulate
from rank_bm25 import BM25Okapi

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

STOPWORDS = {
    "dan", "di", "ke", "yang", "tahun", "atau", "untuk", "dari", "dengan",
    "pada", "dalam", "oleh", "adalah", "ini", "itu", "kota", "malang",
    "menurut", "berdasarkan", "angka", "hasil", "tingkat", "jumlah",
}

def tokenize(text):
    tokens = re.sub(r"[^a-z0-9\s]", "", text.lower()).split()
    return [t for t in tokens if t not in STOPWORDS and len(t) > 1]

def levenshtein(a, b):
    m, n = len(a), len(b)
    dp = list(range(n + 1))
    for i in range(1, m + 1):
        prev = dp[0]
        dp[0] = i
        for j in range(1, n + 1):
            temp = dp[j]
            dp[j] = prev if a[i-1] == b[j-1] else 1 + min(prev, dp[j], dp[j-1])
            prev = temp
    return dp[n]

def fuzzy_score(query_token, title):
    words = tokenize(title)
    if not words:
        return 0.0
    best = max(
        1.0 - levenshtein(query_token, w) / max(len(query_token), len(w), 1)
        for w in words
    )
    return best

def ndcg_at_k(ranked_ids, relevant_ids, k=5):
    dcg = sum(
        1.0 / math.log2(i + 2)
        for i, doc_id in enumerate(ranked_ids[:k])
        if doc_id in relevant_ids
    )
    ideal_hits = min(len(relevant_ids), k)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(ideal_hits))
    return dcg / idcg if idcg > 0 else 0.0

def evaluate(ranked_ids, relevant_ids, k=5):
    top_k = ranked_ids[:k]
    hits = len(set(top_k) & relevant_ids)
    precision = hits / k
    recall = hits / len(relevant_ids) if relevant_ids else 0.0
    mrr = next(
        (1.0 / (i + 1) for i, d in enumerate(top_k) if d in relevant_ids), 0.0
    )
    ndcg = ndcg_at_k(ranked_ids, relevant_ids, k)
    return precision, recall, mrr, ndcg

def load_data():
    logs = pd.read_csv(os.path.join(DATA_DIR, "raw_activity_logs.csv"))
    catalog = pd.read_csv(os.path.join(DATA_DIR, "contents_catalog.csv"))
    with open(os.path.join(DATA_DIR, "ml_recommendations.json"), encoding="utf-8") as f:
        ml_recs = json.load(f)
    return logs, catalog, ml_recs

def run_benchmark():
    logs, catalog, ml_recs = load_data()

    # Filter log yang punya contents_id
    logs = logs.dropna(subset=["contents_id_content"])
    catalog = catalog.dropna(subset=["id", "title"])

    catalog_ids = list(catalog["id"].astype(str))
    catalog_titles = list(catalog["title"].astype(str))
    tokenized_corpus = [tokenize(t) for t in catalog_titles]
    bm25 = BM25Okapi(tokenized_corpus)

    # Bangun ground truth: per user -> set content_id yang diakses
    user_relevant = logs.groupby("user_id")["contents_id_content"].apply(set).to_dict()

    # Ambil semua user_id yang punya ml_recs
    ml_users = list(ml_recs.keys())

    results = {"baseline": [], "bm25": [], "hybrid": []}

    for user_id in ml_users:
        relevant = user_relevant.get(user_id, set())
        if not relevant:
            continue

        user_logs = logs[logs["user_id"] == user_id]
        if user_logs.empty:
            continue

        # Gunakan judul konten pertama yang diakses sebagai query simulasi
        query_title = str(user_logs.iloc[0]["title"])
        query_tokens = tokenize(query_title)
        if not query_tokens:
            continue

        ml_boost_ids = set(ml_recs.get(user_id, []))

        # --- BASELINE: substring match, urut asal ---
        baseline_ranked = [
            cid for cid, title in zip(catalog_ids, catalog_titles)
            if any(qt in title.lower() for qt in query_tokens)
        ] + [cid for cid in catalog_ids if cid not in [
            c for c, t in zip(catalog_ids, catalog_titles)
            if any(qt in t.lower() for qt in query_tokens)
        ]]
        p, r, mrr, ndcg = evaluate(baseline_ranked, relevant)
        results["baseline"].append((p, r, mrr, ndcg))

        # --- BM25 ---
        scores = bm25.get_scores(query_tokens)
        bm25_ranked = [catalog_ids[i] for i in sorted(range(len(scores)), key=lambda x: -scores[x])]
        p, r, mrr, ndcg = evaluate(bm25_ranked, relevant)
        results["bm25"].append((p, r, mrr, ndcg))

        # --- HYBRID: BM25 + fuzzy + ML boost ---
        hybrid_scores = {}
        for i, (cid, title) in enumerate(zip(catalog_ids, catalog_titles)):
            score = scores[i]
            # Fuzzy boost
            for qt in query_tokens:
                score += fuzzy_score(qt, title) * 0.5
            # ML recommendation boost
            if cid in ml_boost_ids:
                score += 0.3
            hybrid_scores[cid] = score
        hybrid_ranked = sorted(catalog_ids, key=lambda x: -hybrid_scores[x])
        p, r, mrr, ndcg = evaluate(hybrid_ranked, relevant)
        results["hybrid"].append((p, r, mrr, ndcg))

    def avg(lst, idx):
        return round(sum(x[idx] for x in lst) / len(lst), 4) if lst else 0.0

    summary = {}
    for method, vals in results.items():
        summary[method] = {
            "precision@5": avg(vals, 0),
            "recall@5":    avg(vals, 1),
            "mrr@5":       avg(vals, 2),
            "ndcg@5":      avg(vals, 3),
            "n_users":     len(vals),
        }

    # Simpan JSON
    out_path = os.path.join(DATA_DIR, "benchmark_results.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    # Tampilkan tabel (safe encoding untuk Windows terminal)
    import sys
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    table = [
        [m, v["precision@5"], v["recall@5"], v["mrr@5"], v["ndcg@5"], v["n_users"]]
        for m, v in summary.items()
    ]
    print("\n=== Search Benchmark Evaluation (K=5) ===")
    print(tabulate(table,
        headers=["Method", "Precision@5", "Recall@5", "MRR@5", "NDCG@5", "Users"],
        tablefmt="grid", floatfmt=".4f"
    ))
    print(f"\nSaved to {out_path}\n")
    return summary

if __name__ == "__main__":
    run_benchmark()
