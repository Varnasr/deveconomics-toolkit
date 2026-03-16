# Contributing to deveconomics-toolkit

Thank you for your interest in contributing to **deveconomics-toolkit**! This project provides open-source Shiny applications for development economics, built with both R and Python. Whether you are fixing a bug, improving documentation, or adding a new app, your contribution is welcome.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Adding a New Shiny App](#adding-a-new-shiny-app)
- [Code Style Guidelines](#code-style-guidelines)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Getting Started

1. **Fork** the repository and clone your fork locally.
2. Create a new branch for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Set up the development environment for the language you are working with:
   - **R Shiny apps:** Install R (>= 4.0) and the required packages listed in each app's `DESCRIPTION` or at the top of `app.R`.
   - **Python Shiny apps:** Create a virtual environment and install dependencies:
     ```bash
     python -m venv .venv
     source .venv/bin/activate
     pip install -r requirements.txt
     ```

## Project Structure

```
deveconomics-toolkit/
├── r-shiny/              # R Shiny applications (5 apps)
│   ├── rct-simulator/
│   ├── did-estimator/
│   ├── gini-calculator/
│   ├── toc-builder/
│   └── wdi-dashboard/
├── python-shiny/         # Python Shiny applications (6 apps)
│   ├── rdd-analyzer/
│   ├── synthetic-control/
│   ├── mpi-calculator/
│   ├── poverty-lines/
│   ├── cba-tool/
│   └── logframe-designer/
├── docs/                 # Documentation
├── LICENSE               # MIT License
└── README.md
```

Apps are organized into four categories:

| Category | Apps |
|---|---|
| Impact Evaluation | RCT, DiD, RDD, Synthetic Control |
| Poverty & Inequality | Gini, MPI, Poverty Lines |
| Program Design | ToC, CBA, Logframe |
| Data Exploration | WDI Dashboard |

## Adding a New Shiny App

1. **Decide on the language.** Choose R or Python based on what best fits the methodology and available packages.
2. **Create a directory** under `r-shiny/` or `python-shiny/` with a descriptive, kebab-case name (e.g., `propensity-score-matching`).
3. **Include the following files** in your app directory:
   - The app entry point (`app.R` for R, `app.py` for Python).
   - A `README.md` explaining the app, the methodology it implements, and how to run it.
   - A dependency file (`DESCRIPTION` or inline comments for R; `requirements.txt` for Python).
   - Sample data or instructions on where to obtain data, if applicable.
4. **Test your app locally** to confirm it runs without errors.
5. **Update the root `README.md`** to include your new app in the app listing.
6. **Submit a pull request** following the process described below.

## Code Style Guidelines

### R Code Style

- Follow the [tidyverse style guide](https://style.tidyverse.org/).
- Use `library()` calls at the top of the file; avoid `require()`.
- Use the pipe operator (`|>` or `%>%`) for readable data transformations.
- Use `snake_case` for variable and function names.
- Keep reactive expressions focused and well-named.
- Use `shiny::` namespace prefix for Shiny functions when clarity is needed.
- Lint your code with `lintr`:
  ```r
  lintr::lint("app.R")
  ```

### Python Code Style

- Follow [PEP 8](https://peps.python.org/pep-0008/).
- Use `snake_case` for variables and functions, `PascalCase` for classes.
- Use type hints where practical.
- Keep imports organized: standard library, third-party, local (separated by blank lines).
- Lint your code with `flake8`:
  ```bash
  flake8 --max-line-length=120 app.py
  ```
- Format code with `black` (recommended):
  ```bash
  black app.py
  ```

### General Guidelines

- Write clear, descriptive commit messages.
- Add comments explaining non-obvious logic, especially statistical methods.
- Keep UI and server logic well-separated.
- Ensure apps are responsive and work on different screen sizes.
- Do not commit sensitive data, API keys, or credentials.

## Submitting Changes

1. Ensure your app runs locally without errors or warnings.
2. Verify that no sensitive data or credentials are included.
3. Push your branch to your fork and open a pull request against `main`.
4. Fill out the pull request template completely.
5. A maintainer will review your PR. Please be responsive to feedback.

## Reporting Issues

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for bugs.
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) for new ideas.
- Include the app name, language version, and steps to reproduce when reporting bugs.

## Code of Conduct

All contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before participating.

## Questions?

Reach out to the maintainer **@Varnasr** or email **hello@impactmojo.in**.

Thank you for helping make development economics tools accessible to everyone!
