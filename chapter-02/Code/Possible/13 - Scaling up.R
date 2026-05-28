sink("Output/11-output.txt")

tic()

all_results_scaled <- list()

for (resp_id in 1:100) {          # Loop over 100 respondents
  chat <- chat_openai(
    model = "gpt-5.4-nano",
    system_prompt = build_prompt(resp_id),
    echo = "none"
  )

  prompts <- as.list(glue("Do you support or oppose the following policy: {issues$question}?"))

  results <- parallel_chat_structured( # Query all 30 issues
    chat,
    prompts,
    type = survey_response_schema,
    include_tokens = TRUE,
    include_cost = TRUE
  )

  all_results_scaled[[resp_id]] <- annotate_results(results, resp_id, n_issues = 30)
}

combined_results_scaled <- bind_rows(all_results_scaled)

toc()

summary_scaled <- combined_results_scaled %>%
  summarize(
    total_queries = n(),
    total_cost = sum(cost),
    overall_accuracy = mean(match == "Correct")
  )

print(glue_data(summary_scaled, "
Total queries: {total_queries}
Total cost: ${round(total_cost, 2)}
Overall accuracy: {round(overall_accuracy * 100, 1)}%
\n"))

write_csv(combined_results_scaled, "Processed/scaled-combined_results.csv")

sink()
