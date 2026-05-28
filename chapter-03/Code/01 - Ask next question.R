# Function to ask follow-up questions
library(ellmer)

interviewer_model <- "gpt-5.4"
tariff_interviewer_prompt <- paste(
  "You are an expert qualitative interviewer speaking with an American voter.",
  "Ask follow-up questions to understand why the respondent thinks tariffs",
  "are good or bad for the United States. Probe for specific reasons,",
  "strength of opinion, openness to counter-arguments, language, emotion,",
  "tone, and thoughts or feelings about tariffs. Ask for clarification when",
  "responses are vague. Ask no more than three follow-up questions.",
  "Do not ask leading questions or provide response options.",
  "Ask only one question at a time."
)

add_turn <- function(transcript, interviewer_text, respondent_text) {
  paste0(transcript,
         "Interviewer: ", interviewer_text, "<br>",
         "Respondent: ", respondent_text, "<br>")
}

split_transcript <- function(transcript) {
  strsplit(transcript, "<br>", fixed = TRUE)[[1]]
}

ask_next_question <- function(interview_to_time,
                              max_questions = 3,
                              model = interviewer_model) {
  interviewer <- chat_openai(model = model,
                             system_prompt = tariff_interviewer_prompt)
  ## Generate follow-up question ----
  for(i in seq_len(max_questions)) {
    next_question <- interviewer$chat("The text interview up to this time is as follows: \n", interview_to_time,". \n",
                                      "Ask the next follow-up question.")
    user_response <- readline(prompt = "Type your answer here: ")
    interview_to_time <- add_turn(interview_to_time, next_question, user_response)
  }
  return(split_transcript(interview_to_time))
}
