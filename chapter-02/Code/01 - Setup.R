# 01 - Setup.R
# Shared definitions for subsequent scripts

library(ellmer)
library(tidyverse)
library(glue)
library(tictoc)
library(broom)
library(pscl)

# Use local (Ollama) or cloud (OpenAI) results?
use_local <- FALSE

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
