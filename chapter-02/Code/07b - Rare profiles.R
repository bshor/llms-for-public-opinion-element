sink("Output/07b-output.txt")

load_combined()  # Loads combined_results

# Add gender and race from CCES data
results_demo <- combined_results %>%
  left_join(
    dta1 %>%
      select(caseid, gender, race_id),
    by = "caseid"
  )

# Aggregate MAE for a subgroup
compute_mae <- function(data, label) {
  errors <- data %>%
    group_by(issue) %>%
    summarize(
      absolute_error = abs(mean(llm_response == "Support") - mean(real_response == "Support"))
    )
  tibble(subgroup = label, n = n_distinct(data$respondent),
         mae = round(mean(errors$absolute_error), 3))
}

# Hierarchical subgroup labels: All -> Party -> Party x Gender -> Party x Race
results_demo <- results_demo %>%
  mutate(l1 = "All respondents", l2 = pid_text,
         l3 = paste(gender, pid_text), l4 = paste(race_id, pid_text))

subgroups <- list()
for (level in c("l1", "l2", "l3", "l4")) {
  for (group in unique(results_demo[[level]])) {
    subgroups <- bind_rows(subgroups,
      compute_mae(filter(results_demo, .data[[level]] == group), group))
  }
}
subgroups <- arrange(subgroups, desc(n))

print(subgroups, n = Inf)

# Visualize MAE vs. sample size
p <- ggplot(subgroups, aes(x = n, y = mae)) +
  geom_point(alpha = 0.6, size = 3) +
  geom_smooth(method = "loess", se = TRUE, color = "blue") +
  scale_x_log10() +
  labs(
    title = "Aggregate accuracy deteriorates for rare demographic profiles",
    x = "Subgroup size (log scale)",
    y = "Mean Absolute Error",
    caption = "Each point represents a demographic subgroup (party, party x gender, party x race)"
  ) +
  theme_minimal()

ggsave("Plots/07b-rare-profiles.png", p, width = 7, height = 5)
cat("Plot saved to Plots/07b-rare-profiles.png\n")

sink()
