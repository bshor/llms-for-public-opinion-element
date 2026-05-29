sink("Output/04b-output.txt")

load_combined()  # Loads combined_results

# Party-specific majority baseline: the modal opinion within each party, per issue
party_majority <- combined_results %>%
  group_by(pid_text, issue) %>%
  summarize(
    party_majority = ifelse(mean(real_response == "Support") >= 0.5,
                            "Support", "Oppose"),
    .groups = "drop"
  )

# Merge party baseline and compute errors
party_pre_df <- combined_results %>%
  left_join(party_majority, by = c("pid_text", "issue")) %>%
  mutate(
    error_model = match == "Incorrect",
    error_party = real_response != party_majority   # Party baseline errors
  )

# Compare standard PRE vs party PRE
party_pre_df %>%
  summarize(
    n = n(),
    e_majority = min(sum(real_response == "Support"),
                     sum(real_response == "Oppose")),
    e_party = sum(error_party),
    e_model = sum(error_model),
    pre = (e_majority - e_model) / e_majority,
    party_pre = (e_party - e_model) / e_party
  ) %>%
  mutate(across(c(pre, party_pre), ~round(.x, 3))) %>%
  write_csv("Tables/pre-comparison.csv") %>%
  print()

# Party PRE by issue
party_pre_df %>%
  group_by(issue) %>%
  summarize(
    e_party = sum(error_party),
    e_model = sum(error_model),
    party_pre = ifelse(e_party == 0, NA, (e_party - e_model) / e_party)
  ) %>%
  arrange(desc(party_pre)) %>%
  print()

sink()
