# Co-occurrence network of reasoning categories ----

cooccur_data <- tariff_hybrid_annotation_data_binary %>%
  dplyr::select(
    domestic_industry_protection,
    job_creation,
    price_increase_concern,
    economic_impact,
    equity_and_fairness,
    nationalism_and_economic_independence,
    lack_of_understanding_indecision,
    retaliation_and_trade_wars,
    political_and_strategic_considerations
  )

# Create co-occurrence matrix ----
cooccur_mat <- t(as.matrix(cooccur_data)) %*% as.matrix(cooccur_data)

# Remove diagonal ----
diag(cooccur_mat) <- 0

# Convert to edge list ----
cooccur_edges <- as.data.frame(as.table(cooccur_mat)) %>%
  filter(Freq > 0) %>%
  rename(from = Var1, to = Var2, weight = Freq)

# Create graph object ----
cooccur_graph <- graph_from_data_frame(cooccur_edges, directed = FALSE)

# Clean node labels ----
V(cooccur_graph)$name <- V(cooccur_graph)$name %>%
  gsub("_", " ", .) %>%
  tools::toTitleCase()

p_cooccurrence_network <- ggraph(cooccur_graph, layout = "fr") +
  geom_edge_link(aes(width = weight), alpha = 0.2, color = "gray70") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE) +
  scale_edge_width(name = "Weight") +
  theme_void()

p_cooccurrence_network

ggsave(
  filename = "Plots/cooccurrence_network.png",
  plot = p_cooccurrence_network,
  width = 8,
  height = 6,
  dpi = 300
)
