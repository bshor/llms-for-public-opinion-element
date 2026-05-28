# Load packages
library(ellmer)
library(glue)

# Define a demographic persona
persona <- glue(
  "It is 2021. You are 45 years old. You are a White woman. ",
  "You have a 4-year college degree. You make $75,000 per year. ",
  "You live in the United States. You are a Republican. ",
  "Provide responses from this person's perspective."
)

# Define response schema
survey_response_schema <- type_object(
  opinion = type_integer("1 to indicate support, 0 to indicate opposition"),
  explanation = type_string("Brief explanation for the opinion"),
  confidence = type_enum("Confidence level", values = c("High", "Medium", "Low"))
)

# Create chat object with persona as system prompt
chat <- chat_openai(
  model = "gpt-5.4-nano",
  system_prompt = persona,
  echo = "none"
)

# Get structured response
response <- chat$chat_structured(
  "Do you support or oppose expanding Medicare to a single comprehensive public health care program that would cover all Americans?",
  type = survey_response_schema
)

# View results
glue(
  "Opinion (1 = support, 0 = oppose): {response$opinion}
  Confidence: {response$confidence}
  Explanation: {response$explanation}"
)
