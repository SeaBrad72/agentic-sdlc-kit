# Implementation plan — skill-spine brick #6: the kit's own `verification` skill

**Planned by dogfooding `skills/plan/SKILL.md`** (5th self-host use). Source design: `docs/architecture/2026-06-28-verification-skill-design.md` (owner-approved 2026-06-28).

## Goal
Ship the kit's own `verification` (verification-before-completion) skill — replacing superpowers `verification-before-completion` — wired DUAL-SEAT to the Engineer (evidence-before-claims) and Orchestrator (confabulation-proofing), with non-vacuous conformance teeth, as one atomic AMBER `apply.py`.

## Architecture
A new FLOOR skill (`skills/verification/SKILL.md`, invoke-by-read) encodes the kit's evidence-before-claims craft; the Engineer def (FLOOR + native) and the Orchestrator def (FLOOR + native) each gain a verification reference; the shared verifier `conformance/orchestrator-loop-wired.sh` gains `check_vbc_skill` (asserts the skill + BOTH seat references) + three negative selftest cases; the `skill-spine` claim and `orchestration.md` extend to "bricks #1–6". No new gate, no new claim, no guard edit (`skills/*` already control-plane).

## Tech stack
POSIX sh (verifier), Python3 (`apply.py`), Markdown (skill + defs + docs), TSV (claims). No new dependencies.

## Global constraints (verbatim from the design + standing process)
- **FLOOR-only / invoke-by-read** — no formal `skills` adapter dimension; no registry/verify.sh/export/guard edits (confirm `skills/*` glob already covers the new file — **confirm-don't-add**).
- **DUAL-SEAT** — Engineer + Orchestrator both reference the skill; the verifier asserts BOTH; each ref-leg gets its own load-bearing negative case (non-vacuity). Reviewer left untouched (its review-instance lives in the `review` skill).
- **AMBER** — control-plane. Author under `scratchpad/verification/`, assemble an idempotent `apply.py`, prove on a **clone dry-run** (`shellcheck` + `verify.sh --require`), hand to the human to apply. The agent never applies/commits-the-applied-diff/pushes/merges/tags ([[merge-tag-authority]]).
- **Version finishing folded into apply.py** — VERSION 3.61.0 → **3.62.0**, README badge, CHANGELOG entry ([[release-finishing-in-apply-py]]).
- **Non-vacuity** — each new selftest case must FAIL a dead/always-pass check (drop-a-marker + each-ref-omitted).
- **ASCII-only verifier markers** — `grep -qF`, ASCII. Watch for markers beginning with `-` (use `grep -qF --` as brick #5 did for `--no-renames`); the brick-#6 markers do not start with `-`, but confirm.
- **Dual review** (reviewer + security-reviewer) → **meta-control panel #13** → fold the close INTO the feature PR.

## Build model
**AMBER** — every task below is authored in `scratchpad/verification/`; nothing lands on a control-plane path as a silent agent commit. The single deliverable is `scratchpad/verification/apply.py` + its clone-proven dry-run log.

## File map (every path the apply.py creates/modifies)
| Path | Change | Responsibility |
|------|--------|----------------|
| `skills/verification/SKILL.md` | **create** | The evidence-before-claims craft (invoke-by-read). Carries the conformance-load-bearing markers. |
| `agents/engineer.agent.md` | modify | Sharpen "self-verify before returning" → reference `skills/verification/SKILL.md` (evidence-before-claims). |
| `.claude/agents/engineer.md` | modify | Native mirror of the Engineer reference. |
| `agents/orchestrator.agent.md` | modify | Sharpen "integrate the returned diffs" → reference `skills/verification/SKILL.md` (confabulation-proofing). |
| `.claude/agents/orchestrator.md` | modify | Native mirror of the Orchestrator reference. |
| `conformance/orchestrator-loop-wired.sh` | modify | `VBC_SKILL_FILE` var + `check_vbc_skill()` (asserts skill + 5 markers + BOTH refs) + main-body call + cases 1–12 fixtures gain the skill + both refs + **new cases 13/14/15**. |
| `conformance/claims.tsv` | modify | Extend the `skill-spine` claim row → verification + "bricks #1–6". |
| `docs/operations/orchestration.md` | modify | Extend the skill-spine line → Engineer + Orchestrator follow `skills/verification/SKILL.md`. |
| `VERSION`, `README.md`, `CHANGELOG.md` | modify | Version finishing 3.61.0 → 3.62.0. |

## Tasks (serialized — all touch the shared verifier surface; the parallel-safety rule forbids fan-out)

### Task 1 — Author the skill content (`skills/verification/SKILL.md`)
Write the skill with frontmatter `name: verification` and a conformance-load-bearing comment (mirror `skills/plan/SKILL.md:10-13`, listing the markers). Required sections + the exact kit-distinctive markers the verifier will grep (lock these strings now, `grep -qF`, ASCII):
- `## When to use` — before any completion/done/passing claim, before committing or opening a PR.
- **The Iron Law** — no completion claim without fresh verification evidence.
- The gate function — identify the command → run it fresh → read exit code + count failures → only then claim.
- **Confabulation-proofing** — verbatim string **`confabulation`**: never trust a subagent's "done" report on file artifacts; verify on disk / via a **`clone dry-run`** (verbatim) — the clone + `verify --require` gate is confabulation-proof.
- **Evidence before claims** — verbatim string **`evidence before claims`**.
- **Fresh** — verbatim string **`fresh`** (run the command fresh in *this* turn).
- **Tagless-clone fidelity** — `git clone .` carries tags `actions/checkout` does not fetch; validate tag-reading checks on a tagless clone.
- Rationalization + red-flag tables (kept from the proven spine).

**Locked markers (verifier greps all five, `grep -qF`):** `name: verification` · `confabulation` · `clone dry-run` · `evidence before claims` · `fresh`. (None begins with `-`; plain `grep -qF` is safe.)

TDD step: content proven by Task 3's check failing without it. Write to `scratchpad/verification/SKILL.md`.

### Task 2 — Wire BOTH seats (4 def edits)
- `agents/engineer.agent.md`: in/after the self-verify responsibility, add "follow the kit's own `skills/verification/SKILL.md` — evidence before claims: run the slice's tests fresh and read the result before reporting done." Must contain literal `skills/verification/SKILL.md`.
- `.claude/agents/engineer.md`: mirror the Engineer reference line.
- `agents/orchestrator.agent.md`: in/after "Integrate the returned diffs", add an explicit confabulation-proofing line referencing `skills/verification/SKILL.md` ("a subagent can report done for files it never wrote — verify the diff / a clone dry-run, never the report"). Must contain literal `skills/verification/SKILL.md`.
- `.claude/agents/orchestrator.md`: mirror the Orchestrator reference line.
Author all four edits as full-file copies under `scratchpad/verification/`.

### Task 3 — Verifier: the check + the dual non-vacuous teeth (TDD heart of the slice)
In a copy of `conformance/orchestrator-loop-wired.sh` under `scratchpad/verification/`:
1. Add path var (after `WORKTREES_SKILL_FILE`): `VBC_SKILL_FILE="${ORCH_LOOP_VBC_SKILL:-skills/verification/SKILL.md}"`.
2. Add `check_vbc_skill()` (mirror `check_worktrees_skill`, but take THREE args `<skill> <engineer_def> <orch_def>`): assert file exists; `grep -qF` each of the 5 markers; assert `$ENGINEER_DEF` references `skills/verification/SKILL.md`; assert `$ORCH_DEF` references it. Each failure prints a distinct FAIL line and sets miss=1.
3. Add the main-body call after the worktrees one: `check_vbc_skill "$VBC_SKILL_FILE" "$ENGINEER_DEF" "$ORCH_DEF" || fail=1`.
4. A `_vbc_skill_ok()` emitter (mirror `_worktrees_skill_ok`) printing a minimal skill with all 5 markers.
5. Cases 1-12: in EACH, create `$rN/skills/verification/SKILL.md` via `_vbc_skill_ok`, append `skills/verification/SKILL.md` to BOTH that case's engineer fixture def AND orchestrator fixture def, and add `ORCH_LOOP_VBC_SKILL="$rN/skills/verification/SKILL.md"` to that case's env subshell.
6. **New case 13** (marker teeth): conformant tree, but emit a verification skill MISSING one marker (drop `confabulation`) → assert exit 1.
7. **New case 14** (Engineer reference teeth): conformant skill + Orchestrator ref present, but the ENGINEER fixture def does NOT reference the skill → assert exit 1.
8. **New case 15** (Orchestrator reference teeth): conformant skill + Engineer ref present, but the ORCHESTRATOR fixture def does NOT reference the skill → assert exit 1.

**Red→green proof (run in scratchpad before assembling apply.py):**
- `sh scratchpad/verification/orchestrator-loop-wired.sh --selftest` with the skill present + all markers + both refs → all 15 cases PASS.
- Mutate case 13 emitter to include all markers → case 13 must FLIP to FAIL ("marker teeth vacuous"). Revert.
- Give case 14 the Engineer ref → case 14 must FLIP to FAIL ("Engineer reference teeth vacuous"). Revert.
- Give case 15 the Orchestrator ref → case 15 must FLIP to FAIL ("Orchestrator reference teeth vacuous"). Revert.

### Task 4 — Extend the claim + the ops doc (text, no new claim row)
- `conformance/claims.tsv` (the `skill-spine` row): rewrite the description → "… + **verification** skill (`skills/verification/SKILL.md`) … referenced by the engineer (TDD **+ evidence-before-claims**) and orchestrator (Architect hat + Isolation **+ confabulation-proofing**) … bricks **#1–6** …". Keep the same claim id + verifier command (no new row).
- `docs/operations/orchestration.md`: extend the sentence → "… and the Engineer and Orchestrator both follow the kit's own `skills/verification/SKILL.md` for verification-before-completion — bricks #1–6 of the kit's own skill spine."

### Task 5 — Assemble `scratchpad/verification/apply.py` (idempotent) + version finishing
One Python3 script that: writes `skills/verification/SKILL.md`; applies the four def edits (idempotent — skip if reference already present); rewrites the verifier (idempotent — guard on `check_vbc_skill` presence); rewrites the claim row + ops line (idempotent string replace, assert old substring present exactly once); bumps VERSION 3.61.0→3.62.0, README badge, prepends a CHANGELOG entry. Each edit guarded so a re-run is a no-op. Mirror brick #5's apply.py shape (base64-embed the SKILL + verifier).

### Task 6 — Clone dry-run (confabulation-proof gate — and a live use of the very skill)
`git clone . <unique-dir>` (guard blocks `rm -rf`; use a unique dir) → run `apply.py` in the clone → `shellcheck conformance/orchestrator-loop-wired.sh` → `sh conformance/orchestrator-loop-wired.sh --selftest` (15/15 PASS) → `sh conformance/verify.sh --require` (skill-spine PASS, 0 failed) → confirm VERSION==3.62.0 → re-run `apply.py` (idempotent no-op). Capture the log. **Never trust a subagent "done" report — verify on the clone** ([[reprioritized-backlog]] confabulation lesson — which this slice's own skill encodes; building it is a live use of it).

## Self-review (spec coverage — every design requirement → a task)
- Skill content + 5 markers → T1. Dual-seat wiring (Engineer FLOOR+native, Orchestrator FLOOR+native) → T2. check + cases 13/14/15 + cases 1–12 fixtures + dual non-vacuity → T3. Claim + ops doc → T4. AMBER apply.py + version finishing → T5. Clone-proof → T6.
- No guard/registry/verify.sh/export edits → confirmed (confirm-don't-add).
- Dual-seat both legs proven independently (cases 14 + 15) → T3.
- Placeholder scan: markers are locked literal strings; paths exact; commands carry expected output. No "handle edge cases" steps. ✔
- Build model AMBER stated; human-only ship steps reserved. ✔

## Terminal state / handoff
Hand to the build skill (`skills/tdd/SKILL.md` via the Engineer seat / subagent-driven build): produce `scratchpad/verification/apply.py` + the Task 6 clone log. Then dual review → panel #13 → human applies + ships.
