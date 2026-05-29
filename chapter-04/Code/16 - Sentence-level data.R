# Reshape respondent responses into separate sentence variables ----

tariff_sentence_annotation_data <- tariff_annotation_data %>%
  select(pid, tariffs_part_words) %>%
  mutate(
    sentence_list = str_split(
      tariffs_part_words,
      "(?<=[.!?])\\s+"
    )
  ) %>%
  mutate(
    sentence_list = map(
      sentence_list,
      ~ .x[str_squish(.x) != ""]
    )
  ) %>%
  unnest_longer(sentence_list) %>%
  group_by(pid) %>%
  mutate(sentence_num = row_number()) %>%
  ungroup() %>%
  mutate(sentence_list = str_squish(sentence_list)) %>%
  pivot_wider(
    names_from = sentence_num,
    values_from = sentence_list,
    names_prefix = "sentence"
  )

# View sentence-level data ----
View(tariff_sentence_annotation_data)
