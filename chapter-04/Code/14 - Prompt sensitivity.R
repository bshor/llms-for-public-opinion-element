# Original coding guide ----
original_tariff_prompt <- paste(
  "Use this coding guide:",
  "",
  "1 = Support tariffs: favors tariffs or emphasizes job protection, domestic industry protection, economic independence, or strategic leverage.",
  "2 = Neutral or mixed: expresses uncertainty, insufficient information, ambivalence, or both positive and negative views.",
  "3 = Oppose tariffs: criticizes tariffs or emphasizes higher prices, inflation, inefficiency, retaliation, or trade wars.",
  "",
  "If the response is unclear, ambivalent, conflicted, or mixed, use Neutral.",
  "Use only the listed reasoning categories.",
  sep = "\n"
)

# Alternative coding guide ----
alternative_tariff_prompt <- paste(
  "Use this coding guide:",
  "",
  "Support: the respondent favors tariffs or emphasizes their benefits.",
  "Neutral: the respondent is uncertain, mixed, ambivalent, or lacks enough information.",
  "Oppose: the respondent criticizes tariffs or emphasizes their costs.",
  "",
  "When both positive and negative views are present, code the response as Neutral unless one side is clearly dominant.",
  "Use only the listed reasoning categories.",
  sep = "\n"
)
