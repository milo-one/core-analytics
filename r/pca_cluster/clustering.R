# silhouette
# WSS (Elbow)
# Gap-Statistik
# automatische K-Auswahl
# K-Means-Ausgabe

choose_and_cluster <- function(X_scaled, k_max = 10, seed = 123, show_plots = TRUE) {
  message("🔍 Bestimme optimale Clusterzahl...")
  
  set.seed(seed)
  
  # 1. Silhouette
  sil <- factoextra::fviz_nbclust(X_scaled, kmeans, method = "silhouette")
  sil_k <- as.numeric(sil$data$clusters[which.max(sil$data$y)])
  
  # 2. WSS (Elbow)
  wss <- factoextra::fviz_nbclust(X_scaled, kmeans, method = "wss")
  
  # 3. Gap Statistic
  gap <- cluster::clusGap(X_scaled, FUN = kmeans, K.max = k_max, B = 50)
  gap_k <- cluster::maxSE(gap$Tab[, "gap"], gap$Tab[, "SE.sim"], method = "firstSEmax")
  
  if (show_plots) {
    message("📊 Zeige Cluster-Diagnostik...")
    
    print(sil)     # ggplot → explicit
    print(wss)     # ggplot → explicit
    plot(gap)      # base R plot → always visible
  }
  
  message(paste0("📌 Silhouette-Empfehlung: k = ", sil_k))
  message(paste0("📌 Gap-Empfehlung: k = ", gap_k))
  message("📌 WSS: Bitte Elbow visuell prüfen.")
  
  return(list(
    silhouette_plot = sil,
    wss_plot = wss,
    gap = gap,
    recommended_silhouette = sil_k,
    recommended_gap = gap_k
  ))
}



run_kmeans <- function(X_scaled, k, seed = 123) {
  message(paste0("⚙️ Starte K-Means mit k = ", k))
  
  set.seed(seed)
  km <- kmeans(X_scaled, centers = k)
  
  message("✔️ K-Means abgeschlossen")
  
  return(km)
}




# 🔥 Schritt 1 — Scores + Cluster zusammenführen
build_pca_cluster_df <- function(pca_results, km, raw_data) {
  scores <- as.data.frame(pca_results$pca$x)
  scores$cluster <- factor(km$cluster)
  
  # direkt anhängen – ohne Sonderlogik
  if ("text_id" %in% names(raw_data)) {
    scores$text_id <- raw_data$text_id
  } else {
    stop("raw_data enthält keine text_id-Spalte.")
  }
  
  return(scores)
}





# 🔥 Schritt 2 — 3D-Plot (rgl, plotly oder ggplot2)
plot_pca_3d <- function(df) {
  
  k <- length(unique(df$cluster))
  pal <- RColorBrewer::brewer.pal(max(3, k), "Set2")
  
  plotly::plot_ly(
    data = df,
    x = ~PC1,
    y = ~PC2,
    z = ~PC3,
    type = "scatter3d",
    mode = "markers",
    color = ~cluster,
    colors = pal,
    marker = list(size = 4),
    text = ~paste(
      "text_id: ", text_id, "<br>",
      "Cluster: ", cluster, "<br>",
      "PC1: ", round(PC1, 4), "<br>",
      "PC2: ", round(PC2, 4), "<br>",
      "PC3: ", round(PC3, 4)
    ),
    hoverinfo = "text"
  )
}



# 🔥 A: Clusterprofile (mittelwertbasierte YAML × Cluster Karte)
compute_cluster_profiles <- function(pca_results, yaml_groups, full_raw) {
  
  # 1. PCA-Scores
  scores <- as.data.frame(pca_results$pca$x)
  
  # 2. Cluster anhängen
  if (!"cluster" %in% names(full_raw)) stop("cluster nicht im Datensatz.")
  scores$cluster <- full_raw$cluster
  
  # 3. Ladungen für YAML-Module holen
  rotation <- pca_results$pca$rotation
  abs_loadings <- abs(rotation)
  
  yaml_matrix <- sapply(yaml_groups, function(fset) {
    colMeans(abs_loadings[fset, , drop = FALSE])
  })
  yaml_matrix <- t(yaml_matrix)   # rows = YAML modules, cols = PCs
  
  # 4. Clusterzentren in PC-Space
  pc_means <- scores %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(across(starts_with("PC"), mean))
  
  # 5. YAML × Cluster Score
  #    Matrixmultiplikation: YAML × PC  %*%  PC × Cluster
  Y <- yaml_matrix
  C <- t(as.matrix(pc_means[, -1]))   # drop cluster label
  
  cluster_profiles <- Y %*% C
  
  colnames(cluster_profiles) <- paste0("cluster_", pc_means$cluster)
  
  return(cluster_profiles)
}


plot_cluster_profiles <- function(cluster_profiles) {
  
  max_val <- max(cluster_profiles, na.rm = TRUE)
  
  hm <- Heatmap(
    cluster_profiles,
    name = "Strength",
    col = circlize::colorRamp2(c(0, max_val), c("white", "darkred")),
    cluster_rows = TRUE,
    cluster_columns = TRUE,
    show_row_names = TRUE,
    show_column_names = TRUE,
    row_title = "YAML Modules",
    column_title = "Clusters"
  )
  
  draw(hm)
}



# 🔥 MANOVA auf PCs über Varianzfilter
run_manova_var <- function(pca_results,
                           full_raw,
                           group_var,
                           min_var = 0.0098) {
  
  # 1. Varianzanteile
  var_exp <- pca_results$pca$sdev^2 / sum(pca_results$pca$sdev^2)
  
  # 2. Auswahl: PCs ≥ min_var
  pcs_keep <- which(var_exp >= min_var)
  
  if (length(pcs_keep) < 2) {
    stop("Zu wenige PCs über der Varianzschwelle. Schwelle senken?")
  }
  
  message("📌 Verwende folgende PCs für die MANOVA: ",
          paste0("PC", pcs_keep, collapse = ", "))
  
  # 3. PCA-Scores extrahieren
  pc_df <- as.data.frame(pca_results$pca$x)[, pcs_keep, drop = FALSE]
  
  # 4. Gruppenvariable anhängen
  if (!group_var %in% names(full_raw)) {
    stop("❌ Gruppenvariable nicht im Datensatz gefunden.")
  }
  
  pc_df[[group_var]] <- full_raw[[group_var]]
  
  # 5. Multivariate MANOVA
  formula_manova <- as.formula(
    paste0("as.matrix(pc_df[, 1:", length(pcs_keep), 
           "]) ~ ", group_var)
  )
  
  fit <- manova(formula_manova, data = pc_df)
  
  # 6. Testausgabe
  multiv <- summary(fit, test = "Wilks")
  univ   <- summary.aov(fit)
  
  # 7. Effektstärken berechnen
  eff <- effectsize::eta_squared(lm(formula_manova, data = pc_df),
                                 partial = TRUE)
  
  list(
    pcs_used = pcs_keep,
    var_explained = var_exp[pcs_keep],
    multivariate = multiv,
    univariate = univ,
    effect_sizes = eff
  )
}




# Funktion Stabilitätstest
test_cluster_stability <- function(X, k, B = 1000) {
  set.seed(123)
  
  fpc::clusterboot(
    X,
    B = B,
    bootmethod = "boot",
    clustermethod = fpc::kmeansCBI,
    k = k,
    seed = 123,
    count = FALSE
  )
}


run_cluster_stability_grid <- function(X, k_values, B = 1000, seed = 123) {
  set.seed(seed)

  results <- lapply(k_values, function(k) {
    message("Teste Clusterstabilitaet fuer k = ", k)
    test_cluster_stability(X, k = k, B = B)
  })

  names(results) <- paste0("k", k_values)
  results
}


summarise_cluster_stability <- function(stability_grid) {
  rows <- lapply(names(stability_grid), function(name) {
    result <- stability_grid[[name]]
    bootmean <- result$bootmean

    data.frame(
      k = as.integer(sub("^k", "", name)),
      cluster = seq_along(bootmean),
      bootmean = bootmean,
      stringsAsFactors = FALSE
    )
  })

  stability_long <- dplyr::bind_rows(rows)

  stability_summary <- stability_long %>%
    dplyr::group_by(k) %>%
    dplyr::summarise(
      min_bootmean = min(bootmean, na.rm = TRUE),
      mean_bootmean = mean(bootmean, na.rm = TRUE),
      median_bootmean = stats::median(bootmean, na.rm = TRUE),
      unstable_clusters_lt_060 = sum(bootmean < 0.60, na.rm = TRUE),
      borderline_clusters_lt_075 = sum(bootmean < 0.75, na.rm = TRUE),
      .groups = "drop"
    )

  list(
    long = stability_long,
    summary = stability_summary
  )
}


make_cluster_decision_table <- function(
    selected_k,
    silhouette_k = NA_integer_,
    gap_k = NA_integer_,
    stability_summary = NULL,
    note = NULL
) {
  selected_stability <- NULL
  if (!is.null(stability_summary)) {
    selected_stability <- stability_summary[stability_summary$k == selected_k, , drop = FALSE]
  }

  data.frame(
    selected_k = selected_k,
    silhouette_recommendation = silhouette_k,
    gap_recommendation = gap_k,
    selected_min_bootmean = if (!is.null(selected_stability) && nrow(selected_stability) > 0) selected_stability$min_bootmean else NA_real_,
    selected_mean_bootmean = if (!is.null(selected_stability) && nrow(selected_stability) > 0) selected_stability$mean_bootmean else NA_real_,
    decision_note = if (is.null(note)) "" else note,
    stringsAsFactors = FALSE
  )
}











