# Hybrid coding workflow with structured responses ----

chat <- chat_openai(
  system_prompt = "You are a professional research assistant coding survey responses about tariffs.",
  model = "gpt-5.4-mini",
  params = params(temperature = 0),
  echo = "none"
)

# Structured response: allowed reasoning categories ----
reasoning_categories <- c(
  "Domestic Industry Protection",
  "Job Creation",
  "Price Increase Concern",
  "Economic Impact",
  "Equity and Fairness",
  "Nationalism and Economic Independence",
  "Lack of Understanding/Indecision",
  "Retaliation and Trade Wars",
  "Political and Strategic Considerations"
)

# Structured response: output schema ----
tariff_schema <- type_object(
  "Code one survey response about tariffs.",
  tariff_position_hybrid = type_enum(
    c("Support", "Neutral", "Oppose")
  ),
  tariff_position_hybrid_num = type_integer(),
  tariff_reasoning_hybrid = type_array(
    type_enum(reasoning_categories)
  ),
  tariff_supporting_excerpt = type_string(),
  tariff_response_summary = type_string()
)

# Researcher-defined coding guide supplied at inference time ----
tariff_prompt <- paste(
  "Use this coding guide:",
  "",
  "1 = Support tariffs: favors tariffs or emphasizes job protection, domestic industry protection, economic independence, or strategic leverage.",
  "2 = Neutral or mixed: expresses uncertainty, insufficient information, ambivalence, or both positive and negative views.",
  "3 = Oppose tariffs: criticizes tariffs or emphasizes higher prices, inflation, inefficiency, retaliation, or trade wars.",
  "",
  "If the response is unclear, ambivalent, conflicted, or mixed, use Neutral.",
  "Use only the listed reasoning categories.",
  sep = "\n"
)

# Structured annotation function ----
annotate_tariff_response <- function(text) {
  chat$chat_structured(
    paste(tariff_prompt, "\n\nResponse:\n", text),
    type = tariff_schema
  )
}

# Create list of prompts for parallel processing ----
tariff_prompts <- as.list(
  paste(tariff_prompt, "\n\nResponse:\n", tariff_annotation_data$tariffs_part_words)
)

# Run structured annotation in parallel ----
tariff_labels <- parallel_chat_structured(
  chat = chat,
  prompts = tariff_prompts,
  type = tariff_schema
)

# Combine results with original data ----
tariff_hybrid_annotation_data <- tariff_annotation_data %>%
  mutate(pid = as.character(pid)) %>%
  bind_cols(tariff_labels) %>%
  mutate(
    tariff_position_hybrid_num = case_when(
      tariff_position_hybrid == "Support" ~ 1,
      tariff_position_hybrid == "Neutral" ~ 2,
      tariff_position_hybrid == "Oppose"  ~ 3,
      TRUE ~ NA_real_
    ),
    tariff_position_hybrid_factor = factor(
      tariff_position_hybrid,
      levels = c("Support", "Neutral", "Oppose")
    ),
    tariff_reasoning_hybrid = map_chr(
      tariff_reasoning_hybrid,
      ~ paste(.x, collapse = ", ")
    )
  )

View(tariff_hybrid_annotation_data)
