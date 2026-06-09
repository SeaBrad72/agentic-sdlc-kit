# Design — Slice 8b: Release-readiness "Definition of Deployable"

**Date:** 2026-06-09
**Status:** Approved (design) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** Second sub-slice of Slice 8 (continuity & safe-delivery hardening). Arc-of-record: `docs/superpowers/ideation/2026-06-08-delivery-safety-continuity-gaps.md`. Closes gap **B1** (release-readiness contract not enforced). Enforcement-gate-first, per the locked Slice 8 ordering.

---

## 1. Goal

Convert `DEVELOPMENT-PROCESS.md` §10's "every release declares its rollback path *before* it ships" — and the §4 Release-stage exit criteria (smoke test, monitoring, rollback ready) — from prose into an **enforced, conditional Release gate**. A deployable service must satisfy a "Definition of Deployable" before promotion, mirroring how `conformance/15-factor-checklist.md` gates Review. Pairs a **Manual checklist** (judgment items) with a **companion script** (mechanically-checkable doc artifacts). MINOR → **2.20.0**.

## 2. Why this is MINOR, not MAJOR

The semver rule (`MAINTAINING.md`): MAJOR = a new **universally-required CI gate**. This gate is **conditional** (deployable services only) and lands at a **human checkpoint** (Release), exactly like the existing threat-model / eval / compliance / 15-factor conditional gates — all additive. So it is MINOR. The companion script is a *conditional* check that **skip-passes** when there is no deploy surface; it is not a new mandatory CI gate-id.

## 3. Decisions

- **Checklist + companion script** (the chosen option). The checklist carries the judgment items (was the rollback *actually* tested? are alerts *actually* wired?); the script auto-verifies only what a grep can honestly confirm (the rollback path is *written down*; a smoke test is *referenced*). Enforce the floor without faking the ceiling.
- **Conditional + fail-closed**, mirroring `container-supply-chain.sh`. The script triggers only when the project has a **deploy surface**; otherwise it prints `N/A` and exits 0 — no forcing release-readiness on a library/CLI/batch project (the 7c "don't force where it doesn't belong" principle). This also means it **skip-passes at the kit root** (the kit is not a deployable service), so no "expected to fail at kit root" caveat is needed.
- **Manual + Auto rows in one checklist**, mirroring `audit-evidence-checklist.md` (which already mixes `Manual` and `**Auto:**` rows). The Auto rows name the command (`ci-gates.sh`, `deployable-ready.sh`); the Manual rows require evidence a reviewer signs off.
- **No new CI gate-id.** The 8 application gate-ids (`ci-gates.sh`) are unchanged. Deployability readiness is a *checklist/Review-style* conformance, not one of the 8 pipeline gates — so `ci-gates.sh` and the §14 contract are untouched.
- **Framework anchor, not a crosswalk** — one-line **OWASP DSOMM** nod (deployment/release maturity), per the arc's fold-in decision.
- **Anti-false-assurance is a contract requirement, not a nicety** (added after design review). The split creates a real hazard: an *automated* green check carries more authority than a manual checkbox, so a passing `deployable-ready.sh` could be misread as "safe to deploy" when it only proves the rollback path is *written down*. Two mandatory, reviewed mitigations close this:
  1. **The script's success output must state its own scope** — it confirms documentation presence, explicitly **not** that rollback/alerts/migrations were tested. This wording is part of the deliverable and is verified in §8.
  2. **The checklist must carry a bold "necessary, not sufficient" callout** distinguishing the Auto rows (*documented*) from the Manual rows (*tested / wired*, reviewer-evidenced). The Auto-vs-Manual boundary is the load-bearing honesty of this slice.
- **The check tests itself in CI** (added after design review). To remedy weak dogfooding — the kit has no deploy surface, so plain CI only ever hits the script's N/A path — `deployable-ready.sh` gets a **`--selftest`** mode that builds `mktemp` fixtures and asserts skip/OK/FAIL, mirroring how `agent-autonomy.sh` is its own case-battery. Kit CI runs `--selftest`, regression-locking the positive and FAIL paths in the pipeline, not just at dev time.

## 4. Deliverables

| # | File | Change |
|---|------|--------|
| A | `conformance/definition-of-deployable.md` (new) | Conditional release-readiness checklist (blank table + worked ts-node example), Manual + Auto rows |
| B | `conformance/deployable-ready.sh` (new) | Companion conditional, fail-closed script for the Auto subset; scope-disclaiming success output; `--selftest` fixture battery |
| C | `DEVELOPMENT-PROCESS.md` §7 (gates table) | New conditional gate row: **Definition of Deployable** *(deployable services)* → Release manager + reviewer |
| D | `DEVELOPMENT-PROCESS.md` §4 (Release stage) + §10 (rollback line) | Point "rollback ready" / "declares its rollback path before it ships" at `conformance/definition-of-deployable.md` |
| E | `conformance/README.md` (index + "kinds" note) | Two new index rows (checklist + script) |
| F | `conformance/audit-evidence-checklist.md` | Row: **Release readiness · Definition of Deployable** (CC8.1 / A.8.31, A.8.32; **Auto (conditional)** → `deployable-ready.sh`) |
| G | `.github/workflows/ci.yml` (conformance job) | Three steps: `test -f conformance/definition-of-deployable.md` (present, mirrors 15-factor); run `deployable-ready.sh` (N/A skip-pass at root proves the conditional); run `deployable-ready.sh --selftest` (exercises skip/OK/FAIL fixtures — the positive-path regression-lock) |
| Meta | `VERSION` 2.20.0 · `CHANGELOG.md` · `docs/ROADMAP-KIT.md` (8b row) |

## 5. Detailed design — `conformance/definition-of-deployable.md`

House style matches `15-factor-checklist.md`: a title, a one-paragraph "proves … / conditional" intro naming the Release gate and the N/A rule, a `## How to use`, a **blank** checklist table, then a **worked example**. Column set: `Item · Applies? (Y / N+reason) · Evidence (where/how) · Check`.

**Mandatory header callout (the anti-false-assurance line, verbatim intent):**
> **What the Auto rows prove — and don't.** The `deployable-ready.sh` rows confirm the release-safety procedures are *written down* (RUNBOOK has Deploy + Rollback sections) and a smoke test is *referenced*. They do **not** verify the rollback was tested, alerts are wired, or the migration down-path works — those are the **Manual** rows, signed off by the release manager with evidence. **A green script is necessary, not sufficient.**

Auto rows are labelled *(documented)* and Manual rows that assert behaviour are labelled *(tested / wired)* so the distinction is visible at the row level, not just in the callout.

Rows (each sourced from §4 Release + §10 Safe Change Delivery):

| Item | Check |
|------|-------|
| Rollback path **declared before ship** — preference order flag-off → redeploy previous → revert (§10) | Manual |
| Rollback path **tested** — the chosen path was actually exercised | Manual |
| DB migration **reversible** — down-path tested, expand-contract; **N/A** if no migration | Manual |
| Feature flags have **owner + expiry**; **N/A** if no flags (a flag with no expiry is a defect, §10) | Manual |
| Progressive-delivery plan — canary / blue-green / staged rollout (§10); **N/A** at Stage 1 with reason | Manual |
| Smoke test **defined**, and post-deploy result recorded | Manual |
| Monitoring / alerts wired on the change's critical paths (§3) | Manual |
| Supply-chain CI gates green — SBOM + provenance (§14) | **Auto:** `sh conformance/ci-gates.sh <workflow>` |
| RUNBOOK has a **Deploy** section **and** a **Rollback** section | **Auto:** `sh conformance/deployable-ready.sh` |
| Smoke test **referenced** (RUNBOOK or a workflow) | **Auto:** `sh conformance/deployable-ready.sh` |
| CHANGELOG entry recorded for this release (§15) | Manual |

The worked example fills the table for the ts-node reference profile (a deployable HTTP service) and shows a `N/A` example (e.g. "no DB this release → migration row N/A"), exactly as the 15-factor file demonstrates the N/A convention.

## 6. Detailed design — `conformance/deployable-ready.sh`

POSIX `sh`, `set -eu`, structured like `container-supply-chain.sh` (header comment stating the contract + the conditional/fail-closed rule + the gate it serves). Operates on a **project directory** (`DIR="${1:-.}"`).

**Deploy-surface detection (the conditional trigger).** The project is "deployable" if ANY of:
- a `Dockerfile` exists (at `$DIR` root or one directory deep), **or**
- any `.github/workflows/*.yml` contains an `environment:` key (the 7a protected prod-deploy pattern), **or**
- any workflow declares a job or step id/name matching `deploy`.

If none match → print `N/A: not a deployable service (no Dockerfile / deploy workflow) — skipping` and `exit 0`. (Skip-pass — never a failure. This is what makes the kit root and non-service projects pass cleanly.)

**When deployable, assert (each miss → `FAIL <reason>` + a remediation hint; fail-closed via a `fail=1` accumulator):**
1. `RUNBOOK.md` exists at `$DIR`.
2. `RUNBOOK.md` contains a **Deploy** heading — `grep -Eiq '^#{1,6}[[:space:]].*deploy'`.
3. `RUNBOOK.md` contains a **Rollback** heading — `grep -Eiq '^#{1,6}[[:space:]].*rollback'`.
4. A **smoke-test signal** — `smoke` appears (case-insensitive) in `RUNBOOK.md` **or** any `.github/workflows/*.yml`.

Exit non-zero if any assertion failed; else print a **scope-disclaiming** success line (mandatory wording, verified in §8):
`deployable-ready: OK — release-readiness DOCS present. NOTE: this verifies documentation only, NOT that rollback/alerts/migrations were tested. Those are Manual rows in definition-of-deployable.md requiring release-manager evidence.`
(The N/A skip line carries the same spirit: it states the project has no deploy surface, not that it is "release-ready".)

**`--selftest` mode (the CI regression-lock).** When invoked as `sh conformance/deployable-ready.sh --selftest`, the script does not check the current project; instead it builds `mktemp` fixtures and asserts each outcome, exiting 0 only if all behave:
- empty dir → N/A skip (exit 0);
- `Dockerfile` + `RUNBOOK.md` with Deploy + Rollback headings + a `smoke` mention → OK (exit 0);
- `Dockerfile` + RUNBOOK with Deploy but **no** Rollback heading → FAIL (exit 1) — asserted as the *expected* failure;
- no Dockerfile but a workflow containing `environment:` + complete RUNBOOK → OK (exit 0).
This mirrors `agent-autonomy.sh`'s self-contained case battery and is what makes the positive/FAIL paths regression-locked in kit CI (where the kit root itself only ever exercises the N/A path). Fixtures are left in their `mktemp` dirs (no `rm -rf`, per the 7e guard lesson).

**Robustness (lessons carried from 7c/7d/7e):**
- Grep patterns anchored to heading lines so a passing mention in prose can't satisfy the "section present" checks (a heading is required, not a stray word) — except the smoke *signal*, which is intentionally a looser presence check (a smoke test may be referenced in a CI step name, not a heading).
- Use a here-doc/temp-file accumulator pattern that keeps `fail` in the current shell (avoid the subshell-loses-`fail` trap from 7d).
- Avoid emitting literal destructive command text that the live `.claude/` guard would block (use neutral fixture content in tests).

**Tested (negative + positive, the established regression-lock pattern), using `mktemp -d` fixtures:**
- *N/A:* empty dir → skip-pass (exit 0, prints N/A).
- *Deployable + complete:* dir with a `Dockerfile` + a `RUNBOOK.md` having Deploy + Rollback headings + a `smoke` mention → `OK` (exit 0).
- *Deployable + missing rollback:* `Dockerfile` + RUNBOOK with Deploy but no Rollback heading → `FAIL` (exit 1).
- *Deployable via workflow:* no Dockerfile but a workflow with `environment:` + complete RUNBOOK → `OK`.
- Fixtures are left in `mktemp` dirs (not `rm -rf`'d) to avoid tripping the guard, per the 7e lesson.

## 7. Wiring detail

- **§7 gates table** — insert a row after the 15-Factor row: `| **Definition of Deployable** *(deployable services)* | Is the release safe to promote — rollback ready, smoke + monitoring wired? (\`conformance/definition-of-deployable.md\`) | Release manager + reviewer |`. Update the conditional-gates sentence below the table to include "deployable-services release readiness".
- **§4 Release stage** (line 112) — append to the "rollback ready" clause: "(verified against `conformance/definition-of-deployable.md`)".
- **§10 rollback line** (line 285) — append to "declares its rollback path before it ships": "— captured in `conformance/definition-of-deployable.md`".
- **`conformance/README.md`** — add two index rows (checklist → Release gate; script → Release/CI, conditional). Keep the "Two kinds of check" note accurate (this pairs both kinds for one contract).
- **`audit-evidence-checklist.md`** — insert after the "RUNBOOK · DR / rollback" row: `| Release readiness · Definition of Deployable | CC8.1 / A.8.31, A.8.32 | filled \`definition-of-deployable.md\` + script output | **Auto (conditional):** \`sh conformance/deployable-ready.sh\` | |`.
- **`.github/workflows/ci.yml`** conformance job — add three steps: `- name: Definition-of-Deployable checklist present` → `run: test -f conformance/definition-of-deployable.md`; `- name: Deployable-ready conditional (N/A at kit root)` → `run: sh conformance/deployable-ready.sh`; `- name: Deployable-ready self-test (skip/OK/FAIL fixtures)` → `run: sh conformance/deployable-ready.sh --selftest`.
- **DSOMM anchor** — one line in the checklist intro: "Aligns with OWASP DSOMM (deployment/release maturity)."

## 8. Validation / testing

- `sh conformance/deployable-ready.sh` at the kit root → `N/A … skipping`, exit 0.
- `sh conformance/deployable-ready.sh --selftest` → exit 0 (all four fixture cases behave: skip / OK / FAIL-as-expected / OK-via-workflow).
- **Anti-false-assurance wording present:** the script's OK output contains "documentation only, NOT that rollback/alerts/migrations were tested" (grep-assert in the plan), and `definition-of-deployable.md` contains the bold "necessary, not sufficient" callout.
- `sh conformance/check-links.sh` → 0 (new files' refs resolve; §7/§4/§10/README/audit rows link real paths).
- `sh conformance/ci-gates.sh profiles/*/ci.yml` (all 10) → green (no gate-id change); `profile-completeness.sh`, `agent-autonomy.sh`, `container-supply-chain.sh`, `backlog-adapters.sh`, `guard-wired.sh` → green (no regression).
- `grep` confirms: §7 has the new gate row; `conformance/README.md` indexes both new files; `audit-evidence-checklist.md` has the release-readiness row.
- Kit CI green (the two new conformance steps pass: checklist present; script N/A skip-pass at root).

## 9. Risks & mitigations

- **False assurance — a green script misread as "safe to deploy"** (the primary concern raised at design review). The script only proves release-safety is *documented*, never *tested/wired*. Mitigation (now a contract requirement, §3): the script's success output self-discloses its scope; the checklist carries a bold "necessary, not sufficient" callout; Auto rows are labelled *(documented)* and behavioural Manual rows *(tested / wired)*; the **release manager signs the Manual rows with evidence** — the checklist, not the script, is the gate of record. §8 grep-asserts the wording so it can't silently regress.
- **Weak dogfooding — kit CI only hits the N/A path** (secondary concern). Mitigation: the `--selftest` fixture battery exercises skip/OK/FAIL in kit CI, so a regression in the positive or fail path breaks the pipeline, not just a dev-time run.
- **Deploy-surface detection false-negative** (a deployable project the script calls N/A). Mitigation: three independent triggers (Dockerfile / `environment:` / deploy job); documented in the checklist intro so a reviewer can still apply the Manual checklist even if the script skips. The script *assists*; the checklist is the gate of record.
- **Deploy-surface false-positive at kit root** (script wrongly thinks the kit is deployable and then fails on a missing RUNBOOK.md). Mitigation: the kit root has no root `Dockerfile` and its `.github/workflows/ci.yml` has no `environment:` key and no `deploy` job — verified to hit the N/A path. The §14 doc *snippet* showing `environment: production` lives inside `DEVELOPMENT-STANDARDS.md` (a `.md`, not a workflow), so it cannot trip the detector. (Plan must re-verify this at build time.)
- **Heading-grep too strict/loose.** Mitigation: section checks require a Markdown heading (`#{1,6}`) so prose mentions don't pass; the smoke check is intentionally looser (presence), documented as such.
- **Subshell-loses-`fail`.** Mitigation: current-shell accumulator pattern (7d lesson).
- **Guard blocks test cleanup.** Mitigation: leave `mktemp` dirs; no `rm -rf` text (7e lesson).

## 10. Out of scope

- The progressive-delivery **reference implementation** (Argo Rollouts / Flagger canary) and the **post-deploy smoke gate in the pipeline** — those are **8e**. 8b *defines and gates readiness*; 8e *ships the executable rollout*.
- Any change to the 8 application CI gate-ids or `ci-gates.sh` / §14.
- Load/soak and resilience verification — that is **8d**.
- Auto-grading the judgment items (rollback tested, alerts wired) — intentionally Manual.

## 11. Definition of Done

- `conformance/definition-of-deployable.md` created (blank table + worked ts-node example, Manual + Auto rows, DSOMM anchor, N/A convention shown).
- `conformance/deployable-ready.sh` created — conditional, fail-closed, skip-passes when no deploy surface; **scope-disclaiming success output**; **`--selftest`** exercises skip/OK/FAIL and passes; negative-tested.
- **Anti-false-assurance wording shipped and asserted:** script OK output discloses "documentation only, NOT … tested"; `definition-of-deployable.md` has the bold "necessary, not sufficient" callout + *(documented)*/*(tested / wired)* row labels.
- §7 gate row added; §4 + §10 reference the checklist; `conformance/README.md` indexes both; `audit-evidence-checklist.md` row added.
- `.github/workflows/ci.yml` runs the two new steps; kit CI green.
- All conformance green; `check-links.sh` 0; no §14/gate-id change; no other conformance regressed.
- `VERSION` 2.20.0; CHANGELOG 2.20.0 entry; ROADMAP 8b row.
- Feature branch → PR → **human ratification** (governing-doc surface → **security-owner lens**, per §13/RBAC). Agent never self-merges.
