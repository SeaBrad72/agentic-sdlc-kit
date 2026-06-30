# Golden-path trigger-filter parity — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the golden-path `paths:` trigger filter to the set of scripts its jobs invoke (so an exercised script can never silently skip the end-to-end proof), widen the filter to clear the current 7-file drift, and register it as the `golden-path-trigger` claim.

**Architecture:** A new POSIX-sh conformance check (`golden-path-filter-parity.sh`, modeled on `ci-selftest-coverage.sh`) extracts the filter set and the invoked-script set from the workflow and asserts invoked ⊆ filter (glob-aware, kit-self N/A, non-vacuous selftest). Control-plane files (workflow, ci.yml, claims.tsv, claims-registry.sh, the new check) are delivered through a single clone-proven AMBER `apply.py` with version-finishing folded in; the human runs it.

**Tech Stack:** POSIX sh (dash-clean), GitHub Actions YAML, the kit's conformance/claims registry, Python 3 for `apply.py`.

## Global Constraints

- **POSIX sh, dash-clean** — the check must pass `conformance/shellcheck.sh` (in CI).
- **Three-state exit convention** — `0` pass / N-A · `1` fail · `2` usage.
- **Non-vacuity is law** — every selftest must have a fixture that FAILS pre-fix and PASSES post-fix; mutation-prove each assertion is load-bearing.
- **Control-plane edits via `apply.py` only** — the runtime guard denies direct shell/Write mutation of `conformance/`, `.github/workflows/`. Author + test in `scratchpad/`, embed into `apply.py`, the human applies.
- **`apply.py` discipline** — idempotent (safe to re-run), all-or-abort (validate every anchor before any write), per-file in-memory buffer when a file gets ≥2 edits (MAINTAINING §3a), version-finishing folded in (VERSION 3.79.0→3.80.0 + README badge + CHANGELOG; [[release-finishing-in-apply-py]]).
- **Governance close is separate + human-run** (marker + meta-control-log row) — the agent does not self-certify its GO (M2-S5).
- **Version:** 3.79.0 → **3.80.0** (MINOR).

---

## File Structure

| File | Responsibility | Delivery |
|------|----------------|----------|
| `conformance/golden-path-filter-parity.sh` | NEW — the parity check + selftest | apply.py (base64 payload) |
| `.github/workflows/golden-path.yml` | widen both `paths:` lists (+7 files) | apply.py (buffered 2-edit) |
| `.github/workflows/ci.yml` | +2 steps (real-run + selftest) | apply.py |
| `conformance/claims.tsv` | +1 claim row `golden-path-trigger` | apply.py |
| `conformance/claims-registry.sh` | +`golden-path-trigger` in REQUIRED_IDS | apply.py |
| `docs/ROADMAP-KIT.md` | mark T4 items 1 + 5 done | apply.py (buffered) |
| `CHANGELOG.md` / `VERSION` / `README.md` | 3.80.0 + badge | apply.py |

Build/test happens in `scratchpad/gp-filter-parity/`.

---

## Task 1: Author + TDD the parity check (in scratchpad)

**Files:**
- Create: `scratchpad/gp-filter-parity/golden-path-filter-parity.sh` (the eventual `conformance/` check)

**Interfaces:**
- Produces: an executable check with `check_parity <wf>`, `filter_set`, `invoked_set`, `covered`, and `--selftest`. Exit `0`/`1`/`2`.

- [ ] **Step 1: Write the check with its embedded selftest**

```sh
#!/bin/sh
# golden-path-filter-parity.sh — assert the golden-path workflow's `paths:` TRIGGER FILTER covers
# every script its jobs INVOKE, so a change to an exercised script can never silently skip the
# end-to-end proof. Closes the parity-drift class where a job gains an `sh scripts/foo.sh` (or
# `sh conformance/foo.sh`) invocation but the hand-kept `paths:` list is not updated.
#
# Parity is ONE-DIRECTIONAL: invoked ⊆ filter. An over-broad filter (an entry never invoked) is
# conservative — it only makes golden-path run more often, never the silent-skip bug — so dead
# filter entries are NOT flagged (that would be YAGNI). Membership is glob-aware: a filter entry
# ending in `/**` covers files under its prefix, so the check survives a rewrite of the literal
# list into directory globs.
#   sh conformance/golden-path-filter-parity.sh [--selftest]
# Exit: 0 = parity holds (or N/A outside the kit) · 1 = an invoked script missing from the filter
#       · 2 = usage. POSIX sh; dash-clean.
set -eu
cd "$(dirname "$0")/.." 2>/dev/null || true

WF="${GOLDEN_PATH_WF:-.github/workflows/golden-path.yml}"

# filter_set <file>: one filter path per line (single-quoted tokens from the `paths:` lines).
filter_set() { grep 'paths:' "$1" | grep -oE "'[^']*'" | tr -d "'"; }

# invoked_set <file>: one invoked scripts/|conformance/ .sh path per line. Comments stripped (so a
# commented or doc-mentioned path is not a false requirement); `paths:` lines excluded (the filter
# is not an invocation).
invoked_set() {
  sed 's/#.*//' "$1" | grep -v 'paths:' \
    | grep -oE '(scripts|conformance)/[A-Za-z0-9._/-]+\.sh' | sort -u
}

# covered <token> <filter-line...>: 0 if token is literally in the filter OR covered by a `/**`
# glob whose prefix is a path-prefix of the token.
covered() {
  _t=$1; shift
  for _e in "$@"; do
    [ "$_e" = "$_t" ] && return 0
    case "$_e" in
      */\*\*) _pfx=${_e%/\*\*}; case "$_t" in "$_pfx"/*) return 0 ;; esac ;;
    esac
  done
  return 1
}

check_parity() {  # <workflow_file>
  _f=$1; _miss=0
  [ -f "$_f" ] || { echo "FAIL: golden-path workflow not found: $_f"; return 1; }
  # shellcheck disable=SC2046  # filter paths are space-free; word-splitting into params is intended
  set -- $(filter_set "$_f")
  for _inv in $(invoked_set "$_f"); do
    covered "$_inv" "$@" || { echo "FAIL: '$_inv' is invoked by golden-path but absent from the paths: trigger filter"; _miss=1; }
  done
  return $_miss
}

selftest() {
  sfail=0; d=$(mktemp -d)
  # dirty: a.sh in filter + invoked; b.sh invoked but NOT in filter -> FAIL naming b.sh
  printf "on:\n  pull_request:\n    paths: ['scripts/a.sh']\njobs:\n  x:\n    steps:\n      - run: sh scripts/a.sh\n      - run: sh scripts/b.sh\n" > "$d/dirty.yml"
  out=$(check_parity "$d/dirty.yml" 2>&1) && { echo "FAIL: selftest — missing file not detected"; sfail=1; } || true
  printf '%s\n' "$out" | grep -q "scripts/b.sh" || { echo "FAIL: selftest — missing file not named"; sfail=1; }
  [ "$sfail" -ne 0 ] || echo "PASS: selftest — missing invoked file detected + named"
  # clean: both in filter -> PASS
  printf "on:\n  pull_request:\n    paths: ['scripts/a.sh', 'scripts/b.sh']\njobs:\n  x:\n    steps:\n      - run: sh scripts/a.sh\n      - run: sh scripts/b.sh\n" > "$d/clean.yml"
  check_parity "$d/clean.yml" >/dev/null 2>&1 && echo "PASS: selftest — complete filter passes" || { echo "FAIL: selftest — complete filter wrongly failed"; sfail=1; }
  # glob: filter scripts/** covers scripts/c.sh -> PASS
  printf "on:\n  pull_request:\n    paths: ['scripts/**']\njobs:\n  x:\n    steps:\n      - run: sh scripts/c.sh\n" > "$d/glob.yml"
  check_parity "$d/glob.yml" >/dev/null 2>&1 && echo "PASS: selftest — glob filter covers" || { echo "FAIL: selftest — glob filter wrongly failed"; sfail=1; }
  # comment: a commented invocation of d.sh (not in filter) must NOT be required
  printf "on:\n  pull_request:\n    paths: ['scripts/a.sh']\njobs:\n  x:\n    steps:\n      - run: sh scripts/a.sh  # sh scripts/d.sh\n" > "$d/comment.yml"
  check_parity "$d/comment.yml" >/dev/null 2>&1 && echo "PASS: selftest — commented invocation ignored" || { echo "FAIL: selftest — comment-stripping not load-bearing"; sfail=1; }
  [ "$sfail" -eq 0 ] && { echo "OK: golden-path-filter-parity selftest"; exit 0; } || { echo "FAIL: golden-path-filter-parity selftest"; exit 1; }
}

case "${1:-}" in
  --selftest) selftest ;;
  "")
    # kit-self: golden-path.yml is kit-only (control-plane + export-ignored). N/A in an adopter tree.
    [ -f "$WF" ] || { echo "golden-path-filter-parity: N/A — kit-self check (golden-path workflow absent)"; exit 0; }
    if check_parity "$WF"; then echo "OK: golden-path paths: filter covers every invoked script"; exit 0
    else echo "FAIL: golden-path paths: filter is missing invoked script(s) above — add them so a change re-triggers golden-path"; exit 1; fi ;;
  *) echo "usage: golden-path-filter-parity.sh [--selftest]" >&2; exit 2 ;;
esac
```

- [ ] **Step 2: Run the selftest — expect all four cases PASS**

Run: `sh scratchpad/gp-filter-parity/golden-path-filter-parity.sh --selftest`
Expected: four `PASS:` lines + `OK: golden-path-filter-parity selftest`, exit 0.

- [ ] **Step 3: Mutation-prove non-vacuity (each assertion is load-bearing)**

Temporarily break `covered()` to always `return 0` and re-run `--selftest`: the **dirty** case must now FAIL (it stopped detecting the missing file), proving the dirty assertion bites. Revert. (Do the same thought-check for comment-stripping by removing `grep -v 'paths:'` — clean/dirty should mis-count.)

Run: `sh scratchpad/gp-filter-parity/golden-path-filter-parity.sh --selftest` (after revert)
Expected: back to all PASS.

- [ ] **Step 4: Shellcheck the check**

Run: `shellcheck scratchpad/gp-filter-parity/golden-path-filter-parity.sh`
Expected: clean (no warnings; the one `SC2046` is disabled inline with justification).

- [ ] **Step 5: Commit (build-phase, feature branch)**

```bash
git add scratchpad/gp-filter-parity/golden-path-filter-parity.sh
git commit -m "build(gp-parity): author golden-path-filter-parity check + selftest"
```
*(Note: `scratchpad/` is gitignored in this repo — if so, skip the commit; the check is delivered via apply.py. Verify with `git check-ignore scratchpad/` first.)*

---

## Task 2: Prove the check catches the REAL drift, and the widen clears it

**Files:**
- Read: `.github/workflows/golden-path.yml` (the real artifact)

**Interfaces:**
- Consumes: the check from Task 1, the `GOLDEN_PATH_WF` env override.

- [ ] **Step 1: Run the check against the REAL workflow — expect RED listing the 7 drifted files**

Run: `GOLDEN_PATH_WF=.github/workflows/golden-path.yml sh scratchpad/gp-filter-parity/golden-path-filter-parity.sh`
Expected: FAIL lines naming `scripts/smoke.sh`, `scripts/otlp-export.sh`, `scripts/escalate.sh`, `conformance/escalation-wired.sh`, `conformance/actionlint-valid.sh`, `conformance/provenance-precondition.sh`, `conformance/ci-gates.sh`; exit 1.

This is the real-world RED — it proves the teeth bite on the actual drift, before any fix.

- [ ] **Step 2: Make a widened copy and confirm GREEN**

Copy the real workflow to scratchpad, add the 7 files to both `paths:` lists, re-run the check against the copy.

Expected: `OK: golden-path paths: filter covers every invoked script`, exit 0.

The exact filter strings for the apply.py (both `pull_request.paths` and `push.paths` carry the identical list):

**OLD** (the single-quoted list, both lines):
```
['profiles/typescript-node/**', 'scripts/incept.sh', '.github/workflows/golden-path.yml', 'scripts/new-profile.sh', 'scripts/adopter-export.sh', 'scripts/containment-audit.sh', 'profiles/_TEMPLATE.md', 'scripts/otel-trace.sh', 'scripts/orchestrator-run.sh', 'scripts/fixtures/engineer-fixture.sh', 'conformance/orchestrator-loop-wired.sh', 'scripts/otel-to-scorecard.sh', 'scripts/agent-scorecard.sh']
```

**NEW** (append the 7 before the closing `]`):
```
[…existing…, 'scripts/smoke.sh', 'scripts/otlp-export.sh', 'scripts/escalate.sh', 'conformance/escalation-wired.sh', 'conformance/actionlint-valid.sh', 'conformance/provenance-precondition.sh', 'conformance/ci-gates.sh']
```

---

## Task 3: Author the AMBER `apply.py`

**Files:**
- Create: `scratchpad/gp-filter-parity/apply.py`

**Interfaces:**
- Consumes: the check source (Task 1, base64-embedded), the exact filter OLD/NEW strings (Task 2).
- Produces: an idempotent, all-or-abort applier the human runs from repo root.

- [ ] **Step 1: Write `apply.py`** with these responsibilities (validate ALL anchors first; only then write; each edit is a no-op if already applied):

1. **Write** `conformance/golden-path-filter-parity.sh` from the base64 payload (mode 0644). Idempotent: overwrite to the canonical bytes.
2. **`.github/workflows/golden-path.yml`** — read once into a buffer; replace the OLD filter list with NEW on **both** the `pull_request` and `push` `paths:` lines (per-file buffer, single write). Idempotent: if NEW already present, skip.
3. **`.github/workflows/ci.yml`** — insert two steps immediately after the `Golden-path-wired self-test` step (anchor: the line `        run: sh conformance/golden-path-wired.sh --selftest`):
```yaml
      - name: Golden-path filter parity (filter covers every invoked script)
        run: sh conformance/golden-path-filter-parity.sh
      - name: Golden-path-filter-parity self-test
        run: sh conformance/golden-path-filter-parity.sh --selftest
```
   Idempotent: skip if `golden-path-filter-parity.sh` already in ci.yml.
4. **`conformance/claims.tsv`** — append the row (tab-separated), idempotent (skip if id present):
```
golden-path-trigger	the golden-path trigger paths: filter covers every script the workflow invokes — no silent skip (.github/workflows/golden-path.yml)	sh conformance/golden-path-filter-parity.sh
```
5. **`conformance/claims-registry.sh`** — add `golden-path-trigger` to `REQUIRED_IDS` (insert after the token `golden-path`). Idempotent: skip if present.
6. **`docs/ROADMAP-KIT.md`** — buffer the file; (a) mark item (1) DONE; (b) mark item (5) DONE. Replace the two bullet lines (lines ~40–41) with `*(✅ DONE, v3.80.0)*` variants. Single write.
7. **`CHANGELOG.md`** — prepend a `## [3.80.0] — 2026-06-30` entry above the current top entry.
8. **`VERSION`** — `3.79.0` → `3.80.0`.
9. **`README.md`** — version badge `3.79.0` → `3.80.0`.

End with a printed summary of changed paths + a re-run-safe note.

- [ ] **Step 2: Commit the applier (if scratchpad is tracked; else it rides in the clone proof)**

```bash
git check-ignore scratchpad/ || git add scratchpad/gp-filter-parity/apply.py && git commit -m "build(gp-parity): apply.py (check install + widen + claim + version finishing)"
```

---

## Task 4: Clone-prove the apply.py

**Files:** none modified in the working tree — proof runs in a throwaway clone.

- [ ] **Step 1: Clone, apply, verify**

```bash
T=$(mktemp -d); git clone -q . "$T/clone"
cp scratchpad/gp-filter-parity/apply.py "$T/clone/apply.py"
cp scratchpad/gp-filter-parity/golden-path-filter-parity.sh "$T/clone/_payload.sh"  # if apply.py reads it; else skip
cd "$T/clone" && python3 apply.py
```
Expected: prints the changed-paths summary, exits 0.

- [ ] **Step 2: Run the proof battery in the clone**

Run (in `$T/clone`):
```bash
sh conformance/golden-path-filter-parity.sh --selftest
sh conformance/golden-path-filter-parity.sh
sh conformance/claims-registry.sh
sh conformance/ci-selftest-coverage.sh
sh conformance/golden-path-wired.sh
sh conformance/badge-version.sh
sh conformance/shellcheck.sh
```
Expected: every command exits 0 (parity green on the widened filter; new `--selftest` wired; claim verifies; badge==3.80.0; shell clean).

- [ ] **Step 3: Idempotency — apply twice**

Run: `python3 apply.py` (second time)
Expected: no-op (all edits already present), exit 0; `git -C . diff --stat` shows no new changes vs. the first apply.

- [ ] **Step 4: Negative control — removing a file from the filter goes RED**

In the clone, delete one widened entry (e.g. `'scripts/smoke.sh'`) from the `paths:` lists and re-run the real-path check.
Expected: FAIL naming `scripts/smoke.sh`, exit 1. Restore. (Proves the lock has teeth on the real artifact.)

- [ ] **Step 5: `verify --require` on the clone**

Run: `sh conformance/verify.sh --require`
Expected: exit 0 (no control failures; nothing unverified). Note the [[tagless-clone-ci-validation]] caveat — `version-tag-coherent` may report the tag-on-HEAD artifact on a working clone; that is the known clone artifact, not a real failure.

---

## Task 5: Dual review + hand-off (loop: review → release)

- [ ] **Step 1: Independent dual review** (builder ≠ reviewer — DEVELOPMENT-PROCESS §12)

Dispatch the `reviewer` agent (correctness, additive-only, parity logic, selftest non-vacuity) and the `security-reviewer` agent (no two-matcher guard gap for the new `conformance/` file; the check surfaces no secret values; the claim row is honest). Both must reach APPROVE/PASS; fold any in-slice findings.

- [ ] **Step 2: Per-slice meta-control panel** (Kit-Steward) — record GO/NO-GO in `docs/architecture/2026-06-30-meta-control-<n>.md`.

- [ ] **Step 3: Hand-off to Bradley** (apply/commit/PR/merge/tag are the human's — [[merge-tag-authority]]):

```bash
# from repo root on feat/golden-path-filter-parity
python3 scratchpad/gp-filter-parity/apply.py
# governance close (human, M2-S5): write marker `3.80.0 GO` + meta-control-log row
git add -A && git commit -m "feat(gp-parity): golden-path trigger-filter parity claim (v3.80.0)"
git show --stat HEAD   # CONFIRM every expected control-plane file is in the commit (keystone-coupling lesson)
git push -u origin feat/golden-path-filter-parity
gh pr create --fill
gh pr checks <#>       # conformance GREEN before merge; only control-plane-ratification may be red (by-design, solo)
gh pr merge <#> --squash --admin --delete-branch
git checkout main && git pull && sh scripts/release-tag.sh   # run AFTER main CI is green (tag-gate polls otherwise)
```

- [ ] **Step 4: Post-ship coherence** — fresh-clone `verify --require` green; `git tag --points-at HEAD` shows `v3.80.0`; update memory.

---

## Self-Review

**Spec coverage:**
- New check + selftest → Task 1. ✓
- Real-drift RED + widen → Task 2. ✓
- Claim registration (claims.tsv + REQUIRED_IDS) + ci.yml wiring → Task 3 (steps 3–5). ✓
- Item 5 roadmap correction → Task 3 (step 6b). ✓
- Version finishing → Task 3 (steps 7–9). ✓
- Clone-proof + idempotency + teeth + verify → Task 4. ✓
- Dual review + ship → Task 5. ✓

**Placeholder scan:** the check is complete source; apply.py responsibilities give exact anchors/strings; no TBDs. ✓

**Type/name consistency:** `check_parity` / `filter_set` / `invoked_set` / `covered` used consistently; claim id `golden-path-trigger` and file `golden-path-filter-parity.sh` consistent across all tasks and the design doc. ✓
