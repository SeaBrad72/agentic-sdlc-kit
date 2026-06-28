# Implementation plan — skill-spine brick #5: the kit's own `worktrees` (isolation) skill

**Planned by dogfooding `skills/plan/SKILL.md`** (4th self-host use). Source design: `docs/architecture/2026-06-28-worktrees-skill-design.md` (owner-approved 2026-06-28).

## Goal
Ship the kit's own `worktrees` (isolation) skill — replacing superpowers `using-git-worktrees` — wired to the Orchestrator seat, with non-vacuous conformance teeth, as one atomic AMBER `apply.py`.

## Architecture
A new FLOOR skill file (`skills/worktrees/SKILL.md`, invoke-by-read) encodes the kit's isolation craft; the Orchestrator def (FLOOR + native) gains an "Isolation" reference; the shared verifier `conformance/orchestrator-loop-wired.sh` gains a `check_worktrees_skill` + two negative selftest cases; the `skill-spine` claim and `orchestration.md` extend to "bricks #1–5". No new gate, no new claim, no guard edit (`skills/*` already control-plane).

## Tech stack
POSIX sh (verifier + apply.py orchestration in Python3 `apply.py`), Markdown (skill + defs + docs), TSV (claims). No new dependencies.

## Global constraints (verbatim from the design + standing process)
- **FLOOR-only / invoke-by-read** — no formal `skills` adapter dimension; no registry/verify.sh/export/guard edits (confirm `skills/*` glob already covers the new file — **confirm-don't-add**).
- **AMBER** — control-plane (new skill, agent defs, verifier, claims). Author under `scratchpad/worktrees/`, assemble an idempotent `apply.py`, prove on a **clone dry-run** (`shellcheck` + `verify.sh --require`), hand to the human to apply. The agent never applies/commits-the-applied-diff/pushes/merges/tags ([[merge-tag-authority]]).
- **Version finishing folded into apply.py** — VERSION 3.60.0 → **3.61.0**, README badge, CHANGELOG entry ([[release-finishing-in-apply-py]]).
- **Non-vacuity** — the new selftest cases must FAIL a dead/always-pass check (drop-a-marker + omit-the-reference).
- **ASCII-only verifier markers** — `grep -qF`, ASCII (matches bricks #1–4).
- **Single-seat parity** — assert the Orchestrator reference only; leave the Engineer def untouched.
- **Dual review** (reviewer + security-reviewer) → **meta-control panel #12** → fold the close INTO the feature PR.

## Build model
**AMBER** — every task below is authored in `scratchpad/worktrees/`; nothing lands on a control-plane path as a silent agent commit. The single deliverable is `scratchpad/worktrees/apply.py` + its clone-proven dry-run log.

## File map (every path the apply.py creates/modifies)
| Path | Change | Responsibility |
|------|--------|----------------|
| `skills/worktrees/SKILL.md` | **create** | The isolation craft (invoke-by-read). Carries the conformance-load-bearing markers. |
| `agents/orchestrator.agent.md` | modify | Add an "## Isolation" reference block → `skills/worktrees/SKILL.md`. |
| `.claude/agents/orchestrator.md` | modify | Native mirror of the Isolation reference. |
| `conformance/orchestrator-loop-wired.sh` | modify | `WORKTREES_SKILL_FILE` var + `check_worktrees_skill()` + main-body call/assertion + cases 1–10 fixtures gain the skill + **new cases 11/12**. |
| `conformance/claims.tsv` | modify | Extend the `skill-spine` claim row → worktrees + "bricks #1–5". |
| `docs/operations/orchestration.md` | modify | Extend the skill-spine line → "and the Orchestrator follows `skills/worktrees/SKILL.md` for isolation — bricks #1–5". |
| `VERSION`, `README.md`, `CHANGELOG.md` | modify | Version finishing 3.60.0 → 3.61.0. |

## Tasks (serialized — all touch the shared verifier surface; the parallel-safety rule forbids fan-out)

### Task 1 — Author the skill content (`skills/worktrees/SKILL.md`)
Write the skill with frontmatter `name: worktrees` and a conformance-load-bearing comment (mirroring `skills/plan/SKILL.md:10-13`). Required sections + the exact kit-distinctive markers the verifier will grep (lock these strings now):
- `## When to use` — before fan-out / before isolated feature work.
- Detect-existing-first (never nest; submodule guard) + native-first (`native` worktree tools, git fallback).
- **The parallel-safety rule** — verbatim string **`disjoint file sets`**, no shared mutable state, each independently testable.
- **Conflict-safe integration** — verbatim string **`--no-renames`** + refuse fail-closed + `kit.conflict`.
- **Engineer boundary** — verbatim string **`out-of-slice`** (zero out-of-slice edits).
- **Honest ceiling** — isolation ≠ security sandbox; cleanup best-effort.
- **Metering** — `scripts/runaway-guard.sh step`.

**Locked markers (verifier greps all five, `grep -qF`):** `name: worktrees` · `disjoint file sets` · `--no-renames` · `out-of-slice` · `native`.

TDD step: this is content, proven by Task 3's check failing without it. Write to `scratchpad/worktrees/SKILL.md`.

### Task 2 — Wire the Orchestrator reference (both defs)
- `agents/orchestrator.agent.md`: add an `## Isolation` block after the `## Design (Architect hat)` block — "For setting up an isolated worktree per fanned-out Engineer, follow the kit's own isolation skill — `skills/worktrees/SKILL.md` … (replacing superpowers using-git-worktrees)." Must contain the literal `skills/worktrees/SKILL.md`.
- `.claude/agents/orchestrator.md`: mirror the same reference line.
Author both edits as full-file copies under `scratchpad/worktrees/`.

### Task 3 — Verifier: the check + the non-vacuous teeth (TDD heart of the slice)
In a copy of `conformance/orchestrator-loop-wired.sh` under `scratchpad/worktrees/`:
1. Add path var (after line 25): `WORKTREES_SKILL_FILE="${ORCH_LOOP_WORKTREES_SKILL:-skills/worktrees/SKILL.md}"`.
2. Add `check_worktrees_skill()` (mirror `check_review_skill`, lines 101-110): assert file exists; `grep -qF` each of the 5 locked markers; assert `$ORCH_DEF` references `skills/worktrees/SKILL.md`.
3. Add the main-body call: `check_worktrees_skill "$WORKTREES_SKILL_FILE" "$ORCH_DEF" || fail=1` (after line 355).
4. **Cases 1–10:** in EACH fixture add `mkdir -p "$rN/skills/worktrees"; _worktrees_skill_ok > "$rN/skills/worktrees/SKILL.md"; printf 'skills/worktrees/SKILL.md\n' >> "$rN/agents/orchestrator.agent.md"` and thread `ORCH_LOOP_WORKTREES_SKILL="$rN/skills/worktrees/SKILL.md"` into each case's env subshell. Add the `_worktrees_skill_ok()` fixture-emitter helper (mirror `_review_skill_ok`).
5. **New case 11** (marker teeth): build a conformant tree but emit a worktrees skill MISSING one marker (e.g. drop `disjoint file sets`) → assert exit 1.
6. **New case 12** (reference teeth): conformant skill present but the Orchestrator fixture def does NOT reference `skills/worktrees/SKILL.md` → assert exit 1.

**Red→green proof (run in scratchpad before assembling apply.py):**
- `sh scratchpad/worktrees/orchestrator-loop-wired.sh --selftest` with the skill ABSENT from a real-tree pointer → check FAILs (proves liveness).
- With the skill present + all markers + reference → all 12 cases PASS.
- Mutate case 11 emitter to include all markers → case 11 must FAIL ("marker teeth vacuous") — proves the negative is load-bearing. Same for case 12 (add the reference → case 12 must FAIL).

### Task 4 — Extend the claim + the ops doc (text, no new claim row)
- `conformance/claims.tsv:39`: rewrite the `skill-spine` description → "… design + plan + tdd + review + **worktrees** skills (… `skills/worktrees/SKILL.md`) … referenced by the orchestrator (Architect hat **+ Isolation**), engineer (TDD), and reviewer (code review) — bricks **#1–5** …". Keep the same claim id + verifier command (no new row).
- `docs/operations/orchestration.md:50`: extend the sentence → "… and the Orchestrator follows the kit's own `skills/worktrees/SKILL.md` for isolation — bricks #1–5 of the kit's own skill spine."

### Task 5 — Assemble `scratchpad/worktrees/apply.py` (idempotent) + version finishing
One Python3 script that: writes `skills/worktrees/SKILL.md`; applies the two orchestrator-def edits (idempotent — skip if reference already present); rewrites the verifier section (idempotent — guard on `check_worktrees_skill` presence); rewrites the claim row + ops line (idempotent string replace); bumps VERSION 3.60.0→3.61.0, README badge, prepends a CHANGELOG entry. Each edit guarded so a re-run is a no-op.

### Task 6 — Clone dry-run (confabulation-proof gate)
`git clone . <tmp>` → run `apply.py` in the clone → `shellcheck conformance/orchestrator-loop-wired.sh` → `sh conformance/orchestrator-loop-wired.sh --selftest` (12/12 PASS) → `sh conformance/verify.sh --require` (skill-spine PASS, 0 failed) → confirm VERSION==3.61.0. Capture the log. **Never trust a subagent "done" report — verify on the clone** ([[reprioritized-backlog]] confabulation lesson).

## Self-review (spec coverage — every design requirement → a task)
- Skill content + markers → T1. Orchestrator wiring (FLOOR+native) → T2. check + cases 11/12 + cases 1–10 fixtures + non-vacuity → T3. Claim + ops doc → T4. AMBER apply.py + version finishing → T5. Clone-proof → T6.
- No guard/registry/verify.sh/export edits → confirmed (confirm-don't-add in Global Constraints + T1 note).
- Single-seat parity (Engineer untouched) → T2/T3.
- Placeholder scan: markers are locked literal strings; paths/line-anchors are exact; commands carry expected output. No "handle edge cases" steps. ✔
- Build model AMBER stated; human-only ship steps reserved. ✔

## Terminal state / handoff
Hand to the build skill (`skills/tdd/SKILL.md` via the Engineer seat / subagent-driven build): produce `scratchpad/worktrees/apply.py` + the Task 6 clone log. Then dual review → panel #12 → human applies + ships.
