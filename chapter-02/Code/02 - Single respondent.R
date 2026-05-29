source("Code/01 - Setup.R")

sink("Output/02-output.txt")

i <- 42                          # Select respondent from CCES
system_prompt <- build_prompt(i) # Build demographic prompt

chat <- chat_openai(             # Initialize chat with system prompt
  model = active_model,
  system_prompt = system_prompt,
  echo = "none"
)

tic()
response <- chat$chat_structured( # Query with structured output
  "Do you support or oppose expanding Medicare to a single comprehensive public health care program that would cover all Americans?",
  type = survey_response_schema
)
toc()

print(glue(                      # Display results
  "
  Respondent 1: {dta1$age[i]}yo {dta1$race_id[i]} {dta1$gender[i]} {dta1$pid_text[i]}

  Real CCES response: {dta1$CC21_320a_t[i]}
  LLM opinion: {ifelse(response$opinion == 1, 'Support', 'Oppose')}
  LLM confidence: {response$confidence}
  LLM reasoning: {response$explanation}
  \n"
))

sink()
