sink("Output/04-output.txt")

load_combined()  # Loads combined_results

combined_results %>%
  group_by(issue) %>%
  summarize(
    n = n(),
    accuracy = mean(match == "Correct"),
    correlation = cor(llm_response == "Support", real_response == "Support"),
    pre = calc_pre(real_response, match)
  ) %>%
  print()

combined_results %>%
  summarize(
    accuracy = mean(match == "Correct"),
    correlation = cor(llm_response == "Support", real_response == "Support"),
    pre = calc_pre(real_response, match)
  ) %>%
  mutate(across(everything(), ~round(.x, 3))) %>%
  write_csv("Tables/overall-accuracy.csv") %>%
  print()

sink()
