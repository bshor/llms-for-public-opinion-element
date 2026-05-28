sink("Output/10-output.txt")

load("Processed/ideal-points.Rdata")  # Loads ideal_points

# Calculate comparison metrics
comparison <- ideal_points %>%
  pivot_wider(id_cols = caseid, names_from = source, values_from = ideal_point) %>%
  filter(!is.na(human), !is.na(llm)) %>%
  summarize(
    n = n(),
    mean_sq_deviation = mean((llm - human)^2),
    correlation = cor(llm, human)
  )

print(comparison)

print(glue("
Ideal point comparison (LLM vs Human):
  N: {comparison$n}
  Mean Squared Deviation: {round(comparison$mean_sq_deviation, 3)}
  Correlation: {round(comparison$correlation, 3)}
\n"))

# Calculate MSD by party
comparison_by_party <- ideal_points %>%
  filter(party %in% c("Democrat", "Republican", "Independent")) %>%
  pivot_wider(id_cols = c(caseid, party), names_from = source, values_from = ideal_point) %>%
  filter(!is.na(human), !is.na(llm)) %>%
  group_by(party) %>%
  summarize(
    n = n(),
    msd = mean((llm - human)^2),
    correlation = cor(llm, human)
  )

print(comparison_by_party)

# Visualize ideal point agreement
plot_data <- ideal_points %>%
  pivot_wider(id_cols = c(caseid, party), names_from = source, values_from = ideal_point) %>%
  filter(!is.na(human), !is.na(llm), party %in% c("Democrat", "Republican", "Independent"))

p <- ggplot(plot_data, aes(x = human, y = llm, color = party)) +
  geom_point(alpha = 0.4, size = 1.5) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +
  scale_color_manual(values = c("Democrat" = "blue4", "Independent" = "gray50", "Republican" = "red4")) +
  labs(
    title = "Ideal point agreement: LLM vs Human",
    x = "Human ideal point",
    y = "LLM ideal point",
    color = "Party",
    caption = "Dashed line represents perfect agreement; colored lines show linear fit by party"
  ) +
  theme_minimal()

ggsave("Plots/10-ideal-point-comparison.png", p, width = 7, height = 5)
cat("Plot saved to Plots/10-ideal-point-comparison.png\n")

sink()
