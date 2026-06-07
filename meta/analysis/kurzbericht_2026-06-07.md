# Kurzbericht: Analyse- und Skriptstand 2026-06-07

Dieser Kurzbericht fasst den aktuellen Stand der R-Analyseorganisation zusammen. Die vollstaendige methodische Darstellung wird separat ausgearbeitet.

## Pipeline-Kontext

Die Python-Pipeline liest Textdateien aus `data_raw/`, wendet die YAML/Regex-Kategorien aus `config/` an, berechnet Stil- und Strukturfeatures und schreibt die Ergebnisdateien nach `out/`. Fuer die oeffentliche Testbarkeit liegt die erzeugte Feature-Tabelle zusaetzlich als `data/features_full.csv` vor.

## R-Analysebereiche

Die R-Skripte sind in folgende Bereiche sortiert:

- `r/core/`: gemeinsame Datenlade-, Bereinigungs- und Tabellenfunktionen
- `r/pca_cluster/`: PCA, Clusterdiagnostik, Heatmaps und Plotly-PCA-Exports
- `r/diagnostics/`: deskriptive Diagnostik, MANOVA/Post-hoc und Canonical Discriminant Analysis
- `r/sem/`: EFA, strenge EFA-Varianten, konfirmatorisches 5F-SEM und SEM-Visualisierung
- `r/lda/`: MILO-LDA, Vergleichsdaten, Visualisierungen und Forensic-Audit-Layer
- `r/k_factor/`: personalisierte K-Faktor-Achse als projektinterne Metrik

## K-Faktor

Der K-Faktor misst keine Klasse, sondern die Position und Naehe eines Textes relativ zu einer personalisierten PCA-Achse. Wichtige Werte sind `k_factor` und `k_axis_distance`; ein hoher K-Wert ist nur dann interpretierbar, wenn die Achsendistanz ebenfalls niedrig ist.

## Paketstatus

Ein lokaler Paket-Prototyp `corek` wurde vorbereitet und erfolgreich geprueft. Im Repository ist vorerst nur ein Platzhalter unter `r-packages/corek/` angelegt, bis ueber Veroeffentlichung und Methodentransparenz entschieden ist.

## Datenschutz / Repo-Ordnung

- `archive/` bleibt ignoriert.
- `out/` bleibt ignoriert, weil es generierte Pipeline-Outputs enthaelt.
- `data_raw/` wird fuer den bereitgestellten Testdatensatz versionierbar gemacht.
- `data/features_full.csv` dient als synthetische/pruefbare Feature-Tabelle fuer R-Analysen.
