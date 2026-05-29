load_combined()  # Loads combined_results

n_issues <- n_distinct(combined_results$issue)

# Same predictors for every issue: party, gender, marital status, education
formula <- as.formula("~ Democrat + Republican + Female + Married + College_Grad")

all_coefs <- list()

for (i in 1:n_issues) {
  issue_col <- paste0("CC21_", issues$issue[i], "_t")  # CCES column name for this issue

  reg_data <- combined_results %>%
    filter(issue == issues$issue[i]) %>%
    left_join(dta1 %>% select(caseid, gender, married, ed, all_of(issue_col)), by = "caseid") %>%
    mutate(
      llm_support  = as.numeric(llm_response == "Support"),
      cces_support = as.numeric(.data[[issue_col]] == "Support"),  # Real response
      Female       = as.numeric(gender == "Female"),
      Married      = as.numeric(married == "married"),
      College_Grad = as.numeric(ed %in% c("a 4-year college degree", "a post-graduate degree (e.g., MA, MBA, PhD, JD, etc.)")),
      Democrat     = as.numeric(pid_text == "Democrat"),
      Republican   = as.numeric(pid_text == "Republican")  # Independents are the reference
    )

  # Fit OLS to both outcome variables; update() splices in the LHS
  cces_coefs <- tidy(lm(update(formula, cces_support ~ .), data = reg_data), conf.int = TRUE) %>%
    filter(term != "(Intercept)") %>%
    mutate(source = "CCES")

  llm_coefs <- tidy(lm(update(formula, llm_support ~ .), data = reg_data), conf.int = TRUE) %>%
    filter(term != "(Intercept)") %>%
    mutate(source = "LLM")

  # Keep only terms present in both models (guards against perfect separation)
  common_terms <- intersect(cces_coefs$term, llm_coefs$term)
  all_coefs[[i]] <- bind_rows(cces_coefs, llm_coefs) %>%
    filter(term %in% common_terms) %>%
    mutate(issue = issues$issue[i])
}

all_coefs <- bind_rows(all_coefs)

save(all_coefs, file = results_path("regression-coefs.Rdata"))
