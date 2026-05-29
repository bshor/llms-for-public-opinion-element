# 02b - Helper functions.R
# Reusable functions for annotating results and computing accuracy metrics

# Annotate LLM results with real responses
annotate_results <- function(results, resp_id, n_issues = 10) {
  real_cols <- paste0("CC21_", issues$issue[1:n_issues], "_t")
  results %>%
    mutate(
      caseid = dta1$caseid[resp_id],
      respondent = resp_id,
      issue = issues$issue[1:n_issues],
      real_response = as.character(dta1[resp_id, real_cols]),
      llm_response = ifelse(opinion == 1, "Support", "Oppose"),
      match = ifelse(llm_response == real_response, "Correct", "Incorrect"),
      .before = 1
    )
}

# Proportionate reduction in error
calc_pre <- function(real_response, match) {
  keep <- !is.na(match) & !is.na(real_response)
  real_response <- real_response[keep]
  match <- match[keep]
  n <- length(real_response)
  support <- sum(real_response == "Support")
  e_baseline <- min(support, n - support)
  e_model <- sum(match == "Incorrect")
  if (e_baseline == 0) return(NA_real_)
  (e_baseline - e_model) / e_baseline
}

# Load combined results for the current run (respects run_tag global)
load_combined <- function() {
  load(results_path("combined_results.Rdata"), envir = parent.frame())
}

# Build combined results with party ID
build_combined <- function(all_results) {
  bind_rows(all_results) %>%
    left_join(dta1 %>% select(caseid, pid_text), by = "caseid") %>%
    mutate(pid3 = case_when(
      pid_text == "Democrat" ~ -1, pid_text == "Republican" ~ 1, TRUE ~ 0
    ))
}
