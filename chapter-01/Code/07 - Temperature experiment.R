# Controlling the Output ----
## Prompt setup ----
author_prompt <- "You are an expert storyteller with a sly sense of humor.
                  You will be given the first few words of a story.
                  Continue the first paragraph of that story."
user_prompt <- "It was a dark and stormy "

## gpt-5.4-mini is a non-reasoning model that supports temperature control.
## (Full reasoning models, such as GPT-5.5, do not expose temperature directly.)
temperature_model <- "gpt-5.4-mini"

## Helper to run the same prompt at a given temperature ----
run_temp <- function(t) {
  chat <- chat_openai(model = temperature_model,
                      system_prompt = author_prompt,
                      params = params(temperature = t))
  chat$chat(user_prompt)
}

## Temperature experiment ----
run_temp(0) # Minimum temperature
run_temp(1) # Default temperature
run_temp(2) # Maximum temperature
