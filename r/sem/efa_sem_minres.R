# CoRE Analytics: strict EFA/SEM robustness check with MINRES
#
# Run from the repository root in RStudio:
#   source("efa_sem_minres.R")
#
# This mirrors `efa_sem_strict.R`, but uses MINRES extraction. It is intended
# as a robustness check because the ML EFA scan did not report convergence.

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
OUTPUT_DIR <- "tables/efa_sem_minres"
SEED <- 123

FEATURE_SOURCE <- "all_numeric"

EXCLUDE_FEATURES <- c(
  "cat_academic_abstraction_and_meta_per_sqrt_wc",
  "cat_llm_mechanical_reflexes_per_sqrt_wc",
  "cat_ethics_social_justice_per_sqrt_wc"
)

MIN_COVERAGE_PERCENT <- 2
MAX_ZERO_OR_NA_PERCENT <- 98
MIN_VARIANCE <- 1e-8
MAX_ABS_CORRELATION <- 0.90
MIN_OVERALL_KMO <- 0.60
MIN_ITEM_MSA <- 0.55

FACTOR_SCAN_RANGE <- 2:10
EFA_FM <- "minres"
EFA_ROTATE <- "oblimin"
MIN_PRIMARY_LOADING <- 0.40
MAX_SECONDARY_LOADING <- 0.20
MIN_COMMUNALITY <- 0.25
MIN_ITEMS_PER_FACTOR <- 3
MAX_ITEMS_PER_FACTOR <- 5
PREFERRED_FACTORS <- NA

RUN_SEM <- TRUE
EXPORT_SEM_FIGURE <- FALSE
SEM_ESTIMATOR <- "MLR"

source(file.path(PROJECT_DIR, "r", "sem", "efa_sem.R"))





