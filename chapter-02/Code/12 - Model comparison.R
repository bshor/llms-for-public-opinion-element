# 12 - Model comparison.R
# Compare all model runs in Processed/: overall and per-issue/per-party accuracy
# and PRE, polarization inflation, and regression coefficients.

source("Code/01 - Setup.R")
source("Code/02b - Helper functions.R")

sink("Output/12-output.txt", split = TRUE)

print_full <- function(x) print(x, n = Inf, width = Inf)

# ---- Load all tagged combined_results files -----------------------------------

result_files <- list.files("Processed", pattern = "-combined_results\\.Rdata$",
                           full.names = TRUE)

all_results <- map(result_files, function(f) {
  tag <- sub("-combined_results\\.Rdata$", "", basename(f))
  e <- new.env()
  load(f, envir = e)
  get("combined_results", envir = e) %>% mutate(model = tag)
}) %>%
  bind_rows()

models <- unique(all_results$model)
cat("Models found:", paste(models, collapse = ", "), "\n\n")

# ---- Overall accuracy and PRE ------------------------------------------------

cat("=== Overall accuracy and PRE ===\n")
all_results %>%
  group_by(model) %>%
  summarise(
    n         = n(),
    accuracy  = round(mean(match == "Correct", na.rm = TRUE), 3),
    pre       = round(calc_pre(real_response, match), 3),
    .groups   = "drop"
  ) %>%
  print_full()

# ---- PRE by issue ------------------------------------------------------------

cat("\n=== PRE by issue ===\n")
all_results %>%
  group_by(model, issue) %>%
  summarise(pre = round(calc_pre(real_response, match), 3), .groups = "drop") %>%
  arrange(issue, model) %>%
  print_full()

# ---- Accuracy and PRE by party -----------------------------------------------

party_summary <- all_results %>%
  group_by(model, pid_text) %>%
  summarise(
    accuracy = round(mean(match == "Correct", na.rm = TRUE), 3),
    pre      = round(calc_pre(real_response, match), 3),
    .groups  = "drop"
  )

cat("\n=== Accuracy by party ===\n")
party_summary %>%
  select(pid_text, model, accuracy) %>%
  arrange(pid_text, model) %>%
  print_full()

cat("\n=== PRE by party ===\n")
party_summary %>%
  select(pid_text, model, pre) %>%
  arrange(pid_text, model) %>%
  print_full()

# ---- Polarization inflation from ideal points --------------------------------

ideal_files <- list.files("Processed", pattern = "-ideal-points\\.Rdata$",
                          full.names = TRUE)

if (length(ideal_files) > 0) {
  cat("\n=== Polarization inflation (median ideal points by party) ===\n")
  map(ideal_files, function(f) {
    tag <- sub("-ideal-points\\.Rdata$", "", basename(f))
    e <- new.env()
    load(f, envir = e)
    get("ideal_points", envir = e) %>%
      group_by(source, party) %>%
      summarise(median_ip = round(median(ideal_point), 3), .groups = "drop") %>%
      mutate(model = tag)
  }) %>%
    bind_rows() %>%
    arrange(source, party, model) %>%
    print_full()

  cat("\n=== Polarization distance (Republican - Democrat median) ===\n")
  map(ideal_files, function(f) {
    tag <- sub("-ideal-points\\.Rdata$", "", basename(f))
    e <- new.env()
    load(f, envir = e)
    get("ideal_points", envir = e) %>%
      filter(party %in% c("Democrat", "Republican")) %>%
      group_by(source, party) %>%
      summarise(median_ip = median(ideal_point), .groups = "drop") %>%
      pivot_wider(names_from = party, values_from = median_ip) %>%
      mutate(distance = round(Republican - Democrat, 3), model = tag) %>%
      select(source, distance, model)
  }) %>%
    bind_rows() %>%
    arrange(source, model) %>%
    print_full()
}

# ---- Regression coefficients -------------------------------------------------

coef_files <- list.files("Processed", pattern = "-regression-coefs\\.Rdata$",
                         full.names = TRUE)

if (length(coef_files) > 0) {
  cat("\n=== Partisan regression coefficients ===\n")
  map(coef_files, function(f) {
    tag <- sub("-regression-coefs\\.Rdata$", "", basename(f))
    e <- new.env()
    load(f, envir = e)
    get("all_coefs", envir = e) %>%
      filter(term %in% c("Democrat", "Republican")) %>%
      group_by(source, term) %>%
      summarise(mean_estimate = round(mean(estimate), 3), .groups = "drop") %>%
      mutate(model = tag)
  }) %>%
    bind_rows() %>%
    arrange(source, term, model) %>%
    print_full()
}

sink()
cat("Output written to Output/12-output.txt\n")
