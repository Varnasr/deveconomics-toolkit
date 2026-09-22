"""
RCT Power Calculator — Impact Mojo
Calculate sample size, statistical power, and minimum detectable effects
for randomized controlled trials commonly used in development economics.
"""

from shiny import App, reactive, render, ui
import numpy as np
import power as pw
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use("Agg")

# --- UI ---
app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("RCT Power Calculator"),
        ui.hr(),
        ui.input_radio_buttons(
            "solve_for",
            "Solve for:",
            choices={
                "sample_size": "Sample Size",
                "power": "Power",
                "mde": "Min. Detectable Effect",
            },
            selected="sample_size",
        ),
        ui.hr(),
        ui.panel_conditional(
            "input.solve_for !== 'mde'",
            ui.input_numeric(
                "effect_size", "Effect size (standardized, Cohen's d)", value=0.2, min=0.01, max=3.0, step=0.01
            ),
        ),
        ui.panel_conditional(
            "input.solve_for !== 'power'",
            ui.input_slider("power", "Statistical power (1 - β)", min=0.5, max=0.99, value=0.8, step=0.01),
        ),
        ui.panel_conditional(
            "input.solve_for !== 'sample_size'",
            ui.input_numeric("n_per_arm", "Sample size per arm", value=100, min=10, max=100000, step=10),
        ),
        ui.input_slider("alpha", "Significance level (α)", min=0.01, max=0.10, value=0.05, step=0.01),
        ui.input_radio_buttons(
            "test_type",
            "Test type:",
            choices={"two_sided": "Two-sided", "one_sided": "One-sided"},
            selected="two_sided",
        ),
        ui.hr(),
        ui.h5("Clustering"),
        ui.input_switch("clustered", "Cluster-randomized design", value=False),
        ui.panel_conditional(
            "input.clustered",
            ui.input_numeric("icc", "Intra-cluster correlation (ICC)", value=0.05, min=0.0, max=1.0, step=0.01),
            ui.input_numeric("cluster_size", "Average cluster size", value=20, min=2, max=1000, step=1),
        ),
        ui.hr(),
        ui.h5("Treatment Arms"),
        ui.input_numeric("n_arms", "Number of treatment arms", value=2, min=2, max=10, step=1),
        ui.input_slider(
            "treat_share", "Share in treatment (for 2-arm)", min=0.1, max=0.9, value=0.5, step=0.05
        ),
        width=340,
    ),
    ui.navset_card_tab(
        ui.nav_panel(
            "Result",
            ui.output_ui("main_result"),
            ui.output_plot("power_curve", height="420px"),
        ),
        ui.nav_panel(
            "Sensitivity",
            ui.output_plot("sensitivity_plot", height="500px"),
        ),
        ui.nav_panel(
            "About",
            ui.markdown(
                """
### RCT Power Calculator

This tool helps development economists and practitioners plan **randomized controlled trials**
by computing the relationship between:

- **Sample size** — total number of observations needed
- **Statistical power** — probability of detecting a true effect (1 − β)
- **Minimum detectable effect (MDE)** — smallest effect you can reliably detect

#### Key features

- **Cluster-randomized designs**: Accounts for intra-cluster correlation via the design effect
- **Multiple treatment arms**: Adjusts for Bonferroni correction with >2 arms
- **Flexible allocation**: Vary treatment/control split (optimal at 50/50 for equal-variance designs)

#### Formulas

For a two-sample t-test, the sample size per arm is:

**n = (z_{α/2} + z_β)² × 2σ² / δ²**

Where δ is the effect size, σ is the standard deviation, and z values correspond to the chosen
significance level and power.

For cluster-randomized trials, multiply by the **design effect**:

**DE = 1 + (m − 1) × ρ**

where m is the cluster size and ρ is the ICC.

#### References

- Duflo, E., Glennerster, R., & Kremer, M. (2007). Using randomization in development economics research.
- Bloom, H. S. (1995). Minimum detectable effects.
- Donner, A., & Klar, N. (2000). Design and analysis of cluster randomization trials.
"""
            ),
        ),
    ),
    title="RCT Power Calculator — Impact Mojo",
    fillable=True,
)


def server(input, output, session):

    @reactive.calc
    def design_effect():
        if input.clustered():
            return pw.design_effect(input.cluster_size(), input.icc())
        return 1.0

    @reactive.calc
    def compute_result():
        de = design_effect()
        p = input.treat_share()
        two_sided = input.test_type() == "two_sided"
        kw = dict(p=p, de=de, two_sided=two_sided, n_arms=input.n_arms())

        if input.solve_for() == "sample_size":
            n_t, n_c = pw.n_per_arm(
                input.effect_size(), input.alpha(), input.power(), **kw
            )
            return {
                "type": "sample_size",
                "n_treatment": int(np.ceil(n_t)),
                "n_control": int(np.ceil(n_c)),
                "n_per_arm": int(np.ceil(max(n_t, n_c))),
                "n_total": int(np.ceil(n_t + n_c)),
                "de": de,
            }

        # For the other two modes the user supplies a per-arm figure, so the
        # equivalent total is what the formulas take.
        n_tot = input.n_per_arm() / max(p, 1 - p)

        if input.solve_for() == "power":
            return {
                "type": "power",
                "power": pw.power(input.effect_size(), n_tot, input.alpha(), **kw),
                "de": de,
            }

        return {
            "type": "mde",
            "mde": pw.mde(n_tot, input.alpha(), input.power(), **kw),
            "de": de,
        }

    @output
    @render.ui
    def main_result():
        r = compute_result()
        if r["type"] == "sample_size":
            return ui.div(
                ui.h2(f"N = {r['n_total']:,}", style="color: #2c6fbb; margin-top:20px;"),
                ui.p(f"Total sample size needed: {r['n_total']:,}"),
                ui.p(f"Treatment: {r['n_treatment']:,}  |  Control: {r['n_control']:,}"),
                ui.p(f"Design effect: {r['de']:.2f}") if r["de"] > 1 else None,
                style="text-align:center; padding: 30px;",
            )
        elif r["type"] == "power":
            pct = r["power"] * 100
            color = "#2ecc71" if r["power"] >= 0.8 else "#e74c3c"
            return ui.div(
                ui.h2(f"Power = {pct:.1f}%", style=f"color: {color}; margin-top:20px;"),
                ui.p("Adequately powered" if r["power"] >= 0.8 else "Under-powered — consider increasing N or effect size"),
                ui.p(f"Design effect: {r['de']:.2f}") if r["de"] > 1 else None,
                style="text-align:center; padding: 30px;",
            )
        else:
            return ui.div(
                ui.h2(f"MDE = {r['mde']:.3f} SD", style="color: #8e44ad; margin-top:20px;"),
                ui.p(f"Minimum detectable effect: {r['mde']:.4f} standard deviations"),
                ui.p(f"Design effect: {r['de']:.2f}") if r["de"] > 1 else None,
                style="text-align:center; padding: 30px;",
            )

    @output
    @render.plot
    def power_curve():
        two_sided = input.test_type() == "two_sided"
        fig, ax = plt.subplots(figsize=(8, 4))
        de = design_effect()

        if input.solve_for() == "sample_size":
            d = input.effect_size()
            ns = np.arange(10, 2001, 10)
            powers = [pw.power(d, 2 * n, input.alpha(), p=0.5, de=de,
                               two_sided=two_sided, n_arms=input.n_arms()) for n in ns]
            ax.plot(ns, powers, color="#2c6fbb", linewidth=2)
            ax.axhline(y=input.power(), color="#e74c3c", linestyle="--", alpha=0.7, label=f"Target power = {input.power()}")
            r = compute_result()
            ax.axvline(x=r["n_per_arm"], color="#2ecc71", linestyle="--", alpha=0.7, label=f"Required n/arm = {r['n_per_arm']}")
            ax.set_xlabel("Sample size per arm")
            ax.set_ylabel("Statistical power")
            ax.set_title("Power curve by sample size")

        elif input.solve_for() == "power":
            ds = np.linspace(0.01, 1.0, 200)
            n = input.n_per_arm()
            powers = [pw.power(d, 2 * n, input.alpha(), p=0.5, de=de,
                               two_sided=two_sided, n_arms=input.n_arms()) for d in ds]
            ax.plot(ds, powers, color="#8e44ad", linewidth=2)
            ax.axvline(x=input.effect_size(), color="#e74c3c", linestyle="--", alpha=0.7, label=f"Your effect = {input.effect_size()}")
            ax.set_xlabel("Effect size (Cohen's d)")
            ax.set_ylabel("Statistical power")
            ax.set_title(f"Power curve by effect size (n/arm = {n})")

        else:  # mde
            ns = np.arange(10, 2001, 10)
            mdes = [pw.mde(2 * n, input.alpha(), input.power(), p=0.5, de=de,
                           two_sided=two_sided, n_arms=input.n_arms()) for n in ns]
            ax.plot(ns, mdes, color="#8e44ad", linewidth=2)
            ax.axvline(x=input.n_per_arm(), color="#e74c3c", linestyle="--", alpha=0.7, label=f"Your n/arm = {input.n_per_arm()}")
            r = compute_result()
            ax.axhline(y=r["mde"], color="#2ecc71", linestyle="--", alpha=0.7, label=f"MDE = {r['mde']:.3f}")
            ax.set_xlabel("Sample size per arm")
            ax.set_ylabel("MDE (standard deviations)")
            ax.set_title("MDE curve by sample size")

        ax.legend()
        ax.grid(True, alpha=0.3)
        fig.tight_layout()
        return fig

    @output
    @render.plot
    def sensitivity_plot():
        two_sided = input.test_type() == "two_sided"
        fig, axes = plt.subplots(2, 2, figsize=(10, 8))
        de = design_effect()

        # Power vs N for different effect sizes
        ax = axes[0, 0]
        ns = np.arange(20, 1501, 10)
        for d in [0.1, 0.2, 0.3, 0.5]:
            powers = [pw.power(d, 2 * n, input.alpha(), p=0.5, de=de,
                               two_sided=two_sided, n_arms=input.n_arms()) for n in ns]
            ax.plot(ns, powers, label=f"d = {d}", linewidth=1.5)
        ax.axhline(y=0.8, color="gray", linestyle=":", alpha=0.5)
        ax.set_xlabel("N per arm")
        ax.set_ylabel("Power")
        ax.set_title("Power by sample size & effect size")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

        # MDE vs N for different power levels
        ax = axes[0, 1]
        ns = np.arange(20, 1501, 10)
        for pwr in [0.7, 0.8, 0.9, 0.95]:
            mdes = [pw.mde(2 * n, input.alpha(), pwr, p=0.5, de=de,
                           two_sided=two_sided, n_arms=input.n_arms()) for n in ns]
            ax.plot(ns, mdes, label=f"Power = {pwr}", linewidth=1.5)
        ax.set_xlabel("N per arm")
        ax.set_ylabel("MDE (SD)")
        ax.set_title("MDE by sample size & power")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

        # Power vs ICC (if clustering enabled)
        ax = axes[1, 0]
        if input.clustered():
            iccs = np.linspace(0.0, 0.5, 100)
            d = input.effect_size() if input.solve_for() != "mde" else 0.2
            n = input.n_per_arm() if input.solve_for() != "sample_size" else 200
            m = input.cluster_size()
            for m_val in [10, 20, 50, 100]:
                des = [pw.design_effect(m_val, icc) for icc in iccs]
                powers = [pw.power(d, 2 * n, input.alpha(), p=0.5, de=de_val,
                                   two_sided=two_sided, n_arms=input.n_arms())
                          for de_val in des]
                ax.plot(iccs, powers, label=f"Cluster size = {m_val}", linewidth=1.5)
            ax.axhline(y=0.8, color="gray", linestyle=":", alpha=0.5)
            ax.set_xlabel("ICC")
            ax.set_ylabel("Power")
            ax.set_title("Power by ICC & cluster size")
            ax.legend(fontsize=8)
        else:
            treat_shares = np.linspace(0.1, 0.9, 100)
            d = input.effect_size() if input.solve_for() != "mde" else 0.2
            for n in [50, 100, 200, 500]:
                powers = [pw.power(d, n, input.alpha(), p=p_share, de=de,
                                   two_sided=two_sided, n_arms=input.n_arms())
                          for p_share in treat_shares]
                ax.plot(treat_shares, powers, label=f"N total = {n}", linewidth=1.5)
            ax.axhline(y=0.8, color="gray", linestyle=":", alpha=0.5)
            ax.set_xlabel("Treatment share")
            ax.set_ylabel("Power")
            ax.set_title("Power by treatment allocation")
            ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

        # N required vs effect size for different power levels
        ax = axes[1, 1]
        ds = np.linspace(0.05, 0.8, 100)
        for pwr in [0.7, 0.8, 0.9, 0.95]:
            ns_required = [pw.n_total(d, input.alpha(), pwr, p=0.5, de=de,
                                      two_sided=two_sided, n_arms=input.n_arms()) / 2
                           for d in ds]
            ax.plot(ds, ns_required, label=f"Power = {pwr}", linewidth=1.5)
        ax.set_xlabel("Effect size (d)")
        ax.set_ylabel("N per arm")
        ax.set_title("Required N by effect size & power")
        ax.set_ylim(0, 3000)
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

        fig.suptitle("Sensitivity Analysis", fontsize=14, fontweight="bold")
        fig.tight_layout()
        return fig


app = App(app_ui, server)
