# Chapter 2 results — gpt-5.4-nano era

Full snapshot of `Output/`, `Processed/`, `Plots/`, and `Tables/` taken on
2026-05-28, **before** rerunning the Chapter 2 pipeline with `gpt-5.4-mini`.

The cloud silicon-sampling results here were generated with **`gpt-5.4-nano`**
(`chat_openai(model = "gpt-5.4-nano")`). This is the state used in the
manuscript prior to the mini rerun.

Notes:
- `Processed/cloud-*` are the nano cloud results.
- `Processed/local-*` and `Output/03c-output.txt` are from the local Ollama
  model (`granite3.2:8b-instruct-q4_K_M`), unchanged by the cloud rerun;
  included here so the snapshot is complete.
- Downstream objects (`ideal-points.Rdata`, `regression-coefs.Rdata`), plots,
  and tables were derived from the nano cloud results.
