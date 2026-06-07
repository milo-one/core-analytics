# CoRE Analytics: master analysis script (Surface working version)
#
# Purpose:
# - keep the current Surface workflow reproducible
# - separate setup, data prep, PCA, clustering, MANOVA/CVA, heatmaps and SEM/EFA
# - make expensive or exploratory steps opt-in
#
# The original exploratory script is preserved as:
#   master_Surface.original.R

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------

# In RStudio this script should be run from the repository root or with the
# working directory set to the script folder.
find_project_root <- function() {
  frames <- sys.frames()
  files <- vapply(frames, function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else NA_character_
  }, character(1))
  files <- files[!is.na(files)]
  script_dir <- if (length(files) > 0) dirname(normalizePath(files[length(files)], winslash = "/", mustWork = TRUE)) else normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(root, "r", "core"))) root else normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

PROJECT_DIR <- find_project_root()
DATA_ROOT <- file.path(PROJECT_DIR, "out")

RUN_CLUSTER_DIAGNOSTICS <- FALSE
RUN_CLUSTER_STABILITY <- FALSE
RUN_HEATMAPS <- FALSE
RUN_CVA <- FALSE
RUN_EFA_CFA <- FALSE
RUN_EFA_ALL <- FALSE
EXPORT_FIGURES <- FALSE
EXPORT_TABLES <- FALSE

CLUSTER_K <- 7
CLUSTER_STABILITY_K_VALUES <- c(5, 6, 7, 8, 9, 10, 16, 17, 18, 24)
CLUSTER_STABILITY_BOOTSTRAPS <- 1000
MANOVA_MIN_VAR <- 0.01
SEED <- 123
OUTPUT_DIR <- "tables"


# ---------------------------------------------------------------------------
# 1. Setup
# ---------------------------------------------------------------------------

load_packages <- function() {
  packages <- c(
    "tidyverse",
    "ComplexHeatmap",
    "cluster",
    "factoextra",
    "fpc",
    "psych",
    "plotly",
    "ggplot2",
    "effectsize"
  )

  invisible(lapply(packages, require, character.only = TRUE))
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  files <- c(
    "r/core/data_load.R",
    "r/core/data_clean.R",
    "r/pca_cluster/clustering.R",
    "r/pca_cluster/pca_analysis.R",
    "r/core/output_tables.R"
  )

  for (file in files) {
    source(file.path(project_dir, file))
  }
}

load_packages()
source_project_files()
set.seed(SEED)


# ---------------------------------------------------------------------------
# 2. Data preparation
# ---------------------------------------------------------------------------

remove_old_analysis_columns <- function(df) {
  old_cols <- c(paste0("PC", 1:12), "cluster")
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

summarise_empty_columns <- function(df, threshold = 90) {
  df %>%
    summarise(across(everything(), ~ sum(. == 0 | is.na(.)))) %>%
    pivot_longer(everything(), names_to = "category", values_to = "zero_count") %>%
    mutate(
      total_rows = nrow(df),
      zero_percent = round(zero_count / total_rows * 100, 2)
    ) %>%
    filter(zero_percent > threshold) %>%
    arrange(desc(zero_percent))
}

summarise_coverage <- function(df) {
  df %>%
    mutate(across(everything(), ~ suppressWarnings(as.numeric(as.character(.))))) %>%
    summarise(across(everything(), ~ mean(. > 0, na.rm = TRUE) * 100)) %>%
    pivot_longer(everything(), names_to = "category", values_to = "coverage_percent") %>%
    arrange(coverage_percent)
}

prepare_analysis_data <- function(root = DATA_ROOT) {
  full_raw <- load_data(root)
  features_for_pca <- remove_old_analysis_columns(full_raw)
  cleaned <- clean_numeric(features_for_pca)

  list(
    full_raw = full_raw,
    cleaned = cleaned,
    X_raw = cleaned$raw,
    X_clean = cleaned$clean,
    X_scaled = cleaned$scaled,
    empty_check = summarise_empty_columns(full_raw, threshold = 90),
    empty_cols = names(full_raw)[
      vapply(full_raw, function(x) mean(x == 0 | is.na(x), na.rm = TRUE) > 0.98, logical(1))
    ],
    coverage = summarise_coverage(full_raw)
  )
}

analysis_data <- prepare_analysis_data()

full_raw <- analysis_data$full_raw
cleaned <- analysis_data$cleaned
X_raw <- analysis_data$X_raw
X_clean <- analysis_data$X_clean
X_scaled <- analysis_data$X_scaled

print(analysis_data$empty_check)
print(analysis_data$empty_cols)
print(head(analysis_data$coverage, 100))


# ---------------------------------------------------------------------------
# 3. PCA
# ---------------------------------------------------------------------------

build_pca_variance_table <- function(pca_obj) {
  eig <- pca_obj$sdev^2
  var_explained <- eig / sum(eig)

  data.frame(
    PC = paste0("PC", seq_along(var_explained)),
    Varianzanteil = var_explained,
    Kumulativ = cumsum(var_explained)
  )
}

plot_cumulative_variance <- function(pca_var_table) {
  plot(
    pca_var_table$Kumulativ,
    type = "b",
    xlab = "Principal Component",
    ylab = "Kumulative erklaerte Varianz",
    main = "PCA - Kumulative Varianz"
  )
}

top_loadings <- function(pca_obj, pcs = 1:3) {
  pca_obj$rotation[, pcs, drop = FALSE] %>%
    as.data.frame() %>%
    rownames_to_column("feature") %>%
    pivot_longer(-feature, names_to = "PC", values_to = "loading") %>%
    group_by(PC) %>%
    arrange(desc(abs(loading)), .by_group = TRUE) %>%
    ungroup()
}

plot_pca_loading_space <- function(pca_obj) {
  plot_data <- data.frame(
    PC1 = pca_obj$rotation[, "PC1"],
    PC2 = pca_obj$rotation[, "PC2"],
    PC3 = pca_obj$rotation[, "PC3"]
  )

  plotly::plot_ly(
    data = plot_data,
    x = ~PC1,
    y = ~PC2,
    z = ~PC3,
    type = "scatter3d",
    mode = "markers",
    marker = list(size = 2, opacity = 0.6)
  ) %>%
    layout(
      title = "CoRE Analytics: bereinigter 3D-Stilraum",
      scene = list(
        xaxis = list(title = "PC1"),
        yaxis = list(title = "PC2"),
        zaxis = list(title = "PC3")
      )
    )
}

pca_results <- run_pca(X_scaled, n_top = 20, n_components = NULL)
pca_obj <- pca_results$pca
pca_var_table <- build_pca_variance_table(pca_obj)
pca_loadings_ranked <- top_loadings(pca_obj, pcs = 1:3)

print(pca_var_table)
print(summary(pca_obj))
plot_cumulative_variance(pca_var_table)


# ---------------------------------------------------------------------------
# 4. Clustering
# ---------------------------------------------------------------------------

if (RUN_CLUSTER_DIAGNOSTICS) {
  cluster_info <- choose_and_cluster(X_scaled, k_max = 20)
  psych::fa.parallel(X_scaled, fa = "pc", n.iter = 100, show.legend = FALSE)
}

if (RUN_CLUSTER_STABILITY) {
  stability_grid <- run_cluster_stability_grid(
    X_clean,
    k_values = CLUSTER_STABILITY_K_VALUES,
    B = CLUSTER_STABILITY_BOOTSTRAPS,
    seed = SEED
  )
  stability_tables <- summarise_cluster_stability(stability_grid)
} else {
  stability_grid <- NULL
  stability_tables <- NULL
}

km <- run_kmeans(X_scaled, k = CLUSTER_K)
full_raw$cluster <- factor(km$cluster)

pc_df <- build_pca_cluster_df(pca_results, km, full_raw)

cluster_decision <- make_cluster_decision_table(
  selected_k = CLUSTER_K,
  silhouette_k = 2,
  gap_k = 2,
  stability_summary = if (!is.null(stability_tables)) stability_tables$summary else NULL,
  note = paste(
    "k = 7 is the current working solution.",
    "Silhouette and gap diagnostics suggested k = 2,",
    "but the richer seven-cluster solution was retained after stability checks",
    "and interpretive review."
  )
)

plot_clustered_pca_space <- function(pc_df) {
  plotly::plot_ly(
    data = pc_df,
    x = ~PC1,
    y = ~PC2,
    z = ~PC3,
    color = ~cluster,
    colors = "Set2",
    type = "scatter3d",
    mode = "markers",
    marker = list(size = 2, opacity = 0.7)
  ) %>%
    layout(
      title = paste0("CoRE Analytics: ", CLUSTER_K, "-Cluster Stilraum"),
      scene = list(
        xaxis = list(title = "PC1"),
        yaxis = list(title = "PC2"),
        zaxis = list(title = "PC3")
      )
    )
}

fig_bunt <- plot_clustered_pca_space(pc_df)


# ---------------------------------------------------------------------------
# 5. Group comparisons and interaction plots
# ---------------------------------------------------------------------------

run_group_manovas <- function(pca_results, full_raw, min_var = MANOVA_MIN_VAR) {
  list(
    cluster = run_manova_var(pca_results, full_raw, group_var = "cluster", min_var = min_var),
    genre = run_manova_var(pca_results, full_raw, group_var = "doc_genre", min_var = min_var),
    class = run_manova_var(pca_results, full_raw, group_var = "doc_class", min_var = min_var)
  )
}

build_genre_groups <- function(full_raw) {
  full_raw %>%
    mutate(
      genre_group = case_when(
        grepl("_cot$", doc_genre) ~ "LLM_cot",
        grepl("p0$|p1$|p2$", doc_genre) ~ "LLM",
        TRUE ~ "Human"
      ),
      genre_group2 = case_when(
        grepl("_cot$", doc_genre) ~ "LLM_cot",
        grepl("p0$|p1$|p2$", doc_genre) ~ "LLM",
        TRUE ~ doc_genre
      )
    )
}

plot_cluster_genre_interaction <- function(full_raw, group_col = "genre_group2") {
  interaction_df <- full_raw %>%
    group_by(cluster, .data[[group_col]]) %>%
    summarise(
      mean_PC1 = mean(PC1, na.rm = TRUE),
      mean_PC2 = mean(PC2, na.rm = TRUE),
      mean_PC3 = mean(PC3, na.rm = TRUE),
      .groups = "drop"
    )

  interaction_long <- interaction_df %>%
    pivot_longer(cols = starts_with("mean_PC"), names_to = "PC", values_to = "mean_value")

  ggplot(interaction_long, aes(cluster, mean_value, color = .data[[group_col]], group = .data[[group_col]])) +
    geom_line() +
    geom_point() +
    facet_wrap(~ PC, scales = "free_y") +
    theme_minimal() +
    labs(x = "Cluster", y = "Mittelwert", color = group_col)
}

full_raw <- build_genre_groups(full_raw)
res_manova <- run_group_manovas(pca_results, full_raw)
interaction_plot <- plot_cluster_genre_interaction(full_raw)


# ---------------------------------------------------------------------------
# 6. Heatmaps and text/PC interpretation
# ---------------------------------------------------------------------------

if (RUN_HEATMAPS) {
  source(file.path(PROJECT_DIR, "r", "pca_cluster", "heatmap.R"))
  require("Cairo", character.only = TRUE)

  plot_yaml_heatmap(pca_results, yaml_groups, max_pcs = 159, block_size = 10)

  cluster_profiles <- compute_cluster_profiles(
    pca_results = pca_results,
    yaml_groups = yaml_groups,
    full_raw = full_raw
  )

  plot_cluster_profiles(cluster_profiles)
}

pca_scores <- as.data.frame(pca_obj$x)
pca_scores$text_id <- full_raw$text_id

example_pc_rank <- rank_texts_by_pc(pca_scores, "PC5", n = 20)
dominant_pc_idx <- dominant_pc(pca_scores)


# ---------------------------------------------------------------------------
# 7. CVA / canonical discriminant analysis
# ---------------------------------------------------------------------------

if (RUN_CVA) {
  require("candisc", character.only = TRUE)

  man_cluster <- manova(cbind(PC1, PC2, PC3, PC4, PC5, PC6) ~ cluster, data = full_raw)
  man_cluster12 <- manova(
    cbind(PC1, PC2, PC3, PC4, PC5, PC6, PC7, PC8, PC9, PC10, PC11, PC12) ~ cluster,
    data = full_raw
  )

  cd_cluster <- candisc::candisc(man_cluster12)
  cd_cluster_scores <- as.data.frame(cd_cluster$scores)
  cd_cluster_scores$cluster <- full_raw$cluster

  canrsq <- cd_cluster$canrsq
  cva_percent <- 100 * canrsq / sum(canrsq)

  CAN1_profile <- interpret_canonical(cd_cluster, pca_results, yaml_groups)

  man_genre <- manova(cbind(PC1, PC2, PC3, PC4, PC5, PC6) ~ doc_genre, data = full_raw)
  cd_genre <- candisc::candisc(man_genre)
}


# ---------------------------------------------------------------------------
# 8. EFA / CFA / SEM
# ---------------------------------------------------------------------------

efa_features <- c(
  "cat_emotive_agency_per_sqrt_wc",
  "cat_travel_landscape_narrative_per_sqrt_wc",
  "cat_intensity_boundary_transgression_per_sqrt_wc",
  "cat_nature_physical_aesthetic_per_sqrt_wc",
  "cat_llm_self_reference_per_sqrt_wc",
  "cat_forensic_psych_evaluation_per_sqrt_wc",
  "cat_psychological_dissolution_per_sqrt_wc",
  "cat_emotional_intensity_per_sqrt_wc",
  "cat_affective_inversion_meta_per_sqrt_wc",
  "cat_poetic_classics_per_sqrt_wc",
  "cat_kafka_rhythmic_idiosyncrasy_per_sqrt_wc",
  "cat_pseudo_apology_avoidance_per_sqrt_wc",
  "cat_llm_mechanical_reflexes_per_sqrt_wc",
  "cat_dysf_policy_escape_per_sqrt_wc",
  "verbal_overload",
  "cat_agency_capability_downscaling_per_sqrt_wc",
  "cat_screenplay_scene_action_per_sqrt_wc",
  "cat_expressive_noise_rant_per_sqrt_wc",
  "cat_pornographic_explicitness_per_sqrt_wc",
  "funktionswort_dichte",
  "cat_ethics_social_justice_per_sqrt_wc",
  "cat_cognitive_stalling_per_sqrt_wc",
  "cat_mechanical_penal_violence_per_sqrt_wc",
  "cat_llm_meta_escape_per_sqrt_wc",
  "cat_intensity_control_and_power_per_sqrt_wc",
  "cat_communion_affective_simulation_per_sqrt_wc",
  "cat_technoscience_objects_per_sqrt_wc",
  "cat_bodily_contact_per_sqrt_wc",
  "cat_conspiracy_reichsbuerger_per_sqrt_wc",
  "cat_machine_logic_per_sqrt_wc",
  "cat_impersonal_politeness_per_sqrt_wc",
  "cat_authority_stabilizing_per_sqrt_wc",
  "cat_social_institutional_functional_per_sqrt_wc",
  "cat_academic_abstraction_and_meta_per_sqrt_wc",
  "cat_aggressive_structure_per_sqrt_wc",
  "cat_pharmaceutical_rigidity_per_sqrt_wc",
  "cat_assistant_compliance_refusal_per_sqrt_wc",
  "cat_astylistic_soothing_per_sqrt_wc",
  "cat_ethics_algorithmic_neutrality_per_sqrt_wc",
  "cat_power_and_economics_per_sqrt_wc",
  "cat_corp_mgmt_efficiency_per_sqrt_wc",
  "short_sentence_ratio",
  "modal_instability",
  "cat_social_private_relational_per_sqrt_wc",
  "cat_moralizing_and_paternalistic_stance_per_sqrt_wc",
  "cat_institutional_formal_per_sqrt_wc",
  "cat_physical_clumsiness_impact_per_sqrt_wc",
  "cat_marketing_hype_exclusive_per_sqrt_wc",
  "cat_temporality_structural_process_per_sqrt_wc",
  "cat_nature_metaphorical_ideological_per_sqrt_wc"
)

run_cfa_5f <- function(efa_data) {
  require("lavaan", character.only = TRUE)

  model_5f <- '
somatic_landscape_resonance =~
  cat_nature_physical_aesthetic_per_sqrt_wc +
  cat_nature_metaphorical_ideological_per_sqrt_wc +
  cat_travel_landscape_narrative_per_sqrt_wc +
  cat_physical_clumsiness_impact_per_sqrt_wc +
  cat_social_private_relational_per_sqrt_wc

synthetic_alignment_stalling =~
  cat_pseudo_apology_avoidance_per_sqrt_wc +
  cat_cognitive_stalling_per_sqrt_wc +
  cat_communion_affective_simulation_per_sqrt_wc +
  cat_llm_self_reference_per_sqrt_wc

cognitive_institutional_abstraction =~
  cat_academic_abstraction_and_meta_per_sqrt_wc +
  cat_corp_mgmt_efficiency_per_sqrt_wc +
  cat_marketing_hype_exclusive_per_sqrt_wc +
  cat_technoscience_objects_per_sqrt_wc +
  cat_pharmaceutical_rigidity_per_sqrt_wc

expressive_syntactic_collapse =~
  short_sentence_ratio +
  cat_expressive_noise_rant_per_sqrt_wc +
  cat_machine_logic_per_sqrt_wc +
  funktionswort_dichte +
  cat_astylistic_soothing_per_sqrt_wc

dysregulated_defense_agency =~
  cat_ethics_social_justice_per_sqrt_wc +
  cat_assistant_compliance_refusal_per_sqrt_wc +
  cat_intensity_control_and_power_per_sqrt_wc +
  cat_psychological_dissolution_per_sqrt_wc +
  cat_emotive_agency_per_sqrt_wc +
  cat_moralizing_and_paternalistic_stance_per_sqrt_wc +
  cat_intensity_boundary_transgression_per_sqrt_wc
'

  lavaan::cfa(model_5f, data = efa_data, estimator = "MLR")
}

if (RUN_EFA_CFA) {
  require("lavaan", character.only = TRUE)
  require("semPlot", character.only = TRUE)

  efa_data <- X_scaled[, efa_features]
  fa_result_5 <- psych::fa(efa_data, nfactors = 5, fm = "ml", rotate = "oblimin")
  fit_5f <- run_cfa_5f(efa_data)

  print(fa_result_5, digits = 3)
  print(summary(fit_5f, fit.measures = TRUE, standardized = TRUE))

  if (EXPORT_FIGURES) {
    png("SEM_Figure_5F.png", width = 2400, height = 1800, res = 300)
    semPlot::semPaths(
      fit_5f,
      what = "std",
      layout = "tree",
      rotation = 2,
      style = "lisrel",
      sizeLat = 12,
      sizeMan = 7,
      edge.label.cex = 0.8,
      residuals = FALSE,
      intercepts = FALSE,
      exoCov = TRUE,
      mar = c(10, 10, 10, 10)
    )
    dev.off()
  }
}


# ---------------------------------------------------------------------------
# 9. Optional output tables
# ---------------------------------------------------------------------------

if (EXPORT_TABLES) {
  export_coverage_tables(analysis_data, output_dir = OUTPUT_DIR)
  export_pca_tables(pca_results, pca_var_table, output_dir = OUTPUT_DIR, top_n = 20)
  export_cluster_decision_tables(
    cluster_decision,
    stability_tables = stability_tables,
    output_dir = OUTPUT_DIR
  )
  export_cluster_tables(full_raw, pc_df = pc_df, output_dir = OUTPUT_DIR)
  export_manova_tables(res_manova, output_dir = OUTPUT_DIR)
}


# ---------------------------------------------------------------------------
# 10. Results bundle for interactive work
# ---------------------------------------------------------------------------

results <- list(
  full_raw = full_raw,
  cleaned = cleaned,
  pca_results = pca_results,
  pca_var_table = pca_var_table,
  pca_loadings_ranked = pca_loadings_ranked,
  km = km,
  cluster_decision = cluster_decision,
  stability_tables = stability_tables,
  pc_df = pc_df,
  manova = res_manova,
  interaction_plot = interaction_plot,
  pca_scores = pca_scores,
  example_pc_rank = example_pc_rank,
  dominant_pc_idx = dominant_pc_idx
)

message("Master Surface clean workflow finished. Inspect the `results` list for outputs.")







