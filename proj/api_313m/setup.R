# Setup R session for HKS API-313M: Tools of economic complexity analysis
#-------------------------------------------------------------------

package_list <-
  c(
    "learnr",
    "foreign",
    "tidylog",
    "economiccomplexity",
    "highcharter",
    "maps",
    "tidyverse",
    "arrow",
    "igraph",
    "viridis",
    "umap",
    "treemap",
    "sf",
    "leaflet",
    "tmap",
    "dataverse",
    "lubridate",
    "janitor",
    "zoo",
    "scales",
    "here",
    "modelsummary",
    "Matrix",
    "wbstats"
  )

# Check if packages are already installed, otherwise install them
to_install <-
  package_list[!(package_list %in% installed.packages()[, "Package"])]
if (length(to_install))
  install.packages(to_install)

# Harvard dataverse
remotes::install_github("iqss/dataverse-client-r")
Sys.setenv("DATAVERSE_SERVER" = "dataverse.harvard.edu")
