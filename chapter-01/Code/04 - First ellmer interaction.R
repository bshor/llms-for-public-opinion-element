### Load libraries ----
library(ellmer)
library(usethis)

### First interaction with ellmer ----
chat <- chat_openai(model = "gpt-5.4-mini") # Set up the chat - this will keep track of your history as well
response <- chat$chat("Tell me three jokes about statisticians.", echo = F) # Start the conversation
response # Get the saved response
response2 <- chat$chat("Tell me three more jokes about statisticians.", echo = F)
response2

chat$get_turns() # Get the full conversation text
chat$get_turns()[[4]] # Get the LLM's second set of jokes
chat$get_turns()[[4]]@text # Pull out just the text.
jokes <- Filter(function(turn) turn@role == "assistant", chat$get_turns()) # Get just the LLM responses
lapply(jokes, function(t) t@text) # Get just the text of the jokes.