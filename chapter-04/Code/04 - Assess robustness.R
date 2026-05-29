# Repeat annotation multiple times ----

test_response <- tariff_annotation_data$tariffs_part_words[1]

# Run annotation twice with identical settings ----
results_run1 <- annotate_tariff_response(test_response)
results_run2 <- annotate_tariff_response(test_response)

# Compare structured outputs ----
results_run1
results_run2

# Compare labels ----
results_run1$tariff_position_hybrid == results_run2$tariff_position_hybrid

# Compare reasoning categories ----
identical(
  results_run1$tariff_reasoning_hybrid,
  results_run2$tariff_reasoning_hybrid
)
