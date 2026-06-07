# Repo-Sortierliste vom 2026-06-07

Zielordner fuer alles, was committed und gepusht werden soll:

```text
C:/Users/Kathrin Preuß/OneDrive/Dokumente/core-analytics
```

Diese Liste dokumentiert den Stand der heutigen Arbeit und trennt zwischen:

- sofort repo-faehig
- repo-faehig nach Strukturentscheidung
- nur lokal / privat
- Loesch- oder Archivkandidaten

## Sicherheitsstatus

Die aktuelle `.gitignore` in `core-analytics` schuetzt sensible Daten grundsaetzlich gut:

```text
data/*
!data/
!data/synthetic_sample.csv
!data/README_data.md
archive/
data_raw/
out/
```

Wichtig: Neue Dateien unter `data/` werden aktuell nicht committed, ausser sie werden explizit freigegeben. Das ist fuer Schutz gut, aber fuer ein testbares Open-Science-Beispiel muss das synthetische Testdatenset entweder in `data/synthetic_sample.csv` landen oder in `.gitignore` gezielt freigegeben werden.

Status nach Korrektur:

- `archive/` bleibt privat/ignoriert.
- `data/prompts_ki_synthetic_data.txt` bleibt privat/ignoriert.
- `data/synthetic_sample.csv` ist freigebbar; aktuell existiert sie, ist aber noch praktisch leer.
- `data/README_data.md` ist freigebbar, existiert aktuell aber noch nicht.

## Heutige Arbeitsdateien: Commit-Empfehlung

### Sofort sinnvoll ins Repo

Diese Dateien sind Methoden-/Analysecode oder Dokumentation und enthalten keine Rohdaten:

```text
MASTER_KONZEPT_work/README_Scripts.md
MASTER_KONZEPT_work/data_load.R
MASTER_KONZEPT_work/data_clean.R
MASTER_KONZEPT_work/output_tables.R
MASTER_KONZEPT_work/pca_analysis.R
MASTER_KONZEPT_work/clustering.R
MASTER_KONZEPT_work/heatmap.R
MASTER_KONZEPT_work/pca_plotly_exports.R
MASTER_KONZEPT_work/descriptive_diagnostics.R
MASTER_KONZEPT_work/manova_posthoc_diagnostics.R
MASTER_KONZEPT_work/canonical_discriminant_analysis.R
MASTER_KONZEPT_work/efa_sem.R
MASTER_KONZEPT_work/efa_sem_strict.R
MASTER_KONZEPT_work/efa_sem_minres.R
MASTER_KONZEPT_work/sem_confirm_5f.R
MASTER_KONZEPT_work/sem_visualize_5f.R
MASTER_KONZEPT_work/lda_milo_train.R
MASTER_KONZEPT_work/lda_milo_visualize_and_compare.R
MASTER_KONZEPT_work/lda_milo_apply_report.R
MASTER_KONZEPT_work/k_factor_axis.R
MASTER_KONZEPT_work/k_factor_usage_example.R
```

Empfohlener Zielort:

```text
core-analytics/r/
```

Optional uebersichtlicher:

```text
core-analytics/r/core/
core-analytics/r/pca_cluster/
core-analytics/r/diagnostics/
core-analytics/r/sem/
core-analytics/r/lda/
core-analytics/r/k_factor/
```

Die zweite Variante ist langfristig besser, braucht aber kleine Pfadanpassungen in `source(...)`-Aufrufen.

### Repo-faehig, aber erst nach Veroeffentlichungsentscheidung

```text
MASTER_KONZEPT_work/corek/
```

Das Paket `corek` ist formal pruefbar (`R CMD build` + `R CMD check`: OK) und enthaelt keine echten Referenzdaten. Es kann ins Repo, wenn die K-Faktor-Methode als transparentes Methodenpaket gezeigt werden soll.

Empfohlener Zielort:

```text
core-analytics/r-packages/corek/
```

Alternative:

```text
core-analytics/corek/
```

Nicht ins Paket:

```text
private/
data_raw/
out/
real_author_reference_features.csv
*_axis_bundle.rds
forensic_thresholds*.rds
raw_texts/
```

### Dokumente / Methodenberichte

Diese Markdown-Dateien sind hilfreich, aber vor dem Commit sollte entschieden werden, ob sie als interne Arbeitsnotizen oder als oeffentliche Methodendokumente gelten:

```text
MASTER_KONZEPT_work/analysis_decisions.md
MASTER_KONZEPT_work/cluster_decision_note.md
MASTER_KONZEPT_work/cluster_profiles.md
MASTER_KONZEPT_work/cluster_profiles_report.md
MASTER_KONZEPT_work/canonical_discriminant_report.md
MASTER_KONZEPT_work/diagnostics_and_manova_report.md
MASTER_KONZEPT_work/efa_sem_report.md
MASTER_KONZEPT_work/efa_sem_strict_report.md
MASTER_KONZEPT_work/sem_model_decision.md
MASTER_KONZEPT_work/lda_milo_report.md
MASTER_KONZEPT_work/integrated_analysis_summary.md
MASTER_KONZEPT_work/refactor_notes.md
MASTER_KONZEPT_work/tables/k_factor/k_factor_report.md
```

Empfohlener Zielort:

```text
core-analytics/meta/analysis/
```

Vorher pruefen:

- enthalten sie private Autor-/Text-IDs?
- enthalten sie sensible Modellnamen, Rohtextfragmente oder personenbezogene Hinweise?
- sollen sie in der Publikation sichtbar sein oder nur lokal bleiben?

## Nicht committen

Diese Artefakte sollten lokal bleiben oder explizit ignoriert werden:

```text
MASTER_KONZEPT_work/tables/
MASTER_KONZEPT_work/tables/k_factor/figures/
MASTER_KONZEPT_work/tables/k_factor/models/
MASTER_KONZEPT_work/tables/lda_milo_visual/
MASTER_KONZEPT_work/*.Rcheck/
MASTER_KONZEPT_work/*.tar.gz
```

Grund: Outputs, HTML-Abhaengigkeiten, Modellbundles und Ergebnisdateien koennen schnell gross werden oder private Ableitungen enthalten.

## Bestehender Repo-Bestand: Aufraeumen

### `python/`

Aktueller Inhalt:

```text
python/__init__.py
python/pipeline_spacy.py
python/requirements.txt
```

Befund:

- `pipeline_spacy.py` ist nur ein TODO-Stub.
- `__init__.py` ist leer.
- die echte Pipeline liegt unter `pipeline/`.
- `requirements.txt` gehoert nicht in `python/`, sondern an die Repo-Wurzel oder nach `pipeline/`.

Empfehlung:

1. `python/requirements.txt` nach `requirements.txt` an die Repo-Wurzel verschieben.
2. `python/` danach loeschen, falls keine weiteren echten Skripte dazukommen.

Aktuell sinnvolle Requirements fuer die echte Pipeline:

```text
pandas
numpy
spacy
scikit-learn
pyyaml
tqdm
regex
```

Optional nur ergaenzen, wenn spaeter wirklich verwendet:

```text
matplotlib
seaborn
```

Zusaetzlicher Installationshinweis fuer spaCy:

```text
python -m spacy download de_core_news_sm
```

oder das in `config/config.yaml` gesetzte Modell entsprechend installieren.

### `r/`

Aktueller Inhalt:

```text
r/01_statistical_pca.R
r/02_plots_density.R
```

Befund:

- Beide Dateien sind praktisch leer/Platzhalter.
- Sie koennen geloescht oder durch die neuen R-Skripte ersetzt werden.

Empfehlung:

- Vor dem Loeschen kurz bestaetigen.
- Danach neue R-Struktur anlegen und die relevanten heutigen Skripte hinein kopieren.

### `archive/`

Aktueller Git-Status:

```text
?? archive/
```

Befund:

- `archive/` ist derzeit untracked.
- Enthalten sind alte Daten/Feature-Outputs, darunter `features_full.csv`, `pca_scores.csv`, `cluster_labels.csv` und private/arbeitsnahe Texte.

Empfehlung:

- Nicht committen.
- Entweder in `.gitignore` aufnehmen:

```text
archive/
```

- oder nur eine oeffentliche, stark reduzierte Sample-Version daraus erstellen.

### `data/`

Befund:

- Es liegt ein neues Testdatenset unter `data/`.
- `.gitignore` erlaubt aber nur:

```text
data/synthetic_sample.csv
data/README_data.md
```

Empfehlung:

- Die synthetische Pipeline-Testdatei als `data/synthetic_sample.csv` erzeugen.
- Eine kurze `data/README_data.md` anlegen oder aktualisieren.
- Andere Testtexte nur committen, wenn sie wirklich synthetisch und freigegeben sind; dann `.gitignore` gezielt erweitern.

## Vorgeschlagene Zielstruktur

```text
core-analytics/
  README.md
  requirements.txt
  run_pipeline.py
  config/
  pipeline/
  data/
    README_data.md
    synthetic_sample.csv
  r/
    README_Scripts.md
    core/
    pca_cluster/
    diagnostics/
    sem/
    lda/
    k_factor/
  r-packages/
    corek/
  meta/
    project_log.md
    codebook.md
    analysis/
```

## Konkrete naechste Schritte

1. Synthetische `data/synthetic_sample.csv` fertig erzeugen.
2. Entscheiden, ob `corek/` jetzt schon ins Repo soll oder lokal bleibt.
3. Entscheiden, ob R-Skripte flach nach `r/` oder sortiert in Unterordner kommen.
4. `python/requirements.txt` in eine Repo-Root-`requirements.txt` ueberfuehren.
5. `python/` loeschen, falls die Stub-Dateien nicht mehr gebraucht werden.
6. Die zwei leeren R-Platzhalter in `r/` loeschen oder ersetzen.
7. `.gitignore` um `archive/` ergaenzen, falls `archive/` privat bleiben soll.
8. Erst danach `git status` pruefen und committen.
## Umgesetzt im Repo-Aufraeumschritt

- R-Skripte wurden in die bevorzugte Struktur unter `r/` einsortiert.
- `r/README_Scripts.md` wurde oben im R-Ordner abgelegt.
- `r-packages/corek/README.md` wurde als Platzhalter fuer das spaetere K-Faktor-Paket angelegt.
- `meta/analysis/kurzbericht_2026-06-07.md` wurde als kompakter Zwischenbericht angelegt.
- Der alte `python/`-Stub-Ordner wurde entfernt.
- Die leeren R-Platzhalter `r/01_statistical_pca.R` und `r/02_plots_density.R` wurden entfernt.
- `requirements.txt` wurde an der Repo-Wurzel angelegt.
- `pipeline/merge_with_style.py` versucht das konfigurierte spaCy-Modell automatisch herunterzuladen, wenn es fehlt.
- `data/features_full.csv` wurde aus `out/features_full.csv` als versionierbare Feature-Fixture abgelegt.
- `data_raw/` wurde fuer den bereitgestellten Testdatensatz versionierbar gemacht.
- `out/` und `archive/` bleiben ignoriert.

Technische Checks:

- Alle 21 R-Dateien unter `r/` wurden erfolgreich geparst.
- Python-Dateien in `pipeline/`, `config/` und `run_pipeline.py` wurden erfolgreich mit `compileall` geprueft.

