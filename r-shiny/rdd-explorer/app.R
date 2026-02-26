###############################################################################
# Regression Discontinuity Explorer - Impact Mojo
# A self-contained Shiny application for exploring Sharp and Fuzzy RDD
###############################################################################

library(shiny)
library(ggplot2)
library(dplyr)

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

#' Generate synthetic RDD data
generate_rdd_data <- function(n, x_min, x_max, cutoff, tau, noise_sd,
                              design, compliance_rate, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  x <- runif(n, x_min, x_max)

  # Potential outcomes: smooth functions on each side of the cutoff
  # y0 = baseline outcome (control potential outcome)
  # y1 = treated potential outcome (y0 + tau)
  mu0 <- 2 + 0.8 * x + 0.3 * x^2  # smooth baseline

  assigned <- as.integer(x >= cutoff)


  if (design == "Sharp") {
    treated <- assigned
  } else {
    # Fuzzy: compliance is imperfect
    # Those assigned to treatment comply with probability = compliance_rate
    # Those not assigned never receive treatment (one-sided non-compliance)
    treated <- ifelse(
      assigned == 1,
      rbinom(sum(assigned), 1, compliance_rate),
      0L
    )
    # Ensure treated is full-length vector aligned with x
    treated_full <- integer(n)
    treated_full[assigned == 1] <- treated
    treated <- treated_full
  }

  y <- mu0 + tau * treated + rnorm(n, 0, noise_sd)

  data.frame(
    x        = x,
    y        = y,
    assigned = assigned,
    treated  = treated
  )
}

#' Kernel weight function
kernel_weight <- function(u, kernel_type) {
  u_abs <- abs(u)
  switch(kernel_type,
    "Uniform"       = ifelse(u_abs <= 1, 1, 0),
    "Triangular"    = ifelse(u_abs <= 1, 1 - u_abs, 0),
    "Epanechnikov"  = ifelse(u_abs <= 1, 0.75 * (1 - u^2), 0),
    ifelse(u_abs <= 1, 1, 0)
  )
}

#' Local polynomial regression estimate (sharp RDD)
#' Returns list(est, se, ci_lo, ci_hi, n_eff)
local_poly_estimate <- function(dat, cutoff, bw, poly_order, kernel_type) {
  in_bw <- dat$x >= (cutoff - bw) & dat$x <= (cutoff + bw)
  d_bw  <- dat[in_bw, ]

  if (nrow(d_bw) < 2 * (poly_order + 1) + 2) {
    return(list(est = NA, se = NA, ci_lo = NA, ci_hi = NA, n_eff = nrow(d_bw)))
  }

  xc <- d_bw$x - cutoff
  w  <- kernel_weight(xc / bw, kernel_type)

  D <- as.integer(d_bw$x >= cutoff)

  # Build design matrix: intercept, D, xc, D*xc, xc^2, D*xc^2, ...
  X <- cbind(1, D, xc, D * xc)
  if (poly_order >= 2) {
    for (p in 2:poly_order) {
      X <- cbind(X, xc^p, D * xc^p)
    }
  }

  tryCatch({
    fit <- lm.wfit(X, d_bw$y, w = w)
    # Coefficient on D is the treatment effect estimate
    beta <- fit$coefficients
    # Heteroskedasticity-robust variance (HC1)
    e   <- fit$residuals
    n_e <- length(e)
    k   <- ncol(X)
    # Bread
    XtWX_inv <- solve(crossprod(X * sqrt(w)))
    # Meat
    meat <- crossprod(X * (w * e))
    V <- (n_e / (n_e - k)) * XtWX_inv %*% meat %*% XtWX_inv
    se <- sqrt(V[2, 2])
    est <- beta[2]
    list(
      est   = est,
      se    = se,
      ci_lo = est - 1.96 * se,
      ci_hi = est + 1.96 * se,
      n_eff = sum(w > 0)
    )
  }, error = function(e) {
    list(est = NA, se = NA, ci_lo = NA, ci_hi = NA, n_eff = sum(w > 0))
  })
}

#' Fuzzy RDD estimate via 2SLS (Wald estimator within bandwidth)
fuzzy_2sls_estimate <- function(dat, cutoff, bw, poly_order, kernel_type) {
  in_bw <- dat$x >= (cutoff - bw) & dat$x <= (cutoff + bw)
  d_bw  <- dat[in_bw, ]

  if (nrow(d_bw) < 2 * (poly_order + 1) + 2) {
    return(list(est = NA, se = NA, ci_lo = NA, ci_hi = NA, n_eff = nrow(d_bw)))
  }

  xc <- d_bw$x - cutoff
  w  <- kernel_weight(xc / bw, kernel_type)
  Z  <- as.integer(d_bw$x >= cutoff)  # instrument: assignment
  D  <- d_bw$treated                   # endogenous: actual treatment

  # Build exogenous covariates (polynomials of xc, interacted with Z)
  W_mat <- cbind(xc)
  if (poly_order >= 2) {
    for (p in 2:poly_order) W_mat <- cbind(W_mat, xc^p)
  }
  # Interactions
  ZW <- Z * W_mat

  # --- First stage: D on Z, W, Z*W ---
  X_fs <- cbind(1, Z, W_mat, ZW)

  tryCatch({
    fs_fit <- lm.wfit(X_fs, D, w = w)
    D_hat  <- fs_fit$fitted.values

    # --- Second stage: Y on D_hat, W, Z*W ---
    X_ss <- cbind(1, D_hat, W_mat, ZW)
    ss_fit <- lm.wfit(X_ss, d_bw$y, w = w)
    est <- ss_fit$coefficients[2]

    # Correct SE: use original D in residuals
    X_ss_orig <- cbind(1, D, W_mat, ZW)
    ss_orig   <- lm.wfit(X_ss_orig, d_bw$y, w = w)
    e <- d_bw$y - X_ss_orig %*% ss_fit$coefficients
    n_e <- length(e)
    k   <- ncol(X_ss)
    XtWX_inv <- solve(crossprod(X_ss * sqrt(w)))
    meat <- crossprod(X_ss * (w * as.vector(e)))
    V <- (n_e / (n_e - k)) * XtWX_inv %*% meat %*% XtWX_inv
    se <- sqrt(V[2, 2])

    list(
      est   = est,
      se    = se,
      ci_lo = est - 1.96 * se,
      ci_hi = est + 1.96 * se,
      n_eff = sum(w > 0)
    )
  }, error = function(e) {
    list(est = NA, se = NA, ci_lo = NA, ci_hi = NA, n_eff = sum(w > 0))
  })
}

#' Naive OLS estimate (no bandwidth restriction)
naive_ols_estimate <- function(dat, cutoff) {
  D <- as.integer(dat$x >= cutoff)
  xc <- dat$x - cutoff
  tryCatch({
    fit <- lm(dat$y ~ D + xc + D:xc)
    s   <- summary(fit)
    est <- coef(fit)["D"]
    se  <- s$coefficients["D", "Std. Error"]
    list(
      est   = est,
      se    = se,
      ci_lo = est - 1.96 * se,
      ci_hi = est + 1.96 * se,
      n_eff = nrow(dat)
    )
  }, error = function(e) {
    list(est = NA, se = NA, ci_lo = NA, ci_hi = NA, n_eff = nrow(dat))
  })
}

# ---------------------------------------------------------------------------
# Theme for plots
# ---------------------------------------------------------------------------
theme_impact_mojo <- function() {
  theme_minimal(base_size = 14) +
    theme(
      plot.title       = element_text(face = "bold", size = 16, hjust = 0),
      plot.subtitle    = element_text(size = 12, color = "grey40", hjust = 0),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey90"),
      legend.position  = "bottom",
      legend.title     = element_text(face = "bold"),
      axis.title       = element_text(face = "bold"),
      strip.text       = element_text(face = "bold")
    )
}

# Colour palette
col_control   <- "#2C7BB6"
col_treated   <- "#D7191C"
col_bandwidth <- "#FDAE61"
col_cutoff    <- "grey30"

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
      .app-title {
        font-size: 24px; font-weight: 700; color: #2C3E50;
        padding: 15px 0 5px 0; margin: 0;
      }
      .app-subtitle {
        font-size: 13px; color: #7f8c8d; margin: 0 0 15px 0;
      }
      .well { background-color: #f8f9fa; border: 1px solid #dee2e6; }
      .estimate-card {
        background: #ffffff; border: 1px solid #dee2e6;
        border-radius: 8px; padding: 18px; margin-bottom: 14px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
      }
      .estimate-card h4 { margin-top: 0; color: #2C3E50; }
      .estimate-value { font-size: 28px; font-weight: 700; color: #2C7BB6; }
      .estimate-detail { font-size: 13px; color: #7f8c8d; margin-top: 4px; }
      .about-section h3 { color: #2C3E50; }
      .about-section p, .about-section li { line-height: 1.7; color: #34495e; }
      .nav-tabs > li > a { color: #2C3E50; }
    "))
  ),

  div(class = "app-title", "Regression Discontinuity Explorer"),
  div(class = "app-subtitle", "Impact Mojo \u2014 Causal Inference for Development Economics"),

  sidebarLayout(
    # --- Sidebar ---
    sidebarPanel(
      width = 3,
      h4("Data Generation"),
      fluidRow(
        column(6, numericInput("x_min", "X Min", value = -5, step = 1)),
        column(6, numericInput("x_max", "X Max", value = 5, step = 1))
      ),
      numericInput("cutoff", "Cutoff Value", value = 0, step = 0.5),
      numericInput("tau", "True Treatment Effect", value = 3.0, step = 0.5),
      sliderInput("n", "Sample Size", min = 50, max = 2000,
                  value = 500, step = 50),
      sliderInput("noise_sd", "Noise SD", min = 0.1, max = 5.0,
                  value = 1.5, step = 0.1),
      actionButton("resample", "Re-draw Sample",
                   class = "btn-primary btn-block",
                   style = "margin-bottom:15px;"),
      hr(),

      h4("Estimation Settings"),
      sliderInput("poly_order", "Polynomial Order", min = 1, max = 4,
                  value = 1, step = 1),
      sliderInput("bandwidth", "Bandwidth", min = 0.5, max = 5.0,
                  value = 2.0, step = 0.1),
      selectInput("kernel", "Kernel",
                  choices = c("Uniform", "Triangular", "Epanechnikov"),
                  selected = "Triangular"),
      hr(),

      h4("Design Type"),
      radioButtons("design", NULL,
                   choices = c("Sharp", "Fuzzy"), selected = "Sharp"),
      conditionalPanel(
        condition = "input.design == 'Fuzzy'",
        sliderInput("compliance", "Compliance Rate",
                    min = 0.3, max = 1.0, value = 0.7, step = 0.05)
      )
    ),

    # --- Main panel ---
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs", type = "tabs",

        # Tab 1: RD Plot
        tabPanel(
          "RD Plot",
          br(),
          plotOutput("rd_plot", height = "520px"),
          div(style = "text-align:center; color:#7f8c8d; font-size:12px;",
              textOutput("plot_caption"))
        ),

        # Tab 2: Estimates
        tabPanel(
          "Estimates",
          br(),
          fluidRow(
            column(4, uiOutput("card_local")),
            column(4, uiOutput("card_ols")),
            column(4, uiOutput("card_fuzzy"))
          ),
          hr(),
          h4("Estimation Summary"),
          tableOutput("est_table")
        ),

        # Tab 3: McCrary Test
        tabPanel(
          "McCrary Test",
          br(),
          plotOutput("mccrary_plot", height = "480px"),
          div(style = "padding:10px; color:#34495e;",
              htmlOutput("mccrary_text"))
        ),

        # Tab 4: Sensitivity
        tabPanel(
          "Sensitivity",
          br(),
          plotOutput("sensitivity_plot", height = "500px"),
          div(style = "text-align:center; color:#7f8c8d; font-size:12px;",
              "Each point is the local polynomial estimate at the given bandwidth. ",
              "The shaded region shows the 95% confidence interval. ",
              "The dashed horizontal line marks the true treatment effect.")
        ),

        # Tab 5: About
        tabPanel(
          "About",
          br(),
          div(
            class = "about-section",
            style = "max-width: 800px;",

            h3("Regression Discontinuity Design (RDD)"),
            p("Regression Discontinuity Design is one of the most credible",
              "quasi-experimental methods for causal inference. It exploits",
              "a known rule that assigns treatment based on whether an",
              "observed ", em("running variable"), " (also called the",
              "forcing variable or score) crosses a fixed cutoff."),

            h3("Sharp vs. Fuzzy Designs"),
            tags$ul(
              tags$li(
                strong("Sharp RDD:"),
                "Treatment status is a deterministic function of the",
                "running variable. Everyone above the cutoff is treated;",
                "everyone below is not. The estimand is the Average",
                "Treatment Effect at the cutoff."
              ),
              tags$li(
                strong("Fuzzy RDD:"),
                "Crossing the cutoff increases the", em("probability"),
                "of treatment but does not guarantee it (imperfect",
                "compliance). The assignment indicator serves as an",
                "instrument for actual treatment, and the Local Average",
                "Treatment Effect (LATE) at the cutoff is estimated via",
                "instrumental variables / 2SLS."
              )
            ),

            h3("Key Assumptions"),
            tags$ol(
              tags$li(
                strong("Continuity of potential outcomes:"),
                "The conditional expectation functions of the potential",
                "outcomes are continuous at the cutoff. This means that",
                "in the absence of treatment, outcomes would evolve",
                "smoothly through the cutoff."
              ),
              tags$li(
                strong("No precise manipulation of the running variable:"),
                "Units cannot precisely sort themselves to one side of",
                "the cutoff. This is often assessed with the McCrary",
                "(2008) density test, which checks whether the density",
                "of the running variable is continuous at the cutoff."
              ),
              tags$li(
                strong("Local randomization (heuristic):"),
                "Near the cutoff, assignment is", em("as good as random"),
                "because individuals just above and just below are",
                "comparable on both observed and unobserved",
                "characteristics."
              )
            ),

            h3("Estimation in This App"),
            p("The app implements local polynomial regression within a",
              "symmetric bandwidth around the cutoff. Observations are",
              "weighted using the selected kernel function.",
              "Heteroskedasticity-robust (HC1) standard errors are",
              "reported. For fuzzy designs, a two-stage least squares",
              "(2SLS) estimator is used with assignment as the instrument",
              "for actual treatment."),
            p("The sensitivity tab shows how the point estimate and",
              "confidence interval change as the bandwidth varies,",
              "providing a visual diagnostic for bandwidth sensitivity."),

            h3("References"),
            tags$ul(
              tags$li("Imbens, G. W., & Lemieux, T. (2008).",
                      em("Regression discontinuity designs: A guide to practice."),
                      "Journal of Econometrics, 142(2), 615\u2013635."),
              tags$li("Lee, D. S., & Lemieux, T. (2010).",
                      em("Regression discontinuity designs in economics."),
                      "Journal of Economic Literature, 48(2), 281\u2013355."),
              tags$li("McCrary, J. (2008).",
                      em("Manipulation of the running variable in the",
                         "regression discontinuity design: A density test."),
                      "Journal of Econometrics, 142(2), 698\u2013714."),
              tags$li("Cattaneo, M. D., Idrobo, N., & Titiunik, R. (2020).",
                      em("A Practical Introduction to Regression Discontinuity",
                         "Designs: Foundations."),
                      "Cambridge University Press.")
            ),

            hr(),
            p(style = "color:#95a5a6; font-size:12px;",
              "Impact Mojo \u2014 Interactive tools for learning causal",
              "inference in development economics.")
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

  # Reactive seed that changes on resample
  rv <- reactiveValues(seed = 42)
  observeEvent(input$resample, {
    rv$seed <- sample.int(1e6, 1)
  })

  # --- Reactive data ---
  sim_data <- reactive({
    generate_rdd_data(
      n               = input$n,
      x_min           = input$x_min,
      x_max           = input$x_max,
      cutoff          = input$cutoff,
      tau             = input$tau,
      noise_sd        = input$noise_sd,
      design          = input$design,
      compliance_rate = if (input$design == "Fuzzy") input$compliance else 1,
      seed            = rv$seed
    )
  })

  # --- Estimates ---
  est_local <- reactive({
    local_poly_estimate(sim_data(), input$cutoff, input$bandwidth,
                        input$poly_order, input$kernel)
  })

  est_ols <- reactive({
    naive_ols_estimate(sim_data(), input$cutoff)
  })

  est_fuzzy <- reactive({
    req(input$design == "Fuzzy")
    fuzzy_2sls_estimate(sim_data(), input$cutoff, input$bandwidth,
                        input$poly_order, input$kernel)
  })

  # -----------------------------------------------------------------------
  # Tab 1: RD Plot
  # -----------------------------------------------------------------------
  output$rd_plot <- renderPlot({
    dat <- sim_data()
    c0  <- input$cutoff
    bw  <- input$bandwidth
    po  <- input$poly_order

    dat$side <- ifelse(dat$x >= c0, "Above cutoff", "Below cutoff")
    dat$in_bw <- dat$x >= (c0 - bw) & dat$x <= (c0 + bw)

    # Fitted lines within bandwidth on each side
    dat_left  <- dat %>% filter(x < c0, in_bw)
    dat_right <- dat %>% filter(x >= c0, in_bw)

    # Generate prediction grids
    make_pred <- function(d, side_label) {
      if (nrow(d) < po + 1) return(NULL)
      xc <- d$x - c0
      fit <- lm(d$y ~ poly(xc, po, raw = TRUE))
      grid_xc <- seq(min(xc), max(xc), length.out = 200)
      pred <- predict(fit, newdata = data.frame(xc = grid_xc),
                      interval = "confidence")
      data.frame(
        x    = grid_xc + c0,
        yhat = pred[, "fit"],
        lo   = pred[, "lwr"],
        hi   = pred[, "upr"],
        side = side_label
      )
    }

    pred_left  <- make_pred(dat_left, "Below cutoff")
    pred_right <- make_pred(dat_right, "Above cutoff")
    pred_all   <- bind_rows(pred_left, pred_right)

    # Base plot
    p <- ggplot(dat, aes(x = x, y = y)) +
      # Bandwidth shading
      annotate("rect",
               xmin = c0 - bw, xmax = c0 + bw,
               ymin = -Inf, ymax = Inf,
               fill = col_bandwidth, alpha = 0.10) +
      # Points
      geom_point(aes(color = side, alpha = in_bw), size = 1.6, shape = 16) +
      scale_alpha_manual(values = c("TRUE" = 0.8, "FALSE" = 0.2), guide = "none") +
      scale_color_manual(
        values = c("Below cutoff" = col_control, "Above cutoff" = col_treated),
        name = "Treatment Status"
      )

    # Fitted lines + CI ribbon
    if (!is.null(pred_all) && nrow(pred_all) > 0) {
      p <- p +
        geom_ribbon(data = pred_all, aes(x = x, ymin = lo, ymax = hi, fill = side),
                    alpha = 0.18, inherit.aes = FALSE) +
        geom_line(data = pred_all, aes(x = x, y = yhat, color = side),
                  linewidth = 1.2, inherit.aes = FALSE) +
        scale_fill_manual(
          values = c("Below cutoff" = col_control, "Above cutoff" = col_treated),
          guide = "none"
        )
    }

    # Cutoff line
    p <- p +
      geom_vline(xintercept = c0, linetype = "dashed", color = col_cutoff,
                 linewidth = 0.7) +
      annotate("text", x = c0, y = Inf, label = paste("Cutoff =", c0),
               vjust = 2, hjust = -0.1, size = 4, color = col_cutoff,
               fontface = "italic") +
      # Bandwidth annotation
      annotate("segment",
               x = c0 - bw, xend = c0 + bw,
               y = min(dat$y) - 0.5, yend = min(dat$y) - 0.5,
               color = col_bandwidth, linewidth = 1,
               arrow = arrow(ends = "both", length = unit(0.08, "inches"))) +
      annotate("text",
               x = c0, y = min(dat$y) - 0.5,
               label = paste0("BW = ", bw),
               vjust = 1.6, size = 3.5, color = "grey40") +
      labs(
        title    = "Regression Discontinuity Plot",
        subtitle = paste0(input$design, " design | Poly order: ", po,
                          " | Kernel: ", input$kernel),
        x = "Running Variable (X)",
        y = "Outcome (Y)"
      ) +
      theme_impact_mojo()

    p
  })

  output$plot_caption <- renderText({
    paste0("Points within the bandwidth (highlighted region) are used for ",
           "estimation. Fitted polynomial of order ", input$poly_order,
           " shown on each side of the cutoff.")
  })

  # -----------------------------------------------------------------------
  # Tab 2: Estimates
  # -----------------------------------------------------------------------

  # Helper to build an estimate card
  make_card <- function(title, est_list, note = "") {
    if (is.null(est_list) || is.na(est_list$est)) {
      return(div(class = "estimate-card",
                 h4(title),
                 p("Estimate not available", style = "color:#e74c3c;")))
    }
    div(
      class = "estimate-card",
      h4(title),
      div(class = "estimate-value", sprintf("%.3f", est_list$est)),
      div(class = "estimate-detail",
          sprintf("SE: %.3f", est_list$se)),
      div(class = "estimate-detail",
          sprintf("95%% CI: [%.3f, %.3f]", est_list$ci_lo, est_list$ci_hi)),
      div(class = "estimate-detail",
          sprintf("Effective N: %d", est_list$n_eff)),
      if (nchar(note) > 0) div(class = "estimate-detail",
                                style = "margin-top:6px; font-style:italic;",
                                note)
    )
  }

  output$card_local <- renderUI({
    make_card("Local Polynomial (Sharp)", est_local(),
              paste0("Bandwidth: ", input$bandwidth,
                     " | Kernel: ", input$kernel,
                     " | Poly: ", input$poly_order))
  })

  output$card_ols <- renderUI({
    make_card("Naive OLS (Full Sample)", est_ols(),
              "Linear regression on full data with treatment dummy")
  })

  output$card_fuzzy <- renderUI({
    if (input$design == "Sharp") {
      div(class = "estimate-card",
          h4("Fuzzy 2SLS"),
          p("Switch to Fuzzy design to see the 2SLS estimate.",
            style = "color:#95a5a6; font-style:italic;"))
    } else {
      make_card("Fuzzy 2SLS (IV)", est_fuzzy(),
                paste0("Instrument: assignment indicator | Compliance: ",
                       input$compliance))
    }
  })

  output$est_table <- renderTable({
    rows <- list()

    loc <- est_local()
    rows[[1]] <- data.frame(
      Method    = "Local Polynomial",
      Estimate  = loc$est,
      `Std Err` = loc$se,
      `CI Lower` = loc$ci_lo,
      `CI Upper` = loc$ci_hi,
      `Eff. N`  = as.integer(loc$n_eff),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    ols <- est_ols()
    rows[[2]] <- data.frame(
      Method    = "Naive OLS",
      Estimate  = ols$est,
      `Std Err` = ols$se,
      `CI Lower` = ols$ci_lo,
      `CI Upper` = ols$ci_hi,
      `Eff. N`  = as.integer(ols$n_eff),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    if (input$design == "Fuzzy") {
      fz <- est_fuzzy()
      rows[[3]] <- data.frame(
        Method    = "Fuzzy 2SLS",
        Estimate  = fz$est,
        `Std Err` = fz$se,
        `CI Lower` = fz$ci_lo,
        `CI Upper` = fz$ci_hi,
        `Eff. N`  = as.integer(fz$n_eff),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    }

    truth <- data.frame(
      Method    = "True Effect",
      Estimate  = input$tau,
      `Std Err` = NA_real_,
      `CI Lower` = NA_real_,
      `CI Upper` = NA_real_,
      `Eff. N`  = NA_integer_,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )

    bind_rows(rows, truth)
  }, digits = 3, na = "\u2014", striped = TRUE, hover = TRUE, bordered = TRUE,
  width = "100%")

  # -----------------------------------------------------------------------
  # Tab 3: McCrary density test
  # -----------------------------------------------------------------------
  output$mccrary_plot <- renderPlot({
    dat <- sim_data()
    c0  <- input$cutoff
    bw  <- input$bandwidth

    # Use a fine binwidth for the histogram
    bin_width <- (input$x_max - input$x_min) / 40

    dat$side <- ifelse(dat$x >= c0, "Above cutoff", "Below cutoff")

    ggplot(dat, aes(x = x)) +
      geom_histogram(aes(y = after_stat(density), fill = side),
                     binwidth = bin_width, color = "white",
                     boundary = c0, alpha = 0.65) +
      geom_density(aes(color = side), linewidth = 1, adjust = 1.2) +
      geom_vline(xintercept = c0, linetype = "dashed", color = col_cutoff,
                 linewidth = 0.8) +
      scale_fill_manual(
        values = c("Below cutoff" = col_control, "Above cutoff" = col_treated),
        name = ""
      ) +
      scale_color_manual(
        values = c("Below cutoff" = col_control, "Above cutoff" = col_treated),
        guide = "none"
      ) +
      labs(
        title    = "McCrary Density Test",
        subtitle = "Is there evidence of manipulation at the cutoff?",
        x = "Running Variable (X)",
        y = "Density"
      ) +
      theme_impact_mojo()
  })

  output$mccrary_text <- renderUI({
    dat <- sim_data()
    c0  <- input$cutoff

    n_below <- sum(dat$x < c0)
    n_above <- sum(dat$x >= c0)
    ratio   <- n_above / max(n_below, 1)

    HTML(paste0(
      "<p><strong>Observations below cutoff:</strong> ", n_below,
      " &nbsp;|&nbsp; <strong>Above cutoff:</strong> ", n_above,
      " &nbsp;|&nbsp; <strong>Ratio (above/below):</strong> ",
      sprintf("%.2f", ratio), "</p>",
      "<p style='color:#7f8c8d;'>A key identifying assumption of RDD is that ",
      "individuals cannot precisely manipulate the running variable to sort ",
      "themselves across the cutoff. A discontinuity in the density at the ",
      "cutoff would raise concerns about this assumption. Because this app ",
      "generates data from a uniform distribution, no manipulation is ",
      "present by construction. In real applications, formal tests ",
      "(McCrary, 2008; Cattaneo, Jansson & Ma, 2020) should be applied.</p>"
    ))
  })

  # -----------------------------------------------------------------------
  # Tab 4: Sensitivity to bandwidth
  # -----------------------------------------------------------------------
  output$sensitivity_plot <- renderPlot({
    dat <- sim_data()
    c0  <- input$cutoff
    po  <- input$poly_order
    kern <- input$kernel
    design <- input$design

    bw_grid <- seq(0.5, 5.0, by = 0.15)
    results <- lapply(bw_grid, function(b) {
      if (design == "Sharp") {
        r <- local_poly_estimate(dat, c0, b, po, kern)
      } else {
        r <- fuzzy_2sls_estimate(dat, c0, b, po, kern)
      }
      data.frame(bw = b, est = r$est, se = r$se,
                 ci_lo = r$ci_lo, ci_hi = r$ci_hi,
                 n_eff = r$n_eff, stringsAsFactors = FALSE)
    })
    sens_df <- bind_rows(results)
    sens_df <- sens_df[!is.na(sens_df$est), ]

    if (nrow(sens_df) == 0) {
      return(ggplot() +
               annotate("text", x = 0.5, y = 0.5,
                        label = "No valid estimates across bandwidth grid",
                        size = 6) +
               theme_void())
    }

    ggplot(sens_df, aes(x = bw, y = est)) +
      geom_hline(yintercept = input$tau, linetype = "dashed",
                 color = col_treated, linewidth = 0.6) +
      geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi),
                  fill = col_control, alpha = 0.18) +
      geom_line(color = col_control, linewidth = 1) +
      geom_point(color = col_control, size = 2) +
      geom_vline(xintercept = input$bandwidth, linetype = "dotted",
                 color = "grey50", linewidth = 0.6) +
      annotate("text", x = input$bandwidth, y = max(sens_df$ci_hi, na.rm = TRUE),
               label = paste0("Selected BW = ", input$bandwidth),
               vjust = -0.5, hjust = -0.05, size = 3.5, color = "grey40",
               fontface = "italic") +
      annotate("text",
               x = max(bw_grid) - 0.3,
               y = input$tau,
               label = paste0("True effect = ", input$tau),
               vjust = -1, hjust = 1, size = 3.5, color = col_treated,
               fontface = "italic") +
      labs(
        title    = "Sensitivity of Treatment Effect to Bandwidth Choice",
        subtitle = paste0(design, " RDD | Polynomial order: ", po,
                          " | Kernel: ", kern),
        x = "Bandwidth",
        y = "Estimated Treatment Effect"
      ) +
      theme_impact_mojo()
  })
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
shinyApp(ui = ui, server = server)
