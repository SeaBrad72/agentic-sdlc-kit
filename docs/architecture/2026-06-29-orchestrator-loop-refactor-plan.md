# Plan — `orchestrator-loop-wired.sh` data-driven refactor

**Design:** `docs/architecture/2026-06-29-orchestrator-loop-refactor-design.md` (owner-approved 2026-06-29).

**Goal:** De-duplicate the orchestrator-loop verifier into a spine table + one generic skill-check + a table-driven selftest, preserving every PASS/FAIL verdict exactly.

**Architecture:** A POSIX-sh newline-delimited table of `{name, skill_file_var, TAB-markers, def:refpath;...}` records drives one `check_spine_skill` function (main path) and one `build_conformant_tree` + generic negative driver (selftest). The 4 bespoke checks (`check_roster`, `check_loop`, `check_gp`, `check_keystone`) are untouched. Equivalence to current behaviour is proven by a scratchpad differential harness (OLD vs NEW main-path across a fixture matrix).

**Tech stack:** POSIX `sh` (the file is `#!/bin/sh`, `set -eu`); Python 3 for the AMBER `apply.py`; `git show` for the OLD baseline.

**Global constraints (verbatim from spec):**
- Behaviour-preserving: every current PASS/FAIL verdict preserved; FAIL message strings preserved verbatim.
- No new gate, claim, or guard matcher; the 3 backed claims (`orchestrator-loop`, `conflict-safe-integration`, `skill-spine`) unchanged.
- `grep -qF --` used uniformly (markers may start with `-`).
- TAB as the record/marker separator (markers contain spaces, never tabs).
- All `ORCH_LOOP_*` env overrides keep working (adopter + `--selftest`).
- Strictly behaviour-preserving — the `fresh`/`native` marker cleanup is a SEPARATE follow-up slice, NOT this one.

**Build model:** **AMBER** — `conformance/` is control-plane. The shipped edit lands via an idempotent, clone-proven `apply.py` a human runs. Version finishing (3.76.0 → 3.77.0) folded into `apply.py`. Build artifacts in `scratchpad/orch-loop-refactor/` (gitignored). Design/plan/panel docs are agent-committable on the feature branch; the apply.py run + commit/push/PR/merge/release-tag are the human's.

---

## File map

| File | Shipped? | Responsibility |
|---|---|---|
| `conformance/orchestrator-loop-wired.sh` | ✅ (via apply.py) | The refactored verifier — table + generic check + table-driven selftest |
| `VERSION`, `CHANGELOG.md`, `README.md` | ✅ (via apply.py) | Version finishing → 3.77.0 |
| `scratchpad/orch-loop-refactor/diff-harness.sh` | ❌ build-time | Differential characterization test (OLD vs NEW) |
| `scratchpad/orch-loop-refactor/old-orchestrator-loop-wired.sh` | ❌ build-time | The pre-refactor file captured via `git show HEAD:` (OLD oracle) |
| `scratchpad/orch-loop-refactor/apply.py` | ❌ build-time | The AMBER applier (writes the new file + version finishing) |
| `docs/architecture/2026-06-29-orchestrator-loop-refactor-{design,plan}.md` | ✅ (agent commit) | Spec + plan |
| `docs/governance/meta-control-log.md` + panel #28 + `.meta-control-last` | ✅ (human) | Governance close at ship |

---

## Task 1 — Differential characterization harness + OLD baseline *(test-first; build-time only)*

**Deliverable:** `scratchpad/orch-loop-refactor/diff-harness.sh` that builds a fixture matrix, runs BOTH the OLD and a target NEW verifier main-path against each fixture, and asserts identical exit codes.

1. Capture the OLD oracle:
   `git show HEAD:conformance/orchestrator-loop-wired.sh > scratchpad/orch-loop-refactor/old-orchestrator-loop-wired.sh`
2. Write `diff-harness.sh`. It must:
   - Provide the same fixture builders the selftest uses (conformant agent/skill files), but as a single `build_tree <dir>` that produces a FULLY conformant tree (all 4 agent defs, loop script, golden-path, all 11 skills incl. keystone + all seat references).
   - Define the fixture matrix as a list of `(label, mutation, expected_exit)`:
     - `conformant` → no mutation → 0
     - per skill marker (every marker in the §3 design table) → delete the line carrying ONLY that marker from the conformant tree → 1
     - per seat reference (design→orch, plan→orch, tdd→eng, review→reviewer, worktrees→orch, verification→eng, verification→orch, debugging→eng, evals→eng, evals→security, discovery→orch, operating→orch) → strip that one reference line → 1
     - `missing-heading` (drop `## Stance` from orchestrator def) → 1
     - `no-killswitch` (loop script without `runaway-guard.sh step`) → 1
     - `no-conflict` (loop script without `kit.conflict`) → 1
     - `keystone-unindexed` (add an on-disk `skills/zzz-probe/SKILL.md` but DON'T index it in the keystone) → 1
     - `no-gp-job` (golden-path without the `orchestrator-loop` job) → 1
   - For each fixture: build the tree, apply the mutation, then run BOTH `sh OLD <env-overrides>` and `sh NEW <env-overrides>` capturing exit codes; assert `exit_old == exit_new` AND each equals `expected_exit`. Print `MATCH`/`MISMATCH` per fixture and a final tally.
   - `NEW` is taken from `${DIFF_NEW:-conformance/orchestrator-loop-wired.sh}` so it can target the working tree.
3. **Run it now (RED-ish baseline):** with NEW == OLD (the unrefactored file), every fixture must MATCH and hit its `expected_exit`. This proves the harness itself is sound (its oracle agrees with itself) BEFORE any refactor.
   `sh scratchpad/orch-loop-refactor/diff-harness.sh` → expect `ALL MATCH (N/N)`.

**Honest ceiling:** this harness proves main-path equivalence across the enumerated matrix; it does not prove the selftest internals match (that is the new selftest's own job — non-vacuity).

**Self-verify:** harness exits 0 with NEW==OLD; the matrix includes ≥1 fixture per marker and per reference (count them in the output).

---

## Task 2 — Refactor production checks to table + `check_spine_skill` *(markers byte-identical)*

**Deliverable:** the 10 uniform `check_*_skill` functions replaced by one table + one generic function; main block iterates; differential harness green.

1. Add the spine table near the top (after the path variables), as a heredoc/`set --`-free newline string. Each record: `name<TAB>SKILL_VAR<TAB>marker1<TAB>marker2...<TAB>__REFS__<TAB>DEF_VAR:refpath;DEF_VAR:refpath`. Use a sentinel (`__REFS__`) to separate the variable-length marker list from the refs field, OR put refs first then markers — choose one and document it inline. (Recommended: `name | skill_var | refs | markers...` so the only variable-length field is last.)
2. Write `check_spine_skill <skill_file> <refs> <tab-markers>`:
   - `[ -f "$s" ]` else `FAIL: missing skill $s` / return 1 (preserve wording family).
   - marker loop with `IFS=<TAB>`, `grep -qF -- "$m" "$s"` → FAIL with the **exact** existing message `FAIL: $s missing kit-distinctive marker '$m' (generic copy?)`.
   - refs loop: split on `;`, each `def:refpath`; `[ -f "$def" ]` else missing-def FAIL; `grep -qF "$refpath" "$def"` else a reference FAIL. **Preserve the per-skill reference FAIL wording** — to keep messages verbatim, store the exact tail message per ref in the table, or accept a generalized-but-equivalent message (DECISION FOR BUILD: differential harness only checks exit codes, so a generalized reference message is acceptable; keep it informative).
3. Replace the main-block invocations (lines ~1035-1051 region) with a loop over the table that resolves `SKILL_VAR`/`DEF_VAR` names to their values (POSIX indirection via `eval` on a vetted, table-internal variable name — never on external input) and calls `check_spine_skill`. Keep `check_roster`/`check_loop`/`check_gp`/`check_keystone` calls as-is.
4. Delete the 10 now-dead `check_*_skill` function definitions.
5. **Run the differential harness against the working tree:**
   `DIFF_NEW=conformance/orchestrator-loop-wired.sh sh scratchpad/orch-loop-refactor/diff-harness.sh` → expect `ALL MATCH`.
6. Run the EXISTING (not-yet-refactored) selftest — it must still pass, since the main-path behaviour is unchanged and the selftest exercises the main path via subprocess:
   `sh conformance/orchestrator-loop-wired.sh --selftest` → `OK:`.

**Honest ceiling:** after Task 2, the production checks are table-driven and proven equivalent; the selftest is still the old verbose one (refactored in Task 3).

**Self-verify:** both the differential harness AND the old selftest are green; `grep -c 'check_.*_skill()' ` shows the 10 dead functions removed (only `check_spine_skill` remains among skill checks).

---

## Task 3 — Refactor the selftest to table-driven

**Deliverable:** the 27 copy-paste cases replaced by `build_conformant_tree` + a generic negative driver iterating the table, plus the bespoke cases 1–4 and the keystone structural case; differential harness still green; new selftest green with ≥ as many assertions as before.

1. Write `build_conformant_tree <dir>` driven by the table: create agents, loop script, golden-path, and every skill (conformant markers via a per-skill `printf`), append every seat reference. Reuse the marker lists FROM THE TABLE so a future brick needs no selftest edit.
2. Write the generic negative driver: for each table row, (a) build a fresh conformant tree, delete one marker line for that skill, run main-path with the env overrides, assert exit 1 + emit `selftest PASS: <name> skill missing a kit-distinctive marker -> exit 1`; (b) build fresh, strip that skill's seat reference(s), assert exit 1 + emit the reference-teeth PASS line. For two-seat skills, break EACH seat reference independently (preserves today's coverage).
3. Keep bespoke: case 1 (conformant→0, the liveness anchor), case 2 (missing heading→1), case 3 (A2 kill-switch→1), case 4 (conflict→1), and the keystone structural regression (on-disk-but-unindexed skill→1, the hardcoded-list-vs-enumeration teeth).
4. Preserve the final `OK:`/`FAIL:` summary lines and the `sf` accumulator semantics.
5. **Run the new selftest:** `sh conformance/orchestrator-loop-wired.sh --selftest` → `OK:`; count PASS lines ≥ 27 (no coverage lost).
6. **Re-run the differential harness** (main-path unaffected by selftest refactor, but confirm): `ALL MATCH`.
7. Confirm line count dropped materially: `wc -l conformance/orchestrator-loop-wired.sh` (expect a large reduction from 1064).

**Honest ceiling:** the new selftest proves the refactored checks have teeth (non-vacuity, liveness anchor present); the differential harness proves they are the SAME teeth as before.

**Self-verify:** new selftest green; PASS-line count ≥ 27; differential harness green; `shellcheck conformance/orchestrator-loop-wired.sh` clean (or no NEW warnings vs OLD).

---

## Task 4 — AMBER `apply.py` (idempotent, version finishing) + clone proof

**Deliverable:** `scratchpad/orch-loop-refactor/apply.py` that writes the refactored file and does version finishing, proven idempotent on a fresh clone.

1. `apply.py` writes `conformance/orchestrator-loop-wired.sh` (base64-embedded full new content — whole-file replace, simplest for a total rewrite), `chmod 0755`.
2. Version finishing folded in (per the standing fix): `VERSION` 3.76.0 → 3.77.0; `README.md` badge; `CHANGELOG.md` entry (Keep-a-Changelog, refactor under a 3.77.0 heading). All edits all-or-abort + idempotent (re-run = no-op, exit 0).
3. **Clone proof:** `git clone . /tmp/clone-x && cd /tmp/clone-x && python3 .../apply.py && sh conformance/orchestrator-loop-wired.sh --selftest && sh conformance/orchestrator-loop-wired.sh` (main path) and re-run apply.py to confirm idempotency. (Run the differential harness against the clone too: OLD oracle vs the applied NEW.)

**Self-verify:** on a fresh clone — apply.py exits 0, selftest `OK:`, main-path `OK:`, second apply.py run is a clean no-op, differential harness `ALL MATCH`.

---

## Task 5 — Dual review + governance + ship *(human-gated)*

1. **Dual review** (builder ≠ reviewer): `reviewer` agent (correctness / standards / behaviour-preservation / non-vacuity) + `security-reviewer` agent (the refactor touches a control-plane verifier — confirm no teeth weakened, no `eval` injection surface, FAIL strings/exit codes preserved, guard-immutability intact).
2. Address findings; re-prove (selftest + differential harness) after any change.
3. **Meta-control panel #28** (Kit-Steward) — GO/NO-GO; marker `.meta-control-last` + `meta-control-log.md` row (human-authored per M2-S5).
4. **Ship (human):** run `apply.py` → `git show --stat` confirms the file + VERSION/CHANGELOG/README in the commit → push → PR → `gh pr merge --squash --admin --delete-branch` (control-plane PR is red on `control-plane-ratification` by-design) → `git checkout main && git pull && sh scripts/release-tag.sh` (after main CI green).
5. Update memory/roadmap: refactor #3 done; bank the `fresh`+`native` marker-cleanup follow-up slice.

---

## Spec coverage check (self-review)

| Spec requirement | Task |
|---|---|
| Table + generic check (§4.1) | Task 2 |
| `grep -qF --` uniform, TAB separator (§4.1, §6) | Task 2 |
| Table-driven selftest (§4.2) | Task 3 |
| Keystone stays bespoke (§3) | Task 2 (untouched) / Task 3 (bespoke case kept) |
| Differential characterization proof (§4.3, owner-ratified) | Task 1, re-run in 2/3/4 |
| FAIL strings / exit codes preserved (§2, §6) | Tasks 2–3 + differential harness |
| Env overrides preserved (§6) | Task 2 |
| AMBER + version finishing 3.77.0 (§7) | Task 4 |
| Dual review + panel (§7) | Task 5 |
| Strictly behaviour-preserving; marker cleanup deferred | global constraint; Task 5 banks follow-up |

## Parallelism / honest ceiling

Tasks are **strictly serial** (each builds on the prior file state; single file). No fan-out. The differential harness is the load-bearing safety net re-run after every code-changing task; the shipped selftest carries non-vacuity. Equivalence proof (differential) is build-time, not a shipped gate — stated, not implied by green.
