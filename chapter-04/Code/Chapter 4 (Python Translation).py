"""
Analysis code for Chapter 4, translated from R to Python.

This file is intentionally written so you can run it line-by-line in an
interactive console, like the R examples. Functions are only introduced where
the corresponding R script introduces functions.

Suggested packages:

    pip install openai pandas numpy matplotlib seaborn networkx scikit-learn statsmodels requests
"""

import json
import os
import re
import time
from pathlib import Path

import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import pandas as pd
import seaborn as sns
import statsmodels.formula.api as smf
from openai import OpenAI
from sklearn.metrics.pairwise import cosine_similarity as sklearn_cosine_similarity


###########
# Setup
###########

ROOT = Path(__file__).resolve().parent

env_path = ROOT / ".env"
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

client = OpenAI()


###########
# 4.2.3 Structuring the Dataset
###########

# Load the dataset tariff_data_sample.csv
tariff_data_sample = pd.read_csv(ROOT / "tariff_data_sample.csv")
tariff_data_sample

# Dataset includes variables:
#   pid = unique respondent identifier
#   tariffs_conversation = full tariff interview transcript


###########
# Function to extract and clean participant text
###########


def clean_participant_text(text):
    if pd.isna(text) or str(text).strip() == "":
        return np.nan

    participant_turns = re.findall(
        r"Participant:\s*(.*?)(?=\s*AI:|$)",
        str(text),
        flags=re.DOTALL,
    )

    participant_turns = [re.sub(r"\s+", " ", x).strip() for x in participant_turns]
    participant_turns = [x for x in participant_turns if x != ""]

    if len(participant_turns) == 0:
        return np.nan

    participant_text = " ".join(participant_turns)
    participant_text = re.sub(r"[^\w\s\.,;:!?'\-\"()/]", "", participant_text)
    participant_text = re.sub(r"\s+", " ", participant_text).strip()

    return participant_text


tariff_annotation_data = tariff_data_sample.copy()
tariff_annotation_data["tariffs_part_words"] = tariff_annotation_data["tariffs_conversation"].map(
    clean_participant_text
)
tariff_annotation_data["tariffs_part_nwords"] = (
    tariff_annotation_data["tariffs_part_words"].fillna("").str.count(r"\S+")
)
tariff_annotation_data = tariff_annotation_data[
    ["pid", "tariffs_part_words", "tariffs_part_nwords"]
]
tariff_annotation_data = tariff_annotation_data[
    tariff_annotation_data["tariffs_part_words"].notna()
    & (tariff_annotation_data["tariffs_part_words"] != "")
]

tariff_annotation_data
tariff_annotation_data.to_csv(ROOT / "tariff_annotation_data.csv", index=False)


###########
# 4.3.3 Model Prompting
###########

prompt_zero = "\n".join(
    [
        "Classify tariff position.",
        "1 = Support, 2 = Neutral, 3 = Oppose.",
        "Return only one number.",
    ]
)

prompt_one = "\n".join(
    [
        "Classify tariff position.",
        "1 = Support, 2 = Neutral, 3 = Oppose.",
        "Return only one number.",
        "",
        "Example:",
        "Response: Tariffs help protect jobs.",
        "Answer: 1",
        "",
        "Now classify:",
    ]
)

prompt_few = "\n".join(
    [
        "Classify tariff position.",
        "1 = Support, 2 = Neutral, 3 = Oppose.",
        "Return only one number.",
        "",
        "Examples:",
        "Response: Tariffs help protect jobs. Answer: 1",
        "Response: I need more information. Answer: 2",
        "Response: Tariffs raise prices. Answer: 3",
        "",
        "Now classify:",
    ]
)

prompt_zero
prompt_one
prompt_few


###########
# 4.3.9 AI Annotation Coding Example
###########

chat_system_prompt = "You are a professional research assistant coding survey responses about tariffs."

reasoning_categories = [
    "Domestic Industry Protection",
    "Job Creation",
    "Price Increase Concern",
    "Economic Impact",
    "Equity and Fairness",
    "Nationalism and Economic Independence",
    "Lack of Understanding/Indecision",
    "Retaliation and Trade Wars",
    "Political and Strategic Considerations",
]

tariff_schema = {
    "type": "json_schema",
    "json_schema": {
        "name": "tariff_annotation",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "tariff_position_hybrid": {
                    "type": "string",
                    "enum": ["Support", "Neutral", "Oppose"],
                },
                "tariff_position_hybrid_num": {"type": "integer"},
                "tariff_reasoning_hybrid": {
                    "type": "array",
                    "items": {"type": "string", "enum": reasoning_categories},
                },
                "tariff_supporting_excerpt": {"type": "string"},
                "tariff_response_summary": {"type": "string"},
            },
            "required": [
                "tariff_position_hybrid",
                "tariff_position_hybrid_num",
                "tariff_reasoning_hybrid",
                "tariff_supporting_excerpt",
                "tariff_response_summary",
            ],
            "additionalProperties": False,
        },
    },
}

tariff_prompt = "\n".join(
    [
        "Use this coding guide:",
        "",
        "1 = Support tariffs: favors tariffs or emphasizes job protection, domestic industry protection, economic independence, or strategic leverage.",
        "2 = Neutral or mixed: expresses uncertainty, insufficient information, ambivalence, or both positive and negative views.",
        "3 = Oppose tariffs: criticizes tariffs or emphasizes higher prices, inflation, inefficiency, retaliation, or trade wars.",
        "",
        "If the response is unclear, ambivalent, conflicted, or mixed, use Neutral.",
        "Use only the listed reasoning categories.",
    ]
)


###########
# Structured annotation function
###########


def annotate_tariff_response(text):
    raw_response = client.chat.completions.create(
        model="gpt-5.4-mini",
        temperature=0,
        messages=[
            {"role": "system", "content": chat_system_prompt},
            {"role": "user", "content": tariff_prompt + "\n\nResponse:\n" + str(text)},
        ],
        response_format=tariff_schema,
    )
    return json.loads(raw_response.choices[0].message.content)


tariff_prompts = [
    tariff_prompt + "\n\nResponse:\n" + text
    for text in tariff_annotation_data["tariffs_part_words"]
]

tariff_labels = []
for prompt in tariff_prompts:
    raw_response = client.chat.completions.create(
        model="gpt-5.4-mini",
        temperature=0,
        messages=[
            {"role": "system", "content": chat_system_prompt},
            {"role": "user", "content": prompt},
        ],
        response_format=tariff_schema,
    )
    tariff_labels.append(json.loads(raw_response.choices[0].message.content))

tariff_labels = pd.DataFrame(tariff_labels)

tariff_hybrid_annotation_data = pd.concat(
    [tariff_annotation_data.reset_index(drop=True), tariff_labels.reset_index(drop=True)],
    axis=1,
)
tariff_hybrid_annotation_data["pid"] = tariff_hybrid_annotation_data["pid"].astype(str)
tariff_hybrid_annotation_data["tariff_position_hybrid_num"] = tariff_hybrid_annotation_data[
    "tariff_position_hybrid"
].map({"Support": 1, "Neutral": 2, "Oppose": 3})
tariff_hybrid_annotation_data["tariff_position_hybrid_factor"] = pd.Categorical(
    tariff_hybrid_annotation_data["tariff_position_hybrid"],
    categories=["Support", "Neutral", "Oppose"],
    ordered=True,
)
tariff_hybrid_annotation_data["tariff_reasoning_hybrid"] = tariff_hybrid_annotation_data[
    "tariff_reasoning_hybrid"
].map(lambda x: ", ".join(x))

tariff_hybrid_annotation_data
tariff_hybrid_annotation_data.to_csv(ROOT / "tariff_hybrid_annotation_data.csv", index=False)


###########
# 4.3.10 Assessing Robustness Across Runs
###########

test_response = tariff_annotation_data["tariffs_part_words"].iloc[0]

results_run1 = annotate_tariff_response(test_response)
results_run2 = annotate_tariff_response(test_response)

results_run1
results_run2

results_run1["tariff_position_hybrid"] == results_run2["tariff_position_hybrid"]
results_run1["tariff_reasoning_hybrid"] == results_run2["tariff_reasoning_hybrid"]


###########
# 4.4 Parsing Outputs for Analysis
###########

reasoning_categories = [
    "Domestic Industry Protection",
    "Job Creation",
    "Price Increase Concern",
    "Economic Impact",
    "Equity and Fairness",
    "Nationalism and Economic Independence",
    "Lack of Understanding/Indecision",
    "Retaliation and Trade Wars",
    "Political and Strategic Considerations",
]

tariff_hybrid_annotation_data_binary = tariff_hybrid_annotation_data.copy()

for cat in reasoning_categories:
    var_name = cat.lower()
    var_name = re.sub(r"[ /]", "_", var_name)
    var_name = re.sub(r"[^a-z0-9_]", "", var_name)

    tariff_hybrid_annotation_data_binary[var_name] = (
        tariff_hybrid_annotation_data_binary["tariff_reasoning_hybrid"]
        .str.contains(cat, case=False, na=False)
        .astype(int)
    )
    tariff_hybrid_annotation_data_binary[var_name] = tariff_hybrid_annotation_data_binary[
        var_name
    ].fillna(0)

tariff_hybrid_annotation_data_binary
tariff_hybrid_annotation_data_binary.to_csv(
    ROOT / "tariff_hybrid_annotation_data_binary.csv",
    index=False,
)


###########
# 4.4.1 Visualizing AI Annotation
###########

reasoning_cols = [
    "domestic_industry_protection",
    "job_creation",
    "price_increase_concern",
    "economic_impact",
    "equity_and_fairness",
    "nationalism_and_economic_independence",
    "lack_of_understandingindecision",
    "retaliation_and_trade_wars",
    "political_and_strategic_considerations",
]

# The slash in "Lack of Understanding/Indecision" is removed by the variable-name cleanup above.
reasoning_cols = [x for x in reasoning_cols if x in tariff_hybrid_annotation_data_binary.columns]

prevalence_data = tariff_hybrid_annotation_data_binary[reasoning_cols].mean().reset_index()
prevalence_data.columns = ["category", "prevalence"]
prevalence_data["category"] = prevalence_data["category"].str.replace("_", " ").str.title()
prevalence_data = prevalence_data.sort_values("prevalence")

p_reasoning_prevalence, ax = plt.subplots(figsize=(7, 5))
sns.barplot(data=prevalence_data, x="prevalence", y="category", color="black", ax=ax)
ax.set_xlabel("Prevalence")
ax.set_ylabel("")
p_reasoning_prevalence.tight_layout()
p_reasoning_prevalence.savefig(ROOT / "p_reasoning_prevalence.png", dpi=300)


###########
# Co-occurrence network of reasoning categories
###########

cooccur_data = tariff_hybrid_annotation_data_binary[reasoning_cols]

cooccur_mat = cooccur_data.to_numpy().T @ cooccur_data.to_numpy()
np.fill_diagonal(cooccur_mat, 0)

cooccur_edges = []
for i, from_col in enumerate(reasoning_cols):
    for j, to_col in enumerate(reasoning_cols):
        if j <= i:
            continue
        weight = cooccur_mat[i, j]
        if weight > 0:
            cooccur_edges.append({"from": from_col, "to": to_col, "weight": weight})

cooccur_edges = pd.DataFrame(cooccur_edges)

cooccur_graph = nx.Graph()
for col in reasoning_cols:
    cooccur_graph.add_node(col, name=col.replace("_", " ").title())
for _, row in cooccur_edges.iterrows():
    cooccur_graph.add_edge(row["from"], row["to"], weight=row["weight"])

pos = nx.spring_layout(cooccur_graph, seed=123)
p_cooccurrence_network, ax = plt.subplots(figsize=(8, 6))
weights = [cooccur_graph[u][v]["weight"] for u, v in cooccur_graph.edges()]
if weights:
    nx.draw_networkx_edges(
        cooccur_graph,
        pos,
        width=[w / max(weights) * 4 for w in weights],
        alpha=0.2,
        edge_color="gray",
        ax=ax,
    )
nx.draw_networkx_nodes(cooccur_graph, pos, node_size=300, node_color="black", ax=ax)
nx.draw_networkx_labels(
    cooccur_graph,
    pos,
    labels={n: cooccur_graph.nodes[n]["name"] for n in cooccur_graph.nodes()},
    font_size=8,
    ax=ax,
)
ax.axis("off")
p_cooccurrence_network.tight_layout()
p_cooccurrence_network.savefig(ROOT / "cooccurrence_network.png", dpi=300)


###########
# 4.5.2 Constructing the Comparison Dataset
###########

human_coded_data = pd.read_csv(ROOT / "human_coded_data.csv")
human_coded_data


###########
# Standardize ordering of reasoning categories
###########


def standardize_reasoning(x):
    if pd.isna(x) or str(x).strip() == "" or str(x).strip().lower() == "none":
        return np.nan

    parts = [part.strip() for part in str(x).split(",")]
    parts = sorted(set(part for part in parts if part != ""))

    return ", ".join(parts)


comparison_data = human_coded_data.copy()
comparison_data["pid"] = comparison_data["pid"].astype(str)
comparison_data["human_tariff_position_factor"] = pd.Categorical(
    comparison_data["human_tariff_position"],
    categories=["Support", "Neutral", "Oppose"],
    ordered=True,
)
comparison_data["human_tariff_position_num"] = comparison_data["human_tariff_position"].map(
    {"Support": 1, "Neutral": 2, "Oppose": 3}
)
comparison_data["human_tariff_reasoning_standardized"] = comparison_data[
    "human_tariff_reasoning"
].map(standardize_reasoning)

comparison_data = comparison_data[
    [
        "pid",
        "tariffs_part_words",
        "human_tariff_position_factor",
        "human_tariff_position_num",
        "human_tariff_reasoning",
        "human_tariff_reasoning_standardized",
    ]
]

ai_data = tariff_hybrid_annotation_data.copy()
ai_data["pid"] = ai_data["pid"].astype(str)
ai_data["tariff_reasoning_hybrid_standardized"] = ai_data["tariff_reasoning_hybrid"].map(
    standardize_reasoning
)
ai_data = ai_data[
    [
        "pid",
        "tariff_position_hybrid_factor",
        "tariff_position_hybrid_num",
        "tariff_reasoning_hybrid",
        "tariff_reasoning_hybrid_standardized",
    ]
]

comparison_data = comparison_data.merge(ai_data, on="pid", how="left")

comparison_data
comparison_data.to_csv(ROOT / "comparison_data.csv", index=False)


###########
# 4.5.3 Summarizing Agreement and Differences
###########

levels = ["Support", "Neutral", "Oppose"]

conf_mat = pd.crosstab(
    comparison_data["human_tariff_position_factor"],
    comparison_data["tariff_position_hybrid_factor"],
)
conf_mat = conf_mat.reindex(index=levels, columns=levels, fill_value=0)

p_conf_matrix, ax = plt.subplots(figsize=(6, 5))
sns.heatmap(conf_mat, annot=True, fmt="d", cmap="Greys", cbar_kws={"label": "Count"}, ax=ax)
ax.set_xlabel("AI Coding")
ax.set_ylabel("Human Coding")
p_conf_matrix.tight_layout()
p_conf_matrix.savefig(ROOT / "confusion_matrix.png", dpi=300)


###########
# AI-human coding difference plot
###########

human_dist = (
    comparison_data["human_tariff_position_factor"]
    .value_counts(normalize=True)
    .reindex(levels, fill_value=0)
)
ai_dist = (
    comparison_data["tariff_position_hybrid_factor"]
    .value_counts(normalize=True)
    .reindex(levels, fill_value=0)
)

diff_data = pd.DataFrame({"position": levels, "Human": human_dist.values, "AI": ai_dist.values})
diff_data["diff"] = diff_data["AI"] - diff_data["Human"]

p_diff_plot, ax = plt.subplots(figsize=(6, 5))
sns.barplot(data=diff_data, x="position", y="diff", color="black", ax=ax)
ax.axhline(0, linestyle="--", color="black")
ax.set_xlabel("Tariff Position")
ax.set_ylabel("AI - Human Difference")
p_diff_plot.tight_layout()
p_diff_plot.savefig(ROOT / "diff_plot.png", dpi=300)


###########
# 4.6.1 Bias Correction for Category Prevalence
###########

labeled_subset = comparison_data[
    comparison_data["human_tariff_position_num"].notna()
    & comparison_data["tariff_position_hybrid_num"].notna()
]

error_rate = (
    labeled_subset["tariff_position_hybrid_num"]
    != labeled_subset["human_tariff_position_num"]
).mean()

error_rate

Y_hat = (tariff_hybrid_annotation_data["tariff_position_hybrid_num"] == 1).mean()
Y_hat_n = (labeled_subset["tariff_position_hybrid_num"] == 1).mean()
Y_n = (labeled_subset["human_tariff_position_num"] == 1).mean()

p_Y_tilde = Y_hat - (Y_hat_n - Y_n)
p_Y_tilde


###########
# Supplemental Code
###########

tariff_sentence_annotation_data = tariff_annotation_data[["pid", "tariffs_part_words"]].copy()
sentence_rows = []

for _, row in tariff_sentence_annotation_data.iterrows():
    sentence_list = re.split(r"(?<=[.!?])\s+", row["tariffs_part_words"])
    sentence_list = [x.strip() for x in sentence_list if x.strip() != ""]
    out = {"pid": row["pid"], "tariffs_part_words": row["tariffs_part_words"]}
    for sentence_num, sentence in enumerate(sentence_list, start=1):
        out[f"sentence{sentence_num}"] = sentence
    sentence_rows.append(out)

tariff_sentence_annotation_data = pd.DataFrame(sentence_rows)
tariff_sentence_annotation_data
tariff_sentence_annotation_data.to_csv(ROOT / "tariff_sentence_annotation_data.csv", index=False)


###########
# Retrieval-augmented generation (RAG) workflow
###########

rag_chat_system_prompt = "You are a professional research assistant coding survey responses about tariffs."

retrieval_database = comparison_data[
    comparison_data["human_tariff_position_factor"].notna()
    & comparison_data["tariffs_part_words"].notna()
].copy()
retrieval_database = retrieval_database.drop_duplicates("pid")
retrieval_database = retrieval_database[
    ["pid", "tariffs_part_words", "human_tariff_position_factor", "human_tariff_reasoning"]
]


###########
# Embedding helper
###########


def get_openai_embedding(text):
    out = client.embeddings.create(
        model="text-embedding-3-small",
        input=str(text),
    )
    return out.data[0].embedding


retrieval_matrix = np.vstack(
    [get_openai_embedding(text) for text in retrieval_database["tariffs_part_words"]]
)


###########
# Cosine similarity function
###########


def cosine_similarity(x, y):
    x = np.array(x)
    y = np.array(y)
    return np.sum(x * y) / (np.sqrt(np.sum(x**2)) * np.sqrt(np.sum(y**2)))


reasoning_categories = [
    "Domestic Industry Protection",
    "Job Creation",
    "Price Increase Concern",
    "Economic Impact",
    "Equity and Fairness",
    "Nationalism and Economic Independence",
    "Lack of Understanding/Indecision",
    "Retaliation and Trade Wars",
    "Political and Strategic Considerations",
]

rag_tariff_schema = {
    "type": "json_schema",
    "json_schema": {
        "name": "rag_tariff_annotation",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "tariff_position_rag": {
                    "type": "string",
                    "enum": ["Support", "Neutral", "Oppose"],
                },
                "tariff_position_rag_num": {"type": "integer"},
                "tariff_reasoning_rag": {
                    "type": "array",
                    "items": {"type": "string", "enum": reasoning_categories},
                },
                "tariff_supporting_excerpt_rag": {"type": "string"},
                "tariff_response_summary_rag": {"type": "string"},
            },
            "required": [
                "tariff_position_rag",
                "tariff_position_rag_num",
                "tariff_reasoning_rag",
                "tariff_supporting_excerpt_rag",
                "tariff_response_summary_rag",
            ],
            "additionalProperties": False,
        },
    },
}


###########
# Retrieve similar examples
###########


def retrieve_examples(text, k=3):
    query_embedding = get_openai_embedding(text)

    similarities = np.array(
        [cosine_similarity(x, query_embedding) for x in retrieval_matrix]
    )

    top_indices = np.argsort(similarities)[::-1][:k]

    return retrieval_database.iloc[top_indices]


###########
# Construct retrieval-augmented prompt
###########


def build_rag_prompt(text, examples):
    example_blocks = []
    for example_num, (_, row) in enumerate(examples.iterrows(), start=1):
        example_blocks.append(
            "Example "
            + str(example_num)
            + ":\n"
            + "Response: "
            + str(row["tariffs_part_words"])
            + "\n"
            + "Position: "
            + str(row["human_tariff_position_factor"])
            + "\n"
            + "Reasoning: "
            + str(row["human_tariff_reasoning"])
        )

    example_block = "\n\n".join(example_blocks)

    return "\n".join(
        [
            "Use the retrieved examples below to guide classification.",
            "",
            "Code the response using these labels:",
            "1 = Support tariffs",
            "2 = Neutral or mixed",
            "3 = Oppose tariffs",
            "",
            "Use only the listed reasoning categories.",
            "",
            "Retrieved examples:",
            example_block,
            "",
            "Now code this response:",
            str(text),
        ]
    )


###########
# RAG annotation function
###########


def annotate_tariff_response_rag(text):
    time.sleep(1)

    examples = retrieve_examples(text, k=3)

    rag_prompt = build_rag_prompt(text, examples)

    raw_response = client.chat.completions.create(
        model="gpt-5.4-mini",
        temperature=0,
        messages=[
            {"role": "system", "content": rag_chat_system_prompt},
            {"role": "user", "content": rag_prompt},
        ],
        response_format=rag_tariff_schema,
    )

    return json.loads(raw_response.choices[0].message.content)


tariff_annotation_subset = tariff_annotation_data.iloc[:10].copy()

tariff_rag_results = [
    annotate_tariff_response_rag(text)
    for text in tariff_annotation_subset["tariffs_part_words"]
]

tariff_rag_labels = pd.DataFrame(tariff_rag_results)

tariff_rag_annotation_data = pd.concat(
    [tariff_annotation_subset.reset_index(drop=True), tariff_rag_labels.reset_index(drop=True)],
    axis=1,
)
tariff_rag_annotation_data["pid"] = tariff_rag_annotation_data["pid"].astype(str)
tariff_rag_annotation_data["tariff_position_rag_factor"] = pd.Categorical(
    tariff_rag_annotation_data["tariff_position_rag"],
    categories=["Support", "Neutral", "Oppose"],
    ordered=True,
)
tariff_rag_annotation_data["tariff_reasoning_rag"] = tariff_rag_annotation_data[
    "tariff_reasoning_rag"
].map(lambda x: ", ".join(x))

tariff_rag_annotation_data
tariff_rag_annotation_data.to_csv(ROOT / "tariff_rag_annotation_data.csv", index=False)
