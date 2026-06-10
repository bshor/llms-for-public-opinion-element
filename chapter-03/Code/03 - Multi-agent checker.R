answer_checker_model <- "gpt-5.4-nano"
answer_checker_prompt <- paste(
  "You are an expert at supervising qualitative survey interviews.",
  "Review whether the respondent gives a serious, on-topic answer.",
  "Return 'yes' if the answer is serious and on-topic.",
  "Return 'no' if it is non-serious or off-topic."
)

ask_checked_next_question <- function(interview_to_time,
                                      max_questions = 3,
                                      model = interviewer_model,
                                      checker_model = answer_checker_model) {
  ## Set up interviewer and answer checker prompts ----
  interviewer <- chat_openai(model = model,
                             system_prompt = tariff_interviewer_prompt)

  answer_check <- chat_openai(model = checker_model,
                              system_prompt = answer_checker_prompt)
  for(i in seq_len(max_questions)) {
    check_answer <- answer_check$chat_structured("The text interview up to this time is as follows: \n", interview_to_time,".",
                                                 type = type_object(
                                                   serious = type_enum(
                                                     c("yes", "no"),
                                                     "Whether the respondent's answer was serious and on-topic."
                                                   )
                                                 ))   # Check response
    if(check_answer$serious == "no") { # Stop interview if not serious response
      cat("A non-serious or off-topic response was detected. Ending the interview.")
      break
    }
    next_question <- interviewer$chat("The text interview up to this time is as follows: \n", interview_to_time,". \n",
                                      "Ask the next follow-up question.")
    user_response <- readline(prompt = "Type your answer here: ")
    interview_to_time <- add_turn(interview_to_time, next_question, user_response)
  }
  ## Return checked question ----
  return(split_transcript(interview_to_time))
}
