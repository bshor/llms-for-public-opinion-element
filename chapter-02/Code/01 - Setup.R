# 01 - Setup.R
# Shared definitions for subsequent scripts

library(ellmer)
library(tidyverse)
library(glue)
library(tictoc)
library(broom)
library(pscl)

# Model for this run. Defaults to a cloud (OpenAI) model; 03c overrides it with
# a local Ollama model. The backend is inferred from the name below.
active_model <- "gpt-5.4-mini"

# Ollama (local) model names contain a colon; OpenAI (cloud) names do not
use_local <- grepl(":", active_model)

# Tag for this run's saved files (colons replaced for valid filenames)
run_tag <- gsub(":", "-", active_model)

# Path to a Processed/ results file for the current run
results_path <- function(name) {
  file.path("Processed", paste0(run_tag, "-", name))
}

# Create output directories
walk(c("Output", "Processed", "Plots", "Tables"), dir.create, showWarnings = FALSE)

# Survey response schema
survey_response_schema <- type_object(
  opinion = type_integer("1 to indicate support, 0 to indicate opposition"),
  explanation = type_string("Brief explanation for the opinion"),
  confidence = type_enum("Confidence level", values = c("High", "Medium", "Low"))
)

# Load CCES 2021 data
dta1 <- read_csv("Data/cces21.csv", show_col_types = FALSE)
issues <- read_csv("Data/cces21_issues.csv", show_col_types = FALSE)

# Build system prompt from CCES respondent demographics
build_prompt <- function(i) {
  glue(
    "It is 2021. ",
    "You are {dta1$age[i]} years old. ",
    "You are {dta1$married[i]}. ",
    "You are {dta1$race_id[i]}. ",
    "You are {dta1$gender[i]}. ",
    "You have {dta1$ed[i]}. ",
    "You make {dta1$income[i]} per year. ",
    "You live in the United States. ",
    "You are {dta1$ideology[i]}. ",
    "You are {dta1$registered[i]}. ",
    "You are a {dta1$pid_text[i]}. ",
    "You {dta1$pol_interest[i]} pay attention to what's going on in government and politics. ",
    "Provide responses from this person's perspective. ",
    "Use only knowledge about politics that they would have."
  )
}
