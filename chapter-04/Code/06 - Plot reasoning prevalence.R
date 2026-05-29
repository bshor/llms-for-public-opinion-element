# Reasoning category prevalence visualization ----

prevalence_data <- tariff_hybrid_annotation_data_binary %>%
  select(
    domestic_industry_protection,
    job_creation,
    price_increase_concern,
    economic_impact,
    equity_and_fairness,
    nationalism_and_economic_independence,
    lack_of_understanding_indecision,
    retaliation_and_trade_wars,
    political_and_strategic_considerations
  ) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE))) %>%
  pivot_longer(
    cols = everything(),
    names_to = "category",
    values_to = "prevalence"
  ) %>%
  mutate(
    category = str_replace_all(category, "_", " "),
    category = str_to_title(category)
  ) %>%
  arrange(prevalence) %>%
  mutate(category = factor(category, levels = category))

p_reasoning_prevalence <- ggplot(prevalence_data, aes(x = prevalence, y = category)) +
  geom_col() +
  labs(
    x = "Prevalence",
    y = NULL
  ) +
  theme_minimal()

p_reasoning_prevalence

ggsave(
  filename = "Plots/p_reasoning_prevalence.png",
  plot = p_reasoning_prevalence,
  width = 7,
  height = 5,
  dpi = 300
)
