
load_data <- function(root_path) {
  message("📂 Lade Daten...")
  
  cat_df     <- readr::read_csv(file.path(root_path, "category_features.csv"))
  feat_df    <- readr::read_csv(file.path(root_path, "features_full.csv"))
  pca_df     <- readr::read_csv(file.path(root_path, "pca_scores.csv"))
  cluster_df <- readr::read_csv(file.path(root_path, "cluster_labels.csv"))
  
  full_raw <- feat_df %>%
    dplyr::left_join(pca_df, by = "text_id") %>%
    dplyr::left_join(cluster_df, by = "text_id")
  
  message("✔️ Daten geladen und zusammengeführt")
  return(full_raw)
}





