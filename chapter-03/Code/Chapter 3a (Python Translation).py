"""
Interviewer design for Chapter 3a, translated from R to Python.

This file is intentionally written so you can run it line-by-line in an
interactive console, like the R examples.

Suggested package:

    pip install openai
"""

import json
import os
from pathlib import Path

from openai import OpenAI


###########
# Load libraries / setup
###########

ROOT = Path.cwd()

env_path = ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

client = OpenAI()


###########
# Function to ask follow-up questions
###########


def ask_next_question(interview_to_time):
    interviewer_prompt = (
        "You are an expert qualitative interviewer. You are conducting an interview with an American voter. "
        "Ask follow-up questions to develop a fuller understanding of why the respondent thinks tariffs are good or bad "
        "for the United States. Probe for specific reasons they hold their opinions. Assess the strength of their opinion "
        "and if they are open to counter-arguments that might change their thinking on the policy. Listen for and probe on: "
        "Language or phrasing, Emotion, Tone, their thoughts and feelings regarding policies on tariffs. Continue with the "
        "interview until you get a FULL picture of what this person was thinking. Ask for clarification or more details when "
        "responses are vague or general. Ask a maximum of three follow-up questions! Do not ask leading questions and do not "
        "provide potential response options, let participants spontaneously tell you what they think without putting words in "
        "their mouths. Also, always ask only one question at a time!"
    )

    interviewer_messages = [{"role": "system", "content": interviewer_prompt}]

    for i in range(1, 4):
        interviewer_messages.append(
            {
                "role": "user",
                "content": (
                    "The text interview up to this time is as follows:\n"
                    f"{interview_to_time}.\nAsk the next follow-up question."
                ),
            }
        )

        response = client.chat.completions.create(
            model="gpt-5.4",
            messages=interviewer_messages,
        )
        next_question = response.choices[0].message.content
        interviewer_messages.append({"role": "assistant", "content": next_question})

        print(next_question)
        user_response = input("Type your answer here: ")

        interview_to_time = (
            interview_to_time
            + "Interviewer: "
            + next_question
            + "<br>"
            + "Respondent: "
            + user_response
            + "<br>"
        )

    interview_to_time = interview_to_time.split("<br>")
    return interview_to_time


###########
# Create a function that will start the interview
###########


def interview_function():
    interview_question = (
        "Overall, do you think increasing tariffs or fees on goods importaed from trading partners "
        "will be good of bad for the United States?\n"
        "Do you think they are: \nVery good, \nGood, \nNeither good nor bad, \nBad, \nVery bad?\n"
    )

    print(interview_question)

    user_response = input("Type your answer here: ")

    interview = ask_next_question(
        "Interviewer: " + interview_question + "<br>" + "Respondent: " + user_response + "<br>"
    )

    print("\nThank you for your responses!")
    return interview


###########
# Run the interview function and save the chat
###########

interview_data = interview_function()


###########
# Making the interviewer multi-agent
###########


###########
# Create function that will conduct a check for non-serious respondents
###########


def ask_next_question(interview_to_time):
    interviewer_prompt = (
        "You are an expert qualitative interviewer. You are conducting an interview with an American voter. "
        "Ask follow-up questions to develop a fuller understanding of why the respondent thinks tariffs are good or bad "
        "for the United States. Probe for specific reasons they hold their opinions. Assess the strength of their opinion "
        "and if they are open to counter-arguments that might change their thinking on the policy. Listen for and probe on: "
        "Language or phrasing, Emotion, Tone, their thoughts and feelings regarding policies on tariffs. Continue with the "
        "interview until you get a FULL picture of what this person was thinking. Ask for clarification or more details when "
        "responses are vague or general. Ask a maximum of three follow-up questions! Do not ask leading questions and do not "
        "provide potential response options, let participants spontaneously tell you what they think without putting words in "
        "their mouths. Also, always ask only one question at a time!"
    )

    answer_checker = (
        "You are an expert at supervising and evaluating qualitative survey interviews. Your will be given the text of an "
        "interview. Please review whether the respondent gives a serious answer that is on topic or if they provide a "
        "non-serious or off topic response. Return a statement labeling the response either 'yes' if it is serious and "
        "on-topic or 'no' if it is non-serious or off-topic."
    )

    seriousness_schema = {
        "type": "json_schema",
        "json_schema": {
            "name": "seriousness_check",
            "strict": True,
            "schema": {
                "type": "object",
                "properties": {
                    "serious": {
                        "type": "string",
                        "enum": ["yes", "no"],
                        "description": "Whether the respondent's answer was serious and on-topic.",
                    }
                },
                "required": ["serious"],
                "additionalProperties": False,
            },
        },
    }

    interviewer_messages = [{"role": "system", "content": interviewer_prompt}]

    for i in range(1, 4):
        check_messages = [
            {"role": "system", "content": answer_checker},
            {
                "role": "user",
                "content": "The text interview up to this time is as follows:\n" + interview_to_time + ".",
            },
        ]

        raw_check = client.chat.completions.create(
            model="gpt-5.4-nano",
            messages=check_messages,
            response_format=seriousness_schema,
        )
        check_answer = json.loads(raw_check.choices[0].message.content)

        if check_answer["serious"] == "no":
            print("A non-serious or off-topic response was detected. Ending the interview.")
            break

        interviewer_messages.append(
            {
                "role": "user",
                "content": (
                    "The text interview up to this time is as follows:\n"
                    + interview_to_time
                    + ".\nAsk the next follow-up question."
                ),
            }
        )

        response = client.chat.completions.create(
            model="gpt-5.4",
            messages=interviewer_messages,
        )
        next_question = response.choices[0].message.content
        interviewer_messages.append({"role": "assistant", "content": next_question})

        print(next_question)
        user_response = input("Type your answer here: ")

        interview_to_time = (
            interview_to_time
            + "Interviewer: "
            + next_question
            + "<br>"
            + "Respondent: "
            + user_response
            + "<br>"
        )

    interview_to_time = interview_to_time.split("<br>")
    return interview_to_time


interview_text = interview_function()
