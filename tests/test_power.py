"""The RCT power calculator, checked against closed form and against simulation.

These exist because every one of the calculator's three solve modes was wrong,
in the direction that flatters a study, and nothing caught it: CI ran
`py_compile ... || echo "Syntax check complete"`, which cannot fail.

The defect was a missing factor of two from Var(xbar_t - xbar_c) = 2 sigma^2 / n.
At d = 0.2, alpha = 0.05 two-sided, 80% power the tool asked for 197 per arm.
Simulated, 197 per arm gives 51% power.

A power formula cannot be checked by eye, which is why the simulation tests are
here rather than only the algebraic ones. They are slow-ish and exact enough:
40,000 replications puts the Monte Carlo standard error on a power near 0.8 at
about 0.002.
"""
import pathlib
import sys

import numpy as np
import pytest
from scipy import stats

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent
                       / "python-shiny" / "rct-power-calculator"))
import power as pw  # noqa: E402

ALPHA = 0.05


def simulated_power(n_per_arm, d, alpha=ALPHA, reps=40_000, seed=7):
    """Empirical rejection rate of a two-sample t-test."""
    rng = np.random.default_rng(seed)
    a = rng.normal(0.0, 1.0, size=(reps, n_per_arm))
    b = rng.normal(d, 1.0, size=(reps, n_per_arm))
    return float((stats.ttest_ind(a, b, axis=1).pvalue < alpha).mean())


# --------------------------------------------------------------------------
# Closed form
# --------------------------------------------------------------------------

@pytest.mark.parametrize("d,expected", [(0.2, 393), (0.5, 63), (0.8, 25)])
def test_n_per_arm_matches_the_textbook_two_sample_figure(d, expected):
    """n per arm = 2 (z_a + z_b)^2 / d^2. The app used to report half of this."""
    n_t, n_c = pw.n_per_arm(d, ALPHA, 0.8)
    assert int(np.ceil(n_t)) == expected
    assert int(np.ceil(n_c)) == expected


def test_power_and_sample_size_are_inverses():
    for d in (0.1, 0.2, 0.35, 0.5):
        N = pw.n_total(d, ALPHA, 0.8)
        assert abs(pw.power(d, N, ALPHA) - 0.8) < 1e-6, f"round trip failed at d={d}"


def test_mde_and_power_are_inverses():
    for N in (200, 785, 4000):
        m = pw.mde(N, ALPHA, 0.8)
        assert abs(pw.power(m, N, ALPHA) - 0.8) < 1e-6, f"round trip failed at N={N}"


def test_unequal_allocation_costs_sample():
    """50/50 is optimal under equal variances, so anything else needs more N."""
    balanced = pw.n_total(0.2, ALPHA, 0.8, p=0.5)
    for p in (0.2, 0.3, 0.7, 0.8):
        assert pw.n_total(0.2, ALPHA, 0.8, p=p) > balanced


def test_design_effect_is_the_moulton_factor():
    assert pw.design_effect(1, 0.05) == 1.0, "singleton clusters cost nothing"
    assert pw.design_effect(20, 0.05) == pytest.approx(1.95)
    assert pw.design_effect(20, 0.0) == 1.0, "zero ICC costs nothing"


def test_clustering_requires_more_sample_in_proportion_to_the_design_effect():
    de = pw.design_effect(20, 0.05)
    assert pw.n_total(0.2, ALPHA, 0.8, de=de) == pytest.approx(
        pw.n_total(0.2, ALPHA, 0.8) * de
    )


def test_one_sided_needs_less_than_two_sided():
    assert pw.n_total(0.2, ALPHA, 0.8, two_sided=False) < pw.n_total(0.2, ALPHA, 0.8)


def test_bonferroni_adjustment_applies_to_comparisons_against_control():
    """k arms means k - 1 comparisons, so alpha is divided by k - 1, not by k."""
    assert pw.z_alpha(0.05, n_arms=2) == pytest.approx(stats.norm.ppf(1 - 0.025))
    assert pw.z_alpha(0.05, n_arms=3) == pytest.approx(stats.norm.ppf(1 - 0.0125))
    assert pw.z_alpha(0.05, n_arms=4) == pytest.approx(stats.norm.ppf(1 - 0.05 / 3 / 2))


# --------------------------------------------------------------------------
# Simulation. The only check that would have caught the original defect.
# --------------------------------------------------------------------------

@pytest.mark.parametrize("d,target", [(0.2, 0.80), (0.3, 0.80), (0.5, 0.90)])
def test_recommended_sample_actually_delivers_the_requested_power(d, target):
    n_t, _ = pw.n_per_arm(d, ALPHA, target)
    got = simulated_power(int(np.ceil(n_t)), d)
    assert abs(got - target) < 0.02, (
        f"d={d}: asked for {target:.0%} power, {int(np.ceil(n_t))} per arm "
        f"simulates at {got:.1%}"
    )


def test_the_old_formula_would_fail_this_suite():
    """Pins the size of the original error so a regression is recognisable.

    The previous expression was (z_a + z_b)^2 / d^2, without the two. At d = 0.2
    that is 197 per arm, and 197 per arm is a badly under-powered trial.
    """
    za, zb = stats.norm.ppf(0.975), stats.norm.ppf(0.8)
    old_n = int(np.ceil((za + zb) ** 2 / 0.2 ** 2))
    assert old_n == 197
    assert simulated_power(old_n, 0.2) < 0.60, "the old n should be badly under-powered"


@pytest.mark.parametrize("n_per_arm_,d", [(393, 0.2), (100, 0.4), (63, 0.5)])
def test_reported_power_matches_simulation(n_per_arm_, d):
    stated = pw.power(d, 2 * n_per_arm_, ALPHA)
    got = simulated_power(n_per_arm_, d)
    assert abs(stated - got) < 0.02, (
        f"tool states {stated:.3f}, simulation gives {got:.3f}"
    )


def test_normal_approximation_shortfall_stays_small():
    """The module uses z, not t, so it understates n slightly at small samples.

    This is a real and known limitation, pinned here rather than hidden. G*Power,
    which uses the t distribution, asks for 64 per arm at d = 0.5 and 26 at
    d = 0.8 where this module asks for 63 and 25. Simulated, those land at 79.6%
    and 79.1% against a nominal 80%. Below about 30 per arm the gap widens, and
    the README says so.
    """
    for d, target in ((0.5, 0.80), (0.8, 0.80)):
        n_t, _ = pw.n_per_arm(d, ALPHA, target)
        got = simulated_power(int(np.ceil(n_t)), d)
        shortfall = target - got
        assert 0 <= shortfall < 0.015, (
            f"d={d}: normal approximation is {shortfall:.3f} short of nominal, "
            f"which is more than the documented gap"
        )


def test_reported_mde_is_detectable_at_the_stated_power():
    n_arm = 400
    m = pw.mde(2 * n_arm, ALPHA, 0.8)
    got = simulated_power(n_arm, m)
    assert abs(got - 0.80) < 0.02, f"MDE {m:.3f} simulates at {got:.1%} power"
