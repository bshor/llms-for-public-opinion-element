# sanitize_outputs.R
# Replace non-ASCII characters in Output/*.txt with ASCII equivalents.
# Run this after any pipeline execution to keep output files LaTeX-safe.
# LLM responses often contain curly quotes, em dashes, etc.

replacements <- list(
  "’" = "'",   # right single quotation mark
  "‘" = "'",   # left single quotation mark
  "“" = '"',   # left double quotation mark
  "”" = '"',   # right double quotation mark
  "—" = "---", # em dash
  "–" = "--",  # en dash
  "×" = "x",   # multiplication sign (appears in tibble output)
  "…" = "..."  # ellipsis
)

files <- list.files("Output", pattern = "\\.txt$", full.names = TRUE)

for (f in files) {
  text <- readLines(f, warn = FALSE, encoding = "UTF-8")
  cleaned <- text
  for (char in names(replacements)) {
    cleaned <- gsub(char, replacements[[char]], cleaned, fixed = TRUE)
  }
  if (!identical(cleaned, text)) {
    writeLines(cleaned, f)
    cat("Fixed:", basename(f), "\n")
  } else {
    cat("Clean:", basename(f), "\n")
  }
}
