# Meta-control panel #31 — Golden-path trigger-filter parity (T4 item 1) + item 5 close

**Date:** 2026-06-30 · **Version:** 3.79.0 → 3.80.0 · **Cadence:** light (5-lens) per-slice M verdict (A5)
**Verdict: GO**

## Slice summary

T4 item 1: lock the golden-path workflow's `paths:` trigger filter to the set of scripts its jobs invoke (so a change to an exercised script can never silently skip the end-to-end proof), widen the filter to clear a 7-file drift, register it as the new headline claim `golden-path-trigger`. T4 item 5 closed as a roadmap correction (the private-repo `enforce_admins` 404 caveat already shipped in `review-lane.md` at v3.48.11; `branch-protection.sh` does not verify `enforce_admins`, so no note belongs there).

New check `conformance/golden-path-filter-parity.sh` (models `ci-selftest-coverage.sh`): extracts the filter set + the invoked-script set, asserts **invoked ⊆ filter** — one-directional (an over-broad filter is conservative, not a bug), glob-aware (a `dir/**` entry covers files under it, surviving a filter rewrite), kit-self N/A in adopter trees, non-vacuous 5-case selftest.

## 5-lens

| Lens | Finding |
|------|---------|
| **Direction/proportion** | Right-weighted. Closes a *live* drift (7 files already adrift), not an empty surface. One new claim + one check + two ci.yml steps; no new gate/guard. Coarse-glob alternative rejected (would undermine the path-filter's purpose); inverse parity rejected (YAGNI). |
| **Correctness** | `reviewer` → **APPROVE** (no Critical/Important). Behaviourally verified: real-workflow RED names exactly 7; widened GREEN; selftest mutation-tested; apply.py base64 == reviewed check; shellcheck clean. |
| **Security** | `security-reviewer` → **PASS-WITH-NOTES**. Two-matcher guard symmetry intact (`conformance/` blanket-covered by both matchers — no new gap); no secret exposure; apply.py writes only fixed in-root literals (no traversal); claim honest. |
| **Non-vacuity** | Teeth proven on the real artifact (drop a widened entry → RED naming it). 5 selftest cases, each load-bearing (mutation: neuter `covered` → dirty case stops detecting; revert anchored comment-strip → hash-in-string case fails). |
| **Coherence** | Clone-proven green end-to-end: parity / actionlint-valid / claims-registry (new claim PASS) / ci-selftest-coverage / golden-path-wired / badge-version / shellcheck / `verify --require` (37 control-checks, 0 failed). Idempotent re-run = no-op. |

## Folds applied in-slice (from the dual review)

- **(security 3a)** comment-strip anchored to whitespace/line-start (`sed -E 's/(^|[[:space:]])#.*//'`) so a `#` inside a shell string cannot hide a same-line invocation; added the 5th selftest case (`#`-in-string) — mutation-proven load-bearing.
- **(security caveat)** header documents the extraction's honest limits (prefix-literal / single-line / comment-anchored; `cd dir && sh bare.sh` and variable-indirection are coverage gaps, never destructive).
- **(security LOW)** apply.py chmods the new check `0o755` to match sibling conformance scripts.
- **(correctness Minor 1)** the `grep -v 'paths:'` exclusion is documented as defensive-by-construction (a harvested filter entry is self-satisfying, so the line cannot change a verdict — intent, not teeth).
- **(correctness Minor 2)** plan doc's stale CI step name (`paths: …`) aligned to the shipped colon-free name.

## Routed / banked (non-blocking)

- **F-gp1** — harden the extractor for `cd dir && sh bare.sh` and variable-indirected invocations (per-segment parse) if the golden-path jobs ever adopt that convention. Coverage gap, not a vuln.
- **(inherited)** the broader inverse-leak guard for `docs/architecture/` (panel #29) remains banked.

## Ship conditions

- Governance close (marker `3.80.0 GO` + this log row) is human-run (M2-S5 — the agent does not self-certify its GO).
- Standard solo control-plane ship: admin-merge sanctioned when `conformance` is green and the only red is `control-plane-ratification` (by-design).
