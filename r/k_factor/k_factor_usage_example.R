# Example runner for the K-Factor axis.
#
# This file is intentionally tiny: keep project-specific paths here and keep
# k_factor_axis.R reusable for future package-style functions.

# 1) Reference texts define the author/person axis.
# Use either one features_full.csv with several rows or a folder that contains
# multiple features_full.csv files.
REFERENCE_FEATURE_FILE <- "C:/path/to/author_reference/features_full.csv"
# REFERENCE_FEATURE_FOLDER <- "C:/path/to/author_reference_folder"

# 2) Target texts are projected into the same PCA space and scored against
# the reference axis. Leave NULL to score the full baseline corpus.
TARGET_FEATURE_FILE <- "C:/path/to/new_texts/features_full.csv"

# 3) Optional: print a compact Zieltexte section for selected rows.
# If omitted, all target rows are still exported to k_factor_scores.csv.
TARGET_TEXT_IDS <- NULL

# 4) Keep the baseline corpus in the 3D plot as orientation context.
PLOT_CONTEXT_CORPUS <- TRUE

source(file.path(dirname(normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = TRUE)), "k_factor_axis.R"))






