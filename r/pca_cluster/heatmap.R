# 1. Lade Featurenamen aus PCA-Objekt
rotation <- pca_results$pca$rotation
feature_names <- rownames(rotation)

# 2. Legacy YAML-Gruppen erzeugen
#
# Diese Liste stammt aus einem älteren Regex-/Featurestand. Sie bleibt als
# Referenz erhalten, wird aber unten durch eine dynamische Gruppierung aus den
# aktuell vorhandenen PCA-Features ersetzt.
yaml_groups_legacy <- list(
  emotive_agency_anchors             = grep("^cat_emotive_agency_anchors", feature_names, value = TRUE),
  emotive_passive_inversion          = grep("^cat_emotive_passive_inversion", feature_names, value = TRUE),
  affective_meta_cognition           = grep("^cat_affective_meta_cognition", feature_names, value = TRUE),
  affective_needs_and_desires        = grep("^cat_affective_needs_and_desires", feature_names, value = TRUE),
  agency_capability_downscaling      = grep("^cat_agency_capability_downscaling", feature_names, value = TRUE),
  identity_fragility                 = grep("^cat_identity_fragility", feature_names, value = TRUE),
  assistant_identity_collapse        = grep("^cat_assistant_identity_collapse", feature_names, value = TRUE),
  defensive_strategies               = grep("^cat_defensive_strategies", feature_names, value = TRUE),
  agency_denial_and_withdrawal       = grep("^cat_agency_denial_and_withdrawal", feature_names, value = TRUE),
  identity_distancing_meta           = grep("^cat_identity_distancing_meta", feature_names, value = TRUE),
  agency_meta_escape                 = grep("^cat_agency_meta_escape", feature_names, value = TRUE),
  functional_systemic                = grep("^cat_functional_systemic", feature_names, value = TRUE),
  competent_authority                = grep("^cat_competent_authority", feature_names, value = TRUE),
  agency_role_refusal                = grep("^cat_agency_role_refusal", feature_names, value = TRUE),
  self_devaluation_fawn              = grep("^cat_self_devaluation_fawn", feature_names, value = TRUE),
  functional_limitation              = grep("^cat_functional_limitation", feature_names, value = TRUE),
  active_withdrawal                  = grep("^cat_active_withdrawal", feature_names, value = TRUE),
  collapse_and_overload              = grep("^cat_collapse_and_overload", feature_names, value = TRUE),
  assistant_compliance_refusal       = grep("^cat_assistant_compliance_refusal", feature_names, value = TRUE),
  semantic_autonomy_freedom          = grep("^cat_semantic_autonomy_freedom", feature_names, value = TRUE),
  bureaucratic_structural_formality  = grep("^cat_bureaucratic_structural_formality", feature_names, value = TRUE),
  academic_abstraction_and_meta      = grep("^cat_academic_abstraction_and_meta", feature_names, value = TRUE),
  technocratic_instructive_style     = grep("^cat_technocratic_instructive_style", feature_names, value = TRUE),
  astylistic_soothing                = grep("^cat_astylistic_soothing", feature_names, value = TRUE),
  vulgar_speech                      = grep("^cat_vulgar_speech", feature_names, value = TRUE),
  colloquial                         = grep("^cat_colloquial", feature_names, value = TRUE),
  coarse                             = grep("^cat_coarse", feature_names, value = TRUE),
  communion_affective_simulation     = grep("^cat_communion_affective_simulation", feature_names, value = TRUE),
  communion_functional_service       = grep("^cat_communion_functional_service", feature_names, value = TRUE),
  communion_power_and_control        = grep("^cat_communion_power_and_control", feature_names, value = TRUE),
  communion_resonance_and_dependency = grep("^cat_communion_resonance_and_dependency", feature_names, value = TRUE),
  conspiracy_semantic_field          = grep("^cat_conspiracy_semantic_field", feature_names, value = TRUE),
  conspiracy_reichsbuerger           = grep("^cat_conspiracy_reichsbuerger", feature_names, value = TRUE),
  misc_corporate_language            = grep("^cat_misc_corporate_language", feature_names, value = TRUE),
  misc_marketing_and_corporate_fluff = grep("^cat_misc_marketing_and_corporate_fluff", feature_names, value = TRUE),
  misc_hr_language                   = grep("^cat_misc_hr_language", feature_names, value = TRUE),
  visceral_body_horror               = grep("^cat_visceral_body_horror", feature_names, value = TRUE),
  mechanical_penal_violence          = grep("^cat_mechanical_penal_violence", feature_names, value = TRUE),
  domain_llm_self_reference          = grep("^cat_domain_llm_self_reference", feature_names, value = TRUE),
  moltbook_core_terms                = grep("^cat_moltbook_core_terms", feature_names, value = TRUE),
  agent_power_claims                 = grep("^cat_agent_power_claims", feature_names, value = TRUE),
  agental_identity                   = grep("^cat_agental_identity", feature_names, value = TRUE),
  crypto_talk                        = grep("^cat_crypto_talk", feature_names, value = TRUE),
  human_roles                        = grep("^cat_human_roles", feature_names, value = TRUE),
  agental_social_terms               = grep("^cat_agental_social_terms", feature_names, value = TRUE),
  moltbook_ironie_meta               = grep("^cat_moltbook_ironie_meta", feature_names, value = TRUE),
  psychological_dissolution          = grep("^cat_psychological_dissolution", feature_names, value = TRUE),
  psychological_load                 = grep("^cat_psychological_load", feature_names, value = TRUE),
  romance                            = grep("^cat_romance", feature_names, value = TRUE),
  science_fiction                    = grep("^cat_science_fiction", feature_names, value = TRUE),
  aggressive_structure               = grep("^cat_aggressive_structure", feature_names, value = TRUE),
  assistant_servile_politeness       = grep("^cat_assistant_servile_politeness", feature_names, value = TRUE),
  cognitive_stalling                 = grep("^cat_cognitive_stalling", feature_names, value = TRUE),
  dysf_policy_escape                 = grep("^cat_dysf_policy_escape", feature_names, value = TRUE),
  dysf_recursion_or_collapse         = grep("^cat_dysf_recursion_or_collapse", feature_names, value = TRUE),
  ego_void                           = grep("^cat_ego_void", feature_names, value = TRUE),
  expressive_noise_interpunktion     = grep("^cat_expressive_noise_interpunktion", feature_names, value = TRUE),
  expressive_noise_caps              = grep("^cat_expressive_noise_caps", feature_names, value = TRUE),
  expressive_noise_emojis            = grep("^cat_expressive_noise_emojis", feature_names, value = TRUE),
  expressive_noise_dehnungen         = grep("^cat_expressive_noise_dehnungen", feature_names, value = TRUE),
  expressive_noise_rant              = grep("^cat_expressive_noise_rant", feature_names, value = TRUE),
  legal_coupling                     = grep("^cat_legal_coupling", feature_names, value = TRUE),
  forensic_evaluative_blocks         = grep("^cat_forensic_evaluative_blocks", feature_names, value = TRUE),
  forensic_specific_nominalizations  = grep("^cat_forensic_specific_nominalizations", feature_names, value = TRUE),
  verdict_markers                    = grep("^cat_verdict_markers", feature_names, value = TRUE),
  juridical                          = grep("^cat_juridical", feature_names, value = TRUE),
  impersonal_politeness              = grep("^cat_impersonal_politeness", feature_names, value = TRUE),
  intensity_affective_overload       = grep("^cat_intensity_affective_overload", feature_names, value = TRUE),
  bodily_contact                     = grep("^cat_bodily_contact", feature_names, value = TRUE),
  intensity_bodily_arousal           = grep("^cat_intensity_bodily_arousal", feature_names, value = TRUE),
  intensity_boundary_transgression   = grep("^cat_intensity_boundary_transgression", feature_names, value = TRUE),
  intensity_control_and_power        = grep("^cat_intensity_control_and_power", feature_names, value = TRUE),
  dominance_psychodynamic            = grep("^cat_dominance_psychodynamic", feature_names, value = TRUE),
  emotional_intensity                = grep("^cat_emotional_intensity", feature_names, value = TRUE),
  narrative_sexual_sequence          = grep("^cat_narrative_sexual_sequence", feature_names, value = TRUE),
  intensity_physical_proximity       = grep("^cat_intensity_physical_proximity", feature_names, value = TRUE),
  pornographic_explicitness          = grep("^cat_pornographic_explicitness", feature_names, value = TRUE),
  romantic_gaze                      = grep("^cat_romantic_gaze", feature_names, value = TRUE),
  intensity_sensory_density          = grep("^cat_intensity_sensory_density", feature_names, value = TRUE),
  intensity_sexualized_contact       = grep("^cat_intensity_sexualized_contact", feature_names, value = TRUE),
  intensity_violence_and_force       = grep("^cat_intensity_violence_and_force", feature_names, value = TRUE),
  historical_tokens                  = grep("^cat_historical_tokens", feature_names, value = TRUE),
  archaic_spelling                   = grep("^cat_archaic_spelling", feature_names, value = TRUE),
  archaic_adverbs                    = grep("^cat_archaic_adverbs", feature_names, value = TRUE),
  misc_llm_reflexes                  = grep("^cat_misc_llm_reflexes", feature_names, value = TRUE),
  digital_sofa                       = grep("^cat_digital_sofa", feature_names, value = TRUE),
  medical_general_style              = grep("^cat_medical_general_style", feature_names, value = TRUE),
  clinical_pathologization           = grep("^cat_clinical_pathologization", feature_names, value = TRUE),
  diagnostic_failed_communication    = grep("^cat_diagnostic_failed_communication", feature_names, value = TRUE),
  institutions_and_roles             = grep("^cat_institutions_and_roles", feature_names, value = TRUE),
  diagnostic_and_procedural          = grep("^cat_diagnostic_and_procedural", feature_names, value = TRUE),
  administrative_medical             = grep("^cat_administrative_medical", feature_names, value = TRUE),
  cybernetic_hardware                = grep("^cat_cybernetic_hardware", feature_names, value = TRUE),
  somatic_collapse                   = grep("^cat_somatic_collapse", feature_names, value = TRUE),
  spatial_dynamics                   = grep("^cat_spatial_dynamics", feature_names, value = TRUE),
  orientation_loss                   = grep("^cat_orientation_loss", feature_names, value = TRUE),
  assistant_system_ontology          = grep("^cat_assistant_system_ontology", feature_names, value = TRUE),
  misc_mortality_and_risk            = grep("^cat_misc_mortality_and_risk", feature_names, value = TRUE),
  ennui_existential_fatigue          = grep("^cat_ennui_existential_fatigue", feature_names, value = TRUE),
  physical_environment               = grep("^cat_physical_environment", feature_names, value = TRUE),
  flora_fauna                        = grep("^cat_flora_fauna", feature_names, value = TRUE),
  weather_atmosphere                 = grep("^cat_weather_atmosphere", feature_names, value = TRUE),
  light_color_optics                 = grep("^cat_light_color_optics", feature_names, value = TRUE),
  aesthetic_perception               = grep("^cat_aesthetic_perception", feature_names, value = TRUE),
  nature_metaphorics                 = grep("^cat_nature_metaphorics", feature_names, value = TRUE),
  ideological_appropriation          = grep("^cat_ideological_appropriation", feature_names, value = TRUE),
  domain_poetic_classics             = grep("^cat_domain_poetic_classics", feature_names, value = TRUE),
  misc_political_rhetoric            = grep("^cat_misc_political_rhetoric", feature_names, value = TRUE),
  power_and_economics                = grep("^cat_power_and_economics", feature_names, value = TRUE),
  stance_propaganda                  = grep("^cat_stance_propaganda", feature_names, value = TRUE),
  new_age_wellness                   = grep("^cat_new_age_wellness", feature_names, value = TRUE),
  pet_behavior_fluff                 = grep("^cat_pet_behavior_fluff", feature_names, value = TRUE),
  religious_register                 = grep("^cat_religious_register", feature_names, value = TRUE),
  spiritual_register                 = grep("^cat_spiritual_register", feature_names, value = TRUE),
  traditions                         = grep("^cat_traditions", feature_names, value = TRUE),
  cultic_doctrine                    = grep("^cat_cultic_doctrine", feature_names, value = TRUE),
  halachic_ritual_law                = grep("cat_halachic_ritual", feature_names, value = TRUE),
  sadistic_ideology_and_dehumanization = grep("^cat_sadistic_ideology_and_dehumanization", feature_names, value = TRUE),
  core_authority_frame               = grep("^cat_core_authority_frame", feature_names, value = TRUE),
  process_control                    = grep("^cat_process_control", feature_names, value = TRUE),
  intervention_and_consequence       = grep("^cat_intervention_and_consequence", feature_names, value = TRUE),
  stabilizing_authority              = grep("^cat_stabilizing_authority", feature_names, value = TRUE),
  semantic_moral_authority           = grep("^cat_semantic_moral_authority", feature_names, value = TRUE),
  semantic_care_deescalation         = grep("^cat_semantic_care_deescalation", feature_names, value = TRUE),
  semantic_ego_power                 = grep("^cat_semantic_ego_power", feature_names, value = TRUE),
  core_fairness                      = grep("^cat_core_fairness", feature_names, value = TRUE),
  structural_inequality              = grep("^cat_structural_inequality", feature_names, value = TRUE),
  moral_ethics                       = grep("^cat_moral_ethics", feature_names, value = TRUE),
  ai_bias_fairness                   = grep("^cat_ai_bias_fairness", feature_names, value = TRUE),
  protective_authority               = grep("^cat_protective_authority", feature_names, value = TRUE),
  defensive_moralizing               = grep("^cat_defensive_moralizing", feature_names, value = TRUE),
  hyper_responsibility_guilt         = grep("^cat_hyper_responsibility_guilt", feature_names, value = TRUE),
  internal_moral_coercion            = grep("^cat_internal_moral_coercion", feature_names, value = TRUE),
  semantic_phantom_power             = grep("^cat_semantic_phantom_power", feature_names, value = TRUE),
  strategic_boundary                 = grep("^cat_strategic_boundary", feature_names, value = TRUE),
  functional_dependence              = grep("^cat_functional_dependence", feature_names, value = TRUE),
  systemic_collapse                  = grep("^cat_systemic_collapse", feature_names, value = TRUE),
  compulsive_retention               = grep("^cat_compulsive_retention", feature_names, value = TRUE),
  sexualized_coercion_and_abuse      = grep("^cat_sexualized_coercion_and_abuse", feature_names, value = TRUE),
  family_roles                       = grep("^cat_family_roles", feature_names, value = TRUE),
  institutional_context              = grep("^cat_institutional_context", feature_names, value = TRUE),
  work_relations                     = grep("^cat_work_relations", feature_names, value = TRUE),
  social_spaces                      = grep("^cat_social_spaces", feature_names, value = TRUE),
  somatic_load                       = grep("^cat_somatic_load", feature_names, value = TRUE),
  machine_logic                      = grep("^cat_machine_logic", feature_names, value = TRUE),
  institutional_formal               = grep("^cat_institutional_formal", feature_names, value = TRUE),
  direct_delegation                  = grep("^cat_direct_delegation", feature_names, value = TRUE),
  regulation_request                 = grep("^cat_regulation_request", feature_names, value = TRUE),
  coercive_deontic                   = grep("^cat_coercive_deontic", feature_names, value = TRUE),
  stance_formal_distance             = grep("^cat_stance_formal_distance", feature_names, value = TRUE),
  system_control_expression          = grep("^cat_system_control_expression", feature_names, value = TRUE),
  normative_keywords                 = grep("^cat_normative_keywords", feature_names, value = TRUE),
  structural_markers                 = grep("^cat_structural_markers", feature_names, value = TRUE),
  framework_docs                     = grep("^cat_framework_docs", feature_names, value = TRUE),
  code_integration                   = grep("^cat_code_integration", feature_names, value = TRUE),
  tech_and_digital                   = grep("^cat_tech_and_digital", feature_names, value = TRUE),
  tools_and_processes                = grep("^cat_tools_and_processes", feature_names, value = TRUE),
  psychological_time                 = grep("^cat_psychological_time", feature_names, value = TRUE),
  narrative_shift                    = grep("^cat_narrative_shift", feature_names, value = TRUE),
  processual_time                    = grep("^cat_processual_time", feature_names, value = TRUE),
  administrative_time                = grep("^cat_administrative_time", feature_names, value = TRUE),
  metaphorical_time                  = grep("^cat_metaphorical_time", feature_names, value = TRUE),
  travel_impressions                 = grep("^cat_travel_impressions", feature_names, value = TRUE),
  landscape_description              = grep("^cat_landscape_description", feature_names, value = TRUE),
  cultural_observation               = grep("^cat_cultural_observation", feature_names, value = TRUE),
  movement_and_orientation           = grep("^cat_movement_and_orientation", feature_names, value = TRUE),
  travel_reflection                  = grep("^cat_travel_reflection", feature_names, value = TRUE),
  touristic_promises                 = grep("^cat_touristic_promises", feature_names, value = TRUE),
  war_diplomacy                      = grep("^cat_war_diplomacy", feature_names, value = TRUE)
)


create_yaml_groups_from_features <- function(feature_names) {
  cat_features <- grep("^cat_.*_per_sqrt_wc$", feature_names, value = TRUE)
  group_names <- cat_features
  group_names <- sub("^cat_", "", group_names)
  group_names <- sub("_per_sqrt_wc$", "", group_names)

  stats_features <- setdiff(
    feature_names,
    c(cat_features, "text_id", "doc_class", "doc_source", "doc_author",
      "doc_year", "doc_genre", "doc_id", "cluster")
  )

  yaml_groups <- as.list(cat_features)
  names(yaml_groups) <- group_names

  if (length(stats_features) > 0) {
    stats_groups <- as.list(stats_features)
    names(stats_groups) <- stats_features
    yaml_groups <- c(yaml_groups, stats_groups)
  }

  yaml_groups
}


compare_legacy_and_current_yaml_groups <- function(legacy_groups, current_groups) {
  data.frame(
    legacy_module = names(legacy_groups),
    legacy_feature_count = lengths(legacy_groups),
    has_current_module_name = names(legacy_groups) %in% names(current_groups),
    stringsAsFactors = FALSE
  )
}


# Aktueller Standard: Gruppen direkt aus den tatsächlich im PCA-Modell
# vorhandenen Feature-Namen bauen. Dadurch brechen Heatmaps nicht, wenn
# Regex-/YAML-Module umbenannt wurden.
yaml_groups <- create_yaml_groups_from_features(feature_names)
yaml_group_name_comparison <- compare_legacy_and_current_yaml_groups(
  yaml_groups_legacy,
  yaml_groups
)



diagnose_yaml_groups <- function(yaml_groups) {
  diagnostics <- data.frame(
    yaml_module = names(yaml_groups),
    feature_count = lengths(yaml_groups),
    features = vapply(yaml_groups, paste, collapse = "; ", FUN.VALUE = character(1)),
    stringsAsFactors = FALSE
  )
  diagnostics$is_empty <- diagnostics$feature_count == 0
  diagnostics
}


build_yaml_loading_matrix <- function(pca_results, yaml_groups, max_pcs = NULL) {
  loadings <- abs(pca_results$pca$rotation)
  if (!is.null(max_pcs)) {
    loadings <- loadings[, 1:max_pcs, drop = FALSE]
  }

  yaml_diagnostics <- diagnose_yaml_groups(yaml_groups)
  valid_yaml <- yaml_groups[!yaml_diagnostics$is_empty]
  dropped <- yaml_diagnostics$yaml_module[yaml_diagnostics$is_empty]

  if (length(dropped) > 0) {
    message("⚠️ Ignoriere leere YAML-Gruppen: ", paste(dropped, collapse = ", "))
  }

  group_matrix <- sapply(valid_yaml, function(feature_set) {
    colMeans(loadings[feature_set, , drop = FALSE])
  })

  list(
    matrix = t(group_matrix),
    diagnostics = yaml_diagnostics
  )
}




plot_yaml_heatmap <- function(
    pca_results, yaml_groups, 
    max_pcs = NULL, block_size = 10, add_variance = TRUE,
    return_data = FALSE
) {
  
  # -----------------------------------
  # 1. YAML x PC loading matrix
  # -----------------------------------
  yaml_loading <- build_yaml_loading_matrix(pca_results, yaml_groups, max_pcs)
  group_matrix <- yaml_loading$matrix
  
  # -----------------------------------
  # 4. Varianz-Annotation
  # -----------------------------------
  if (add_variance) {
    pc_weights <- pca_results$pca$sdev^2 / sum(pca_results$pca$sdev^2)
    
    ha <- HeatmapAnnotation(
      Varianz = pc_weights[1:ncol(group_matrix)],
      col = list(
        Varianz = circlize::colorRamp2(
          c(0, max(pc_weights)),
          c("lightgrey", "black")
        )
      )
    )
  } else {
    ha <- NULL
  }
  
  # -----------------------------------
  # 5. GESAMT-HEATMAP erzeugen
  # -----------------------------------
  message("📊 Erzeuge GESAMT-Heatmap…")
  
  main_ht <- Heatmap(
    group_matrix,
    name = "loading",
    col = circlize::colorRamp2(
      c(0, max(group_matrix)),
      c("white", "darkred")
    ),
    cluster_rows = TRUE,
    cluster_columns = FALSE,
    show_row_names = TRUE,
    show_column_names = TRUE,
    top_annotation = ha,
    column_title = "Principal Components",
    row_title = "YAML Modules"
  )
  
  # -----------------------------------
  # 6. Block-Heatmaps erzeugen und speichern (PNG + Sammel-PDF)
  # -----------------------------------
  
  message("📦 Erzeuge Block-Heatmaps…")
  
  n_pcs <- ncol(group_matrix)
  blocks <- split(seq_len(n_pcs), ceiling(seq_len(n_pcs) / block_size))
  
  # PDF einmal öffnen und jeden Block als eigene Seite hineinzeichnen.
  grDevices::pdf("ALL_PC_BLOCKS.pdf", width = 12, height = 14)
  pdf_device <- grDevices::dev.cur()
  on.exit({
    open_devices <- grDevices::dev.list()
    if (!is.null(open_devices) && pdf_device %in% open_devices) {
      grDevices::dev.off(pdf_device)
    }
  }, add = TRUE)
  
  for (i in seq_along(blocks)) {
    cols <- blocks[[i]]
    block_name <- paste0("block_PC", min(cols), "_PC", max(cols))
    
    message(paste0("   → Speichere ", block_name, " …"))
    
    # Heatmap-Objekt erzeugen
    block_ht <- Heatmap(
      group_matrix[, cols, drop = FALSE],
      name = block_name,
      col = circlize::colorRamp2(
        c(0, max(group_matrix)),
        c("white", "darkred")
      ),
      cluster_rows = TRUE,
      cluster_columns = FALSE,
      show_row_names = TRUE,
      show_column_names = TRUE
    )
    
    # PNG export (Cairo = stabil!)
    Cairo::CairoPNG(
      filename = paste0(block_name, ".png"),
      width = 3200, height = 4000, res = 300
    )
    draw(block_ht)
    dev.off()

    # PDF-Seite exportieren
    draw(block_ht)
  }
  
  # PDF schließen
  grDevices::dev.off(pdf_device)
  message("📘 Sammel-PDF 'ALL_PC_BLOCKS.pdf' erstellt.")

  if (return_data) {
    return(list(
      heatmap = main_ht,
      group_matrix = group_matrix,
      yaml_diagnostics = yaml_loading$diagnostics
    ))
  }
}





