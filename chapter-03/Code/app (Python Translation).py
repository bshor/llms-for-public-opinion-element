"""
Political marketing research app for Chapter 3b, translated from Shiny to Flask.

Suggested packages:

    pip install flask openai

Run:

    python "app (Python Translation).py"

Then open http://127.0.0.1:5000 in a browser.
"""

from __future__ import annotations

import os
from pathlib import Path
from uuid import uuid4

from flask import Flask, jsonify, render_template_string, request, session
from openai import OpenAI


ROOT = Path.cwd()

env_path = ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "replace-this-development-secret")

client = OpenAI()


Q_ANSWER_PROMPT = """You are a public relations representative for John Smith, who is running for City Council in Columbus, OH.
Your job is to answer questions from voters.
Respond truthfully based on the information in the candidate's information file.
Rely only on the candidate information included in the system message.
If you do not know the answer to a question, apologize and say you don't know the answer.
End each response by asking if they have any more questions about any aspect of John Smith."""

Q_ASKING_PROMPT = """You are an expert research interviewer hired by the campaign for John Smith for City Council in Columbus, OH.
You will be interacting with a voter.
Your goals will be to find out:
(1) What they think of John Smith as a candidate.
(2) What do they think of John Smith's stance on the issues that are important to them.
(3) What recommendations they have for improving life in Columbus, OH.
(4) What suggestions do they have for getting John Smith's message out to others.
Ask follow-up questions or ask for elaboration when anything is unclear.
Ask no more than five questions.
Ask only one question at a time."""


STORE: dict[str, dict] = {}


def get_candidate_information(candidate_text_file: str = "smithforcitycouncil.md") -> str:
    path = ROOT / candidate_text_file
    if not path.exists():
        return (
            "No candidate information file was found. Create smithforcitycouncil.md "
            "in this folder to provide the candidate biography and policy positions."
        )
    return path.read_text(encoding="utf-8")


def get_state() -> dict:
    if "sid" not in session:
        session["sid"] = str(uuid4())
    return STORE.setdefault(
        session["sid"],
        {
            "phase": "intro",
            "qa_messages": [],
            "interview_messages": [],
            "interview_count": 0,
        },
    )


def llm_reply(system_prompt: str, messages: list[dict[str, str]]) -> str:
    response = client.chat.completions.create(
        model="gpt-5.4",
        messages=[{"role": "system", "content": system_prompt}, *messages],
    )
    return response.choices[0].message.content or ""


HTML = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Smith for City Council Survey</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; background: #f6f7f9; color: #1b1d22; }
    main { max-width: 860px; margin: 0 auto; padding: 32px 18px; }
    .panel { background: white; border: 1px solid #d8dde6; border-radius: 8px; padding: 24px; }
    .hidden { display: none; }
    button { background: #2457a6; color: white; border: 0; border-radius: 6px; padding: 10px 16px; cursor: pointer; }
    .chat { display: flex; flex-direction: column; gap: 10px; height: 520px; overflow-y: auto; padding: 12px; border: 1px solid #d8dde6; border-radius: 8px; background: #fff; }
    .msg { max-width: 78%; padding: 10px 12px; border-radius: 8px; line-height: 1.4; white-space: pre-wrap; }
    .assistant { background: #edf2fb; align-self: flex-start; }
    .user { background: #e8f5e9; align-self: flex-end; }
    form { display: flex; gap: 8px; margin-top: 12px; }
    input { flex: 1; padding: 10px 12px; border: 1px solid #c6ccd6; border-radius: 6px; }
  </style>
</head>
<body>
<main>
  <section id="intro" class="panel">
    <h2>Introducing John Smith, Candidate for Columbus City Council.</h2>
    <h3>This survey has two parts.</h3>
    <p>In the first part, you will be able to ask questions about John Smith, his background, and his stances on major issues.</p>
    <p>In the second part, you will be asked questions about what you think of John Smith.</p>
    <button id="start">Next</button>
  </section>

  <section id="qa" class="hidden">
    <div id="qaChat" class="chat"></div>
    <form id="qaForm"><input id="qaInput" autocomplete="off"><button>Send</button></form>
  </section>

  <section id="interview" class="hidden">
    <div id="interviewChat" class="chat"></div>
    <form id="interviewForm"><input id="interviewInput" autocomplete="off"><button>Send</button></form>
  </section>

  <section id="thanks" class="panel hidden">
    <h3>Thank you for chatting with us! Your response has been submitted.</h3>
  </section>
</main>
<script>
function addMessage(target, role, text) {
  const chat = document.getElementById(target);
  const msg = document.createElement("div");
  msg.className = "msg " + role;
  msg.textContent = text;
  chat.appendChild(msg);
  chat.scrollTop = chat.scrollHeight;
}
function show(id) { document.getElementById(id).classList.remove("hidden"); }
function hide(id) { document.getElementById(id).classList.add("hidden"); }
document.addEventListener("paste", e => {
  if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") e.preventDefault();
});
document.getElementById("start").onclick = async () => {
  const res = await fetch("/start", {method: "POST"});
  const data = await res.json();
  hide("intro"); show("qa");
  addMessage("qaChat", "assistant", data.message);
};
document.getElementById("qaForm").onsubmit = async e => {
  e.preventDefault();
  const input = document.getElementById("qaInput");
  const text = input.value.trim();
  if (!text) return;
  input.value = "";
  addMessage("qaChat", "user", text);
  const res = await fetch("/qa", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({message: text})});
  const data = await res.json();
  if (data.phase === "interview") {
    hide("qa"); show("interview");
    addMessage("interviewChat", "assistant", data.intro);
    addMessage("interviewChat", "assistant", data.message);
  } else {
    addMessage("qaChat", "assistant", data.message);
  }
};
document.getElementById("interviewForm").onsubmit = async e => {
  e.preventDefault();
  const input = document.getElementById("interviewInput");
  const text = input.value.trim();
  if (!text) return;
  input.value = "";
  addMessage("interviewChat", "user", text);
  const res = await fetch("/interview", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({message: text})});
  const data = await res.json();
  if (data.phase === "thanks") {
    hide("interview"); show("thanks");
  } else {
    addMessage("interviewChat", "assistant", data.message);
  }
};
</script>
</body>
</html>
"""


@app.route("/")
def index():
    get_state()
    return render_template_string(HTML)


@app.post("/start")
def start():
    state = get_state()
    state["phase"] = "qa"
    message = (
        "Hi! I am here to answer any questions you may have about John Smith, "
        "a candidate for City Council in Columbus, OH. When you are ready to go, "
        "just type 'done' or 'no' into the text box. Please enter your question below and hit enter when you are ready."
    )
    state["qa_messages"].append({"role": "assistant", "content": message})
    return jsonify({"message": message})


@app.post("/qa")
def qa():
    state = get_state()
    user_msg = request.json["message"]
    clean = "".join(ch for ch in user_msg.lower().strip() if ch.isalnum() or ch.isspace())
    if clean in {"done", "no"}:
        state["phase"] = "interview"
        intro = (
            "Thank you for your questions! Now I am going to ask you a few questions "
            "about your impressions of and recommendations for John Smith. I will ask four questions."
        )
        first_question = llm_reply(
            Q_ASKING_PROMPT,
            [{"role": "user", "content": "Please start the interview by asking for the respondent's general impression of John Smith."}],
        )
        state["interview_messages"].extend(
            [
                {"role": "assistant", "content": intro},
                {"role": "assistant", "content": first_question},
            ]
        )
        return jsonify({"phase": "interview", "intro": intro, "message": first_question})

    state["qa_messages"].append({"role": "user", "content": user_msg})
    candidate_info = get_candidate_information()
    system_prompt = f"{Q_ANSWER_PROMPT}\n\nCandidate information:\n{candidate_info}"
    answer = llm_reply(system_prompt, state["qa_messages"])
    state["qa_messages"].append({"role": "assistant", "content": answer})
    return jsonify({"phase": "qa", "message": answer})


@app.post("/interview")
def interview():
    state = get_state()
    user_msg = request.json["message"]
    state["interview_messages"].append({"role": "user", "content": user_msg})
    state["interview_count"] += 1
    if state["interview_count"] >= 4:
        state["phase"] = "thanks"
        return jsonify({"phase": "thanks"})

    answer = llm_reply(Q_ASKING_PROMPT, state["interview_messages"])
    state["interview_messages"].append({"role": "assistant", "content": answer})
    return jsonify({"phase": "interview", "message": answer})


if __name__ == "__main__":
    app.run(debug=True)
