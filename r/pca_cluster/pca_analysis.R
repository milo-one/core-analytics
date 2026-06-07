run_pca <- function(X_scaled, n_top = 20, n_components = NULL) {
  message("🧭 Starte PCA...")
  
  # PCA durchführen
  pca <- prcomp(X_scaled, scale. = FALSE)  # Daten wurden vorher bereits skaliert
  
  loadings <- pca$rotation
  abs_load <- abs(loadings)
  
  # Anzahl PCs bestimmen, falls nicht angegeben
  if (is.null(n_components)) {
    n_components <- ncol(loadings)
  }
  
  message("✔️ PCA abgeschlossen: Es werden ", n_components, " Komponenten ausgewertet.")
  
  # Für jede Komponente Top + Bottom erstellen
  features <- lapply(1:n_components, function(i) {
    ord <- order(loadings[, i], decreasing = TRUE)     # echte Ladungen
    ord_low <- order(loadings[, i], decreasing = FALSE)
    
    list(
      top_20 = data.frame(
        feature = rownames(loadings)[ord][1:n_top],
        loading = loadings[ord, i][1:n_top],
        abs_loading = abs_load[ord, i][1:n_top],
        row.names = NULL
      ),
      bottom_20 = data.frame(
        feature = rownames(loadings)[ord_low][1:n_top],
        loading = loadings[ord_low, i][1:n_top],
        abs_loading = abs_load[ord_low, i][1:n_top],
        row.names = NULL
      )
    )
  })
  
  names(features) <- paste0("PC", 1:n_components)
  
  return(list(
    pca = pca,
    loadings = loadings,
    features = features
  ))
}



# 🔥 B: Textprofilierung
profile_text <- function(text_id, pca_results, yaml_groups, full_raw) {
  
  # 1. PCA-Scores für alle Texte
  scores <- as.data.frame(pca_results$pca$x)
  scores$text_id <- full_raw$text_id
  
  if (!text_id %in% scores$text_id) stop("text_id nicht vorhanden.")
  
  # 2. Scores für diesen Text
  vec <- scores[scores$text_id == text_id, grep("^PC", names(scores))]
  vec <- as.numeric(vec)
  
  # 3. YAML-Ladungsmatrix holen
  rotation <- pca_results$pca$rotation
  abs_loadings <- abs(rotation)
  
  yaml_matrix <- sapply(yaml_groups, function(fset) {
    colMeans(abs_loadings[fset, , drop = FALSE])
  })
  yaml_matrix <- t(yaml_matrix)   # YAML × PCs
  
  # 4. Gewichtung: YAML × PC-Scores
  profile <- yaml_matrix %*% vec
  profile <- as.numeric(profile)
  names(profile) <- rownames(yaml_matrix)
  
  sort(profile, decreasing = TRUE)
}


# 🔥 C: Interpretation einer einzelnen PCA-Komponente

interpret_pc <- function(pc, pca_results, yaml_groups) {
  
  rotation <- pca_results$pca$rotation
  abs_loadings <- abs(rotation)
  
  # YAML × PCs
  yaml_matrix <- sapply(yaml_groups, function(fset) {
    colMeans(abs_loadings[fset, , drop = FALSE])
  })
  yaml_matrix <- t(yaml_matrix)
  
  # Scores für die gewählte PC
  vec <- yaml_matrix[, pc]
  vec_sorted <- sort(vec, decreasing = TRUE)
  
  list(
    pc = pc,
    top_modules = head(vec_sorted, 20),
    bottom_modules = tail(vec_sorted, 20)
  )
}



# 🔥 TEXTPROFILIERUNG MIT INTERPRETATION (B3)
# 1. Profilberechnung + Interpretation
interpret_text <- function(text_id, pca_results, yaml_groups, full_raw,
                           top_n = 5, bottom_n = 5) {
  
  # --- 1. PCA-Scores extrahieren ---
  scores <- as.data.frame(pca_results$pca$x)
  scores$text_id <- full_raw$text_id
  
  if (!text_id %in% scores$text_id) {
    stop("text_id nicht gefunden.")
  }
  
  vec <- scores[scores$text_id == text_id, grep("^PC", names(scores))]
  vec <- as.numeric(vec)
  
  # --- 2. YAML-Ladungsmatrix ---
  rotation <- pca_results$pca$rotation
  abs_loadings <- abs(rotation)
  
  yaml_matrix <- t(sapply(yaml_groups, function(fset) {
    colMeans(abs_loadings[fset, , drop = FALSE])
  }))
  
  # --- 3. Gewichtung: YAML × PC-Scores ---
  profile <- yaml_matrix %*% vec
  profile <- as.numeric(profile)
  names(profile) <- rownames(yaml_matrix)
  
  # --- 4. Top / Bottom Module extrahieren ---
  sorted <- sort(profile, decreasing = TRUE)
  
  top_mod <- head(sorted, top_n)
  bottom_mod <- tail(sorted, bottom_n)
  
  # --- 5. Textuelle Interpretation bauen ---
  top_names    <- names(top_mod)
  bottom_names <- names(bottom_mod)
  
  interpretation <- paste0(
    "Der Text „", text_id, "“ zeigt ein klares semantisches Profil. ",
    
    "Auf der dominanten Seite stehen besonders: ",
    paste(top_names, collapse = ", "), ". ",
    
    "Diese Module prägen die PCA-Position des Textes am stärksten; ",
    "sie ziehen den Text auf Achsen, die typischerweise mit diesen Mustern assoziiert sind. ",
    
    "Auffällig gering vertreten sind dagegen: ",
    paste(bottom_names, collapse = ", "), ". ",
    
    "Diese Abwesenheiten tragen dazu bei, dass der Text sich von anderen Clustern oder Genres ",
    "in diesen Dimensionen abhebt. "
  )
  
  list(
    vector = profile,
    top = top_mod,
    bottom = bottom_mod,
    interpretation = interpretation
  )
}


rank_texts_by_pc <- function(pca_scores, pc = "PC1", n = 20) {
  
  if (!pc %in% colnames(pca_scores)) {
    stop(paste("PC nicht gefunden:", pc))
  }
  
  # Werte extrahieren
  vals <- pca_scores[[pc]]
  
  # Top & Bottom Indizes
  top_idx <- order(vals, decreasing = TRUE)[1:n]
  bottom_idx <- order(vals)[1:n]
  
  list(
    pc = pc,
    top = pca_scores[top_idx, c("text_id", pc)],
    bottom = pca_scores[bottom_idx, c("text_id", pc)]
  )
}

dominant_pc <- function(pca_scores) {
  score_matrix <- pca_scores[, grep("^PC", colnames(pca_scores))]
  apply(abs(score_matrix), 1, which.max)
}


cor_feature_pc <- function(X_clean, pca_scores, pc = "PC1") {
  
  # Korrelation pro Feature
  cvec <- cor(X_clean, pca_scores[[pc]])
  
  # sortieren
  sorted_pos <- sort(cvec, decreasing = TRUE)
  sorted_neg <- sort(cvec, decreasing = FALSE)
  
  list(
    pc = pc,
    top_positive = head(sorted_pos, 20),
    top_negative = head(sorted_neg, 20)
  )
}


# ✅ 2. PC-Nachbarschaften: Distanz + Clustering
neighbor_cluster <- function(pca_scores, method = "euclidean") {
  
  # Nur die PC-Spalten extrahieren
  pcs <- pca_scores[, grep("^PC", colnames(pca_scores))]
  
  # Distanzmatrix
  D <- dist(pcs, method = method)
  
  # Hierarchisches Clustering
  hc <- hclust(D, method = "ward.D2")
  
  list(
    dist = D,
    hclust = hc
  )
}


nearest_neighbors <- function(nb, pca_scores, text_row, k = 20) {
  
  D <- as.matrix(nb$dist)
  
  # Distanzen der Zielzeile
  dvec <- D[text_row, ]
  
  # sortieren (aber Zieltext selbst entfernen)
  ord <- order(dvec)
  ord <- ord[ord != text_row]
  
  tibble(
    text_id = pca_scores$text_id[ord][1:k],
    distance = dvec[ord][1:k]
  )
}


find_relevant_pcs_for_text <- function(pca_scores, text_row, z = 1){
  # nur numerische PCs
  pcs <- pca_scores[, sapply(pca_scores, is.numeric), drop = FALSE]
  
  # Z-Werte pro PC
  z_scores <- scale(pcs)
  
  # Welche PCs sind stärker als z-SD nach oben oder unten?
  which(abs(z_scores[text_row, ]) >= z)
}


# 3) Kombination mit Feature-Ladungen: welche sprachlichen Merkmale treiben genau diese PCs
# Wenn du herausfinden willst:
# Warum ist PC13 wichtig für mich?
# Was drückt PC22 bei meinem Text aus?
get_pc_profile <- function(pc, loadings_mat, top = 10){
  vals <- loadings_mat[, pc]
  list(
    positive = sort(vals, decreasing = TRUE)[1:top],
    negative = sort(vals, decreasing = FALSE)[1:top]
  )
}




# -----------------------------------------------------------
# interpret_canonical(): Die neue Premium-Funktion
# -----------------------------------------------------------
interpret_canonical <- function(cd_obj, pca_results, yaml_groups) {
  
  # CAN-Gewichte extrahieren (Can1)
  pc_weights <- cd_obj$coeffs.std[, 1]
  names(pc_weights) <- rownames(cd_obj$coeffs.std)
  
  # PCA-Ladungen der verwendeten PCs extrahieren
  used_pcs <- names(pc_weights)             # z.B. "PC1","PC2",… "PC12"
  loadings <- pca_results$pca$rotation[, used_pcs, drop = FALSE]
  
  # Canonical loading = weighted sum der PC-Ladungen
  canonical_loading <- as.vector(loadings %*% pc_weights)
  names(canonical_loading) <- rownames(loadings)
  
  abs_loading <- abs(canonical_loading)
  
  # Modul-Scores
  module_scores <- sapply(yaml_groups, function(fset) {
    mean(abs_loading[fset], na.rm = TRUE)
  })
  
  module_scores_sorted <- sort(module_scores, decreasing = TRUE)
  
  list(
    canonical_axis = "Can1",
    top_modules = head(module_scores_sorted, 12),
    bottom_modules = tail(module_scores_sorted, 12)
  )
}







