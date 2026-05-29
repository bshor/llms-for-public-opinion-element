# Regression with DSL correction ----

# Create outcome: Price Increase Concern (binary) ----
comparison_data <- comparison_data %>%
  mutate(
    price_concern = as.integer(
      str_detect(human_tariff_reasoning, regex("Price Increase Concern", ignore_case = TRUE))
    )
  )

# DSL example ----
out <- dsl(
  model = "lm",
  formula = price_concern ~ human_tariff_position_num,
  predicted_var = "human_tariff_position_num",
  prediction = "tariff_position_hybrid_num",
  data = comparison_data
)

summary(out)
