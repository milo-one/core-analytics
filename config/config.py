from pathlib import Path
import yaml

# --------------------------------------------------
# Basis: Projektpfad
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# --------------------------------------------------
# Funktionierender UNIVERSAL-PARSER:
# Top-Level, Sub-Level, patterns / pattern / regex,
# vollständige Rekursion, keine False-Negatives.
# --------------------------------------------------

IGNORE_META = {
    "description",
    "weight",
    "metric_features",
    "components",
    "exclusions",
    "exclude",
    "regex",
    "pattern",
    "patterns",
}

def extract_categories(data: dict) -> dict:
    """
    EXAKTE Übernahme der funktionierenden Logik:
    - erkennt Top-Level Kategorien
    - erkennt Subkategorien
    - erkennt patterns / pattern / regex überall
    - rekursiv, verlustfrei, robust

    Rückgabe:
        dict(category_name -> list_of_regex_strings)
    """
    categories = {}

    def recurse(current_key, content):
        # -----------------------------
        # Fall A: content ist Liste
        # → echte Patternliste
        # -----------------------------
        if isinstance(content, list):
            categories.setdefault(current_key, [])
            for item in content:
                if isinstance(item, str):
                    categories[current_key].append(item)
            return

        # -----------------------------
        # Fall B: content ist Dict
        # -----------------------------
        if isinstance(content, dict):

            # 1) Lokale patterns sammeln
            local_patterns = []

            for k, v in content.items():
                if k.lower() in {"pattern", "patterns", "regex"}:
                    if isinstance(v, list):
                        local_patterns.extend(v)

            # Wenn Patterns vorhanden → Kategorie = current_key
            if local_patterns:
                categories.setdefault(current_key, []).extend(local_patterns)

            # 2) Subkeys durchlaufen
            for k, v in content.items():

                # Meta-Felder überspringen
                if k.lower() in IGNORE_META:
                    continue

                # Sub-Level weiter analysieren
                recurse(k, v)

            return

    for top_key, content in data.items():
        recurse(top_key, content)

    return categories


def extract_exclusions(data: dict) -> dict:
    """
    Sammelt exclusions auf beliebiger Ebene und ordnet sie der jeweils
    lokalen Kategorie/Subkategorie zu.
    """
    ex = {}

    def collect_strings(value):
        strings = []
        if isinstance(value, str):
            strings.append(value)
        elif isinstance(value, list):
            for item in value:
                strings.extend(collect_strings(item))
        return strings

    def recurse(current_key, content):
        if isinstance(content, dict):
            for k, v in content.items():
                key_lower = k.lower()
                if key_lower in {"exclusions", "exclude"}:
                    ex.setdefault(current_key, []).extend(collect_strings(v))
                    continue

                if key_lower in IGNORE_META:
                    continue

                next_key = k if isinstance(v, (dict, list)) else current_key
                recurse(next_key, v)

    for top, content in data.items():
        recurse(top, content)

    return ex


# --------------------------------------------------
# YAML laden + Kategorien extrahieren
# --------------------------------------------------

def _discover_category_files(config_dir: Path) -> list[Path]:
    """
    Lädt alle Kategorie-YAMLs aus config/.
    config.yaml bleibt Steuerdatei und wird nicht als Regex-Kategorie interpretiert.
    """
    ignored = {"config.yaml", "config.yml"}
    return [
        path
        for path in sorted(config_dir.glob("*.y*ml"), key=lambda p: p.name.lower())
        if path.name.lower() not in ignored
    ]


def _load_yaml() -> dict:
    cfg_path = PROJECT_ROOT / "config" / "config.yaml"
    with cfg_path.open(encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    config_dir = PROJECT_ROOT / "config"
    category_files = _discover_category_files(config_dir)

    all_categories = {}
    all_exclusions = {}

    def load_file(path):
        with path.open(encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}

        if isinstance(data, list):
            all_categories.setdefault(path.stem, []).extend(
                item for item in data if isinstance(item, str)
            )
            return

        if not isinstance(data, dict):
            print(f"[WARN] Überspringe YAML ohne Dict-Struktur: {path.name}")
            return

        cats = extract_categories(data)
        excl = extract_exclusions(data)

        # merge
        for c, pats in cats.items():
            all_categories.setdefault(c, []).extend(pats)
        for c, ex_list in excl.items():
            all_exclusions.setdefault(c, []).extend(ex_list)

    for path in category_files:
        load_file(path)

    cfg["all_categories"] = all_categories
    cfg["all_exclusions"] = all_exclusions
    cfg["category_files_loaded"] = [path.name for path in category_files]

    print("\n--- CATEGORY LOAD REPORT ---")
    print(f"Loaded YAML files: {len(category_files)}")
    print(f"Loaded exclusions: {sum(len(v) for v in all_exclusions.values())}")
    for c, pats in sorted(all_categories.items(), key=lambda x: x[0].lower()):
        print(f"{c:40}  {len(pats)} patterns")
    print("--- END REPORT ---\n")

    return cfg


# --------------------------------------------------
# Globale Konfiguration laden
# --------------------------------------------------

_CFG = _load_yaml()

# --------------------------------------------------
# Pfade
# --------------------------------------------------

DATA_RAW = PROJECT_ROOT / _CFG["paths"]["data_raw"]
OUT_DIR = PROJECT_ROOT / _CFG["paths"]["out"]

# --------------------------------------------------
# NLP / Features
# --------------------------------------------------

LANGUAGE = _CFG["project"]["language"]
SPACY_MODEL = _CFG["spacy"]["model"]

COMPUTE_STYLE = bool(_CFG["features"]["compute_style"])
COMPUTE_CATEGORIES = bool(_CFG["features"]["compute_categories"])

# --------------------------------------------------
# Output-Dateien
# --------------------------------------------------

STYLE_FEATURES_CSV = OUT_DIR / "style_features.csv"
CATEGORY_FEATURES_CSV = OUT_DIR / "category_features.csv"
FEATURES_FULL_CSV = OUT_DIR / "features_full.csv"
PCA_SCORES_CSV = OUT_DIR / "pca_scores.csv"
CLUSTER_LABELS_CSV = OUT_DIR / "cluster_labels.csv"
