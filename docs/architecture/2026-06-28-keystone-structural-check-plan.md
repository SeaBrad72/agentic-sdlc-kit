# Implementation plan — keystone structural self-check (hardening slice)

**Planned by dogfooding `skills/plan/SKILL.md`** (8th self-host use). Source design: `docs/architecture/2026-06-28-keystone-structural-check-design.md` (owner-approved 2026-06-28).

## Goal
Make `check_keystone` enumerate every on-disk `skills/*/SKILL.md` (excluding the keystone) instead of a hardcoded path list, so the keystone index cannot drift green relative to disk — as one atomic AMBER `apply.py`. Verifier-only + one keystone wording tweak.

## Architecture
`conformance/orchestrator-loop-wired.sh` is the only logic change: `check_keystone` derives `SKILLS_DIR` from the keystone path and loops over `"$SKILLS_DIR"/*/`, asserting the keystone indexes each `skills/<name>` (skipping `using-skills`). A new selftest case 20 proves the enumeration is dynamic (a novel-named skill on disk, unindexed → exit 1). One wording line in `skills/using-skills/SKILL.md` makes the structural enforcement literal. No new skill, seat, claim, or gate.

## Tech stack
POSIX sh (verifier), Python3 (`apply.py`), Markdown (keystone), TSV (claims, optional wording tweak). No new dependencies.

## Global constraints
- **FLOOR-only / verifier-only** — no new skill/seat; no registry/verify.sh/export/guard edits (`skills/*` + `conformance/*` already control-plane — confirm-don't-add).
- **POSIX sh portability** — the enumeration must work in dash/sh (no bashisms): `for d in "$SKILLS_DIR"/*/` (trailing-slash glob), `basename`, `[ -f ... ]`. Handle the no-match glob case (if `skills/` has no subdirs the glob stays literal — guard with `[ -d "$d" ]` or `[ -f "$d/SKILL.md" ]` which already filters).
- **AMBER** — control-plane verifier. Author under `scratchpad/keystone-struct/`, assemble an idempotent `apply.py`, prove on a **clone dry-run** (`shellcheck` + `verify.sh --require` + the case-20 flip). The agent never applies/commits/pushes/merges/tags ([[merge-tag-authority]]).
- **Version finishing folded into apply.py** — VERSION 3.64.1 → **3.65.0**, README badge, CHANGELOG entry.
- **Non-vacuity** — case 20 must FAIL when the novel skill is unindexed AND flip to a different state when indexed (prove it's the enumeration, not a fluke).
- **Dual review + panel #16 + fold close into PR.** Ship discipline (learned from the incident): `git show --stat HEAD` confirms the verifier + keystone are both committed; admin-merge only when `conformance` is GREEN.

## Build model
**AMBER** — authored in `scratchpad/keystone-struct/`; the single deliverable is `scratchpad/keystone-struct/apply.py` + its clone-proven log.

## File map
| Path | Change | Responsibility |
|------|--------|----------------|
| `conformance/orchestrator-loop-wired.sh` | modify | `check_keystone` enumerates `$SKILLS_DIR/*/SKILL.md`; new case 20 (novel-skill structural teeth); comment updates. |
| `skills/using-skills/SKILL.md` | modify | One wording line: "…enforces it **against every `skills/*` on disk**…". |
| `conformance/claims.tsv` | modify (optional) | Tighten the `skill-spine` wording to mention structural enforcement (same id + command). |
| `VERSION`, `README.md`, `CHANGELOG.md` | modify | Version finishing 3.64.1 → 3.65.0. |

## Tasks (serialized — single shared verifier surface)

### Task 1 — Rewrite `check_keystone` to enumerate (TDD heart)
In a copy of `conformance/orchestrator-loop-wired.sh` under `scratchpad/keystone-struct/`:
1. In `check_keystone() { s=$1; o=$2; ... }`, after the discipline-marker loop, REPLACE the hardcoded index for-loop with:
   ```
   skills_dir=$(dirname "$(dirname "$s")")
   for d in "$skills_dir"/*/; do
     [ -f "$d/SKILL.md" ] || continue
     name=$(basename "$d")
     [ "$name" = "using-skills" ] && continue
     grep -qF "skills/$name" "$s" || { echo "FAIL: $s does not index on-disk spine skill 'skills/$name' (index not exhaustive)"; miss=1; }
   done
   ```
2. Keep the discipline-marker greps and the Orchestrator-reference assertion unchanged.
3. Update the `check_keystone` header comment ("indexes ALL SEVEN spine skills" → "indexes every on-disk `skills/*` spine skill (structural — enumerated, not a hardcoded list)") and line-13 header comment similarly.

### Task 2 — New selftest case 20 (structural non-vacuity)
Mirror the case-16/17 structure. Case 20: build a fully conformant tree (all discipline markers + Orchestrator ref + every existing skill indexed), THEN create an extra skill dir with a novel name not in any prior list — `$r20/skills/zzz-probe/SKILL.md` (any non-empty content) — and do NOT add `skills/zzz-probe` to that fixture's keystone. Assert the run exits 1 (`c20_fail=1` → PASS); print `selftest PASS:`/`selftest FAIL:` lines. This proves the loop enumerates disk (a hardcoded list would not catch `zzz-probe`).
- Confirm case 16 (keystone omits `skills/verification`) still exits 1 under the new enumeration (the on-disk `skills/verification` dir exists in the fixture but is unindexed → fail).
- Verify cases 1–19 still pass (their `_keystone_ok` keystones index every `skills/*` dir the fixtures create).

**Red→green proof (scratchpad, before apply.py):**
- `sh scratchpad/keystone-struct/orchestrator-loop-wired.sh --selftest` → all 20 cases PASS.
- Mutate case 20 to ALSO index `skills/zzz-probe` in its keystone → case 20 must FLIP to FAIL ("structural teeth vacuous"). Revert.
- Sanity: temporarily revert `check_keystone` to the hardcoded list → case 20 must FAIL (the hardcoded list misses `zzz-probe`), proving the new enumeration is what catches it. Revert.

### Task 3 — Keystone wording tweak
`skills/using-skills/SKILL.md`: idempotent swap — "`check_keystone` enforces it, so every new skill brick must add its row here." → "`check_keystone` enforces it against every `skills/*` on disk, so every new skill brick must add its row here." (No marker churn; the discipline markers are untouched.)

### Task 4 — Claim wording (optional, same id)
`conformance/claims.tsv` `skill-spine` row: optionally append "…(`check_keystone` enforces the index against every on-disk `skills/*`)…". Same claim id + verifier command; no new row. If it complicates the idempotent swap, skip — the structural behaviour is what matters.

### Task 5 — Assemble `scratchpad/keystone-struct/apply.py` (idempotent) + version finishing
Mirror prior apply.py shape (base64-embed the verifier): write the verifier (idempotent — guard on a sentinel like the new `on-disk spine skill` FAIL string or `skills_dir=$(dirname`); swap the keystone wording (idempotent); optional claim swap; bump VERSION 3.64.1→3.65.0, README badge, prepend CHANGELOG. Guard every mutation so a re-run is a clean no-op.

### Task 6 — Clone dry-run (confabulation-proof)
`git clone . <unique-dir>` → `python3 apply.py` → `shellcheck conformance/orchestrator-loop-wired.sh` → `sh conformance/orchestrator-loop-wired.sh --selftest` (20/20 PASS) → `sh conformance/verify.sh --require` (skill-spine PASS, 0 failed) → VERSION 3.65.0 → re-run apply.py (idempotent). Capture the log. **Verify on the clone, never trust the report** (`skills/verification/SKILL.md`).

## Self-review (spec coverage)
- Structural enumeration → T1. Case 20 structural teeth + case 16 retained + cases 1–19 intact → T2. Keystone wording → T3. Claim wording (optional) → T4. AMBER apply.py + version finishing → T5. Clone-proof → T6.
- POSIX-sh portability of the glob/basename loop → T1 (Global Constraints).
- No new skill/seat/claim-row/gate/guard → confirmed.
- Placeholder scan: the enumeration snippet + case-20 fixture are concrete; commands carry expected output. ✔

## Terminal state / handoff
Hand to the build skill (subagent-driven via the Engineer seat): produce `scratchpad/keystone-struct/apply.py` + the Task 6 clone log incl. the case-20 + hardcoded-list-regression flip evidence. Then dual review → panel #16 → human applies + ships (with the `git show --stat` discipline). **Next: brick #9 `evals` on the now-hardened keystone coupling.**
