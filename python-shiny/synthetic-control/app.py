"""
Synthetic Control Visualizer — Impact Mojo
A Shiny for Python application implementing the Synthetic Control Method (SCM)
for development economics policy evaluation.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from scipy.optimize import minimize
from shiny import App, reactive, render, ui

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("Synthetic Control Visualizer"),
        ui.hr(),
        ui.h5("Data Generation"),
        ui.input_numeric("n_donors", "Number of donor units", value=15, min=5, max=30),
        ui.input_numeric(
            "n_pre", "Pre-treatment periods", value=10, min=5, max=20
        ),
        ui.input_numeric(
            "n_post", "Post-treatment periods", value=5, min=2, max=10
        ),
        ui.hr(),
        ui.h5("Treatment Effect"),
        ui.input_numeric("true_effect", "True treatment effect", value=5.0, step=0.5),
        ui.input_select(
            "effect_type",
            "Effect type",
            choices={"constant": "Constant", "growing": "Growing", "temporary": "Temporary (fades out)"},
            selected="constant",
        ),
        ui.hr(),
        ui.h5("DGP Parameters"),
        ui.input_numeric("noise_sd", "Noise level (SD)", value=1.0, min=0.0, step=0.1),
        ui.input_numeric("trend_slope", "Common trend slope", value=1.0, step=0.1),
        ui.input_numeric(
            "treated_baseline", "Treated unit baseline", value=50, step=1
        ),
        ui.input_numeric("seed", "Random seed", value=42, min=0),
        ui.hr(),
        ui.h5("Placebo Tests"),
        ui.input_switch("show_placebo", "Show placebo tests", value=False),
        ui.panel_conditional(
            "input.show_placebo",
            ui.input_numeric(
                "n_placebo",
                "Number of placebo iterations",
                value=15,
                min=5,
                max=30,
            ),
        ),
        width=310,
    ),
    ui.navset_tab(
        ui.nav_panel(
            "SCM Plot",
            ui.output_plot("scm_plot", height="560px"),
            ui.output_text_verbatim("scm_summary"),
        ),
        ui.nav_panel(
            "Weights",
            ui.output_plot("weights_plot", height="420px"),
            ui.h5("Donor Weights Table"),
            ui.output_data_frame("weights_table"),
        ),
        ui.nav_panel(
            "Placebo Tests",
            ui.output_ui("placebo_ui"),
        ),
        ui.nav_panel(
            "Pre-Treatment Fit",
            ui.output_plot("fit_plot", height="480px"),
            ui.output_text_verbatim("fit_stats"),
        ),
        ui.nav_panel(
            "About",
            ui.output_ui("about_content"),
        ),
    ),
    title="Synthetic Control Visualizer — Impact Mojo",
    fillable=True,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _generate_data(
    n_donors: int,
    n_pre: int,
    n_post: int,
    true_effect: float,
    effect_type: str,
    noise_sd: float,
    trend_slope: float,
    treated_baseline: float,
    seed: int,
):
    """
    Simulate panel data with one treated unit and *n_donors* control units.

    Returns
    -------
    time : 1-d array of period indices (0 … T-1)
    treated : 1-d array, outcome for the treated unit
    donors  : 2-d array (n_donors x T), outcomes for donor units
    treat_period : int, index of first treatment period
    effect_vec : 1-d array (length T), the applied treatment effect (0 pre)
    """
    rng = np.random.default_rng(int(seed))
    T = n_pre + n_post
    time = np.arange(T)
    treat_period = n_pre  # 0-indexed first post-treatment period

    # Donor baselines drawn near the treated baseline
    donor_baselines = treated_baseline + rng.normal(0, 5, size=n_donors)
    # Unit-specific mild slopes
    donor_slopes = trend_slope + rng.normal(0, 0.15, size=n_donors)

    donors = np.zeros((n_donors, T))
    for j in range(n_donors):
        donors[j] = (
            donor_baselines[j]
            + donor_slopes[j] * time
            + rng.normal(0, noise_sd, T)
        )

    # Treated unit — pre-treatment is a convex combination of donors + noise
    # so that a good synthetic control exists by construction.
    true_weights = rng.dirichlet(np.ones(n_donors))
    treated = true_weights @ donors + rng.normal(0, noise_sd, T)

    # Build the treatment-effect vector
    effect_vec = np.zeros(T)
    if effect_type == "constant":
        effect_vec[treat_period:] = true_effect
    elif effect_type == "growing":
        for t in range(treat_period, T):
            effect_vec[t] = true_effect * (t - treat_period + 1) / n_post
    elif effect_type == "temporary":
        for t in range(treat_period, T):
            decay = 1.0 - (t - treat_period) / n_post
            effect_vec[t] = true_effect * max(decay, 0.0)

    treated = treated + effect_vec

    return time, treated, donors, treat_period, effect_vec


def _solve_weights(treated_pre: np.ndarray, donors_pre: np.ndarray):
    """
    Find non-negative weights summing to 1 that minimise the squared
    prediction error in the pre-treatment period.

    Parameters
    ----------
    treated_pre : 1-d array (n_pre,)
    donors_pre  : 2-d array (n_donors, n_pre)

    Returns
    -------
    weights : 1-d array (n_donors,)
    """
    n_donors = donors_pre.shape[0]
    w0 = np.ones(n_donors) / n_donors

    def objective(w):
        synthetic = w @ donors_pre
        return np.sum((treated_pre - synthetic) ** 2)

    constraints = {"type": "eq", "fun": lambda w: np.sum(w) - 1.0}
    bounds = [(0.0, 1.0)] * n_donors

    result = minimize(
        objective,
        w0,
        method="SLSQP",
        bounds=bounds,
        constraints=constraints,
        options={"maxiter": 1000, "ftol": 1e-12},
    )
    return result.x


# Shared matplotlib style helper
_MPL_RC = {
    "figure.facecolor": "#fafafa",
    "axes.facecolor": "#ffffff",
    "axes.edgecolor": "#cccccc",
    "axes.grid": True,
    "grid.alpha": 0.35,
    "grid.linestyle": "--",
    "font.family": "sans-serif",
    "font.size": 11,
    "axes.titlesize": 13,
    "axes.labelsize": 11,
}


def _apply_style():
    plt.rcParams.update(_MPL_RC)


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

def server(input, output, session):

    # ---- Core reactive data --------------------------------------------------

    @reactive.calc
    def sim_data():
        return _generate_data(
            n_donors=int(input.n_donors()),
            n_pre=int(input.n_pre()),
            n_post=int(input.n_post()),
            true_effect=float(input.true_effect()),
            effect_type=input.effect_type(),
            noise_sd=float(input.noise_sd()),
            trend_slope=float(input.trend_slope()),
            treated_baseline=float(input.treated_baseline()),
            seed=int(input.seed()),
        )

    @reactive.calc
    def scm_results():
        time, treated, donors, tp, effect_vec = sim_data()
        n_pre = int(input.n_pre())
        weights = _solve_weights(treated[:n_pre], donors[:, :n_pre])
        synthetic = weights @ donors
        gap = treated - synthetic
        return {
            "time": time,
            "treated": treated,
            "donors": donors,
            "treat_period": tp,
            "effect_vec": effect_vec,
            "weights": weights,
            "synthetic": synthetic,
            "gap": gap,
        }

    # ---- Tab 1: SCM Plot -----------------------------------------------------

    @render.plot
    def scm_plot():
        _apply_style()
        res = scm_results()
        time = res["time"]
        treated = res["treated"]
        synthetic = res["synthetic"]
        gap = res["gap"]
        tp = res["treat_period"]

        fig, axes = plt.subplots(2, 1, figsize=(10, 7.5), gridspec_kw={"height_ratios": [3, 2]})
        fig.subplots_adjust(hspace=0.32)

        # --- upper panel: levels ---
        ax = axes[0]
        ax.plot(time, treated, linewidth=2.2, color="#d62728", label="Treated unit")
        ax.plot(
            time,
            synthetic,
            linewidth=2.2,
            linestyle="--",
            color="#1f77b4",
            label="Synthetic control",
        )
        ax.axvline(tp - 0.5, color="#555555", linestyle=":", linewidth=1.2, label="Treatment onset")
        ax.fill_between(
            time[tp:],
            synthetic[tp:],
            treated[tp:],
            alpha=0.15,
            color="#d62728",
            label="Estimated effect",
        )
        ax.set_xlabel("Period")
        ax.set_ylabel("Outcome")
        ax.set_title("Treated Unit vs. Synthetic Control")
        ax.legend(loc="upper left", fontsize=9, framealpha=0.9)
        ax.xaxis.set_major_locator(mticker.MaxNLocator(integer=True))

        # --- lower panel: gap ---
        ax2 = axes[1]
        ax2.bar(
            time,
            gap,
            color=np.where(np.arange(len(time)) < tp, "#888888", "#d62728"),
            alpha=0.7,
            width=0.7,
        )
        ax2.axhline(0, color="black", linewidth=0.8)
        ax2.axvline(tp - 0.5, color="#555555", linestyle=":", linewidth=1.2)
        ax2.set_xlabel("Period")
        ax2.set_ylabel("Gap (Treated − Synthetic)")
        ax2.set_title("Treatment Effect Gap")
        ax2.xaxis.set_major_locator(mticker.MaxNLocator(integer=True))

        fig.suptitle("Synthetic Control Method — Gap Analysis", fontsize=14, fontweight="bold", y=0.99)
        return fig

    @render.text
    def scm_summary():
        res = scm_results()
        tp = res["treat_period"]
        gap = res["gap"]
        post_gap = gap[tp:]
        pre_gap = gap[:tp]

        lines = [
            "--- Summary Statistics ---",
            f"Average post-treatment gap : {np.mean(post_gap):+.3f}",
            f"Cumulative post-treatment gap : {np.sum(post_gap):+.3f}",
            f"Max post-treatment gap : {np.max(np.abs(post_gap)):.3f}",
            f"Pre-treatment RMSPE : {np.sqrt(np.mean(pre_gap ** 2)):.4f}",
            f"Post/Pre RMSPE ratio : {np.sqrt(np.mean(post_gap ** 2)) / max(np.sqrt(np.mean(pre_gap ** 2)), 1e-9):.2f}",
            f"True effect (input) : {input.true_effect()}  |  Effect type: {input.effect_type()}",
        ]
        return "\n".join(lines)

    # ---- Tab 2: Weights ------------------------------------------------------

    @render.plot
    def weights_plot():
        _apply_style()
        res = scm_results()
        weights = res["weights"]
        n = len(weights)
        labels = [f"Donor {i + 1}" for i in range(n)]

        # Sort descending for readability
        order = np.argsort(weights)[::-1]
        sorted_w = weights[order]
        sorted_labels = [labels[i] for i in order]

        fig, ax = plt.subplots(figsize=(10, 5.5))
        colors = ["#1f77b4" if w > 0.01 else "#cccccc" for w in sorted_w]
        bars = ax.barh(range(n), sorted_w, color=colors, edgecolor="white", height=0.7)
        ax.set_yticks(range(n))
        ax.set_yticklabels(sorted_labels, fontsize=9)
        ax.invert_yaxis()
        ax.set_xlabel("Weight")
        ax.set_title("Donor Unit Weights in Synthetic Control", fontweight="bold")

        # Annotate non-trivial weights
        for i, (bar, w) in enumerate(zip(bars, sorted_w)):
            if w > 0.005:
                ax.text(
                    bar.get_width() + 0.005,
                    bar.get_y() + bar.get_height() / 2,
                    f"{w:.3f}",
                    va="center",
                    fontsize=8,
                    color="#333333",
                )
        fig.tight_layout()
        return fig

    @render.data_frame
    def weights_table():
        res = scm_results()
        weights = res["weights"]
        n = len(weights)
        df = pd.DataFrame(
            {
                "Donor": [f"Donor {i + 1}" for i in range(n)],
                "Weight": np.round(weights, 5),
            }
        )
        df = df.sort_values("Weight", ascending=False).reset_index(drop=True)
        df.index = df.index + 1
        df.index.name = "Rank"
        return df

    # ---- Tab 3: Placebo Tests ------------------------------------------------

    @render.ui
    def placebo_ui():
        if not input.show_placebo():
            return ui.div(
                ui.br(),
                ui.div(
                    ui.p(
                        "Placebo tests are disabled. Enable the ",
                        ui.strong("Show placebo tests"),
                        " toggle in the sidebar to run inference.",
                        style="font-size: 1.05em;",
                    ),
                    style="padding: 30px; background: #f8f8f8; border-radius: 8px; max-width: 600px; margin: 40px auto; text-align: center;",
                ),
            )
        return ui.div(
            ui.output_plot("placebo_plot", height="520px"),
            ui.output_text_verbatim("placebo_stats"),
        )

    @reactive.calc
    def placebo_results():
        """Run placebo SCM for each donor unit (or a subsample)."""
        res = scm_results()
        donors = res["donors"]
        n_pre = int(input.n_pre())
        n_donors = donors.shape[0]
        n_plac = min(int(input.n_placebo()), n_donors)
        rng = np.random.default_rng(int(input.seed()) + 999)
        placebo_indices = rng.choice(n_donors, size=n_plac, replace=False)

        placebo_gaps = []
        for idx in placebo_indices:
            pseudo_treated = donors[idx]
            # Remaining donors (exclude the pseudo-treated unit)
            remaining_mask = np.ones(n_donors, dtype=bool)
            remaining_mask[idx] = False
            pseudo_donors = donors[remaining_mask]
            try:
                w = _solve_weights(pseudo_treated[:n_pre], pseudo_donors[:, :n_pre])
                synth = w @ pseudo_donors
                placebo_gaps.append(pseudo_treated - synth)
            except Exception:
                continue  # skip if optimisation fails
        return placebo_gaps

    @render.plot
    def placebo_plot():
        _apply_style()
        res = scm_results()
        gap = res["gap"]
        tp = res["treat_period"]
        time = res["time"]
        pgaps = placebo_results()

        fig, ax = plt.subplots(figsize=(10, 6.5))
        for pg in pgaps:
            ax.plot(time, pg, color="#aaaaaa", linewidth=0.8, alpha=0.6)
        ax.plot(time, gap, color="#d62728", linewidth=2.5, label="Treated unit gap", zorder=5)
        ax.axvline(tp - 0.5, color="#555555", linestyle=":", linewidth=1.2)
        ax.axhline(0, color="black", linewidth=0.7)
        ax.set_xlabel("Period")
        ax.set_ylabel("Gap")
        ax.set_title("Placebo Tests — In-Space Placebos", fontweight="bold")
        ax.legend(loc="upper left", fontsize=10)
        ax.xaxis.set_major_locator(mticker.MaxNLocator(integer=True))
        fig.tight_layout()
        return fig

    @render.text
    def placebo_stats():
        res = scm_results()
        gap = res["gap"]
        tp = res["treat_period"]
        pgaps = placebo_results()
        if not pgaps:
            return "No placebo results available."

        treated_post_rmspe = np.sqrt(np.mean(gap[tp:] ** 2))
        treated_pre_rmspe = np.sqrt(np.mean(gap[:tp] ** 2))
        treated_ratio = treated_post_rmspe / max(treated_pre_rmspe, 1e-9)

        ratios = []
        for pg in pgaps:
            pre_r = np.sqrt(np.mean(pg[:tp] ** 2))
            post_r = np.sqrt(np.mean(pg[tp:] ** 2))
            ratios.append(post_r / max(pre_r, 1e-9))

        rank = 1 + sum(r >= treated_ratio for r in ratios)
        total = 1 + len(ratios)
        pval = rank / total

        lines = [
            "--- Placebo Inference ---",
            f"Treated post/pre RMSPE ratio : {treated_ratio:.3f}",
            f"Rank among all units         : {rank} / {total}",
            f"Pseudo p-value               : {pval:.3f}",
            "",
            f"Number of placebo iterations : {len(pgaps)}",
            f"Interpretation: {'Significant at 10%' if pval <= 0.10 else 'Significant at 5%' if pval <= 0.05 else 'Not significant at conventional levels'}"
            if pval <= 0.10
            else f"Interpretation: Not significant at conventional levels (p = {pval:.3f})",
        ]
        return "\n".join(lines)

    # ---- Tab 4: Pre-Treatment Fit --------------------------------------------

    @render.plot
    def fit_plot():
        _apply_style()
        res = scm_results()
        treated = res["treated"]
        synthetic = res["synthetic"]
        n_pre = int(input.n_pre())

        treated_pre = treated[:n_pre]
        synth_pre = synthetic[:n_pre]

        fig, axes = plt.subplots(1, 2, figsize=(11, 5.5))

        # Left: time-series comparison
        ax = axes[0]
        periods = np.arange(n_pre)
        ax.plot(periods, treated_pre, "o-", color="#d62728", linewidth=1.8, markersize=5, label="Treated")
        ax.plot(
            periods,
            synth_pre,
            "s--",
            color="#1f77b4",
            linewidth=1.8,
            markersize=5,
            label="Synthetic",
        )
        ax.set_xlabel("Pre-treatment period")
        ax.set_ylabel("Outcome")
        ax.set_title("Pre-Treatment Trajectories")
        ax.legend(fontsize=9)
        ax.xaxis.set_major_locator(mticker.MaxNLocator(integer=True))

        # Right: scatter actual vs synthetic
        ax2 = axes[1]
        lo = min(treated_pre.min(), synth_pre.min()) - 1
        hi = max(treated_pre.max(), synth_pre.max()) + 1
        ax2.plot([lo, hi], [lo, hi], "k--", linewidth=0.8, alpha=0.5, label="45-degree line")
        ax2.scatter(synth_pre, treated_pre, color="#1f77b4", s=50, edgecolors="white", zorder=3)
        ax2.set_xlabel("Synthetic control outcome")
        ax2.set_ylabel("Treated unit outcome")
        ax2.set_title("Actual vs. Synthetic (Pre-Treatment)")
        ax2.set_xlim(lo, hi)
        ax2.set_ylim(lo, hi)
        ax2.set_aspect("equal", adjustable="box")
        ax2.legend(fontsize=9)

        fig.suptitle("Pre-Treatment Fit Diagnostics", fontsize=13, fontweight="bold", y=1.01)
        fig.tight_layout()
        return fig

    @render.text
    def fit_stats():
        res = scm_results()
        treated = res["treated"]
        synthetic = res["synthetic"]
        n_pre = int(input.n_pre())

        treated_pre = treated[:n_pre]
        synth_pre = synthetic[:n_pre]
        residuals = treated_pre - synth_pre
        rmspe = np.sqrt(np.mean(residuals ** 2))
        ss_res = np.sum(residuals ** 2)
        ss_tot = np.sum((treated_pre - np.mean(treated_pre)) ** 2)
        r2 = 1.0 - ss_res / max(ss_tot, 1e-12)
        mae = np.mean(np.abs(residuals))

        lines = [
            "--- Pre-Treatment Fit Statistics ---",
            f"RMSPE (Root Mean Squared Prediction Error) : {rmspe:.5f}",
            f"MAE   (Mean Absolute Error)                : {mae:.5f}",
            f"R²    (Coefficient of Determination)       : {r2:.5f}",
            f"Max absolute residual                      : {np.max(np.abs(residuals)):.5f}",
            "",
            "A good synthetic control should have RMSPE close to zero and R² close to 1.",
            "If pre-treatment fit is poor, the post-treatment gap estimate may be unreliable.",
        ]
        return "\n".join(lines)

    # ---- Tab 5: About --------------------------------------------------------

    @render.ui
    def about_content():
        return ui.div(
            ui.div(
                ui.h2("About the Synthetic Control Method"),
                ui.hr(),
                ui.h4("What is the Synthetic Control Method?"),
                ui.p(
                    "The Synthetic Control Method (SCM) is a statistical approach for estimating "
                    "causal effects in comparative case studies. It constructs a weighted combination "
                    "of untreated (donor) units to create a 'synthetic' version of the treated unit — "
                    "one that approximates what the treated unit's outcome trajectory would have looked "
                    "like in the absence of the intervention."
                ),
                ui.p(
                    "The key idea is that no single untreated unit may be a suitable comparison for "
                    "the treated unit, but a ",
                    ui.strong("weighted combination"),
                    " of donor units can provide a far better counterfactual than any individual control.",
                ),
                ui.h4("When to Use SCM"),
                ui.tags.ul(
                    ui.tags.li(
                        ui.strong("Comparative case studies: "),
                        "When a policy, shock, or intervention affects a single unit "
                        "(country, state, region, firm) and you have a panel of untreated units.",
                    ),
                    ui.tags.li(
                        ui.strong("Policy evaluation: "),
                        "Estimating the effect of legislation, trade agreements, "
                        "economic liberalization, or public health interventions.",
                    ),
                    ui.tags.li(
                        ui.strong("Small-N settings: "),
                        "When the number of treated units is very small (often just one), "
                        "making traditional difference-in-differences or regression approaches less reliable.",
                    ),
                ),
                ui.h4("Key Assumptions"),
                ui.tags.ol(
                    ui.tags.li(
                        ui.strong("No interference (SUTVA): "),
                        "The treatment of one unit does not affect outcomes of donor units.",
                    ),
                    ui.tags.li(
                        ui.strong("Convex hull: "),
                        "The treated unit's pre-treatment characteristics lie within the convex hull "
                        "of the donor units. The synthetic control is a weighted average, so it cannot "
                        "extrapolate beyond the donors.",
                    ),
                    ui.tags.li(
                        ui.strong("No anticipation: "),
                        "Units do not change behaviour before the treatment actually occurs.",
                    ),
                    ui.tags.li(
                        ui.strong("Common factor structure: "),
                        "Outcomes are driven by common factors, and the factor loadings can be matched "
                        "by re-weighting donor units.",
                    ),
                ),
                ui.h4("Inference: Placebo Tests"),
                ui.p(
                    "Because SCM is typically applied to a single treated unit, classical standard errors "
                    "are not available. Instead, inference relies on ",
                    ui.strong("placebo (permutation) tests"),
                    ": the SCM procedure is applied iteratively, pretending each donor unit was treated. "
                    "If the treated unit's gap is unusually large relative to placebo gaps, we gain "
                    "confidence the effect is genuine. A common test statistic is the ratio of "
                    "post-treatment RMSPE to pre-treatment RMSPE.",
                ),
                ui.h4("Classic Applications in Development Economics"),
                ui.tags.ul(
                    ui.tags.li(
                        ui.strong("German Reunification (Abadie et al., 2015): "),
                        "Estimated the economic cost of reunification on West Germany's GDP per capita "
                        "using OECD countries as donors.",
                    ),
                    ui.tags.li(
                        ui.strong("California Proposition 99 (Abadie et al., 2010): "),
                        "Evaluated the effect of California's 1988 tobacco tax on per-capita cigarette "
                        "sales using other US states as controls.",
                    ),
                    ui.tags.li(
                        ui.strong("Basque Country terrorism (Abadie & Gardeazabal, 2003): "),
                        "Assessed the economic impact of ETA terrorism on the Basque Country's GDP "
                        "per capita using other Spanish regions.",
                    ),
                    ui.tags.li(
                        ui.strong("Economic liberalization: "),
                        "Multiple studies have used SCM to evaluate trade liberalization episodes, "
                        "examining the effect of policy reforms on GDP growth in developing countries.",
                    ),
                ),
                ui.h4("Technical Details of This App"),
                ui.p(
                    "This visualizer solves a constrained quadratic programme to find non-negative "
                    "donor weights summing to one that minimise the sum of squared differences between "
                    "the treated unit and the synthetic control in the pre-treatment period. The "
                    "optimisation uses SciPy's SLSQP solver. Data are generated from a factor-model "
                    "DGP where the treated unit is, by construction, a noisy convex combination of donors."
                ),
                ui.h4("References"),
                ui.tags.ul(
                    ui.tags.li(
                        "Abadie, A. & Gardeazabal, J. (2003). \"The Economic Costs of Conflict: "
                        "A Case Study of the Basque Country.\" ",
                        ui.em("American Economic Review"),
                        ", 93(1), 113–132.",
                    ),
                    ui.tags.li(
                        "Abadie, A., Diamond, A., & Hainmueller, J. (2010). \"Synthetic Control Methods "
                        "for Comparative Case Studies: Estimating the Effect of California's Tobacco "
                        "Control Program.\" ",
                        ui.em("Journal of the American Statistical Association"),
                        ", 105(490), 493–505.",
                    ),
                    ui.tags.li(
                        "Abadie, A., Diamond, A., & Hainmueller, J. (2015). \"Comparative Politics and "
                        "the Synthetic Control Method.\" ",
                        ui.em("American Journal of Political Science"),
                        ", 59(2), 495–510.",
                    ),
                    ui.tags.li(
                        "Abadie, A. (2021). \"Using Synthetic Controls: Feasibility, Data Requirements, "
                        "and Methodological Aspects.\" ",
                        ui.em("Journal of Economic Literature"),
                        ", 59(2), 391–425.",
                    ),
                ),
                ui.hr(),
                ui.p(
                    ui.em("Impact Mojo — Interactive tools for causal inference and development economics."),
                    style="text-align: center; color: #888888;",
                ),
                style="max-width: 820px; margin: 0 auto; padding: 20px 10px; line-height: 1.65;",
            )
        )


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = App(app_ui, server)
