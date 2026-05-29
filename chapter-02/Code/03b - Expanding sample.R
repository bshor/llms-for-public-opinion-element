sink("Output/03b-output.txt")

n_target <- 100                    # Target sample size

# Load existing results
f_all <- results_path("all_results.rds")
all_results <- if (file.exists(f_all)) readRDS(f_all) else list()

existing_ids <- seq_along(all_results)  # Indices of existing results
missing_ids <- setdiff(1:n_target, existing_ids)

cat("Found existing:", paste(existing_ids, collapse = ", "), "\n")
cat("Querying:", paste(missing_ids, collapse = ", "), "\n")

tic()
for (resp_id in missing_ids) {    # Loop over missing respondents only
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

saveRDS(all_results, results_path("all_results.rds")) # Save expanded list

all_results <- readRDS(results_path("all_results.rds"))
combined_results <- build_combined(all_results)

save(combined_results, file = results_path("combined_results.Rdata"))

combined_results %>%
  select(caseid, respondent, issue, real_response, llm_response, match, confidence) %>%
  slice_sample(n = 15) %>%       # Show random sample
  print()

sink()

sink("Output/03b-summary-output.txt")
cat(glue("
Total queries: {nrow(combined_results)}
Total input tokens: {sum(combined_results$input_tokens)}
Total output tokens: {sum(combined_results$output_tokens)}
Total cost: ${round(sum(combined_results$cost), 2)}
\n"))
sink()
