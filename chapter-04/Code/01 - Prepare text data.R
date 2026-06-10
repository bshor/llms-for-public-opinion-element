# Prepare respondent-level tariff text for annotation ----

# Load libraries ----
library(tidyverse)
library(dsl)
library(ellmer)
library(igraph)
library(ggraph)
library(openai)

# Load the dataset ----
tariff_data_sample <- read_csv("Data/tariff_data_sample.csv")

# Dataset includes variables:
#   pid = unique respondent identifier
#   tariffs_conversation = full tariff interview transcript

# Function to extract and clean participant text ----
clean_participant_text <- function(text) {

  # Handle missing or empty responses ----
  if (is.na(text) || str_squish(text) == "") {
    return(NA_character_)
  }

  # Extract all participant turns:
  participant_turns <- str_extract_all(
    text,
    "Participant:\\s*(.*?)(?=\\s*AI:|$)"
  )[[1]]

  # Remove speaker label ----
  participant_turns <- str_remove(participant_turns, "^Participant:\\s*")

  # Remove empty turns ----
  participant_turns <- participant_turns[str_squish(participant_turns) != ""]

  # If no participant text was found, return NA ----
  if (length(participant_turns) == 0) {
    return(NA_character_)
  }

  # Remove extra whitespace within turns ----
  participant_turns <- str_squish(participant_turns)

  # Collapse all participant turns into one string ----
  participant_text <- paste(participant_turns, collapse = " ")

  # Final cleanup ----
  participant_text <- str_replace_all(
    participant_text,
    "[^[:alnum:][:space:][:punct:]]",
    ""
  )
  participant_text <- str_squish(participant_text)

  return(participant_text)
}

# Apply cleaning function to tariff interview data ----
tariff_annotation_data <- tariff_data_sample %>%
  mutate(
    tariffs_part_words  = map_chr(tariffs_conversation, clean_participant_text),
    tariffs_part_nwords = str_count(tariffs_part_words, "\\S+")
  ) %>%
  select(pid, tariffs_part_words, tariffs_part_nwords) %>%
  filter(!is.na(tariffs_part_words), tariffs_part_words != "")

# View prepared data ----
View(tariff_annotation_data)
