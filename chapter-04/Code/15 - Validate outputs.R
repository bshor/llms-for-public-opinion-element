# Validation schema ----
validation_schema <- type_object(
  "Evaluate whether an annotation matches a survey response.",
  check = type_enum(c("YES", "NO")),
  explanation = type_string()
)

# Validation prompt ----
validation_prompt <- paste(
  "Evaluate whether the assigned tariff annotation matches the response.",
  "Consider both the tariff position and the reasoning categories.",
  sep = "\n"
)

# Example validation input ----
validation_input <- paste(
  validation_prompt,
  "",
  "Response:",
  test_response,
  "",
  "Assigned position:",
  results_run1$tariff_position_hybrid,
  "",
  "Assigned reasoning:",
  paste(results_run1$tariff_reasoning_hybrid, collapse = ", "),
  sep = "\n"
)

# Run validation ----
check <- chat$chat_structured(
  validation_input,
  type = validation_schema
)

check
