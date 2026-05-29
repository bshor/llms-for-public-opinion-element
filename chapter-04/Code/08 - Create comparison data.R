# Create comparison dataset ----

# Load the human-coded dataset ----
human_coded_data <- read_csv("Data/human_coded_data.csv")

# Standardize ordering of reasoning categories ----
standardize_reasoning <- function(x) {
  if (is.na(x) || str_squish(x) == "" || str_to_lower(str_squish(x)) == "none") {
    return(NA_character_)
  }

  parts <- str_split(x, ",")[[1]] %>%
    str_squish() %>%
    unique() %>%
    sort()

  paste(parts, collapse = ", ")
}

# Merge datasets ----
comparison_data <- human_coded_data %>%
  mutate(
    pid = as.character(pid),
    human_tariff_position_factor = factor(
      human_tariff_position,
      levels = c("Support", "Neutral", "Oppose")
    ),
    human_tariff_position_num = case_when(
      human_tariff_position == "Support" ~ 1,
      human_tariff_position == "Neutral" ~ 2,
      human_tariff_position == "Oppose"  ~ 3,
      TRUE ~ NA_real_
    ),
    human_tariff_reasoning_standardized = vapply(
      human_tariff_reasoning,
      standardize_reasoning,
      character(1)
    )
  ) %>%
  select(
    pid,
    tariffs_part_words,
    human_tariff_position_factor,
    human_tariff_position_num,
    human_tariff_reasoning,
    human_tariff_reasoning_standardized
  ) %>%
  left_join(
    tariff_hybrid_annotation_data %>%
      mutate(
        pid = as.character(pid),
        tariff_reasoning_hybrid_standardized = vapply(
          tariff_reasoning_hybrid,
          standardize_reasoning,
          character(1)
        )
      ) %>%
      select(
        pid,
        tariff_position_hybrid_factor,
        tariff_position_hybrid_num,
        tariff_reasoning_hybrid,
        tariff_reasoning_hybrid_standardized
      ),
    by = "pid"
  )

View(comparison_data)
