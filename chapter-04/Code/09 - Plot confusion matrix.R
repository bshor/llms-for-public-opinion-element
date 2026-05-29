# Confusion matrix heat map ----

conf_mat <- comparison_data %>%
  count(human_tariff_position_factor, tariff_position_hybrid_factor) %>%
  complete(
    human_tariff_position_factor = factor(
      c("Support", "Neutral", "Oppose"),
      levels = c("Support", "Neutral", "Oppose")
    ),
    tariff_position_hybrid_factor = factor(
      c("Support", "Neutral", "Oppose"),
      levels = c("Support", "Neutral", "Oppose")
    ),
    fill = list(n = 0)
  )

p_conf_matrix <- ggplot(conf_mat, aes(
  x = tariff_position_hybrid_factor,
  y = human_tariff_position_factor,
  fill = n
)) +
  geom_tile() +
  geom_text(aes(label = n), color = "white") +
  scale_fill_gradient(low = "gray80", high = "black") +
  labs(
    x = "AI Coding",
    y = "Human Coding",
    fill = "Count"
  ) +
  theme_minimal()

p_conf_matrix

ggsave(
  filename = "Plots/confusion_matrix.png",
  plot = p_conf_matrix,
  width = 6,
  height = 5,
  dpi = 300
)
