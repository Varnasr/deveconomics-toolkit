"""
MPI Explorer — Impact Mojo
===========================
A Multidimensional Poverty Index (MPI) Explorer for development economics.

Implements the Alkire-Foster method used by UNDP/OPHI to compute the global MPI.
Generates synthetic household-level data with realistic correlated deprivation
patterns across 10 indicators in 3 dimensions (Health, Education, Living Standards).

Part of the Impact Mojo portfolio.
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.patches import FancyBboxPatch
from shiny import App, Inputs, Outputs, Session, reactive, render, ui

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DIMENSIONS = {
    "Health": ["Nutrition", "Child mortality"],
    "Education": ["Years of schooling", "School attendance"],
    "Living Standards": [
        "Cooking fuel",
        "Sanitation",
        "Drinking water",
        "Electricity",
        "Housing",
        "Assets",
    ],
}

INDICATORS = []
INDICATOR_DIMENSION = {}
for dim, inds in DIMENSIONS.items():
    for ind in inds:
        INDICATORS.append(ind)
        INDICATOR_DIMENSION[ind] = dim

# Standard equal-nested weights (each dimension = 1/3)
EQUAL_WEIGHTS = {}
for dim, inds in DIMENSIONS.items():
    w = (1.0 / 3.0) / len(inds)
    for ind in inds:
        EQUAL_WEIGHTS[ind] = w

# Dimension colours
DIM_COLORS = {
    "Health": "#E74C3C",
    "Education": "#2E86C1",
    "Living Standards": "#27AE60",
}

INDICATOR_COLORS = {
    "Nutrition": "#E74C3C",
    "Child mortality": "#C0392B",
    "Years of schooling": "#2E86C1",
    "School attendance": "#2471A3",
    "Cooking fuel": "#27AE60",
    "Sanitation": "#229954",
    "Drinking water": "#1E8449",
    "Electricity": "#196F3D",
    "Housing": "#117A65",
    "Assets": "#0E6655",
}

# Realistic baseline deprivation probabilities (loosely based on global averages)
BASELINE_DEPRIVATION = {
    "Nutrition": 0.28,
    "Child mortality": 0.06,
    "Years of schooling": 0.22,
    "School attendance": 0.10,
    "Cooking fuel": 0.45,
    "Sanitation": 0.35,
    "Drinking water": 0.15,
    "Electricity": 0.18,
    "Housing": 0.30,
    "Assets": 0.25,
}

# ---------------------------------------------------------------------------
# Matplotlib global style
# ---------------------------------------------------------------------------

plt.rcParams.update(
    {
        "figure.facecolor": "#FAFAFA",
        "axes.facecolor": "#FAFAFA",
        "axes.edgecolor": "#CCCCCC",
        "axes.grid": True,
        "grid.color": "#E0E0E0",
        "grid.linewidth": 0.5,
        "font.family": "sans-serif",
        "font.size": 11,
        "axes.titlesize": 14,
        "axes.titleweight": "bold",
        "axes.labelsize": 12,
        "xtick.labelsize": 10,
        "ytick.labelsize": 10,
        "figure.dpi": 120,
    }
)

# ---------------------------------------------------------------------------
# Data generation
# ---------------------------------------------------------------------------


def generate_households(n: int, seed: int = 42) -> pd.DataFrame:
    """Generate *n* synthetic households with correlated deprivation patterns.

    Within each dimension the indicators are positively correlated via a shared
    latent factor so that a household deprived in one health indicator is more
    likely deprived in the other, etc.  Cross-dimension correlation is weaker
    but still positive (general poverty factor).
    """
    rng = np.random.default_rng(seed)

    # Latent general poverty factor per household (higher = more deprived)
    poverty_factor = rng.beta(2, 5, size=n)  # skewed right

    # Latent dimension factors
    dim_factors = {}
    for dim in DIMENSIONS:
        dim_factors[dim] = 0.5 * poverty_factor + 0.5 * rng.beta(2, 5, size=n)

    data = {}
    for ind in INDICATORS:
        dim = INDICATOR_DIMENSION[ind]
        base_p = BASELINE_DEPRIVATION[ind]
        # Shift probability using the latent factor
        p = np.clip(base_p + 0.6 * (dim_factors[dim] - 0.25), 0.02, 0.98)
        data[ind] = (rng.random(n) < p).astype(int)

    return pd.DataFrame(data)


# ---------------------------------------------------------------------------
# MPI computation helpers
# ---------------------------------------------------------------------------


def compute_mpi(df: pd.DataFrame, weights: dict, k: float):
    """Return (mpi, H, A, dep_scores, is_poor) using the Alkire-Foster method."""
    w_arr = np.array([weights[ind] for ind in INDICATORS])
    dep_matrix = df[INDICATORS].values  # n x 10, binary
    dep_scores = dep_matrix @ w_arr  # weighted deprivation score per HH
    is_poor = dep_scores >= k
    H = is_poor.mean()  # headcount ratio
    if is_poor.sum() > 0:
        A = dep_scores[is_poor].mean()  # intensity
    else:
        A = 0.0
    mpi = H * A
    return mpi, H, A, dep_scores, is_poor


def indicator_contributions(df, weights, k):
    """Censored headcount ratio and contribution of each indicator."""
    w_arr = np.array([weights[ind] for ind in INDICATORS])
    dep_matrix = df[INDICATORS].values
    dep_scores = dep_matrix @ w_arr
    is_poor = dep_scores >= k
    n = len(df)
    contributions = {}
    censored_rates = {}
    mpi_val = (dep_scores * is_poor).sum() / n if n > 0 else 0
    for j, ind in enumerate(INDICATORS):
        ch = (dep_matrix[:, j] * is_poor).sum() / n  # censored headcount
        censored_rates[ind] = ch
        contributions[ind] = (weights[ind] * ch) / mpi_val if mpi_val > 0 else 0
    return censored_rates, contributions, mpi_val


def uncensored_deprivation_rates(df):
    """Raw deprivation rate for each indicator."""
    return {ind: df[ind].mean() for ind in INDICATORS}


def mpi_sensitivity(df, weights, k_values):
    """Compute MPI, H, A for a range of k values."""
    results = []
    for k in k_values:
        mpi, H, A, _, _ = compute_mpi(df, weights, k)
        results.append({"k": k, "MPI": mpi, "H": H, "A": A})
    return pd.DataFrame(results)


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

# Build weight sliders for custom weights
weight_sliders = []
for dim, inds in DIMENSIONS.items():
    default_w = round(EQUAL_WEIGHTS[inds[0]], 4)
    weight_sliders.append(ui.h6(dim, class_="mt-3 mb-1", style="color:#555;"))
    for ind in inds:
        weight_sliders.append(
            ui.input_slider(
                f"w_{ind.replace(' ', '_')}",
                ind,
                min=0.0,
                max=0.5,
                value=default_w,
                step=0.01,
            )
        )

app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("MPI Explorer", style="margin-bottom:2px;"),
        ui.p("Impact Mojo", style="color:#888; font-size:0.85em; margin-top:0;"),
        ui.hr(),
        ui.input_slider(
            "n_households",
            "Number of households",
            min=100,
            max=5000,
            value=1000,
            step=100,
        ),
        ui.input_slider(
            "k_cutoff",
            "Poverty cutoff (k)",
            min=0.10,
            max=1.0,
            value=0.33,
            step=0.01,
        ),
        ui.input_switch("custom_weights", "Use custom weights", value=False),
        ui.panel_conditional(
            "input.custom_weights",
            ui.div(
                ui.p(
                    ui.output_text("weight_sum_msg"),
                    style="font-size:0.85em;",
                ),
                *weight_sliders,
                style="max-height:360px; overflow-y:auto; padding-right:6px;",
            ),
        ),
        ui.hr(),
        ui.input_slider("seed", "Random seed", min=1, max=999, value=42, step=1),
        width=320,
    ),
    ui.navset_tab(
        ui.nav_panel(
            "MPI Dashboard",
            ui.div(
                ui.output_plot("dashboard_kpis", height="220px"),
                ui.output_plot("radar_chart", height="480px"),
            ),
        ),
        ui.nav_panel(
            "Decomposition",
            ui.output_plot("decomposition_plot", height="620px"),
        ),
        ui.nav_panel(
            "Distribution",
            ui.output_plot("distribution_plot", height="560px"),
        ),
        ui.nav_panel(
            "Sensitivity",
            ui.output_plot("sensitivity_plot", height="560px"),
        ),
        ui.nav_panel(
            "About",
            ui.div(
                ui.markdown(
                    """
## About the Multidimensional Poverty Index (MPI)

### What is the MPI?

The **Global Multidimensional Poverty Index (MPI)** is an international
measure of acute multidimensional poverty covering over 100 developing
countries. It complements traditional monetary poverty measures by
capturing the **simultaneous deprivations** that a person or household
faces across multiple dimensions of well-being.

The MPI was developed by the **Oxford Poverty and Human Development
Initiative (OPHI)** at the University of Oxford and the **United Nations
Development Programme (UNDP)** and has been published annually in the
*Human Development Report* since 2010.

---

### The Alkire-Foster Method

The MPI is computed using the **Alkire-Foster (AF) method** (Alkire &
Foster, 2011), a flexible framework for multidimensional poverty
measurement:

1. **Identify** who is poor by examining simultaneous deprivations.
2. **Aggregate** to obtain an overall poverty measure.

#### Step 1 — Deprivation identification

Each household is assessed across **10 indicators** grouped into
**3 equally weighted dimensions**:

| Dimension | Indicator | Deprived if... | Weight |
|---|---|---|---|
| **Health** (1/3) | Nutrition | Any household member is undernourished (BMI < 18.5 for adults; stunted/wasted for children) | 1/6 |
| | Child mortality | A child under 18 has died in the household in the past 5 years | 1/6 |
| **Education** (1/3) | Years of schooling | No household member aged 10+ has completed 6 years of schooling | 1/6 |
| | School attendance | Any school-aged child (up to grade 8) is not attending school | 1/6 |
| **Living Standards** (1/3) | Cooking fuel | Household cooks with dung, wood, charcoal, or coal | 1/18 |
| | Sanitation | Household sanitation facility is not improved or is shared | 1/18 |
| | Drinking water | Household does not have access to improved drinking water or the improved source is 30+ minutes away | 1/18 |
| | Electricity | Household has no electricity | 1/18 |
| | Housing | Housing materials (floor, roof, walls) are inadequate | 1/18 |
| | Assets | Household does not own more than one of: radio, TV, telephone, bicycle, motorbike, refrigerator, and does not own a car or truck | 1/18 |

Each household receives a **weighted deprivation score** *c* (0 to 1).

#### Step 2 — Poverty cutoff

A household is identified as **MPI-poor** if its deprivation score
**c >= k**, where **k = 1/3** is the standard cutoff (deprived in at
least one-third of weighted indicators).

#### Step 3 — Aggregation

- **H** (Incidence / Headcount Ratio) = proportion of population that is MPI-poor
- **A** (Intensity) = average deprivation score among the MPI-poor
- **MPI = H x A** — the adjusted headcount ratio

---

### Decomposition

A key strength of the AF method is that the MPI can be **decomposed**:

- **By indicator**: the *censored headcount ratio* for each indicator
  shows its contribution to overall poverty.
- **By sub-group**: the MPI can be computed for regions, ethnic groups,
  or urban/rural, enabling targeted policy.

---

### SDG Linkages

The MPI is directly relevant to **SDG 1** (No Poverty), specifically
Target 1.2: *"reduce at least by half the proportion of men, women and
children of all ages living in poverty in all its dimensions."*

The 10 MPI indicators also map to SDGs 2 (Zero Hunger), 3 (Good Health),
4 (Quality Education), 6 (Clean Water), 7 (Affordable Energy),
8 (Decent Work), and 11 (Sustainable Cities).

---

### References

1. Alkire, S. & Foster, J. (2011). "Counting and multidimensional
   poverty measurement." *Journal of Public Economics*, 95(7-8), 476-487.
2. Alkire, S., Kanagaratnam, U. & Suppa, N. (2024). *The Global
   Multidimensional Poverty Index (MPI) 2024*. OPHI MPI Methodological
   Note 56, University of Oxford.
3. UNDP & OPHI (2023). *2023 Global Multidimensional Poverty Index —
   Unstacking Global Poverty: Data for High-Impact Action*. United
   Nations Development Programme.

---

### About This App

This interactive explorer was built as part of the **Impact Mojo**
portfolio to demonstrate applied data science for development economics.
It generates synthetic household data with realistic correlated
deprivation patterns and lets users experiment with:

- Sample size and random seed
- Poverty cutoff sensitivity
- Custom vs. equal indicator weights
- Decomposition and distributional analysis

Built with **Python Shiny** and **Matplotlib**.
"""
                ),
                style="max-width:860px; padding:24px;",
            ),
        ),
    ),
    title="MPI Explorer — Impact Mojo",
    fillable=True,
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------


def server(input: Inputs, output: Outputs, session: Session):

    # -- Reactive: current weights dict ---------------------------------
    @reactive.calc
    def current_weights() -> dict:
        if input.custom_weights():
            raw = {}
            for ind in INDICATORS:
                slider_id = f"w_{ind.replace(' ', '_')}"
                raw[ind] = input[slider_id]()
            total = sum(raw.values())
            if total == 0:
                return EQUAL_WEIGHTS.copy()
            return {k: v / total for k, v in raw.items()}
        else:
            return EQUAL_WEIGHTS.copy()

    # -- Reactive: generated data ---------------------------------------
    @reactive.calc
    def household_data() -> pd.DataFrame:
        return generate_households(input.n_households(), seed=input.seed())

    # -- Reactive: MPI results ------------------------------------------
    @reactive.calc
    def mpi_results():
        df = household_data()
        w = current_weights()
        k = input.k_cutoff()
        mpi, H, A, dep_scores, is_poor = compute_mpi(df, w, k)
        return {
            "mpi": mpi,
            "H": H,
            "A": A,
            "dep_scores": dep_scores,
            "is_poor": is_poor,
        }

    # -- Weight sum message ---------------------------------------------
    @output
    @render.text
    def weight_sum_msg():
        raw = {}
        for ind in INDICATORS:
            slider_id = f"w_{ind.replace(' ', '_')}"
            raw[ind] = input[slider_id]()
        total = sum(raw.values())
        if abs(total - 1.0) < 0.005:
            return f"Weights sum: {total:.2f} (valid)"
        else:
            return f"Weights sum: {total:.2f} (will be normalised to 1.0)"

    # -- Dashboard KPIs -------------------------------------------------
    @output
    @render.plot
    def dashboard_kpis():
        res = mpi_results()
        fig, axes = plt.subplots(1, 3, figsize=(11, 2.2))
        fig.subplots_adjust(wspace=0.3)

        kpis = [
            ("MPI (H x A)", res["mpi"], "#8E44AD"),
            ("Incidence (H)", res["H"], "#2E86C1"),
            ("Intensity (A)", res["A"], "#E67E22"),
        ]

        for ax, (label, value, color) in zip(axes, kpis):
            ax.set_xlim(0, 1)
            ax.set_ylim(0, 1)
            ax.axis("off")
            # Large number
            ax.text(
                0.5, 0.58, f"{value:.3f}", ha="center", va="center",
                fontsize=38, fontweight="bold", color=color,
                transform=ax.transAxes,
            )
            # Label
            ax.text(
                0.5, 0.12, label, ha="center", va="center",
                fontsize=13, color="#555555",
                transform=ax.transAxes,
            )
            # Percentage subtitle
            ax.text(
                0.5, 0.88, f"{value * 100:.1f}%", ha="center", va="center",
                fontsize=13, color=color, alpha=0.7,
                transform=ax.transAxes,
            )

        n_poor = int(res["is_poor"].sum())
        n_total = len(res["is_poor"])
        fig.suptitle(
            f"{n_poor:,} of {n_total:,} households identified as MPI-poor "
            f"(k = {input.k_cutoff():.2f})",
            fontsize=11, color="#777777", y=0.02,
        )
        fig.patch.set_facecolor("#FAFAFA")
        return fig

    # -- Radar / Spider chart -------------------------------------------
    @output
    @render.plot
    def radar_chart():
        df = household_data()
        rates = uncensored_deprivation_rates(df)

        labels = list(rates.keys())
        values = [rates[ind] for ind in labels]
        N = len(labels)

        angles = np.linspace(0, 2 * np.pi, N, endpoint=False).tolist()
        values_closed = values + [values[0]]
        angles_closed = angles + [angles[0]]

        fig, ax = plt.subplots(figsize=(7, 5.2), subplot_kw={"polar": True})

        ax.set_theta_offset(np.pi / 2)
        ax.set_theta_direction(-1)

        # Draw the polygon
        ax.plot(angles_closed, values_closed, "o-", linewidth=2, color="#2E86C1")
        ax.fill(angles_closed, values_closed, alpha=0.18, color="#2E86C1")

        # Indicator labels
        wrapped = []
        for lbl in labels:
            if len(lbl) > 12:
                parts = lbl.rsplit(" ", 1)
                wrapped.append("\n".join(parts))
            else:
                wrapped.append(lbl)
        ax.set_thetagrids(np.degrees(angles), wrapped, fontsize=9)

        # Colour each label by dimension
        for lbl_obj, ind in zip(ax.get_xticklabels(), labels):
            dim = INDICATOR_DIMENSION[ind]
            lbl_obj.set_color(DIM_COLORS[dim])
            lbl_obj.set_fontweight("bold")

        ax.set_ylim(0, max(max(values) * 1.15, 0.1))
        ax.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=1.0))
        ax.set_title(
            "Deprivation Rates by Indicator (uncensored)",
            pad=24, fontsize=13, fontweight="bold",
        )

        # Legend for dimensions
        from matplotlib.lines import Line2D
        legend_elements = [
            Line2D([0], [0], marker="s", color="w",
                   markerfacecolor=DIM_COLORS[d], markersize=10, label=d)
            for d in DIMENSIONS
        ]
        ax.legend(
            handles=legend_elements, loc="lower right",
            bbox_to_anchor=(1.25, -0.05), fontsize=9, framealpha=0.9,
        )

        fig.tight_layout()
        fig.patch.set_facecolor("#FAFAFA")
        return fig

    # -- Decomposition --------------------------------------------------
    @output
    @render.plot
    def decomposition_plot():
        df = household_data()
        w = current_weights()
        k = input.k_cutoff()
        censored, contribs, mpi_val = indicator_contributions(df, w, k)

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6.8), height_ratios=[1.6, 1])
        fig.subplots_adjust(hspace=0.45)

        # -- Top: contribution bar by indicator -------------------------
        colors = [INDICATOR_COLORS[ind] for ind in INDICATORS]
        vals = [contribs[ind] * 100 for ind in INDICATORS]
        short_labels = []
        for ind in INDICATORS:
            parts = ind.split()
            if len(parts) > 1 and len(ind) > 10:
                short_labels.append(parts[0][:4] + ".\n" + " ".join(parts[1:]))
            else:
                short_labels.append(ind)

        bars = ax1.bar(range(len(INDICATORS)), vals, color=colors, edgecolor="white", linewidth=0.5)
        ax1.set_xticks(range(len(INDICATORS)))
        ax1.set_xticklabels(short_labels, fontsize=8, ha="center")
        ax1.set_ylabel("% Contribution to MPI")
        ax1.set_title(
            f"Indicator Contributions to MPI ({mpi_val:.4f})",
            fontsize=13, fontweight="bold",
        )
        for bar, v in zip(bars, vals):
            if v > 1:
                ax1.text(
                    bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5,
                    f"{v:.1f}%", ha="center", va="bottom", fontsize=8,
                )

        # -- Bottom: stacked bar by dimension ---------------------------
        dim_contribs = {}
        for dim in DIMENSIONS:
            dim_contribs[dim] = sum(contribs[ind] for ind in DIMENSIONS[dim]) * 100

        dims = list(DIMENSIONS.keys())
        dim_vals = [dim_contribs[d] for d in dims]
        dim_cols = [DIM_COLORS[d] for d in dims]

        left = 0
        for d, v, c in zip(dims, dim_vals, dim_cols):
            ax2.barh(0, v, left=left, color=c, edgecolor="white", height=0.5, label=d)
            if v > 3:
                ax2.text(
                    left + v / 2, 0, f"{d}\n{v:.1f}%",
                    ha="center", va="center", fontsize=10, fontweight="bold",
                    color="white",
                )
            left += v

        ax2.set_xlim(0, 100)
        ax2.set_yticks([])
        ax2.set_xlabel("% Contribution")
        ax2.set_title("Dimension Contributions", fontsize=13, fontweight="bold")
        ax2.legend(loc="upper right", fontsize=9)

        fig.patch.set_facecolor("#FAFAFA")
        return fig

    # -- Distribution ---------------------------------------------------
    @output
    @render.plot
    def distribution_plot():
        res = mpi_results()
        k = input.k_cutoff()
        dep = res["dep_scores"]
        is_poor = res["is_poor"]

        fig, ax = plt.subplots(figsize=(10, 5.5))

        bins = np.linspace(0, 1, 41)
        ax.hist(
            dep[~is_poor], bins=bins, color="#2ECC71", alpha=0.75,
            edgecolor="white", linewidth=0.5, label="Non-poor",
        )
        ax.hist(
            dep[is_poor], bins=bins, color="#E74C3C", alpha=0.75,
            edgecolor="white", linewidth=0.5, label="MPI-poor",
        )

        # Cutoff line
        ax.axvline(k, color="#8E44AD", linewidth=2.5, linestyle="--", label=f"Cutoff k = {k:.2f}")

        n_poor = int(is_poor.sum())
        n_total = len(is_poor)
        pct = n_poor / n_total * 100 if n_total > 0 else 0

        ax.set_xlabel("Weighted Deprivation Score (c)")
        ax.set_ylabel("Number of Households")
        ax.set_title(
            f"Distribution of Household Deprivation Scores  "
            f"({n_poor:,} poor / {n_total:,} total = {pct:.1f}%)",
            fontsize=13, fontweight="bold",
        )
        ax.legend(fontsize=10, loc="upper right")

        # Annotate
        ax.annotate(
            f"MPI-poor\n{n_poor:,} HH ({pct:.1f}%)",
            xy=(min(k + 0.05, 0.9), ax.get_ylim()[1] * 0.85),
            fontsize=11, color="#E74C3C", fontweight="bold",
        )

        fig.tight_layout()
        fig.patch.set_facecolor("#FAFAFA")
        return fig

    # -- Sensitivity analysis -------------------------------------------
    @output
    @render.plot
    def sensitivity_plot():
        df = household_data()
        w = current_weights()
        k_current = input.k_cutoff()

        k_range = np.arange(0.10, 1.01, 0.02)
        sens = mpi_sensitivity(df, w, k_range)

        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5.2))
        fig.subplots_adjust(wspace=0.30)

        # -- Left: MPI across k ----------------------------------------
        ax1.plot(sens["k"], sens["MPI"], "-o", color="#8E44AD", markersize=3, linewidth=2, label="MPI")
        ax1.axvline(k_current, color="#E74C3C", linewidth=2, linestyle="--", alpha=0.7, label=f"Current k = {k_current:.2f}")
        # Highlight current
        mpi_at_k = np.interp(k_current, sens["k"], sens["MPI"])
        ax1.plot(k_current, mpi_at_k, "o", color="#E74C3C", markersize=10, zorder=5)
        ax1.set_xlabel("Poverty Cutoff (k)")
        ax1.set_ylabel("MPI Value")
        ax1.set_title("MPI Sensitivity to Cutoff k", fontsize=13, fontweight="bold")
        ax1.legend(fontsize=9)
        ax1.set_xlim(0.08, 1.02)

        # -- Right: H and A across k -----------------------------------
        ax2.plot(sens["k"], sens["H"], "-s", color="#2E86C1", markersize=3, linewidth=2, label="H (Incidence)")
        ax2.plot(sens["k"], sens["A"], "-^", color="#E67E22", markersize=3, linewidth=2, label="A (Intensity)")
        ax2.axvline(k_current, color="#E74C3C", linewidth=2, linestyle="--", alpha=0.7)
        ax2.set_xlabel("Poverty Cutoff (k)")
        ax2.set_ylabel("Value")
        ax2.set_title("Incidence & Intensity vs. Cutoff", fontsize=13, fontweight="bold")
        ax2.legend(fontsize=9)
        ax2.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=1.0))
        ax2.set_xlim(0.08, 1.02)

        fig.suptitle(
            "As k increases, fewer households qualify as MPI-poor (H falls) "
            "but those who do are more intensely deprived (A rises).",
            fontsize=9.5, color="#777777", y=0.01,
        )
        fig.patch.set_facecolor("#FAFAFA")
        return fig


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = App(app_ui, server)
