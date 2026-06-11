# Gate Parity — design (eval · observability/SLO · threat-model)

**Status:** design approved (brainstorm), pre-plan.
**Shape:** a small **two-slice arc**. Slice 1 — eval-driven development (v2.46.0). Slice 2 — observability/SLO + threat-model (v2.47.0). Both **MINOR** (conditional checks + templates; no new *universal* gate).

---

## Problem

The kit's signature move is **declared artifact + executable conformance** for every gate. Three gates are *named in prose* but never got that treatment, leaving them thinner than their siblings (a11y → sign-off template + `conditional-gates.sh`; resilience → `resilience-readiness.md` + `resilience-ready.sh`; DR → `dr-readiness.md` + `dr-ready.sh`):

- **A. Eval-driven development** — strong discipline in `DEVELOPMENT-STANDARDS.md` (regression gate, versioned set, pinned judge) + a concrete harness in `profiles/ml.md`, but **no `EVAL-PLAN` template and no `eval-ready` conformance**. It is the only conditional gate (a11y/load/eval) lacking the declared-artifact + readiness treatment — and the most instrumental for an AI-powered, agentic shop.
- **B. Observability / SLO** — Factor 14 Telemetry + §9 SLOs/error-budgets exist in prose, but **no `observability-ready` check** in the resilience/DR readiness family verifies the posture is declared + recorded.
- **C. Threat model** — a real §7 security gate + a DoR flag + a security-owner role, but **no `THREAT-MODEL-TEMPLATE`** (every other gate-artifact is templated: TEST-PLAN, UAT-SIGNOFF, A11Y-SIGNOFF, BIA, POSTMORTEM, WAIVER).

## Honesty invariant (whole arc)

Each new readiness check verifies the discipline is **declared / recorded**, never that it **actually works** — evals *pass*, the system is *observable in prod*, the threat model is *good*. Those stay the §7 gate (evals run in CI) or **Manual** operator/security-owner rows. No green check overclaims — the same "necessary, not sufficient" framing as `resilience-ready` / `dr-ready`.

---

## Slice 1 — Eval-driven development (the AI-feature gate) · v2.46.0

### Components
- **`templates/EVAL-PLAN-TEMPLATE.md`** (new) — the AI-feature eval artifact, in the kit's guidance-blockquote style. Sections: task-quality dataset + rubric (exact-match / graded / LLM-as-judge); **regression threshold** (the bar the CI eval gate enforces); safety / red-team set; the **pinned judge + model version**; where the harness lives (→ profile, e.g. `evals/run.py`); a **model-upgrade-regression** trigger (on any model/prompt/param change, evals re-run — this is the §7 Eval gate's trigger, restated as a checklist item); and an **Auto vs Manual** honesty note.
- **`conformance/eval-readiness.md`** (new) — checklist: **Auto** (eval plan present · regression threshold recorded · eval gate wired) vs **Manual** (the evals actually pass · the red-team set actually ran · the judge is independent of the system under test).
- **`conformance/eval-ready.sh`** (new) — conditional, fail-closed (mirrors `resilience-ready.sh`'s N/A · OK · FAIL shape + `--selftest`).
  - **Trigger (binds when AI feature):** an `evals/` directory exists, OR an `EVAL-PLAN.md` exists, OR the RUNBOOK/`CLAUDE.md` declares `AI feature:` (a project marker). Otherwise **N/A** (no model → no eval gate) — N/A is the honest skip for a CLI/library/batch job.
  - **When bound, asserts (documented-readiness, not execution):** an `EVAL-PLAN.md` is present; a **regression threshold** is recorded (not the `[threshold]` placeholder); and the eval gate is wired (the RUNBOOK or a CI workflow references the eval suite). FAIL on a bound project missing any; N/A otherwise.
  - `--selftest` fixtures: no-AI-signal → N/A; AI-signal + complete plan/threshold/gate → OK; AI-signal + `[threshold]` placeholder → FAIL; AI-signal + no plan → FAIL.

### Wiring
- `conformance/verify.sh` — add `check doc eval-ready sh conformance/eval-ready.sh` (the "doc" tier, alongside resilience/dr — it is a documentation-readiness check).
- `.github/workflows/ci.yml` (control-plane `cp`) — add `eval-ready.sh --selftest` step.
- `DEVELOPMENT-STANDARDS.md` §14 conditional-gates block — the **Eval** line gains the readiness pointer (`conformance/eval-readiness.md`), matching how the Load line points to `resilience-readiness.md`.
- `DEVELOPMENT-STANDARDS.md` AI-Evaluations section + `templates/` table in `CLAUDE.md` — one-line pointers to the template.
- `conformance/README.md` index row; `conformance/audit-evidence-checklist.md` row (Eval gate → **Auto (conditional):** `eval-ready.sh`); compliance-crosswalk row if a natural home exists (else skip — no forced row).
- `conformance/conditional-gates.sh` already asserts the eval gate is *named* in §7 — leave it; the new check is the *readiness* complement.

### Release
`VERSION` → 2.46.0; CHANGELOG; no roadmap (standalone). MINOR.

---

## Slice 2 — Observability/SLO + Threat-model · v2.47.0

### B. Observability / SLO (mirror resilience-ready)
- **`conformance/observability-readiness.md`** (new) — **Auto** (SLOs declared · golden-signals/telemetry recorded as wired) vs **Manual** (the signals are actually emitted in prod · alerts actually fire · the SLO/error-budget is actually tracked).
- **`conformance/observability-ready.sh`** (new) — conditional on a **deploy surface** (Dockerfile / deploy workflow, exactly as `resilience-ready`). Binds → asserts the RUNBOOK records **SLOs** (`SLOs:` with a real target, not placeholder) and **telemetry wired** (`Telemetry:` metrics+traces+health with a date/marker, not placeholder); N/A for non-deployed. `--selftest`.
- **`templates/RUNBOOK-TEMPLATE.md`** — add the SLO + telemetry record lines (in the §8 Monitoring area, same style as the resilience `Load/soak tested:` line). Keep the keyed phrases in sync with the script.
- **Wiring:** `verify.sh` (`check doc observability-ready`), CI selftest step (control-plane `cp`), `conformance/README.md` row, `audit-evidence-checklist.md` row, `DEVELOPMENT-STANDARDS.md` Factor 14 / §9 pointer.

### C. Threat-model (template-only)
- **`templates/THREAT-MODEL-TEMPLATE.md`** (new) — STRIDE/LINDDUN-lite: system/asset summary · data classification · trust boundaries · threats (per category) · mitigations / controls · residual risk · **security-owner sign-off**. Kit guidance-blockquote style; mirrors `A11Y-SIGNOFF-TEMPLATE.md`.
- **Wiring (no script):** named in `DEVELOPMENT-PROCESS.md` §7 (security gate) where threat-model is required; the DoR threat-model flag (`CLAUDE.md`) gains the template pointer; `DEVELOPMENT-STANDARDS.md` security section + `CLAUDE.md` `templates/` table get one-line pointers. No conformance check — threat modeling is a human/security-owner-ratified artifact; presence ≠ quality, and "sensitive" is not honestly auto-detectable.

### Release
`VERSION` → 2.47.0; CHANGELOG. MINOR.

---

## Testing / verification (both slices)

- New scripts: `dash -n` clean; `--selftest` green (plain and under `CI=true` for any escalation logic); the live check is N/A at the kit root (the kit is a framework — no `evals/`, no deploy surface) — confirm N/A, not FAIL, and that the script is **not** forced into `verify.sh`'s unconditional control aggregate inappropriately (it joins as a `doc` check like resilience/dr, which are N/A at kit root).
- `check-links.sh`, `doc-budget.sh`, `verify.sh` green; bootstrap-into-temp unaffected.
- Fresh templates read as **incomplete/placeholder** through their checks (no false PASS): a fresh RUNBOOK with placeholder SLO/telemetry → observability FAIL; an `EVAL-PLAN.md` with `[threshold]` → eval FAIL.

## Governance

Each slice: feature branch → PR → **human ratification** (Bradley merges; agent never self-merges). `DEVELOPMENT-STANDARDS.md` / `DEVELOPMENT-PROCESS.md` edits are governing-doc changes → **security-owner lens** (esp. the threat-model wiring). Each `ci.yml` selftest step via the control-plane `cp`. Kit stays generic/anonymized ([[kit-anonymization]]).

## Out of scope / deferred
- No `threat-model` conformance script (template-only, by decision).
- Cost/FinOps already covered (STANDARDS §2 / §9) — not in scope.
- The pre-story **product-discovery front end** is the next, separate frontier (Bradley's stated direction after this).
