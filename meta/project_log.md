# Project Log

Public progress log for the CoRE Analytics / Computational Behavioral Linguistics project.

This Markdown version is derived from the private project logbook. Personal interaction details, private notes, and non-methodological material were intentionally omitted or generalized for Git publication. The purpose of this file is to document reproducible research progress, not to archive private working notes.

## Scope

- Tracks methodological, infrastructural, and artifact-level progress.
- Preserves dates and public research milestones where available.
- Avoids raw private interaction content and unpublished personal material.

## Timeline

### 2025-06-20 - Initial conceptual boundary model

- First written formulation of the distinction between clarification, reflection, confrontation, and boundary conditions.
- Established the early working principle that interaction intensity must be structured by explicit limits.

Reference:
- source: Projektlogbuch.docx

### 2025-06-24 - Reference interaction and directive work mode

- Documented a task-oriented interaction mode with reduced small talk and clearer procedural structure.
- Marked the beginning of treating interaction form as an analyzable linguistic object rather than incidental style.

Reference:
- source: Projektlogbuch.docx

### 2025-07-08 - External model sanity check

- A context-free external model run classified the material as a coherent human-AI interaction structure.
- This supported the decision to treat the phenomenon as a framework candidate rather than a single prompt artifact.

Reference:
- source: Projektlogbuch.docx

### 2025-07-10 to 2025-08-12 - Stability, reset, and reconstruction phase

- Multiple interaction tests exposed the importance of persistence, reset behavior, and reconstruction after memory loss.
- The project scope shifted toward observable structure: role position, agency attribution, refusal, boundary handling, and system repair.

Reference:
- source: Projektlogbuch.docx

### 2025-10-28 to 2025-11-10 - Digital psychology and interaction profiling

- Expanded the theoretical basis toward digital psychology of interaction and power/agency profiles.
- Explored humor, authority, register, and personalized response profiles as measurable interaction features.

Reference:
- source: Projektlogbuch.docx

### 2025-11-25 - Bibliometric structure block

- Created a bibliometric overview of the research field using a Scopus corpus.
- Used co-citation and keyword dynamics to identify fragmentation and the need for interaction-centered operationalization.

Reference:
- source: Projektlogbuch.docx

### 2025-11-28 to 2025-12-01 - Project formalization and empirical setup

- Formalized the project core as a digital psychology / computational behavioral linguistics framework.
- Started codebook development to operationalize interaction, agency, power, register, and affective categories.

Reference:
- source: Projektlogbuch.docx

### 2025-12-02 to 2025-12-04 - Local infrastructure and first clustering pipeline

- Prepared local Linux/CUDA-oriented infrastructure and implemented early hierarchical clustering workflows.
- Created the first structured project folders and began stabilizing the analysis pipeline.

Reference:
- source: Projektlogbuch.docx

### 2025-12-05 to 2025-12-16 - Feature expansion and pipeline activation

- Expanded feature engineering, PCA-style dimensional thinking, and psychometric framing.
- Activated corpus processing steps and moved from conceptual labels toward measurable feature matrices.

Reference:
- source: Projektlogbuch.docx

### 2025-12-17 to 2025-12-22 - Model separation and validation phase

- Prepared additional corpora and downstream model-comparison tasks.
- Used LDA, MANOVA, and PCA checks to test whether human/model distinctions and interaction axes were recoverable from features.

Reference:
- source: Projektlogbuch.docx

### 2025-12-28 to 2025-12-30 - Paper and classification expansion

- Extended literature and classification work into a broader paper-oriented structure.
- Prepared global classification vocabulary for later codebook alignment.

Reference:
- source: Projektlogbuch.docx

### 2026-01-01 to 2026-01-07 - Drift scripts, spaCy optimization, and corpus expansion

- Developed scripts for drift measurement and time-aware feature comparison.
- Optimized spaCy-based processing and expanded corpora for register and temporal drift analysis.

Reference:
- source: Projektlogbuch.docx

### 2026-01-10 to 2026-01-20 - Classifier and large-corpus feature phase

- Built a four-class classifier and scaled the corpus for stronger feature extraction.
- Moved to larger German spaCy resources and began counting formulaic response markers more systematically.

Reference:
- source: Projektlogbuch.docx

### 2026-01-25 to 2026-01-31 - GPU, OCR, multidimensional style imprint, and audio-adjacent experiments

- Set up local GPU/OCR infrastructure and created multidimensional style-profile workflows.
- Explored additional modalities and interaction signatures while keeping the analysis focus on text-derived features.

Reference:
- source: Projektlogbuch.docx

### 2026-02-09 to 2026-02-17 - Corpus sanitation and factor modeling

- Performed manual corpus cleaning and expanded the feature system to roughly 194 feature candidates.
- Worked on discriminant axes, EFA distillation, SEM planning, and robustness-oriented method design.

Reference:
- source: Projektlogbuch.docx

### 2026-03-01 to 2026-03-05 - Robustness, infrastructure, and preregistration

- Documented robustness evidence for the first principal component and advanced local training infrastructure.
- Created public-facing repository/framework structure and completed preregistration preparation.

Reference:
- source: Projektlogbuch.docx

### 2026-03-09 to 2026-03-18 - T3 data collection and deployment phase

- Collected T3 data and prepared JSONL training material.
- Completed a deployment milestone for the first locally adapted model variant.

Reference:
- source: Projektlogbuch.docx

### 2026-03-23 to 2026-04-18 - RunPod, hardware, validation, and audit calibration

- Documented remote training constraints, hardware failure, and subsequent validation work.
- Performed T3 drift analysis and began audit calibration for the category system.

Reference:
- source: Projektlogbuch.docx

### 2026-04-28 to 2026-05-06 - Prototype comparison and pipeline refactor

- Compared prototype behavior and identified a strong interaction-key effect.
- Reworked the text pipeline with Codex support and added agentic text restoration as a methodological component.

Reference:
- source: Projektlogbuch.docx

### 2026-05-19 - System consolidation and epistemological refinement

- Consolidated the system architecture and clarified the epistemological framing of the project.
- Prepared the next stage of method documentation and public artifact separation.

Reference:
- source: Projektlogbuch.docx

### 2026-06-01 - Repository publication, codebook finalization, and regex audit preservation

- Converted the existing Excel codebook into a final Git-ready CSV with 166 current YAML categories, descriptions, anchor examples, regex logic, pattern counts, and QA fields.
- Created supporting reproducibility artifacts: codebook QA, Excel/YAML alignment report, full YAML regex audit, and conservative regex refactor notes.
- Transferred the current working pipeline scripts and 167 YAML configuration files into the `milo-one/core-analytics` repository.
- Updated repository documentation, protected local raw-data/output folders via `.gitignore`, added the missing `regex` dependency, and committed/pushed the reproducibility snapshot.

Reference:
- commit: 91ca40c chore: add preregistered pipeline and codebook artifacts
- repository: https://github.com/milo-one/core-analytics
