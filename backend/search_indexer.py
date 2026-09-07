"""
search_indexer.py -- Build BM25 index dari contents_catalog.csv
Output: backend/data/search_index.json
"""
import os, json, re
import pandas as pd

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

STOPWORDS = {
    "dan", "di", "ke", "yang", "tahun", "atau", "untuk", "dari", "dengan",
    "pada", "dalam", "oleh", "adalah", "ini", "itu", "kota", "malang",
    "menurut", "berdasarkan", "angka", "hasil", "tingkat", "jumlah",
}

def tokenize(text):
    tokens = re.sub(r"[^a-z0-9\s]", "", text.lower()).split()
    return [t for t in tokens if t not in STOPWORDS and len(t) > 1]

def build_index():
    df = pd.read_csv(os.path.join(DATA_DIR, "contents_catalog.csv"))
    df = df.dropna(subset=["id", "title"])

    index = {}
    doc_lengths = {}

    for _, row in df.iterrows():
        doc_id = str(row["id"])
        tokens = tokenize(str(row["title"]))
        doc_lengths[doc_id] = len(tokens)
        tf_map = {}
        for t in tokens:
            tf_map[t] = tf_map.get(t, 0) + 1
        for term, tf in tf_map.items():
            if term not in index:
                index[term] = {}
            index[term][doc_id] = tf

    avg_dl = sum(doc_lengths.values()) / len(doc_lengths) if doc_lengths else 1.0
    result = {
        "index": index,
        "doc_lengths": doc_lengths,
        "avg_doc_length": round(avg_dl, 4),
        "total_docs": len(doc_lengths),
    }

    out_path = os.path.join(DATA_DIR, "search_index.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"[search_indexer] Index built: {len(index)} terms, {len(doc_lengths)} docs")
    print(f"[search_indexer] Saved to {out_path}")
    return result

if __name__ == "__main__":
    build_index()
