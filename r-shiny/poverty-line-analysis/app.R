###############################################################################
# Poverty Line Analysis -- Impact Mojo
# A Shiny application for FGT (Foster-Greer-Thorbecke) poverty analysis
# Libraries: shiny, ggplot2, dplyr, tidyr
###############################################################################

library(shiny)
library(ggplot2)
library(dplyr)
library(tidyr)

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

generate_income_data <- function(n, distribution, mean_income, sd_log) {
  set.seed(NULL)
  if (distribution == "Log-normal") {
    mu <- log(mean_income) - (sd_log^2) / 2
    income <- rlnorm(n, meanlog = mu, sdlog = sd_log)
  } else if (distribution == "Gamma") {
    shape <- (mean_income / (sd_log * mean_income))^2
    shape <- max(shape, 0.5)
    rate <- shape / mean_income
    income <- rgamma(n, shape = shape, rate = rate)
  } else {
    # Mixture: 60% low-income log-normal + 40% higher-income log-normal
    n_low <- round(n * 0.6)
    n_high <- n - n_low
    mu_low <- log(mean_income * 0.6) - (sd_log^2) / 2
    mu_high <- log(mean_income * 1.8) - ((sd_log * 0.7)^2) / 2
    income_low <- rlnorm(n_low, meanlog = mu_low, sdlog = sd_log)
    income_high <- rlnorm(n_high, meanlog = mu_high, sdlog = sd_log * 0.7)
    income <- sample(c(income_low, income_high))
  }
  income[income < 0.01] <- 0.01
  return(income)
}

calc_fgt <- function(income, poverty_line, alpha) {
  n <- length(income)
  poor <- income[income < poverty_line]
  if (length(poor) == 0) return(0)
  gaps <- (poverty_line - poor) / poverty_line
  return(mean(c(gaps^alpha, rep(0, n - length(poor)))))
}

calc_watts <- function(income, poverty_line) {
  n <- length(income)
  poor <- income[income < poverty_line]
  if (length(poor) == 0) return(0)
  poor[poor < 0.01] <- 0.01
  return(sum(log(poverty_line / poor)) / n)
}

assign_subgroups <- function(n) {
  data.frame(
    location = sample(c("Urban", "Rural"), n, replace = TRUE, prob = c(0.45, 0.55)),
    hh_head = sample(c("Male-headed", "Female-headed"), n, replace = TRUE, prob = c(0.65, 0.35)),
    region = sample(paste("Region", 1:5), n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

# Consistent professional theme for all plots
theme_impact <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.title = element_text(face = "bold", size = rel(1.15), hjust = 0, margin = margin(b = 10)),
      plot.subtitle = element_text(color = "#555555", hjust = 0, margin = margin(b = 12)),
      plot.caption = element_text(color = "#888888", size = rel(0.75), hjust = 1),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e0e0e0", linewidth = 0.3),
      axis.title = element_text(face = "bold", size = rel(0.9)),
      axis.text = element_text(color = "#333333"),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = rel(0.85)),
      legend.text = element_text(size = rel(0.8)),
      strip.text = element_text(face = "bold", size = rel(0.9)),
      plot.margin = margin(15, 15, 15, 15)
    )
}

poverty_line_colors <- c(
  "$1.90" = "#e63946",
  "$2.15" = "#d62828",
  "$3.65" = "#f77f00",
  "$6.85" = "#fcbf49"
)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background-color: #f7f8fa;
      }
      .title-bar {
        background: linear-gradient(135deg, #1a3a5c 0%, #2b5e8c 100%);
        color: #ffffff;
        padding: 18px 25px;
        margin: -15px -15px 20px -15px;
        border-bottom: 3px solid #f4a261;
      }
      .title-bar h2 {
        margin: 0;
        font-weight: 700;
        letter-spacing: 0.5px;
      }
      .title-bar .subtitle {
        font-size: 13px;
        color: #c8ddf0;
        margin-top: 3px;
      }
      .metric-card {
        background: #ffffff;
        border-radius: 8px;
        padding: 18px;
        margin-bottom: 12px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
        border-left: 4px solid #2b5e8c;
        text-align: center;
      }
      .metric-card.highlight {
        border-left-color: #d62828;
      }
      .metric-card .metric-value {
        font-size: 32px;
        font-weight: 700;
        color: #1a3a5c;
      }
      .metric-card .metric-label {
        font-size: 13px;
        color: #666666;
        margin-top: 4px;
      }
      .metric-card .metric-sub {
        font-size: 12px;
        color: #999999;
        margin-top: 2px;
      }
      .sidebar-panel {
        background: #ffffff;
        border-radius: 8px;
        padding: 15px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
      }
      .well { background: #ffffff; border: 1px solid #e0e0e0; }
      .nav-tabs > li > a { color: #1a3a5c; font-weight: 600; }
      .nav-tabs > li.active > a { color: #d62828; border-bottom: 2px solid #d62828; }
      hr.section-divider {
        border-top: 1px solid #dde3ea;
        margin: 15px 0;
      }
      .preset-btn { margin: 2px; }
      .about-section h4 { color: #1a3a5c; margin-top: 20px; }
      .about-section .formula {
        background: #f0f4f8;
        border-left: 3px solid #2b5e8c;
        padding: 10px 15px;
        font-family: 'Courier New', monospace;
        margin: 10px 0;
        border-radius: 0 4px 4px 0;
        overflow-x: auto;
      }
      .about-section .ref {
        color: #555555;
        font-size: 13px;
        padding-left: 20px;
        text-indent: -20px;
        margin-bottom: 6px;
      }
    "))
  ),

  div(class = "title-bar",
    h2("Poverty Line Analysis"),
    div(class = "subtitle", "Impact Mojo | FGT Indices & Development Economics Toolkit")
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Data Input"),
      radioButtons("data_source", NULL,
        choices = c("Generate synthetic" = "generate", "Paste data" = "paste"),
        selected = "generate", inline = TRUE
      ),

      conditionalPanel(
        condition = "input.data_source == 'generate'",
        selectInput("distribution", "Distribution",
          choices = c("Log-normal", "Gamma", "Mixture"),
          selected = "Log-normal"
        ),
        sliderInput("sample_size", "Sample size",
          min = 200, max = 5000, value = 1000, step = 100
        ),
        numericInput("mean_income", "Mean daily income (PPP $)",
          value = 5.0, min = 0.5, max = 100, step = 0.5
        ),
        numericInput("sd_log", "SD of log-income",
          value = 1.0, min = 0.1, max = 3.0, step = 0.1
        ),
        actionButton("btn_regenerate", "Generate New Sample",
          class = "btn-primary btn-sm", style = "margin-bottom: 10px; width: 100%;")
      ),

      conditionalPanel(
        condition = "input.data_source == 'paste'",
        textAreaInput("paste_data", "Paste income values (one per line or comma-separated)",
          rows = 6, placeholder = "1.25\n3.40\n2.80\n..."),
        actionButton("btn_parse", "Parse Data",
          class = "btn-primary btn-sm", style = "margin-bottom: 10px; width: 100%;")
      ),

      hr(class = "section-divider"),
      h4("Poverty Line"),
      numericInput("poverty_line", "Poverty line ($ per day, PPP)",
        value = 2.15, min = 0.1, max = 50, step = 0.05
      ),
      div(style = "margin-bottom: 10px;",
        tags$label("World Bank preset lines:", style = "font-size: 12px; color: #666;"),
        br(),
        actionButton("preset_190", "$1.90", class = "btn btn-outline-secondary btn-sm preset-btn"),
        actionButton("preset_215", "$2.15", class = "btn btn-outline-secondary btn-sm preset-btn"),
        actionButton("preset_365", "$3.65", class = "btn btn-outline-secondary btn-sm preset-btn"),
        actionButton("preset_685", "$6.85", class = "btn btn-outline-secondary btn-sm preset-btn")
      ),
      checkboxInput("show_multi_lines", "Show multiple poverty lines simultaneously", value = FALSE),

      hr(class = "section-divider"),
      h4("FGT Parameters"),
      radioButtons("fgt_alpha", "Alpha parameter",
        choices = c("0 (Headcount)" = "0", "1 (Gap)" = "1", "2 (Severity)" = "2"),
        selected = "0", inline = FALSE
      ),

      hr(class = "section-divider"),
      h4("PPP Adjustment"),
      numericInput("ppp_factor", "Currency / PPP adjustment factor",
        value = 1.0, min = 0.01, max = 1000, step = 0.1
      ),
      helpText("Multiply raw income by this factor to convert to PPP $.")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(id = "main_tabs", type = "tabs",

        # ----- Tab 1: FGT Indices -----
        tabPanel("FGT Indices",
          br(),
          fluidRow(
            column(3, uiOutput("card_fgt0")),
            column(3, uiOutput("card_fgt1")),
            column(3, uiOutput("card_fgt2")),
            column(3, uiOutput("card_watts"))
          ),
          fluidRow(
            column(6, uiOutput("card_pop")),
            column(6, uiOutput("card_summary"))
          ),
          conditionalPanel(
            condition = "input.show_multi_lines == true",
            hr(),
            h4("Comparison Across World Bank Poverty Lines"),
            tableOutput("multi_line_table")
          )
        ),

        # ----- Tab 2: Distribution -----
        tabPanel("Distribution",
          br(),
          fluidRow(
            column(7, plotOutput("density_plot", height = "450px")),
            column(5, plotOutput("cdf_plot", height = "450px"))
          ),
          fluidRow(
            column(12, plotOutput("histogram_plot", height = "350px"))
          )
        ),

        # ----- Tab 3: Poverty Profile -----
        tabPanel("Poverty Profile",
          br(),
          fluidRow(
            column(6, plotOutput("profile_location_plot", height = "380px")),
            column(6, plotOutput("profile_gender_plot", height = "380px"))
          ),
          fluidRow(
            column(12, plotOutput("profile_region_plot", height = "380px"))
          ),
          hr(),
          h4("FGT Indices by Subgroup"),
          tableOutput("subgroup_table")
        ),

        # ----- Tab 4: Growth & Redistribution -----
        tabPanel("Growth & Redistribution",
          br(),
          fluidRow(
            column(4,
              wellPanel(
                h4("Simulation Parameters"),
                sliderInput("growth_rate", "Uniform growth rate (%)",
                  min = -10, max = 30, value = 5, step = 1, post = "%"),
                sliderInput("redist_share", "Redistribution to bottom quintile (%)",
                  min = 0, max = 50, value = 10, step = 1, post = "%"),
                helpText("Growth is applied uniformly. Redistribution transfers a share of
                          total growth to the bottom 20%."),
                actionButton("btn_simulate", "Run Simulation",
                  class = "btn-primary", style = "width: 100%;")
              )
            ),
            column(8,
              plotOutput("growth_plot", height = "400px"),
              br(),
              fluidRow(
                column(4, uiOutput("sim_card_baseline")),
                column(4, uiOutput("sim_card_growth")),
                column(4, uiOutput("sim_card_redist"))
              ),
              tableOutput("growth_table")
            )
          )
        ),

        # ----- Tab 5: About -----
        tabPanel("About",
          br(),
          div(class = "about-section",
            h3("Poverty Line Analysis Tool"),
            p("This tool provides interactive analysis of income distributions using the
               Foster-Greer-Thorbecke (FGT) class of poverty measures, widely used in
               development economics and policy evaluation."),

            h4("FGT Indices"),
            p("The FGT family of poverty measures is defined as:"),
            div(class = "formula",
              "FGT(alpha) = (1/N) * SUM_i [ ((z - y_i) / z) ^ alpha ] for all y_i < z"
            ),
            p("where N is the total population, z is the poverty line, y_i is the income
               of individual i, and the sum is taken over all individuals below the poverty line."),
            tags$ul(
              tags$li(tags$b("FGT(0) -- Headcount Ratio (H):"),
                " The proportion of the population living below the poverty line. Simple and
                  intuitive but insensitive to the depth of poverty."),
              tags$li(tags$b("FGT(1) -- Poverty Gap Index (PG):"),
                " The average shortfall from the poverty line (counting the non-poor as having
                  zero shortfall), expressed as a proportion of the poverty line. Captures the
                  depth of poverty."),
              tags$li(tags$b("FGT(2) -- Squared Poverty Gap (SPG):"),
                " Weights individual shortfalls by themselves, giving greater weight to the
                  poorest. Captures inequality among the poor (severity of poverty).")
            ),

            h4("Watts Index"),
            p("The Watts index is an alternative poverty measure defined as:"),
            div(class = "formula",
              "W = (1/N) * SUM_i [ ln(z / y_i) ] for all y_i < z"
            ),
            p("It satisfies the transfer sensitivity axiom and is continuous, making it useful
               for measuring marginal changes in poverty."),

            h4("World Bank International Poverty Lines"),
            tags$table(
              class = "table table-bordered", style = "max-width: 600px;",
              tags$thead(tags$tr(
                tags$th("Line"), tags$th("Value (2017 PPP $)"), tags$th("Description")
              )),
              tags$tbody(
                tags$tr(tags$td("Extreme poverty"), tags$td("$2.15/day"), tags$td("Updated international poverty line (2022 revision)")),
                tags$tr(tags$td("Previous extreme"), tags$td("$1.90/day"), tags$td("Prior international poverty line (2015 PPP)")),
                tags$tr(tags$td("Lower-middle"), tags$td("$3.65/day"), tags$td("Lower-middle income country poverty line")),
                tags$tr(tags$td("Upper-middle"), tags$td("$6.85/day"), tags$td("Upper-middle income country poverty line"))
              )
            ),

            h4("SDG 1: No Poverty"),
            p("Sustainable Development Goal 1 calls for ending poverty in all its forms everywhere
               by 2030. Target 1.1 specifically aims to eradicate extreme poverty (below $2.15/day).
               The FGT indices are central to monitoring progress: the headcount ratio tracks
               prevalence, the poverty gap tracks depth, and FGT(2) tracks severity and
               inequality among the poor."),

            h4("Purchasing Power Parity (PPP)"),
            p("International poverty lines are expressed in PPP dollars, which adjust for
               differences in the cost of living across countries. PPP conversion factors
               equalize the purchasing power of different currencies by accounting for price
               differences of comparable goods and services. The World Bank uses PPP exchange
               rates from the International Comparison Program (ICP) to ensure poverty lines
               are comparable across countries."),

            h4("References"),
            div(class = "ref",
              "Foster, J., Greer, J., & Thorbecke, E. (1984). A class of decomposable poverty
               measures. ", tags$i("Econometrica"), ", 52(3), 761-766."
            ),
            div(class = "ref",
              "Ravallion, M. (2016). ", tags$i("The Economics of Poverty: History, Measurement,
               and Policy"), ". Oxford University Press."
            ),
            div(class = "ref",
              "World Bank (2022). Poverty and Shared Prosperity 2022: Correcting Course.
               Washington, DC: World Bank."
            ),
            div(class = "ref",
              "Watts, H. W. (1968). An economic definition of poverty. In D. P. Moynihan (Ed.),
               ", tags$i("On Understanding Poverty"), ". Basic Books."
            ),
            div(class = "ref",
              "Atkinson, A. B. (1987). On the measurement of poverty. ",
              tags$i("Econometrica"), ", 55(4), 749-764."
            ),
            hr(),
            p(style = "color: #888; font-size: 12px;",
              "Impact Mojo | Poverty Line Analysis Tool | Built with R Shiny")
          )
        )
      )
    )
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

server <- function(input, output, session) {

  # ---- Reactive: raw income data ----
  rv <- reactiveValues(
    income_raw = NULL,
    subgroups = NULL,
    regen_counter = 0,
    sim_counter = 0
  )

  # Regenerate button
  observeEvent(input$btn_regenerate, {
    rv$regen_counter <- rv$regen_counter + 1
  })

  # Preset poverty line buttons
  observeEvent(input$preset_190, { updateNumericInput(session, "poverty_line", value = 1.90) })
  observeEvent(input$preset_215, { updateNumericInput(session, "poverty_line", value = 2.15) })
  observeEvent(input$preset_365, { updateNumericInput(session, "poverty_line", value = 3.65) })
  observeEvent(input$preset_685, { updateNumericInput(session, "poverty_line", value = 6.85) })

  # Generate or parse data
  income_data <- reactive({
    if (input$data_source == "generate") {
      # Depend on regenerate button
      rv$regen_counter
      inc <- generate_income_data(
        n = input$sample_size,
        distribution = input$distribution,
        mean_income = input$mean_income,
        sd_log = input$sd_log
      )
    } else {
      input$btn_parse
      raw <- isolate(input$paste_data)
      if (is.null(raw) || nchar(trimws(raw)) == 0) return(NULL)
      vals <- trimws(unlist(strsplit(raw, "[,\n\r]+")))
      inc <- suppressWarnings(as.numeric(vals))
      inc <- inc[!is.na(inc) & inc > 0]
      if (length(inc) < 2) return(NULL)
    }
    inc
  })

  # Adjusted income (with PPP factor)
  income_adj <- reactive({
    inc <- income_data()
    if (is.null(inc)) return(NULL)
    inc * input$ppp_factor
  })

  # Subgroups (regenerate with data)
  subgroups <- reactive({
    inc <- income_adj()
    if (is.null(inc)) return(NULL)
    assign_subgroups(length(inc))
  })

  # ---- FGT Indices tab ----
  output$card_fgt0 <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    val <- calc_fgt(inc, z, 0)
    n_poor <- sum(inc < z)
    div(class = "metric-card highlight",
      div(class = "metric-value", sprintf("%.1f%%", val * 100)),
      div(class = "metric-label", "FGT(0) -- Headcount Ratio"),
      div(class = "metric-sub", sprintf("%s of %s individuals below $%.2f",
        format(n_poor, big.mark = ","), format(length(inc), big.mark = ","), z))
    )
  })

  output$card_fgt1 <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    val <- calc_fgt(inc, z, 1)
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.3f", val)),
      div(class = "metric-label", "FGT(1) -- Poverty Gap"),
      div(class = "metric-sub", sprintf("%.1f%% average normalized shortfall", val * 100))
    )
  })

  output$card_fgt2 <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    val <- calc_fgt(inc, z, 2)
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.4f", val)),
      div(class = "metric-label", "FGT(2) -- Severity"),
      div(class = "metric-sub", "Squared poverty gap (inequality among poor)")
    )
  })

  output$card_watts <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    val <- calc_watts(inc, z)
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.4f", val)),
      div(class = "metric-label", "Watts Index"),
      div(class = "metric-sub", "Log-based poverty measure")
    )
  })

  output$card_pop <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    n_poor <- sum(inc < z)
    div(class = "metric-card",
      div(class = "metric-value", format(n_poor, big.mark = ",")),
      div(class = "metric-label", sprintf("Individuals below $%.2f poverty line", z)),
      div(class = "metric-sub", sprintf("Out of %s total | Poverty rate: %.1f%%",
        format(length(inc), big.mark = ","), 100 * n_poor / length(inc)))
    )
  })

  output$card_summary <- renderUI({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    poor_inc <- inc[inc < z]
    avg_gap <- if (length(poor_inc) > 0) mean(z - poor_inc) else 0
    div(class = "metric-card",
      div(class = "metric-value", sprintf("$%.2f", avg_gap)),
      div(class = "metric-label", "Average poverty gap ($ per day)"),
      div(class = "metric-sub", sprintf(
        "Mean income: $%.2f | Median: $%.2f | Gini approx: %.3f",
        mean(inc), median(inc),
        {
          n <- length(inc)
          s <- sort(inc)
          2 * sum((1:n) * s) / (n * sum(s)) - (n + 1) / n
        }
      ))
    )
  })

  # Multi-line comparison table
  output$multi_line_table <- renderTable({
    inc <- income_adj()
    req(inc)
    lines <- c(1.90, 2.15, 3.65, 6.85)
    data.frame(
      `Poverty Line` = sprintf("$%.2f", lines),
      `FGT(0) Headcount` = sapply(lines, function(z) sprintf("%.1f%%", calc_fgt(inc, z, 0) * 100)),
      `FGT(1) Gap` = sapply(lines, function(z) sprintf("%.4f", calc_fgt(inc, z, 1))),
      `FGT(2) Severity` = sapply(lines, function(z) sprintf("%.4f", calc_fgt(inc, z, 2))),
      `Watts Index` = sapply(lines, function(z) sprintf("%.4f", calc_watts(inc, z))),
      `N Poor` = sapply(lines, function(z) format(sum(inc < z), big.mark = ",")),
      check.names = FALSE
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE, align = "c")

  # ---- Distribution tab ----
  output$density_plot <- renderPlot({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    df <- data.frame(income = inc)
    x_max <- quantile(inc, 0.98)

    # Build poverty lines data
    if (input$show_multi_lines) {
      plines <- data.frame(
        z = c(1.90, 2.15, 3.65, 6.85),
        label = c("$1.90", "$2.15", "$3.65", "$6.85")
      )
    } else {
      plines <- data.frame(z = z, label = sprintf("$%.2f", z))
    }

    # Compute density for shading
    dens <- density(inc, from = 0, to = max(inc), n = 512)
    dens_df <- data.frame(x = dens$x, y = dens$y)
    shade_df <- dens_df[dens_df$x <= z, ]

    p <- ggplot(df, aes(x = income)) +
      geom_density(fill = "#2b5e8c", alpha = 0.25, color = "#2b5e8c", linewidth = 0.8) +
      geom_area(data = shade_df, aes(x = x, y = y), fill = "#d62828", alpha = 0.35) +
      geom_vline(data = plines, aes(xintercept = z), color = "#d62828",
                 linetype = "dashed", linewidth = 0.9) +
      geom_text(data = plines, aes(x = z, y = Inf, label = label),
                vjust = 2, hjust = -0.15, color = "#d62828", fontface = "bold", size = 3.8) +
      coord_cartesian(xlim = c(0, x_max)) +
      labs(
        title = "Income Density Distribution",
        subtitle = sprintf("Shaded area: population below $%.2f poverty line", z),
        x = "Daily income (PPP $)", y = "Density"
      ) +
      theme_impact()
    p
  })

  output$cdf_plot <- renderPlot({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    x_max <- quantile(inc, 0.98)
    df <- data.frame(income = sort(inc), cdf = seq_along(inc) / length(inc))

    if (input$show_multi_lines) {
      plines <- data.frame(
        z = c(1.90, 2.15, 3.65, 6.85),
        label = c("$1.90", "$2.15", "$3.65", "$6.85")
      )
    } else {
      plines <- data.frame(z = z, label = sprintf("$%.2f", z))
    }

    headcount <- calc_fgt(inc, z, 0)

    p <- ggplot(df, aes(x = income, y = cdf)) +
      geom_line(color = "#2b5e8c", linewidth = 0.9) +
      geom_vline(data = plines, aes(xintercept = z), color = "#d62828",
                 linetype = "dashed", linewidth = 0.8) +
      geom_hline(yintercept = headcount, color = "#888888", linetype = "dotted", linewidth = 0.6) +
      annotate("text", x = z * 0.5, y = headcount + 0.03,
               label = sprintf("H = %.1f%%", headcount * 100),
               color = "#d62828", fontface = "bold", size = 3.5) +
      coord_cartesian(xlim = c(0, x_max)) +
      scale_y_continuous(labels = scales::percent_format(1)) +
      labs(
        title = "Cumulative Distribution (CDF)",
        subtitle = "Headcount ratio = CDF at poverty line",
        x = "Daily income (PPP $)", y = "Cumulative proportion"
      ) +
      theme_impact()
    p
  })

  output$histogram_plot <- renderPlot({
    inc <- income_adj()
    req(inc)
    z <- input$poverty_line
    x_max <- quantile(inc, 0.98)
    df <- data.frame(income = inc, poor = ifelse(inc < z, "Below poverty line", "Above poverty line"))

    p <- ggplot(df, aes(x = income, fill = poor)) +
      geom_histogram(bins = 60, color = "white", linewidth = 0.2, alpha = 0.85) +
      scale_fill_manual(values = c("Below poverty line" = "#d62828", "Above poverty line" = "#2b5e8c")) +
      coord_cartesian(xlim = c(0, x_max)) +
      labs(
        title = "Income Histogram",
        subtitle = sprintf("Poverty line: $%.2f | Red = below poverty line", z),
        x = "Daily income (PPP $)", y = "Count", fill = NULL
      ) +
      theme_impact()
    p
  })

  # ---- Poverty Profile tab ----
  calc_profile <- function(inc, sg, z) {
    df <- data.frame(income = inc, sg)
    loc <- df %>%
      group_by(location) %>%
      summarise(
        FGT0 = calc_fgt(income, z, 0),
        FGT1 = calc_fgt(income, z, 1),
        FGT2 = calc_fgt(income, z, 2),
        N = n(),
        N_poor = sum(income < z),
        .groups = "drop"
      ) %>%
      rename(Group = location) %>%
      mutate(Category = "Location")

    gen <- df %>%
      group_by(hh_head) %>%
      summarise(
        FGT0 = calc_fgt(income, z, 0),
        FGT1 = calc_fgt(income, z, 1),
        FGT2 = calc_fgt(income, z, 2),
        N = n(),
        N_poor = sum(income < z),
        .groups = "drop"
      ) %>%
      rename(Group = hh_head) %>%
      mutate(Category = "Household Head")

    reg <- df %>%
      group_by(region) %>%
      summarise(
        FGT0 = calc_fgt(income, z, 0),
        FGT1 = calc_fgt(income, z, 1),
        FGT2 = calc_fgt(income, z, 2),
        N = n(),
        N_poor = sum(income < z),
        .groups = "drop"
      ) %>%
      rename(Group = region) %>%
      mutate(Category = "Region")

    bind_rows(loc, gen, reg)
  }

  profile_data <- reactive({
    inc <- income_adj()
    sg <- subgroups()
    req(inc, sg)
    z <- input$poverty_line
    # Apply subgroup-specific income adjustments for realism
    # Rural incomes ~20% lower, female-headed ~15% lower, regions vary
    adj <- rep(1, length(inc))
    adj[sg$location == "Rural"] <- adj[sg$location == "Rural"] * 0.80
    adj[sg$hh_head == "Female-headed"] <- adj[sg$hh_head == "Female-headed"] * 0.85
    region_mult <- c("Region 1" = 0.75, "Region 2" = 0.90, "Region 3" = 1.0,
                     "Region 4" = 1.10, "Region 5" = 1.25)
    for (r in names(region_mult)) {
      adj[sg$region == r] <- adj[sg$region == r] * region_mult[r]
    }
    inc_adj <- inc * adj
    calc_profile(inc_adj, sg, z)
  })

  output$profile_location_plot <- renderPlot({
    prof <- profile_data()
    req(prof)
    loc_df <- prof %>% filter(Category == "Location")
    ggplot(loc_df, aes(x = Group, y = FGT0, fill = Group)) +
      geom_col(width = 0.6, alpha = 0.9) +
      geom_text(aes(label = sprintf("%.1f%%", FGT0 * 100)), vjust = -0.5, fontface = "bold", size = 4) +
      scale_fill_manual(values = c("Urban" = "#2b5e8c", "Rural" = "#d62828")) +
      scale_y_continuous(labels = scales::percent_format(1), expand = expansion(mult = c(0, 0.15))) +
      labs(title = "Poverty Rate by Location", subtitle = "FGT(0) headcount ratio",
           x = NULL, y = "Headcount ratio") +
      theme_impact() + theme(legend.position = "none")
  })

  output$profile_gender_plot <- renderPlot({
    prof <- profile_data()
    req(prof)
    gen_df <- prof %>% filter(Category == "Household Head")
    ggplot(gen_df, aes(x = Group, y = FGT0, fill = Group)) +
      geom_col(width = 0.6, alpha = 0.9) +
      geom_text(aes(label = sprintf("%.1f%%", FGT0 * 100)), vjust = -0.5, fontface = "bold", size = 4) +
      scale_fill_manual(values = c("Male-headed" = "#2b5e8c", "Female-headed" = "#e76f51")) +
      scale_y_continuous(labels = scales::percent_format(1), expand = expansion(mult = c(0, 0.15))) +
      labs(title = "Poverty Rate by Household Head", subtitle = "FGT(0) headcount ratio",
           x = NULL, y = "Headcount ratio") +
      theme_impact() + theme(legend.position = "none")
  })

  output$profile_region_plot <- renderPlot({
    prof <- profile_data()
    req(prof)
    reg_df <- prof %>% filter(Category == "Region") %>% arrange(Group)
    ggplot(reg_df, aes(x = reorder(Group, FGT0), y = FGT0, fill = FGT0)) +
      geom_col(width = 0.65, alpha = 0.9) +
      geom_text(aes(label = sprintf("%.1f%%", FGT0 * 100)), hjust = -0.15, fontface = "bold", size = 3.8) +
      scale_fill_gradient(low = "#f4a261", high = "#d62828", guide = "none") +
      scale_y_continuous(labels = scales::percent_format(1), expand = expansion(mult = c(0, 0.2))) +
      coord_flip() +
      labs(title = "Poverty Rate by Region", subtitle = "FGT(0) headcount ratio, sorted",
           x = NULL, y = "Headcount ratio") +
      theme_impact()
  })

  output$subgroup_table <- renderTable({
    prof <- profile_data()
    req(prof)
    prof %>%
      mutate(
        `Headcount (%)` = sprintf("%.1f%%", FGT0 * 100),
        `Poverty Gap` = sprintf("%.4f", FGT1),
        `Severity` = sprintf("%.4f", FGT2),
        `N` = format(N, big.mark = ","),
        `N Poor` = format(N_poor, big.mark = ",")
      ) %>%
      select(Category, Group, `Headcount (%)`, `Poverty Gap`, Severity, N, `N Poor`)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, align = "c")

  # ---- Growth & Redistribution tab ----
  sim_results <- reactive({
    input$btn_simulate
    inc <- isolate(income_adj())
    req(inc)
    z <- isolate(input$poverty_line)
    growth <- isolate(input$growth_rate) / 100
    redist <- isolate(input$redist_share) / 100

    # Baseline
    base_fgt0 <- calc_fgt(inc, z, 0)
    base_fgt1 <- calc_fgt(inc, z, 1)
    base_fgt2 <- calc_fgt(inc, z, 2)

    # Uniform growth
    inc_growth <- inc * (1 + growth)
    growth_fgt0 <- calc_fgt(inc_growth, z, 0)
    growth_fgt1 <- calc_fgt(inc_growth, z, 1)
    growth_fgt2 <- calc_fgt(inc_growth, z, 2)

    # Growth + redistribution
    total_growth_amount <- sum(inc) * growth
    redist_amount <- total_growth_amount * redist
    remaining_growth <- growth * (1 - redist)
    inc_redist <- inc * (1 + remaining_growth)

    # Identify bottom quintile
    q20 <- quantile(inc, 0.20)
    bottom_idx <- which(inc <= q20)
    if (length(bottom_idx) > 0) {
      per_person <- redist_amount / length(bottom_idx)
      inc_redist[bottom_idx] <- inc_redist[bottom_idx] + per_person
    }
    redist_fgt0 <- calc_fgt(inc_redist, z, 0)
    redist_fgt1 <- calc_fgt(inc_redist, z, 1)
    redist_fgt2 <- calc_fgt(inc_redist, z, 2)

    list(
      baseline = inc,
      growth = inc_growth,
      redist = inc_redist,
      z = z,
      table = data.frame(
        Scenario = c("Baseline", "Uniform Growth", "Growth + Redistribution"),
        `FGT(0) Headcount` = sprintf("%.1f%%", c(base_fgt0, growth_fgt0, redist_fgt0) * 100),
        `FGT(1) Gap` = sprintf("%.4f", c(base_fgt1, growth_fgt1, redist_fgt1)),
        `FGT(2) Severity` = sprintf("%.4f", c(base_fgt2, growth_fgt2, redist_fgt2)),
        `N Poor` = format(c(sum(inc < z), sum(inc_growth < z), sum(inc_redist < z)), big.mark = ","),
        check.names = FALSE
      ),
      fgt0 = c(base_fgt0, growth_fgt0, redist_fgt0)
    )
  })

  output$growth_plot <- renderPlot({
    res <- sim_results()
    req(res)
    z <- res$z
    x_max <- quantile(c(res$baseline, res$growth, res$redist), 0.95)

    df <- bind_rows(
      data.frame(income = res$baseline, Scenario = "Baseline"),
      data.frame(income = res$growth, Scenario = "Uniform Growth"),
      data.frame(income = res$redist, Scenario = "Growth + Redistribution")
    )
    df$Scenario <- factor(df$Scenario, levels = c("Baseline", "Uniform Growth", "Growth + Redistribution"))

    ggplot(df, aes(x = income, color = Scenario, fill = Scenario)) +
      geom_density(alpha = 0.15, linewidth = 0.9) +
      geom_vline(xintercept = z, color = "#d62828", linetype = "dashed", linewidth = 0.8) +
      annotate("text", x = z, y = Inf, label = sprintf("z = $%.2f", z),
               vjust = 2, hjust = -0.1, color = "#d62828", fontface = "bold", size = 3.5) +
      coord_cartesian(xlim = c(0, x_max)) +
      scale_color_manual(values = c("#888888", "#2b5e8c", "#2a9d8f")) +
      scale_fill_manual(values = c("#888888", "#2b5e8c", "#2a9d8f")) +
      labs(
        title = "Income Distribution Under Growth & Redistribution Scenarios",
        subtitle = sprintf("Growth: %+d%% | Redistribution to bottom quintile: %d%%",
          input$growth_rate, input$redist_share),
        x = "Daily income (PPP $)", y = "Density", color = NULL, fill = NULL
      ) +
      theme_impact()
  })

  output$sim_card_baseline <- renderUI({
    res <- sim_results()
    req(res)
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.1f%%", res$fgt0[1] * 100)),
      div(class = "metric-label", "Baseline Headcount")
    )
  })

  output$sim_card_growth <- renderUI({
    res <- sim_results()
    req(res)
    change <- res$fgt0[2] - res$fgt0[1]
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.1f%%", res$fgt0[2] * 100)),
      div(class = "metric-label", "After Growth"),
      div(class = "metric-sub", sprintf("%+.1f pp change", change * 100))
    )
  })

  output$sim_card_redist <- renderUI({
    res <- sim_results()
    req(res)
    change <- res$fgt0[3] - res$fgt0[1]
    div(class = "metric-card",
      div(class = "metric-value", sprintf("%.1f%%", res$fgt0[3] * 100)),
      div(class = "metric-label", "After Redistribution"),
      div(class = "metric-sub", sprintf("%+.1f pp change", change * 100))
    )
  })

  output$growth_table <- renderTable({
    res <- sim_results()
    req(res)
    res$table
  }, striped = TRUE, hover = TRUE, bordered = TRUE, align = "c")
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
shinyApp(ui = ui, server = server)
