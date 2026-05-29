# Optional: Run the same pipeline with a local model via Ollama.
# Set ollama_model in 01 - Setup.R and use_local <- TRUE before sourcing.
# Requires: Ollama running locally with the target model already pulled.

source("Code/01 - Setup.R")
source("Code/02b - Helper functions.R")

sink(paste0("Output/03c-", run_tag, "-output.txt"))

n_target <- 100

# Incremental: load existing or start fresh
f_all <- results_path("all_results.rds")
all_results <- if (file.exists(f_all)) readRDS(f_all) else list()

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

  saveRDS(all_results, results_path("all_results.rds"))  # Save after each respondent
  cat("Respondent", resp_id, "done\n")
}
toc()

# Build combined results
combined_results <- build_combined(all_results)
save(combined_results, file = results_path("combined_results.Rdata"))

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
