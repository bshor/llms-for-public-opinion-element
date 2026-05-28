sink("Output/06-output.txt")

load_combined()  # Loads combined_results

combined_results %>%
  count(confidence) %>%
  mutate(percent = round(n / sum(n) * 100, 1)) %>%        # Distribution of confidence
  print()

# Filter by confidence level
high_conf <- combined_results %>% filter(confidence == "High")
med_low_conf <- combined_results %>% filter(confidence %in% c("Medium", "Low"))

tibble(
  level = c("All", "High", "Medium/Low"),
  n = c(nrow(combined_results), nrow(high_conf), nrow(med_low_conf)),
  accuracy = c(
    mean(combined_results$match == "Correct"),
    mean(high_conf$match == "Correct"),
    mean(med_low_conf$match == "Correct")
  ),
  pre = c(
    calc_pre(combined_results$real_response, combined_results$match),
    calc_pre(high_conf$real_response, high_conf$match),
    calc_pre(med_low_conf$real_response, med_low_conf$match)
  )
) %>%
  print() -> comparison

print("Accuracy by confidence level:")
glue_data(comparison, "  {level}: {n} ({round(accuracy * 100, 1)}% accurate, PRE = {round(pre, 3)})\n")

improvement_acc <- round((comparison$accuracy[2] - comparison$accuracy[3]) * 100, 1)
improvement_pre <- round(comparison$pre[2] - comparison$pre[3], 3)

print(glue("High vs Medium/Low improvement: +{improvement_acc} percentage points (accuracy), +{improvement_pre} (PRE)"))

sink()
