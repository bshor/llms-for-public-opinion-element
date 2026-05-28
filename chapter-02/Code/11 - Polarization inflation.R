sink("Output/11-output.txt")

load("Processed/ideal-points.Rdata")  # Loads ideal_points

# Calculate party medians by source
party_medians <- ideal_points %>%
  filter(party %in% c("Democrat", "Republican", "Independent")) %>%
  group_by(source, party) %>%
  summarize(median_ideal = median(ideal_point), .groups = "drop") %>%
  pivot_wider(names_from = party, values_from = median_ideal)

print(party_medians)

# Calculate polarization (R - D distance)
polarization <- party_medians %>%
  mutate(
    polarization = Republican - Democrat,
    independent_position = Independent
  ) %>%
  select(source, Democrat, Independent, Republican, polarization)

print(polarization)

# Calculate inflation metrics
polarization %>%
  pivot_longer(cols = c(Democrat, Independent, Republican, polarization),
               names_to = "metric", values_to = "value") %>%
  pivot_wider(names_from = source, values_from = value) %>%
  mutate(
    metric = ifelse(metric == "polarization", "R-D Polarization", metric),
    change_pct = (llm - human) / abs(human) * 100,
    across(c(human, llm), ~round(.x, 3)),
    change_pct = round(change_pct, 0)
  ) %>%
  write_csv("Tables/polarization-inflation.csv") %>%
  print()

sink()
