# Load packages
packages <-
  c("tidyverse",
    "dataverse",
    "wbstats",
    "Matrix",
    "here")
sapply(packages, library, character.only = T)

# Set working directory appropriately
# setwd(PATH_TO_FOLDER) <--- only do this if "here" doesn't work for you
here::i_am("proj/api_313m/working_with_trade_data.R")
#-------------------------------------------------------------------

# Look for trade data from Harvard Dataverse
# https://dataverse.harvard.edu/dataverse/atlas
dataverse_dataset <- get_dataset("doi:10.7910/DVN/T4CHWJ")
dataverse_filelist <-
  dataverse_dataset$files[c("filename", "contentType")]

# Download trade data and HS product classifications
trade <-
  get_dataframe_by_name("country_hsproduct2digit_year.tab", "10.7910/DVN/T4CHWJ")
hs_product <-
  get_dataframe_by_name("hs_product.tab", "10.7910/DVN/3BAL1O")

# Backup download method
# https://intl-atlas-downloads.s3.amazonaws.com/country_hsproduct2digit_year.csv.zip

# Add actual HS product code to data
trade <- trade %>%
  left_join(select(hs_product, product_id, hs_product_code)) %>%
  select(-location_id,-product_id)

# Get some country-specific data
# Population, GDP per capita
wb_indicators <- c(gdp_capita = "NY.GDP.PCAP.CD",
                   pop = "SP.POP.TOTL")
wdi <-
  wb_data(wb_indicators, start_date = 1995, end_date = 2020) %>%
  select(-iso2c, -country)

# Some quick exploration
mean_trade <- trade %>%
  filter(year > 2015) %>%
  group_by(location_code, hs_product_code) %>%
  summarize(
    export_value = mean(export_value, na.rm = TRUE),
    import_value = mean(import_value, na.rm = TRUE),
  ) %>%
  ungroup()


# Distributions
summary(mean_trade)
ggplot(mean_trade) +
  geom_density(aes(x = export_value, color = "Exports"), alpha = 0.6) +
  geom_density(aes(x = import_value, color = "Imports"), alpha = 0.6) +
  scale_x_continuous(
    trans = "log",
    labels = scales::scientific_format(),
    breaks = scales::log_breaks(n = 8)
  ) +
  labs(
    x = "Trade value (USD)",
    y = "Density",
    color = NULL,
    caption = "Source: Atlas of Economic Complexity"
  ) +
  theme_minimal() +
  theme(
    axis.text = element_text(size = 12),
    axis.title = element_text(size = 15),
    legend.text = element_text(size = 12),
    legend.position = "bottom"
  )

# Alternate - tidy format
mean_trade %>%
  select(hs_product_code, export_value, import_value) %>%
  pivot_longer(export_value:import_value,
               names_to = "trade_type",
               values_to = "trade_value") %>%
  mutate(trade_type = str_sub(trade_type, end = -7)) -> mean_trade_long

mean_trade_long %>%
  ggplot(aes(x = trade_value, fill = trade_type)) +
  geom_histogram(alpha = 0.5, position = "identity") +
  scale_x_continuous(
    trans = "log",
    labels = scales::scientific_format(),
    breaks = scales::log_breaks(n = 6)
  ) +
  labs(
    x = "Trade value (USD)",
    y = "Count",
    fill = NULL,
    caption = "Source: Atlas of Economic Complexity"
  )


# Quick cleaning - only keep row if > 1% of country's exports / imports
mean_trade_clean <- mean_trade %>%
  group_by(location_code) %>%
  filter(
    export_value > 0.01 * sum(export_value, na.rm = TRUE) |
      import_value > 0.01 * sum(import_value, na.rm = TRUE)
  ) # At this stage, check if still grouped

# Alternate approach
mean_trade_alternate <- mean_trade %>%
  group_by(location_code) %>%
  mutate(
    export_value = na_if(
      export_value,
      export_value > 0.01 * sum(export_value, na.rm = TRUE)
    ),
    import_value = if_else(
      import_value > 0.01 * sum(import_value, na.rm = TRUE),
      import_value,
      NA_real_
    )
  ) %>%
  filter(!is.na(export_value) | !is.na(import_value))

# Economic complexity measures
# Prepare trade data
trade_year <- trade %>%
  filter(year == 2018) %>%
  select(location_code, hs_product_code, export_value) %>%
  filter(!(is.na(as.numeric(hs_product_code)))) %>% # Remove services
  pivot_wider(
    id_cols = "location_code",
    names_from = "hs_product_code",
    values_from = "export_value",
    values_fill = 0
  )

# Store locations and product codes for later
locations <- trade_year$location_code
products <- trade_year %>%
  select(-location_code) %>%
  names()

# Convert trade data into a matrix
trade_year <- trade_year %>%
  select(-location_code) %>%
  as.matrix() %>%
  Matrix(dimnames = list(locations = locations, products = products))


dim(trade_year / rowSums(trade_year))

# Get RCA
rca <-
  t(t(trade_year / rowSums(trade_year)) / (colSums(trade_year) / sum(trade_year)))

mcp <- (rca > 1)

# Diversity and ubiquity

# How diverse is a country? (how many products does it make competitively?)
diversity <- rowSums(mcp)

# How ubiquitous is a product? (how many countries make it competitively?)
ubiquity <- colSums(mcp)

# Make sure that diversity and ubiquity aren't zero
mcp <-
  mcp[rownames(mcp) %in% names(diversity[diversity > 0]),
      colnames(mcp) %in% names(ubiquity[ubiquity > 0])]

# Calculate ECI and PCI eigenvectors
mcp1 <- mcp / diversity
mcp2 <- t(t(mcp) / ubiquity)
Mcc <- mcp1 %*% t(mcp2)
Mpp <- t(mcp2) %*% mcp1

# compute eigenvalues for eci
eigenvecs <- eigen(Mpp)
kp <- Re(eigenvecs$vectors[, 2])
kc <- as.vector(mcp1 %*% kp)

# Adjust sign of ECI and PCI so it corresponds with diversity
s1 <-
  ifelse(cor(diversity, as.vector(kc), use = "pairwise.complete.obs") > 0,
         1,
         -1)
eci <- s1 * kc
pci <- s1 * kp
names(eci) <- rownames(rca)
names(pci) <- colnames(rca)

# Standardize
eci <- (eci - mean(eci)) / sd(eci)
pci <- (pci - mean(eci)) / sd(eci)

# Convert to dataframes with country and product characteristics
wdi_year <- wdi %>%
  rename(year = date) %>%
  filter(year == 2018)

eci_df <- enframe(eci) %>%
  rename(location_code = name, eci = value) %>%
  left_join(wdi_year, by = c("location_code" = "iso3c")) %>%
  arrange(-eci)

pci_df <- enframe(pci) %>%
  rename(hs_product_code = name, pci = value) %>%
  left_join(hs_product, by = "hs_product_code") %>%
  arrange(-pci)


eci_df %>%
  ggplot(aes(x = gdp_capita, y = eci, size = pop)) +
  geom_point() +
  geom_smooth(method = "lm") +
  scale_x_continuous(
    trans = "log",
    labels = scales::scientific_format(),
    breaks = scales::log_breaks(n = 8)
  ) +
  labs(
    x = "GDP Per Capita (current USD)",
    y = "ECI",
    color = NULL,
    caption = "Source: Atlas of Economic Complexity; World Bank WDI"
  ) +
  theme_minimal() +
  theme(legend.position = "none")


# Exercise (if you have extra time)
# 1) Can you implement the method of reflections in R?
# 2) Can you pull data from the DEV309 dataset and plot the correlations between
# ECI and a host of outcome variables across countries?
# 3) What are the differences between computed ECI at the 2 and 4-digit levels?
