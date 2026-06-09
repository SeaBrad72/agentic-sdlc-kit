# Design — Slice 8f: DORA metrics collection

**Date:** 2026-06-09
**Status:** Approved (design) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** Sixth and **final** sub-slice of Slice 8 (continuity & safe-delivery hardening). Arc-of-record: `docs/superpowers/ideation/2026-06-08-delivery-safety-continuity-gaps.md`. Closes gap **C1** (DORA defined but not instrumented). **Completes Slice 8.**

---

## 1. Goal

Instrument the DORA four + the two agentic-specific signals that `DEVELOPMENT-PROCESS.md` §14 maps but nothing collects. Measurement is the precondition for the soft→hard-gating maturity the kit already describes (§9 error budgets, §14). 8f ships a **collection reference** (how to derive each metric from GitHub data + the maturity-gating path + a dashboard pattern) and a **real, scoped collector** (`scripts/dora.sh`) that computes the universally GitHub-derivable subset and is honest about the rest. MINOR → **2.24.0**.

## 2. Decisions

- **Reference + a real scoped `scripts/dora.sh`** (the chosen option). The script computes what is universally derivable from any GitHub repo (release cadence, PR lead time, review latency) and **documents** the metrics that need deployment + incident data (deploy-frequency-proper, change-fail rate, MTTR, retro-closure) as adopter-wired. Concrete and dogfoodable, honest about the subset.
- **No new baseline conformance gate** (the discussed decision). DORA is a **feedback instrument, not a gate**. A *presence* check ("is a collector wired") measures the wrong thing (you copied a file ≠ you measure-and-improve — theatre). A *value-gate* ("change-fail < X") as a **baseline** is harmful — it punishes early-stage projects, and the kit deliberately makes DORA-value-gating a **maturity step** (§9 soft→hard "promotes with scale"), not a baseline. The *acted-upon* signal (retro-closure) is judgment, already carried by §14. So: no gate.
- **CI smokes the collector, never the numbers** (the honest enforcement). Kit CI runs `sh scripts/dora.sh --selftest` (deterministic, no network) to prove the collector *executes and degrades cleanly*. It does not gate on metric values.
- **Graceful degradation → exit 0.** `scripts/dora.sh` is a **report**, not a gate: any `gh` call that fails (no auth / missing scope / no network) makes that metric print "unavailable (needs `gh` + scope)" and the script continues, exiting 0. A reporting tool must never fail a pipeline for lack of data — that would punish a project for being early.
- **`gh`-only dependency.** The script uses `gh` and `gh`'s built-in `--jq` (gojq) for date math — **no separate `jq` binary**. POSIX `sh`, dash-clean, guard-safe (no destructive text).
- **The maturity-gating path is documented, not built.** The reference shows *how* to promote to value-gating (gate on change-fail / MTTR) when a project reaches the §9 maturity stage — the right home for DORA enforcement (opt-in at scale).
- **Framework anchor** — the DORA program (Accelerate / State of DevOps) named in the reference; the kit's §14 table already maps to it.

## 3. Deliverables

| # | File | Change |
|---|------|--------|
| A | `docs/operations/dora-metrics.md` (new) | The reference: per-metric GitHub data source + derivation, maturity-gating path, dashboard pattern |
| B | `scripts/dora.sh` (new) | Real collector for the GitHub-derivable subset; graceful degradation; `--selftest` |
| C | `DEVELOPMENT-PROCESS.md` §14 | Reference the doc + name the collector |
| D | `DEVELOPMENT-PROCESS.md` §9 | Cross-reference the maturity-gating path in the doc (so "promote to hard-gate" has a how-to) |
| E | `conformance/README.md` | One-line note: DORA is measurement-enablement (no gate); collector is CI-smoked |
| F | `.github/workflows/ci.yml` | A `dora.sh --selftest` smoke step (conformance job) |
| Meta | `VERSION` 2.24.0 · `CHANGELOG.md` · `docs/ROADMAP-KIT.md` (8f row + **Slice 8 complete**) |

## 4. Detailed design — `docs/operations/dora-metrics.md`

Stack-neutral reference (joins `docs/operations/`). Sections:
- **Purpose + the DORA map** — re-state the §14 four + the 2 agentic signals; this doc is the *how to collect*.
- **Per metric: GitHub data source + derivation** —
  - **Deployment frequency** — the GitHub **Deployments API** / **Releases** (count per window). `scripts/dora.sh` uses releases as the universal proxy; true deploy events are adopter-wired (a deploy workflow that records a Deployment).
  - **Lead time for changes** — commit/PR **created → merged (→ deployed)** timestamps; `scripts/dora.sh` computes the **PR created→merged** proxy (the deploy leg is adopter-wired).
  - **Change-failure rate** — deployments that caused an incident / required a revert or hotfix ÷ total deployments. **Adopter-wired:** needs an incident signal (an `incident`/`postmortem` label or the §15 incident record) + deployment events.
  - **MTTR** — incident **open → resolved** duration (the §15 / 8a postmortem records / issue close times). **Adopter-wired.**
  - **Review latency (agentic)** — PR **created → first review** (or → merged proxy). `scripts/dora.sh` computes it — the human-bottleneck signal (§14).
  - **Retro-action closure (agentic)** — share of retro action items closed; from backlog labels (a `retro`/`adjust` label). **Adopter-wired** (backlog-backend specific, §6).
- **The maturity-gating path** — per §9 (error budgets soft→hard): **default = surface in metrics + retros, do not gate**; **maturity step = gate** (e.g., freeze non-critical releases when change-fail or MTTR breaches a threshold). Shows the opt-in promotion, the right home for DORA enforcement. Cross-references §9 + the §14 table.
- **Dashboard pattern** — a flow-metrics dashboard (the DORA "Four Keys" reference project, or Grafana over the GitHub data, or a board digest §12). Cadence/format set per org (a configuration point, not a fixed ritual; ties to §12 stakeholder visibility).
- **Tooling (Org-owned)** — Four Keys, Grafana, a metrics warehouse, or `scripts/dora.sh` for the GitHub-derivable subset. The kit standardizes the **definitions and the derivation**, not the dashboard.

## 5. Detailed design — `scripts/dora.sh`

POSIX `sh`, `set -eu`, in `scripts/` (peer of `incept.sh`, `new-profile.sh`). Header comment states: this is a **report**, not a gate; it computes the GitHub-derivable subset and names the rest adopter-wired; it exits 0 even with no data.

**Usage:**
```
sh scripts/dora.sh [--window DAYS]   # default window 30; reports for the current repo
sh scripts/dora.sh --selftest        # deterministic degradation self-test (no network)
```

**Behaviour (default run):**
- Resolve the window (default 30 days). For each GitHub-derivable metric, attempt the `gh` call; **wrap each in graceful degradation** — on any non-zero `gh` exit (no `gh`, no auth, missing scope, no network), print `<metric>: unavailable (needs gh auth + <scope>)` and continue.
  - **Release cadence** — `gh release list` count within the window → "N releases in <window>d (deployment-frequency proxy)".
  - **PR lead time** — `gh pr list --state merged --json createdAt,mergedAt --jq '<avg merged-created hours>'` → "avg PR lead time: H.h h (lead-time proxy; deploy leg adopter-wired)". Empty set → "no merged PRs in window".
  - **Review latency** — `gh pr list --state merged --json createdAt,reviews/mergedAt --jq '<avg created→first-review or →merged hours>'` → "avg review latency: H.h h".
- Always print the **adopter-wired** block: deployment-frequency (true) · change-failure rate · MTTR · retro-action closure → each with the one-line "how to wire" pointer to `docs/operations/dora-metrics.md`.
- If `gh` itself is absent → print a single clear "`gh` not found — install + `gh auth login`; the GitHub-derivable metrics need it" and still print the adopter-wired block. **Exit 0.**

**`--selftest`:** deterministically exercises the **graceful-degradation contract** without network — force the no-`gh` path (e.g. run with a `PATH` that hides `gh`, or an internal `DORA_FORCE_NO_GH=1` switch the selftest sets) and assert: the script prints the "unavailable"/"gh not found" messaging, prints the adopter-wired block, and **exits 0**. (The metric *math* lives in `gh --jq` and is exercised by a real authenticated run, documented in the reference — not in CI, which has no guaranteed PR-read scope.) Print `dora --selftest: OK`.

**Robustness (carried lessons):** `set -eu`; each `gh` call guarded so a failure can't abort the script (`out=$(gh ... 2>/dev/null) || { echo unavailable; ...; }` in current-shell form, no subshell-loses-state); dash-clean; `_`-prefixed helper params; explicit `exit 0` at the end of the default path; no `rm`/destructive text (guard-safe); leaves no temp state.

## 6. Wiring detail

- **`DEVELOPMENT-PROCESS.md` §14** — after the agentic-signals sentence, add: "**Collect them:** `docs/operations/dora-metrics.md` (per-metric GitHub data source + dashboard pattern); `scripts/dora.sh` reports the GitHub-derivable subset (release cadence, PR lead time, review latency)."
- **`DEVELOPMENT-PROCESS.md` §9** — append to the error-budget **maturity-step** line: "(the same soft→hard promotion applies to DORA change-fail / MTTR — see `docs/operations/dora-metrics.md`)."
- **`conformance/README.md`** — a `>` note: "**DORA metrics (measurement-enablement, no gate):** §14's DORA four + agentic signals are *collected*, not gated — `scripts/dora.sh` (GitHub-derivable subset, CI-smoked) + `../docs/operations/dora-metrics.md` (derivation + the maturity-gating path). Value-gating is a §9 maturity step, not a baseline check."
- **`.github/workflows/ci.yml`** conformance job — add a step: `- name: DORA collector smoke (executes + degrades cleanly)` → `run: sh scripts/dora.sh --selftest`.
- **Meta** — `VERSION` 2.24.0; CHANGELOG 2.24.0 (note: **completes Slice 8**); `docs/ROADMAP-KIT.md` 8f row marked ✅ + a "Slice 8 complete" note.

## 7. Validation / testing

- `sh scripts/dora.sh --selftest` → `dora --selftest: OK`, exit 0 (degradation path asserted).
- `sh scripts/dora.sh` at the kit root → runs; with `gh` authenticated it prints real release-cadence / PR-lead-time / review-latency for this repo + the adopter-wired block; without `gh`/auth it prints "unavailable"/"gh not found" + the adopter-wired block; **exit 0** either way.
- `sh -n scripts/dora.sh` + (`dash -n` if available) → clean.
- `sh conformance/check-links.sh` → 0 (the new doc's references resolve; §14/§9/README references to `docs/operations/dora-metrics.md` + `scripts/dora.sh` valid).
- All other conformance green (no gate-id change; no new conformance script).
- Kit CI green (the dora smoke step passes — it exits 0 regardless of `gh`/auth in the runner).

## 8. Risks & mitigations

- **CI runner lacks PR-read scope / network** → a *bare* `gh` run could print "unavailable". Mitigation: CI runs `--selftest` (forced no-`gh`, deterministic, no network) — it asserts the degradation contract and exits 0; it never needs `gh` data.
- **A `gh` call hangs / errors mid-run** → could abort under `set -e`. Mitigation: every `gh` call is guarded (`|| { ...; }`) in current-shell form; the script can't be aborted by a failing metric.
- **Over-claiming the script "measures DORA"** → it only covers the GitHub-derivable subset. Mitigation: the script and the reference are explicit — deploy-freq-proper / change-fail / MTTR / retro-closure are labelled **adopter-wired** with how-to pointers.
- **DORA misused as a baseline gate** → the reference states value-gating is a **§9 maturity step**, not a baseline; no conformance gate is added.
- **`gh --jq` date-function portability** → gojq (gh's engine) supports `fromdateiso8601`; the math runs wherever `gh` is installed, no separate `jq`. Empty-set division guarded in the jq expression.

## 9. Out of scope

- A hosted dashboard / the deployment + incident wiring (Org-owned).
- Any DORA **value-gate** baseline check (deliberately a §9 maturity step).
- The agentic retro-closure collector (backlog-backend specific, §6 — documented as adopter-wired).
- Any change to the 8 application CI gate-ids or §14's gate set.

## 10. Definition of Done

- `docs/operations/dora-metrics.md` created (per-metric GitHub derivation incl. adopter-wired ones, the §9 maturity-gating path, a dashboard pattern, DORA anchor, tooling Org-owned).
- `scripts/dora.sh` created — computes the GitHub-derivable subset via `gh`; graceful degradation → exit 0; `--selftest` asserts the degradation contract; `gh`-only; dash-clean; guard-safe.
- §14 references the doc + names the collector; §9 cross-references the maturity-gating path; `conformance/README.md` note; kit CI runs the dora smoke step.
- All conformance green; `check-links.sh` 0; no new gate-id; no baseline DORA gate.
- `VERSION` 2.24.0; CHANGELOG 2.24.0 entry (**completes Slice 8**); ROADMAP 8f row + Slice 8 marked complete.
- Feature branch → PR → **human ratification** (governing-doc surface → **security-owner lens**). Agent never self-merges.
