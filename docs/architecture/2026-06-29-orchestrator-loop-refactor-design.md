# Design — `orchestrator-loop-wired.sh` data-driven refactor

**Date:** 2026-06-29
**Slice:** Roadmap priority #3 (Refactoring lens #1) — make the orchestrator-loop conformance verifier data-driven.
**Change-class:** Control-plane (`conformance/` path) — full rigor; AMBER `apply.py`; dual review (reviewer + security); human ships.
**Status:** DESIGN — awaiting owner ratification (design HARD-GATE).

---

## 1. Problem

`conformance/orchestrator-loop-wired.sh` (1064 lines) is the behaviour-lock for the
orchestration loop and the skill spine. It has grown **super-linearly** — the roadmap
measured ~128 lines per new skill brick. Root cause: triple redundancy.

1. **10 near-identical `check_*_skill` functions.** Each does the same three things —
   skill file exists → carries kit-distinctive markers → the owning seat(s) reference it —
   differing only in *file path*, *marker list*, and *which seat(s)* reference it.
2. **27 selftest cases, each of which reconstructs all 14 skills.** A case is ~57 lines of
   `mkdir`/`printf` fixture setup plus one ~600-char env-var invocation line. Adding skill
   #N therefore edits all N−1 existing cases (the quadratic term).
3. **One path variable + one main-block invocation** per skill (cheap; not the problem).

This worsens with **every** future brick. Fixing it now (before more bricks land) is the
right-weight move.

## 2. Goal & non-goals

- **Goal:** behaviour-preserving refactor. Every current PASS/FAIL verdict — on the real
  tree and on every fixture — is preserved exactly. Future bricks cost ~1 table row.
- **Non-goal:** changing what is asserted, adding/removing any check, or altering the
  claims (`orchestrator-loop`, `conflict-safe-integration`, `skill-spine`) this verifier
  backs. No behaviour change, no new gate.

## 3. The structure today (what we refactor vs. what we keep)

**Keep bespoke (4 checks — not uniform skill checks):**
- `check_roster` — six-heading structure across the 4 agent defs.
- `check_loop` — kill-switch + `kit.denied` + `kit.conflict` + `git diff --name-only` wiring.
- `check_gp` — golden-path job name (with line-comment stripping).
- `check_keystone` — **structural enumeration** (greps the *filesystem* for every on-disk
  `skills/*`, not a marker list). Genuinely different shape → stays bespoke.

**Refactor (10 uniform skill checks) into a table + one generic function:**

| skill | markers | seat-ref(s) |
|---|---|---|
| design | `name: design`, `<HARD-GATE>`, `## When to use`, `Design-intent lens`, `RE-SELECT`, `Honest ceiling` | Orchestrator |
| plan | `name: plan`, `## When to use`, `INVEST`, `AMBER`, `Conformance lock`, `Dual review` | Orchestrator |
| tdd | `name: tdd`, `## When to use`, `Red-Green-Refactor`, `non-vacuity`, `critical path`, `evals` | Engineer |
| review | `name: review`, `## When to use`, `Confidence`, `adversarial`, `builder`, `NEEDS-FIXES` | Reviewer |
| worktrees | `name: worktrees`, `disjoint file sets`, `--no-renames`, `out-of-slice`, `native` | Orchestrator |
| verification | `name: verification`, `confabulation`, `clone dry-run`, `evidence before claims`, `fresh` | Engineer **+** Orchestrator |
| debugging | `name: debugging`, `root cause`, `reproduce`, `regression test`, `one hypothesis` | Engineer |
| evals | `name: evals`, `eval-driven`, `judge`, `red-team`, `threshold` | Engineer **+** Security |
| continuous-discovery | `name: continuous-discovery`, `discovery partner`, `outcome over output`, `opportunity solution tree`, `riskiest assumption`, `small bet` | Orchestrator |
| operating | `name: operating`, `blast radius`, `advisory, not actuating`, `the human commands the catastrophic action`, `autonomy tier`, `surface, don't actuate` | Orchestrator |

The two-seat rows (verification, evals) are why a seat-ref is a **list**, not a scalar — a
uniform representation that subsumes both 1-seat and 2-seat checks.

## 4. Proposed design

### 4.1 Production logic (the shipped checks)

A POSIX-sh table encoded as newline-delimited records (sh has no arrays). Each record:

```
<name> | <skill_file_var> | <markers> | <seat1_def_var>:<refpath> [;<seat2_def_var>:<refpath>]
```

One generic function consumes a record:

```sh
check_spine_skill() {  # <skill_file> <markers_tab_sep> <def:refpath;...>
  s=$1; markers=$2; refs=$3; miss=0
  [ -f "$s" ] || { echo "FAIL: missing skill $s"; return 1; }
  # grep -qF -- is used uniformly: some markers (--no-renames) start with '-'.
  OLD_IFS=$IFS; IFS='	'
  for m in $markers; do
    grep -qF -- "$m" "$s" || { echo "FAIL: $s missing kit-distinctive marker '$m' (generic copy?)"; miss=1; }
  done
  IFS=$OLD_IFS
  # each ref is def<TAB>refpath; the def must reference the refpath
  ...one ref-loop, same FAIL wording as today...
  return $miss
}
```

The main block iterates the table, resolving the `*_var` names to the env-overridable
path variables that already exist (so `--selftest` can still point at a fixture tree, and
adopter overrides keep working). **The FAIL message strings are preserved verbatim** so
any downstream log-grepping (and the honest claim wording) is unaffected.

**Correctness note (caught during design):** today only `check_worktrees_skill` and
`check_operating_skill` use `grep -qF --`; the other eight use plain `grep -qF`. Since no
*current* marker in those eight starts with `-`, behaviour is identical — but the generic
function uses `grep -qF --` everywhere, which is strictly safer and a precondition for the
table (worktrees/operating markers live in the same loop as the rest).

### 4.2 Selftest (the safety net) — table-driven

- One `build_conformant_tree <dir>` helper, driven by the same table, that constructs a
  fully-conformant fixture (replacing the per-case copy-paste).
- A generic negative driver: for each table row, build a conformant tree, then (a) drop one
  marker from that skill → assert exit 1; (b) drop that skill's seat reference → assert
  exit 1. This *generates* the marker-teeth + reference-teeth pair per skill (today's
  cases 5–27) from the table.
- Keep bespoke: the conformant-pass case, missing-heading, A2 kill-switch teeth, conflict
  teeth (cases 1–4), and the **keystone structural** regression (the hardcoded-list-vs-
  enumeration case — its teeth ARE the enumeration, so it can't be table-generated).

### 4.3 Behaviour-preservation proof — characterization / differential test (owner-ratified)

The decisive safeguard, because we are rewriting the net and the thing it protects at once.
A **one-shot differential harness** (lives in `scratchpad/`, **not shipped**):

1. Enumerate a fixture matrix: the conformant tree, plus every single-marker-drop, every
   single-seat-reference-drop, the keystone structural breaks, and the 4 non-skill breaks.
2. Run the **OLD** verifier (`git show HEAD:...` / the pre-refactor file) against each
   fixture; record exit code + stdout.
3. Run the **NEW** verifier against the identical matrix; assert exit code matches for
   every fixture (and spot-check stdout FAIL lines).
4. Any divergence = the refactor changed behaviour → fix before proceeding.

This proof is **independent of the rewritten selftest** — it compares old-vs-new directly,
so it cannot be fooled by a co-refactored test. It is the honest-ceiling answer: the green
selftest proves the new checks have teeth; the differential harness proves they are the
*same* teeth.

## 5. Kit-discipline check (design skill)

- **Honest ceiling.** The shipped selftest proves *non-vacuity* (teeth exist). The
  *equivalence* to the old behaviour is proven by the differential harness, which is a
  build-time artifact, not a shipped gate — stated plainly, not implied by the green check.
- **Non-vacuity.** Preserved: the table-generated negative cases give every skill a
  load-bearing marker-break and reference-break, exactly as today. Liveness anchor = the
  conformant-pass case.
- **Right-weight / anti-ceremony.** No new gate, no new claim, no new guard matcher. One
  verifier shrinks; future bricks get cheaper. Extends the existing mechanism.
- **Control-plane completeness.** This slice does **not** make any new path control-plane
  (`conformance/` is already guard-protected). No guard-matcher or autonomy-fixture change.
  The file itself is edited via AMBER `apply.py` under the existing guard.
- **Design-intent / default-KEEP.** We keep all 4 bespoke checks and every assertion; we
  only de-duplicate the uniform 10. Nothing asserted today is dropped.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Refactor silently weakens a check (vacuous) | Differential harness (old vs new, full matrix) + the shipped table-generated negatives |
| `IFS`/word-split bug splits a marker containing a space (e.g. `## When to use`, `discovery partner`) | Use TAB as the record/marker separator (markers contain spaces but not tabs); unit-cover a multi-word marker in the differential matrix |
| Marker starting with `-` breaks grep | `grep -qF --` uniformly (§4.1) |
| Adopter/`--selftest` env overrides break | Table resolves the **existing** `ORCH_LOOP_*` path variables; overrides unchanged |
| FAIL-message drift breaks log consumers / claim honesty | Preserve FAIL strings verbatim |
| Keystone's structural logic accidentally folded into the table | Explicitly kept bespoke (§3) |

## 7. Build plan (hand-off to `plan` skill)

1. Author the differential harness in `scratchpad/`; capture OLD baseline (matrix verdicts).
2. Refactor production checks → table + `check_spine_skill`; main block iterates.
3. Refactor selftest → `build_conformant_tree` + generic negative driver; keep bespoke
   cases 1–4 + keystone structural.
4. Run new selftest (all cases green) **and** the differential harness (old≡new) — both
   must pass.
5. Fold into an AMBER `apply.py` (idempotent, clone-proven) including version finishing
   (VERSION/CHANGELOG/README → 3.77.0) per the release-finishing-in-apply.py standing fix.
6. Dual review (reviewer + security); meta-control panel #28; human ships.

## 8. Honest ceiling (explicit)

- Proven by the shipped selftest: the refactored checks have teeth (non-vacuous).
- Proven by the differential harness (build-time, not shipped): new ≡ old across the matrix.
- **Not** proven: that the *marker lists themselves* are the "right" distinctiveness bar —
  that is unchanged from today and out of scope (this is a refactor, not a re-spec).
