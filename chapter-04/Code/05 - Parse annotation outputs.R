# Binary transformation (1 = present, 0 = not present) ----

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

tariff_hybrid_annotation_data_binary <- tariff_hybrid_annotation_data

for (cat in reasoning_categories) {
  var_name <- str_to_lower(str_replace_all(cat, "[ /]", "_"))

  tariff_hybrid_annotation_data_binary[[var_name]] <- as.integer(
    str_detect(
      tariff_hybrid_annotation_data_binary$tariff_reasoning_hybrid,
      regex(cat, ignore_case = TRUE)
    )
  )

  tariff_hybrid_annotation_data_binary[[var_name]][
    is.na(tariff_hybrid_annotation_data_binary[[var_name]])
  ] <- 0
}

View(tariff_hybrid_annotation_data_binary)
