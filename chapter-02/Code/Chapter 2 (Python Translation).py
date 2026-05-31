"""
Code examples for Chapter 2, translated from R to Python.

This file is intentionally written so you can run it line-by-line in an
interactive console, like the R examples. Functions are only introduced where
the corresponding R script introduces functions.

Suggested packages:

    pip install openai pandas numpy matplotlib seaborn statsmodels scikit-learn requests
"""

import json
import os
import pickle
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import requests
import seaborn as sns
import statsmodels.formula.api as smf
from openai import OpenAI
from sklearn.decomposition import PCA


###########
# Load packages / setup
###########

# Use the current folder when pasting lines into an interactive console.
ROOT = Path.cwd()


# Load OPENAI_API_KEY from a .env file in this folder.
env_path = ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

client = OpenAI()


###########
# Define a demographic persona
###########

persona = (
    "It is 2021. You are 45 years old. You are a White woman. "
    "You have a 4-year college degree. You make $75,000 per year. "
    "You live in the United States. You are a Republican. "
    "Provide responses from this person's perspective."
)


###########
# Define response schema
###########

survey_response_schema = {
    "type": "json_schema",
    "json_schema": {
        "name": "survey_response",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "opinion": {
                    "type": "integer",
                    "description": "1 to indicate support, 0 to indicate opposition",
                },
                "explanation": {
                    "type": "string",
                    "description": "Brief explanation for the opinion",
                },
                "confidence": {
                    "type": "string",
                    "enum": ["High", "Medium", "Low"],
                    "description": "Confidence level",
                },
            },
            "required": ["opinion", "explanation", "confidence"],
            "additionalProperties": False,
        },
    },
}


###########
# Create chat object with persona as system prompt / get structured response
###########

messages = [{"role": "system", "content": persona}]

messages.append(
    {
        "role": "user",
        "content": "Do you support or oppose expanding Medicare to a single comprehensive public health care program that would cover all Americans?",
    }
)

raw_response = client.chat.completions.create(
    model="gpt-5.4-mini",
    messages=messages,
    response_format=survey_response_schema,
)

response = json.loads(raw_response.choices[0].message.content)

print(
    f"""
Opinion (1 = support, 0 = oppose): {response["opinion"]}
Confidence: {response["confidence"]}
Explanation: {response["explanation"]}
"""
)


###########
# 01 - Setup.R
# Shared definitions for subsequent scripts
###########

# Model for this run. Defaults to a cloud (OpenAI) model; the local-model
# section overrides it with an Ollama model.
active_model = "gpt-5.4-mini"

# Ollama (local) model names contain a colon; OpenAI (cloud) names do not.
use_local = ":" in active_model

# Tag for this run's saved files (colons replaced for valid filenames).
run_tag = active_model.replace(":", "-")


def results_path(name):
    return ROOT / "Processed" / f"{run_tag}-{name}"

# Create output directories
for folder in ["Output", "Processed", "Plots", "Tables"]:
    (ROOT / folder).mkdir(exist_ok=True)

# Load CCES 2021 data.
cces_path = ROOT / "Data" / "cces21.csv"

issues_path = ROOT / "Data" / "cces21_issues.csv"


dta1 = pd.read_csv(cces_path)
issues = pd.read_csv(issues_path)


###########
# Build system prompt from CCES respondent demographics
###########


def build_prompt(i):
    row = dta1.iloc[i - 1]
    return (
        f"It is 2021. "
        f"You are {row['age']} years old. "
        f"You are {row['married']}. "
        f"You are {row['race_id']}. "
        f"You are {row['gender']}. "
        f"You have {row['ed']}. "
        f"You make {row['income']} per year. "
        f"You live in the United States. "
        f"You are {row['ideology']}. "
        f"You are {row['registered']}. "
        f"You are a {row['pid_text']}. "
        f"You {row['pol_interest']} pay attention to what's going on in government and politics. "
        f"Provide responses from this person's perspective. "
        f"Use only knowledge about politics that they would have."
    )


###########
# 02 - Single respondent structured query
###########

i = 42
system_prompt = build_prompt(i)

messages = [
    {"role": "system", "content": system_prompt},
    {
        "role": "user",
        "content": "Do you support or oppose expanding Medicare to a single comprehensive public health care program that would cover all Americans?",
    },
]

start_time = time.perf_counter()
raw_response = client.chat.completions.create(
    model=active_model,
    messages=messages,
    response_format=survey_response_schema,
)
elapsed = time.perf_counter() - start_time

response = json.loads(raw_response.choices[0].message.content)
response
elapsed

row = dta1.iloc[i - 1]
print(
    f"""
Respondent 1: {row["age"]}yo {row["race_id"]} {row["gender"]} {row["pid_text"]}

Real CCES response: {row["CC21_320a_t"]}
LLM opinion: {"Support" if response["opinion"] == 1 else "Oppose"}
LLM confidence: {response["confidence"]}
LLM reasoning: {response["explanation"]}
"""
)


###########
# 02b - Helper functions.R
# Reusable functions for annotating results and computing accuracy metrics
###########


def annotate_results(results, resp_id, n_issues=10):
    real_cols = [f"CC21_{issue}_t" for issue in issues["issue"].iloc[:n_issues]]
    row = dta1.iloc[resp_id - 1]
    out = results.copy()
    out.insert(0, "caseid", row["caseid"])
    out.insert(1, "respondent", resp_id)
    out.insert(2, "issue", issues["issue"].iloc[:n_issues].to_list())
    out.insert(3, "real_response", row[real_cols].astype(str).to_list())
    out.insert(4, "llm_response", np.where(out["opinion"] == 1, "Support", "Oppose"))
    out.insert(5, "match", np.where(out["llm_response"] == out["real_response"], "Correct", "Incorrect"))
    return out


def calc_pre(real_response, match):
    real_response = pd.Series(real_response)
    match = pd.Series(match)
    n = len(real_response)
    support = (real_response == "Support").sum()
    e_baseline = min(support, n - support)
    e_model = (match == "Incorrect").sum()
    if e_baseline == 0:
        return np.nan
    return (e_baseline - e_model) / e_baseline


def load_combined():
    return pd.read_pickle(results_path("combined_results.pkl"))


def build_combined(all_results):
    combined = pd.concat(list(all_results.values()), ignore_index=True)
    combined = combined.merge(dta1[["caseid", "pid_text"]], on="caseid", how="left")
    combined["pid3"] = np.select(
        [combined["pid_text"] == "Democrat", combined["pid_text"] == "Republican"],
        [-1, 1],
        default=0,
    )
    return combined


###########
# 03a - Query 10 respondents x 10 issues
###########

all_results = {}

start_time = time.perf_counter()
for resp_id in range(1, 11):
    system_prompt = build_prompt(resp_id)
    prompts = [
        f"Do you support or oppose the following policy: {question}?"
        for question in issues["question"].iloc[:10]
    ]

    rows = [None] * len(prompts)
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {}
        for prompt_index, prompt in enumerate(prompts):
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ]
            future = executor.submit(
                client.chat.completions.create,
                model=active_model,
                messages=messages,
                response_format=survey_response_schema,
            )
            futures[future] = prompt_index

        for future in as_completed(futures):
            prompt_index = futures[future]
            raw = future.result()
            parsed = json.loads(raw.choices[0].message.content)
            usage = raw.usage
            parsed["input_tokens"] = usage.prompt_tokens if usage else np.nan
            parsed["output_tokens"] = usage.completion_tokens if usage else np.nan
            parsed["cost"] = np.nan
            rows[prompt_index] = parsed

    results = pd.DataFrame(rows)
    all_results[resp_id] = annotate_results(results, resp_id)

elapsed = time.perf_counter() - start_time
elapsed

with open(results_path("all_results.pkl"), "wb") as f:
    pickle.dump(all_results, f)

combined_results = pd.concat(list(all_results.values()), ignore_index=True)

combined_results[
    ["caseid", "respondent", "issue", "real_response", "llm_response", "match", "confidence"]
].sample(n=min(15, len(combined_results)), random_state=123)

print(
    f"""
Total queries: {len(combined_results)}
Total input tokens: {combined_results["input_tokens"].sum()}
Total output tokens: {combined_results["output_tokens"].sum()}
Total cost: ${round(combined_results["cost"].sum(skipna=True), 2)}
"""
)


###########
# 03b - Expand to 100 respondents, preserving existing results
###########

n_target = 100

all_results_path = results_path("all_results.pkl")
if all_results_path.exists():
    with open(all_results_path, "rb") as f:
        all_results = pickle.load(f)
else:
    all_results = {}

existing_ids = sorted(all_results.keys())
missing_ids = [x for x in range(1, n_target + 1) if x not in existing_ids]

print("Found existing:", existing_ids)
print("Querying:", missing_ids)

start_time = time.perf_counter()
for resp_id in missing_ids:
    system_prompt = build_prompt(resp_id)
    prompts = [
        f"Do you support or oppose the following policy: {question}?"
        for question in issues["question"].iloc[:10]
    ]

    rows = [None] * len(prompts)
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {}
        for prompt_index, prompt in enumerate(prompts):
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ]
            future = executor.submit(
                client.chat.completions.create,
                model=active_model,
                messages=messages,
                response_format=survey_response_schema,
            )
            futures[future] = prompt_index

        for future in as_completed(futures):
            prompt_index = futures[future]
            raw = future.result()
            parsed = json.loads(raw.choices[0].message.content)
            usage = raw.usage
            parsed["input_tokens"] = usage.prompt_tokens if usage else np.nan
            parsed["output_tokens"] = usage.completion_tokens if usage else np.nan
            parsed["cost"] = np.nan
            rows[prompt_index] = parsed

    results = pd.DataFrame(rows)
    all_results[resp_id] = annotate_results(results, resp_id)

elapsed = time.perf_counter() - start_time
elapsed

with open(all_results_path, "wb") as f:
    pickle.dump(all_results, f)

combined_results = build_combined(all_results)

combined_results.to_pickle(results_path("combined_results.pkl"))
combined_results.to_csv(results_path("combined_results.csv"), index=False)

combined_results[
    ["caseid", "respondent", "issue", "real_response", "llm_response", "match", "confidence"]
].sample(n=min(15, len(combined_results)), random_state=123)

print(
    f"""
Total queries: {len(combined_results)}
Total input tokens: {combined_results["input_tokens"].sum()}
Total output tokens: {combined_results["output_tokens"].sum()}
Total cost: ${round(combined_results["cost"].sum(skipna=True), 2)}
"""
)


###########
# 03c - Optional local model via Ollama
###########

active_model = "llama3.1:8b-instruct-q4_K_M"
use_local = ":" in active_model
run_tag = active_model.replace(":", "-")
n_target = 100

local_results_path = results_path("all_results.pkl")
if local_results_path.exists():
    with open(local_results_path, "rb") as f:
        all_results = pickle.load(f)
else:
    all_results = {}

existing_ids = sorted(all_results.keys())
missing_ids = [x for x in range(1, n_target + 1) if x not in existing_ids]

print("Model:", active_model)
print("Found:", len(existing_ids), "existing,", len(missing_ids), "to query")

start_time = time.perf_counter()
for resp_id in missing_ids:
    system_prompt = build_prompt(resp_id)
    prompts = [
        f"Do you support or oppose the following policy: {question}?"
        for question in issues["question"].iloc[:10]
    ]

    rows = [None] * len(prompts)
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {}
        for prompt_index, prompt in enumerate(prompts):
            future = executor.submit(
                requests.post,
                "http://localhost:11434/api/chat",
                json={
                    "model": active_model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": prompt},
                    ],
                    "stream": False,
                    "format": survey_response_schema["json_schema"]["schema"],
                },
                timeout=120,
            )
            futures[future] = prompt_index

        for future in as_completed(futures):
            prompt_index = futures[future]
            raw = future.result()
            raw.raise_for_status()
            parsed = json.loads(raw.json()["message"]["content"])
            parsed["input_tokens"] = np.nan
            parsed["output_tokens"] = np.nan
            rows[prompt_index] = parsed

    results = pd.DataFrame(rows)
    all_results[resp_id] = annotate_results(results, resp_id)

    with open(local_results_path, "wb") as f:
        pickle.dump(all_results, f)
    print("Respondent", resp_id, "done")

elapsed = time.perf_counter() - start_time
elapsed

combined_results = build_combined(all_results)

combined_results.to_pickle(results_path("combined_results.pkl"))
combined_results.to_csv(results_path("combined_results.csv"), index=False)

combined_results[
    ["caseid", "respondent", "issue", "real_response", "llm_response", "match", "confidence"]
].sample(n=min(15, len(combined_results)), random_state=123)

print(
    f"""
Total queries: {len(combined_results)}
Total input tokens: {combined_results["input_tokens"].sum()}
Total output tokens: {combined_results["output_tokens"].sum()}
"""
)


###########
# 04 - Overall accuracy by issue and overall
###########

combined_results = load_combined()

issue_metrics = (
    combined_results.groupby("issue")
    .apply(
        lambda x: pd.Series(
            {
                "n": len(x),
                "accuracy": (x["match"] == "Correct").mean(),
                "correlation": (x["llm_response"] == "Support").corr(x["real_response"] == "Support"),
                "pre": calc_pre(x["real_response"], x["match"]),
            }
        )
    )
    .reset_index()
)

issue_metrics

overall_accuracy = pd.DataFrame(
    [
        {
            "accuracy": (combined_results["match"] == "Correct").mean(),
            "correlation": (combined_results["llm_response"] == "Support").corr(
                combined_results["real_response"] == "Support"
            ),
            "pre": calc_pre(combined_results["real_response"], combined_results["match"]),
        }
    ]
).round(3)

overall_accuracy.to_csv(ROOT / "Tables" / "overall-accuracy.csv", index=False)
overall_accuracy


###########
# 04b - Party-specific majority baseline
###########

combined_results = load_combined()

party_majority = (
    combined_results.groupby(["pid_text", "issue"])["real_response"]
    .agg(lambda x: "Support" if (x == "Support").mean() >= 0.5 else "Oppose")
    .rename("party_majority")
    .reset_index()
)

party_pre_df = combined_results.merge(party_majority, on=["pid_text", "issue"], how="left")
party_pre_df["error_model"] = party_pre_df["match"] == "Incorrect"
party_pre_df["error_party"] = party_pre_df["real_response"] != party_pre_df["party_majority"]

e_majority = min(
    (party_pre_df["real_response"] == "Support").sum(),
    (party_pre_df["real_response"] == "Oppose").sum(),
)
e_party = party_pre_df["error_party"].sum()
e_model = party_pre_df["error_model"].sum()

pre_comparison = pd.DataFrame(
    [
        {
            "n": len(party_pre_df),
            "e_majority": e_majority,
            "e_party": e_party,
            "e_model": e_model,
            "pre": (e_majority - e_model) / e_majority,
            "party_pre": (e_party - e_model) / e_party,
        }
    ]
).round({"pre": 3, "party_pre": 3})

pre_comparison.to_csv(ROOT / "Tables" / "pre-comparison.csv", index=False)
pre_comparison

party_pre_by_issue = (
    party_pre_df.groupby("issue")
    .apply(
        lambda x: pd.Series(
            {
                "e_party": x["error_party"].sum(),
                "e_model": x["error_model"].sum(),
                "party_pre": np.nan
                if x["error_party"].sum() == 0
                else (x["error_party"].sum() - x["error_model"].sum()) / x["error_party"].sum(),
            }
        )
    )
    .reset_index()
    .sort_values("party_pre", ascending=False)
)

party_pre_by_issue


###########
# 05 - Aggregate comparison plot
###########

combined_results = load_combined()

aggregate_comparison = (
    combined_results.groupby("issue")
    .apply(
        lambda x: pd.Series(
            {
                "llm_support": (x["llm_response"] == "Support").mean(),
                "real_support": (x["real_response"] == "Support").mean(),
            }
        )
    )
    .reset_index()
)

aggregate_comparison["absolute_error"] = (
    aggregate_comparison["llm_support"] - aggregate_comparison["real_support"]
).abs()

aggregate_comparison

summary_mae = aggregate_comparison["absolute_error"].mean()
print(f"Mean Absolute Error: {round(summary_mae, 3)}")

fig, ax = plt.subplots(figsize=(6, 6))
ax.scatter(aggregate_comparison["real_support"], aggregate_comparison["llm_support"], alpha=0.5)
for _, row in aggregate_comparison.iterrows():
    ax.text(row["real_support"], row["llm_support"] + 0.02, row["issue"], fontsize=8)
ax.plot([0, 1], [0, 1], linestyle="--", color="red")
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.set_aspect("equal")
ax.set_xlabel("Real CCES proportion supporting")
ax.set_ylabel("LLM proportion supporting")
ax.set_title("Aggregate accuracy: Synthetic vs. Real proportions")
fig.tight_layout()
fig.savefig(ROOT / "Plots" / "05-plot.png", dpi=300)


###########
# 06 - Accuracy by confidence
###########

combined_results = load_combined()

confidence_counts = combined_results["confidence"].value_counts(dropna=False).reset_index()
confidence_counts.columns = ["confidence", "n"]
confidence_counts["percent"] = (confidence_counts["n"] / confidence_counts["n"].sum() * 100).round(1)
confidence_counts

high_conf = combined_results[combined_results["confidence"] == "High"]
med_low_conf = combined_results[combined_results["confidence"].isin(["Medium", "Low"])]

comparison = pd.DataFrame(
    {
        "level": ["All", "High", "Medium/Low"],
        "n": [len(combined_results), len(high_conf), len(med_low_conf)],
        "accuracy": [
            (combined_results["match"] == "Correct").mean(),
            (high_conf["match"] == "Correct").mean(),
            (med_low_conf["match"] == "Correct").mean(),
        ],
        "pre": [
            calc_pre(combined_results["real_response"], combined_results["match"]),
            calc_pre(high_conf["real_response"], high_conf["match"]),
            calc_pre(med_low_conf["real_response"], med_low_conf["match"]),
        ],
    }
)

comparison

for _, row in comparison.iterrows():
    print(f"  {row['level']}: {row['n']} ({round(row['accuracy'] * 100, 1)}% accurate, PRE = {round(row['pre'], 3)})")

improvement_acc = round((comparison.loc[1, "accuracy"] - comparison.loc[2, "accuracy"]) * 100, 1)
improvement_pre = round(comparison.loc[1, "pre"] - comparison.loc[2, "pre"], 3)

print(f"High vs Medium/Low improvement: +{improvement_acc} percentage points (accuracy), +{improvement_pre} (PRE)")


###########
# 07 - Party metrics
###########

combined_results = load_combined()

party_metrics = (
    combined_results.groupby("pid_text")
    .apply(
        lambda x: pd.Series(
            {
                "n_respondents": x["respondent"].nunique(),
                "accuracy": (x["match"] == "Correct").mean(),
                "pre": calc_pre(x["real_response"], x["match"]),
            }
        )
    )
    .reset_index()
    .rename(columns={"pid_text": "party"})
    .sort_values("accuracy", ascending=False)
    .round({"accuracy": 3, "pre": 3})
)

party_metrics.to_csv(ROOT / "Tables" / "party-metrics.csv", index=False)
party_metrics


###########
# 07b - Rare demographic profiles
###########

combined_results = load_combined()

results_demo = combined_results.merge(dta1[["caseid", "gender", "race_id"]], on="caseid", how="left")


def compute_mae(data, label):
    errors = (
        data.groupby("issue")
        .apply(lambda x: abs((x["llm_response"] == "Support").mean() - (x["real_response"] == "Support").mean()))
        .reset_index(name="absolute_error")
    )
    return pd.DataFrame(
        [{"subgroup": label, "n": data["respondent"].nunique(), "mae": round(errors["absolute_error"].mean(), 3)}]
    )


results_demo["l1"] = "All respondents"
results_demo["l2"] = results_demo["pid_text"]
results_demo["l3"] = results_demo["gender"] + " " + results_demo["pid_text"]
results_demo["l4"] = results_demo["race_id"] + " " + results_demo["pid_text"]

subgroups = []
for level in ["l1", "l2", "l3", "l4"]:
    for group in results_demo[level].dropna().unique():
        subgroups.append(compute_mae(results_demo[results_demo[level] == group], group))

subgroups = pd.concat(subgroups, ignore_index=True).sort_values("n", ascending=False)
subgroups

fig, ax = plt.subplots(figsize=(7, 5))
sns.regplot(data=subgroups, x="n", y="mae", lowess=True, scatter_kws={"alpha": 0.6, "s": 40}, ax=ax)
ax.set_xscale("log")
ax.set_title("Aggregate accuracy deteriorates for rare demographic profiles")
ax.set_xlabel("Subgroup size (log scale)")
ax.set_ylabel("Mean Absolute Error")
fig.tight_layout()
fig.savefig(ROOT / "Plots" / "07b-rare-profiles.png", dpi=300)


###########
# 07c - Accuracy by issue and party heatmap
###########

combined_results = load_combined()

heatmap_data = (
    combined_results.rename(columns={"pid_text": "party"})
    .groupby(["issue", "party"])
    .agg(accuracy=("match", lambda x: (x == "Correct").mean()), n=("match", "size"))
    .reset_index()
)

fig, ax = plt.subplots(figsize=(6, 5))
heatmap_table = heatmap_data.pivot(index="issue", columns="party", values="accuracy")
sns.heatmap(
    heatmap_table,
    annot=True,
    fmt=".0%",
    cmap=sns.diverging_palette(25, 170, as_cmap=True),
    center=heatmap_data["accuracy"].mean(),
    ax=ax,
)
ax.set_xlabel("")
ax.set_ylabel("")
ax.set_title("Individual accuracy by issue and party")
fig.tight_layout()
fig.savefig(ROOT / "Plots" / "07c-heatmap.png", dpi=300)


###########
# 08 - Regression coefficients
###########

combined_results = load_combined()
n_issues = combined_results["issue"].nunique()

formula_terms = ["Democrat", "Republican", "Female", "Married", "College_Grad"]

all_coefs = []

for issue_index in range(n_issues):
    issue = issues.loc[issue_index, "issue"]
    issue_col = f"CC21_{issue}_t"

    reg_data = combined_results[combined_results["issue"] == issue].merge(
        dta1[["caseid", "gender", "married", "ed", issue_col]],
        on="caseid",
        how="left",
    )

    reg_data["llm_support"] = (reg_data["llm_response"] == "Support").astype(int)
    reg_data["cces_support"] = (reg_data[issue_col] == "Support").astype(int)
    reg_data["Female"] = (reg_data["gender"] == "Female").astype(int)
    reg_data["Married"] = (reg_data["married"] == "married").astype(int)
    reg_data["College_Grad"] = reg_data["ed"].isin(
        ["a 4-year college degree", "a post-graduate degree (e.g., MA, MBA, PhD, JD, etc.)"]
    ).astype(int)
    reg_data["Democrat"] = (reg_data["pid_text"] == "Democrat").astype(int)
    reg_data["Republican"] = (reg_data["pid_text"] == "Republican").astype(int)

    for outcome, source in [("cces_support", "CCES"), ("llm_support", "LLM")]:
        fit = smf.ols(f"{outcome} ~ {' + '.join(formula_terms)}", data=reg_data).fit()
        ci = fit.conf_int()
        for term in formula_terms:
            all_coefs.append(
                {
                    "term": term,
                    "estimate": fit.params[term],
                    "conf.low": ci.loc[term, 0],
                    "conf.high": ci.loc[term, 1],
                    "source": source,
                    "issue": issue,
                }
            )

all_coefs = pd.DataFrame(all_coefs)

all_coefs.to_pickle(results_path("regression-coefs.pkl"))
all_coefs.to_csv(results_path("regression-coefs.csv"), index=False)


###########
# 08b - Plot coefficient comparison
###########

all_coefs = pd.read_pickle(results_path("regression-coefs.pkl"))

plot_data = all_coefs.copy()
plot_data["term"] = plot_data["term"].replace({"College_Grad": "College+"})
plot_data["term"] = pd.Categorical(
    plot_data["term"],
    categories=["College+", "Married", "Female", "Republican", "Democrat"],
    ordered=True,
)

g = sns.FacetGrid(plot_data, col="issue", col_wrap=5, height=2.3, sharex=False)
g.map_dataframe(sns.pointplot, x="estimate", y="term", hue="source", dodge=0.4, errorbar=None)
for ax in g.axes.flat:
    ax.axvline(0, linestyle="--", alpha=0.5, color="black")
g.add_legend()
g.figure.suptitle("Regression coefficients: CCES vs LLM", y=1.02)
g.figure.tight_layout()
g.figure.savefig(ROOT / "Plots" / "08b-regression-comparison.png", dpi=300)

party_inflation = (
    all_coefs[all_coefs["term"].isin(["Democrat", "Republican"])]
    .assign(abs_estimate=lambda x: x["estimate"].abs())
    .groupby(["term", "source"])["abs_estimate"]
    .mean()
    .unstack()
)
party_inflation["pct_change"] = (party_inflation["LLM"] - party_inflation["CCES"]) / party_inflation["CCES"] * 100

print("Party coefficient inflation:")
for term, row in party_inflation.iterrows():
    print(f"  {term}: {round(row['pct_change'], 1)}% inflation")


###########
# 09a - Ideal points
###########

combined_results = load_combined()

stacked = combined_results.copy()
stacked["human"] = (stacked["real_response"] == "Support").astype(int)
stacked["llm"] = (stacked["llm_response"] == "Support").astype(int)

stacked = stacked.melt(
    id_vars=["caseid", "issue", "pid_text", "pid3"],
    value_vars=["human", "llm"],
    var_name="source",
    value_name="support",
)

stacked["respondent_id"] = stacked["source"] + "_" + stacked["caseid"].astype(str)

votes = stacked.pivot_table(index="respondent_id", columns="issue", values="support")

respondent_data = (
    stacked[["respondent_id", "caseid", "source", "pid_text", "pid3"]]
    .drop_duplicates()
    .reset_index(drop=True)
)

# The R code uses pscl::ideal. Here, PCA provides a simple one-dimensional
# analogue for a line-by-line Python example.
vote_matrix = votes.fillna(votes.mean()).to_numpy()
ideal_score = PCA(n_components=1).fit_transform(vote_matrix).ravel()

ideal_points = respondent_data.rename(columns={"pid_text": "party"}).copy()
ideal_points["ideal_point"] = ideal_score

party_medians_check = ideal_points.groupby("party")["ideal_point"].median()
if party_medians_check.get("Republican", 0) < party_medians_check.get("Democrat", 0):
    ideal_points["ideal_point"] = -ideal_points["ideal_point"]

ideal_points.to_pickle(results_path("ideal-points.pkl"))
ideal_points.to_csv(results_path("ideal-points.csv"), index=False)


###########
# 09b - Visualize ideal point distributions
###########

ideal_points = pd.read_pickle(results_path("ideal-points.pkl"))

ideal_plot = ideal_points[ideal_points["party"].isin(["Democrat", "Republican"])].copy()
ideal_plot["source"] = ideal_plot["source"].replace({"human": "Human (CCES)", "llm": "LLM"})

g = sns.displot(
    data=ideal_plot,
    x="ideal_point",
    hue="party",
    row="source",
    kind="kde",
    fill=True,
    alpha=0.4,
    height=2.5,
    aspect=1.4,
)
g.set_axis_labels("Ideal point (liberal to conservative)", "Density")
g.figure.savefig(ROOT / "Plots" / "09-ideal-points.png", dpi=300)


###########
# 10 - Ideal point comparison
###########

ideal_points = pd.read_pickle(results_path("ideal-points.pkl"))

comparison = (
    ideal_points.pivot_table(index="caseid", columns="source", values="ideal_point")
    .dropna(subset=["human", "llm"])
    .reset_index()
)

comparison_summary = pd.DataFrame(
    [
        {
            "n": len(comparison),
            "mean_sq_deviation": ((comparison["llm"] - comparison["human"]) ** 2).mean(),
            "correlation": comparison["llm"].corr(comparison["human"]),
        }
    ]
)

comparison_summary

print(
    f"""
Ideal point comparison (LLM vs Human):
  N: {comparison_summary.loc[0, "n"]}
  Mean Squared Deviation: {round(comparison_summary.loc[0, "mean_sq_deviation"], 3)}
  Correlation: {round(comparison_summary.loc[0, "correlation"], 3)}
"""
)

comparison_by_party = (
    ideal_points[ideal_points["party"].isin(["Democrat", "Republican", "Independent"])]
    .pivot_table(index=["caseid", "party"], columns="source", values="ideal_point")
    .dropna(subset=["human", "llm"])
    .reset_index()
    .groupby("party")
    .apply(
        lambda x: pd.Series(
            {
                "n": len(x),
                "msd": ((x["llm"] - x["human"]) ** 2).mean(),
                "correlation": x["llm"].corr(x["human"]),
            }
        )
    )
    .reset_index()
)

comparison_by_party

plot_data = (
    ideal_points[ideal_points["party"].isin(["Democrat", "Republican", "Independent"])]
    .pivot_table(index=["caseid", "party"], columns="source", values="ideal_point")
    .dropna(subset=["human", "llm"])
    .reset_index()
)

fig, ax = plt.subplots(figsize=(7, 5))
sns.scatterplot(data=plot_data, x="human", y="llm", hue="party", alpha=0.4, ax=ax)
sns.regplot(data=plot_data, x="human", y="llm", scatter=False, color="black", ax=ax)
ax.axline((0, 0), slope=1, linestyle="--", color="black")
ax.set_title("Ideal point agreement: LLM vs Human")
ax.set_xlabel("Human ideal point")
ax.set_ylabel("LLM ideal point")
fig.tight_layout()
fig.savefig(ROOT / "Plots" / "10-ideal-point-comparison.png", dpi=300)


###########
# 11 - Polarization
###########

ideal_points = pd.read_pickle(results_path("ideal-points.pkl"))

party_medians = (
    ideal_points[ideal_points["party"].isin(["Democrat", "Republican", "Independent"])]
    .groupby(["source", "party"])["ideal_point"]
    .median()
    .unstack()
)

party_medians

polarization = party_medians.copy()
polarization["polarization"] = polarization["Republican"] - polarization["Democrat"]
polarization = polarization.reset_index()

polarization

polarization_inflation = polarization.melt(
    id_vars="source",
    value_vars=["Democrat", "Independent", "Republican", "polarization"],
    var_name="metric",
    value_name="value",
).pivot(index="metric", columns="source", values="value")

polarization_inflation["metric"] = polarization_inflation.index
polarization_inflation["metric"] = polarization_inflation["metric"].replace(
    {"polarization": "R-D Polarization"}
)
polarization_inflation["change_pct"] = (
    (polarization_inflation["llm"] - polarization_inflation["human"])
    / polarization_inflation["human"].abs()
    * 100
).round(0)

polarization_inflation[["human", "llm"]] = polarization_inflation[["human", "llm"]].round(3)
polarization_inflation = polarization_inflation.reset_index(drop=True)

polarization_inflation.to_csv(ROOT / "Tables" / "polarization-inflation.csv", index=False)
polarization_inflation


###########
# 12 - Compare saved model runs
###########

combined_files = sorted((ROOT / "Processed").glob("*-combined_results.pkl"))

model_results = []
for path in combined_files:
    model = path.name.removesuffix("-combined_results.pkl")
    result = pd.read_pickle(path).copy()
    result["model"] = model
    model_results.append(result)

if model_results:
    all_model_results = pd.concat(model_results, ignore_index=True)
    print("Models found:", ", ".join(all_model_results["model"].unique()))

    overall_summary = (
        all_model_results.groupby("model")
        .apply(
            lambda x: pd.Series(
                {
                    "n": len(x),
                    "accuracy": round((x["match"] == "Correct").mean(), 3),
                    "pre": round(calc_pre(x["real_response"], x["match"]), 3),
                }
            )
        )
        .reset_index()
    )
    print("\n=== Overall accuracy and PRE ===")
    print(overall_summary.to_string(index=False))

    issue_summary = (
        all_model_results.groupby(["model", "issue"])
        .apply(lambda x: round(calc_pre(x["real_response"], x["match"]), 3))
        .rename("pre")
        .reset_index()
        .sort_values(["issue", "model"])
    )
    print("\n=== PRE by issue ===")
    print(issue_summary.to_string(index=False))

    party_summary = (
        all_model_results.groupby(["model", "pid_text"])
        .apply(
            lambda x: pd.Series(
                {
                    "accuracy": round((x["match"] == "Correct").mean(), 3),
                    "pre": round(calc_pre(x["real_response"], x["match"]), 3),
                }
            )
        )
        .reset_index()
    )
    print("\n=== Accuracy and PRE by party ===")
    print(party_summary.sort_values(["pid_text", "model"]).to_string(index=False))

ideal_files = sorted((ROOT / "Processed").glob("*-ideal-points.pkl"))
if ideal_files:
    ideal_summaries = []
    polarization_distances = []
    for path in ideal_files:
        model = path.name.removesuffix("-ideal-points.pkl")
        points = pd.read_pickle(path)

        median_points = (
            points.groupby(["source", "party"])["ideal_point"]
            .median()
            .round(3)
            .rename("median_ip")
            .reset_index()
        )
        median_points["model"] = model
        ideal_summaries.append(median_points)

        distances = (
            points[points["party"].isin(["Democrat", "Republican"])]
            .groupby(["source", "party"])["ideal_point"]
            .median()
            .unstack()
            .reset_index()
        )
        distances["distance"] = (distances["Republican"] - distances["Democrat"]).round(3)
        distances["model"] = model
        polarization_distances.append(distances[["source", "distance", "model"]])

    print("\n=== Polarization inflation (median ideal points by party) ===")
    print(pd.concat(ideal_summaries).sort_values(["source", "party", "model"]).to_string(index=False))

    print("\n=== Polarization distance (Republican - Democrat median) ===")
    print(pd.concat(polarization_distances).sort_values(["source", "model"]).to_string(index=False))

coef_files = sorted((ROOT / "Processed").glob("*-regression-coefs.pkl"))
if coef_files:
    coef_summaries = []
    for path in coef_files:
        model = path.name.removesuffix("-regression-coefs.pkl")
        coefs = pd.read_pickle(path)
        summary = (
            coefs[coefs["term"].isin(["Democrat", "Republican"])]
            .groupby(["source", "term"])["estimate"]
            .mean()
            .round(3)
            .rename("mean_estimate")
            .reset_index()
        )
        summary["model"] = model
        coef_summaries.append(summary)

    print("\n=== Partisan regression coefficients ===")
    print(pd.concat(coef_summaries).sort_values(["source", "term", "model"]).to_string(index=False))
