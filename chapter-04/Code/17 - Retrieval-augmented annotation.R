# Retrieval-augmented generation (RAG) workflow ----

# Demonstration version: only the first 10 responses are annotated. Running the
# full workflow can take substantial time because each response requires
# embedding retrieval and model-based annotation.

rag_chat <- chat_openai(
  system_prompt = "You are a professional research assistant coding survey responses about tariffs.",
  model = "gpt-4o",
  params = params(temperature = 0),
  echo = "none"
)

# Create retrieval database from human-coded examples ----
retrieval_database <- comparison_data %>%
  filter(
    !is.na(human_tariff_position_factor),
    !is.na(tariffs_part_words)
  ) %>%
  distinct(pid, .keep_all = TRUE) %>%
  select(
    pid,
    tariffs_part_words,
    human_tariff_position_factor,
    human_tariff_reasoning
  )

# Embedding helper ----
get_openai_embedding <- function(text) {

  out <- create_embedding(
    model = "text-embedding-3-small",
    input = text
  )

  emb <- unlist(out, use.names = FALSE)
  emb <- emb[!is.na(suppressWarnings(as.numeric(emb)))]
  emb <- as.numeric(emb)

  return(emb)
}

# Create embedding matrix ----
retrieval_matrix <- do.call(
  rbind,
  lapply(
    retrieval_database$tariffs_part_words,
    get_openai_embedding
  )
)

# Cosine similarity function ----
cosine_similarity <- function(x, y) {
  sum(x * y) / (sqrt(sum(x^2)) * sqrt(sum(y^2)))
}

# Structured response: allowed reasoning categories ----
reasoning_categories <- c(
  "Domestic Industry Protection",
  "Job Creation",
  "Price Increase Concern",
  "Economic Impact",
  "Equity and Fairness",
  "Nationalism and Economic Independence",
  "Lack of Understanding/Indecision",
  "Retaliation and Trade Wars",
  "Political and Strategic Considerations"
)

# Structured response schema ----
rag_tariff_schema <- type_object(
  "Code one survey response about tariffs.",
  tariff_position_rag = type_enum(
    c("Support", "Neutral", "Oppose")
  ),
  tariff_position_rag_num = type_integer(),
  tariff_reasoning_rag = type_array(
    type_enum(reasoning_categories)
  ),
  tariff_supporting_excerpt_rag = type_string(),
  tariff_response_summary_rag = type_string()
)

# Retrieve similar examples ----
retrieve_examples <- function(text, k = 3) {

  query_embedding <- get_openai_embedding(text)

  similarities <- apply(
    retrieval_matrix,
    1,
    function(x) cosine_similarity(x, query_embedding)
  )

  top_indices <- order(
    similarities,
    decreasing = TRUE
  )[1:k]

  retrieval_database[top_indices, ]
}

# Construct retrieval-augmented prompt ----
build_rag_prompt <- function(text, examples) {

  example_block <- paste0(
    "Example ", seq_len(nrow(examples)), ":\n",
    "Response: ", examples$tariffs_part_words, "\n",
    "Position: ", examples$human_tariff_position_factor, "\n",
    "Reasoning: ", examples$human_tariff_reasoning,
    collapse = "\n\n"
  )

  paste(
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
    text,
    sep = "\n"
  )
}

# RAG annotation function ----
annotate_tariff_response_rag <- function(text) {

  # Pause briefly to reduce rate-limit errors ----
  Sys.sleep(1)

  examples <- retrieve_examples(text, k = 3)

  rag_prompt <- build_rag_prompt(
    text,
    examples
  )

  rag_chat$chat_structured(
    rag_prompt,
    type = rag_tariff_schema
  )
}

# Select only the first 10 responses ----
tariff_annotation_subset <- tariff_annotation_data %>%
  slice(1:10)

# Run RAG annotation on first 10 responses ----
tariff_rag_results <- lapply(
  tariff_annotation_subset$tariffs_part_words,
  annotate_tariff_response_rag
)

# Convert list output to tibble ----
tariff_rag_labels <- tibble(
  tariff_position_rag = map_chr(
    tariff_rag_results,
    "tariff_position_rag"
  ),
  tariff_position_rag_num = map_int(
    tariff_rag_results,
    "tariff_position_rag_num"
  ),
  tariff_reasoning_rag = map(
    tariff_rag_results,
    "tariff_reasoning_rag"
  ),
  tariff_supporting_excerpt_rag = map_chr(
    tariff_rag_results,
    "tariff_supporting_excerpt_rag"
  ),
  tariff_response_summary_rag = map_chr(
    tariff_rag_results,
    "tariff_response_summary_rag"
  )
)

# Combine RAG labels with original data ----
tariff_rag_annotation_data <- tariff_annotation_subset %>%
  mutate(pid = as.character(pid)) %>%
  bind_cols(tariff_rag_labels) %>%
  mutate(
    tariff_position_rag_factor = factor(
      tariff_position_rag,
      levels = c("Support", "Neutral", "Oppose")
    ),
    tariff_reasoning_rag = map_chr(
      tariff_reasoning_rag,
      ~ paste(.x, collapse = ", ")
    )
  )

# View RAG annotation dataset ----
View(tariff_rag_annotation_data)
