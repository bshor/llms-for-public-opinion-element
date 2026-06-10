# Create a function that will start the interview. ----
interview_function <- function(next_question_function = ask_basic_next_question) {
  ## Ask opening question and get user response ----
  interview_question <- paste0("Overall, do you think increasing tariffs or fees on goods imported from trading partners will be good or bad for the United States?\n",
                               "Do you think they are: \nVery good, \nGood, \nNeither good nor bad, \nBad, \nVery bad?\n")

  cat(interview_question)

  user_response <- readline(prompt = "Type your answer here: ") # Receive and record response

  ## Set up chat ----
  interview <- next_question_function(paste0("Interviewer: ", interview_question, "<br>",
                                             "Respondent: ", user_response, "<br>"))

  cat("\nThank you for your responses!")
  return(interview) # Return the data from the chat that can be saved as an object
}
