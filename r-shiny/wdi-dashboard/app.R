# =============================================================================
# World Development Indicators Dashboard -- Impact Mojo
# A self-contained R Shiny application for exploring synthetic WDI-style data
# Libraries: shiny, ggplot2, dplyr, tidyr, DT
# =============================================================================

library(shiny)
library(ggplot2)
library(dplyr)
library(tidyr)
library(DT)

# =============================================================================
# 1. SYNTHETIC DATA GENERATION
# =============================================================================

set.seed(42)

# --- Country / Region definitions -------------------------------------------

countries_by_region <- list(
  "Sub-Saharan Africa" = c(
    "Nigeria", "Ethiopia", "Kenya", "Tanzania", "South Africa",
    "Ghana", "Senegal", "Uganda", "Mozambique", "Rwanda"
  ),
  "South Asia" = c(
    "India", "Bangladesh", "Pakistan", "Sri Lanka", "Nepal",
    "Afghanistan", "Bhutan"
  ),
  "East Asia & Pacific" = c(
    "China", "Indonesia", "Vietnam", "Philippines", "Thailand",
    "Malaysia", "Cambodia", "Myanmar"
  ),
  "Latin America & Caribbean" = c(
    "Brazil", "Mexico", "Colombia", "Peru", "Chile",
    "Argentina", "Ecuador", "Guatemala"
  ),
  "Middle East & North Africa" = c(
    "Egypt", "Morocco", "Tunisia", "Jordan", "Iran",
    "Iraq", "Algeria"
  ),
  "Europe & Central Asia" = c(
    "Turkey", "Poland", "Romania", "Ukraine", "Kazakhstan",
    "Georgia", "Serbia", "Bulgaria", "Hungary", "Czech Republic"
  )
)

region_lookup <- stack(countries_by_region)
names(region_lookup) <- c("country", "region")
region_lookup$country <- as.character(region_lookup$country)
region_lookup$region  <- as.character(region_lookup$region)

all_countries <- region_lookup$country
all_regions   <- names(countries_by_region)
years         <- 2000:2022
n_years       <- length(years)

# --- Population baselines (millions, approximate 2010 values) ---------------

pop_baseline <- c(
  Nigeria = 158, Ethiopia = 88, Kenya = 41, Tanzania = 45, `South Africa` = 51,
  Ghana = 25, Senegal = 13, Uganda = 33, Mozambique = 23, Rwanda = 10,
  India = 1235, Bangladesh = 149, Pakistan = 174, `Sri Lanka` = 20,
  Nepal = 27, Afghanistan = 29, Bhutan = 0.7,
  China = 1341, Indonesia = 242, Vietnam = 87, Philippines = 93,
  Thailand = 66, Malaysia = 28, Cambodia = 14, Myanmar = 51,
  Brazil = 196, Mexico = 118, Colombia = 46, Peru = 29, Chile = 17,
  Argentina = 41, Ecuador = 15, Guatemala = 14,
  Egypt = 82, Morocco = 32, Tunisia = 11, Jordan = 7, Iran = 74,
  Iraq = 31, Algeria = 36,
  Turkey = 73, Poland = 38, Romania = 20, Ukraine = 46,
  Kazakhstan = 16, Georgia = 4.4, Serbia = 7.3, Bulgaria = 7.4,
  Hungary = 10, `Czech Republic` = 10.5
)

# --- Helper: generate a trending series with noise --------------------------

generate_series <- function(start, end, n, noise_sd, lower = -Inf, upper = Inf) {
  trend <- seq(start, end, length.out = n)
  noise <- rnorm(n, mean = 0, sd = noise_sd)
  values <- trend + noise
  # smooth slightly so year-to-year jumps are not wild
  values <- stats::filter(values, rep(1/3, 3), sides = 2)
  values[1]  <- start + rnorm(1, 0, noise_sd * 0.5)
  values[n]  <- end   + rnorm(1, 0, noise_sd * 0.5)
  values <- as.numeric(values)
  # interpolate any NAs from the filter edges
  values <- approx(seq_along(values), values, seq_along(values))$y
  pmin(pmax(values, lower), upper)
}

# --- Regional baseline parameters for each indicator -----------------------
# Each indicator: list of (start_range, end_range, noise_sd, lower, upper)
# keyed by region. start/end are c(low, high) and a uniform draw picks each
# country's trajectory.

indicator_params <- list(
  "GDP per capita (PPP)" = list(
    "Sub-Saharan Africa"         = list(s = c(1200, 3500),  e = c(2000, 6500),  sd = 150,  lo = 400,   hi = 30000),
    "South Asia"                 = list(s = c(1500, 5000),  e = c(3500, 13000), sd = 300,  lo = 500,   hi = 30000),
    "East Asia & Pacific"        = list(s = c(2000, 10000), e = c(5000, 20000), sd = 500,  lo = 600,   hi = 40000),
    "Latin America & Caribbean"  = list(s = c(5000, 14000), e = c(8000, 22000), sd = 600,  lo = 2000,  hi = 35000),
    "Middle East & North Africa" = list(s = c(4000, 12000), e = c(6000, 18000), sd = 500,  lo = 2000,  hi = 35000),
    "Europe & Central Asia"      = list(s = c(8000, 22000), e = c(15000, 38000),sd = 800,  lo = 3000,  hi = 50000)
  ),
  "Life expectancy" = list(
    "Sub-Saharan Africa"         = list(s = c(46, 56), e = c(56, 66), sd = 0.4, lo = 40, hi = 85),
    "South Asia"                 = list(s = c(58, 68), e = c(65, 76), sd = 0.3, lo = 45, hi = 85),
    "East Asia & Pacific"        = list(s = c(62, 72), e = c(68, 78), sd = 0.3, lo = 50, hi = 85),
    "Latin America & Caribbean"  = list(s = c(66, 76), e = c(72, 80), sd = 0.25,lo = 55, hi = 85),
    "Middle East & North Africa" = list(s = c(64, 72), e = c(70, 78), sd = 0.3, lo = 50, hi = 85),
    "Europe & Central Asia"      = list(s = c(68, 76), e = c(74, 80), sd = 0.25,lo = 60, hi = 85)
  ),
  "Under-5 mortality rate" = list(
    "Sub-Saharan Africa"         = list(s = c(100, 200), e = c(40, 100), sd = 4,  lo = 2,  hi = 300),
    "South Asia"                 = list(s = c(60, 120),  e = c(25, 60),  sd = 3,  lo = 2,  hi = 200),
    "East Asia & Pacific"        = list(s = c(25, 70),   e = c(8, 30),   sd = 2,  lo = 2,  hi = 150),
    "Latin America & Caribbean"  = list(s = c(20, 50),   e = c(8, 22),   sd = 1.5,lo = 2,  hi = 100),
    "Middle East & North Africa" = list(s = c(25, 60),   e = c(10, 28),  sd = 2,  lo = 2,  hi = 120),
    "Europe & Central Asia"      = list(s = c(10, 30),   e = c(3, 12),   sd = 1,  lo = 2,  hi = 60)
  ),
  "Primary completion rate" = list(
    "Sub-Saharan Africa"         = list(s = c(40, 70),  e = c(60, 90),  sd = 2, lo = 20, hi = 100),
    "South Asia"                 = list(s = c(55, 80),  e = c(75, 98),  sd = 1.5, lo = 30, hi = 100),
    "East Asia & Pacific"        = list(s = c(80, 95),  e = c(90, 100), sd = 1, lo = 50, hi = 100),
    "Latin America & Caribbean"  = list(s = c(75, 95),  e = c(85, 100), sd = 1.2, lo = 50, hi = 100),
    "Middle East & North Africa" = list(s = c(70, 92),  e = c(85, 100), sd = 1.2, lo = 40, hi = 100),
    "Europe & Central Asia"      = list(s = c(90, 99),  e = c(95, 100), sd = 0.5, lo = 70, hi = 100)
  ),
  "Access to electricity (%)" = list(
    "Sub-Saharan Africa"         = list(s = c(10, 50),  e = c(30, 80),  sd = 2, lo = 5,  hi = 100),
    "South Asia"                 = list(s = c(40, 75),  e = c(75, 100), sd = 1.5, lo = 20, hi = 100),
    "East Asia & Pacific"        = list(s = c(60, 95),  e = c(90, 100), sd = 1, lo = 30, hi = 100),
    "Latin America & Caribbean"  = list(s = c(75, 97),  e = c(90, 100), sd = 0.8, lo = 50, hi = 100),
    "Middle East & North Africa" = list(s = c(80, 99),  e = c(95, 100), sd = 0.5, lo = 60, hi = 100),
    "Europe & Central Asia"      = list(s = c(95, 100), e = c(99, 100), sd = 0.2, lo = 80, hi = 100)
  ),
  "Poverty headcount ($2.15/day)" = list(
    "Sub-Saharan Africa"         = list(s = c(30, 70),  e = c(20, 55),  sd = 2, lo = 0, hi = 90),
    "South Asia"                 = list(s = c(25, 55),  e = c(5, 25),   sd = 2, lo = 0, hi = 80),
    "East Asia & Pacific"        = list(s = c(15, 45),  e = c(1, 10),   sd = 1.5, lo = 0, hi = 70),
    "Latin America & Caribbean"  = list(s = c(5, 20),   e = c(2, 10),   sd = 1, lo = 0, hi = 40),
    "Middle East & North Africa" = list(s = c(3, 15),   e = c(1, 8),    sd = 0.8, lo = 0, hi = 30),
    "Europe & Central Asia"      = list(s = c(1, 8),    e = c(0.2, 3),  sd = 0.4, lo = 0, hi = 20)
  ),
  "Maternal mortality ratio" = list(
    "Sub-Saharan Africa"         = list(s = c(400, 1100), e = c(200, 700), sd = 25, lo = 5,  hi = 1500),
    "South Asia"                 = list(s = c(200, 600),  e = c(60, 250),  sd = 15, lo = 5,  hi = 1000),
    "East Asia & Pacific"        = list(s = c(50, 300),   e = c(15, 120),  sd = 8,  lo = 5,  hi = 600),
    "Latin America & Caribbean"  = list(s = c(50, 200),   e = c(20, 100),  sd = 6,  lo = 5,  hi = 400),
    "Middle East & North Africa" = list(s = c(40, 150),   e = c(15, 70),   sd = 5,  lo = 5,  hi = 300),
    "Europe & Central Asia"      = list(s = c(10, 50),    e = c(3, 20),    sd = 2,  lo = 2,  hi = 100)
  ),
  "CO2 emissions per capita" = list(
    "Sub-Saharan Africa"         = list(s = c(0.1, 1.5),  e = c(0.2, 2.0),  sd = 0.08, lo = 0, hi = 20),
    "South Asia"                 = list(s = c(0.3, 1.5),  e = c(0.8, 2.5),  sd = 0.1,  lo = 0, hi = 20),
    "East Asia & Pacific"        = list(s = c(0.5, 5.0),  e = c(1.5, 8.0),  sd = 0.2,  lo = 0, hi = 25),
    "Latin America & Caribbean"  = list(s = c(1.0, 4.5),  e = c(1.2, 5.0),  sd = 0.15, lo = 0, hi = 20),
    "Middle East & North Africa" = list(s = c(1.5, 6.0),  e = c(2.0, 7.5),  sd = 0.2,  lo = 0, hi = 25),
    "Europe & Central Asia"      = list(s = c(3.0, 10.0), e = c(3.5, 9.0),  sd = 0.25, lo = 0, hi = 25)
  ),
  "Internet users (%)" = list(
    "Sub-Saharan Africa"         = list(s = c(0.2, 3),   e = c(15, 50),  sd = 1.5, lo = 0, hi = 100),
    "South Asia"                 = list(s = c(0.5, 5),   e = c(20, 55),  sd = 2,   lo = 0, hi = 100),
    "East Asia & Pacific"        = list(s = c(2, 20),    e = c(40, 85),  sd = 2,   lo = 0, hi = 100),
    "Latin America & Caribbean"  = list(s = c(3, 15),    e = c(50, 80),  sd = 2,   lo = 0, hi = 100),
    "Middle East & North Africa" = list(s = c(2, 12),    e = c(45, 80),  sd = 2,   lo = 0, hi = 100),
    "Europe & Central Asia"      = list(s = c(8, 30),    e = c(65, 92),  sd = 1.5, lo = 0, hi = 100)
  ),
  "Govt expenditure on education (% GDP)" = list(
    "Sub-Saharan Africa"         = list(s = c(2.5, 5.5), e = c(2.8, 5.8), sd = 0.25, lo = 1, hi = 10),
    "South Asia"                 = list(s = c(2.0, 4.5), e = c(2.5, 5.0), sd = 0.2,  lo = 1, hi = 10),
    "East Asia & Pacific"        = list(s = c(2.5, 5.0), e = c(3.0, 5.5), sd = 0.2,  lo = 1, hi = 10),
    "Latin America & Caribbean"  = list(s = c(3.0, 5.5), e = c(3.5, 6.0), sd = 0.2,  lo = 1, hi = 10),
    "Middle East & North Africa" = list(s = c(3.0, 6.0), e = c(3.0, 6.0), sd = 0.25, lo = 1, hi = 10),
    "Europe & Central Asia"      = list(s = c(3.5, 6.0), e = c(3.5, 6.5), sd = 0.2,  lo = 1, hi = 10)
  ),
  "Gini index" = list(
    "Sub-Saharan Africa"         = list(s = c(38, 62), e = c(35, 58), sd = 0.8, lo = 20, hi = 70),
    "South Asia"                 = list(s = c(30, 42), e = c(28, 40), sd = 0.5, lo = 20, hi = 65),
    "East Asia & Pacific"        = list(s = c(30, 45), e = c(30, 44), sd = 0.6, lo = 20, hi = 65),
    "Latin America & Caribbean"  = list(s = c(42, 58), e = c(38, 52), sd = 0.7, lo = 25, hi = 65),
    "Middle East & North Africa" = list(s = c(32, 42), e = c(30, 40), sd = 0.5, lo = 20, hi = 60),
    "Europe & Central Asia"      = list(s = c(26, 38), e = c(25, 36), sd = 0.4, lo = 20, hi = 55)
  ),
  "Agricultural land (%)" = list(
    "Sub-Saharan Africa"         = list(s = c(30, 70), e = c(32, 68), sd = 0.5, lo = 5,  hi = 85),
    "South Asia"                 = list(s = c(40, 65), e = c(38, 63), sd = 0.4, lo = 10, hi = 80),
    "East Asia & Pacific"        = list(s = c(20, 55), e = c(18, 53), sd = 0.4, lo = 5,  hi = 80),
    "Latin America & Caribbean"  = list(s = c(25, 55), e = c(26, 56), sd = 0.4, lo = 5,  hi = 80),
    "Middle East & North Africa" = list(s = c(10, 45), e = c(10, 44), sd = 0.4, lo = 2,  hi = 75),
    "Europe & Central Asia"      = list(s = c(30, 60), e = c(28, 58), sd = 0.4, lo = 10, hi = 80)
  ),
  "Rural population (%)" = list(
    "Sub-Saharan Africa"         = list(s = c(55, 85), e = c(40, 72), sd = 0.6, lo = 5,  hi = 95),
    "South Asia"                 = list(s = c(60, 82), e = c(50, 72), sd = 0.5, lo = 10, hi = 95),
    "East Asia & Pacific"        = list(s = c(30, 75), e = c(20, 55), sd = 0.6, lo = 5,  hi = 90),
    "Latin America & Caribbean"  = list(s = c(15, 55), e = c(10, 42), sd = 0.5, lo = 3,  hi = 80),
    "Middle East & North Africa" = list(s = c(25, 55), e = c(18, 42), sd = 0.5, lo = 3,  hi = 80),
    "Europe & Central Asia"      = list(s = c(20, 45), e = c(15, 38), sd = 0.4, lo = 3,  hi = 70)
  ),
  "Fertility rate" = list(
    "Sub-Saharan Africa"         = list(s = c(4.5, 7.0), e = c(3.0, 5.5), sd = 0.1, lo = 1, hi = 8),
    "South Asia"                 = list(s = c(2.5, 5.5), e = c(1.8, 3.5), sd = 0.08,lo = 1, hi = 8),
    "East Asia & Pacific"        = list(s = c(1.5, 3.5), e = c(1.3, 2.8), sd = 0.06,lo = 1, hi = 7),
    "Latin America & Caribbean"  = list(s = c(2.0, 4.0), e = c(1.5, 2.8), sd = 0.06,lo = 1, hi = 7),
    "Middle East & North Africa" = list(s = c(2.2, 5.0), e = c(1.8, 3.5), sd = 0.07,lo = 1, hi = 7),
    "Europe & Central Asia"      = list(s = c(1.2, 2.2), e = c(1.2, 1.9), sd = 0.04,lo = 1, hi = 5)
  ),
  "Adult literacy rate" = list(
    "Sub-Saharan Africa"         = list(s = c(35, 75), e = c(50, 85), sd = 1, lo = 15, hi = 100),
    "South Asia"                 = list(s = c(40, 85), e = c(60, 95), sd = 0.8, lo = 20, hi = 100),
    "East Asia & Pacific"        = list(s = c(75, 95), e = c(85, 99), sd = 0.5, lo = 40, hi = 100),
    "Latin America & Caribbean"  = list(s = c(80, 96), e = c(88, 99), sd = 0.4, lo = 50, hi = 100),
    "Middle East & North Africa" = list(s = c(55, 90), e = c(72, 96), sd = 0.6, lo = 30, hi = 100),
    "Europe & Central Asia"      = list(s = c(92, 99), e = c(96, 100),sd = 0.2, lo = 70, hi = 100)
  )
)

indicator_names <- names(indicator_params)

# --- Build the data frame ---------------------------------------------------

build_wdi_data <- function() {
  rows <- list()
  idx <- 1
  for (cname in all_countries) {
    reg <- region_lookup$region[region_lookup$country == cname]
    base_pop <- pop_baseline[cname]
    if (is.na(base_pop)) base_pop <- 10  # fallback
    # population series: grows 1-2.5 % per year depending on region
    pop_growth <- if (reg == "Sub-Saharan Africa") runif(1, 0.022, 0.028)
      else if (reg == "South Asia") runif(1, 0.012, 0.018)
      else if (reg == "Europe & Central Asia") runif(1, -0.002, 0.005)
      else runif(1, 0.005, 0.015)
    pop_series <- base_pop * (1 + pop_growth)^(seq(-10, 12))  # 2000 is index 1 (offset -10 from 2010)

    for (yi in seq_along(years)) {
      row <- list(country = cname, region = reg, year = years[yi],
                  population = round(pop_series[yi] * 1e6))
      for (ind in indicator_names) {
        p <- indicator_params[[ind]][[reg]]
        # deterministic seed per country-indicator so results are reproducible
        set.seed(sum(utf8ToInt(cname)) * which(indicator_names == ind) + yi * 0)
        s_val <- runif(1, p$s[1], p$s[2])
        e_val <- runif(1, p$e[1], p$e[2])
        set.seed(sum(utf8ToInt(cname)) * which(indicator_names == ind))
        series <- generate_series(s_val, e_val, n_years, p$sd, p$lo, p$hi)
        row[[ind]] <- round(series[yi], 2)
      }
      rows[[idx]] <- row
      idx <- idx + 1
    }
  }
  df <- bind_rows(rows)
  df
}

wdi_data <- build_wdi_data()

# --- Custom ggplot theme ----------------------------------------------------

theme_wdi <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.title       = element_text(face = "bold", size = base_size + 3,
                                      margin = margin(b = 10), color = "#1a1a2e"),
      plot.subtitle    = element_text(size = base_size, color = "#555555",
                                      margin = margin(b = 12)),
      plot.caption     = element_text(size = base_size - 3, color = "#888888",
                                      hjust = 1),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e0e0e0", linewidth = 0.3),
      axis.title       = element_text(face = "bold", color = "#333333"),
      axis.text        = element_text(color = "#444444"),
      legend.position  = "bottom",
      legend.title     = element_text(face = "bold", size = base_size - 1),
      legend.text      = element_text(size = base_size - 2),
      strip.text       = element_text(face = "bold", size = base_size - 1,
                                      color = "#1a1a2e"),
      plot.background  = element_rect(fill = "#fafbfc", color = NA),
      panel.background = element_rect(fill = "#ffffff", color = NA)
    )
}

# Region color palette
region_colors <- c(
  "Sub-Saharan Africa"         = "#e63946",
  "South Asia"                 = "#f4a261",
  "East Asia & Pacific"        = "#2a9d8f",
  "Latin America & Caribbean"  = "#264653",
  "Middle East & North Africa" = "#e9c46a",
  "Europe & Central Asia"      = "#457b9d"
)

# =============================================================================
# 2. USER INTERFACE
# =============================================================================

ui <- fluidPage(
  # Custom CSS for polish
  tags$head(tags$style(HTML("
    body {
      background-color: #f0f2f5;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    .well {
      background-color: #ffffff;
      border: 1px solid #dee2e6;
      border-radius: 8px;
    }
    h2.app-title {
      color: #1a1a2e;
      font-weight: 700;
      margin-bottom: 4px;
    }
    .app-subtitle {
      color: #6c757d;
      font-size: 14px;
      margin-bottom: 18px;
    }
    .nav-tabs > li > a {
      color: #495057;
      font-weight: 500;
    }
    .nav-tabs > li.active > a {
      color: #1a1a2e;
      font-weight: 700;
      border-bottom: 3px solid #457b9d;
    }
    .sidebar-section-title {
      font-weight: 600;
      color: #1a1a2e;
      margin-top: 14px;
      margin-bottom: 6px;
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .about-section h4 {
      color: #1a1a2e;
      margin-top: 18px;
    }
    .about-section p, .about-section li {
      color: #444;
      line-height: 1.65;
    }
  "))),

  titlePanel(
    title = div(
      h2("World Development Indicators Dashboard", class = "app-title"),
      div("Impact Mojo  |  Exploring global development data with synthetic WDI-style indicators",
          class = "app-subtitle")
    ),
    windowTitle = "WDI Dashboard - Impact Mojo"
  ),

  sidebarLayout(
    # --- Sidebar ---
    sidebarPanel(
      width = 3,
      div(class = "sidebar-section-title", "Indicator"),
      selectInput("indicator", NULL,
                  choices = indicator_names,
                  selected = "GDP per capita (PPP)"),

      div(class = "sidebar-section-title", "Countries"),
      selectizeInput("countries", NULL,
                     choices  = all_countries,
                     selected = c("Nigeria", "India", "Brazil", "China",
                                  "South Africa", "Poland"),
                     multiple = TRUE,
                     options  = list(maxItems = 15,
                                    placeholder = "Type to search...")),

      div(class = "sidebar-section-title", "Year Range"),
      sliderInput("year_range", NULL,
                  min = 2000, max = 2022,
                  value = c(2000, 2022),
                  sep = "", step = 1),

      div(class = "sidebar-section-title", "Region Filter"),
      selectInput("region_filter", NULL,
                  choices  = c("All", all_regions),
                  selected = "All"),

      div(class = "sidebar-section-title", "Comparison Mode"),
      radioButtons("comparison_mode", NULL,
                   choices  = c("Time series", "Cross-country",
                                "Regional averages"),
                   selected = "Time series", inline = TRUE),

      checkboxInput("show_trend", "Show trend lines", value = FALSE),

      hr(),
      # Second indicator for scatter tab
      div(class = "sidebar-section-title", "Second Indicator (Scatter tab)"),
      selectInput("indicator2", NULL,
                  choices  = indicator_names,
                  selected = "Life expectancy"),
      div(class = "sidebar-section-title", "Scatter Year"),
      sliderInput("scatter_year", NULL,
                  min = 2000, max = 2022,
                  value = 2015, sep = "", step = 1),

      hr(),
      div(style = "text-align:center; color:#999; font-size:12px; margin-top:8px;",
          "Data is synthetic for demonstration purposes.",
          br(),
          paste0(length(all_countries), " countries | ",
                 length(indicator_names), " indicators | ",
                 min(years), "-", max(years)))
    ),

    # --- Main panel ---
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs", type = "tabs",

        # Tab 1: Time Series
        tabPanel("Time Series",
          br(),
          plotOutput("ts_plot", height = "520px")
        ),

        # Tab 2: Cross-Country
        tabPanel("Cross-Country",
          br(),
          fluidRow(
            column(4, sliderInput("cross_year", "Select Year:",
                                  min = 2000, max = 2022,
                                  value = 2020, sep = "", step = 1)),
            column(4, radioButtons("sort_order", "Sort:", inline = TRUE,
                                   choices = c("Descending", "Ascending",
                                               "Alphabetical"),
                                   selected = "Descending"))
          ),
          plotOutput("cross_plot", height = "520px")
        ),

        # Tab 3: Regional
        tabPanel("Regional",
          br(),
          radioButtons("regional_type", "Display:", inline = TRUE,
                       choices = c("Trend lines", "Box plots"),
                       selected = "Trend lines"),
          plotOutput("regional_plot", height = "540px")
        ),

        # Tab 4: Scatter
        tabPanel("Scatter",
          br(),
          plotOutput("scatter_plot", height = "540px")
        ),

        # Tab 5: Data Table
        tabPanel("Data Table",
          br(),
          downloadButton("download_data", "Download CSV", class = "btn-sm"),
          br(), br(),
          DTOutput("data_table")
        ),

        # Tab 6: About
        tabPanel("About",
          br(),
          div(class = "about-section",
            h4("About the World Development Indicators"),
            p("The World Development Indicators (WDI) is the World Bank's premier",
              "compilation of cross-country comparable data on development.",
              "The database contains over 1,400 time-series indicators for",
              "217 economies, with data going back more than 50 years."),

            h4("Sustainable Development Goals (SDGs)"),
            p("Many indicators in this dashboard align with the United Nations",
              "Sustainable Development Goals adopted in 2015. These 17 global",
              "goals address interconnected challenges including poverty,",
              "inequality, climate change, environmental degradation, and",
              "access to justice and institutions."),

            h4("Indicators in This Dashboard"),
            tags$ul(
              tags$li(tags$strong("GDP per capita (PPP)"),
                " -- Gross domestic product per person adjusted for purchasing",
                "power parity, measured in international dollars."),
              tags$li(tags$strong("Life expectancy"),
                " -- Average number of years a newborn is expected to live."),
              tags$li(tags$strong("Under-5 mortality rate"),
                " -- Deaths of children under five per 1,000 live births."),
              tags$li(tags$strong("Primary completion rate"),
                " -- Percentage of students completing the last year of primary education."),
              tags$li(tags$strong("Access to electricity"),
                " -- Percentage of the population with access to electricity."),
              tags$li(tags$strong("Poverty headcount ($2.15/day)"),
                " -- Share of population living below $2.15 per day (2017 PPP)."),
              tags$li(tags$strong("Maternal mortality ratio"),
                " -- Maternal deaths per 100,000 live births."),
              tags$li(tags$strong("CO2 emissions per capita"),
                " -- Carbon dioxide emissions in metric tons per person."),
              tags$li(tags$strong("Internet users (%)"),
                " -- Percentage of individuals using the Internet."),
              tags$li(tags$strong("Govt expenditure on education"),
                " -- Government spending on education as a share of GDP."),
              tags$li(tags$strong("Gini index"),
                " -- Measure of income inequality (0 = perfect equality, 100 = maximum inequality)."),
              tags$li(tags$strong("Agricultural land (%)"),
                " -- Share of land area used for agriculture."),
              tags$li(tags$strong("Rural population (%)"),
                " -- Share of total population living in rural areas."),
              tags$li(tags$strong("Fertility rate"),
                " -- Average number of children per woman."),
              tags$li(tags$strong("Adult literacy rate"),
                " -- Percentage of people aged 15+ who can read and write.")
            ),

            h4("How to Interpret Development Indicators"),
            p("When comparing development indicators across countries, it is",
              "important to consider differences in data collection methods,",
              "definitions, and reporting standards. Trends over time are often",
              "more informative than single-year snapshots. Regional averages",
              "can mask wide variation among countries within a region."),
            p("Cross-country scatter plots can reveal correlations between",
              "indicators (e.g., higher GDP per capita often associates with",
              "longer life expectancy), but correlation does not imply causation."),

            h4("Synthetic Data Disclaimer"),
            p(tags$em("This dashboard uses synthetic data generated to resemble",
              "real-world development indicator patterns. The data is intended",
              "solely for demonstration purposes and does not reflect actual",
              "country statistics. For real data, visit the"),
              tags$a("World Bank Open Data portal.",
                     href = "https://data.worldbank.org/",
                     target = "_blank")),

            hr(),
            p(style = "color:#999; font-size:12px;",
              "Impact Mojo | Built with R Shiny, ggplot2, dplyr, tidyr, DT")
          )
        )
      )
    )
  )
)

# =============================================================================
# 3. SERVER LOGIC
# =============================================================================

server <- function(input, output, session) {

  # --- Reactive: filtered data based on sidebar controls --------------------

  filtered_data <- reactive({
    df <- wdi_data %>%
      filter(year >= input$year_range[1],
             year <= input$year_range[2])

    if (input$region_filter != "All") {
      df <- df %>% filter(region == input$region_filter)
    }
    df
  })

  # Data for selected countries
  selected_data <- reactive({
    req(input$countries)
    filtered_data() %>%
      filter(country %in% input$countries)
  })

  # --- Update country selector when region filter changes -------------------

  observeEvent(input$region_filter, {
    if (input$region_filter == "All") {
      new_choices <- all_countries
    } else {
      new_choices <- countries_by_region[[input$region_filter]]
    }
    # keep currently selected countries that are still valid
    still_valid <- intersect(input$countries, new_choices)
    if (length(still_valid) == 0) {
      still_valid <- head(new_choices, 3)
    }
    updateSelectizeInput(session, "countries",
                         choices  = new_choices,
                         selected = still_valid)
  })

  # -----------------------------------------------------------------------
  # TAB 1: TIME SERIES
  # -----------------------------------------------------------------------

  output$ts_plot <- renderPlot({
    df <- selected_data()
    req(nrow(df) > 0)
    ind <- input$indicator

    p <- ggplot(df, aes(x = year, y = .data[[ind]],
                        color = country, group = country)) +
      geom_line(linewidth = 1, alpha = 0.85) +
      geom_point(size = 1.8, alpha = 0.7) +
      scale_color_brewer(palette = "Set2", name = "Country") +
      labs(title = ind,
           subtitle = paste0(input$year_range[1], " - ", input$year_range[2],
                             " | ", length(input$countries), " countries selected"),
           x = "Year", y = ind,
           caption = "Source: Synthetic WDI-style data (Impact Mojo)") +
      theme_wdi()

    if (input$show_trend) {
      p <- p + geom_smooth(method = "loess", se = FALSE,
                           linewidth = 0.7, linetype = "dashed",
                           alpha = 0.5, formula = y ~ x)
    }
    p
  })

  # -----------------------------------------------------------------------
  # TAB 2: CROSS-COUNTRY
  # -----------------------------------------------------------------------

  output$cross_plot <- renderPlot({
    df <- selected_data() %>%
      filter(year == input$cross_year)
    req(nrow(df) > 0)
    ind <- input$indicator

    # sort order
    if (input$sort_order == "Descending") {
      df <- df %>% mutate(country = reorder(country, .data[[ind]], FUN = identity))
    } else if (input$sort_order == "Ascending") {
      df <- df %>% mutate(country = reorder(country, -.data[[ind]], FUN = identity))
    } else {
      df <- df %>% mutate(country = factor(country, levels = sort(unique(country))))
    }

    p <- ggplot(df, aes(x = country, y = .data[[ind]], fill = region)) +
      geom_col(alpha = 0.88, width = 0.7) +
      scale_fill_manual(values = region_colors, name = "Region") +
      coord_flip() +
      labs(title = paste0(ind, " (", input$cross_year, ")"),
           subtitle = paste0("Cross-country comparison | ",
                             nrow(df), " countries"),
           x = NULL, y = ind,
           caption = "Source: Synthetic WDI-style data (Impact Mojo)") +
      theme_wdi() +
      theme(legend.position = "right")

    p
  })

  # -----------------------------------------------------------------------
  # TAB 3: REGIONAL
  # -----------------------------------------------------------------------

  output$regional_plot <- renderPlot({
    df <- filtered_data()
    req(nrow(df) > 0)
    ind <- input$indicator

    if (input$regional_type == "Trend lines") {
      # Regional averages over time
      reg_avg <- df %>%
        group_by(region, year) %>%
        summarise(mean_val = mean(.data[[ind]], na.rm = TRUE),
                  .groups = "drop")

      p <- ggplot(reg_avg, aes(x = year, y = mean_val, color = region)) +
        geom_line(linewidth = 1.1) +
        geom_point(size = 1.8) +
        scale_color_manual(values = region_colors, name = "Region") +
        facet_wrap(~ region, scales = "free_y", ncol = 3) +
        labs(title = paste0("Regional Averages: ", ind),
             subtitle = paste0(input$year_range[1], " - ", input$year_range[2]),
             x = "Year", y = ind,
             caption = "Source: Synthetic WDI-style data (Impact Mojo)") +
        theme_wdi() +
        theme(legend.position = "none",
              axis.text.x = element_text(angle = 45, hjust = 1))

      if (input$show_trend) {
        p <- p + geom_smooth(method = "lm", se = TRUE,
                             linewidth = 0.6, linetype = "dashed",
                             alpha = 0.15, formula = y ~ x)
      }
      p

    } else {
      # Box plots showing distribution by region for selected year range
      p <- ggplot(df, aes(x = region, y = .data[[ind]], fill = region)) +
        geom_boxplot(alpha = 0.75, outlier.alpha = 0.4, width = 0.6) +
        scale_fill_manual(values = region_colors, name = "Region") +
        labs(title = paste0("Regional Distribution: ", ind),
             subtitle = paste0(input$year_range[1], " - ", input$year_range[2],
                               " (all years pooled)"),
             x = NULL, y = ind,
             caption = "Source: Synthetic WDI-style data (Impact Mojo)") +
        theme_wdi() +
        theme(legend.position = "none",
              axis.text.x = element_text(angle = 25, hjust = 1))

      p
    }
  })

  # -----------------------------------------------------------------------
  # TAB 4: SCATTER
  # -----------------------------------------------------------------------

  output$scatter_plot <- renderPlot({
    df <- filtered_data() %>%
      filter(year == input$scatter_year)
    req(nrow(df) > 0)
    ind1 <- input$indicator
    ind2 <- input$indicator2

    # scale population for bubble size
    pop_range <- range(df$population, na.rm = TRUE)
    size_label <- "Population"

    p <- ggplot(df, aes(x = .data[[ind1]], y = .data[[ind2]],
                        size = population, color = region)) +
      geom_point(alpha = 0.7) +
      scale_size_continuous(
        name   = size_label,
        range  = c(2, 18),
        labels = function(x) {
          ifelse(x >= 1e9, paste0(round(x / 1e9, 1), "B"),
          ifelse(x >= 1e6, paste0(round(x / 1e6, 0), "M"),
                 format(x, big.mark = ",")))
        }
      ) +
      scale_color_manual(values = region_colors, name = "Region") +
      labs(title = paste0(ind1, "  vs.  ", ind2),
           subtitle = paste0("Year: ", input$scatter_year,
                             " | Bubble size = Population | Color = Region"),
           x = ind1, y = ind2,
           caption = "Source: Synthetic WDI-style data (Impact Mojo)") +
      theme_wdi() +
      theme(legend.box = "vertical")

    if (input$show_trend) {
      p <- p + geom_smooth(aes(group = 1), method = "lm", se = TRUE,
                           linewidth = 0.7, linetype = "dashed",
                           color = "#333333", alpha = 0.1,
                           formula = y ~ x)
    }

    # Label a subset of points for readability (top 8 by population)
    top_countries <- df %>%
      arrange(desc(population)) %>%
      head(8)

    p <- p +
      geom_text(data = top_countries,
                aes(label = country),
                size = 3.2, fontface = "bold",
                vjust = -1.2, show.legend = FALSE)

    p
  })

  # -----------------------------------------------------------------------
  # TAB 5: DATA TABLE
  # -----------------------------------------------------------------------

  output$data_table <- renderDT({
    df <- selected_data()
    req(nrow(df) > 0)

    # Format population with commas
    df <- df %>%
      mutate(population = format(population, big.mark = ",", scientific = FALSE))

    datatable(
      df,
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 20,
        scrollX    = TRUE,
        autoWidth  = TRUE,
        dom        = "lfrtip",
        order      = list(list(2, "desc"))  # sort by year desc
      ),
      class = "cell-border stripe hover compact"
    ) %>%
      formatStyle(columns = names(df),
                  fontSize = "13px")
  })

  output$download_data <- downloadHandler(
    filename = function() {
      paste0("wdi_dashboard_data_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(selected_data(), file, row.names = FALSE)
    }
  )
}

# =============================================================================
# 4. RUN THE APP
# =============================================================================

shinyApp(ui = ui, server = server)
