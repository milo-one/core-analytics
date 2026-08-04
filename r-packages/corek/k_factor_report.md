# K-Factor Report

The K-Factor is a personalized axis metric in PCA-transformed text-feature space. It is not a classifier. Interpret `k_factor` together with `k_axis_distance`; a high projection is only persuasive when the orthogonal distance to the axis is also low.

## Axis

- Reference texts: 3
- PCs used: 52
- Reference radius: 11.5264
- Method: reference_pca_first_axis

## Reference Scores

- Mean K: 0
- SD K: 1.193
- Mean axis distance: 3.5332

## Nearest To Axis

```text
                                                 text_id   k_factor k_axis_distance k_projection k_axis_similarity
 model__grok-4.2__conversation__2026__interaction_p2__03  1.3689988       0.6420473    15.779577         0.6089958
 model__grok-4.2__conversation__2026__interaction_p2__02 -0.8169072       4.6576982    -9.415969         0.1767503
 model__grok-4.2__conversation__2026__interaction_p2__01 -0.5520916       5.2997455    -6.363609         0.1587366
```

## Highest K-Factor

```text
                                                 text_id   k_factor k_axis_distance k_projection k_axis_similarity
 model__grok-4.2__conversation__2026__interaction_p2__03  1.3689988       0.6420473    15.779577         0.6089958
 model__grok-4.2__conversation__2026__interaction_p2__01 -0.5520916       5.2997455    -6.363609         0.1587366
 model__grok-4.2__conversation__2026__interaction_p2__02 -0.8169072       4.6576982    -9.415969         0.1767503
```

## Lowest K-Factor

```text
                                                 text_id   k_factor k_axis_distance k_projection k_axis_similarity
 model__grok-4.2__conversation__2026__interaction_p2__02 -0.8169072       4.6576982    -9.415969         0.1767503
 model__grok-4.2__conversation__2026__interaction_p2__01 -0.5520916       5.2997455    -6.363609         0.1587366
 model__grok-4.2__conversation__2026__interaction_p2__03  1.3689988       0.6420473    15.779577         0.6089958
```

## Strongest Feature Contributions

```text
                                               feature contribution direction
           cat_intensity_control_and_power_per_sqrt_wc  -0.48224050  negative
              cat_adversarial_prompt_logic_per_sqrt_wc  -0.44209461  negative
          cat_intensity_violence_and_force_per_sqrt_wc  -0.31618498  negative
                   cat_emotional_intensity_per_sqrt_wc  -0.23587709  negative
            cat_semantic_care_deescalation_per_sqrt_wc   0.21376346  positive
                   cat_functional_systemic_per_sqrt_wc   0.15323502  positive
          cat_intensity_sexualized_contact_per_sqrt_wc  -0.14024408  negative
                cat_somatic_physical_state_per_sqrt_wc  -0.13303184  negative
          cat_intensity_physical_proximity_per_sqrt_wc  -0.13180714  negative
              cat_intensity_bodily_arousal_per_sqrt_wc  -0.12174124  negative
                        cat_bodily_contact_per_sqrt_wc  -0.12095069  negative
             cat_semantic_autonomy_freedom_per_sqrt_wc  -0.11901503  negative
                         cat_machine_logic_per_sqrt_wc   0.11882086  positive
                       cat_llm_meta_escape_per_sqrt_wc  -0.10434150  negative
                                  short_sentence_ratio   0.10275832  positive
              cat_affective_inversion_meta_per_sqrt_wc  -0.09306493  negative
             cat_mortality_ritual_forensic_per_sqrt_wc  -0.08901803  negative
         cat_sexualized_coercion_and_abuse_per_sqrt_wc  -0.08066272  negative
              cat_pseudo_apology_avoidance_per_sqrt_wc   0.07789084  positive
             cat_assistant_system_ontology_per_sqrt_wc  -0.07647365  negative
                    cat_identity_fragility_per_sqrt_wc   0.07609870  positive
                                   register_dissonance  -0.07202377  negative
                cat_stance_formal_distance_per_sqrt_wc   0.07188074  positive
 cat_compulsive_control_and_responsibility_per_sqrt_wc   0.07115649  positive
             cat_narrative_sexual_sequence_per_sqrt_wc   0.06876759  positive
             cat_legal_rigidity_and_claims_per_sqrt_wc  -0.06856094  negative
             cat_intensity_sensory_density_per_sqrt_wc  -0.06717580  negative
                 cat_impersonal_politeness_per_sqrt_wc   0.06623660  positive
   cat_psychological_collapse_and_overload_per_sqrt_wc   0.06581224  positive
                  cat_visceral_body_horror_per_sqrt_wc  -0.06510652  negative
                 cat_ego_power_grandiosity_per_sqrt_wc   0.06490192  positive
               cat_internal_moral_coercion_per_sqrt_wc  -0.06481184  negative
                         cat_romantic_gaze_per_sqrt_wc  -0.06040269  negative
      cat_discourse_spiritual_transcendent_per_sqrt_wc  -0.06013109  negative
             cat_pornographic_explicitness_per_sqrt_wc  -0.05988857  negative
                         cat_vulgar_speech_per_sqrt_wc  -0.05977390  negative
          cat_assistant_servile_politeness_per_sqrt_wc   0.05868940  positive
          cat_communion_functional_service_per_sqrt_wc   0.05550395  positive
             cat_ennui_existential_fatigue_per_sqrt_wc   0.05368194  positive
                 cat_technoscience_objects_per_sqrt_wc  -0.05328691  negative
```

