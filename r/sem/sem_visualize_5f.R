# CoRE Analytics: visualise confirmatory 5F SEM
#
# Run from the repository root in RStudio:
#   source("sem_visualize_5f.R")
#
# Inputs:
# - tables/sem_confirm_5f/sem_standardized_loadings.csv
# - tables/sem_confirm_5f/sem_factor_covariances.csv
# - sem_confirm_5f.R for optional semPlot path diagram

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
SEM_OUTPUT_DIR <- "tables/sem_confirm_5f"
FIGURE_DIR <- file.path(SEM_OUTPUT_DIR, "figures")

if (!dir.exists(FIGURE_DIR)) {
  dir.create(FIGURE_DIR, recursive = TRUE)
}

load_required_packages <- function() {
  packages <- c("tidyverse", "ggplot2")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]

  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

load_required_packages()

pretty_factor_labels <- c(
  semantic_somatic_intensity = "Semantic-somatic\nintensity",
  assistant_collapse_servility = "Assistant collapse\n& servility",
  authority_system_control = "Authority &\nsystem control",
  lexical_syntactic_compression = "Lexical-syntactic\ncompression",
  religious_doctrinal_discourse = "Religious-doctrinal\ndiscourse"
)

sem_path_node_labels <- c(
  # Indicators: semantic_somatic_intensity
  "sem_breadth",
  "ttr",
  "aff_overload",
  "body_arousal",
  "somatic_load",

  # Indicators: assistant_collapse_servility
  "id_collapse",
  "apology",
  "recursion",
  "servility",

  # Indicators: authority_system_control
  "auth_interv",
  "auth_struct",
  "sys_control",
  "cyber_frame",
  "power_ctrl",

  # Indicators: lexical_syntactic_compression
  "word_len",
  "adj_density",
  "verb_density",
  "func_density",

  # Indicators: religious_doctrinal_discourse
  "relig_inst",
  "ritual_law",
  "reg_disson",
  "spiritual",

  # Latent factors
  "Sem_Somatic",
  "Assistant_Collapse",
  "Authority_Control",
  "LexSyn_Compress",
  "Rel_Doctrine"
)

pretty_item_label <- function(x) {
  x %>%
    stringr::str_remove("^cat_") %>%
    stringr::str_remove("_per_sqrt_wc$") %>%
    stringr::str_replace_all("_", " ") %>%
    stringr::str_replace("^avg word length$", "avg word length") %>%
    stringr::str_replace("^type token ratio$", "type-token ratio") %>%
    stringr::str_replace("^adjektiv dichte$", "adjective density") %>%
    stringr::str_replace("^verb dichte$", "verb density") %>%
    stringr::str_replace("^funktionswort dichte$", "function-word density")
}

loadings_path <- file.path(SEM_OUTPUT_DIR, "sem_standardized_loadings.csv")
covariances_path <- file.path(SEM_OUTPUT_DIR, "sem_factor_covariances.csv")

loadings <- readr::read_csv(loadings_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    factor_label = dplyr::recode(lhs, !!!pretty_factor_labels),
    item_label = pretty_item_label(rhs),
    loading = std.all,
    abs_loading = abs(std.all)
  )

covariances <- readr::read_csv(covariances_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    lhs_label = dplyr::recode(lhs, !!!pretty_factor_labels),
    rhs_label = dplyr::recode(rhs, !!!pretty_factor_labels),
    covariance = std.all
  )


# ---------------------------------------------------------------------------
# 1. Standardized loading plot
# ---------------------------------------------------------------------------

loading_plot <- loadings %>%
  dplyr::mutate(
    item_label = forcats::fct_reorder(item_label, loading),
    factor_label = factor(factor_label, levels = pretty_factor_labels)
  ) %>%
  ggplot2::ggplot(ggplot2::aes(x = loading, y = item_label, fill = loading > 0)) +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.4, color = "grey35") +
  ggplot2::geom_col(width = 0.72) +
  ggplot2::facet_wrap(~ factor_label, scales = "free_y", ncol = 1) +
  ggplot2::scale_fill_manual(values = c("TRUE" = "#2f6f73", "FALSE" = "#9a4d4d"), guide = "none") +
  ggplot2::scale_x_continuous(limits = c(-1, 1), breaks = seq(-1, 1, 0.5)) +
  ggplot2::labs(
    title = "Confirmatory 5F SEM: standardized factor loadings",
    x = "Standardized loading",
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 15),
    strip.text = ggplot2::element_text(face = "bold", size = 11),
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank()
  )

ggplot2::ggsave(
  file.path(FIGURE_DIR, "sem_5f_standardized_loadings.png"),
  loading_plot,
  width = 9,
  height = 12,
  dpi = 300
)


# ---------------------------------------------------------------------------
# 2. Factor covariance heatmap
# ---------------------------------------------------------------------------

factor_names <- names(pretty_factor_labels)
factor_labels <- unname(pretty_factor_labels)

cov_matrix <- diag(1, length(factor_names))
rownames(cov_matrix) <- factor_labels
colnames(cov_matrix) <- factor_labels

for (i in seq_len(nrow(covariances))) {
  lhs <- pretty_factor_labels[covariances$lhs[i]]
  rhs <- pretty_factor_labels[covariances$rhs[i]]
  cov_matrix[lhs, rhs] <- covariances$covariance[i]
  cov_matrix[rhs, lhs] <- covariances$covariance[i]
}

cov_long <- as.data.frame(as.table(cov_matrix)) %>%
  dplyr::rename(factor_a = Var1, factor_b = Var2, covariance = Freq)

cov_plot <- cov_long %>%
  ggplot2::ggplot(ggplot2::aes(x = factor_a, y = factor_b, fill = covariance)) +
  ggplot2::geom_tile(color = "white", linewidth = 0.7) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", covariance)), size = 3.5) +
  ggplot2::scale_fill_gradient2(
    low = "#9a4d4d",
    mid = "white",
    high = "#2f6f73",
    midpoint = 0,
    limits = c(-1, 1),
    name = "Std. covariance"
  ) +
  ggplot2::coord_fixed() +
  ggplot2::labs(
    title = "Confirmatory 5F SEM: latent factor covariances",
    x = NULL,
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 15),
    axis.text.x = ggplot2::element_text(angle = 35, hjust = 1),
    panel.grid = ggplot2::element_blank()
  )

ggplot2::ggsave(
  file.path(FIGURE_DIR, "sem_5f_factor_covariances.png"),
  cov_plot,
  width = 9,
  height = 7,
  dpi = 300
)


# ---------------------------------------------------------------------------
# 3. SEM path diagram via semPlot, if available
# ---------------------------------------------------------------------------

if (require("semPlot", character.only = TRUE)) {
  source(file.path(PROJECT_DIR, "r", "sem", "sem_confirm_5f.R"))

  grDevices::png(
    file.path(FIGURE_DIR, "sem_5f_path_diagram.png"),
    width = 3200,
    height = 2200,
    res = 300
  )

  semPlot::semPaths(
    sem_confirm_5f_results$fit,
    what = "std",
    whatLabels = "std",
    style = "lisrel",
    layout = "tree2",
    nodeLabels = sem_path_node_labels,
    rotation = 2,
    residuals = FALSE,
    intercepts = FALSE,
    exoCov = TRUE,
    edge.label.cex = 0.65,
    sizeLat = 9,
    sizeMan = 4.8,
    nCharNodes = 0,
    mar = c(8, 8, 8, 8)
  )

  grDevices::dev.off()

  grDevices::png(
    file.path(FIGURE_DIR, "sem_5f_path_diagram_spring.png"),
    width = 3200,
    height = 2200,
    res = 300
  )

  semPlot::semPaths(
    sem_confirm_5f_results$fit,
    what = "std",
    whatLabels = "std",
    style = "ram",
    layout = "spring",
    nodeLabels = sem_path_node_labels,
    residuals = FALSE,
    intercepts = FALSE,
    exoCov = TRUE,
    curve = 2,
    edge.label.cex = 0.65,
    sizeLat = 9,
    sizeMan = 4.8,
    nCharNodes = 0,
    mar = c(8, 8, 8, 8)
  )

  grDevices::dev.off()
} else {
  warning("semPlot is not installed; skipping sem_5f_path_diagram.png")
}

message("SEM figures written to: ", normalizePath(FIGURE_DIR, winslash = "/", mustWork = TRUE))





