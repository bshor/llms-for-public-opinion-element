sink("Output/03a-output.txt")

all_results <- list()

tic()
for (resp_id in 1:10) {           # Loop over 10 respondents
  chat <- chat_openai(
    model = active_model,
    system_prompt = build_prompt(resp_id),
    echo = "none"
  )

  prompts <- as.list(glue("Do you support or oppose the following policy: {issues$question[1:10]}?"))

  results <- parallel_chat_structured( # Query 10 issues in parallel
    chat,
    prompts,
    type = survey_response_schema,
    include_tokens = TRUE,
    include_cost = TRUE
  )

  all_results[[resp_id]] <- annotate_results(results, resp_id)
}
toc()

saveRDS(all_results, results_path("all_results.rds"))   # Save list to disk

combined_results <- bind_rows(all_results)

combined_results %>%
  select(caseid, respondent, issue, real_response, llm_response, match, confidence) %>%
  slice_sample(n = 15) %>%       # Show random sample
  print()

print(glue("
Total queries: {nrow(combined_results)}
Total input tokens: {sum(combined_results$input_tokens)}
Total output tokens: {sum(combined_results$output_tokens)}
Total cost: ${round(sum(combined_results$cost), 2)}
\n"))

sink()
