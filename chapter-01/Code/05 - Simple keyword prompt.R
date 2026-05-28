## Non-CREATE prompt ----
chat <- chat_openai(model = "gpt-5.4-mini") # Resetting the conversation
chat$chat("Can you give me the keywords for research topic 'affective polarization'")
