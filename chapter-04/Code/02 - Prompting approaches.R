# Zero-shot prompt ----
prompt_zero <- paste(
  "Classify tariff position.",
  "1 = Support, 2 = Neutral, 3 = Oppose.",
  "Return only one number.",
  sep = "\n"
)

# One-shot prompt ----
prompt_one <- paste(
  "Classify tariff position.",
  "1 = Support, 2 = Neutral, 3 = Oppose.",
  "Return only one number.",
  "",
  "Example:",
  "Response: Tariffs help protect jobs.",
  "Answer: 1",
  "",
  "Now classify:",
  sep = "\n"
)

# Few-shot prompt ----
prompt_few <- paste(
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
  sep = "\n"
)
