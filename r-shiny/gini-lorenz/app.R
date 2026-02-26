# =============================================================================
# Gini & Lorenz Curve Tool -- Impact Mojo
# A development economics tool for inequality analysis
# Self-contained Shiny app using: shiny, ggplot2, dplyr
# =============================================================================

library(shiny)
library(ggplot2)
library(dplyr)

# =============================================================================
# Helper Functions
# =============================================================================

compute_gini <- function(x) {
  x <- sort(x[x >= 0])
  n <- length(x)
  if (n < 2 || sum(x) == 0) return(NA_real_)
  numerator <- 2 * sum(seq_len(n) * x) - (n + 1) * sum(x)
  gini <- numerator / (n * sum(x))
  return(gini)
}

compute_lorenz <- function(x) {
  x <- sort(x[x >= 0])
  n <- length(x)
  cum_income <- cumsum(x) / sum(x)
  cum_pop <- seq_len(n) / n
  data.frame(
    cum_pop = c(0, cum_pop),
    cum_income = c(0, cum_income)
  )
}

compute_theil <- function(x) {
  x <- x[x > 0]
  n <- length(x)
  if (n < 2) return(NA_real_)
  mu <- mean(x)
  theil <- mean((x / mu) * log(x / mu))
  return(theil)
}

compute_palma <- function(x) {
  x <- sort(x[x >= 0])
  n <- length(x)
  bottom_40_cutoff <- floor(n * 0.40)
  top_10_cutoff <- floor(n * 0.90)
  bottom_40_share <- sum(x[1:bottom_40_cutoff])
  top_10_share <- sum(x[(top_10_cutoff + 1):n])
  if (bottom_40_share == 0) return(NA_real_)
  return(top_10_share / bottom_40_share)
}

compute_quantile_shares <- function(x, n_groups) {
  x <- sort(x[x >= 0])
  n <- length(x)
  total <- sum(x)
  groups <- cut(seq_len(n),
                breaks = quantile(seq_len(n), probs = seq(0, 1, length.out = n_groups + 1)),
                include.lowest = TRUE, labels = FALSE)
  shares <- tapply(x, groups, sum) / total * 100
  labels <- paste0("Q", seq_len(n_groups))
  data.frame(
    quantile = factor(labels, levels = labels),
    share = as.numeric(shares)
  )
}

compute_income_shares <- function(x, n_groups) {
  x <- sort(x[x >= 0])
  n <- length(x)
  total <- sum(x)
  breaks <- floor(seq(0, n, length.out = n_groups + 1))
  shares <- numeric(n_groups)
  for (i in seq_len(n_groups)) {
    idx_start <- breaks[i] + 1
    idx_end <- breaks[i + 1]
    shares[i] <- sum(x[idx_start:idx_end]) / total * 100
  }
  shares
}

generate_distribution <- function(dist_type, n, param1, param2) {
  set.seed(NULL)
  vals <- switch(dist_type,
    "Log-normal" = rlnorm(n, meanlog = param1, sdlog = param2),
    "Pareto" = {
      u <- runif(n)
      xm <- param2
      alpha <- param1
      xm / (u^(1 / alpha))
    },
    "Exponential" = rexp(n, rate = 1 / param1),
    "Uniform" = runif(n, min = param1, max = param2),
    rlnorm(n, meanlog = param1, sdlog = param2)
  )
  vals[vals < 0] <- 0
  return(vals)
}

# Theme for plots
theme_impact_mojo <- function() {
  theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", size = 16, hjust = 0, color = "#1a1a2e"),
      plot.subtitle = element_text(size = 12, color = "#555555", margin = margin(b = 12)),
      plot.caption = element_text(size = 9, color = "#999999", hjust = 1),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e8e8e8", linewidth = 0.4),
      axis.title = element_text(face = "bold", size = 12, color = "#333333"),
      axis.text = element_text(size = 11, color = "#555555"),
      legend.position = "bottom",
      legend.text = element_text(size = 11),
      legend.title = element_text(face = "bold", size = 11),
      plot.margin = margin(15, 20, 15, 15),
      strip.text = element_text(face = "bold", size = 12)
    )
}

palette_main <- c("#2c6fbb", "#e63946")

# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f7f8fc;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }
      .title-bar {
        background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
        color: #ffffff;
        padding: 18px 28px;
        margin: -15px -15px 20px -15px;
        border-radius: 0 0 6px 6px;
      }
      .title-bar h2 {
        margin: 0;
        font-weight: 700;
        font-size: 24px;
        letter-spacing: 0.5px;
      }
      .title-bar .subtitle {
        margin: 4px 0 0 0;
        font-size: 13px;
        opacity: 0.8;
        font-weight: 400;
      }
      .well {
        background-color: #ffffff;
        border: 1px solid #dde1ea;
        border-radius: 8px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.05);
      }
      .nav-tabs > li > a {
        font-weight: 600;
        color: #555555;
      }
      .nav-tabs > li.active > a {
        color: #2c6fbb;
        border-bottom: 2px solid #2c6fbb;
      }
      .stat-card {
        background: #ffffff;
        border: 1px solid #dde1ea;
        border-radius: 8px;
        padding: 16px 20px;
        margin-bottom: 12px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.04);
      }
      .stat-card h4 {
        margin: 0 0 4px 0;
        font-size: 13px;
        color: #888888;
        text-transform: uppercase;
        letter-spacing: 0.8px;
        font-weight: 600;
      }
      .stat-card .stat-value {
        font-size: 26px;
        font-weight: 700;
        color: #1a1a2e;
      }
      .section-header {
        font-weight: 700;
        color: #1a1a2e;
        border-bottom: 2px solid #2c6fbb;
        padding-bottom: 6px;
        margin-bottom: 14px;
        margin-top: 18px;
      }
      .about-section {
        max-width: 800px;
        line-height: 1.7;
        color: #333;
      }
      .about-section h3 {
        color: #1a1a2e;
        margin-top: 24px;
        font-weight: 700;
      }
      .about-section h4 {
        color: #2c6fbb;
        margin-top: 18px;
        font-weight: 600;
      }
      .formula-box {
        background: #f0f4fa;
        border-left: 4px solid #2c6fbb;
        padding: 12px 16px;
        margin: 10px 0;
        border-radius: 0 6px 6px 0;
        font-family: 'Courier New', Courier, monospace;
        font-size: 13px;
        overflow-x: auto;
      }
      .sidebar-section-label {
        font-weight: 700;
        color: #1a1a2e;
        font-size: 13px;
        text-transform: uppercase;
        letter-spacing: 0.6px;
        margin-top: 14px;
        margin-bottom: 6px;
        padding-bottom: 4px;
        border-bottom: 1px solid #e0e0e0;
      }
    "))
  ),

  div(class = "title-bar",
    h2("Gini & Lorenz Curve Tool"),
    p(class = "subtitle", "Impact Mojo | Development Economics Inequality Toolkit")
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      # Data input mode
      radioButtons("data_mode", "Data Input Mode",
        choices = c("Generate", "Paste data"),
        selected = "Generate", inline = TRUE
      ),

      # ----- Generate mode controls -----
      conditionalPanel(
        condition = "input.data_mode == 'Generate'",
        div(class = "sidebar-section-label", "Distribution A"),
        selectInput("dist_type_a", "Distribution Type",
          choices = c("Log-normal", "Pareto", "Exponential", "Uniform"),
          selected = "Log-normal"
        ),
        sliderInput("pop_size_a", "Population Size",
          min = 100, max = 10000, value = 1000, step = 100
        ),
        conditionalPanel(
          condition = "input.dist_type_a == 'Log-normal'",
          numericInput("lnorm_mean_a", "Mean (log scale)", value = 7, step = 0.1),
          numericInput("lnorm_sd_a", "Std Dev (log scale)", value = 1.0, step = 0.1, min = 0.01)
        ),
        conditionalPanel(
          condition = "input.dist_type_a == 'Pareto'",
          numericInput("pareto_shape_a", "Shape (alpha)", value = 2.0, step = 0.1, min = 0.1),
          numericInput("pareto_scale_a", "Scale (x_m)", value = 1000, step = 100, min = 1)
        ),
        conditionalPanel(
          condition = "input.dist_type_a == 'Exponential'",
          numericInput("exp_mean_a", "Mean", value = 5000, step = 100, min = 1)
        ),
        conditionalPanel(
          condition = "input.dist_type_a == 'Uniform'",
          numericInput("unif_min_a", "Minimum", value = 500, step = 100),
          numericInput("unif_max_a", "Maximum", value = 10000, step = 100)
        ),
        actionButton("generate_a", "Generate Distribution A",
          class = "btn-primary", style = "width:100%; margin-bottom: 10px;"
        )
      ),

      # ----- Paste mode controls -----
      conditionalPanel(
        condition = "input.data_mode == 'Paste data'",
        div(class = "sidebar-section-label", "Paste Values"),
        textAreaInput("paste_data_a", "Income/consumption values (comma-separated)",
          placeholder = "e.g. 1200, 3400, 5600, 2300, 8900, ...",
          rows = 5
        ),
        actionButton("parse_a", "Load Data A",
          class = "btn-primary", style = "width:100%; margin-bottom: 10px;"
        )
      ),

      hr(),

      # ----- Compare toggle -----
      checkboxInput("compare_mode", "Compare two distributions", value = FALSE),

      # ----- Second distribution -----
      conditionalPanel(
        condition = "input.compare_mode == true",
        div(class = "sidebar-section-label", "Distribution B"),
        conditionalPanel(
          condition = "input.data_mode == 'Generate'",
          selectInput("dist_type_b", "Distribution Type",
            choices = c("Log-normal", "Pareto", "Exponential", "Uniform"),
            selected = "Pareto"
          ),
          sliderInput("pop_size_b", "Population Size",
            min = 100, max = 10000, value = 1000, step = 100
          ),
          conditionalPanel(
            condition = "input.dist_type_b == 'Log-normal'",
            numericInput("lnorm_mean_b", "Mean (log scale)", value = 7, step = 0.1),
            numericInput("lnorm_sd_b", "Std Dev (log scale)", value = 0.5, step = 0.1, min = 0.01)
          ),
          conditionalPanel(
            condition = "input.dist_type_b == 'Pareto'",
            numericInput("pareto_shape_b", "Shape (alpha)", value = 3.0, step = 0.1, min = 0.1),
            numericInput("pareto_scale_b", "Scale (x_m)", value = 1000, step = 100, min = 1)
          ),
          conditionalPanel(
            condition = "input.dist_type_b == 'Exponential'",
            numericInput("exp_mean_b", "Mean", value = 3000, step = 100, min = 1)
          ),
          conditionalPanel(
            condition = "input.dist_type_b == 'Uniform'",
            numericInput("unif_min_b", "Minimum", value = 1000, step = 100),
            numericInput("unif_max_b", "Maximum", value = 5000, step = 100)
          ),
          actionButton("generate_b", "Generate Distribution B",
            class = "btn-info", style = "width:100%; margin-bottom: 10px;"
          )
        ),
        conditionalPanel(
          condition = "input.data_mode == 'Paste data'",
          textAreaInput("paste_data_b", "Income/consumption values (comma-separated)",
            placeholder = "e.g. 2000, 2100, 2200, 2300, ...",
            rows = 5
          ),
          actionButton("parse_b", "Load Data B",
            class = "btn-info", style = "width:100%; margin-bottom: 10px;"
          )
        )
      ),

      hr(),

      # Quantile groups
      selectInput("n_quantiles", "Quantile Groups (bar chart)",
        choices = c("Quintiles (5)" = 5, "Deciles (10)" = 10, "Ventiles (20)" = 20),
        selected = 5
      )
    ),

    # =========================================================================
    # Main Panel
    # =========================================================================
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs", type = "tabs",

        # --- Lorenz Curve Tab ---
        tabPanel("Lorenz Curve",
          br(),
          plotOutput("lorenz_plot", height = "560px"),
          div(style = "margin-top: 8px; color: #888; font-size: 12px;",
            "The shaded area between the Lorenz curve and the line of equality represents the degree of inequality."
          )
        ),

        # --- Summary Statistics Tab ---
        tabPanel("Summary Statistics",
          br(),
          uiOutput("summary_stats_ui")
        ),

        # --- Distribution Tab ---
        tabPanel("Distribution",
          br(),
          plotOutput("dist_plot", height = "520px")
        ),

        # --- Quantile Shares Tab ---
        tabPanel("Quantile Shares",
          br(),
          plotOutput("quantile_plot", height = "520px")
        ),

        # --- About Tab ---
        tabPanel("About",
          br(),
          div(class = "about-section",
            h3("About This Tool"),
            p("The Gini & Lorenz Curve Tool is part of the",
              strong("Impact Mojo"), "portfolio of development economics applications.",
              "It provides interactive exploration of income and consumption inequality",
              "using the most widely used metrics in development economics and poverty monitoring."),

            h4("The Lorenz Curve"),
            p("Developed by Max O. Lorenz in 1905, the Lorenz curve is a graphical",
              "representation of the distribution of income or wealth within a population.",
              "The horizontal axis shows the cumulative share of the population (from poorest",
              "to richest) and the vertical axis shows the cumulative share of income.",
              "A 45-degree line represents perfect equality, where every person has the same income."),

            h4("The Gini Coefficient"),
            p("The Gini coefficient, developed by Corrado Gini in 1912, is the most widely",
              "used single measure of inequality. It equals twice the area between the Lorenz",
              "curve and the line of perfect equality."),
            div(class = "formula-box",
              "G = (2 / n * mu) * SUM_i [ i * x_(i) ] - (n + 1) / n"),
            p("Where x_(i) are values sorted in ascending order, n is population size, and mu is the mean.",
              "The coefficient ranges from 0 (perfect equality) to 1 (perfect inequality).",
              "Typical country-level Gini values for income range from about 0.25 (Scandinavian countries)",
              "to above 0.60 (South Africa, parts of Latin America)."),

            h4("The Theil Index"),
            p("The Theil index (Theil's T) belongs to the family of Generalized Entropy measures.",
              "Unlike the Gini coefficient, it is decomposable: total inequality can be broken",
              "down into within-group and between-group components, making it valuable for",
              "analyzing inequality across regions, sectors, or demographic groups."),
            div(class = "formula-box",
              "T = (1/n) * SUM_i [ (x_i / mu) * ln(x_i / mu) ]"),
            p("Values range from 0 (perfect equality) to ln(n) (maximum inequality).",
              "A Theil index of 0.5 or above generally indicates high inequality."),

            h4("The Palma Ratio"),
            p("Proposed by Gabriel Palma (2011) and popularized by Alex Cobham and Andy Sumner,",
              "the Palma ratio is defined as the income share of the top 10% divided by the",
              "income share of the bottom 40%. It is based on the empirical observation that",
              "the middle 50% (deciles 5-9) tend to capture approximately half of total income",
              "across countries, so the main variation in inequality is driven by the tails."),
            div(class = "formula-box",
              "Palma = Income share of top 10% / Income share of bottom 40%"),
            p("A Palma ratio of 1 means the top 10% earn as much as the bottom 40%.",
              "Values above 2 indicate high inequality. The Palma ratio is used in SDG indicator",
              "10.1 discussions and is favored by many development practitioners for its",
              "intuitive interpretation."),

            h4("P90/P10 Ratio"),
            p("The ratio of income at the 90th percentile to income at the 10th percentile.",
              "This measure captures the distance between the top and bottom of the distribution",
              "while being robust to extreme outliers. The OECD frequently uses this metric in",
              "cross-country inequality comparisons."),

            h3("Development Economics Context"),
            h4("World Bank Poverty Monitoring"),
            p("The World Bank uses the Gini coefficient extensively in its",
              "World Development Indicators (WDI) and PovcalNet databases. Inequality metrics",
              "inform the Bank's twin goals of ending extreme poverty and boosting shared",
              "prosperity (measured as income growth of the bottom 40%)."),

            h4("Sustainable Development Goals (SDGs)"),
            p("SDG 10 ('Reduce inequality within and among countries') directly targets",
              "income inequality. Target 10.1 calls for progressively achieving income growth",
              "of the bottom 40% at a rate higher than the national average. The Palma ratio",
              "and Gini coefficient are key monitoring tools for this target."),

            h4("Limitations"),
            tags$ul(
              tags$li("The Gini coefficient is more sensitive to changes in the middle of the distribution than at the tails."),
              tags$li("Different Lorenz curves can produce the same Gini coefficient (crossing curves)."),
              tags$li("Income-based measures may not capture wealth inequality, access to services, or non-monetary dimensions of well-being."),
              tags$li("Survey-based income data often suffer from underreporting at the top, underestimating true inequality.")
            ),

            h3("References"),
            tags$ul(
              tags$li("Lorenz, M.O. (1905). 'Methods of Measuring the Concentration of Wealth.',",
                       em("Publications of the American Statistical Association"), ", 9(70), 209-219."),
              tags$li("Gini, C. (1912).", em("Variabilita e mutabilita."), "Bologna: Tipografia di Paolo Cuppini."),
              tags$li("Theil, H. (1967).", em("Economics and Information Theory."), "Amsterdam: North-Holland."),
              tags$li("Palma, J.G. (2011). 'Homogeneous middles vs. heterogeneous tails, and the end of the",
                       "'Inverted-U': It's all about the share of the rich.',", em("Development and Change"), ", 42(1), 87-153."),
              tags$li("Cobham, A. & Sumner, A. (2013). 'Putting the Gini Back in the Bottle?",
                       "The Palma as a Policy-Relevant Measure of Inequality.',",
                       em("King's College London Working Paper.")),
              tags$li("World Bank (2016).", em("Poverty and Shared Prosperity: Taking on Inequality."),
                       "Washington, DC: World Bank Group."),
              tags$li("United Nations (2015).", em("Transforming Our World: The 2030 Agenda for Sustainable Development."))
            ),

            br(), br()
          )
        )
      )
    )
  )
)


# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

  # ---- Reactive values for distributions ----
  data_a <- reactiveVal(NULL)
  data_b <- reactiveVal(NULL)

  # ---- Generate / load Distribution A ----
  observeEvent(input$generate_a, {
    params <- switch(input$dist_type_a,
      "Log-normal" = list(p1 = input$lnorm_mean_a, p2 = input$lnorm_sd_a),
      "Pareto"     = list(p1 = input$pareto_shape_a, p2 = input$pareto_scale_a),
      "Exponential" = list(p1 = input$exp_mean_a, p2 = 0),
      "Uniform"    = list(p1 = input$unif_min_a, p2 = input$unif_max_a)
    )
    vals <- generate_distribution(input$dist_type_a, input$pop_size_a, params$p1, params$p2)
    data_a(vals)
  })

  observeEvent(input$parse_a, {
    txt <- input$paste_data_a
    vals <- tryCatch({
      v <- as.numeric(trimws(unlist(strsplit(txt, "[,;\\s]+"))))
      v[!is.na(v) & v >= 0]
    }, error = function(e) NULL)
    if (!is.null(vals) && length(vals) > 1) {
      data_a(vals)
    } else {
      showNotification("Could not parse data A. Please check format.", type = "error")
    }
  })

  # ---- Generate / load Distribution B ----
  observeEvent(input$generate_b, {
    params <- switch(input$dist_type_b,
      "Log-normal" = list(p1 = input$lnorm_mean_b, p2 = input$lnorm_sd_b),
      "Pareto"     = list(p1 = input$pareto_shape_b, p2 = input$pareto_scale_b),
      "Exponential" = list(p1 = input$exp_mean_b, p2 = 0),
      "Uniform"    = list(p1 = input$unif_min_b, p2 = input$unif_max_b)
    )
    vals <- generate_distribution(input$dist_type_b, input$pop_size_b, params$p1, params$p2)
    data_b(vals)
  })

  observeEvent(input$parse_b, {
    txt <- input$paste_data_b
    vals <- tryCatch({
      v <- as.numeric(trimws(unlist(strsplit(txt, "[,;\\s]+"))))
      v[!is.na(v) & v >= 0]
    }, error = function(e) NULL)
    if (!is.null(vals) && length(vals) > 1) {
      data_b(vals)
    } else {
      showNotification("Could not parse data B. Please check format.", type = "error")
    }
  })

  # ---- Auto-generate on startup ----
  observe({
    if (is.null(data_a())) {
      vals <- generate_distribution("Log-normal", 1000, 7, 1.0)
      data_a(vals)
    }
  })

  # ---- Label helpers ----
  label_a <- reactive({
    if (input$data_mode == "Generate") {
      paste0("A: ", input$dist_type_a)
    } else {
      "A: Pasted data"
    }
  })

  label_b <- reactive({
    if (input$data_mode == "Generate") {
      paste0("B: ", input$dist_type_b)
    } else {
      "B: Pasted data"
    }
  })

  # =========================================================================
  # LORENZ CURVE PLOT
  # =========================================================================
  output$lorenz_plot <- renderPlot({
    req(data_a())
    lorenz_a <- compute_lorenz(data_a())
    gini_a <- compute_gini(data_a())

    lorenz_a$group <- label_a()

    p <- ggplot() +
      geom_ribbon(
        data = lorenz_a,
        aes(x = cum_pop, ymin = cum_income, ymax = cum_pop),
        fill = palette_main[1], alpha = 0.15
      ) +
      geom_line(
        data = data.frame(x = c(0, 1), y = c(0, 1)),
        aes(x = x, y = y), linetype = "dashed", color = "#888888", linewidth = 0.8
      ) +
      geom_line(
        data = lorenz_a,
        aes(x = cum_pop, y = cum_income, color = group),
        linewidth = 1.2
      )

    if (input$compare_mode && !is.null(data_b())) {
      lorenz_b <- compute_lorenz(data_b())
      gini_b <- compute_gini(data_b())
      lorenz_b$group <- label_b()

      p <- p +
        geom_ribbon(
          data = lorenz_b,
          aes(x = cum_pop, ymin = cum_income, ymax = cum_pop),
          fill = palette_main[2], alpha = 0.10
        ) +
        geom_line(
          data = lorenz_b,
          aes(x = cum_pop, y = cum_income, color = group),
          linewidth = 1.2
        ) +
        scale_color_manual(
          name = "Distribution",
          values = setNames(palette_main, c(label_a(), label_b()))
        ) +
        labs(
          subtitle = sprintf("Gini A = %.4f  |  Gini B = %.4f", gini_a, gini_b)
        )
    } else {
      p <- p +
        scale_color_manual(
          name = "Distribution",
          values = setNames(palette_main[1], label_a())
        ) +
        labs(
          subtitle = sprintf("Gini Coefficient = %.4f", gini_a)
        )
    }

    p +
      labs(
        title = "Lorenz Curve",
        x = "Cumulative Share of Population",
        y = "Cumulative Share of Income",
        caption = "Impact Mojo | Gini & Lorenz Curve Tool"
      ) +
      scale_x_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0, 1, 0.2)) +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0, 1, 0.2)) +
      annotate("text", x = 0.55, y = 0.45, label = "Line of Perfect Equality",
               color = "#888888", size = 3.8, angle = 38, fontface = "italic") +
      coord_equal() +
      theme_impact_mojo()
  })

  # =========================================================================
  # SUMMARY STATISTICS
  # =========================================================================
  output$summary_stats_ui <- renderUI({
    req(data_a())

    build_stat_panel <- function(vals, dist_label) {
      gini <- compute_gini(vals)
      theil <- compute_theil(vals)
      palma <- compute_palma(vals)
      p10 <- quantile(vals, 0.10)
      p50 <- median(vals)
      p90 <- quantile(vals, 0.90)
      p90p10 <- if (p10 > 0) p90 / p10 else NA

      quintile_shares <- compute_income_shares(vals, 5)
      decile_shares <- compute_income_shares(vals, 10)

      fmt <- function(x, d = 4) {
        if (is.na(x)) return("N/A")
        formatC(x, format = "f", digits = d, big.mark = ",")
      }
      fmt_pct <- function(x) paste0(fmt(x, 1), "%")
      fmt_money <- function(x) formatC(x, format = "f", digits = 0, big.mark = ",")

      tagList(
        h4(class = "section-header", dist_label),
        fluidRow(
          column(3, div(class = "stat-card",
            h4("Gini Coefficient"),
            div(class = "stat-value", fmt(gini))
          )),
          column(3, div(class = "stat-card",
            h4("Theil Index"),
            div(class = "stat-value", fmt(theil))
          )),
          column(3, div(class = "stat-card",
            h4("Palma Ratio"),
            div(class = "stat-value", fmt(palma, 2))
          )),
          column(3, div(class = "stat-card",
            h4("P90 / P10 Ratio"),
            div(class = "stat-value", fmt(p90p10, 2))
          ))
        ),
        fluidRow(
          column(3, div(class = "stat-card",
            h4("Mean"),
            div(class = "stat-value", fmt_money(mean(vals)))
          )),
          column(3, div(class = "stat-card",
            h4("Median"),
            div(class = "stat-value", fmt_money(p50))
          )),
          column(3, div(class = "stat-card",
            h4("P10"),
            div(class = "stat-value", fmt_money(p10))
          )),
          column(3, div(class = "stat-card",
            h4("P90"),
            div(class = "stat-value", fmt_money(p90))
          ))
        ),
        fluidRow(
          column(2, div(class = "stat-card",
            h4("N"), div(class = "stat-value", fmt_money(length(vals)))
          )),
          column(2, div(class = "stat-card",
            h4("Min"), div(class = "stat-value", fmt_money(min(vals)))
          )),
          column(2, div(class = "stat-card",
            h4("Max"), div(class = "stat-value", fmt_money(max(vals)))
          )),
          column(3, div(class = "stat-card",
            h4("Std Dev"), div(class = "stat-value", fmt_money(sd(vals)))
          )),
          column(3, div(class = "stat-card",
            h4("Coeff of Variation"),
            div(class = "stat-value", fmt(sd(vals) / mean(vals), 3))
          ))
        ),
        h5(style = "margin-top:16px; font-weight:700; color:#1a1a2e;", "Income Shares by Quintile"),
        fluidRow(
          lapply(seq_len(5), function(i) {
            column(2, div(class = "stat-card",
              h4(paste0("Q", i, " (", (i-1)*20, "-", i*20, "%)")),
              div(class = "stat-value", style = "font-size:20px;", fmt_pct(quintile_shares[i]))
            ))
          })
        ),
        h5(style = "margin-top:16px; font-weight:700; color:#1a1a2e;", "Income Shares by Decile"),
        fluidRow(
          lapply(seq_len(5), function(i) {
            column(2, div(class = "stat-card",
              h4(paste0("D", i)),
              div(class = "stat-value", style = "font-size:18px;", fmt_pct(decile_shares[i]))
            ))
          })
        ),
        fluidRow(
          lapply(6:10, function(i) {
            column(2, div(class = "stat-card",
              h4(paste0("D", i)),
              div(class = "stat-value", style = "font-size:18px;", fmt_pct(decile_shares[i]))
            ))
          })
        )
      )
    }

    panels <- list(build_stat_panel(data_a(), paste("Distribution", label_a())))

    if (input$compare_mode && !is.null(data_b())) {
      panels <- c(panels, list(
        hr(),
        build_stat_panel(data_b(), paste("Distribution", label_b()))
      ))
    }

    do.call(tagList, panels)
  })

  # =========================================================================
  # DISTRIBUTION PLOT
  # =========================================================================
  output$dist_plot <- renderPlot({
    req(data_a())

    df_a <- data.frame(value = data_a(), group = label_a())
    pcts_a <- quantile(data_a(), probs = c(0.10, 0.25, 0.50, 0.75, 0.90))

    if (input$compare_mode && !is.null(data_b())) {
      df_b <- data.frame(value = data_b(), group = label_b())
      df <- rbind(df_a, df_b)

      p <- ggplot(df, aes(x = value, fill = group, color = group)) +
        geom_histogram(aes(y = after_stat(density)),
          bins = 60, alpha = 0.35, position = "identity", linewidth = 0.3
        ) +
        geom_density(linewidth = 1.0, alpha = 0) +
        scale_fill_manual(values = setNames(palette_main, c(label_a(), label_b()))) +
        scale_color_manual(values = setNames(palette_main, c(label_a(), label_b())))
    } else {
      p <- ggplot(df_a, aes(x = value)) +
        geom_histogram(aes(y = after_stat(density)),
          bins = 60, fill = palette_main[1], color = "white", alpha = 0.7, linewidth = 0.2
        ) +
        geom_density(color = palette_main[1], linewidth = 1.1) +
        geom_vline(xintercept = pcts_a, linetype = "dotted", color = "#e63946", linewidth = 0.6) +
        annotate("text",
          x = pcts_a, y = Inf,
          label = paste0(c("P10", "P25", "P50", "P75", "P90"), "\n", formatC(pcts_a, format = "f", digits = 0, big.mark = ",")),
          vjust = 1.5, hjust = -0.1, size = 3.2, color = "#e63946", fontface = "bold"
        )
    }

    p +
      labs(
        title = "Income / Consumption Distribution",
        subtitle = "Histogram with density overlay and percentile markers",
        x = "Income / Consumption Value",
        y = "Density",
        fill = "Distribution",
        color = "Distribution",
        caption = "Impact Mojo | Gini & Lorenz Curve Tool"
      ) +
      theme_impact_mojo()
  })

  # =========================================================================
  # QUANTILE SHARES PLOT
  # =========================================================================
  output$quantile_plot <- renderPlot({
    req(data_a())
    n_q <- as.integer(input$n_quantiles)

    shares_a <- compute_quantile_shares(data_a(), n_q)
    shares_a$group <- label_a()

    if (input$compare_mode && !is.null(data_b())) {
      shares_b <- compute_quantile_shares(data_b(), n_q)
      shares_b$group <- label_b()
      shares <- rbind(shares_a, shares_b)

      p <- ggplot(shares, aes(x = quantile, y = share, fill = group)) +
        geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.85) +
        geom_text(
          aes(label = sprintf("%.1f%%", share)),
          position = position_dodge(width = 0.75), vjust = -0.5, size = 3.3, fontface = "bold"
        ) +
        scale_fill_manual(values = setNames(palette_main, c(label_a(), label_b())))
    } else {
      equal_share <- 100 / n_q
      p <- ggplot(shares_a, aes(x = quantile, y = share)) +
        geom_col(fill = palette_main[1], alpha = 0.8, width = 0.65) +
        geom_hline(yintercept = equal_share, linetype = "dashed", color = "#e63946", linewidth = 0.7) +
        geom_text(
          aes(label = sprintf("%.1f%%", share)),
          vjust = -0.5, size = 3.8, fontface = "bold", color = "#1a1a2e"
        ) +
        annotate("text", x = n_q * 0.85, y = equal_share + 0.8,
                 label = paste0("Equal share = ", sprintf("%.1f%%", equal_share)),
                 color = "#e63946", size = 3.5, fontface = "italic")
    }

    group_label <- switch(as.character(n_q),
      "5" = "Quintile", "10" = "Decile", "20" = "Ventile"
    )

    p +
      labs(
        title = paste("Income Share by", group_label),
        subtitle = paste0("Population divided into ", n_q, " equal-sized groups, ordered from poorest to richest"),
        x = paste(group_label, "Group (poorest to richest)"),
        y = "Share of Total Income (%)",
        fill = "Distribution",
        caption = "Impact Mojo | Gini & Lorenz Curve Tool"
      ) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
      theme_impact_mojo()
  })
}

# =============================================================================
# Run the app
# =============================================================================
shinyApp(ui = ui, server = server)
