# CoRE Analytics: standalone EFA and SEM workflow
#
# Purpose:
# - run only EFA/CFA/SEM, without clustering, heatmaps or MANOVA
# - reduce the candidate feature set before SEM
# - export decision tables for factor count, item retention and SEM fit
#
# Run from the repository root in RStudio:
#   source("efa_sem.R")

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------

PROJECT_DIR <- if (exists("PROJECT_DIR")) PROJECT_DIR else normalizePath(".", winslash = "/", mustWork = TRUE)
DATA_ROOT <- if (exists("DATA_ROOT")) DATA_ROOT else file.path(PROJECT_DIR, "out")
OUTPUT_DIR <- if (exists("OUTPUT_DIR")) OUTPUT_DIR else "tables/efa_sem"
SEED <- if (exists("SEED")) SEED else 123

# Feature source:
# - "all_numeric": start from all numeric non-PC/non-cluster variables
# - "curated": start from CURATED_EFA_FEATURES below
FEATURE_SOURCE <- if (exists("FEATURE_SOURCE")) FEATURE_SOURCE else "all_numeric"
EXCLUDE_FEATURES <- if (exists("EXCLUDE_FEATURES")) EXCLUDE_FEATURES else character(0)

# First-stage feature filters
MIN_COVERAGE_PERCENT <- if (exists("MIN_COVERAGE_PERCENT")) MIN_COVERAGE_PERCENT else 2
MAX_ZERO_OR_NA_PERCENT <- if (exists("MAX_ZERO_OR_NA_PERCENT")) MAX_ZERO_OR_NA_PERCENT else 98
MIN_VARIANCE <- if (exists("MIN_VARIANCE")) MIN_VARIANCE else 1e-8
MAX_ABS_CORRELATION <- if (exists("MAX_ABS_CORRELATION")) MAX_ABS_CORRELATION else 0.92
MIN_OVERALL_KMO <- if (exists("MIN_OVERALL_KMO")) MIN_OVERALL_KMO else 0.60
MIN_ITEM_MSA <- if (exists("MIN_ITEM_MSA")) MIN_ITEM_MSA else 0.50

# EFA scan and retention thresholds
FACTOR_SCAN_RANGE <- if (exists("FACTOR_SCAN_RANGE")) FACTOR_SCAN_RANGE else 2:12
EFA_FM <- if (exists("EFA_FM")) EFA_FM else "ml"
EFA_ROTATE <- if (exists("EFA_ROTATE")) EFA_ROTATE else "oblimin"
MIN_PRIMARY_LOADING <- if (exists("MIN_PRIMARY_LOADING")) MIN_PRIMARY_LOADING else 0.35
MAX_SECONDARY_LOADING <- if (exists("MAX_SECONDARY_LOADING")) MAX_SECONDARY_LOADING else 0.25
MIN_COMMUNALITY <- if (exists("MIN_COMMUNALITY")) MIN_COMMUNALITY else 0.20
MIN_ITEMS_PER_FACTOR <- if (exists("MIN_ITEMS_PER_FACTOR")) MIN_ITEMS_PER_FACTOR else 3
MAX_ITEMS_PER_FACTOR <- if (exists("MAX_ITEMS_PER_FACTOR")) MAX_ITEMS_PER_FACTOR else 6
PREFERRED_FACTORS <- if (exists("PREFERRED_FACTORS")) PREFERRED_FACTORS else NA

# SEM/CFA options
RUN_SEM <- if (exists("RUN_SEM")) RUN_SEM else TRUE
EXPORT_SEM_FIGURE <- if (exists("EXPORT_SEM_FIGURE")) EXPORT_SEM_FIGURE else FALSE
SEM_ESTIMATOR <- if (exists("SEM_ESTIMATOR")) SEM_ESTIMATOR else "MLR"


# ---------------------------------------------------------------------------
# 1. Setup
# ---------------------------------------------------------------------------

load_required_packages <- function() {
  packages <- c("tidyverse", "psych", "lavaan")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]

  if (length(missing) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing, collapse = ", "),
      ". Install them in RStudio first, then rerun this script."
    )
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "data_load.R"))
  source(file.path(project_dir, "r", "core", "data_clean.R"))
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

safe_write_csv <- function(df, filename, output_dir = OUTPUT_DIR) {
  write_table_csv(df, filename, output_dir = output_dir)
}

load_required_packages()
source_project_files()
set.seed(SEED)


# ---------------------------------------------------------------------------
# 2. Candidate features
# ---------------------------------------------------------------------------

CURATED_EFA_FEATURES <- c(
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

remove_old_analysis_columns <- function(df) {
  old_cols <- c(paste0("PC", 1:300), "cluster")
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

get_numeric_candidates <- function(full_raw, feature_source = FEATURE_SOURCE) {
  numeric_cols <- names(full_raw)[vapply(full_raw, is.numeric, logical(1))]
  numeric_cols <- setdiff(numeric_cols, c(paste0("PC", 1:300), "cluster"))
  numeric_cols <- setdiff(numeric_cols, EXCLUDE_FEATURES)

  if (feature_source == "curated") {
    missing <- setdiff(CURATED_EFA_FEATURES, numeric_cols)
    if (length(missing) > 0) {
      message("Curated features not found and ignored: ", paste(missing, collapse = ", "))
    }
    return(intersect(CURATED_EFA_FEATURES, numeric_cols))
  }

  numeric_cols
}

summarise_feature_quality <- function(df, features) {
  rows <- lapply(features, function(feature) {
    x <- suppressWarnings(as.numeric(df[[feature]]))
    non_missing <- !is.na(x)
    positive <- x > 0

    data.frame(
      feature = feature,
      coverage_percent = mean(positive, na.rm = TRUE) * 100,
      zero_or_na_percent = mean(is.na(x) | x == 0) * 100,
      variance = stats::var(x, na.rm = TRUE),
      mean = mean(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      n_non_missing = sum(non_missing),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows)
}

filter_by_basic_quality <- function(feature_quality) {
  feature_quality %>%
    dplyr::mutate(
      keep_basic = coverage_percent >= MIN_COVERAGE_PERCENT &
        zero_or_na_percent <= MAX_ZERO_OR_NA_PERCENT &
        variance > MIN_VARIANCE
    )
}

drop_correlated_features <- function(x, max_abs_correlation = MAX_ABS_CORRELATION) {
  if (ncol(x) < 2) {
    return(list(data = x, dropped = data.frame()))
  }

  cor_mat <- stats::cor(x, use = "pairwise.complete.obs")
  cor_mat[is.na(cor_mat)] <- 0
  diag(cor_mat) <- 0

  dropped <- character(0)
  decisions <- list()

  repeat {
    abs_cor <- abs(cor_mat)
    max_val <- max(abs_cor, na.rm = TRUE)

    if (!is.finite(max_val) || max_val < max_abs_correlation) {
      break
    }

    hit <- which(abs_cor == max_val, arr.ind = TRUE)[1, ]
    a <- rownames(cor_mat)[hit[1]]
    b <- colnames(cor_mat)[hit[2]]

    mean_abs_a <- mean(abs_cor[a, ], na.rm = TRUE)
    mean_abs_b <- mean(abs_cor[b, ], na.rm = TRUE)
    drop <- if (mean_abs_a >= mean_abs_b) a else b
    keep <- if (drop == a) b else a

    dropped <- c(dropped, drop)
    decisions[[length(decisions) + 1]] <- data.frame(
      dropped_feature = drop,
      retained_feature = keep,
      abs_correlation = max_val,
      dropped_mean_abs_correlation = if (drop == a) mean_abs_a else mean_abs_b,
      retained_mean_abs_correlation = if (drop == a) mean_abs_b else mean_abs_a,
      stringsAsFactors = FALSE
    )

    cor_mat <- cor_mat[setdiff(rownames(cor_mat), drop), setdiff(colnames(cor_mat), drop), drop = FALSE]
  }

  list(
    data = x[, setdiff(colnames(x), dropped), drop = FALSE],
    dropped = if (length(decisions) > 0) dplyr::bind_rows(decisions) else data.frame()
  )
}

filter_by_kmo <- function(x) {
  if (ncol(x) < 3) {
    return(list(data = x, kmo = NULL, item_msa = data.frame()))
  }

  current <- x
  dropped <- list()

  repeat {
    kmo <- psych::KMO(stats::cor(current, use = "pairwise.complete.obs"))
    item_msa <- sort(kmo$MSAi)
    low <- names(item_msa[item_msa < MIN_ITEM_MSA])

    if (length(low) == 0 || ncol(current) <= MIN_ITEMS_PER_FACTOR * 2) {
      break
    }

    drop <- low[1]
    dropped[[length(dropped) + 1]] <- data.frame(
      feature = drop,
      reason = "low_item_msa",
      item_msa = item_msa[drop],
      overall_kmo = kmo$MSA,
      stringsAsFactors = FALSE
    )
    current <- current[, setdiff(colnames(current), drop), drop = FALSE]
  }

  final_kmo <- if (ncol(current) >= 3) psych::KMO(stats::cor(current, use = "pairwise.complete.obs")) else NULL
  final_item_msa <- if (!is.null(final_kmo)) {
    data.frame(
      feature = names(final_kmo$MSAi),
      item_msa = as.numeric(final_kmo$MSAi),
      overall_kmo = final_kmo$MSA,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame()
  }

  list(
    data = current,
    kmo = final_kmo,
    item_msa = final_item_msa,
    dropped = if (length(dropped) > 0) dplyr::bind_rows(dropped) else data.frame()
  )
}

prepare_efa_matrix <- function(full_raw) {
  excluded_present <- intersect(EXCLUDE_FEATURES, names(full_raw))
  safe_write_csv(
    data.frame(feature = excluded_present, reason = "configured_exclusion"),
    "efa_configured_exclusions.csv"
  )

  features <- get_numeric_candidates(full_raw)
  quality <- summarise_feature_quality(full_raw, features)
  quality <- filter_by_basic_quality(quality)
  safe_write_csv(quality, "efa_feature_quality.csv")

  kept_basic <- quality$feature[quality$keep_basic]
  message("Features after basic quality filter: ", length(kept_basic), " / ", length(features))

  x_raw <- full_raw[, kept_basic, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  x_scaled <- scale(x_raw)
  x_scaled <- as.data.frame(x_scaled)

  cor_filtered <- drop_correlated_features(x_scaled)
  safe_write_csv(cor_filtered$dropped, "efa_dropped_high_correlation.csv")
  message("Features after correlation filter: ", ncol(cor_filtered$data))

  kmo_filtered <- filter_by_kmo(cor_filtered$data)
  safe_write_csv(kmo_filtered$item_msa, "efa_item_msa.csv")
  safe_write_csv(kmo_filtered$dropped, "efa_dropped_low_msa.csv")

  if (!is.null(kmo_filtered$kmo)) {
    message("Final overall KMO: ", round(kmo_filtered$kmo$MSA, 3))
    if (kmo_filtered$kmo$MSA < MIN_OVERALL_KMO) {
      warning("Overall KMO is below ", MIN_OVERALL_KMO, ". Treat EFA results cautiously.")
    }
  }

  list(
    data = kmo_filtered$data,
    quality = quality,
    dropped_correlation = cor_filtered$dropped,
    item_msa = kmo_filtered$item_msa,
    dropped_msa = kmo_filtered$dropped
  )
}


# ---------------------------------------------------------------------------
# 3. EFA scan
# ---------------------------------------------------------------------------

fit_efa_safe <- function(x, nfactors) {
  tryCatch(
    suppressWarnings(psych::fa(x, nfactors = nfactors, fm = EFA_FM, rotate = EFA_ROTATE)),
    error = function(e) e
  )
}

summarise_efa_fit <- function(fit, nfactors) {
  if (inherits(fit, "error")) {
    return(data.frame(
      factors = nfactors,
      converged = FALSE,
      tli = NA_real_,
      rmsea = NA_real_,
      srmr = NA_real_,
      bic = NA_real_,
      complexity = NA_real_,
      crossloadings = NA_integer_,
      low_h2 = NA_integer_,
      retained_items = NA_integer_,
      min_items_per_factor = NA_integer_,
      error = fit$message,
      stringsAsFactors = FALSE
    ))
  }

  loadings <- as.data.frame(unclass(fit$loadings))
  abs_loadings <- abs(as.matrix(loadings))
  primary <- apply(abs_loadings, 1, max)
  secondary <- apply(abs_loadings, 1, function(row) {
    sorted <- sort(row, decreasing = TRUE)
    if (length(sorted) < 2) 0 else sorted[2]
  })
  max_factor <- colnames(abs_loadings)[apply(abs_loadings, 1, which.max)]
  clean_item <- primary >= MIN_PRIMARY_LOADING &
    secondary <= MAX_SECONDARY_LOADING &
    fit$communality >= MIN_COMMUNALITY
  items_per_factor <- table(factor(max_factor[clean_item], levels = colnames(abs_loadings)))

  data.frame(
    factors = nfactors,
    converged = isTRUE(fit$converged),
    tli = fit$TLI,
    rmsea = fit$RMSEA[1],
    srmr = fit$rms,
    bic = fit$BIC,
    complexity = mean(fit$complexity, na.rm = TRUE),
    crossloadings = sum(apply(abs_loadings, 1, function(row) sum(row > MIN_PRIMARY_LOADING) > 1)),
    low_h2 = sum(fit$communality < MIN_COMMUNALITY, na.rm = TRUE),
    retained_items = sum(clean_item),
    min_items_per_factor = min(items_per_factor),
    error = "",
    stringsAsFactors = FALSE
  )
}

scan_efa_factor_counts <- function(x, scan_range = FACTOR_SCAN_RANGE) {
  fits <- lapply(scan_range, function(k) {
    message("Fitting EFA with ", k, " factors")
    fit_efa_safe(x, k)
  })
  names(fits) <- paste0("F", scan_range)

  scan <- dplyr::bind_rows(Map(summarise_efa_fit, fits, scan_range))
  safe_write_csv(scan, "efa_factor_scan.csv")

  list(fits = fits, scan = scan)
}

choose_factor_count <- function(scan) {
  usable <- scan %>%
    dplyr::filter(
      !is.na(rmsea),
      retained_items >= MIN_ITEMS_PER_FACTOR * factors,
      min_items_per_factor >= MIN_ITEMS_PER_FACTOR
    )

  if (!is.na(PREFERRED_FACTORS) && PREFERRED_FACTORS %in% usable$factors) {
    return(PREFERRED_FACTORS)
  }

  if (nrow(usable) == 0) {
    warning("No factor count passed strict item-retention rules. Falling back to best RMSEA among converged fits.")
    fallback <- scan %>% dplyr::filter(!is.na(rmsea)) %>% dplyr::arrange(rmsea, bic)
    return(fallback$factors[1])
  }

  usable %>%
    dplyr::mutate(
      score = dplyr::min_rank(rmsea) +
        dplyr::min_rank(bic) +
        dplyr::min_rank(complexity) +
        dplyr::min_rank(crossloadings) +
        dplyr::min_rank(low_h2)
    ) %>%
    dplyr::arrange(score, factors) %>%
    dplyr::pull(factors) %>%
    .[1]
}

extract_loading_table <- function(fit) {
  loadings <- as.data.frame(unclass(fit$loadings))
  loadings$feature <- rownames(loadings)
  loadings <- loadings %>% dplyr::relocate(feature)

  abs_loadings <- abs(as.matrix(loadings[, setdiff(names(loadings), "feature"), drop = FALSE]))
  primary_idx <- apply(abs_loadings, 1, which.max)
  primary_factor <- colnames(abs_loadings)[primary_idx]
  primary_loading <- as.matrix(loadings[, colnames(abs_loadings), drop = FALSE])[
    cbind(seq_len(nrow(loadings)), primary_idx)
  ]
  secondary_loading <- apply(abs_loadings, 1, function(row) {
    sorted <- sort(row, decreasing = TRUE)
    if (length(sorted) < 2) 0 else sorted[2]
  })

  loadings %>%
    dplyr::mutate(
      primary_factor = primary_factor,
      primary_loading = primary_loading,
      abs_primary_loading = abs(primary_loading),
      secondary_abs_loading = secondary_loading,
      communality = fit$communality,
      uniqueness = fit$uniquenesses,
      keep_for_sem = abs_primary_loading >= MIN_PRIMARY_LOADING &
        secondary_abs_loading <= MAX_SECONDARY_LOADING &
        communality >= MIN_COMMUNALITY
    ) %>%
    dplyr::arrange(primary_factor, dplyr::desc(abs_primary_loading))
}

select_sem_items <- function(loadings_table) {
  candidates <- loadings_table %>%
    dplyr::filter(keep_for_sem) %>%
    dplyr::arrange(primary_factor, dplyr::desc(abs_primary_loading))

  candidates %>%
    dplyr::group_by(primary_factor) %>%
    dplyr::slice_head(n = MAX_ITEMS_PER_FACTOR) %>%
    dplyr::mutate(items_in_factor = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::filter(items_in_factor >= MIN_ITEMS_PER_FACTOR)
}


# ---------------------------------------------------------------------------
# 4. SEM / CFA from retained EFA structure
# ---------------------------------------------------------------------------

make_lavaan_model <- function(sem_items) {
  model_lines <- sem_items %>%
    dplyr::group_by(primary_factor) %>%
    dplyr::summarise(
      line = paste0(
        dplyr::first(primary_factor),
        " =~ ",
        paste(feature, collapse = " + ")
      ),
      .groups = "drop"
    ) %>%
    dplyr::pull(line)

  paste(model_lines, collapse = "\n")
}

summarise_lavaan_fit <- function(fit, model_name = "efa_derived_sem") {
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

fit_sem_from_efa <- function(x, sem_items) {
  model <- make_lavaan_model(sem_items)
  writeLines(model, file.path(ensure_output_dir(OUTPUT_DIR), "efa_derived_lavaan_model.txt"))

  fit <- lavaan::cfa(
    model,
    data = x[, unique(sem_items$feature), drop = FALSE],
    estimator = SEM_ESTIMATOR,
    std.lv = TRUE,
    missing = "fiml"
  )

  fit_table <- summarise_lavaan_fit(fit)
  safe_write_csv(fit_table, "sem_fit_measures.csv")

  parameters <- lavaan::parameterEstimates(fit, standardized = TRUE) %>%
    dplyr::filter(op == "=~") %>%
    dplyr::arrange(lhs, dplyr::desc(abs(std.all)))
  safe_write_csv(parameters, "sem_standardized_loadings.csv")

  if (EXPORT_SEM_FIGURE) {
    if (!require("semPlot", character.only = TRUE)) {
      warning("semPlot is not installed; skipping SEM figure export.")
    } else {
      grDevices::png(
        file.path(ensure_output_dir(OUTPUT_DIR), "SEM_EFA_Derived.png"),
        width = 2600,
        height = 1800,
        res = 300
      )
      semPlot::semPaths(
        fit,
        what = "std",
        layout = "tree",
        rotation = 2,
        style = "lisrel",
        residuals = FALSE,
        intercepts = FALSE,
        exoCov = TRUE,
        edge.label.cex = 0.7,
        sizeLat = 10,
        sizeMan = 5,
        nCharNodes = 0,
        mar = c(8, 8, 8, 8)
      )
      grDevices::dev.off()
    }
  }

  list(model = model, fit = fit, fit_table = fit_table, parameters = parameters)
}


# ---------------------------------------------------------------------------
# 5. Run workflow
# ---------------------------------------------------------------------------

message("Loading data from: ", DATA_ROOT)
full_raw <- load_data(DATA_ROOT)
full_raw <- remove_old_analysis_columns(full_raw)

efa_prepared <- prepare_efa_matrix(full_raw)
efa_matrix <- efa_prepared$data
safe_write_csv(data.frame(feature = colnames(efa_matrix)), "efa_retained_feature_list.csv")

message("Final EFA matrix: ", nrow(efa_matrix), " rows x ", ncol(efa_matrix), " features")

efa_scan <- scan_efa_factor_counts(efa_matrix)
selected_factors <- choose_factor_count(efa_scan$scan)
message("Selected factor count: ", selected_factors)

selected_fit <- efa_scan$fits[[paste0("F", selected_factors)]]
loadings_table <- extract_loading_table(selected_fit)
safe_write_csv(loadings_table, paste0("efa_loadings_F", selected_factors, ".csv"))

sem_items <- select_sem_items(loadings_table)
safe_write_csv(sem_items, "efa_sem_items.csv")

factor_item_counts <- sem_items %>%
  dplyr::count(primary_factor, name = "n_items") %>%
  dplyr::arrange(primary_factor)
safe_write_csv(factor_item_counts, "efa_sem_factor_item_counts.csv")

if (RUN_SEM && nrow(factor_item_counts) >= 2) {
  sem_results <- fit_sem_from_efa(efa_matrix, sem_items)
  print(sem_results$fit_table)
} else {
  sem_results <- NULL
  warning("SEM skipped: fewer than two retained factors or RUN_SEM is FALSE.")
}

efa_sem_results <- list(
  prepared = efa_prepared,
  matrix = efa_matrix,
  scan = efa_scan,
  selected_factors = selected_factors,
  selected_fit = selected_fit,
  loadings = loadings_table,
  sem_items = sem_items,
  sem = sem_results
)

message("EFA/SEM workflow complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





