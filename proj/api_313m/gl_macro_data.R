# Load packages
packages <-
  c("tidyverse",
    "dataverse",
    "arrow",
    "Matrix",
    "here")
sapply(packages, library, character.only = T)

# Set working directory appropriately
# setwd(PATH_TO_FOLDER) <--- only do this if "here" doesn't work for you
here::i_am("proj/api_313m/gl_macro_data.R")
#-------------------------------------------------------------------

# Read GL Macro data
gl_macro <-
  read_parquet(
    here("data", "raw", "gl_macro", "glmacro_master_alldata.parquet"),
    col_select = c(
      "weo_countrycodeiso",
      "year",
      "weo_ngdpdpc",
      "wdi_en_atm_co2e_pc",
      "weo_lp",
      "wb_regionname"
    )
  ) %>%
  rename(
    country_code = weo_countrycodeiso,
    year = year,
    gdp_pc = weo_ngdpdpc,
    co2_pc = wdi_en_atm_co2e_pc,
    pop = weo_lp,
    region = wb_regionname
  )

# Check for duplicates at the country-year level
gl_macro %>%
  group_by(country_code, year) %>%
  summarise(n = n()) %>%
  filter(n > 1)

# Keep latest data available for each country
gl_macro <-
  gl_macro %>% # Filter out null country codes and weo_ngdpdpc
  drop_na() %>%
  group_by(country_code) %>%
  filter(year == max(year)) %>%
  ungroup()

# Show the min, mean, median, max for the year variable
gl_macro %>%
  summarise(
    min_year = min(year),
    mean_year = mean(year),
    median_year = median(year),
    max_year = max(year)
  )


# Plot, with log GDP per capita on the x-axis, and log CO2 emissions per capita on the y-axis,
# Size of points given by population, and color by region
ggplot(gl_macro, aes(
  x = log(gdp_pc),
  y = log(co2_pc),
  size = pop,
  color = region
)) +
  geom_point() +
  scale_size_continuous(range = c(1, 10)) +
  labs(x = "Log GDP per capita",
       y = "Log CO2 emissions per capita",
       size = "Population (millions)",
       color = "Region") +
  theme_bw()