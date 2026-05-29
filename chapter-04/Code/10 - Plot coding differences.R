# AI-human coding difference plot ----

# Create distribution data ----
dist_data <- comparison_data %>%
  select(human_tariff_position_factor, tariff_position_hybrid_factor) %>%
  pivot_longer(
    cols = everything(),
    names_to = "source",
    values_to = "position"
  ) %>%
  mutate(
    source = recode(source,
      human_tariff_position_factor = "Human",
      tariff_position_hybrid_factor = "AI"
    ),
    position = factor(
      position,
      levels = c("Support", "Neutral", "Oppose")
    )
  ) %>%
  count(source, position) %>%
  group_by(source) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

diff_data <- dist_data %>%
  select(source, position, prop) %>%
  pivot_wider(names_from = source, values_from = prop) %>%
  mutate(diff = AI - Human)

p_diff_plot <- ggplot(diff_data, aes(x = position, y = diff)) +
  geom_col(fill = "black") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(
    x = "Tariff Position",
    y = "AI - Human Difference"
  ) +
  theme_minimal()

p_diff_plot

ggsave(
  filename = "Plots/diff_plot.png",
  plot = p_diff_plot,
  width = 6,
  height = 5,
  dpi = 300
)
