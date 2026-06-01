# pipeline/extract_categories.py
import regex as re
import os
import pandas as pd
from tqdm import tqdm
from time import perf_counter

from config.config import DATA_RAW, OUT_DIR, _CFG


# ---------------------------------------------
# UTF-8 Prüfen
# ---------------------------------------------
def scan_for_encoding_issues(folder):
    bad_files = []
    for root, _, files in os.walk(folder):
        for f in files:
            if not f.lower().endswith((".txt", ".md", ".rtf", ".pdf")):
                continue
            path = os.path.join(root, f)
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    fh.read()
            except Exception as e:
                bad_files.append((path, str(e)))
    return bad_files

# ---------------------------------------------
# Texte einlesen
# ---------------------------------------------
def read_texts():
    rows = []
    for path in sorted(DATA_RAW.rglob("*.txt")):
        text_id = path.stem
        text = path.read_text(encoding="utf-8", errors="ignore")
        rows.append({"text_id": text_id, "text": text})
    if not rows:
        raise RuntimeError(f"Keine .txt-Dateien in {DATA_RAW} gefunden.")
    return pd.DataFrame(rows)


# ---------------------------------------------
# NESTED YAML flatten
# ---------------------------------------------
def flatten_patterns(node):
    """Rekursiv alle Regex-Strings aus verschachtelten YAML-Strukturen ziehen."""
    patterns = []

    if node is None:
        return patterns

    # direktes Pattern
    if isinstance(node, str):
        patterns.append(node)
        return patterns

    # Liste von Patterns
    if isinstance(node, list):
        for item in node:
            patterns.extend(flatten_patterns(item))
        return patterns

    # verschachtelte dicts
    if isinstance(node, dict):
        for sub in node.values():
            patterns.extend(flatten_patterns(sub))
        return patterns

    return patterns



# ---------------------------------------------
# Regex zählen
# ---------------------------------------------

def compile_regexes(patterns, category, kind):
    regexes = []
    for p in patterns:
        try:
            regexes.append(re.compile(p, flags=re.IGNORECASE | re.MULTILINE))
        except Exception as e:
            print(f"⚠️ Fehler in {kind} {category}: {p} -> {e}")
    return regexes


def match_context(text: str, start: int, end: int, max_chars: int = 500) -> str:
    left_candidates = [
        text.rfind(".", 0, start),
        text.rfind("!", 0, start),
        text.rfind("?", 0, start),
        text.rfind(";", 0, start),
        text.rfind("\n", 0, start),
    ]
    right_candidates = [
        pos for pos in (
            text.find(".", end),
            text.find("!", end),
            text.find("?", end),
            text.find(";", end),
            text.find("\n", end),
        )
        if pos != -1
    ]

    left = max(left_candidates) + 1 if max(left_candidates) != -1 else max(0, start - max_chars // 2)
    right = min(right_candidates) + 1 if right_candidates else min(len(text), end + max_chars // 2)

    if right - left > max_chars:
        left = max(0, start - max_chars // 2)
        right = min(len(text), end + max_chars // 2)

    return text[left:right]


def is_excluded(text: str, start: int, end: int, exclusion_regexes) -> bool:
    if not exclusion_regexes:
        return False
    context = match_context(text, start, end)
    return any(rgx.search(context) for rgx in exclusion_regexes)


def count_regex_matches(text: str, regex_list, exclusion_regexes=None):
    total = 0
    for rgx in regex_list:
        for hit in rgx.finditer(text):
            if is_excluded(text, hit.start(), hit.end(), exclusion_regexes):
                continue
            total += 1
    return total


# ---------------------------------------------
# RUN
# ---------------------------------------------
def run():
    run_start = perf_counter()
    OUT_DIR.mkdir(exist_ok=True, parents=True)

    print(f"-> Lese Rohtexte aus {DATA_RAW} ...")
    t_read0 = perf_counter()
    df = read_texts()
    t_read1 = perf_counter()
    print(f"   ✓ {len(df)} Texte geladen.\n")
    print(f"[BENCH] Lesen der Rohtexte: {t_read1 - t_read0:.3f} s")

    print("-> Lade Kategorien aus YAML ...")

    raw_categories = _CFG["all_categories"]
    raw_exclusions = _CFG.get("all_exclusions", {})
    categories = {}
    exclusions = {}

    print("\n-> Kompiliere Regex-Patterns ...")
    t_compile0 = perf_counter()

    for cat, node in raw_categories.items():
        patterns = flatten_patterns(node)
        categories[cat] = compile_regexes(patterns, cat, "Kategorie")

    for cat, node in raw_exclusions.items():
        patterns = flatten_patterns(node)
        exclusions[cat] = compile_regexes(patterns, cat, "Exclusion")

    t_compile1 = perf_counter()

    print("\n   ✓ Kategorien geladen:", len(categories))
    print("   ✓ Regex gesamt:", sum(len(v) for v in categories.values()))
    print("   ✓ Exclusion-Regex gesamt:", sum(len(v) for v in exclusions.values()))
    print(f"[BENCH] Regex-Kompilierung: {t_compile1 - t_compile0:.3f} s")

    # Optional Debug-Ausgabe:
    print("\n-> Zeige Pattern-Anzahl pro Kategorie:")
    for k, v in categories.items():
        print(f"   {k:30} {len(v)} Patterns")

    print("\n-> Zähle Treffer pro Kategorie und Text …\n")

    # ----------------------------
    # Kategorien zählen (fragmentfrei)
    # ----------------------------

    # Fortschrittsanzeige
    tqdm.pandas()

    # Alle Ergebnisse hier sammeln – KEIN direktes df[col] mehr!
    result_cols = {}

    print("\n-> Zähle Treffer pro Kategorie und Text …\n")
    t_match0 = perf_counter()

    for cat, regex_list in categories.items():
        col = f"cat_{cat}"
        print(f"\n--- Kategorie: {cat} ({len(regex_list)} Patterns) ---")

        # nur sammeln, nicht einfügen
        result_cols[col] = df.progress_apply(
            lambda row: count_regex_matches(
                row["text"],
                regex_list,
                exclusions.get(cat, []),
            ),
            axis=1
        )

    # Einmaliges Anhängen — fragmentfrei
    df = pd.concat([df, pd.DataFrame(result_cols)], axis=1)

    # Text entfernen
    df = df.drop(columns=["text"], errors="ignore")

    out_file = OUT_DIR / "category_features.csv"
    df.to_csv(out_file, index=False)
    print(f"\n-> Kategorie-Features gespeichert unter: {out_file}\n")

    t_match1 = perf_counter()
    run_total = perf_counter() - run_start
    match_time = t_match1 - t_match0
    print(f"[BENCH] Regex-Matching gesamt: {match_time:.3f} s")
    print(f"[BENCH] Extract-Kategorien gesamt: {run_total:.3f} s")
    print(f"[BENCH] Durchsatz Matching: {len(df)/match_time:.2f} Texte/s")
