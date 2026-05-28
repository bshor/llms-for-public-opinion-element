library(shiny)
library(shinychat)
library(ellmer)
library(shinyjs)
library(bslib)

interviewer_model <- "gpt-5.4"
candidate_info_file <- "smithforcitycouncil.md"
max_interview_questions <- 4
exit_commands <- c("done", "no")

q_answer_prompt <- paste(
  "You are a public relations representative for John Smith,",
  "who is running for City Council in Columbus, OH.",
  "Your job is to answer questions from voters.",
  "Respond truthfully based only on the get_candidate_information tool.",
  "If you do not know the answer, apologize and say you do not know.",
  "End each response by asking if they have any more questions about John Smith."
)

q_asking_prompt <- paste(
  "You are an expert research interviewer hired by the campaign for",
  "John Smith for City Council in Columbus, OH. You will interact with a voter.",
  "Your goals are to learn:",
  "(1) what they think of John Smith as a candidate;",
  "(2) what they think of his stance on issues important to them;",
  "(3) what recommendations they have for improving life in Columbus;",
  "(4) what suggestions they have for getting Smith's message out to others.",
  "Ask follow-up questions or ask for elaboration when anything is unclear.",
  "Ask no more than four questions. Ask only one question at a time."
)

qa_greeting <- "Hi! I am here to answer any questions you may have about John Smith, a candidate for City Council in Columbus, OH. When you are ready to go, just type 'done' or 'no' into the text box. Please enter your question below and hit enter when you are ready."
interview_intro <- "Thank you for your questions! Now I am going to ask you a few questions about your impressions of and recommendations for John Smith. I will ask four questions."
first_interview_prompt <- "Please start the interview by asking for the respondent's general impression of John Smith."

#' Gets information on John Smith for City Council
#'
#' @return A markdown document with information about John Smith.
get_candidate_information <- function() {
  paste(readLines(candidate_info_file, warn = FALSE), collapse = "\n")
}

clean_command <- function(x) gsub("[[:punct:]]", "", tolower(trimws(x)))

## Define the UIs for the application ----
ui <- page_fillable(
  tags$head(
    tags$script(HTML("
    $(document).ready(function() {
      $(document).on('paste', 'input[type=text], textarea', function(e) {
        e.preventDefault();
      });
    });
  "))
  ),

  shinyjs::useShinyjs(),

  div(id = "introduction",
      h2("Introducing John Smith, Candidate for Columbus City Council."),
      h3("This survey has two parts."),
      h3("In the first part, you will be able to ask questions about John Smith, his background, and his stances on major issues."),
      h3("In the second part, you will be asked questions about what you think of John Smith."),
      h3("Click Next when ready to get started."),
      actionButton("start_btn", "Next", class = "btn-primary")),

  shinyjs::hidden(
    div(id = "qa_phase", chat_ui(id = "candidate_chat"))
  ),

  shinyjs::hidden(
    div(id = "interview_phase", chat_ui(id = "interview_chat_ui"))
  ),

  shinyjs::hidden(
    div(id = "thankyou_msg", h3("Thank you for chatting with us!"))
  )
)

## Define server ----
server <- function(input, output, session) {

  candidate_agent <- chat_openai(system_prompt = q_answer_prompt,
                                 model = interviewer_model,
                                 echo = "none")

  candidate_agent$register_tool(tool(
    get_candidate_information,
    "Gets information about John Smith for City Council in Columbus, OH. Used whenever someone asks for information about this candidate."
  ))

  interviewer_agent <- chat_openai(system_prompt = q_asking_prompt,
                                   model = interviewer_model,
                                   echo = "none")

  app_phase <- reactiveVal("intro") # intro, qa, interview, thanks
  interview_count <- reactiveVal(0)
  phase_ids <- c(intro = "introduction", qa = "qa_phase",
                 interview = "interview_phase", thanks = "thankyou_msg")

  show_phase <- function(phase) {
    app_phase(phase)
    invisible(lapply(phase_ids, shinyjs::hide))
    shinyjs::show(phase_ids[[phase]])
  }

  observeEvent(input$start_btn, {
    show_phase("qa")
    chat_append("candidate_chat", qa_greeting)
  })

  observeEvent(input$candidate_chat_user_input, {
    if (app_phase() != "qa") return()

    user_msg <- input$candidate_chat_user_input
    clean_msg <- clean_command(user_msg)

    if (clean_msg %in% exit_commands) {
      show_phase("interview")
      chat_append("interview_chat_ui", interview_intro)

      response <- interviewer_agent$chat(first_interview_prompt)
      chat_append("interview_chat_ui", response)
    } else {
      response <- candidate_agent$chat(user_msg)
      chat_append("candidate_chat", response)
    }
  })

  observeEvent(input$interview_chat_ui_user_input, {
    if (app_phase() != "interview") return()

    user_msg <- input$interview_chat_ui_user_input

    new_count <- interview_count() + 1
    interview_count(new_count)

    if (new_count < max_interview_questions) {
      response <- interviewer_agent$chat(user_msg)
      chat_append("interview_chat_ui", response)
    } else {
      show_phase("thanks")
    }
  })
}

shinyApp(ui = ui, server = server)
