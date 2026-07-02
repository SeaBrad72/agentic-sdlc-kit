# Design — `build`: the subagent-driven execution spine skill

**Date:** 2026-07-01
**Author:** Orchestrator (Architect hat), via `skills/design`
**Status:** Proposed — awaiting owner HARD-GATE approval
**Slice:** `build-spine-skill` (successor to the promotion-contract epic / non-vacuity topic; owner-approved next 2026-07-01)

---

## Goal

Ship the kit's own **`build`** spine skill — the invoke-by-reading craft for *executing an owner-approved plan via subagents with review gates*. This is the one remaining self-hosting roster gap: the discipline exists only inside `agents/orchestrator.agent.md` + `agents/engineer.agent.md` + `docs/operations/orchestration.md`, never as a spine skill a conductor invokes by reading. Its absence is the concrete reason the loop kept drifting to superpowers `subagent-driven-development`.

## The gap (concrete proof it is real)

- **`skills/plan`'s terminal state says: "handed to the build skill"** — a named successor that does not exist on disk. Naming this skill `build` makes that existing wiring accurate for free.
- **`skills/using-skills` keystone** indexes design→plan→tdd→review→worktrees→verification→debugging→evals→continuous-discovery→operating — there is a plan skill and a tdd skill, but nothing that owns *"take the plan and drive its tasks to a reviewed branch."*
- The full core SDLC loop is kit-self-hosted through Review; the **execution conductor step between plan and integration** is the missing brick.

## Agents-vs-skills resolution (decided up front, per the design skill's rule)

> "A standing agent (seat) is earned only by a distinct skill AND (distinct tools OR must-run-parallel/independent); otherwise it is a skill a seat invokes. Few agents, many skills."

`build` is a **SKILL the Orchestrator (conductor) invokes**, **NOT a new agent**. The Orchestrator + Engineer agents remain the seats; `build` encodes the loop discipline the conductor follows. It is wired as a new `## Execution` hat section in `agents/orchestrator.agent.md`, sitting between Design(plan) and Verification(integration). **No new agent is created.**

## Naming (owner-ratified 2026-07-01) — `build`, and how it does NOT collide with `tdd`

Owner chose `build` over `execute`/`subagent-driven`. The one-term-one-meaning risk (the kit avoided naming continuous-discovery "discovery" for exactly this reason) is resolved by scope:

| Skill | Scope | Altitude |
|---|---|---|
| `tdd` | Build **one task** test-first (red → green → refactor) | within a single task |
| `build` | Execute the **whole plan**: dispatch each task to a fresh executor, review between tasks, integrate | across all tasks of a slice |

**`build` composes `tdd`.** The conductor's `build` loop dispatches each task to a fresh executor; that executor builds its one task via `tdd`. The SKILL.md states this composition explicitly so the boundary is unambiguous. `build` also makes `plan`'s "handed to the build skill" prose accurate.

## The discipline `build` codifies (harness-neutral — the loop hand-coded this session)

Read the owner-approved plan, then per task:
1. **Task-brief as a FILE.** Each task's context is handed off as a file (the Task-Context-Contract), not pasted into a shared context window that compaction can erase.
2. **Fresh executor per task.** Dispatch a fresh executor (the kit's `engineer` agent) per task — no accumulated context, no cross-task contamination. Each executor builds its task via `tdd`.
3. **Review between tasks (builder ≠ reviewer).** After each task, an independent reviewer gates the diff before the next task starts. The builder is never the sole reviewer.
4. **Fix-loop.** Reviewer findings route back to a fresh executor; re-review until the gate passes. Findings are resolved, not waived.
5. **Durable ledger.** Progress (tasks done / in-review / blocked) is recorded in a durable ledger file that survives context compaction — the loop can be resumed cold.
6. **Parallel-safety by disjoint sets.** Fan out only tasks with disjoint file sets and no shared mutable state (this *references* `skills/worktrees` for the parallel-safety rule + isolation; it does not duplicate it).
7. **Final whole-branch review.** After all tasks integrate, a final adversarial review of the whole branch — per-task green does not imply the branch is coherent.
8. **Control-plane → GREEN-brick + AMBER-apply.** Any task touching control-plane (guard/CI/conformance/claims/agent-or-skill defs/governance markers) is authored GREEN in scratchpad and handed to a human as an idempotent `apply.py`; the agent never silently commits control-plane. Version finishing folds into the apply.py.

## Kit-distinctive markers (conformance-load-bearing)

The SKILL.md carries these exact phrases (byte-identical to the `spine_table()` row); a generic subagent-driven-development paraphrase lacks them, so `check_spine_skill` KILLs a generic copy:

1. `name: build` (frontmatter)
2. `fresh executor per task`
3. `task brief as a file`
4. `review between tasks`
5. `durable ledger`
6. `whole-branch review`

An early HTML comment block in the SKILL.md lists these as the load-bearing markers (kit convention, mirrors operating/design).

## Honest ceiling (stated, not chased)

- **Provable (structural):** the SKILL.md exists, carries every kit-distinctive marker, is indexed by `skills/using-skills`, and is referenced by the owning seat (Orchestrator). A generic paraphrase fails the markers. The agents-vs-skills rule is respected (conductor hat, not a new seat).
- **NOT provable (un-gateable):** whether an agent actually *runs the loop* at runtime — dispatch is harness-specific (the Agent/Task tool), so the FLOOR is "invoke by reading the discipline"; a native binding is a bonus. Same ceiling as `using-skills` and `operating`: **provided + structurally proven; runtime loop-adherence un-gateable.** The discipline is kept harness-neutral (fresh executor per task, file handoffs, review gates, durable ledger) even though concrete dispatch is platform-local.

## Conformance obligations (the wiring, all in one AMBER apply.py)

All touched paths are control-plane → **GREEN-brick + AMBER `apply.py`** (E5 base64-embed pattern behind a fail-closed guard: skip if the row is already present; abort if any anchor is missing). Files:

1. **`skills/build/SKILL.md`** — new file (the craft), with the load-bearing marker comment.
2. **`conformance/orchestrator-loop-wired.sh`** — four surgical edits:
   - a `BUILD_SKILL_FILE="${ORCH_LOOP_BUILD_SKILL:-skills/build/SKILL.md}"` path variable;
   - a `build` row in `spine_table()` (name / 6 markers / `orch:build skill not wired to the Orchestrator`);
   - a `build) echo "$BUILD_SKILL_FILE" ;;` case in `skill_path()`;
   - **`ORCH_LOOP_BUILD_SKILL="$t/skills/build/SKILL.md"`** added to the selftest's `st_run()` env block. **This line is load-bearing** — without it the selftest reads the real SKILL.md instead of the fixture, so the auto-generated marker-drop teeth silently pass (false-green vacuity). This is the single highest-risk edit.
3. **`skills/using-skills/SKILL.md`** — a `build` index-table row + add `skills/build` to the load-bearing HTML-comment path list.
4. **`agents/orchestrator.agent.md`** — a new `## Execution` section referencing `skills/build/SKILL.md` (satisfies the `orch` ref in the spine row).
5. **`conformance/claims.tsv`** — extend the existing **`skill-spine`** claim prose to include `build` (NO new claim id — keeps the registry balanced; `claim-gate-counts.sh` row counts unchanged).
6. **Version finishing** folded into apply.py: `VERSION` 3.86.0 → 3.87.0, `README` badge, `CHANGELOG` entry.

Non-vacuity is largely automatic: the table-driven `--selftest` generates a marker-drop case and a reference-omitted case for the new `build` row (both must exit 1 = KILLED). Plus the conformant-fixture liveness anchor (exit 0). The `st_run` env-var edit is what makes those teeth real.

## Build model & process

Subagent-driven (dogfood the very loop this skill describes — the meta/capstone framing): plan via `skills/plan` → dispatch the SKILL.md authoring + the conformance edits to engineer subagents with file handoffs → independent reviewer + security-reviewer (the security lens = the false-KILL / vacuity threat + guard completeness) → GREEN-brick proven on a clone (`--selftest` flips + `verify --require` + shellcheck/`dash -n`) → AMBER apply.py handed to the owner. Governance close (marker + meta-control-log row) is a separate human-run script if a panel is convened; a routine spine brick may not need a full panel (owner's call at review).

## Watch-outs (this session's scars, carried in)

- `st_run` env-var (above) — the one edit that makes non-vacuity real.
- `dash -n` + `shellcheck` all subagent-authored shell before trusting green (a leaked authoring artifact runtime-passes but lint-fails).
- GREEN-brick + AMBER forced for every control-plane file; Bash that merely NAMES a control-plane path is guard-blocked → read via python `open()` / subagents.
- Markers must not contain `|` or TAB (spine_table split chars); labels must not contain `,`/`;`/`:`.
- Re-verify `git HEAD`/tag fresh before handing any ship command.
- version-tag-coherent is legitimately RED between apply and commit; apply → commit → then verify.

## Terminal state of this design

A committed, owner-approved spec, handed to `skills/plan`. This design does not start implementation.
