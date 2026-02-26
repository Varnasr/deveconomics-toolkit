"""
Cost-Benefit Analysis Tool -- Impact Mojo
A comprehensive CBA tool for development economics.
"""

import numpy as np
import pandas as pd
from scipy import optimize
from shiny import App, reactive, render, ui
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import io

# ---------------------------------------------------------------------------
# Styling constants
# ---------------------------------------------------------------------------
COLORS = {
    "cost": "#E74C3C",
    "benefit": "#27AE60",
    "net": "#2980B9",
    "cumulative": "#8E44AD",
    "grid": "#E0E0E0",
    "bg": "#FAFAFA",
    "text": "#2C3E50",
}

PLT_STYLE = {
    "figure.facecolor": COLORS["bg"],
    "axes.facecolor": "#FFFFFF",
    "axes.edgecolor": COLORS["grid"],
    "axes.grid": True,
    "grid.color": COLORS["grid"],
    "grid.linestyle": "--",
    "grid.alpha": 0.7,
    "font.family": "sans-serif",
    "font.size": 11,
    "axes.titlesize": 14,
    "axes.titleweight": "bold",
    "axes.labelsize": 12,
    "legend.fontsize": 10,
    "legend.framealpha": 0.9,
    "figure.dpi": 100,
}

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def compute_annual_values(year0_val, growth_rate, horizon, start_year=0):
    """Return an array of length (horizon+1) with values growing at growth_rate,
    starting from start_year (values before start_year are zero)."""
    vals = np.zeros(horizon + 1)
    for t in range(horizon + 1):
        if t >= start_year:
            vals[t] = year0_val * ((1 + growth_rate / 100.0) ** (t - start_year))
    return vals


def discount_series(series, rate):
    """Discount a series at a constant annual rate."""
    n = len(series)
    factors = np.array([(1 + rate / 100.0) ** (-t) for t in range(n)])
    return series * factors


def compute_npv(costs, benefits, rate):
    """Net present value = PV(benefits) - PV(costs)."""
    dc = discount_series(costs, rate)
    db = discount_series(benefits, rate)
    return float(np.sum(db) - np.sum(dc))


def compute_bcr(costs, benefits, rate):
    """Benefit-cost ratio."""
    dc = np.sum(discount_series(costs, rate))
    db = np.sum(discount_series(benefits, rate))
    if dc == 0:
        return float("inf") if db > 0 else 0.0
    return float(db / dc)


def compute_irr(costs, benefits):
    """Internal rate of return using scipy root-finding on the NPV function."""
    net = benefits - costs
    if np.all(net >= 0) or np.all(net <= 0):
        return None
    try:
        result = optimize.brentq(
            lambda r: float(np.sum(discount_series(net, r * 100.0))),
            -0.5, 10.0,
            maxiter=500,
        )
        return result * 100.0
    except (ValueError, RuntimeError):
        return None


def compute_payback(costs, benefits, rate):
    """Payback period: first year in which cumulative discounted net benefit >= 0."""
    net = discount_series(benefits - costs, rate)
    cum = np.cumsum(net)
    idx = np.where(cum >= 0)[0]
    if len(idx) == 0:
        return None
    return int(idx[0])


def fmt_currency(val, currency="USD"):
    """Format a number as currency string."""
    if abs(val) >= 1e9:
        return f"{currency} {val/1e9:,.2f}B"
    if abs(val) >= 1e6:
        return f"{currency} {val/1e6:,.2f}M"
    if abs(val) >= 1e3:
        return f"{currency} {val/1e3:,.2f}K"
    return f"{currency} {val:,.2f}"


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

def make_cost_inputs(i):
    """Generate UI inputs for a single cost category."""
    return ui.div(
        ui.row(
            ui.column(4, ui.input_text(f"cost_name_{i}", f"Cost {i+1} name", value=f"Cost {i+1}")),
            ui.column(4, ui.input_numeric(f"cost_val_{i}", "Year-0 value", value=100000, min=0)),
            ui.column(4, ui.input_numeric(f"cost_growth_{i}", "Annual growth %", value=2.0, min=-50, max=100, step=0.5)),
        ),
        class_="mb-2",
    )


def make_benefit_inputs(i):
    """Generate UI inputs for a single benefit category."""
    return ui.div(
        ui.row(
            ui.column(3, ui.input_text(f"ben_name_{i}", f"Benefit {i+1} name", value=f"Benefit {i+1}")),
            ui.column(3, ui.input_numeric(f"ben_val_{i}", "Year-0 value", value=150000, min=0)),
            ui.column(3, ui.input_numeric(f"ben_growth_{i}", "Annual growth %", value=3.0, min=-50, max=100, step=0.5)),
            ui.column(3, ui.input_numeric(f"ben_start_{i}", "Start year", value=0, min=0, max=30)),
        ),
        class_="mb-2",
    )


app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("Project Settings"),
        ui.input_text("project_name", "Project name", value="My Development Project"),
        ui.input_slider("horizon", "Time horizon (years)", min=1, max=30, value=10),
        ui.input_slider("discount_rate", "Discount rate (%)", min=0, max=20, value=5, step=0.5),
        ui.input_switch("use_social_rate", "Use social discount rate", value=False),
        ui.panel_conditional(
            "input.use_social_rate",
            ui.input_slider("social_rate", "Social discount rate (%)", min=0, max=20, value=3, step=0.5),
        ),
        ui.input_text("currency", "Currency label", value="USD"),
        ui.hr(),
        ui.h5("Cost Categories"),
        ui.input_slider("n_costs", "Number of cost categories", min=1, max=10, value=3),
        ui.output_ui("cost_inputs_ui"),
        ui.hr(),
        ui.h5("Benefit Categories"),
        ui.input_slider("n_benefits", "Number of benefit categories", min=1, max=10, value=3),
        ui.output_ui("benefit_inputs_ui"),
        ui.hr(),
        ui.h5("Sensitivity Analysis"),
        ui.input_switch("include_sensitivity", "Include sensitivity analysis", value=True),
        ui.panel_conditional(
            "input.include_sensitivity",
            ui.input_slider("sens_range", "Discount rate +/- (pp)", min=1, max=10, value=3, step=0.5),
        ),
        width=420,
        bg="#F7F9FC",
    ),
    ui.navset_tab(
        ui.nav_panel(
            "Summary",
            ui.h3(ui.output_text("summary_title")),
            ui.row(
                ui.column(3, ui.value_box("Net Present Value", ui.output_text("npv_display"), showcase=ui.HTML('<i class="fa-solid fa-chart-line" style="font-size:2rem"></i>'), theme="primary", id="npv_box")),
                ui.column(3, ui.value_box("Benefit-Cost Ratio", ui.output_text("bcr_display"), showcase=ui.HTML('<i class="fa-solid fa-scale-balanced" style="font-size:2rem"></i>'), theme="info")),
                ui.column(3, ui.value_box("Internal Rate of Return", ui.output_text("irr_display"), showcase=ui.HTML('<i class="fa-solid fa-percent" style="font-size:2rem"></i>'), theme="secondary")),
                ui.column(3, ui.value_box("Payback Period", ui.output_text("payback_display"), showcase=ui.HTML('<i class="fa-solid fa-clock" style="font-size:2rem"></i>'), theme="dark")),
            ),
            ui.output_ui("npv_color_style"),
            ui.hr(),
            ui.h4("Summary Table"),
            ui.output_data_frame("summary_table"),
        ),
        ui.nav_panel(
            "Cash Flows",
            ui.h4("Annual Cash Flow Chart"),
            ui.output_plot("cashflow_chart", height="400px"),
            ui.h4("Cumulative Net Benefit"),
            ui.output_plot("cumulative_chart", height="350px"),
            ui.hr(),
            ui.h4("Annual Cash Flow Table"),
            ui.output_data_frame("cashflow_table"),
        ),
        ui.nav_panel(
            "Sensitivity",
            ui.h4("Tornado Diagram — NPV Sensitivity to +/-20% Parameter Changes"),
            ui.output_plot("tornado_plot", height="450px"),
            ui.h4("Spider Plot — NPV vs Discount Rate"),
            ui.output_plot("spider_plot", height="400px"),
            ui.h4("Monte Carlo Simulation — NPV Distribution (+/-30% variation)"),
            ui.output_plot("monte_carlo_plot", height="400px"),
            ui.output_ui("monte_carlo_stats"),
        ),
        ui.nav_panel(
            "CEA",
            ui.h4("Cost-Effectiveness Analysis"),
            ui.row(
                ui.column(
                    4,
                    ui.input_text("cea_metric", "Effectiveness metric", value="DALYs averted"),
                    ui.input_numeric("cea_units", "Total units of effectiveness", value=500, min=0),
                    ui.input_numeric("cea_benchmark_low", "Benchmark: low (cost per unit)", value=50, min=0),
                    ui.input_numeric("cea_benchmark_high", "Benchmark: high (cost per unit)", value=150, min=0),
                ),
                ui.column(
                    8,
                    ui.output_ui("cea_summary"),
                    ui.output_plot("cea_chart", height="350px"),
                ),
            ),
        ),
        ui.nav_panel(
            "About",
            ui.div(
                ui.h3("About This Tool"),
                ui.markdown("""
**Cost-Benefit Analysis (CBA)** is a systematic approach for estimating the strengths and
weaknesses of alternatives used to determine options that provide the best approach to
achieving benefits while preserving savings. In development economics, CBA is a
cornerstone of project appraisal used by the **World Bank**, regional development banks,
and organizations such as **J-PAL** (Abdul Latif Jameel Poverty Action Lab).

---

### Key Concepts

#### Net Present Value (NPV)

$$
NPV = \\sum_{t=0}^{T} \\frac{B_t - C_t}{(1+r)^t}
$$

Where *B_t* = benefits in year *t*, *C_t* = costs in year *t*, *r* = discount rate, *T* = time horizon.
A project is economically viable if **NPV > 0**.

#### Benefit-Cost Ratio (BCR)

$$
BCR = \\frac{\\sum_{t=0}^{T} B_t / (1+r)^t}{\\sum_{t=0}^{T} C_t / (1+r)^t}
$$

A project is worthwhile if **BCR > 1**.

#### Internal Rate of Return (IRR)

The discount rate *r\\** at which NPV = 0:

$$
\\sum_{t=0}^{T} \\frac{B_t - C_t}{(1+r^*)^t} = 0
$$

A project is acceptable if **IRR > opportunity cost of capital**.

#### Payback Period

The first year *t\\** in which cumulative discounted net benefits turn non-negative.

---

### Social Discount Rate

In development economics, the **social discount rate** is often lower than the private
discount rate to reflect society's preference for future welfare. Common values:

| Institution | Recommended Social Rate |
|---|---|
| World Bank | 3 -- 6% (varies by country income) |
| UK Treasury (Green Book) | 3.5% (declining for long horizons) |
| US OMB (Circular A-4) | 3% and 7% (dual rate) |
| J-PAL / GiveWell | 3 -- 5% |

---

### When to Use CBA vs. CEA

| | CBA | CEA |
|---|---|---|
| **Measures** | Monetized costs and benefits | Cost per unit of outcome |
| **Decision rule** | NPV > 0, BCR > 1 | Compare cost-effectiveness ratios |
| **Best for** | Infrastructure, policy reform | Health interventions, education |
| **Limitation** | Requires monetizing all benefits | Cannot compare across different outcomes |

**Cost-Effectiveness Analysis (CEA)** is preferred when benefits are difficult to monetize
(e.g., lives saved, disability-adjusted life years averted). The **CEA tab** in this tool
allows you to compute cost per unit of effectiveness and compare against established
benchmarks.

---

### GiveWell Cost-Effectiveness Benchmarks

GiveWell considers interventions cost-effective if they avert a DALY for less than
approximately **$50 -- $100** (varying by context). The World Health Organization
historically used **1x -- 3x GDP per capita** per DALY averted as a threshold, though
this benchmark has been revised in recent guidance.

---

### References

1. **Boardman, A. E., Greenberg, D. H., Vining, A. R., & Weimer, D. L.** (2018).
   *Cost-Benefit Analysis: Concepts and Practice* (5th ed.). Cambridge University Press.
2. **J-PAL.** (2021). *Cost-Effectiveness Analysis.*
   [www.povertyactionlab.org](https://www.povertyactionlab.org)
3. **World Bank.** (2010). *Cost-Benefit Analysis in World Bank Projects.* Independent
   Evaluation Group.
4. **GiveWell.** (2023). *Cost-Effectiveness Analysis -- GiveWell.*
   [www.givewell.org](https://www.givewell.org)
5. **Dhaliwal, I., Duflo, E., Glennerster, R., & Tulloch, C.** (2013). "Comparative
   cost-effectiveness analysis to inform policy in developing countries: a general
   framework with applications for education." *Education Policy in Developing Countries*,
   pp. 285-338.
6. **HM Treasury.** (2022). *The Green Book: Central Government Guidance on Appraisal
   and Evaluation.*
"""),
                class_="p-4",
            ),
        ),
    ),
    title=ui.div(
        ui.h2("Cost-Benefit Analysis Tool", style="margin:0;display:inline"),
        ui.span(" -- Impact Mojo", style="font-size:1rem;color:#7f8c8d;vertical-align:middle;margin-left:8px"),
    ),
    fillable=True,
)


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

def server(input, output, session):

    # --- Dynamic UI for cost / benefit inputs ---

    @output
    @render.ui
    def cost_inputs_ui():
        n = input.n_costs()
        return ui.div(*[make_cost_inputs(i) for i in range(n)])

    @output
    @render.ui
    def benefit_inputs_ui():
        n = input.n_benefits()
        return ui.div(*[make_benefit_inputs(i) for i in range(n)])

    # --- Reactive helpers to gather parameter values ---

    @reactive.Calc
    def effective_rate():
        if input.use_social_rate():
            return input.social_rate()
        return input.discount_rate()

    @reactive.Calc
    def cost_series():
        """Return total annual cost array (sum of all categories)."""
        h = input.horizon()
        total = np.zeros(h + 1)
        for i in range(input.n_costs()):
            try:
                name = input[f"cost_name_{i}"]()
                val = float(input[f"cost_val_{i}"]() or 0)
                gr = float(input[f"cost_growth_{i}"]() or 0)
            except Exception:
                val, gr = 0.0, 0.0
            total += compute_annual_values(val, gr, h)
        return total

    @reactive.Calc
    def benefit_series():
        """Return total annual benefit array (sum of all categories)."""
        h = input.horizon()
        total = np.zeros(h + 1)
        for i in range(input.n_benefits()):
            try:
                val = float(input[f"ben_val_{i}"]() or 0)
                gr = float(input[f"ben_growth_{i}"]() or 0)
                sy = int(input[f"ben_start_{i}"]() or 0)
            except Exception:
                val, gr, sy = 0.0, 0.0, 0
            total += compute_annual_values(val, gr, h, start_year=sy)
        return total

    @reactive.Calc
    def cost_category_series():
        """Return dict of category name -> annual array for costs."""
        h = input.horizon()
        cats = {}
        for i in range(input.n_costs()):
            try:
                name = input[f"cost_name_{i}"]() or f"Cost {i+1}"
                val = float(input[f"cost_val_{i}"]() or 0)
                gr = float(input[f"cost_growth_{i}"]() or 0)
            except Exception:
                name, val, gr = f"Cost {i+1}", 0.0, 0.0
            cats[name] = compute_annual_values(val, gr, h)
        return cats

    @reactive.Calc
    def benefit_category_series():
        """Return dict of category name -> annual array for benefits."""
        h = input.horizon()
        cats = {}
        for i in range(input.n_benefits()):
            try:
                name = input[f"ben_name_{i}"]() or f"Benefit {i+1}"
                val = float(input[f"ben_val_{i}"]() or 0)
                gr = float(input[f"ben_growth_{i}"]() or 0)
                sy = int(input[f"ben_start_{i}"]() or 0)
            except Exception:
                name, val, gr, sy = f"Benefit {i+1}", 0.0, 0.0, 0
            cats[name] = compute_annual_values(val, gr, h, start_year=sy)
        return cats

    # --- Summary tab outputs ---

    @output
    @render.text
    def summary_title():
        return f"Project: {input.project_name()}"

    @output
    @render.text
    def npv_display():
        npv = compute_npv(cost_series(), benefit_series(), effective_rate())
        return fmt_currency(npv, input.currency())

    @output
    @render.text
    def bcr_display():
        bcr = compute_bcr(cost_series(), benefit_series(), effective_rate())
        return f"{bcr:.3f}"

    @output
    @render.text
    def irr_display():
        irr = compute_irr(cost_series(), benefit_series())
        if irr is None:
            return "N/A"
        return f"{irr:.2f}%"

    @output
    @render.text
    def payback_display():
        pb = compute_payback(cost_series(), benefit_series(), effective_rate())
        if pb is None:
            return "Not reached"
        return f"Year {pb}"

    @output
    @render.ui
    def npv_color_style():
        npv = compute_npv(cost_series(), benefit_series(), effective_rate())
        color = "#27AE60" if npv >= 0 else "#E74C3C"
        label = "ECONOMICALLY VIABLE" if npv >= 0 else "NOT VIABLE"
        return ui.div(
            ui.span(label, style=f"color:white;background:{color};padding:6px 18px;border-radius:6px;font-weight:bold;font-size:1.1rem"),
            style="text-align:center;margin:12px 0",
        )

    @output
    @render.data_frame
    def summary_table():
        r = effective_rate()
        cur = input.currency()
        cost_cats = cost_category_series()
        ben_cats = benefit_category_series()

        rows = []
        for name, series in cost_cats.items():
            pv = float(np.sum(discount_series(series, r)))
            rows.append({"Category": name, "Type": "Cost", f"Total Undiscounted ({cur})": f"{float(np.sum(series)):,.0f}", f"Present Value ({cur})": f"{pv:,.0f}"})
        for name, series in ben_cats.items():
            pv = float(np.sum(discount_series(series, r)))
            rows.append({"Category": name, "Type": "Benefit", f"Total Undiscounted ({cur})": f"{float(np.sum(series)):,.0f}", f"Present Value ({cur})": f"{pv:,.0f}"})

        total_c = float(np.sum(discount_series(cost_series(), r)))
        total_b = float(np.sum(discount_series(benefit_series(), r)))
        rows.append({"Category": "TOTAL COSTS", "Type": "---", f"Total Undiscounted ({cur})": f"{float(np.sum(cost_series())):,.0f}", f"Present Value ({cur})": f"{total_c:,.0f}"})
        rows.append({"Category": "TOTAL BENEFITS", "Type": "---", f"Total Undiscounted ({cur})": f"{float(np.sum(benefit_series())):,.0f}", f"Present Value ({cur})": f"{total_b:,.0f}"})
        rows.append({"Category": "NET PRESENT VALUE", "Type": "---", f"Total Undiscounted ({cur})": "---", f"Present Value ({cur})": f"{total_b - total_c:,.0f}"})

        return render.DataGrid(pd.DataFrame(rows), row_selection_mode="none")

    # --- Cash Flows tab ---

    @output
    @render.plot
    def cashflow_chart():
        with plt.rc_context(PLT_STYLE):
            fig, ax = plt.subplots(figsize=(10, 4.5))
            h = input.horizon()
            years = np.arange(h + 1)
            costs = cost_series()
            benefits = benefit_series()
            net = benefits - costs

            ax.plot(years, costs / 1e3, color=COLORS["cost"], linewidth=2.2, marker="o", markersize=4, label="Total Costs")
            ax.plot(years, benefits / 1e3, color=COLORS["benefit"], linewidth=2.2, marker="s", markersize=4, label="Total Benefits")
            ax.plot(years, net / 1e3, color=COLORS["net"], linewidth=2, linestyle="--", marker="^", markersize=4, label="Net Benefits")
            ax.axhline(0, color="#7f8c8d", linewidth=0.8, linestyle="-")
            ax.fill_between(years, 0, net / 1e3, where=(net >= 0), alpha=0.10, color=COLORS["benefit"])
            ax.fill_between(years, 0, net / 1e3, where=(net < 0), alpha=0.10, color=COLORS["cost"])

            ax.set_xlabel("Year")
            ax.set_ylabel(f"Value ({input.currency()} thousands)")
            ax.set_title("Annual Cash Flows")
            ax.legend(loc="best")
            fig.tight_layout()
            return fig

    @output
    @render.plot
    def cumulative_chart():
        with plt.rc_context(PLT_STYLE):
            fig, ax = plt.subplots(figsize=(10, 3.8))
            h = input.horizon()
            years = np.arange(h + 1)
            r = effective_rate()
            net_disc = discount_series(benefit_series() - cost_series(), r)
            cum = np.cumsum(net_disc)

            ax.plot(years, cum / 1e3, color=COLORS["cumulative"], linewidth=2.5, marker="D", markersize=4)
            ax.fill_between(years, 0, cum / 1e3, where=(cum >= 0), alpha=0.15, color=COLORS["benefit"])
            ax.fill_between(years, 0, cum / 1e3, where=(cum < 0), alpha=0.15, color=COLORS["cost"])
            ax.axhline(0, color="#7f8c8d", linewidth=0.8)
            ax.set_xlabel("Year")
            ax.set_ylabel(f"Cumulative NPV ({input.currency()} thousands)")
            ax.set_title("Cumulative Discounted Net Benefit")
            fig.tight_layout()
            return fig

    @output
    @render.data_frame
    def cashflow_table():
        h = input.horizon()
        r = effective_rate()
        cur = input.currency()
        years = np.arange(h + 1)
        costs = cost_series()
        benefits = benefit_series()
        net = benefits - costs
        disc_net = discount_series(net, r)
        cum = np.cumsum(disc_net)
        df = pd.DataFrame({
            "Year": years,
            f"Costs ({cur})": [f"{v:,.0f}" for v in costs],
            f"Benefits ({cur})": [f"{v:,.0f}" for v in benefits],
            f"Net ({cur})": [f"{v:,.0f}" for v in net],
            f"Discounted Net ({cur})": [f"{v:,.0f}" for v in disc_net],
            f"Cumulative NPV ({cur})": [f"{v:,.0f}" for v in cum],
        })
        return render.DataGrid(df, row_selection_mode="none")

    # --- Sensitivity tab ---

    @output
    @render.plot
    def tornado_plot():
        with plt.rc_context(PLT_STYLE):
            r = effective_rate()
            costs = cost_series()
            benefits = benefit_series()
            base_npv = compute_npv(costs, benefits, r)

            # Parameters to vary: each cost category, each benefit category, discount rate
            labels = []
            low_npvs = []
            high_npvs = []

            # Vary each cost category +/- 20%
            for name, series in cost_category_series().items():
                other_costs = costs - series
                npv_low = compute_npv(other_costs + series * 0.8, benefits, r)
                npv_high = compute_npv(other_costs + series * 1.2, benefits, r)
                labels.append(name)
                low_npvs.append(npv_low)
                high_npvs.append(npv_high)

            # Vary each benefit category +/- 20%
            for name, series in benefit_category_series().items():
                other_bens = benefits - series
                npv_low = compute_npv(costs, other_bens + series * 0.8, r)
                npv_high = compute_npv(costs, other_bens + series * 1.2, r)
                labels.append(name)
                low_npvs.append(npv_low)
                high_npvs.append(npv_high)

            # Vary discount rate +/- 20%
            npv_low_r = compute_npv(costs, benefits, r * 0.8)
            npv_high_r = compute_npv(costs, benefits, r * 1.2)
            labels.append("Discount rate")
            low_npvs.append(npv_low_r)
            high_npvs.append(npv_high_r)

            low_npvs = np.array(low_npvs)
            high_npvs = np.array(high_npvs)

            # Sort by swing width
            swings = np.abs(high_npvs - low_npvs)
            order = np.argsort(swings)
            labels = [labels[i] for i in order]
            low_npvs = low_npvs[order]
            high_npvs = high_npvs[order]

            # Ensure low < high for bar drawing
            bar_left = np.minimum(low_npvs, high_npvs)
            bar_right = np.maximum(low_npvs, high_npvs)

            fig, ax = plt.subplots(figsize=(10, max(4, len(labels) * 0.55 + 1.5)))
            y_pos = np.arange(len(labels))
            ax.barh(y_pos, (bar_right - base_npv) / 1e3, left=base_npv / 1e3, height=0.6, color=COLORS["benefit"], alpha=0.85, label="+20%")
            ax.barh(y_pos, (bar_left - base_npv) / 1e3, left=base_npv / 1e3, height=0.6, color=COLORS["cost"], alpha=0.85, label="-20%")
            ax.axvline(base_npv / 1e3, color=COLORS["text"], linewidth=1.5, linestyle="-")
            ax.set_yticks(y_pos)
            ax.set_yticklabels(labels)
            ax.set_xlabel(f"NPV ({input.currency()} thousands)")
            ax.set_title("Tornado Diagram: Parameter Sensitivity (+/-20%)")
            ax.legend(loc="best")
            fig.tight_layout()
            return fig

    @output
    @render.plot
    def spider_plot():
        with plt.rc_context(PLT_STYLE):
            fig, ax = plt.subplots(figsize=(10, 4.2))
            r = effective_rate()
            rng = input.sens_range() if input.include_sensitivity() else 3
            rates = np.linspace(max(0, r - rng), r + rng, 50)
            costs = cost_series()
            benefits = benefit_series()
            npvs = [compute_npv(costs, benefits, rt) / 1e3 for rt in rates]

            ax.plot(rates, npvs, color=COLORS["net"], linewidth=2.5)
            ax.axhline(0, color="#7f8c8d", linewidth=0.8)
            ax.axvline(r, color=COLORS["cumulative"], linewidth=1, linestyle="--", label=f"Current rate ({r}%)")
            ax.fill_between(rates, 0, npvs, where=(np.array(npvs) >= 0), alpha=0.10, color=COLORS["benefit"])
            ax.fill_between(rates, 0, npvs, where=(np.array(npvs) < 0), alpha=0.10, color=COLORS["cost"])
            ax.set_xlabel("Discount Rate (%)")
            ax.set_ylabel(f"NPV ({input.currency()} thousands)")
            ax.set_title("Spider Plot: NPV vs Discount Rate")
            ax.legend(loc="best")
            fig.tight_layout()
            return fig

    @output
    @render.plot
    def monte_carlo_plot():
        with plt.rc_context(PLT_STYLE):
            fig, ax = plt.subplots(figsize=(10, 4.2))
            r = effective_rate()
            costs = cost_series()
            benefits = benefit_series()
            n_sim = 2000
            rng = np.random.default_rng(42)

            npv_samples = []
            for _ in range(n_sim):
                c_mult = 1 + rng.uniform(-0.30, 0.30, size=len(costs))
                b_mult = 1 + rng.uniform(-0.30, 0.30, size=len(benefits))
                npv_samples.append(compute_npv(costs * c_mult, benefits * b_mult, r))
            npv_samples = np.array(npv_samples)

            ax.hist(npv_samples / 1e3, bins=60, color=COLORS["net"], alpha=0.75, edgecolor="white", linewidth=0.5)
            mean_npv = np.mean(npv_samples)
            p5 = np.percentile(npv_samples, 5)
            p95 = np.percentile(npv_samples, 95)
            ax.axvline(mean_npv / 1e3, color=COLORS["cost"], linewidth=2, linestyle="-", label=f"Mean: {fmt_currency(mean_npv, input.currency())}")
            ax.axvline(p5 / 1e3, color="#7f8c8d", linewidth=1.5, linestyle="--", label=f"5th %ile: {fmt_currency(p5, input.currency())}")
            ax.axvline(p95 / 1e3, color="#7f8c8d", linewidth=1.5, linestyle="--", label=f"95th %ile: {fmt_currency(p95, input.currency())}")
            ax.set_xlabel(f"NPV ({input.currency()} thousands)")
            ax.set_ylabel("Frequency")
            ax.set_title("Monte Carlo Simulation: NPV Distribution (2,000 runs, +/-30% variation)")
            ax.legend(loc="best")
            fig.tight_layout()
            return fig

    @output
    @render.ui
    def monte_carlo_stats():
        r = effective_rate()
        costs = cost_series()
        benefits = benefit_series()
        n_sim = 2000
        rng = np.random.default_rng(42)
        npv_samples = []
        for _ in range(n_sim):
            c_mult = 1 + rng.uniform(-0.30, 0.30, size=len(costs))
            b_mult = 1 + rng.uniform(-0.30, 0.30, size=len(benefits))
            npv_samples.append(compute_npv(costs * c_mult, benefits * b_mult, r))
        npv_samples = np.array(npv_samples)
        prob_pos = float(np.mean(npv_samples > 0) * 100)
        cur = input.currency()
        return ui.div(
            ui.row(
                ui.column(3, ui.strong("Probability NPV > 0:"), ui.br(), f"{prob_pos:.1f}%"),
                ui.column(3, ui.strong("Mean NPV:"), ui.br(), fmt_currency(np.mean(npv_samples), cur)),
                ui.column(3, ui.strong("Std Dev:"), ui.br(), fmt_currency(np.std(npv_samples), cur)),
                ui.column(3, ui.strong("95% CI:"), ui.br(), f"{fmt_currency(np.percentile(npv_samples, 2.5), cur)} to {fmt_currency(np.percentile(npv_samples, 97.5), cur)}"),
            ),
            class_="bg-light p-3 rounded mt-2",
        )

    # --- CEA tab ---

    @output
    @render.ui
    def cea_summary():
        r = effective_rate()
        total_disc_cost = float(np.sum(discount_series(cost_series(), r)))
        units = input.cea_units()
        cur = input.currency()
        metric = input.cea_metric()

        if units is None or units <= 0:
            return ui.div(ui.p("Please enter a positive number of effectiveness units.", style="color:#E74C3C"))

        cer = total_disc_cost / units
        bench_low = input.cea_benchmark_low() or 50
        bench_high = input.cea_benchmark_high() or 150

        if cer <= bench_low:
            verdict_color = "#27AE60"
            verdict_text = "HIGHLY COST-EFFECTIVE"
        elif cer <= bench_high:
            verdict_color = "#F39C12"
            verdict_text = "MODERATELY COST-EFFECTIVE"
        else:
            verdict_color = "#E74C3C"
            verdict_text = "NOT COST-EFFECTIVE by benchmark"

        return ui.div(
            ui.h4("Cost-Effectiveness Ratio"),
            ui.p(
                ui.strong(f"{cur} {cer:,.2f}"),
                f" per {metric}",
                style="font-size:1.3rem",
            ),
            ui.p(
                ui.span(verdict_text, style=f"color:white;background:{verdict_color};padding:4px 14px;border-radius:5px;font-weight:bold"),
            ),
            ui.hr(),
            ui.p(f"Total discounted costs: {fmt_currency(total_disc_cost, cur)}"),
            ui.p(f"Total effectiveness units: {units:,.0f} {metric}"),
            ui.p(f"Benchmarks: {cur} {bench_low:,.0f} (low) -- {cur} {bench_high:,.0f} (high) per {metric}"),
            class_="p-3",
        )

    @output
    @render.plot
    def cea_chart():
        with plt.rc_context(PLT_STYLE):
            fig, ax = plt.subplots(figsize=(7, 3.8))
            r = effective_rate()
            total_disc_cost = float(np.sum(discount_series(cost_series(), r)))
            units = input.cea_units()
            cur = input.currency()
            metric = input.cea_metric()
            bench_low = input.cea_benchmark_low() or 50
            bench_high = input.cea_benchmark_high() or 150

            if units is None or units <= 0:
                ax.text(0.5, 0.5, "Enter effectiveness units > 0", ha="center", va="center", transform=ax.transAxes, fontsize=14)
                fig.tight_layout()
                return fig

            cer = total_disc_cost / units
            bars = [cer, bench_low, bench_high]
            labels = ["This project", "Benchmark (low)", "Benchmark (high)"]
            colors_bar = [COLORS["net"], COLORS["benefit"], COLORS["cost"]]

            ax.barh(labels[::-1], bars[::-1], color=colors_bar[::-1], height=0.5, edgecolor="white", linewidth=1.5)
            for i, v in enumerate(bars[::-1]):
                ax.text(v + max(bars) * 0.02, i, f"{cur} {v:,.0f}", va="center", fontsize=10, fontweight="bold")

            ax.set_xlabel(f"Cost per {metric} ({cur})")
            ax.set_title("Cost-Effectiveness Comparison")
            ax.set_xlim(0, max(bars) * 1.35)
            fig.tight_layout()
            return fig

    # --- end server ---


app = App(app_ui, server)
