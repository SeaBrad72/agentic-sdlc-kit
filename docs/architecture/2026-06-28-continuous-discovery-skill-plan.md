# Implementation plan — skill-spine brick #10: the kit's own `continuous-discovery` skill

**Planned by dogfooding `skills/plan/SKILL.md`** (10th self-host use). Source design: `docs/architecture/2026-06-28-continuous-discovery-skill-design.md` (owner-approved 2026-06-28).

## Goal
Ship the kit's own `continuous-discovery` skill — the problem-space product-discovery craft (a kit-original), the human↔AI **discovery partner** — wired single-seat to the Orchestrator (Product hat), folding in the banked count-neutral sweep at the orchestrator defs, as one atomic AMBER `apply.py`.

## Architecture
A new FLOOR skill (`skills/continuous-discovery/SKILL.md`, invoke-by-read) encodes the partner craft and points at the kit's existing discovery infra (`FEATURE-REQUEST` template, `discovery-complete.sh`, the DoR success-metric item) and its solution-space twin `design`; the Orchestrator def (FLOOR + native) gains a Product-hat reference; the shared verifier gains a `DISCOVERY_SKILL_FILE` var + `check_discovery_skill` (asserts the skill + the single Orchestrator ref, mirroring `check_skill`/`check_worktrees_skill`) + 2 negative cases; the keystone gains the `continuous-discovery` index row + comment path (prose already count-neutral from brick #9); the `skill-spine` claim + `orchestration.md` extend. No new gate, no new claim row, no guard edit.

## Tech stack
POSIX sh (verifier), Python3 (`apply.py`), Markdown (skill + defs + keystone + docs), TSV (claims). No new dependencies.

## Global constraints (verbatim from the design + standing process)
- **FLOOR-only / invoke-by-read** — no formal `skills` adapter dimension; no registry/verify.sh/export/guard edits (confirm `skills/*` glob covers the new file — **confirm-don't-add**).
- **SINGLE-SEAT, Orchestrator (Product hat)** — only the Orchestrator references the skill; the verifier asserts that one ref (reuses the existing `ORCH_DEF` var, no new def var). No Product *seat* (the human is the PO; no parallelism → a hat, not a seat, per agents-vs-skills).
- **Kit-original** — superpowers has no continuous/product-discovery skill (`brainstorming` = solution-space = the kit's `design`); the claim says "#1–8 replace superpowers; `evals` and `continuous-discovery` add crafts superpowers lacks." Do NOT write "replaces superpowers" for continuous-discovery.
- **One-term-one-meaning** — folder/name is `continuous-discovery`, NEVER bare `discovery` (that meaning is the skill-discovery keystone). The skill prose opens by disambiguating from skill-discovery.
- **Points at, does not duplicate, the discovery infra** — the skill references `templates/FEATURE-REQUEST-TEMPLATE.md`, `conformance/discovery-complete.sh`, the DoR success-metric/hypothesis item, and `skills/design`+`skills/verification`; it does not re-implement them.
- **Keystone structural check (v3.65.0) requires the continuous-discovery row** — this slice MUST add `skills/continuous-discovery` to the keystone index or `check_keystone` fails on every fixture + the live tree. Prose already count-neutral (brick #9) — add only the row + comment path.
- **Free fold-in (banked count-neutral sweep)** — fix the stale "the kit's **six** spine skills (design, plan, tdd, review, worktrees, verification)" at `agents/orchestrator.agent.md:67` + `.claude/agents/orchestrator.md:22` → count-neutral, since this slice edits those exact files. Leave historical CHANGELOG/log entries (point-in-time).
- **AMBER** — control-plane. Author under `scratchpad/continuous-discovery/`, idempotent `apply.py`, clone dry-run (`shellcheck` + `verify.sh --require` + case 24/25 flips). Agent never applies/commits/pushes/merges/tags ([[merge-tag-authority]]).
- **Version finishing folded into apply.py** — VERSION 3.66.0 → **3.67.0**, README badge, CHANGELOG entry.
- **ASCII-only markers** — `grep -qF`, ASCII; none begins with `-`.
- **Dual review + panel #18 + fold close into PR.** Ship discipline (incident lessons): `git show --stat HEAD` confirms the keystone + orchestrator defs are committed; admin-merge only when `conformance` is GREEN.

## Build model
**AMBER** — authored in `scratchpad/continuous-discovery/`; the single deliverable is `scratchpad/continuous-discovery/apply.py` + its clone-proven log.

## File map
| Path | Change | Responsibility |
|------|--------|----------------|
| `skills/continuous-discovery/SKILL.md` | **create** | The problem-space partner craft (invoke-by-read). Carries the markers + the infra/twin chain. |
| `agents/orchestrator.agent.md` | modify | New "Product (continuous-discovery) hat" section before the Architect hat; + count-neutral fold-in at line 67. |
| `.claude/agents/orchestrator.md` | modify | Native mirror of the Product hat; + count-neutral fold-in at line 22. |
| `conformance/orchestrator-loop-wired.sh` | modify | `DISCOVERY_SKILL_FILE` var + `check_discovery_skill()` (skill + Orchestrator ref) + main-body call + cases 1–23 fixtures gain the skill dir + orch ref + keystone index path + **new cases 24/25**. |
| `skills/using-skills/SKILL.md` | modify | Add `continuous-discovery` index row + conformance-comment path. (Prose already count-neutral — no count edit.) |
| `conformance/claims.tsv` | modify | Extend the `skill-spine` claim (kit-original wording, count-neutral). |
| `docs/operations/orchestration.md` | modify | Orchestrator wears the Product hat and follows `skills/continuous-discovery/SKILL.md` before the Architect hat. |
| `VERSION`, `README.md`, `CHANGELOG.md` | modify | Version finishing 3.66.0 → 3.67.0. |

## Tasks (serialized — shared verifier + keystone surface)

### Task 1 — Author the skill (`skills/continuous-discovery/SKILL.md`)
Frontmatter `name: continuous-discovery` + conformance-load-bearing HTML comment (mirror `skills/plan/SKILL.md:10-13`, listing the 6 markers). Open by disambiguating from skill-discovery (the keystone). Required content + EXACT marker strings (`grep -qF`, ASCII):
- `## When to use` — at the **front of the loop**, BEFORE `design` shapes a solution: when a problem/outcome is assumed rather than validated, or a slice carries an untested assumption.
- **`discovery partner`** (kit-distinctive, central/defined term — likely a heading "The discovery partner — not the decider") — the human is the PO; the agent structures the space and keeps it honest, never decides what to build. This is the marker that makes an "agent-does-discovery" paraphrase fail.
- **`outcome over output`** (kit-distinctive north-star) — frame work by the customer/business outcome it changes, not the feature shipped; a slice with no outcome hypothesis is output theatre. Ties to the DoR "success metric / hypothesis."
- **`opportunity solution tree`** (genuine-craft anchor, Torres) — map outcome → opportunities → solution ideas → experiments; the chosen opportunity is explicit, not the first idea.
- **`riskiest assumption`** (genuine-craft anchor) — name desirability/viability/feasibility/usability assumptions; rank the one that wastes the most work if wrong; test it first.
- **`small bet`** — design the cheapest experiment that proves/kills the riskiest assumption BEFORE building the slice; continuous, not big-bang.
- Hands off to `skills/design/SKILL.md` (problem-space → solution-space), never to implementation.
- Quadrants (desirability/viability/feasibility/usability) + interview technique as supporting **prose** (NOT markers — tight scope).
- Chain to `templates/FEATURE-REQUEST-TEMPLATE.md`, `conformance/discovery-complete.sh`, the DoR success-metric item, `skills/design/SKILL.md`, `skills/verification/SKILL.md`.
- Red-flags / rationalization table (e.g. "I'll just build it, the problem is obvious" → name + test the riskiest assumption first).

**Locked markers (6, `grep -qF`, ASCII):** `name: continuous-discovery` · `discovery partner` · `outcome over output` · `opportunity solution tree` · `riskiest assumption` · `small bet`.
*(Plan-time lock note: sharpens the design §4 candidate `opportunity` → the full high-entropy Torres term `opportunity solution tree`; all six confirmed ASCII, none leading `-`.)* Write to `scratchpad/continuous-discovery/SKILL.md`.

### Task 2 — Wire the Orchestrator seat (2 def edits)
- `agents/orchestrator.agent.md`: add a **"## Product (continuous-discovery) hat"** section placed BEFORE "## Design (Architect hat)" — "Before convening the cast and before the Architect hat shapes a solution, wear the Product hat and follow the kit's own `skills/continuous-discovery/SKILL.md` (read + follow it) to interrogate the problem/outcome and surface+test the riskiest assumption. The human is the PO; this is a *hat the Orchestrator wears*, not a Product seat (agents-vs-skills rule)." Literal `skills/continuous-discovery/SKILL.md`.
  - **Count-neutral fold-in (line ~67):** "indexes the kit's **six** spine skills (design, plan, tdd, review, worktrees, verification)" → "indexes the kit's spine skills (see the keystone index)". Count- and membership-neutral.
- `.claude/agents/orchestrator.md`: native mirror of the Product-hat reference + the same count-neutral fold-in at line ~22.
Author as full-file copies or surgical idempotent inserts under `scratchpad/continuous-discovery/`.

### Task 3 — Verifier: check + non-vacuous teeth (TDD heart)
In a copy of `conformance/orchestrator-loop-wired.sh`:
1. Add path var: `DISCOVERY_SKILL_FILE="${ORCH_LOOP_DISCOVERY_SKILL:-skills/continuous-discovery/SKILL.md}"`. (Reuse the existing `ORCH_DEF` var — no new def var.)
2. `check_discovery_skill()` taking `<skill> <orch_def>` (mirror `check_worktrees_skill`): assert file exists; `grep -qF` each of the 6 markers; assert orch_def references `skills/continuous-discovery/SKILL.md`. Distinct FAIL lines. (Comment note: no marker begins with `-`, so plain `grep -qF` is safe — no `--` needed, unlike worktrees.)
3. Main-body call after `check_evals_skill`: `check_discovery_skill "$DISCOVERY_SKILL_FILE" "$ORCH_DEF" || fail=1`.
4. A `_discovery_skill_ok()` emitter (mirror `_evals_skill_ok`) with all 6 markers.
5. Cases 1-23: in EACH, create `$rN/skills/continuous-discovery/SKILL.md` via `_discovery_skill_ok`, append `skills/continuous-discovery/SKILL.md` to the orchestrator fixture def (`$rN/agents/orchestrator.agent.md`), add `skills/continuous-discovery` to that fixture's keystone (`_keystone_ok` must now emit it so the structural `check_keystone` passes), AND thread `ORCH_LOOP_DISCOVERY_SKILL` into the env subshell.
6. **Case 24** (marker teeth): emit a discovery skill MISSING a marker (drop `outcome over output`) → exit 1.
7. **Case 25** (Orchestrator reference teeth): conformant skill, but the Orchestrator def does NOT reference `skills/continuous-discovery/SKILL.md` → exit 1.

Note: `_keystone_ok` now must index `skills/continuous-discovery` (the structural check enumerates the fixture's skills dirs, which now include `continuous-discovery`); ensure every case's keystone names it or those cases fail for the wrong reason.

**Red→green proof (scratchpad):**
- `sh scratchpad/continuous-discovery/orchestrator-loop-wired.sh --selftest` → all 25 cases PASS.
- Mutate case 24 (restore `outcome over output`) → case 24 FLIPs to FAIL. Revert.
- Give case 25 the Orchestrator ref → case 25 FLIPs to FAIL. Revert.

### Task 4 — Keystone (continuous-discovery row) + claim + ops doc
- `skills/using-skills/SKILL.md`:
  - Add the `continuous-discovery` index row after the `evals` row: `| continuous-discovery | \`skills/continuous-discovery\` | Problem-space product discovery before solutioning (frame the outcome, surface + test the riskiest assumption). |`.
  - Add `skills/continuous-discovery` to the conformance-comment path list (the HTML comment that enumerates index paths).
  - **No count swaps** — prose already count-neutral ("every spine skill on disk") from brick #9.
- `conformance/claims.tsv` `skill-spine` row: extend → "… + the kit's own `continuous-discovery` skill (`skills/continuous-discovery/SKILL.md`), the problem-space product-discovery craft, referenced by the orchestrator (Product hat) … bricks #1-8 replace superpowers (content + discovery); `evals` and `continuous-discovery` add crafts superpowers lacks". Same id + verifier command; no new row. Count-neutral wording.
- `docs/operations/orchestration.md`: extend → the Orchestrator wears the Product hat and follows `skills/continuous-discovery/SKILL.md` for problem-space discovery BEFORE the Architect hat.

### Task 5 — Assemble `scratchpad/continuous-discovery/apply.py` (idempotent) + version finishing
Mirror prior apply.py (base64-embed SKILL + verifier): write the skill; 2 orchestrator def edits (Product hat insert + count-neutral swap, idempotent); replace the verifier; keystone edits (continuous-discovery row + comment path, idempotent); claim + ops swaps; VERSION 3.66.0→3.67.0, README badge, CHANGELOG prepend. Guard every mutation for clean re-run no-op.

### Task 6 — Clone dry-run (confabulation-proof)
`git clone . <unique>` → `python3 apply.py` → `shellcheck` → selftest (25/25) → `verify.sh --require` (skill-spine PASS, **and** confirm `check_keystone` passes with the continuous-discovery row indexed, 0 failed) → VERSION 3.67.0 → re-run apply.py (idempotent). Capture the log + the case 24/25 flip evidence.

## Self-review (spec coverage)
- Skill (6 markers + infra/twin chain + disambiguation) → T1. Single-seat Orchestrator wiring (FLOOR+native) + count-neutral fold-in → T2. check + cases 24/25 + cases 1–23 fixtures (incl. orch ref + keystone continuous-discovery row) + non-vacuity → T3. Keystone row + claim + ops → T4. AMBER apply.py + version finishing → T5. Clone-proof incl. structural-keystone-passes → T6.
- No guard/registry/verify.sh/export edits → confirmed (confirm-don't-add).
- Single ref-leg proven (case 25); kit-original claim wording (no "replaces superpowers" for continuous-discovery) → T4.
- One-term-one-meaning honored (folder `continuous-discovery`, disambiguation in prose) → T1.
- Placeholder scan: markers + keystone row are exact literal strings; commands carry expected output. ✔

## Terminal state / handoff
Hand to the build skill (subagent-driven via the Engineer seat, control-plane authored to `scratchpad/`): `scratchpad/continuous-discovery/apply.py` + the Task 6 clone log incl. the 24/25 flips + structural-keystone-passes. Then dual review (reviewer + security) → panel #18 → human applies + ships (git show --stat + green-conformance discipline). **This completes the intended Phase-2 spine. Next: E10 zero-superpowers acceptance.**
