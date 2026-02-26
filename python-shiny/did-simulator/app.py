"""
Difference-in-Differences Simulator — Impact Mojo
===================================================
An interactive tool for development economics practitioners to explore
DiD estimation, parallel trends assumptions, and event-study designs.
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import statsmodels.api as sm
from scipy import stats

from shiny import App, reactive, render, ui

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

SIDEBAR = ui.sidebar(
    ui.h4("Simulation Parameters"),
    ui.hr(),
    ui.input_numeric(
        "baseline_mean",
        "Baseline mean (control group)",
        value=50,
        min=0,
        max=200,
        step=1,
    ),
    ui.input_slider(
        "time_trend",
        "Time trend (slope per period)",
        min=-5.0,
        max=10.0,
        value=2.0,
        step=0.5,
    ),
    ui.input_slider(
        "treatment_effect",
        "Treatment effect (DiD)",
        min=-20.0,
        max=30.0,
        value=5.0,
        step=0.5,
    ),
    ui.input_numeric(
        "n_per_cell",
        "Sample size per group-period",
        value=100,
        min=10,
        max=1000,
        step=10,
    ),
    ui.input_slider(
        "noise_sd",
        "Noise / std. deviation",
        min=1.0,
        max=40.0,
        value=10.0,
        step=0.5,
    ),
    ui.hr(),
    ui.input_slider(
        "n_pre",
        "Pre-treatment periods",
        min=2,
        max=10,
        value=4,
        step=1,
    ),
    ui.input_slider(
        "n_post",
        "Post-treatment periods",
        min=1,
        max=5,
        value=2,
        step=1,
    ),
    ui.hr(),
    ui.input_switch(
        "violate_parallel",
        "Violate parallel trends",
        value=False,
    ),
    ui.p(
        ui.tags.small(
            "When enabled, a differential pre-trend is added to the "
            "treatment group, breaking the key identifying assumption."
        ),
        style="color: #666; margin-top: -4px;",
    ),
    width=320,
    bg="#f8f9fa",
)

app_ui = ui.page_sidebar(
    SIDEBAR,
    ui.navset_tab(
        ui.nav_panel(
            "DiD Plot",
            ui.output_plot("did_plot", height="560px"),
            ui.output_text_verbatim("did_estimate_text"),
        ),
        ui.nav_panel(
            "Regression Output",
            ui.output_text_verbatim("regression_table"),
        ),
        ui.nav_panel(
            "Event Study",
            ui.output_plot("event_study_plot", height="560px"),
            ui.output_text_verbatim("event_study_text"),
        ),
        ui.nav_panel(
            "About",
            ui.div(
                ui.HTML(_about_html := ""),  # placeholder — replaced below
                style="max-width: 800px; padding: 20px 10px;",
            ),
        ),
    ),
    title=ui.div(
        ui.h3(
            "Difference-in-Differences Simulator",
            style="margin:0; display:inline;",
        ),
        ui.span(
            " — Impact Mojo",
            style="font-size:1rem; color:#6c757d; font-weight:400;",
        ),
        style="padding: 6px 0;",
    ),
    fillable=True,
)

# Patch in the About HTML (keeps the UI definition cleaner) ----------------

ABOUT_HTML = """
<h3>About This Simulator</h3>

<h4>Difference-in-Differences (DiD)</h4>
<p>
Difference-in-Differences is one of the most widely used quasi-experimental
research designs in economics, public health, and the social sciences. It
estimates the <strong>causal effect</strong> of a treatment or policy
intervention by comparing changes in outcomes over time between a group that
receives the treatment (<em>treatment group</em>) and a group that does not
(<em>control group</em>).
</p>

<h4>The Canonical 2&times;2 Model</h4>
<p>The standard DiD regression takes the form:</p>
<pre style="background:#f1f3f5; padding:12px; border-radius:6px;">
Y_it = &alpha; + &beta;<sub>1</sub>&middot;Post_t + &beta;<sub>2</sub>&middot;Treat_i + &beta;<sub>3</sub>&middot;(Post_t &times; Treat_i) + &epsilon;_it
</pre>
<ul>
  <li><strong>&beta;<sub>1</sub></strong> captures the common time effect</li>
  <li><strong>&beta;<sub>2</sub></strong> captures the baseline difference between groups</li>
  <li><strong>&beta;<sub>3</sub></strong> is the <strong>DiD estimator</strong> &mdash; the average treatment effect on the treated (ATT)</li>
</ul>

<h4>Key Identifying Assumptions</h4>
<ol>
  <li>
    <strong>Parallel Trends</strong> &mdash; In the absence of treatment, the
    treatment and control groups would have followed the same trajectory over
    time. This is the most critical and testable assumption. Use the
    <em>"Violate parallel trends"</em> toggle to see what happens when it
    fails.
  </li>
  <li>
    <strong>No Anticipation</strong> &mdash; Units do not change their
    behaviour in anticipation of the treatment before it is implemented.
  </li>
  <li>
    <strong>SUTVA (Stable Unit Treatment Value Assumption)</strong> &mdash;
    The treatment status of one unit does not affect the outcomes of other
    units, and there is only one version of the treatment.
  </li>
  <li>
    <strong>No Compositional Changes</strong> &mdash; The composition of
    treatment and control groups remains stable over time.
  </li>
</ol>

<h4>Event-Study Design</h4>
<p>
The <em>Event Study</em> tab shows dynamic treatment effects by interacting
the treatment indicator with each relative-time period (omitting <em>t = &minus;1</em>
as the reference category). Pre-treatment coefficients should hover around
zero under parallel trends; significant pre-treatment coefficients are a
red flag.
</p>

<h4>References</h4>
<ul>
  <li>Card, D. &amp; Krueger, A.B. (1994). &ldquo;Minimum Wages and Employment:
      A Case Study of the Fast-Food Industry in New Jersey and
      Pennsylvania.&rdquo; <em>American Economic Review</em>, 84(4), 772&ndash;793.</li>
  <li>Angrist, J.D. &amp; Pischke, J.-S. (2009). <em>Mostly Harmless
      Econometrics: An Empiricist&rsquo;s Companion.</em> Princeton University
      Press.</li>
  <li>Cunningham, S. (2021). <em>Causal Inference: The Mixtape.</em> Yale
      University Press.</li>
  <li>Roth, J., Sant&rsquo;Anna, P.H.C., Bilinski, A., &amp; Poe, J. (2023).
      &ldquo;What&rsquo;s Trending in Difference-in-Differences? A Synthesis of
      the Recent Econometrics Literature.&rdquo; <em>Journal of
      Econometrics</em>, 235(2), 2218&ndash;2244.</li>
</ul>

<hr>
<p style="color:#888; font-size:0.85rem;">
  <strong>Impact Mojo</strong> &mdash; Interactive tools for impact evaluation
  and development economics.
</p>
"""

# We need to rebuild the About nav panel properly. The placeholder above
# is never rendered; instead we reconstruct the ui object directly.
# Because Shiny for Python constructs the UI tree eagerly, the simplest
# approach is to define the full UI again with the HTML included. We use
# a helper function and re-assign app_ui.

def _build_ui():
    sidebar = SIDEBAR

    about_panel = ui.nav_panel(
        "About",
        ui.div(
            ui.HTML(ABOUT_HTML),
            style="max-width: 800px; padding: 20px 10px;",
        ),
    )

    return ui.page_sidebar(
        sidebar,
        ui.navset_tab(
            ui.nav_panel(
                "DiD Plot",
                ui.output_plot("did_plot", height="560px"),
                ui.output_text_verbatim("did_estimate_text"),
            ),
            ui.nav_panel(
                "Regression Output",
                ui.output_text_verbatim("regression_table"),
            ),
            ui.nav_panel(
                "Event Study",
                ui.output_plot("event_study_plot", height="560px"),
                ui.output_text_verbatim("event_study_text"),
            ),
            about_panel,
        ),
        title=ui.div(
            ui.h3(
                "Difference-in-Differences Simulator",
                style="margin:0; display:inline;",
            ),
            ui.span(
                " — Impact Mojo",
                style="font-size:1rem; color:#6c757d; font-weight:400;",
            ),
            style="padding: 6px 0;",
        ),
        fillable=True,
    )


app_ui = _build_ui()

# ---------------------------------------------------------------------------
# Colour palette (colour-blind-friendly)
# ---------------------------------------------------------------------------

CLR_CONTROL = "#3574A7"   # steel blue
CLR_TREAT = "#E45C3A"     # burnt orange
CLR_GRID = "#E0E0E0"
CLR_VLINE = "#888888"
CLR_DID = "#2CA02C"       # green for the DiD highlight

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------


def server(input, output, session):
    # ---- Reactive: generate synthetic panel data -------------------------

    @reactive.calc
    def sim_data():
        np.random.seed(42)

        n = int(input.n_per_cell())
        n_pre = int(input.n_pre())
        n_post = int(input.n_post())
        T = n_pre + n_post  # total periods
        baseline = float(input.baseline_mean())
        trend = float(input.time_trend())
        effect = float(input.treatment_effect())
        sd = float(input.noise_sd())
        violate = bool(input.violate_parallel())

        # Relative time: -n_pre, ..., -1, 0, 1, ..., n_post-1
        rel_times = list(range(-n_pre, n_post))

        records = []
        for t_idx, rel_t in enumerate(rel_times):
            for treat in [0, 1]:
                y_mean = baseline + trend * (t_idx)
                # Permanent level difference for treatment group
                if treat == 1:
                    y_mean += 3.0  # small baseline gap

                # Parallel-trends violation: differential slope for treat
                if violate and treat == 1:
                    y_mean += 1.5 * t_idx  # steeper trend for treatment

                # Treatment effect kicks in at rel_t >= 0
                if treat == 1 and rel_t >= 0:
                    y_mean += effect

                y_vals = np.random.normal(y_mean, sd, size=n)
                for y in y_vals:
                    records.append(
                        {
                            "unit_id": len(records),
                            "rel_time": rel_t,
                            "period": t_idx,
                            "treat": treat,
                            "post": int(rel_t >= 0),
                            "y": y,
                        }
                    )

        df = pd.DataFrame(records)
        df["treat_post"] = df["treat"] * df["post"]
        return df

    # ---- Helper: group means ---------------------------------------------

    @reactive.calc
    def group_means():
        df = sim_data()
        return df.groupby(["rel_time", "treat"])["y"].mean().reset_index()

    # ---- Helper: OLS results ---------------------------------------------

    @reactive.calc
    def ols_result():
        df = sim_data()
        X = df[["post", "treat", "treat_post"]].astype(float)
        X = sm.add_constant(X)
        model = sm.OLS(df["y"].astype(float), X).fit(
            cov_type="HC1"
        )
        return model

    # ---- Helper: Event-study OLS -----------------------------------------

    @reactive.calc
    def event_study_result():
        df = sim_data().copy()
        n_pre = int(input.n_pre())
        n_post = int(input.n_post())
        rel_times = sorted(df["rel_time"].unique())

        # Create dummies for treat * rel_time (omitting t = -1)
        ref_period = -1
        interact_cols = []
        for t in rel_times:
            if t == ref_period:
                continue
            col_name = f"D_{t}"
            df[col_name] = ((df["treat"] == 1) & (df["rel_time"] == t)).astype(float)
            interact_cols.append(col_name)

        # Also include period fixed effects (omit last) and treat dummy
        period_dummies = pd.get_dummies(df["rel_time"], prefix="t", drop_first=True, dtype=float)
        X = pd.concat(
            [
                df[["treat"]].astype(float),
                period_dummies,
                df[interact_cols],
            ],
            axis=1,
        )
        X = sm.add_constant(X)
        model = sm.OLS(df["y"].astype(float), X).fit(cov_type="HC1")

        # Extract interaction coefficients
        coefs = []
        for t in rel_times:
            if t == ref_period:
                coefs.append({"rel_time": t, "coef": 0.0, "se": 0.0, "ci_lo": 0.0, "ci_hi": 0.0})
                continue
            col = f"D_{t}"
            b = model.params[col]
            se = model.bse[col]
            ci = model.conf_int().loc[col]
            coefs.append({"rel_time": t, "coef": b, "se": se, "ci_lo": ci[0], "ci_hi": ci[1]})

        return pd.DataFrame(coefs), model

    # ==================================================================
    # TAB 1 — DiD Plot
    # ==================================================================

    @render.plot
    def did_plot():
        gm = group_means()
        n_pre = int(input.n_pre())
        effect = float(input.treatment_effect())

        fig, ax = plt.subplots(figsize=(9, 5.2))
        fig.patch.set_facecolor("white")
        ax.set_facecolor("#FAFAFA")

        for treat_val, label, clr, marker in [
            (0, "Control", CLR_CONTROL, "o"),
            (1, "Treatment", CLR_TREAT, "s"),
        ]:
            sub = gm[gm["treat"] == treat_val].sort_values("rel_time")
            ax.plot(
                sub["rel_time"],
                sub["y"],
                color=clr,
                marker=marker,
                markersize=7,
                linewidth=2.2,
                label=label,
                zorder=3,
            )

        # Vertical line at treatment
        ax.axvline(
            x=-0.5,
            color=CLR_VLINE,
            linestyle="--",
            linewidth=1.4,
            label="Treatment onset",
            zorder=2,
        )
        ax.fill_betweenx(
            ax.get_ylim(),
            -0.5,
            gm["rel_time"].max() + 0.5,
            color=CLR_TREAT,
            alpha=0.04,
            zorder=0,
        )

        # Annotate DiD estimate
        model = ols_result()
        did_est = model.params["treat_post"]
        did_pval = model.pvalues["treat_post"]

        stars = ""
        if did_pval < 0.001:
            stars = "***"
        elif did_pval < 0.01:
            stars = "**"
        elif did_pval < 0.05:
            stars = "*"

        ax.annotate(
            f"DiD = {did_est:+.2f}{stars}\n(p = {did_pval:.4f})",
            xy=(0.5, 0.5),
            xycoords=("axes fraction", "axes fraction"),
            fontsize=13,
            fontweight="bold",
            color=CLR_DID,
            ha="center",
            va="center",
            bbox=dict(
                boxstyle="round,pad=0.5",
                facecolor="white",
                edgecolor=CLR_DID,
                linewidth=1.5,
                alpha=0.92,
            ),
            zorder=5,
        )

        # Violation warning
        if input.violate_parallel():
            ax.text(
                0.98,
                0.02,
                "Parallel trends violated",
                transform=ax.transAxes,
                fontsize=10,
                color="#CC0000",
                fontstyle="italic",
                ha="right",
                va="bottom",
                bbox=dict(facecolor="#FFF3F3", edgecolor="#CC0000", alpha=0.85, boxstyle="round,pad=0.3"),
                zorder=5,
            )

        ax.set_xlabel("Relative Time Period", fontsize=12, labelpad=8)
        ax.set_ylabel("Outcome (Y)", fontsize=12, labelpad=8)
        ax.set_title(
            "Difference-in-Differences: Group Means Over Time",
            fontsize=14,
            fontweight="bold",
            pad=12,
        )
        ax.legend(loc="upper left", fontsize=10, framealpha=0.95)
        ax.grid(True, color=CLR_GRID, linewidth=0.6, zorder=0)
        ax.xaxis.set_major_locator(ticker.MaxNLocator(integer=True))
        ax.tick_params(labelsize=10)

        fig.tight_layout()
        return fig

    @render.text
    def did_estimate_text():
        model = ols_result()
        b = model.params["treat_post"]
        se = model.bse["treat_post"]
        ci = model.conf_int().loc["treat_post"]
        n = int(model.nobs)
        return (
            f"DiD Estimate (Post x Treat): {b:.4f}  |  "
            f"Robust SE: {se:.4f}  |  "
            f"95% CI: [{ci[0]:.4f}, {ci[1]:.4f}]  |  "
            f"N = {n:,}"
        )

    # ==================================================================
    # TAB 2 — Regression Output
    # ==================================================================

    @render.text
    def regression_table():
        model = ols_result()
        summary = model.summary2()

        header = (
            "=" * 72 + "\n"
            "  OLS Regression: Y = alpha + beta1*Post + beta2*Treat + beta3*(Post x Treat) + e\n"
            "  Robust (HC1) standard errors\n"
            "=" * 72 + "\n\n"
        )

        # Rename index for clarity
        rename_map = {
            "const": "Intercept (alpha)",
            "post": "Post (beta1)",
            "treat": "Treat (beta2)",
            "treat_post": "Post x Treat [DiD] (beta3)",
        }

        params = model.params.rename(index=rename_map)
        bse = model.bse.rename(index=rename_map)
        tvals = model.tvalues.rename(index=rename_map)
        pvals = model.pvalues.rename(index=rename_map)
        ci = model.conf_int().rename(index=rename_map)

        table_header = f"{'Variable':<35s} {'Coef':>10s} {'Std Err':>10s} {'t':>9s} {'P>|t|':>9s} {'[0.025':>10s} {'0.975]':>10s}\n"
        divider = "-" * 95 + "\n"

        rows = ""
        for var in params.index:
            rows += (
                f"{var:<35s} "
                f"{params[var]:>10.4f} "
                f"{bse[var]:>10.4f} "
                f"{tvals[var]:>9.3f} "
                f"{pvals[var]:>9.4f} "
                f"{ci.loc[var, 0]:>10.4f} "
                f"{ci.loc[var, 1]:>10.4f}\n"
            )

        footer = (
            divider
            + f"R-squared:          {model.rsquared:.4f}\n"
            + f"Adj. R-squared:     {model.rsquared_adj:.4f}\n"
            + f"F-statistic:        {model.fvalue:.2f}  (p = {model.f_pvalue:.2e})\n"
            + f"Observations:       {int(model.nobs):,}\n"
            + f"Residual Std Err:   {np.sqrt(model.mse_resid):.4f}\n"
            + divider
        )

        return header + table_header + divider + rows + footer

    # ==================================================================
    # TAB 3 — Event Study
    # ==================================================================

    @render.plot
    def event_study_plot():
        coef_df, _ = event_study_result()

        fig, ax = plt.subplots(figsize=(9, 5.2))
        fig.patch.set_facecolor("white")
        ax.set_facecolor("#FAFAFA")

        pre_mask = coef_df["rel_time"] < 0
        post_mask = coef_df["rel_time"] >= 0

        # Confidence intervals
        ax.fill_between(
            coef_df["rel_time"],
            coef_df["ci_lo"],
            coef_df["ci_hi"],
            alpha=0.15,
            color=CLR_TREAT,
            zorder=1,
        )

        # Error bars + points
        for mask, clr, label in [
            (pre_mask, CLR_CONTROL, "Pre-treatment"),
            (post_mask, CLR_TREAT, "Post-treatment"),
        ]:
            sub = coef_df[mask]
            ax.errorbar(
                sub["rel_time"],
                sub["coef"],
                yerr=[sub["coef"] - sub["ci_lo"], sub["ci_hi"] - sub["coef"]],
                fmt="o",
                color=clr,
                markersize=7,
                capsize=4,
                capthick=1.5,
                linewidth=1.5,
                label=label,
                zorder=3,
            )

        ax.axhline(0, color="#555555", linewidth=1.0, linestyle="-", zorder=2)
        ax.axvline(
            -0.5,
            color=CLR_VLINE,
            linestyle="--",
            linewidth=1.4,
            zorder=2,
        )

        # Reference period marker
        ref = coef_df[coef_df["rel_time"] == -1]
        if not ref.empty:
            ax.plot(
                ref["rel_time"].values[0],
                ref["coef"].values[0],
                marker="D",
                color="#FFD700",
                markersize=10,
                markeredgecolor="#333",
                markeredgewidth=1.2,
                zorder=5,
                label="Reference (t = -1)",
            )

        # Violation warning
        if input.violate_parallel():
            ax.text(
                0.98,
                0.02,
                "Parallel trends violated",
                transform=ax.transAxes,
                fontsize=10,
                color="#CC0000",
                fontstyle="italic",
                ha="right",
                va="bottom",
                bbox=dict(facecolor="#FFF3F3", edgecolor="#CC0000", alpha=0.85, boxstyle="round,pad=0.3"),
                zorder=5,
            )

        ax.set_xlabel("Relative Time Period", fontsize=12, labelpad=8)
        ax.set_ylabel("Coefficient (Treatment x Period)", fontsize=12, labelpad=8)
        ax.set_title(
            "Event-Study Plot: Dynamic Treatment Effects",
            fontsize=14,
            fontweight="bold",
            pad=12,
        )
        ax.legend(loc="upper left", fontsize=10, framealpha=0.95)
        ax.grid(True, color=CLR_GRID, linewidth=0.6, zorder=0)
        ax.xaxis.set_major_locator(ticker.MaxNLocator(integer=True))
        ax.tick_params(labelsize=10)

        fig.tight_layout()
        return fig

    @render.text
    def event_study_text():
        coef_df, model = event_study_result()
        lines = [
            "Event-Study Coefficients (Treat x Relative-Time Dummies, ref = t = -1):",
            "-" * 72,
            f"{'Period':>8s} {'Coef':>10s} {'SE':>10s} {'95% CI':>24s}",
            "-" * 72,
        ]
        for _, row in coef_df.iterrows():
            t = int(row["rel_time"])
            marker = " <-- ref" if t == -1 else ""
            lines.append(
                f"  t={t:>+3d}   {row['coef']:>10.4f} {row['se']:>10.4f}"
                f"   [{row['ci_lo']:>9.4f}, {row['ci_hi']:>9.4f}]{marker}"
            )
        lines.append("-" * 72)
        lines.append(f"Model R-squared: {model.rsquared:.4f}  |  Observations: {int(model.nobs):,}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = App(app_ui, server)
