sink("Output/09b-output.txt")

load("Processed/ideal-points.Rdata")  # Loads ideal_points

# Visualize ideal point distributions
ideal_plot <- ideal_points %>%
  filter(party %in% c("Democrat", "Republican")) %>%
  mutate(source = ifelse(source == "human", "Human (CCES)", "LLM"))

p <- ggplot(ideal_plot, aes(x = ideal_point, fill = party)) +
  geom_density(alpha = 0.4) +
  facet_wrap(~ source, nrow = 2) +
  scale_fill_manual(values = c("Democrat" = "blue4", "Republican" = "red4")) +
  labs(
    title = "Ideal point distributions: Human vs LLM",
    x = "Ideal point (liberal to conservative)",
    y = "Density",
    fill = "Party"
  ) +
  theme_minimal()

ggsave("Plots/09-ideal-points.png", p, width = 7, height = 5)
cat("Plot saved to Plots/09-ideal-points.png\n")

sink()
