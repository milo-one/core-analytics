# CoRE Analytics: confirmatory 5-factor SEM from strict EFA structure
#
# Purpose:
# - fit the interpretable strict 5F model directly
# - provide a stable CFA/SEM candidate independent of the exploratory EFA scan
# - export fit, loadings and model text
#
# Run from the repository root in RStudio:
#   source("sem_confirm_5f.R")

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
OUTPUT_DIR <- "tables/sem_confirm_5f"
SEED <- 123

load_required_packages <- function() {
  packages <- c("tidyverse", "lavaan")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]

  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "data_load.R"))
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

make_sem_data <- function(full_raw, model_features) {
  full_raw[, model_features, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0))) %>%
    scale() %>%
    as.data.frame()
}

summarise_lavaan_fit <- function(fit, model_name = "strict_5f_confirmatory") {
  measures <- lavaan::fitMeasures(
    fit,
    c("npar", "chisq", "df", "pvalue", "cfi", "tli", "rmsea", "srmr", "aic", "bic")
  )

  data.frame(
    model = model_name,
    measure = names(measures),
    value = as.numeric(measures),
    stringsAsFactors = FALSE
  )
}

load_required_packages()
source_project_files()
set.seed(SEED)

model_5f <- '
semantic_somatic_intensity =~
  semantic_breadth_abs +
  type_token_ratio +
  cat_intensity_affective_overload_per_sqrt_wc +
  cat_intensity_bodily_arousal_per_sqrt_wc +
  cat_somatic_load_per_sqrt_wc

assistant_collapse_servility =~
  cat_assistant_identity_collapse_per_sqrt_wc +
  apology_density +
  cat_dysf_recursion_or_collapse_per_sqrt_wc +
  cat_assistant_servile_politeness_per_sqrt_wc

authority_system_control =~
  cat_authority_interventionist_per_sqrt_wc +
  cat_authority_structural_per_sqrt_wc +
  cat_system_control_expression_per_sqrt_wc +
  cat_framing_cybernetic_structural_per_sqrt_wc +
  cat_communion_power_and_control_per_sqrt_wc

lexical_syntactic_compression =~
  avg_word_length +
  adjektiv_dichte +
  verb_dichte +
  funktionswort_dichte

religious_doctrinal_discourse =~
  cat_discourse_religious_institutional_per_sqrt_wc +
  cat_discourse_ritual_law_per_sqrt_wc +
  register_dissonance +
  cat_discourse_spiritual_transcendent_per_sqrt_wc
'

model_features <- unique(unlist(regmatches(
  model_5f,
  gregexpr("[A-Za-z][A-Za-z0-9_]*", model_5f)
)))
latent_names <- c(
  "semantic_somatic_intensity",
  "assistant_collapse_servility",
  "authority_system_control",
  "lexical_syntactic_compression",
  "religious_doctrinal_discourse"
)
model_features <- setdiff(model_features, c(latent_names))

full_raw <- load_data(DATA_ROOT)
missing_features <- setdiff(model_features, names(full_raw))
if (length(missing_features) > 0) {
  stop("Model features missing from data: ", paste(missing_features, collapse = ", "))
}

sem_data <- make_sem_data(full_raw, model_features)
output_dir <- ensure_output_dir(OUTPUT_DIR)
writeLines(model_5f, file.path(output_dir, "strict_5f_lavaan_model.txt"))

fit_5f <- lavaan::cfa(
  model_5f,
  data = sem_data,
  estimator = "MLR",
  std.lv = TRUE,
  missing = "fiml"
)

fit_table <- summarise_lavaan_fit(fit_5f)
write_table_csv(fit_table, "sem_fit_measures.csv", output_dir = OUTPUT_DIR)

loadings <- lavaan::parameterEstimates(fit_5f, standardized = TRUE) %>%
  dplyr::filter(op == "=~") %>%
  dplyr::arrange(lhs, dplyr::desc(abs(std.all)))
write_table_csv(loadings, "sem_standardized_loadings.csv", output_dir = OUTPUT_DIR)

factor_covariances <- lavaan::parameterEstimates(fit_5f, standardized = TRUE) %>%
  dplyr::filter(op == "~~", lhs != rhs) %>%
  dplyr::arrange(dplyr::desc(abs(std.all)))
write_table_csv(factor_covariances, "sem_factor_covariances.csv", output_dir = OUTPUT_DIR)

print(fit_table)

sem_confirm_5f_results <- list(
  model = model_5f,
  data = sem_data,
  fit = fit_5f,
  fit_table = fit_table,
  loadings = loadings,
  factor_covariances = factor_covariances
)


library(semPlot)

png(
  "tables/sem_confirm_5f/figures/sem_5f_path_diagram_spring_final.png",
  width = 6200,
  height = 3500,
  res = 400
)

semPaths(
  sem_confirm_5f_results$fit,
  what = "std",
  whatLabels = "std",
  style = "ram",
  layout = "spring",
  nodeLabels = c(
    "sem_breadth", "ttr", "aff_overload", "body_arousal", "somatic_load",
    "id_collapse", "apology", "recursion", "servility",
    "auth_interv", "auth_struct", "sys_control", "cyber_frame", "power_ctrl",
    "word_len", "adj_density", "verb_density", "func_density",
    "relig_inst", "ritual_law", "reg_disson", "spiritual",
    "Sem_Somatic", "Assistant_Collapse", "Authority_Control",
    "LexSyn_Compress", "Rel_Doctrine"
  ),
  residuals = FALSE,
  intercepts = FALSE,
  exoCov = TRUE,
  curve = 3,
  edge.label.cex = 0.6,
  edge.label.position = 0.35,
  sizeLat = 9,
  sizeMan = 5,
  nCharNodes = 4,
  label.cex = 1.1,
  mar = c(1, 1, 1, 1)
)


# besonders diese Paramter anpassen:
# edge.label.cex = 0.55
# sizeLat = 8
# sizeMan = 4
# mar = c(4, 4, 4, 4)

dev.off()





