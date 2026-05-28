# CoRE Analytics – Computational Behavioral Linguistics (CBL)

This repository contains the end-to-end data processing pipelines, psycholinguistic feature extraction, and statistical models for the CoRE research framework.

## Pipeline Architecture

The analytic framework operates in a two-stage multi-language pipeline:
1. **Extraction (Python):** Raw text corpora are processed via `spaCy` and custom Regular Expressions (`re`) to extract ~180 linguistic and stylometric feature categories.
2. **Analysis (R):** The extracted feature matrices are analyzed using PCA, LDA, and longitudinal drift-measurement models.

## Repository Structure

* `/python` - Python scripts for NLP tokenization, POS-tagging (`spaCy`), and regex-based feature extraction.
* `/R` - R scripts for data cleaning, structural equation modeling, and visualization.
* `/data` - Anonymized/synthetic sample datasets for pipeline validation.
* `/meta` - Complete codebook defining the 7-dimensional model psychology.

## Setup & Dependencies

### Python Pipeline
Navigate to `/python` and install the required NLP environment:
```bash
pip install -r requirements.txt
python -m spacy download de_core_news_lg
