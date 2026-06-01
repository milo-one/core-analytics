# pipeline/pca_kmeans.py

from pathlib import Path

import pandas as pd
import numpy as np
from time import perf_counter


from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans

from config.config import OUT_DIR


# Fallback, falls du es nicht in config.yaml geregelt hast
DEFAULT_N_COMPONENTS = 12
DEFAULT_N_CLUSTERS = 8



def select_numeric_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Wählt alle numerischen Spalten als Input für PCA/KMeans.
    text_id und andere Nicht-Features werden entfernt.
    """
    non_feature_cols = {"text_id"}
    numeric_df = df.drop(columns=[c for c in df.columns if c in non_feature_cols], errors="ignore")
    numeric_df = numeric_df.select_dtypes(include=[np.number])

    if numeric_df.empty:
        raise ValueError("Keine numerischen Feature-Spalten gefunden für PCA/KMeans.")

    return numeric_df


def run():
    features_file = OUT_DIR / "features_full.csv"
    if not features_file.exists():
        raise FileNotFoundError(
            f"features_full.csv nicht gefunden unter {features_file}. "
            "Hast du merge_with_style.py schon ausgeführt?"
        )

    print(f"-> Lese Feature-Matrix aus: {features_file}")
    df = pd.read_csv(features_file)

    df_features = select_numeric_features(df)
    print(f"-> Anzahl Features (numerisch): {df_features.shape[1]}")

    # Standardisieren
    t0 = perf_counter()
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(df_features)
    t1 = perf_counter()
    print(f"[BENCH] Scaling: {t1 - t0:.3f} s")

        # --- PCA-Sanity-Check ---
    n_samples = df_features.shape[0]
    n_features = df_features.shape[1]
    max_components = min(n_samples, n_features)

    if max_components < 2:
        print("-> Zu wenige Daten für PCA. Überspringe PCA und K-Means.")
        
        # Leere, aber gültige pca_scores.csv erzeugen
        pca_file = OUT_DIR / "pca_scores.csv"
        df_empty = pd.DataFrame({"text_id": df["text_id"]})
        df_empty.to_csv(pca_file, index=False)
        print(f"-> Leere PCA-Scores gespeichert unter: {pca_file}")
        
        print("==============================")
        print(" PIPELINE ABGESCHLOSSEN")
        print("==============================")
        print(f"Ergebnisse liegen in: {OUT_DIR}")
        return

    # --- PCA regulär ausführen ---
    n_components = min(DEFAULT_N_COMPONENTS, max_components)
    print(f"-> Führe PCA mit {n_components} Komponenten durch ...")

    t2 = perf_counter()
    pca = PCA(n_components=n_components, random_state=42)
    X_pca = pca.fit_transform(X_scaled)
    t3 = perf_counter()
    print(f"[BENCH] PCA: {t3 - t2:.3f} s")

    # PCA-Scores speichern
    pca_cols = [f"PC{i+1}" for i in range(n_components)]

    df_pca = pd.DataFrame(X_pca, columns=pca_cols)
    df_pca.insert(0, "text_id", df["text_id"])

    pca_file = OUT_DIR / "pca_scores.csv"
    df_pca.to_csv(pca_file, index=False)
    print(f"-> PCA-Scores gespeichert unter: {pca_file}")

    # --- K-Means Check ---
    n_clusters = min(DEFAULT_N_CLUSTERS, df_pca.shape[0])
    if n_clusters < 2:
        print("-> Zu wenige Texte für sinnvolles Clustering. Skipping K-Means.")

    print(f"-> Führe K-Means mit {n_clusters} Clustern durch ...")
    t4 = perf_counter()
    kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init="auto")
    clusters = kmeans.fit_predict(X_pca)
    t5 = perf_counter()
    print(f"[BENCH] KMeans: {t5 - t4:.3f} s")

    df_clusters = pd.DataFrame({
        "text_id": df["text_id"],
        "cluster": clusters,
    })

    cluster_file = OUT_DIR / "cluster_labels.csv"
    df_clusters.to_csv(cluster_file, index=False)
    print(f"-> Cluster-Labels gespeichert unter: {cluster_file}")

if __name__ == "__main__":
    run()
