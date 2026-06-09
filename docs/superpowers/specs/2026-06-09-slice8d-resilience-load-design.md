# Design — Slice 8d: Resilience + load/soak verification

**Date:** 2026-06-09
**Status:** Approved (design) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** Fourth sub-slice of Slice 8 (continuity & safe-delivery hardening). Arc-of-record: `docs/superpowers/ideation/2026-06-08-delivery-safety-continuity-gaps.md`. Closes gap **A3** (resilience principles + load/soak asserted but never verified). Anchors to chaos-engineering / SRE reliability practice.

---

## 1. Goal

Verify what the kit currently only asserts. `DEVELOPMENT-STANDARDS.md` §4 lists resilience principles (structured errors, idempotency, retry-with-backoff, circuit breakers, graceful degradation) and §6 says "Load-test before any public launch" — but nothing checks that any of it was exercised. 8d adds a **resilience-verification reference** (the "how"), a **conditional resilience-readiness checklist** (the judgment), and a **thin record-script** (proof the drills were run + recorded). MINOR → **2.22.0**.

## 2. Decisions

- **Separate conformance artifact** (the chosen option), not an extension of `definition-of-deployable.md`. Resilience (survives failure & load) is conceptually distinct from deployability (ships & rolls back safely); a separate file keeps each checklist focused and matches the per-concern-file pattern (15-factor, dr-readiness).
- **Checklist + thin record-script** (the chosen option). Manual rows hold the judgment (breaker tripped, degraded gracefully, survived soak); the script auto-verifies only the documented floor — a **recorded** load/soak date and fault-injection date. **No load-test tooling detection** — k6/Locust/Gatling/JMeter are stack-variable, so detecting them would be theater or stack-coupled; the script checks a *dated record*, stack-neutral.
- **Conditional + fail-closed**, mirroring `deployable-ready.sh`. Detection of a **deploy surface** (Dockerfile / `environment:` workflow / deploy job); no surface → N/A skip-pass. (A library/CLI has no dependencies to circuit-break or load to soak.) Skip-passes at the kit root.
- **Proportionate N/A — deployable-style, not DR-style.** Unlike 8c (escalate-only, self-incriminating N/A), 8d uses the plain conditional N/A of `deployable-ready.sh`. Rationale: blast radius. A missed DR gate = irreversible data loss → self-incriminating N/A + DoD anchor. A missed resilience gate = degraded reliability, caught at Review → the §7 gate + checklist-as-gate-of-record is proportionate. (Matching enforcement weight to blast radius is the design principle.)
- **No DoD anchor** (unlike 8c). The §7 conditional Review gate is the enforcement point; the existing DoD "monitoring/alerting on critical paths" already covers the production-observability floor. Keeps the DoD from bloating.
- **Anti-false-assurance is a contract requirement** (carried from 8b/8c). A recorded "Fault-injection drill: 2026-06-01" does **not** prove the system *is* resilient. The script's success output self-discloses it checks the drills were **recorded**, not that they **passed**; the checklist holds "breaker tripped / degraded gracefully / survived soak" as **Manual** rows. Bold "a green script is necessary, not sufficient" callout + *(documented)* / *(verified)* labels. `--selftest` battery regression-locks the paths in kit CI.
- **Framework anchor, not a crosswalk** — one-line chaos-engineering (Principles of Chaos) / SRE reliability nod in the reference + checklist.

## 3. Deliverables

| # | File | Change |
|---|------|--------|
| A | `docs/operations/resilience-verification.md` (new) | The "how": fault-injection drill + load/soak test + recording |
| B | `conformance/resilience-readiness.md` (new) | Conditional resilience checklist (Manual + Auto rows, callout) |
| C | `conformance/resilience-ready.sh` (new) | Conditional, fail-closed record-script; scope-disclaiming; `--selftest` |
| D | `templates/RUNBOOK-TEMPLATE.md` §8 | Resilience-record lines ("Load/soak tested: [date]" · "Fault-injection drill: [date]") |
| E | `DEVELOPMENT-STANDARDS.md` §4 + §6 | Reference the verification doc ("verify these — don't just assert them") |
| F | `DEVELOPMENT-PROCESS.md` §7 (gates) | New conditional **Resilience readiness** gate (deployable services) |
| G | `conformance/README.md` + `audit-evidence-checklist.md` | Index the two checks; a reliability audit row |
| H | `.github/workflows/ci.yml` | `resilience-ready.sh` present + N/A + `--selftest` (3 steps) |
| Meta | `VERSION` 2.22.0 · `CHANGELOG.md` · `docs/ROADMAP-KIT.md` (8d row) |

## 4. Detailed design — `docs/operations/resilience-verification.md`

Stack-neutral reference (new `docs/operations/` dir — a home for ops/reliability references; 8e progressive-delivery will join it). Sections:
- **Purpose + chaos-engineering/SRE anchor** + the **do-no-harm rule in bold:** *inject faults in staging / an isolated environment, never production.*
- **Fault-injection drill** — kill or degrade a dependency (DB, cache, downstream API) in staging; observe that the **circuit breaker trips**, **retries back off** (not a thundering herd), and the service **degrades gracefully** (serves a fallback / sheds load) rather than crashing. Record date + what was observed.
- **Load / soak test** — drive sustained, realistic load; watch **latency (p95/p99), error rate, and resource trends**; find the **knee** (where latency/errors break the §6 budget); a **soak** (hours) catches leaks and slow degradation. Record date + the actuals vs. the §6 perf budget.
- **What "passed" means** — breaker/degradation behaved, and load/soak stayed within the §6 budget with no leak. Recording a date is the **floor**; a *passed* drill (the Manual rows in `conformance/resilience-readiness.md`) is the **bar**.
- **Cadence** — pre-launch (§6) and after any change to a dependency or the failure-handling path; periodically (recurring maintenance, §15).
- **Tooling (Org-owned)** — load generators (k6/Locust/Gatling/JMeter/vegeta) and fault-injection (toxiproxy, a chaos tool, or manual dependency-kill) are platform choices. The kit standardizes the **practice and the proof**, not the tool.

## 5. Detailed design — `conformance/resilience-readiness.md` + `conformance/resilience-ready.sh`

### Checklist (`resilience-readiness.md`)
Mirrors `definition-of-deployable.md`: intro (Checklist-type; conditional N/A for non-deployable; chaos/SRE + §4/§6 anchor), the bold **"a green script is necessary, not sufficient"** callout, `## How to use`, blank table, worked example, N/A note. Rows:

| # | Item | Check |
|---|------|-------|
| 1 | Retry with backoff exercised on a transient failure (§4) *(verified)* | Manual |
| 2 | Circuit breaker **trips** when a dependency fails (§4) *(verified)* | Manual |
| 3 | Graceful degradation — killed dependency → service degrades, not crashes (§4) *(verified)* | Manual |
| 4 | Idempotency verified for retryable operations (§4) *(verified)* | Manual |
| 5 | Fault-injection drill **run** — date recorded (RUNBOOK §8) *(documented)* | **Auto:** `resilience-ready.sh` |
| 6 | Load test **run** — latency/error within the §6 budget *(verified)* | Manual |
| 7 | Soak test clean — no leak / latency creep over time *(verified)* | Manual |
| 8 | Load/soak **run** — date recorded (RUNBOOK §8) *(documented)* | **Auto:** `resilience-ready.sh` |

### Script (`resilience-ready.sh`)
POSIX `sh`, `set -eu`, structured like `deployable-ready.sh` (deploy-surface detection helper `wf_is_deploy`, `_`-prefixed params, `exit $?`). Operates on a project dir.

**Deploy-surface detection** (identical to `deployable-ready.sh`): a `Dockerfile`, OR a workflow `environment:` key, OR a `deploy` job key. None → `N/A: … no deploy surface … skipping`, exit 0.

**When deployable, assert (fail-closed accumulator):**
1. `RUNBOOK.md` exists.
2. A **"Load/soak tested:"** line whose value is not the `[date]` placeholder.
3. A **"Fault-injection drill:"** line whose value is not the `[date]` placeholder.

Success → scope-disclaiming line: `resilience-ready: OK — resilience drills are RECORDED. NOTE: this does NOT verify the system is actually resilient (breaker tripped, degraded gracefully, survived soak) — those are Manual rows in resilience-readiness.md requiring on-call/operator evidence.`

**`--selftest`** fixtures (left in `mktemp`): empty → N/A; stateless-but-no-deploy-surface → N/A; deployable (Dockerfile) + RUNBOOK with both real dated records → OK; deployable + "Load/soak tested: [date]" placeholder → FAIL; deployable + missing "Fault-injection drill:" line → FAIL.

**Robustness (carried lessons):** anchored greps; current-shell `fail` accumulator (7d); leave fixtures (7e); `_`-prefixed params + explicit `exit $?` (8b); a comment noting the RUNBOOK §8 record-string coupling (8c review); a negative selftest fixture for the conditional.

## 6. Wiring detail

- **`templates/RUNBOOK-TEMPLATE.md` §8** — after the existing "Error tracking…" line, add: `- **Resilience verification** *(deployable services — see `docs/operations/resilience-verification.md`)*: Load/soak tested: [date] · Fault-injection drill: [date]`.
- **`DEVELOPMENT-STANDARDS.md` §4** — append to the graceful-degradation bullet: "Verify these under failure — don't just assert them (`docs/operations/resilience-verification.md`)."
- **`DEVELOPMENT-STANDARDS.md` §6** — the "Load-test before any public launch" clause → "Load-test (and soak-test) before any public launch (`docs/operations/resilience-verification.md`)."
- **`DEVELOPMENT-PROCESS.md` §7** — insert a row after the DR-readiness gate: `| **Resilience readiness** *(deployable services)* | Do resilience + load/soak verifications pass — breaker trips, degrades gracefully, within perf budget? (\`conformance/resilience-readiness.md\`) | On-call / operator + reviewer |`; add "Resilience-readiness" to the conditional-gates sentence.
- **`conformance/README.md`** — two index rows (checklist → Review/recurring conditional; script → Review/CI conditional on a deploy surface).
- **`audit-evidence-checklist.md`** — a row after the DR-drill row: `| Resilience · load/soak + fault-injection | A1.2, A1.3 / A.8.6, A.8.16 | resilience-verification records (RUNBOOK §8) + drill logs | **Auto (conditional):** \`sh conformance/resilience-ready.sh\` | |`.
- **`.github/workflows/ci.yml`** conformance job — three steps: checklist present; `resilience-ready.sh` (N/A at root); `resilience-ready.sh --selftest`.

## 7. Validation / testing

- `sh conformance/resilience-ready.sh` at kit root → `N/A …`, exit 0 (kit root has no deploy surface — re-verify at build, same as `deployable-ready.sh`).
- `sh conformance/resilience-ready.sh --selftest` → all fixtures behave (N/A / N/A / OK / FAIL-placeholder / FAIL-missing), exit 0.
- Scope-disclaimer wording present (grep-assert): "does NOT verify the system is actually resilient".
- Checklist callout present; `(documented)` / `(verified)` labels present.
- `sh conformance/check-links.sh` → 0; all other conformance green (no gate-id change); `sh -n` + `dash -n` clean on `resilience-ready.sh`.
- Kit CI green (the three new steps pass).

## 8. Risks & mitigations

- **False assurance — a recorded drill misread as "it's resilient."** Mitigation (contract): script self-discloses scope; checklist holds the behavioural rows as Manual; bold callout; grep-asserted wording.
- **Deploy-surface false-negative** (a service the detector calls N/A). Mitigation: same three triggers as `deployable-ready.sh`; the checklist is the gate of record; a negative selftest fixture. (Proportionate plain N/A — resilience blast radius is reliability, not data loss, so no escalate-only framing.)
- **Record-string coupling** — the script greps for "Load/soak tested:" / "Fault-injection drill:" which must match the RUNBOOK §8 wording. Mitigation: an inline comment in the script noting the coupling (8c lesson).
- **Subshell-loses-`fail` / guard-blocks-cleanup / param clobber.** Mitigations: current-shell accumulator (7d); leave fixtures (7e); `_`-prefixed params (8b).

## 9. Out of scope

- Progressive-delivery reference + post-deploy smoke gate — **8e**.
- DORA metrics collection — **8f**.
- Real load-test / chaos tooling or configs (Org-owned; the kit standardizes the practice + proof).
- Any change to the 8 application CI gate-ids or §14.
- A DoD anchor or a hard Inception gate (proportionate to blast radius — Review gate only).

## 10. Definition of Done

- `docs/operations/resilience-verification.md` created (fault-injection + load/soak how-to, isolated-env do-no-harm rule, recorded ≠ passed, chaos/SRE anchor).
- `conformance/resilience-readiness.md` (callout, Manual + Auto rows, worked example, N/A note) + `conformance/resilience-ready.sh` (conditional, fail-closed, scope-disclaiming, `--selftest`, dash-clean) created; the five fixture cases pass.
- RUNBOOK §8 resilience records; §4 + §6 reference the verification doc; §7 conditional Resilience-readiness gate.
- `conformance/README.md` indexes both; `audit-evidence-checklist.md` reliability row; kit CI runs present + N/A + selftest.
- All conformance green; `check-links.sh` 0; no §14/gate-id change; anti-false-assurance wording shipped + grep-asserted.
- `VERSION` 2.22.0; CHANGELOG 2.22.0 entry; ROADMAP 8d row.
- Feature branch → PR → **human ratification** (governing-doc surface → **security-owner lens**). Agent never self-merges.
