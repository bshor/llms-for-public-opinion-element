# benchmark_local.R
# Time a single respondent × 10 issues against a local Ollama model.
# Usage:
#   Rscript Code/benchmark_local.R                     # uses active_model from Setup.R
#   Rscript Code/benchmark_local.R qwen3.5:9b-q4_K_M  # override model

source("Code/01 - Setup.R")
source("Code/02b - Helper functions.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) active_model <- args[1]

cat("Model:", active_model, "\n")
cat("Respondent: 1\n")
cat("Issues: 10\n\n")

chat <- chat_ollama(
  model = active_model,
  system_prompt = build_prompt(1),
  echo = "none",
  api_args = list(think = FALSE)
)

prompts <- as.list(glue("Do you support or oppose the following policy: {issues$question[1:10]}?"))

tic()
results <- parallel_chat_structured(
  chat,
  prompts,
  type = survey_response_schema,
  include_tokens = TRUE
)
t <- toc(quiet = TRUE)

elapsed <- round(t$toc - t$tic, 1)
result_df <- annotate_results(results, 1)

cat(glue("
Elapsed:       {elapsed} sec
Input tokens:  {sum(results$input_tokens)}
Output tokens: {sum(results$output_tokens)}
Accuracy:      {sum(result_df$match == 'Correct')}/10
\n"))

print(result_df %>% select(issue, real_response, llm_response, match, confidence))
