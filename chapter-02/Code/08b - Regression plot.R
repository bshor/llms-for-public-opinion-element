sink("Output/08b-output.txt")

load(results_path("regression-coefs.Rdata"))  # Loads all_coefs

# Plot coefficient comparison
all_coefs %>%
  mutate(
    term = recode(term, "College_Grad" = "College+"),
    term = factor(term, levels = rev(c("Democrat", "Republican", "Female", "Married", "College+")))
  ) %>%
  ggplot(aes(x = term, y = estimate, ymin = conf.low, ymax = conf.high, color = source)) +
  geom_pointrange(position = position_dodge(width = 0.5), size = 0.5) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  facet_wrap(~ issue, nrow = 2) +
  coord_flip() +
  scale_color_manual(values = c("CCES" = "orange", "LLM" = "green4")) +
  labs(
    title = "Regression coefficients: CCES vs LLM",
    x = "Predictor",
    y = "Coefficient (95% CI)",
    color = "Source"
  ) +
  theme_minimal()

ggsave("Plots/08b-regression-comparison.png", width = 12, height = 5)
cat("Plot saved to Plots/08b-regression-comparison.png\n")

# Calculate party coefficient inflation
party_inflation <- all_coefs %>%
  filter(term %in% c("Democrat", "Republican")) %>%
  group_by(term, source) %>%
  summarize(mean_abs_coef = mean(abs(estimate)), .groups = "drop") %>%
  pivot_wider(names_from = source, values_from = mean_abs_coef) %>%
  mutate(pct_change = (LLM - CCES) / CCES * 100)

print("Party coefficient inflation:")
print(glue_data(party_inflation, "  {term}: {round(pct_change, 1)}% inflation")) 

sink()
