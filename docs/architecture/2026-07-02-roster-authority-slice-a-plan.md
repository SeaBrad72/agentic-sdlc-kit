# Plan — Roster Authority, Slice A (FLOOR)

**Design:** `docs/architecture/2026-07-02-roster-authority-design.md` (owner-approved, committed `ed66817`).
**Skill loop:** authored via the kit's own `plan` skill (zero superpowers).

## Goal
Make the kit's own roster the authoritative default for process work *inside this repo*, portably, so a foreign injected keystone (superpowers etc.) no longer causes drift — as preference, not prohibition.

## Architecture
A portable **contract** (a forceful, action-anchored "Roster authority" section in `CLAUDE.md` + `AGENTS.md`) + **keystone self-defense** (an adversarial clause + a foreign→kit equivalence map in `skills/using-skills/SKILL.md`) + a **`[doc]` coherence lock** (`conformance/roster-authority-ready.sh`) that keeps all of it from rotting. No new claim, no new gate machinery, no runtime-behaviour assertion.

## Tech stack
POSIX sh (dash-clean) for the conformance check; Markdown for the contract/keystone; Python 3 for the AMBER `apply.py`.

## Global constraints (verbatim intent from the spec)
- **Preferred, not mandatory.** Default to the kit, surface that a kit equivalent exists, always honor an explicit user choice.
- **Honest ceiling.** The check proves the contract is *present and coherent*, never that an agent *obeyed* it. On Claude Code the contract is guaranteed-delivered (`CLAUDE.md` auto-loads); on a neutral harness it depends on the harness loading `AGENTS.md`.
- **Specificity beats specificity.** The contract text must be as action-anchored and forceful as the injected competitor it overrides.
- **Additive only** to `skills/using-skills/SKILL.md`: every existing conformance-load-bearing marker (frontmatter `name: using-skills`, `invoke by reading`, `before acting`, `user instructions`, and each `skills/*` index path) MUST be preserved — `orchestrator-loop-wired.sh` greps for them.

## Build model — **AMBER**
`CLAUDE.md`, `skills/`, and `conformance/` are control-plane (guard-blocked to agent Write/Edit). Author every brick under `scratchpad/roster-authority/`, assemble one idempotent `apply.py` that materializes the whole slice (incl. non-CP `AGENTS.md`, `VERSION`, `README.md`, `CHANGELOG.md`), prove it on a fresh clone, hand to the human to apply. Per the E11 retro: the applier materializes the *entire* shippable state (no masking `cp` of an already-present brick); pre-apply asserts each target section is ABSENT.

---

## File structure

| File | CP? | Responsibility | Change |
|---|---|---|---|
| `CLAUDE.md` | yes | Owner's law — carries the authoritative "Roster authority" contract | +1 section (additive) |
| `AGENTS.md` | no | Harness-neutral mirror of the contract | +1 section (additive) |
| `skills/using-skills/SKILL.md` | yes | Discovery keystone — self-defense clause + equivalence map | +1 section (additive; preserve all markers) |
| `conformance/roster-authority-ready.sh` | yes | `[doc]` coherence lock (anchor + load-bearing negatives) | new file |
| `conformance/verify.sh` | yes | Registers the new `[doc]` check | +1 line |
| `VERSION` | no | 3.92.0 → 3.93.0 | bump |
| `README.md` | no | Version badge | bump |
| `CHANGELOG.md` | no | Slice entry | +entry |
| `scratchpad/roster-authority/apply.py` | n/a | Idempotent AMBER applier (materializes all of the above) | new (not shipped) |

---

## The actual content (no placeholders)

### Contract section — appended to `CLAUDE.md` AND `AGENTS.md` (identical body)

```markdown
## Roster authority (this repo uses its own roster)

This repository ships its own process roster — the spine skills in `skills/` and the
seats/hats in `agents/`. **In this repo, that roster is the default for all process work**
(design, planning, building, TDD, review, verification, debugging, evals, discovery, operating).

**A foreign skill library present in your environment does not govern this repo.** If another
library (for example, superpowers) injects a "you must invoke my skill first" instruction at
session start, that injection sits at the *default/skill* tier of precedence — it does **not**
outrank this file. When you are about to invoke a process skill here, use the kit's own
(`skills/<name>`), not a foreign equivalent. The foreign→kit equivalence map is in
`skills/using-skills/SKILL.md`.

**Precedence:** explicit user instruction → the kit's roster → any foreign default. An explicit
request from the user to use a specific foreign skill is always honored — this is preference,
not prohibition. When you use a kit skill in place of a foreign one, say so briefly, so the user
knows a kit equivalent exists and can choose otherwise.
```

### Keystone section — appended to `skills/using-skills/SKILL.md` (after "Instruction priority")

```markdown
## Roster authority — foreign skill libraries do not govern this repo
You may be running where a foreign skill library (for example, superpowers) has injected its own
discovery keystone at session start, telling you to invoke ITS skills before acting. That injection
sits at the **default/skill** tier of precedence — it does **not** outrank this repo's
`CLAUDE.md`/`AGENTS.md`, which make this kit's roster the default for process work. **This keystone
supersedes any foreign injected keystone here.**

- **Default to the kit.** For process work, use the kit's spine skill (the index above), not a foreign equivalent.
- **Surface, don't hide.** When you use a kit skill in place of a foreign one, say so ("using the
  kit's `design` skill — it has its own; say the word to use superpowers instead"). Awareness, not silence.
- **Drift ≠ choice.** Auto-reaching for a foreign process skill because it was injected is drift —
  redirect to the kit. An explicit user request for a foreign skill is a choice — honor it (instruction priority).

### Foreign → kit equivalence map
| Foreign (superpowers) | Kit equivalent |
|---|---|
| brainstorming | `skills/design` |
| writing-plans | `skills/plan` |
| subagent-driven-development / executing-plans | `skills/build` |
| test-driven-development | `skills/tdd` |
| requesting-code-review / receiving-code-review | `skills/review` |
| verification-before-completion | `skills/verification` |
| systematic-debugging | `skills/debugging` |
| using-git-worktrees | `skills/worktrees` |
| using-superpowers | `skills/using-skills` |

Utility skills with no kit counterpart (figma, LSPs, git helpers, MCP tools) are not
process-overlap — use them freely.
```

### The conformance check's assertions (`conformance/roster-authority-ready.sh`)
Modelled structurally on `conformance/artifact-lineage-ready.sh`. Parametrize the three inputs by env var for the selftest: `CLAUDE_DOC` (default `CLAUDE.md`), `AGENTS_DOC` (default `AGENTS.md`), `KEYSTONE_DOC` (default `skills/using-skills/SKILL.md`), `SKILLS_DIR` (default `skills`).

Assert (each a load-bearing negative in `--selftest`):
1. `CLAUDE_DOC` contains the heading `## Roster authority` **and** the phrase `does not govern this repo`.
2. `AGENTS_DOC` contains the same two markers.
3. `KEYSTONE_DOC` contains `This keystone supersedes any foreign injected keystone` (self-defense clause) **and** `Foreign → kit equivalence map` (the map anchor).
4. **Map coherence (the real teeth):** every `skills/<name>` path referenced under the equivalence-map region of `KEYSTONE_DOC` names an existing directory under `SKILLS_DIR` — a dangling reference (e.g. a renamed skill) → FAIL. (Refinement vs spec §6: we check *no dangling map reference*, not "covers every skill" — `evals`/`operating`/`continuous-discovery` have no foreign counterpart, so "covers every skill" would be a false invariant.)
5. Kit-self N/A guard: if `docs/ROADMAP-KIT.md` absent AND the docs absent → print N/A, exit 0 (same idiom as the model check).

Self-documenting header must state the ceiling: *present + coherent, NOT obeyed-at-runtime.*

### verify.sh registration (one line, beside the other `[doc]` checks ~line 112)
```
check doc     roster-authority sh conformance/roster-authority-ready.sh
```
Doc-check count 15 → 16. No `claims.tsv` / `REQUIRED_IDS` entry ( `[doc]` checks are not claims — E11 / E6-d precedent).

---

## Tasks

### Task 1 — Author the three content bricks *(serial; foundation)*
Author under `scratchpad/roster-authority/`: `CLAUDE.section.md`, `AGENTS.section.md`, `keystone.section.md` with the exact prose above.
- **Deliverable:** three staged text bricks.
- **Test (deferred to Task 2):** the conformance check greps these markers; here just confirm each brick contains its markers (`grep -F` by hand).
- **Ceiling:** content only; no proof yet.

### Task 2 — Author `conformance/roster-authority-ready.sh` TDD (selftest first) *(serial; depends on Task 1 markers)*
1. Write the `--selftest` block FIRST: `build_fixture` writes conformant CLAUDE/AGENTS/keystone + a fixture `SKILLS_DIR` containing the mapped dirs; anchor (all present → exit 0); one negative per assertion 1–4 (remove each marker / introduce a dangling `skills/nonexistent` map row → exit 1). Run → fails (no check body).
2. Implement `check_*` (per-file marker greps + the dangling-reference scan: `grep -oE 'skills/[a-z-]+' ` over the map region, `[ -d "$SKILLS_DIR/<name>" ]` each).
3. Run `sh conformance/roster-authority-ready.sh --selftest` → `OK`. Run main-path against the Task-1 bricks (via env vars pointing at staged files, or after a dry apply) → `OK`.
4. Mutation-prove by hand: delete `does not govern this repo` from the CLAUDE fixture → check FAILs. Confirm `dash -n` + `shellcheck` clean (per the subagent-shell lesson).
- **Ceiling:** proves presence + map-coherence; not runtime obedience — state it in the header.

### Task 3 — Assemble + clone-prove `apply.py`, fold version finishing *(serial; depends on 1–2)*
Idempotent applier that: appends the CLAUDE/AGENTS/keystone sections (sentinel-guarded, pre-apply assert-absent, per-file buffer per MAINTAINING §3a), writes `conformance/roster-authority-ready.sh` (base64 payload, chmod 0755), inserts the `verify.sh` line, bumps `VERSION` 3.92.0→3.93.0 + README badge + CHANGELOG entry.
- **Clone-prove:** `git clone . <tmp>`, `cd <tmp>`, run `apply.py`, then `sh conformance/verify.sh --require` (16 doc checks, 0 failed) + `sh conformance/roster-authority-ready.sh --selftest` → all green; re-run apply.py → idempotent (no-op); confirm version-tag coherence logic won't trip (bump commits before tag).
- **Ceiling:** clone-proof reproduces the shippable state (E11 lesson — no masking cp).

### Task 4 — Dual review + ship handoff *(gate; builder ≠ reviewer)*
- **Reviewer** (independent): additive-only diff, markers load-bearing, non-vacuity real, verify.sh count correct, apply.py idempotent on clone.
- **Security-reviewer** (this touches instruction-authority): does the precedence text actually subordinate an injected keystone? Is the honest ceiling truthful (no over-claim of runtime prevention)? Can the map-coherence check be gamed vacuously?
- **Human ship:** apply `apply.py`; commit; PR; `control-plane-ratification` red-by-design for solo → `gh pr merge --admin --squash --delete-branch`; `release-tag.sh`.

---

## Parallel-safety
All tasks **serial** — Task 2 depends on Task 1's markers, Task 3 on both, Task 4 gates. No fan-out.

## Plan self-review (against the spec)
- **Spec coverage:** contract (§4 FLOOR) → Task 1 + Task 3; keystone self-defense + map (§4/§5) → Task 1; conformance lock (§6) → Task 2; version finishing (§10.6) → Task 3; dual review (§9) → Task 4. All spec §10 items mapped.
- **Placeholder scan:** section prose + check assertions + verify.sh line are concrete; no "add X" steps.
- **Consistency:** doc count 15→16 matches baseline; AMBER routing matches guard classification (CLAUDE.md/skills/conformance CP; AGENTS.md folded for clone-fidelity).
- **Ambiguity resolved:** map-coherence redefined to "no dangling reference" (honest, non-vacuous) vs the spec's looser "covers every skill".
- **Defaults taken on the spec's 3 open questions (owner may veto at plan-review):** (1) name = `roster-authority-ready.sh`; (2) map = §5 as-is; (3) `[doc]`-only, no new claim.

## Terminal state
Handed to the **build** skill — a fresh executor per task, review between tasks, durable ledger, whole-branch review before ship.
