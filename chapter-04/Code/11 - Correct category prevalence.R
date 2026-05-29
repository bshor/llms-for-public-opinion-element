# Bias-corrected estimate of category prevalence ----

labeled_subset <- comparison_data %>%
  filter(
    !is.na(human_tariff_position_num),
    !is.na(tariff_position_hybrid_num)
  )

# Error rate in labeled subset ----
error_rate <- mean(
  labeled_subset$tariff_position_hybrid_num != labeled_subset$human_tariff_position_num,
  na.rm = TRUE
)

error_rate

# Full-sample estimate ----
Y_hat <- mean(
  tariff_hybrid_annotation_data$tariff_position_hybrid_num == 1,
  na.rm = TRUE
)

# AI-labeled subset ----
Y_hat_n <- mean(
  labeled_subset$tariff_position_hybrid_num == 1,
  na.rm = TRUE
)

# Human-labeled subset ----
Y_n <- mean(
  labeled_subset$human_tariff_position_num == 1,
  na.rm = TRUE
)

# Bias-corrected estimate ----
p_Y_tilde <- Y_hat - (Y_hat_n - Y_n)
p_Y_tilde
