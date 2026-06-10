# Slice 9g — Stack-Decision Aid (design)

**Date:** 2026-06-10 · **Arc:** Slice 9, Tier 2 (R7) · **Version target:** MINOR → **v2.32.0**
**Input:** review stack-undecided persona (scored **5/10**): *"`new-profile.sh` and the custom path are excellent, but the self-labeled '⭐ key step' gives zero comparison material — no per-profile 'best for,' no matrix; the full-stack (SPA+API) case is unaddressed; and `incept` silently defaults the undecided to typescript-node."* The creation path is fine; the **decision** path is the gap.

## Scope (ratified at brainstorm)
Central comparison guide **and** per-profile sections (drift-guarded by a completeness check); a loud-not-silent incept default; full-stack guidance. Docs + a small incept notice + a completeness conformance check. No loop-machinery change.

## Components

### 1. `docs/STACK-SELECTION.md` (new — the decision aid)
- **Comparison matrix** — one row per shipped profile; columns **Best for · Avoid when · Typical domain/runtime**. The at-a-glance "compare, don't guess" view START-HERE §2 lacks. Content per stack (refined in the plan, kept accurate/non-hype):
  - **typescript-node** — full-stack web / APIs / SPAs / serverless, JS ecosystem & fast iteration · avoid CPU-bound numeric / hard-real-time.
  - **python** — data/ML, scripting, APIs, rapid dev · avoid perf-critical hot loops without native extensions.
  - **go** — networked services, CLIs, high-concurrency, single-binary cloud infra · avoid rich GUI / data-science.
  - **java-spring** — large transactional enterprise services, mature JVM ecosystem · avoid cold-start-sensitive tiny serverless.
  - **kotlin** — modern-language JVM services / Android · avoid non-JVM targets.
  - **dotnet** — C#/Azure enterprise, high-perf services · avoid quick throwaway scripts.
  - **rust** — performance/safety-critical, systems, WASM · avoid rapid CRUD where velocity dominates.
  - **ml** — model training/serving, eval-driven work · avoid plain web APIs without ML.
  - **data-engineering** — ETL/ELT, batch/stream pipelines, warehouses · avoid interactive apps/APIs.
  - **terraform** — infrastructure-as-code · not an application stack (pair with an app profile).
- **Per-stack "Best for / Avoid when" blurb** — the canonical short text (matrix row is the one-liner).
- **Full-stack / polyglot (SPA + API) guidance** — pick a **primary profile per deployable service**; in a monorepo, run `incept` per service (each gets its own profile + CI) **or** choose the API stack as primary and record the frontend stack in **ADR-000**. Guidance, not new machinery.
- **Don't see your stack?** → `scripts/new-profile.sh` + `profiles/_TEMPLATE.md` (existing custom path).
- Linked from **START-HERE §2** (as its comparison material) and `README.md`.

### 2. Per-profile "Best for / Avoid when" (10 × `profiles/<stack>.md`)
A short `## Best for / Avoid when` section near the top (after the title, before §1 Toolchain) + a one-line pointer: *"Choosing a stack? Compare all profiles → `../docs/STACK-SELECTION.md`."* Discoverable while reading a single profile; the matrix aggregates them.

### 3. Loud-not-silent incept default (`scripts/incept.sh`)
Track whether `--stack` was passed (`STACK_EXPLICIT=0`; set `1` in the `--stack` arm). After input collection, if not explicit, print to stderr: *"notice: no --stack given — using '<STACK>'. Choose deliberately: docs/STACK-SELECTION.md."* The interactive stack prompt appends the guide pointer. The default still works (automation + bootstrap unaffected) — it is simply no longer silent. Satisfies the review's "stop SILENTLY defaulting."

### 4. `conformance/stack-selection.sh` (new — drift guard)
Completeness, not brittle content-equality:
- (a) `docs/STACK-SELECTION.md` exists.
- (b) every shipped `profiles/<stack>.md` contains a "Best for" + "Avoid when" marker.
- (c) the matrix names every shipped profile (a row per `profiles/<stack>.md`).
- `--selftest`: synthesize a temp profile missing the section + a matrix missing a row → assert both detected. Corpus in the script.
- Wired into kit CI (**one control-plane `cp`**).

## Files

| File | Change | Owner |
|------|--------|-------|
| `docs/STACK-SELECTION.md` | **New** — matrix + per-stack blurbs + full-stack guidance | agent |
| `profiles/<stack>.md` ×10 | `## Best for / Avoid when` section + guide pointer | agent |
| `scripts/incept.sh` | Loud default notice + interactive-prompt pointer | agent |
| `conformance/stack-selection.sh` | **New** — completeness check + `--selftest` | agent |
| `conformance/README.md` | index row | agent |
| `START-HERE.md` | §2 links the guide as comparison material | agent |
| `README.md` | link the guide | agent |
| `.github/workflows/ci.yml` | `stack-selection.sh` step | **human `cp`** |
| `VERSION`, `CHANGELOG.md`, `docs/ROADMAP-SLICE9.md` | 2.32.0; 9g row → shipped | agent |

## Verification
- `sh conformance/stack-selection.sh` → PASS on the real tree (all 10 profiles have the section; matrix complete); `--selftest` → detects a synthesized gap (exit non-zero).
- `dash -n` clean on `stack-selection.sh` + `incept.sh`.
- `incept` with no `--stack` prints the notice and still proceeds with the default; with `--stack go` no notice; `--noninteractive` bootstrap still passes `inception-done.sh`.
- `sh conformance/check-links.sh` green (STACK-SELECTION + the 10 profile pointers + START-HERE/README links resolve).
- `sh conformance/profile-completeness.sh` still green (the new section doesn't break the 11-section contract).
- Anonymization: generic ([[kit-anonymization]]).
- Governance: feature branch → PR → human ratification; the `.github/workflows` step via human `cp`; the matrix wording (stack guidance) is opinion-bearing → review for fairness/accuracy, not hype.

## Out of scope / deferred
- An interactive "stack wizard" script that asks questions and recommends — the matrix + guidance is the decision aid; a wizard is speculative (revisit only on demand).
- Reworking `new-profile.sh` (the creation path is already good — R7 is about *deciding*, not *creating*).
- Full per-profile deployment recipes for the polyglot/monorepo case (guidance points the way; per-service incept already handles it).

## Known implications
- The matrix is **opinion-bearing** (stack trade-offs). It must stay fair and accurate, not marketing — reviewed against each profile's real strengths; "avoid when" is a genuine limitation, not a strawman. A new profile must add a matrix row + its own section, or `stack-selection.sh` fails (the intended drift guard).
