# Core packages for this chapter
install.packages(c("tidyverse", "here", "ellmer", "usethis"))

# Additional packages used in Chapter 2
install.packages(c("glue", "tictoc", "broom", "pscl"))

# Additional packages used in Chapter 3
install.packages(c("shiny", "shinyjs", "shinychat", "bslib"))

# Additional packages used in Chapter 4
install.packages(c("devtools", "future", "future.apply", "igraph", "ggraph"))

# dsl package for Chapter 4 (devtools necessary for install)
install_github("naoki-egami/dsl", dependencies = TRUE)
