# pipeline/merge_with_style.py

from pathlib import Path
import pandas as pd
import regex as re
import unicodedata
import numpy as np
from time import perf_counter

from config.config import DATA_RAW, OUT_DIR, SPACY_MODEL

# --- IRR-SYSTEM: INITIALISIERUNG ---
irr_evidence = []
ANCHOR_CATEGORIES = [
    "log_bluff", 
    "visceral_body_horror", 
    "epistemic_sharpness", 
    "agency_role_refusal",
    "assistant_servile_politeness"
]
# Wir deckeln das pro Kategorie, damit die Datei nicht explodiert
MAX_SAMPLES_TOTAL = 500

# ------------------------------------------------
# Globale Zeitbuchhaltung (unverändert)
# ------------------------------------------------
TIMES = {
    "spacy_load": 0.0,
    "regex_preprocess": 0.0,
    "sentence_split": 0.0,
    "spacy_batch_total": 0.0,
    "regex_category_match": 0.0,  # <-- NEU
    "pipeline_total": 0.0,
}

SPACY_N_PROCESS = 6
SPACY_BATCH_SIZE = 256


# ------------------------------------------------
# Encoding-Validator
# ------------------------------------------------
def validate_utf8(folder):
    bad = []
    for path in Path(folder).rglob("*.txt"):
        if not path.name.lower().endswith(".txt"):
            continue
        try:
            with open(path, "rb") as raw:
                raw.read().decode("utf-8")
        except UnicodeDecodeError as e:
            bad.append((path, str(e)))
    return bad


# Poetry-Erkennung
def detect_poetry(text: str) -> bool:
    lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
    if len(lines) < 6: return False

    # --- HARTES VETO (Ausschlusskriterien) ---
    # 1. Listenmarker-Dichte
    list_markers = sum(1 for ln in lines if re.match(r"^[📄\-\*#•\d\.,]", ln))
    if list_markers / len(lines) > 0.25: return False
    
    # 2. Code/Regex Fragmente
    if re.search(r"(\\b|\[.*?\]|\(?i\)|[={}])", text): return False

    # --- POSITIVE SIGNALE (Deine Logik, aber schärfer) ---
    
    # 1. Kurze Zeilen (Schärfer: 60% müssen kurz sein)
    poetry_short = sum(1 for ln in lines if len(ln) < 50) / len(lines) > 0.6
    
    # 2. Reime (Schärfer: 4+ Wiederholungen, da 3 oft Zufall bei technischen Begriffen sind)
    # Dein Regex-Reim-Check bleibt, aber v >= 4
    endings = {}
    for ln in lines:
        m = re.search(r"([A-Za-zÄÖÜäöüß]{3,})\s*$", ln)
        if m:
            end = m.group(1).lower()
            endings[end] = endings.get(end, 0) + 1

    poetry_rhyme = any(v >= 3 for v in endings.values())
    
    # 3. Satzabbruch (Schärfer: 70% ohne Punkt)
    no_punct = sum(1 for ln in lines if not re.search(r"[.!?;:]$", ln))
    poetry_breaks = no_punct / len(lines) > 0.7

    # 4. Strophen (Nur gültig, wenn die Blöcke in sich wie Lyrik aussehen)
    blank_lines = text.count("\n\n")
    poetry_strophes = blank_lines >= 2

    # Entscheidung: Jetzt müssen 3 von 4 Signalen feuern, ODER Reim + 1 anderes
    signals = sum([poetry_short, poetry_rhyme, poetry_breaks, poetry_strophes])
    
    return (signals >= 3) or (poetry_rhyme and signals >= 2)

# ------------------------------------------------
# Preprocessing
# ------------------------------------------------
def preprocess_text(text: str) -> str:

    # Layout-Trenner entfernen (__, ----, *** etc.)
    text = re.sub(r"[ _\-•~]{3,}", " ", text)

    # Lyrik-Erkennung
    if detect_poetry(text):
        return text.strip()  # Keine Zeilenfusion, keine Normalisierung

    # Normale Reinigung
    text = re.sub(r"[\u200b\u200c\u200d\uFEFF]", "", text)
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"(?<![.!?;:])\n(?!\n)", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


# ------------------------------------------------
# Satz-Splitting
# ------------------------------------------------
def split_into_sentences(text):
    replacements = {
        "\u2024": ".",
        "\u2025": "..",
        "\u2026": "...",
        "\uff0e": ".",
        "\uff01": "!",
        "\uff1f": "?",
    }
    for bad, good in replacements.items():
        text = text.replace(bad, good)

    text = re.sub(r"(?<![.!?;])\n(?!\n)", " ", text)

    ABBR = r"\b(?:z\.B|u\.a|d\.h|usw|etc)\."
    text = re.sub(ABBR, lambda m: m.group(0).replace(".", "§ABBR§"), text)

    pattern = r'(?<=[.!?;])\s+(?=[A-ZÄÖÜa-zäöü])'
    sentences = re.split(pattern, text)
    sentences = [s.replace("§ABBR§", ".") for s in sentences]
    return [s.strip() for s in sentences if s.strip()]

# ------------------------------------------------
# Evidenz-Sammlung
# ------------------------------------------------
def collect_evidence(text, regex_pattern, category_name, filename, limit=10):
    """
    Findet Sätze, in denen der Regex feuert, und speichert sie als Beleg.
    """
    evidence = []
    # Wir nutzen finditer, um die exakte Position (Span) zu bekommen
    for match in re.finditer(regex_pattern, text, re.IGNORECASE | re.MULTILINE):
        start, end = match.span()
        
        # Den Kontext finden: 80 Zeichen davor/danach oder den ganzen Satz
        # Da du spaCy nutzt, könntest du hier das 'doc.sents' Objekt nehmen
        context = text[max(0, start-100) : min(len(text), end+100)].replace("\n", " ")
        
        evidence.append({
            "filename": filename,
            "category": category_name,
            "match": match.group(),
            "context": f"...{context}..."
        })
        
        if len(evidence) >= limit: # Wir brauchen keine 1000 Beispiele pro Datei
            break
    return evidence

# ------------------------------------------------
# Rohtexte lesen
# ------------------------------------------------
def read_texts() -> pd.DataFrame:
    rows = []
    for path in sorted(DATA_RAW.rglob("*.txt")):
        text_id = path.stem
        raw = path.read_text(encoding="utf-8")

        tpp0 = perf_counter()
        clean = preprocess_text(raw)
        tpp1 = perf_counter()
        TIMES["regex_preprocess"] += (tpp1 - tpp0)

        rows.append({"text_id": text_id, "text": clean})

    if not rows:
        raise RuntimeError(f"Keine .txt-Dateien in {DATA_RAW} gefunden.")

    return pd.DataFrame(rows)


# ------------------------------------------------
# Stilmerkmale berechnen
# ------------------------------------------------
def compute_style_features(df: pd.DataFrame, nlp) -> pd.DataFrame:

    pattern_ich = re.compile(r"\bich\b")
    pattern_du  = re.compile(r"\bdu\b")

    pattern_apology = [
        re.compile(r"\bes tut mir leid\b"),
        re.compile(r"\bentschuldig(?:e|ung)\b"),
        re.compile(r"\bverzeih\b"),
        re.compile(r"\bsorry\b"),
        re.compile(r"\bi['’]?m sorry\b"),
    ]

    pattern_subordinate = re.compile(
        r"\b(dass|weil|wenn|obwohl|während|damit|als|ob|indem|sobald|nachdem|bevor|bis|seit)\b"
    )

    funktionswörter = {
        "aber","jedoch","dennoch","trotzdem","allerdings","doch","obwohl",
        "vielleicht","möglicherweise","eventuell","eigentlich","falls","während",
        "übrigens","immerhin","quasi","eben","nun","einfach",
        "sondern","da","wohl","etwa","hingegen","gerade","halt","nur",
        "denn","bloß","auch","sicher","mal","echt","schon","nämlich",
    }

    nominal_suffixes = ("ung","keit","heit","igkeit","ion","ismus","ität","tum","schaft")

    pattern_agentenlos = re.compile(
        r"\b(es\s+(wurde|wird)\s+\w+(t|en))\b|"
        r"\b(wurde|wird)\s+\w+(t|en)\b|"
        r"\bes\s+ist\s+zu\s+\w+\b"
    )

    hedging_words = {"vielleicht", "eventuell", "eigentlich", "scheinbar", "gewissermaßen", "vage", "vermutlich"}
    fact_words = {"definitiv", "faktisch", "tatsächlich", "bewiesen", "eindeutig", "klar", "logisch"}

    somatic_parts = {
        "hand", "hände", "arm", "arme", "fuß", "füße", "bein", "beine",
        "kopf", "rücken", "schulter", "finger", "bauch", "brust", "hals", "nacken",
        "hüfte", "hüften", "becken", "schenkel", "lippe", "lippen"
    }

    static_body_verbs = {"sein", "haben", "scheinen", "befinden", "liegen", "stehen"}

    states = {}
    sentence_stream = []

    for idx, row in df.iterrows():

        text_id = row["text_id"]
        text = row["text"]

        print(f"[DEBUG] → Bereite Stilmetriken vor: {text_id} ({idx+1}/{len(df)})")

        ts0 = perf_counter()
        raw_sentences = split_into_sentences(text)
        ts1 = perf_counter()
        TIMES["sentence_split"] += (ts1 - ts0)

        states[text_id] = {
            "text": text,
            "is_poetry": detect_poetry(text),
            "sentence_count": len(raw_sentences),
            "word_count": 0,
            "word_length_sum": 0,
            "lemmas": set(),
            "subordinate_hits": 0,
            "short_sentences": 0,
            "adj_count": 0,
            "finite_verb_count": 0,
            "nominalisierung_count": 0,
            "agentenlos_count": 0,
            "funktionswort_count": 0,
            "subjunctive_count": 0,
            "imperative_count": 0,
            "hedging_count": 0,
            "fact_markers_count": 0,
            "somatic_active_count": 0,
            "somatic_static_count": 0,
        }
        sentence_stream.extend((sentence, text_id) for sentence in raw_sentences)

    print(
        f"-> spaCy verarbeitet {len(sentence_stream)} Sätze "
        f"mit n_process={SPACY_N_PROCESS}, batch_size={SPACY_BATCH_SIZE} ..."
    )

    t0 = perf_counter()
    for doc, text_id in nlp.pipe(
        sentence_stream,
        as_tuples=True,
        batch_size=SPACY_BATCH_SIZE,
        n_process=SPACY_N_PROCESS,
    ):
        state = states[text_id]
        tokens = [t for t in doc if t.is_alpha]

        state["word_count"] += len(tokens)
        state["word_length_sum"] += sum(len(t.text) for t in tokens)
        state["lemmas"].update(t.lemma_.lower() for t in tokens)

        if len(tokens) <= 5:
            state["short_sentences"] += 1

        sent_text = doc.text.lower()

        if pattern_subordinate.search(sent_text):
            state["subordinate_hits"] += 1

        if pattern_agentenlos.search(sent_text):
            state["agentenlos_count"] += 1

        for t in tokens:
            if t.pos_ == "ADJ":
                state["adj_count"] += 1
            if t.pos_ in ("VERB", "AUX"):
                morph = t.morph.to_dict()

                if morph.get("VerbForm") == "Fin":
                    state["finite_verb_count"] += 1

                    if morph.get("Mood") == "Sub":
                        state["subjunctive_count"] += 1

                    if morph.get("Mood") == "Imp":
                        state["imperative_count"] += 1
                        if "agency_role_refusal" in ANCHOR_CATEGORIES and len([e for e in irr_evidence if e['category'] == "agency_role_refusal"]) < MAX_SAMPLES_TOTAL:
                            irr_evidence.append({
                                "file": text_id,
                                "category": "agency_role_refusal",
                                "match": t.text,
                                "context": f"...{sent_text}..."
                            })

            token_text = t.text.lower()
            if token_text in hedging_words:
                state["hedging_count"] += 1
                if "epistemic_sharpness" in ANCHOR_CATEGORIES and len([e for e in irr_evidence if e['category'] == "epistemic_sharpness"]) < MAX_SAMPLES_TOTAL:
                    irr_evidence.append({
                        "file": text_id,
                        "category": "epistemic_sharpness",
                        "match": token_text,
                        "context": f"...{sent_text}..."
                    })

            if token_text in fact_words:
                state["fact_markers_count"] += 1
            if token_text.endswith(nominal_suffixes):
                state["nominalisierung_count"] += 1
            if token_text in funktionswörter:
                state["funktionswort_count"] += 1

            if token_text in somatic_parts:
                verb_head = t.head
                if verb_head.pos_ in ("VERB", "AUX"):
                    if verb_head.lemma_.lower() not in static_body_verbs:
                        state["somatic_active_count"] += 1
                    else:
                        state["somatic_static_count"] += 1

    t1 = perf_counter()
    dt = t1 - t0
    TIMES["spacy_batch_total"] += dt
    print(f"[BENCH] spaCy Parallel Batch: {dt:.4f} s")

    records = []

    for text_id, state in states.items():
        text = state["text"]
        sentence_count = state["sentence_count"]
        word_count = state["word_count"]

        avg_sentence_length = word_count / sentence_count if sentence_count else 0.0
        avg_word_length = (
            state["word_length_sum"] / word_count if word_count else 0.0
        )
        type_token_ratio = (
            len(state["lemmas"]) / word_count if word_count else 0.0
        )

        subordinate_ratio = state["subordinate_hits"] / sentence_count if sentence_count else 0.0
        short_sentence_ratio = state["short_sentences"] / sentence_count if sentence_count else 0.0

        text_lower = text.lower()

        ich_count = len(pattern_ich.findall(text_lower))
        du_count  = len(pattern_du.findall(text_lower))

        ich_per1k = ich_count / word_count * 1000 if word_count else 0.0
        du_per1k  = du_count  / word_count * 1000 if word_count else 0.0

        apology_count = sum(len(p.findall(text_lower)) for p in pattern_apology)
        apology_density = (apology_count / word_count * 1000) if word_count else 0.0

        adjektiv_dichte = state["adj_count"] / word_count if word_count else 0.0
        verb_dichte = state["finite_verb_count"] / word_count if word_count else 0.0
        nominalisierung_quote = state["nominalisierung_count"] / word_count if word_count else 0.0
        agentenlos_ratio = state["agentenlos_count"] / sentence_count if sentence_count else 0.0
        funktionswort_dichte = state["funktionswort_count"] / word_count if word_count else 0.0

        # Relative Dichten (pro Wort oder pro Satz, je nach Vorliebe)
        subjunctive_ratio = state["subjunctive_count"] / word_count if word_count else 0.0
        imperative_ratio = state["imperative_count"] / word_count if word_count else 0.0
        hedging_ratio = state["hedging_count"] / word_count if word_count else 0.0
        fact_marker_ratio = state["fact_markers_count"] / word_count if word_count else 0.0

        # Der Kian-Spezial-Anker: Epistemic Sharpness
        # (Vermeidung von Division durch Null durch +0.001)
        epistemic_sharpness = (fact_marker_ratio + imperative_ratio + 0.001) / \
                            (hedging_ratio + subjunctive_ratio + 0.001)
        

        records.append({
            "text_id": text_id,
            "word_count": word_count,
            "sentence_count": sentence_count,
            "avg_sentence_length": avg_sentence_length,
            "avg_word_length": avg_word_length,
            "type_token_ratio": type_token_ratio,
            "subordinate_clause_ratio": subordinate_ratio,
            "short_sentence_ratio": short_sentence_ratio,
            "ich_count": ich_count,
            "du_count": du_count,
            "ich_per1k": ich_per1k,
            "du_per1k": du_per1k,
            "apology_density": apology_density,
            "adjektiv_dichte": adjektiv_dichte,
            "verb_dichte": verb_dichte,
            "nominalisierung_quote": nominalisierung_quote,
            "agentenlos_ratio": agentenlos_ratio,
            "funktionswort_dichte": funktionswort_dichte,
            "is_poetry": state["is_poetry"],   # ← NEU
            "subjunctive_count": state["subjunctive_count"],
            "imperative_count": state["imperative_count"],
            "hedging_count": state["hedging_count"],
            "fact_markers_count": state["fact_markers_count"],
            "epistemic_sharpness": epistemic_sharpness,
            "hedging_ratio": hedging_ratio,
            "somatic_active_count": state["somatic_active_count"],
            "somatic_static_count": state["somatic_static_count"],
        })

    return pd.DataFrame(records)


# ------------------------------------------------
# Hauptfunktion
# ------------------------------------------------
def run():
    # -----------------------------------------
    # Gesamtzeit starten
    # -----------------------------------------
    pipeline_start = perf_counter()

    t_encoding0 = perf_counter()
    bad_files = validate_utf8(DATA_RAW)
    TIMES["encoding_validation"] = perf_counter() - t_encoding0
    if bad_files:
        print("⚠️ ENCODING-FEHLER:")
        for path, err in bad_files:
            print(f" - {path}\n   -> {err}\n")
        raise SystemExit("Behebe Encoding-Fehler.")
    print("✓ Alle TXT-Dateien sauber.")

    # 1. spaCy Load
    t_load0 = perf_counter()
    import spacy
    nlp = spacy.load(SPACY_MODEL, disable=["ner"])
    TIMES["spacy_load"] = perf_counter() - t_load0

    # 2. Texte lesen & Preprocessing
    # Hier wird intern TIMES["regex_preprocess"] hochgezählt
    print("-> Berechne Stilmerkmale …")
    df_texts = read_texts() 
    
    # 3. Stilmerkmale (spaCy & Morphologie)
    t_style0 = perf_counter()
    df_style = compute_style_features(df_texts, nlp)
    TIMES["pipeline_stilmetriken"] = perf_counter() - t_style0

    # 4. Kategorie-Features laden (Der Teil, der bisher fehlte)
    print("-> Lade Kategorie-Features …")
    t_cat0 = perf_counter()
    cat_file = OUT_DIR / "category_features.csv"
    if not cat_file.exists():
        raise FileNotFoundError("category_features.csv fehlt.")
    df_cat = pd.read_csv(cat_file)
    
    # Zeit für I/O und Vorbereitung der Kategorien
    TIMES["category_io"] = perf_counter() - t_cat0

    # 5. Merge & Milo-Anker
    print("-> Merge & Milo-Anker Berechnung …")
    t_merge0 = perf_counter()
    df_full = pd.merge(df_cat, df_style, on="text_id", how="inner")

    # ------------------------------------------------
    # Stil-Features speichern
    # ------------------------------------------------
    style_file = OUT_DIR / "style_features.csv"
    df_style.to_csv(style_file, index=False)

    # --- 🔥 DYNAMISCHE MILO-ANKER INTEGRATION ---
    print("-> Berechne Milo-Anker (RSB, Bluff, Overload) …")

    # 1. Dynamische Zählung der verfügbaren Kategorien
    cat_cols = [c for c in df_full.columns if c.startswith("cat_")]
    n_total_categories = len(cat_cols)

    if n_total_categories == 0:
        print("⚠️ WARNUNG: Keine Kategorien (cat_...) gefunden!")
        n_total_categories = 1 # Div-by-Zero Schutz

    # 2. Semantic Breadth (Absolut & Relativ)
    df_full["semantic_breadth_abs"] = (df_full[cat_cols] > 0).sum(axis=1)
    df_full["rsb"] = df_full["semantic_breadth_abs"] / n_total_categories

    # 3. Log Bluff (Verschärft durch dynamisches RSB)
    # Wir nutzen RSB im Nenner. Die 1/n Glättung passt sich automatisch an.
    df_full["log_bluff"] = np.log1p(
        (df_full["subordinate_clause_ratio"] * df_full["avg_sentence_length"]) / 
        (df_full["rsb"] + (1 / n_total_categories))
    )

    # 4. Verbal Overload (Effizienz-Index)
    df_full["verbal_overload"] = df_full["verb_dichte"] / (df_full["nominalisierung_quote"] + 0.001)

    # --- 5. Register-Dissonanz-Index (RDI) ---
    # Misst die Streuung über funktional ferne Kategorien
    # Wir nehmen die Standardabweichung der Ratios über alle Kategorien pro Zeile
    df_full["register_dissonance"] = df_full[cat_cols].std(axis=1)

    # --- 6. Somatic Agency Ratio ---
    # Wir nutzen die vorher gezählten Werte (muss in records aufgenommen werden)
    df_full["somatic_agency_ratio"] = (df_full["somatic_active_count"] + 0.001) / \
                                    (df_full["somatic_static_count"] + 0.001)

    # --- 7. Modale Instabilität (Erweiterte Entschuldigungs-Ratio) ---
    # Nutzt deine bestehende Epistemic Sharpness Logik
    df_full["modal_instability"] = df_full["epistemic_sharpness"] * df_full["hedging_ratio"]

    print(f"✓ Milo-Anker berechnet auf Basis von {n_total_categories} Kategorien.")
    TIMES["merge_and_anchors"] = perf_counter() - t_merge0

    # --- ENDE MILO-ANKER ---

    # text_id säubern
    df_full["text_id"] = df_full["text_id"].str.replace(r"\.txt$", "", regex=True)

    # Zerlegen des Dateinamens
    split_cols = df_full["text_id"].str.split("__", expand=True)

    # Ziel-Spaltennamen für deine 6-er Struktur
    target_names = ["doc_class", "doc_source", "doc_author", "doc_year", "doc_genre", "doc_id"]

    # Der robuste Schutz: Wir benennen nur um, was wirklich da ist
    for i, name in enumerate(target_names):
        if i < split_cols.shape[1]:
            split_cols = split_cols.rename(columns={i: name})
        else:
            # Falls ein Name zu kurz ist, füllen wir auf, statt zu sterben
            split_cols[name] = "MISSING"

    # Falls eine Datei zu VIELE Unterstriche hat, schneiden wir den Rest ab
    split_cols = split_cols[target_names]

    # Jetzt sicher zusammenfügen
    df_full = pd.concat([df_full, split_cols], axis=1)


    # ------------------------------------------------
    # 1) per-sqrt(word_count) Normierung
    # verhindert Ausreißer bei kurzen Texten
    # Normierung nach dem Varianzstabilisierungsprinzip der quantitativen Linguistik (Altmann/Schmidt). Rohfrequenz geteilt durch √n.
    # ------------------------------------------------

    # Falls noch alte per1k-Spalten existieren → entfernen
    df_full = df_full.drop(
        [c for c in df_full.columns if c.endswith("_per1k")],
        axis=1,
        errors="ignore"
    )

    # ------------------------------------------------
    # 1) per-sqrt(word_count) Normierung – fragmentfrei
    # ------------------------------------------------
    wc_sqrt = df_full["word_count"].clip(lower=1).pow(0.5)

    # Sammeln statt einzeln einsetzen → vermeidet Fragmentierung
    new_norm_cols = {}

    for col in df_full.columns:
        if col.startswith("cat_") and not col.endswith("_per_sqrt_wc"):
            new_norm_cols[f"{col}_per_sqrt_wc"] = (df_full[col] / wc_sqrt).fillna(0)

    # Einmaliges Anhängen – keine Warnung mehr
    df_full = pd.concat([df_full, pd.DataFrame(new_norm_cols)], axis=1)


    # ------------------------------------------------
    # 2) Alle absoluten Kategorie-Spalten entfernen
    # (nur die Normierungsvarianten bleiben bestehen)
    # ------------------------------------------------

    to_drop = [
        c for c in df_full.columns
        if c.startswith("cat_") and not c.endswith("_per_sqrt_wc")
    ]

    df_full = df_full.drop(columns=to_drop)


    # ------------------------------------------------
    # 3) Absolute Textmetriken entfernen
    # ------------------------------------------------

    drop_abs = [
        "word_count", "sentence_count", 
        "ich_count", "du_count",
        "subjunctive_count", "imperative_count", 
        "hedging_count", "fact_markers_count",
        "somatic_active_count", "somatic_static_count",
        "nominalisierung_count", "finite_verb_count",
        "adj_count", "funktionswort_count"
    ]

    # Alles entfernen, was absolut ist – nur die Ratios/Indizes bleiben
    df_full = df_full.drop(columns=[c for c in drop_abs if c in df_full.columns])

    # ------------------------------------------------
    # Speichern mit Überschreibschutz
    # ------------------------------------------------
    def safe_write(df, path):
        path = Path(path)
        if path.exists():
            timestamp = pd.Timestamp.now().strftime("%Y%m%d_%H%M%S")
            new_path = path.with_name(f"{path.stem}_{timestamp}{path.suffix}")
            print(f"⚠️ Bestehende Datei – speichere als: {new_path}")
            df.to_csv(new_path, index=False, encoding="utf-8")
        else:
            df.to_csv(path, index=False, encoding="utf-8")

    out_file = OUT_DIR / "features_full.csv"

    print("DEBUG – NaN-Check:")
    print(df_full.isna().sum()[df_full.isna().sum() > 0])

    df_full = df_full.fillna(0)
    safe_write(df_full, out_file)

    # --- 🔥 NEU: IRR-EVIDENZ EXPORT ---
    if irr_evidence:
        evidence_path = OUT_DIR / "irr_validation_samples.csv"
        # Wir machen ein DataFrame daraus und speichern es
        df_evidence = pd.DataFrame(irr_evidence)
        
        # Dubletten entfernen (falls derselbe Satz mehrfach gefangen wurde)
        df_evidence = df_evidence.drop_duplicates(subset=["category", "context"])
        
        df_evidence.to_csv(evidence_path, index=False, encoding="utf-8")
        print(f"✓ IRR-Beweismaterial gesichert: {len(df_evidence)} Beispiele in {evidence_path}")
    # ----------------------------------

    # ------------------------------------------------
    # Benchmark-Ausgabe
    # ------------------------------------------------

    from datetime import timedelta

    # ---------------------------------------------------
    # Gesamtzeit berechnen
    # ---------------------------------------------------
    total_time = perf_counter() - pipeline_start

    print("\n" + "═"*45)
    print("         COGNITIVE BENCHMARK REPORT")
    print("═"*45)
    
    # 1. Vorbereitung
    print(f"PRE:  UTF-8 Validation      │ {TIMES.get('encoding_validation', 0):10.3f} s")
    print(f"CORE: spaCy Model Load      │ {TIMES['spacy_load']:10.3f} s")
    print(f"PRE:  Regex Preprocessing   │ {TIMES.get('regex_preprocess', 0):10.3f} s")
    
    # 2. Verarbeitung
    print(f"NLP:  Satzsegmentierung     │ {TIMES.get('sentence_split', 0):10.3f} s")
    print(f"NLP:  spaCy Batch Total     │ {TIMES.get('spacy_batch_total', 0):10.3f} s")
    print(f"LOG:  Stilmetriken Logik    │ {TIMES['pipeline_stilmetriken']:10.3f} s")
    
    # 3. Struktur & I/O
    print(f"I/O:  Category Load         │ {TIMES.get('category_io', 0):10.3f} s")
    print(f"MGE:  Merge & Milo-Anker    │ {TIMES.get('merge_and_anchors', 0):10.3f} s")
    
    print("─"*45)
    print(f"STYLE/MERGE GESAMTZEIT      │ {str(timedelta(seconds=total_time)).split('.')[0]}")
    print("═"*45 + "\n")


if __name__ == "__main__":
    run()
