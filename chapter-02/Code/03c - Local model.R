# Optional: Run the same pipeline with a local model via Ollama.
# Requires: Ollama running locally, model pulled with: ollama pull granite3.2:8b-instruct-q4_K_M

sink("Output/03c-output.txt")

ollama_model <- "granite3.2:8b-instruct-q4_K_M"
n_target <- 100

# Incremental: load existing or start fresh
if (file.exists("Processed/local-all_results.rds")) {
  all_results <- readRDS("Processed/local-all_results.rds")
} else {
  all_results <- list()
}

existing_ids <- seq_along(all_results)
missing_ids <- setdiff(1:n_target, existing_ids)
cat("Model:", ollama_model, "\n")
cat("Found:", length(existing_ids), "existing,", length(missing_ids), "to query\n")

tic()
for (resp_id in missing_ids) {
  chat <- chat_ollama(
    model = ollama_model,
    system_prompt = build_prompt(resp_id),
    echo = "none"
  )

  prompts <- as.list(glue("Do you support or oppose the following policy: {issues$question[1:10]}?"))

  results <- parallel_chat_structured(
    chat,
    prompts,
    type = survey_response_schema,
    include_tokens = TRUE
  )

  all_results[[resp_id]] <- annotate_results(results, resp_id)

  saveRDS(all_results, "Processed/local-all_results.rds")  # Save after each respondent
  cat("Respondent", resp_id, "done\n")
}
toc()

# Build combined results
combined_results <- build_combined(all_results)

save(combined_results, file = "Processed/local-combined_results.Rdata")

combined_results %>%
  select(caseid, respondent, issue, real_response, llm_response, match, confidence) %>%
  slice_sample(n = 15) %>%
  print()

print(glue("
Total queries: {nrow(combined_results)}
Total input tokens: {sum(combined_results$input_tokens)}
Total output tokens: {sum(combined_results$output_tokens)}
"))

sink()
