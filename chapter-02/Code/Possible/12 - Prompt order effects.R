sink("Output/10-output.txt")

i <- 42                                                  # Select respondent
issue_index <- 1                                         # Select issue

prompt_original <- build_prompt(i)
prompt_lines <- str_split(prompt_original, "\\. ")[[1]]
question <- glue("Do you support or oppose the following policy: {issues$question[issue_index]}?")

tic()
responses <- map_dfr(1:10, ~ {                           # Query 10 times with random order
  set.seed(.x)                                           # Different seed each iteration
  prompt_shuffled <- paste(sample(prompt_lines), collapse = ". ")

  chat <- chat_openai(
    model = "gpt-5.4-nano",
    system_prompt = prompt_shuffled,
    echo = "none"
  )

  response <- chat$chat_structured(question, type = survey_response_schema)
  tibble(iteration = .x, opinion = response$opinion, confidence = response$confidence)
})
toc()

responses <- responses %>%
  mutate(position = ifelse(opinion == 1, "Support", "Oppose"))

responses %>% print()

response_summary <- responses %>%
  count(position) %>%
  mutate(percent = round(n / sum(n) * 100, 1))

print(glue("
Issue: {issues$issue[issue_index]}
Response distribution across 10 randomized prompts:
{paste(response_summary$position, ': ', response_summary$n, ' (', response_summary$percent, '%)', collapse = '\n', sep = '')}
\n"))

sink()
