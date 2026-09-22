"""Power, sample size and MDE for a two-arm trial with optional clustering.

Kept separate from `app.py` so the arithmetic can be tested without a browser or
a Shiny runtime. Every formula here is checked against a simulated t-test in
`tests/test_power.py`; do not change one without re-running that.

One convention throughout: **N is the total sample**, split `p` to treatment and
`1 - p` to control. Per-arm helpers are derived from it rather than computed
separately. The app previously mixed the two conventions, and the per-arm
expressions were missing the factor of two that comes from

    Var(xbar_treat - xbar_control) = sigma^2 / n_t + sigma^2 / n_c

so the standard error of the *difference* was understated. Every affected answer
erred in the direction that flatters a study: at d = 0.2, alpha = 0.05 two-sided
and 80% power the tool asked for 197 per arm, which simulates at 51% power; it
reported 97.8% power for a design with 80%; and it quoted an MDE of 0.141 SD
where the true value is 0.200 SD. `n_total` was right throughout, because
1 / (p * (1 - p)) already carries the two at p = 0.5.

Limitation, stated rather than buried: these use the normal approximation, not
the t distribution, so they understate the required sample slightly at small n.
At d = 0.5 this module asks for 63 per arm where G*Power asks for 64, and at
d = 0.8 for 25 where G*Power asks for 26; simulated, those land at 79.6% and
79.1% power against a nominal 80%. The gap is under one percentage point above
about 25 per arm and widens below it. `tests/test_power.py` pins its size.
"""

import numpy as np
from scipy import stats

__all__ = [
    "design_effect", "z_alpha", "se_standardised",
    "n_total", "n_per_arm", "power", "mde",
]


def design_effect(cluster_size, icc):
    """Moulton factor for equally sized clusters: 1 + (m - 1) * rho."""
    return 1.0 + (cluster_size - 1) * icc


def z_alpha(alpha, two_sided=True, n_arms=2):
    """Critical value, Bonferroni-adjusted for comparisons against a control arm.

    With k arms there are k - 1 such comparisons, so alpha is divided by k - 1.
    """
    a = alpha / (n_arms - 1) if n_arms > 2 else alpha
    return stats.norm.ppf(1 - a / 2) if two_sided else stats.norm.ppf(1 - a)


def se_standardised(n_total_, p=0.5, de=1.0):
    """Standard error of the treatment-control difference, in SD units.

    This is the single place the factor of two lives. With n_t = p*N and
    n_c = (1-p)*N, Var(difference) = sigma^2 * (1/n_t + 1/n_c)
    = sigma^2 / (N * p * (1-p)), inflated by the design effect.
    """
    return np.sqrt(de / (n_total_ * p * (1.0 - p)))


def n_total(effect_size, alpha=0.05, target_power=0.8, p=0.5, de=1.0,
            two_sided=True, n_arms=2):
    """Total sample needed to detect `effect_size` (in SD) at `target_power`."""
    za = z_alpha(alpha, two_sided, n_arms)
    zb = stats.norm.ppf(target_power)
    return (za + zb) ** 2 * de / (effect_size ** 2 * p * (1.0 - p))


def n_per_arm(effect_size, alpha=0.05, target_power=0.8, p=0.5, de=1.0,
              two_sided=True, n_arms=2):
    """(n_treatment, n_control) for the same design.

    At p = 0.5 both equal 2 * (z_a + z_b)^2 * de / d^2, the textbook two-sample
    figure. The app used to report half of this.
    """
    N = n_total(effect_size, alpha, target_power, p, de, two_sided, n_arms)
    return N * p, N * (1.0 - p)


def power(effect_size, n_total_, alpha=0.05, p=0.5, de=1.0,
          two_sided=True, n_arms=2):
    """Power of a design with total sample `n_total_`."""
    za = z_alpha(alpha, two_sided, n_arms)
    return float(stats.norm.cdf(effect_size / se_standardised(n_total_, p, de) - za))


def mde(n_total_, alpha=0.05, target_power=0.8, p=0.5, de=1.0,
        two_sided=True, n_arms=2):
    """Smallest effect (in SD) a design with total sample `n_total_` can detect."""
    za = z_alpha(alpha, two_sided, n_arms)
    zb = stats.norm.ppf(target_power)
    return float((za + zb) * se_standardised(n_total_, p, de))
