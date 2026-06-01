# pipeline/vectorize_categories.py

import pandas as pd
from pathlib import Path

from config.config import CATEGORY_FEATURES_CSV, OUT_DIR

def load_category_features() -> pd.DataFrame:
    """
    Lädt die von extract_categories.py erzeugte Kategorie-Matrix.
    Erwartetes Format:
        text_id, cat_FOO, cat_BAR, ...
    """
    if not CATEGORY_FEATURES_CSV.exists():
        raise FileNotFoundError(f"category_features.csv nicht gefunden: {CATEGORY_FEATURES_CSV}")

    df = pd.read_csv(CATEGORY_FEATURES_CSV, encoding="utf-8")
    if "text_id" not in df.columns:
        raise ValueError("Spalte 'text_id' fehlt in category_features.csv")

    return df


def extract_category_matrix(df: pd.DataFrame) -> pd.DataFrame:
    """
    Filtert alle cat_* Spalten plus text_id heraus.
    """
    cat_cols = [c for c in df.columns if c.startswith("cat_")]
    if not cat_cols:
        raise ValueError("Keine Spalten mit Präfix 'cat_' gefunden.")

    cols = ["text_id"] + cat_cols
    return df[cols].copy()


def zscore_scale(df: pd.DataFrame, exclude_cols=None) -> pd.DataFrame:
    """
    Z-Standardisierung (Mittelwert 0, Std 1) für numerische Spalten.
    exclude_cols: Spalten, die nicht skaliert werden (z.B. text_id).
    """
    if exclude_cols is None:
        exclude_cols = []

    df_scaled = df.copy()
    numeric_cols = [c for c in df.columns if c not in exclude_cols and pd.api.types.is_numeric_dtype(df[c])]

    for col in numeric_cols:
        mean = df_scaled[col].mean()
        std = df_scaled[col].std(ddof=0)
        if std == 0:
            # konstante Spalten bleiben 0
            df_scaled[col] = 0.0
        else:
            df_scaled[col] = (df_scaled[col] - mean) / std

    return df_scaled


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"-> Lese Kategorie-Features aus: {CATEGORY_FEATURES_CSV}")
    df = load_category_features()

    print("-> Extrahiere Kategorie-Vektoren (cat_*) ...")
    mat = extract_category_matrix(df)

    raw_path = OUT_DIR / "category_vectors_raw.csv"
    mat.to_csv(raw_path, index=False, encoding="utf-8")
    print(f"✅ Roh-Vektoren gespeichert unter: {raw_path}")

    print("-> Skaliere Kategorie-Vektoren (Z-Score) ...")
    mat_scaled = zscore_scale(mat, exclude_cols=["text_id"])

    scaled_path = OUT_DIR / "category_vectors_scaled.csv"
    mat_scaled.to_csv(scaled_path, index=False, encoding="utf-8")
    print(f"✅ Skalierte Vektoren gespeichert unter: {scaled_path}")


if __name__ == "__main__":
    main()
