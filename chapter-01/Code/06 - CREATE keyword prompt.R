## CREATE prompt ----
chat <- chat_openai(model = "gpt-5.4-mini")
chat$chat("You are an experienced researcher specializing in public opinion and political behavior.
          Please suggest some keywords related to my research topic which is 'affective polarization'.
          Analyze the topic 'affective polarization' and use your extensive database to identify the most relevant and frequently associated topics, terms, and phrases.
          List the result in bullet points. 
          Keywords related to affective polarization: partisan hostility, social identity and affect. 
          Please give me a table.")
