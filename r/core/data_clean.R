clean_numeric <- function(df) {
  message("🧹 Bereinige numerische Variablen...")
  
  # Nur numerische Spalten extrahieren
  X_raw <- df %>%
    dplyr::select(where(is.numeric)) %>%
    dplyr::mutate(across(everything(), ~tidyr::replace_na(.x, 0)))
  
  # Nullvarianz identifizieren
  zero_var_cols <- X_raw %>%
    summarise(across(everything(), ~var(.x, na.rm = TRUE))) %>%
    tidyr::gather(col, var) %>%
    dplyr::filter(var == 0) %>%
    dplyr::pull(col)
  
  if (length(zero_var_cols) > 0) {
    message("⚠️ Entferne Nullvarianz-Spalten: ", paste(zero_var_cols, collapse = ", "))
  } else {
    message("✔️ Keine Nullvarianz-Spalten gefunden")
  }
  
  X_clean <- X_raw %>% dplyr::select(-all_of(zero_var_cols))
  
  # Skalieren
  X_scaled <- scale(X_clean)
  
  message("✔️ Numerische Variablen bereinigt und skaliert")
  
  return(list(
    raw = X_raw,
    clean = X_clean,
    scaled = X_scaled
  ))
}





