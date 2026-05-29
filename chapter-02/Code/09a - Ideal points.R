sink("Output/09a-output.txt")

load_combined()  # Loads combined_results

# Stack CCES and LLM responses vertically
stacked <- combined_results %>%
  mutate(human = as.numeric(real_response == "Support"),
         llm = as.numeric(llm_response == "Support")) %>%
  pivot_longer(cols = c(human, llm), names_to = "source", values_to = "support") %>%
  mutate(respondent_id = paste0(source, "_", caseid))

# Create wide vote matrix and respondent metadata
votes <- stacked %>%
  pivot_wider(id_cols = respondent_id, names_from = issue, values_from = support) %>%
  select(-respondent_id) %>%
  as.data.frame()

respondent_data <- stacked %>%
  distinct(respondent_id, caseid, source, pid_text, pid3) %>%
  as.data.frame()

# Create rollcall object
rc <- rollcall(
  data = votes,
  legis.data = respondent_data,
  legis.names = respondent_data$respondent_id,
  desc = "Combined CCES and LLM responses"
)

# Estimate ideal points using party as starting values
xstart <- as.matrix(respondent_data$pid3)

ideal_model <- ideal(rc, d = 1, normalize = TRUE,
                     maxiter = 500, burnin = 10, thin = 1,
                     startvals = list(x = xstart), verbose = FALSE)

# Extract and save ideal points
ideal_points <- respondent_data %>%
  as_tibble() %>%
  rename(party = pid_text) %>%
  mutate(ideal_point = ideal_model$xbar[, "D1"])

save(ideal_points, file = results_path("ideal-points.Rdata"))

cat("Ideal points estimated and saved.\n")

sink()
