# deveconomics-toolkit

Eleven Shiny apps for development econometrics: six in Python (`python-shiny/`),
five in R (`r-shiny/`). No shared package, no build step. Each app is a single
`app.py` or `app.R` plus its own `requirements.txt`.

## Commands

```bash
pip install -r requirements-dev.txt
python -m pytest tests/ -q                       # the arithmetic
cd python-shiny/rct-power-calculator && shiny run app.py
cd r-shiny/gini-lorenz && Rscript -e 'shiny::runApp(".")'
```

## What these apps are for, and what that demands

Someone sizes a real trial with the power calculator. Someone quotes a benefit
cost ratio from the CBA app in a proposal. A wrong number here does not throw an
exception, it goes into a document. So the standard for anything that computes
is a check against closed form *and*, where the quantity is a sampling property,
against simulation.

**A power formula cannot be checked by eye.** All three solve modes in the power
calculator were wrong for as long as the repository existed, each in the
direction that flatters a study, and reading the code did not reveal it. Running
it did.

## The defect this repository is shaped around

`Var(xbar_treat - xbar_control) = sigma^2/n_t + sigma^2/n_c`. That factor of two
was missing from every per-arm expression in the power calculator:

| solve mode | reported | true |
|---|---|---|
| n per arm, d=0.2, 80% power | 197 | 393 (197 per arm simulates at **51%** power) |
| power at 393 per arm | 97.8% | 80.0% |
| MDE at 393 per arm | 0.141 SD | 0.200 SD |

`n_total` was right throughout, because `1 / (p * (1-p))` equals 4 at p = 0.5 and
already carries the two. That is exactly why it survived: the one output anyone
would sanity-check against a published table was correct.

The arithmetic now lives in `python-shiny/rct-power-calculator/power.py`, which
imports no Shiny and is therefore testable, and `app.py` calls into it. **Do not
inline a formula back into `app.py`.** The file mixed two conventions before
(the allocation panel used total N and was correct; everything else used per-arm
and was not), which is how the inconsistency hid.

## Watch out for

- **One convention: N is the total sample**, split `p` treatment and `1-p`
  control. Per-arm figures are derived from it. If you add a formula, add it to
  `power.py` in those terms and add a simulation test.
- **The module uses the normal approximation, not t**, so it understates the
  required sample slightly at small n: 63 per arm at d = 0.5 where G*Power says
  64, 25 at d = 0.8 where G*Power says 26. Simulated, 79.6% and 79.1% against a
  nominal 80%. This is pinned by `test_normal_approximation_shortfall_stays_small`
  and stated in the README. Do not quietly switch to t without updating both.
- **Bonferroni divides by k-1, not k.** With k arms there are k-1 comparisons
  against control.
- **Verified correct, leave alone unless you re-verify:** the Alkire-Foster
  implementation in `mpi-explorer` (M0 = H x A, with censored headcount ratios
  computed as `(dep_matrix[:, j] * is_poor).sum() / n`), and the NPV, BCR, IRR,
  growth and discounted-payback functions in `cost-benefit-analysis`, which were
  checked against closed form on 2026-09-22 and agree exactly.
- **The R apps have no test coverage**, only a parse check. 5,113 lines. If you
  touch `gini-lorenz` or `poverty-line-analysis`, the Gini and the poverty
  measures both have closed forms worth asserting; that work has not been done.

## CI

`.github/workflows/ci.yml` compiles every Python app, imports each one and
asserts it defines a Shiny `App`, runs the test suite, and parses every R app.

It previously ran, in full:

```
python -m py_compile python-shiny/*/app.py 2>/dev/null || echo "Syntax check complete"
```

The `|| echo` means the step cannot fail. A syntax error printed "Syntax check
complete" and exited 0. The R apps were not checked at all. If you add a step
here, make sure a failure actually fails: no trailing `|| echo`, no `2>/dev/null`
swallowing the reason, and `set -euo pipefail` in any loop.
