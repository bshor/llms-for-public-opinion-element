sink("Output/05-output.txt")

load_combined()  # Loads combined_results

aggregate_comparison <- combined_results %>%
  group_by(issue) %>%
  summarize(
    llm_support = mean(llm_response == "Support"),          # Synthetic proportion
    real_support = mean(real_response == "Support")         # Real proportion
  ) %>%
  mutate(
    absolute_error = abs(llm_support - real_support)        # Distance from truth
  ) %>%
  print()

summary_mae <- aggregate_comparison %>%
  summarize(mae = mean(absolute_error))

print(glue_data(summary_mae, "
Mean Absolute Error: {round(mae, 3)}
\n"))

p <- ggplot(aggregate_comparison, aes(x = real_support, y = llm_support)) +
  geom_point(size = 2, alpha = 0.5) +                      # Add points
  geom_text(aes(label = issue), size = 3, vjust = -0.5) +  # Label each point with issue ID
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") + # Perfect agreement line
  labs(
    x = "Real CCES proportion supporting",
    y = "LLM proportion supporting",
    title = "Aggregate accuracy: Synthetic vs. Real proportions"
  ) +
  coord_fixed(xlim = c(0, 1), ylim = c(0, 1)) +            # 1:1 aspect ratio
  theme_minimal()

ggsave("Plots/05-plot.png", p, width = 6, height = 6)
cat("Plot saved to Plots/05-plot.png\n")

sink()
