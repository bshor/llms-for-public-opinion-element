sink("Output/07c-output.txt")

load_combined()  # Loads combined_results

# Accuracy by issue and party
heatmap_data <- combined_results %>%
  rename(party = pid_text) %>%
  group_by(issue, party) %>%
  summarize(accuracy = mean(match == "Correct"), n = n(), .groups = "drop")

p <- ggplot(heatmap_data, aes(x = party, y = issue, fill = accuracy)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = paste0(round(accuracy * 100), "%")),    # Show % in cells
            size = 3.5, color = "black") +
  scale_fill_gradient2(low = "#d4691e", mid = "white", high = "#2d8b7b",
                       midpoint = mean(heatmap_data$accuracy),  # White = average
                       labels = scales::percent) +
  labs(x = NULL, y = NULL, fill = "Accuracy",
       title = "Individual accuracy by issue and party") +
  theme_minimal() +
  theme(panel.grid = element_blank())

ggsave("Plots/07c-heatmap.png", p, width = 6, height = 5)
cat("Plot saved to Plots/07c-heatmap.png\n")

sink()
