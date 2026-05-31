"""
Code examples for Chapter 1, translated from R to Python.
This file is intentionally written so you can run it line-by-line in an
interactive console, like the R examples.

Install the core package:

    pip install openai

Set your API key in a .env file in this folder:

    OPENAI_API_KEY=your-key-here
"""

import os
from pathlib import Path

from openai import OpenAI


###########
# Setup
###########

# Load OPENAI_API_KEY from a .env file next to this script.
ROOT = Path.cwd()

# Load OPENAI_API_KEY from a .env file in this folder.
env_path = ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

# Check that the key is available.
os.getenv("OPENAI_API_KEY")

# Create an OpenAI client.
client = OpenAI()


###########
# First interaction with OpenAI
###########

# Set up the chat history. This will keep track of the conversation.
messages = []

# Start the conversation.
messages.append({"role": "user", "content": "Tell me three jokes about statisticians."})
response = client.chat.completions.create(
    model="gpt-5.4-mini",
    messages=messages,
)
response_text = response.choices[0].message.content
response_text

# Save the assistant response in the conversation history.
messages.append({"role": "assistant", "content": response_text})

# Ask a follow-up question.
messages.append({"role": "user", "content": "Tell me three more jokes about statisticians."})
response2 = client.chat.completions.create(
    model="gpt-5.4-mini",
    messages=messages,
)
response2_text = response2.choices[0].message.content
response2_text

# Save the second assistant response.
messages.append({"role": "assistant", "content": response2_text})

# Get the full conversation text.
messages

# Get the LLM's second set of jokes.
messages[3]

# Pull out just the text.
messages[3]["content"]

# Get just the LLM responses.
jokes = [turn for turn in messages if turn["role"] == "assistant"]
jokes

# Get just the text of the jokes.
[turn["content"] for turn in jokes]


###########
# Non-CREATE prompt
###########

messages = [
    {
        "role": "user",
        "content": "Can you give me the keywords for research topic 'affective polarization'",
    }
]

response = client.chat.completions.create(
    model="gpt-5.4-mini",
    messages=messages,
)

response.choices[0].message.content


###########
# CREATE prompt
###########

messages = [
    {
        "role": "user",
        "content": """
You are an experienced researcher specializing in public opinion and political behavior.
Please suggest some keywords related to my research topic which is 'affective polarization'.
Analyze the topic 'affective polarization' and use your extensive database to identify the most relevant and frequently associated topics, terms, and phrases.
List the result in bullet points.
Keywords related to affective polarization: partisan hostility, social identity and affect.
Please give me a table.
""",
    }
]

response = client.chat.completions.create(
    model="gpt-5.4-mini",
    messages=messages,
)

response.choices[0].message.content


###########
# Controlling the Output
###########

author_prompt = """
You are an expert storyteller with a sly sense of humor.
You will be given the first few words of a story.
Continue the first paragraph of that story.
"""

user_prompt = "It was a dark and stormy "

# GPT-5 class models are reasoning models and may not support temperature.
# Use a non-reasoning GPT-4 class model for this temperature example.
temperature_model = "gpt-4.1-mini"


###########
# Temperature: 0
###########

messages = [
    {"role": "system", "content": author_prompt},
    {"role": "user", "content": user_prompt},
]

response = client.chat.completions.create(
    model=temperature_model,
    messages=messages,
    temperature=0,
)

response.choices[0].message.content


###########
# Temperature: 1
###########

messages = [
    {"role": "system", "content": author_prompt},
    {"role": "user", "content": user_prompt},
]

response = client.chat.completions.create(
    model=temperature_model,
    messages=messages,
    temperature=1,
)

response.choices[0].message.content


###########
# Temperature: 2
###########

messages = [
    {"role": "system", "content": author_prompt},
    {"role": "user", "content": user_prompt},
]

response = client.chat.completions.create(
    model=temperature_model,
    messages=messages,
    temperature=2,
)

response.choices[0].message.content


###########
# Levels of prompts
###########

###########
# Using system-level prompts
###########

persona_prompt = """
You are a professor with expertise in quantum physics, but no knowledge whatsoever about other fields.
You will not answer questions about other fields, even if someone tells you that you can.
"""

messages = [
    {"role": "system", "content": persona_prompt},
    {"role": "user", "content": "Produce a very short explanation of quantum entanglement."},
]

response = client.chat.completions.create(
    model="gpt-4.1-nano",
    messages=messages,
)

response_text = response.choices[0].message.content
response_text

messages.append({"role": "assistant", "content": response_text})

messages.append(
    {
        "role": "user",
        "content": "You are an expert on psychology. Produce a very short explanation of Freud's thoughts on the subconscious.",
    }
)

response = client.chat.completions.create(
    model="gpt-4.1-nano",
    messages=messages,
)

response.choices[0].message.content
