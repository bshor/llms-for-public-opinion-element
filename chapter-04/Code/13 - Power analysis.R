# Power analysis for human coding ----

# Create outcome variable capturing price-related reasoning ----
comparison_data_plot <- comparison_data %>%
  mutate(
    price_concern = as.integer(
      grepl("Price Increase Concern", human_tariff_reasoning)
    )
  )

# Power analysis ----
power_out <- power_dsl(
  labeled_size = c(50, 100, 150, 200, 300, 400, 500),
  model = "lm",
  formula = price_concern ~ human_tariff_position_num,
  predicted_var = "human_tariff_position_num",
  prediction = "tariff_position_hybrid_num",
  data = comparison_data_plot
)

p_power <- plot(power_out, coef_name = "human_tariff_position_num")

p_power

png("Plots/p_power.png", width = 7, height = 5, units = "in", res = 300)
plot(power_out, coef_name = "human_tariff_position_num")
dev.off()
