sink("Output/07-output.txt")

load_combined()  # Loads combined_results

combined_results %>%
  rename(party = pid_text) %>%
  group_by(party) %>%
  summarize(
    n_respondents = n_distinct(respondent),
    accuracy = mean(match == "Correct"),
    pre = calc_pre(real_response, match)
  ) %>%
  arrange(desc(accuracy)) %>%
  mutate(across(c(accuracy, pre), ~round(.x, 3))) %>%
  write_csv("Tables/party-metrics.csv") %>%
  print()

sink()
