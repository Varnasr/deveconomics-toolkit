# deveconomics-toolkit

**Interactive Shiny apps for development economics, impact evaluation, and the international development sector.**

A suite of 11 open-source tools built with R Shiny and Python Shiny — designed for researchers, practitioners, and students working in global development. Created for [Impact Mojo](https://impactmojo.com).

---

## The Apps

### Impact Evaluation & Econometrics

| App | Framework | What it does |
|-----|-----------|--------------|
| [RCT Power Calculator](python-shiny/rct-power-calculator/) | Python Shiny | Compute sample size, statistical power, and MDE for randomized controlled trials. Supports cluster randomization and multiple treatment arms. |
| [DiD Simulator](python-shiny/did-simulator/) | Python Shiny | Simulate difference-in-differences designs with OLS regression output, event-study plots, and parallel trends violation detection. |
| [RDD Explorer](r-shiny/rdd-explorer/) | R Shiny | Explore sharp and fuzzy regression discontinuity designs with local polynomial estimation, McCrary manipulation tests, and bandwidth sensitivity. |
| [Synthetic Control Visualizer](python-shiny/synthetic-control/) | Python Shiny | Visualize the synthetic control method with constrained optimization, in-space placebo tests, and pre-treatment fit diagnostics. |

### Poverty & Inequality

| App | Framework | What it does |
|-----|-----------|--------------|
| [Gini & Lorenz Curve Tool](r-shiny/gini-lorenz/) | R Shiny | Calculate Gini, Theil, and Palma ratio from generated or user-supplied data. Compare distributions side by side with interactive Lorenz curves. |
| [MPI Explorer](python-shiny/mpi-explorer/) | Python Shiny | Explore the Multidimensional Poverty Index using the Alkire-Foster method. Radar charts, decomposition by dimension, and sensitivity to the poverty cutoff. |
| [Poverty Line Analysis](r-shiny/poverty-line-analysis/) | R Shiny | Compute FGT(0/1/2) and Watts indices against World Bank poverty lines ($2.15, $3.65, $6.85). Simulate growth and redistribution scenarios. |

### Program Design & Management

| App | Framework | What it does |
|-----|-----------|--------------|
| [Theory of Change Visualizer](python-shiny/theory-of-change/) | Python Shiny | Build interactive ToC diagrams with sector templates (Education, Health, Livelihoods, WASH). Auto-generates narrative descriptions and exportable summaries. |
| [Cost-Benefit Analysis Tool](python-shiny/cost-benefit-analysis/) | Python Shiny | Calculate NPV, BCR, and IRR with tornado diagrams, Monte Carlo simulation, and a cost-effectiveness tab benchmarked against GiveWell thresholds. |
| [LogFrame Builder](r-shiny/logframe-builder/) | R Shiny | Build logical frameworks with editable matrices, indicator tracking with progress bars, results chain visualization, and HTML/CSV export. 6 sector templates. |

### Data Exploration

| App | Framework | What it does |
|-----|-----------|--------------|
| [WDI Dashboard](r-shiny/wdi-dashboard/) | R Shiny | Explore 15 development indicators across 50 countries and 6 regions. Time series, cross-country comparisons, scatter plots, and downloadable data tables. |

---

## Quick Start

### Python Shiny apps

```bash
# Pick any Python app
cd python-shiny/rct-power-calculator

# Create a virtual environment (recommended)
python -m venv .venv
source .venv/bin/activate   # Linux/Mac
# .venv\Scripts\activate    # Windows

# Install dependencies and run
pip install -r requirements.txt
shiny run app.py
```

The app will be available at `http://127.0.0.1:8000`.

### R Shiny apps

```r
# From R or RStudio — pick any R app
shiny::runApp("r-shiny/rdd-explorer")
```

Or from the command line:

```bash
cd r-shiny/rdd-explorer
Rscript -e "shiny::runApp('.')"
```

The app will be available at `http://127.0.0.1:3838` (or the port R assigns).

### R dependencies

All R apps use standard CRAN packages. Install them once:

```r
install.packages(c("shiny", "ggplot2", "dplyr", "tidyr", "DT"))
```

---

## Project Structure

```
deveconomics-toolkit/
├── README.md
├── LICENSE
├── .gitignore
│
├── python-shiny/
│   ├── rct-power-calculator/
│   │   ├── app.py
│   │   └── requirements.txt
│   ├── did-simulator/
│   │   ├── app.py
│   │   └── requirements.txt
│   ├── mpi-explorer/
│   │   ├── app.py
│   │   └── requirements.txt
│   ├── theory-of-change/
│   │   ├── app.py
│   │   └── requirements.txt
│   ├── cost-benefit-analysis/
│   │   ├── app.py
│   │   └── requirements.txt
│   └── synthetic-control/
│       ├── app.py
│       └── requirements.txt
│
└── r-shiny/
    ├── rdd-explorer/
    │   └── app.R
    ├── gini-lorenz/
    │   └── app.R
    ├── poverty-line-analysis/
    │   └── app.R
    ├── logframe-builder/
    │   └── app.R
    └── wdi-dashboard/
        └── app.R
```

---

## Deployment Options

Each app is self-contained and can be deployed independently:

| Platform | Best for | Guide |
|----------|----------|-------|
| **shinyapps.io** | R apps — free tier available | `rsconnect::deployApp("r-shiny/rdd-explorer")` |
| **Hugging Face Spaces** | Python apps — free GPU/CPU | Create a Space with the Gradio/Docker SDK and point to the app |
| **Shinylive** | Python apps — runs entirely in the browser via WebAssembly | `shinylive export app.py site/` |
| **Posit Connect** | Enterprise deployment for both R and Python | Follow Posit Connect docs |
| **Docker** | Any app — portable containers | See Dockerfiles (coming soon) |
| **Your website** | Embed any deployed app via `<iframe>` | `<iframe src="https://your-app-url" width="100%" height="800px"></iframe>` |

---

## Tech Stack

- **Python Shiny** (6 apps) — `shiny`, `numpy`, `scipy`, `matplotlib`, `pandas`, `statsmodels`
- **R Shiny** (5 apps) — `shiny`, `ggplot2`, `dplyr`, `tidyr`, `DT`
- All apps generate synthetic data for demonstration — no external API calls or datasets required

---

## Key References

These apps implement methods from the development economics canon:

- Angrist, J. & Pischke, J. (2009). *Mostly Harmless Econometrics*
- Duflo, E., Glennerster, R. & Kremer, M. (2007). Using Randomization in Development Economics Research
- Abadie, A., Diamond, A. & Hainmueller, J. (2010). Synthetic Control Methods
- Imbens, G. & Lemieux, T. (2008). Regression Discontinuity Designs
- Alkire, S. & Foster, J. (2011). Counting and Multidimensional Poverty Measurement
- Foster, J., Greer, J. & Thorbecke, E. (1984). A Class of Decomposable Poverty Measures
- Card, D. & Krueger, A. (1994). Minimum Wages and Employment

---

## Contributing

Contributions are welcome! If you'd like to add a new app or improve an existing one:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-app`)
3. Add your app in the appropriate directory (`python-shiny/` or `r-shiny/`)
4. Include a `requirements.txt` (Python) or document R dependencies
5. Submit a pull request

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

Built with care for the global development community.
