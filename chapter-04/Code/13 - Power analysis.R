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

# Plot standard error vs. size of labeled data ----
p_power <- tibble(size = power_out$labeled_size,
                  se = power_out$predicted_se[, "human_tariff_position_num"]) %>%
  distinct() %>% arrange(size) %>%
  ggplot(aes(size, se)) + geom_line(color = "grey50") + geom_point(size = 2) +
  geom_point(data = ~ filter(.x, size == 100), shape = 15, size = 3.5) +
  labs(x = "Size of Labeled Data", y = "Standard Error") + theme_minimal()

ggsave("Plots/p_power.png", p_power, width = 7, height = 5, dpi = 300)
