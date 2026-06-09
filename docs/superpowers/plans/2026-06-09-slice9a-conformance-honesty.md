# Slice 9a — Conformance Honesty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** Make the conformance layer honest about "green ≠ verified": give `branch-protection.sh` a three-state outcome (no silent pass), add an executable classified-aggregate runner `verify.sh`, and document the control-vs-documentation taxonomy.

**Architecture:** POSIX `sh`. `branch-protection.sh` gains exit-2 (unverified) + CI/`--require` escalation + `--selftest`. New `verify.sh` runs the kit-applicable checks, tags each `[control]`/`[doc]`, prints an honest footer, gates only on control failures. `conformance/README.md` gains a "Verifies" column + a "what green means" section. CI runs both `--selftest`s.

**Spec:** `docs/superpowers/specs/2026-06-09-slice9a-conformance-honesty-design.md`

---

## Task 1: Three-state `branch-protection.sh`

**Files:** Modify `conformance/branch-protection.sh`

- [ ] **Step 1: Rewrite the script** to the three-state contract. Replace the whole file with:

```sh
#!/bin/sh
# branch-protection.sh — verify `main` is actually protected on the remote
# (DEVELOPMENT-STANDARDS.md §14 / DEVELOPMENT-PROCESS.md §12). THREE-STATE contract:
#   exit 0  — verified protected (PR reviews + status checks required)
#   exit 1  — verified NOT protected / a required setting missing (FAIL)
#   exit 2  — COULD NOT VERIFY (no gh, unauthenticated, or no GitHub remote) — NOT a pass.
# A silent pass when unverifiable is false assurance; this returns a distinct status.
# Escalation: in CI (CI env set) or with --require, "could not verify" becomes exit 1 —
# in a gate the check MUST be runnable. Requires `gh` authenticated to verify.
#   usage: sh conformance/branch-protection.sh [BRANCH] [--require] | --selftest
set -eu

REQUIRE="${REQUIRE:-0}"
[ -n "${CI:-}" ] && REQUIRE=1
BRANCH=main
for a in "$@"; do
  case "$a" in
    --require) REQUIRE=1 ;;
    --selftest) ;; # handled below
    -*) echo "usage: branch-protection.sh [BRANCH] [--require] | --selftest" >&2; exit 2 ;;
    *) BRANCH="$a" ;;
  esac
done

# unverifiable: exit 2 normally, exit 1 (FAIL) under CI/--require.
unverifiable() {
  if [ "$REQUIRE" = "1" ]; then
    echo "FAIL: branch-protection could not verify ($1) and verification is required (CI/--require)."; exit 1
  fi
  echo "UNVERIFIED: $1 — run in CI or authenticate gh. (NOT a pass.)"; exit 2
}

run() {
  command -v gh >/dev/null 2>&1 || unverifiable "gh not installed"
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  [ -n "$REPO" ] || unverifiable "no GitHub repo context"
  PROT=$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>/dev/null || true)
  [ -n "$PROT" ] && { printf '%s' "$PROT" | grep -q '"message"' && [ -z "$(printf '%s' "$PROT" | grep -o required_pull_request_reviews)" ] && PROT=; } || true
  if [ -z "$PROT" ]; then
    echo "FAIL: $BRANCH on $REPO has no branch protection (or it is not readable)."; exit 1
  fi
  ok=0
  printf '%s' "$PROT" | grep -q '"required_pull_request_reviews"' || { echo "FAIL: required PR reviews not enabled on $BRANCH"; ok=1; }
  printf '%s' "$PROT" | grep -q '"required_status_checks"' || { echo "FAIL: required status checks not enabled on $BRANCH"; ok=1; }
  [ "$ok" -eq 0 ] && echo "OK: $BRANCH on $REPO is protected (PR reviews + status checks required)."
  exit "$ok"
}

selftest() {
  st=0
  # local, no gh -> exit 2 (UNVERIFIED)
  out=$(CI= REQUIRE=0 PATH=/nonexistent sh "$0" 2>&1); rc=$?
  if [ "$rc" = "2" ]; then echo "selftest PASS: no-gh local -> exit 2 (UNVERIFIED)"; else echo "selftest FAIL: no-gh local should be exit 2 (got $rc)"; st=1; fi
  printf '%s' "$out" | grep -q UNVERIFIED || { echo "selftest FAIL: missing UNVERIFIED message"; st=1; }
  # CI, no gh -> exit 1 (escalated FAIL)
  out=$(CI=true PATH=/nonexistent sh "$0" 2>&1); rc=$?
  if [ "$rc" = "1" ]; then echo "selftest PASS: no-gh + CI -> exit 1 (FAIL escalation)"; else echo "selftest FAIL: no-gh+CI should be exit 1 (got $rc)"; st=1; fi
  # --require, no gh -> exit 1
  out=$(CI= PATH=/nonexistent sh "$0" --require 2>&1); rc=$?
  if [ "$rc" = "1" ]; then echo "selftest PASS: no-gh + --require -> exit 1"; else echo "selftest FAIL: no-gh+--require should be exit 1 (got $rc)"; st=1; fi
  [ "$st" = "0" ] && echo "branch-protection --selftest: OK"
  return "$st"
}

case "${1:-}" in
  --selftest) selftest; exit $? ;;
  *) run ;;
esac
```

- [ ] **Step 2: dash syntax check.** Run: `dash -n conformance/branch-protection.sh` → no output (POSIX-clean).

- [ ] **Step 3: Run the selftest.** Run: `sh conformance/branch-protection.sh --selftest`
Expected: three `selftest PASS` lines + `branch-protection --selftest: OK`, exit 0.

- [ ] **Step 4: Sanity — local no-require run.** Run: `sh conformance/branch-protection.sh; echo "exit=$?"`
Expected: either `OK:` (if gh is authed here and main is protected) with exit 0, or `UNVERIFIED:` with exit 2 — NOT a bare pass with no verification. (In this authed repo it should print OK.)

- [ ] **Step 5: Commit.**

```bash
git add conformance/branch-protection.sh
git commit -m "feat(conformance): 9a — three-state branch-protection (no silent pass; CI/--require escalation; --selftest)"
```

---

## Task 2: `conformance/verify.sh` — classified aggregate runner

**Files:** Create `conformance/verify.sh`

- [ ] **Step 1: Create the runner.** Write `conformance/verify.sh`:

```sh
#!/bin/sh
# verify.sh — honest aggregate conformance runner. Classifies each check:
#   [control] — verifies a live/remote/structural WORKING control
#   [doc]     — verifies DOCUMENTATION / recorded evidence EXISTS (not that it was tested)
# Prints PASS/FAIL/UNVERIFIED/N-A per check and an honest summary footer. Exit policy:
#   non-zero if any [control] check FAILS, or (under --require / CI) any check is UNVERIFIED.
#   [doc] checks that are present-but-untested PASS — they are honestly labelled, not hidden.
# A green run proves controls hold AND release/DR/resilience safety is DOCUMENTED — NOT
# that those procedures were tested. See conformance/README.md "What a green run means".
#   usage: sh conformance/verify.sh [--require] | --selftest
set -eu
cd "$(dirname "$0")/.."   # repo root

REQUIRE=0
[ -n "${CI:-}" ] && REQUIRE=1
[ "${1:-}" = "--require" ] && REQUIRE=1

ctrl_fail=0; unverified=0; controls=0; docs=0; failed=0
line() { printf '  %-9s %-26s %s\n' "$1" "$2" "$3"; }

# run a check: kind name command...
check() {
  kind=$1; name=$2; shift 2
  if out=$("$@" 2>&1); then rc=0; else rc=$?; fi
  case "$kind" in control) controls=$((controls+1)) ;; doc) docs=$((docs+1)) ;; esac
  if [ "$rc" = "0" ]; then
    line "[$kind]" "$name" "PASS"
  elif [ "$rc" = "2" ]; then
    line "[$kind]" "$name" "UNVERIFIED"; unverified=$((unverified+1))
    [ "$REQUIRE" = "1" ] && failed=$((failed+1))
  else
    line "[$kind]" "$name" "FAIL"; failed=$((failed+1))
    [ "$kind" = "control" ] && ctrl_fail=1
  fi
}

echo "Conformance verification (honest aggregate)"
echo "-------------------------------------------"
check control agent-autonomy   sh conformance/agent-autonomy.sh
check control ci-gates         sh conformance/ci-gates.sh profiles/typescript-node/ci.yml
check control guard-wired      sh conformance/guard-wired.sh
check control check-links      sh conformance/check-links.sh
check control backlog-adapters sh conformance/backlog-adapters.sh
check control branch-protect   sh conformance/branch-protection.sh
check doc     deployable-ready sh conformance/deployable-ready.sh
check doc     dr-ready         sh conformance/dr-ready.sh
check doc     resilience-ready sh conformance/resilience-ready.sh

echo ""
printf 'Summary: %d control-checks · %d doc-checks · %d unverified · %d failed\n' "$controls" "$docs" "$unverified" "$failed"
echo "A green run proves controls hold AND release/DR/resilience safety is DOCUMENTED —"
echo "it does NOT prove those procedures were tested. doc-checks verify records exist."
echo "UNVERIFIED is NOT a pass. See conformance/README.md \"What a green run means\"."

if [ "$ctrl_fail" != "0" ]; then echo "RESULT: FAIL (a control check failed)"; exit 1; fi
if [ "$REQUIRE" = "1" ] && [ "$unverified" != "0" ]; then echo "RESULT: FAIL (unverified under --require/CI)"; exit 1; fi
echo "RESULT: OK (controls verified; docs present)"; exit 0
```

- [ ] **Step 2: Make executable + dash check.** Run: `chmod +x conformance/verify.sh && dash -n conformance/verify.sh` → no output.

- [ ] **Step 3: Add a minimal `--selftest`.** Append before the final `case`… actually add selftest handling. Insert near the top after the REQUIRE block a dispatch:

Replace the line `[ "${1:-}" = "--require" ] && REQUIRE=1` region by adding, right after `set -eu` block and `cd`, a selftest branch at the END of the file is simplest. Append at the very end of the file:

```sh
```
(No-op — selftest is handled by the wrapper below.)

Actually, implement selftest cleanly: insert this block immediately BEFORE the `echo "Conformance verification` line:

```sh
if [ "${1:-}" = "--selftest" ]; then
  # deterministic: assert the classifier + footer render and that a forced control-fail exits 1
  out=$(REQUIRE=0 sh "$0" 2>&1) || true
  printf '%s\n' "$out" | grep -q "control-checks" || { echo "verify --selftest: FAIL (no summary)"; exit 1; }
  printf '%s\n' "$out" | grep -q "UNVERIFIED is NOT a pass" || { echo "verify --selftest: FAIL (no honesty footer)"; exit 1; }
  echo "verify --selftest: OK"; exit 0
fi
```

- [ ] **Step 4: Run it.** Run: `sh conformance/verify.sh`
Expected: a classified list ([control]/[doc] each PASS/…); footer with the honesty statement; `RESULT: OK` (assuming controls pass and main is protected here). If branch-protect is UNVERIFIED locally, still RESULT: OK (not --require).

- [ ] **Step 5: Run the selftest.** Run: `sh conformance/verify.sh --selftest`
Expected: `verify --selftest: OK`, exit 0.

- [ ] **Step 6: Commit.**

```bash
git add conformance/verify.sh
git commit -m "feat(conformance): 9a — verify.sh classified aggregate (control vs doc; honest footer; --selftest)"
```

---

## Task 3: Document the taxonomy in `conformance/README.md`

**Files:** Modify `conformance/README.md`

- [ ] **Step 1: Add a "Verifies" column** to the index table. Read the table, and for each row add a `control` or `documentation/evidence` tag matching the verify.sh classification (agent-autonomy/ci-gates/guard-wired/check-links/backlog-adapters/branch-protection/container-supply-chain = control; deployable/dr/resilience-ready + the `.md` checklists = documentation/evidence). Add `verify.sh` as a new row (`script` · `the honest aggregate runner` · control-gating).

- [ ] **Step 2: Add a "What a green run means — and doesn't" section** near the top:

```markdown
## What a green run means — and doesn't

Conformance checks are two kinds (see the **Verifies** column, and run `sh conformance/verify.sh` for an honest aggregate):

- **control** — proves a *working* control holds: the agent guard denies the destructive battery, CI declares the required gate ids, `main` is protected on the remote, links resolve. Green here is load-bearing.
- **documentation / evidence** — proves a procedure is *written down* and (for readiness) a drill **date is recorded** — NOT that the rollback, restore, or fault-injection was actually tested. Those are Manual rows in the paired checklist, requiring release-manager / on-call evidence.

**`UNVERIFIED` is not a pass.** A check that cannot run (e.g. `branch-protection.sh` with no `gh`/remote) exits **2** and is reported `UNVERIFIED`, distinct from PASS — in CI or under `--require` it becomes a FAIL. A green dashboard with an unseen UNVERIFIED is the false assurance this layer exists to prevent.

In short: **green proves controls hold and safety is documented; it does not prove the documented procedures were tested.**
```

- [ ] **Step 3: Verify links.** Run: `sh conformance/check-links.sh` → OK.

- [ ] **Step 4: Commit.**

```bash
git add conformance/README.md
git commit -m "docs(conformance): 9a — Verifies taxonomy column + 'what a green run means' section"
```

---

## Task 4: Wire selftests into CI + release

**Files:** Modify `.github/workflows/ci.yml`, `VERSION`, `CHANGELOG.md`, `docs/ROADMAP-SLICE9.md`

> NOTE: `.github/workflows/ci.yml` is control-plane (guard-protected). If editing it via an agent is blocked, the human maintainer applies this hunk via the `KIT_GUARD_SELFEDIT` gate (same as 9b). The change is additive (two `run:` steps).

- [ ] **Step 1: Add CI steps.** In `.github/workflows/ci.yml`, in the conformance job after the resilience selftest step, add:

```yaml
      - name: branch-protection three-state selftest
        run: sh conformance/branch-protection.sh --selftest
      - name: conformance aggregate (verify) selftest
        run: sh conformance/verify.sh --selftest
```

- [ ] **Step 2: Bump VERSION** to `2.26.0`.

- [ ] **Step 3: CHANGELOG entry** under `## [2.26.0] - 2026-06-09` (Keep a Changelog): three-state branch-protection (no silent pass; CI/--require escalation), new `verify.sh` classified aggregate, README taxonomy. Note the behavior change: `branch-protection.sh` now exits 2 (UNVERIFIED) instead of 0 when it cannot verify.

- [ ] **Step 4: ROADMAP** — mark **9a** done in `docs/ROADMAP-SLICE9.md` (Stage II): "shipped v2.26.0 — three-state branch-protection + honest aggregate + taxonomy."

- [ ] **Step 5: Full sweep + commit.**

```bash
sh conformance/agent-autonomy.sh && sh conformance/check-links.sh && sh conformance/verify.sh --selftest && sh conformance/branch-protection.sh --selftest
git add .github/workflows/ci.yml VERSION CHANGELOG.md docs/ROADMAP-SLICE9.md
git commit -m "chore(release): 2.26.0 — conformance honesty (9a)"
```

---

## Final review (controller)
- Dispatch `reviewer` + `security-reviewer` (branch-protection is a governing-surface check) on the branch diff. Confirm: three-state logic is correct (exit 2 vs 1 vs 0), the CI escalation can't be bypassed, verify.sh exit policy gates control-fails and unverified-under-require, no POSIX issues, README taxonomy matches verify.sh classification.
- Then superpowers:finishing-a-development-branch → PR (no self-merge; Bradley ratifies).

## Self-review notes
- Spec coverage: branch-protection three-state (T1), verify.sh aggregate (T2), README taxonomy (T3), CI + release (T4). All mapped.
- The `ci.yml` edit is the only control-plane file — flagged for human-gated apply if the agent is blocked (mirrors 9b).
- No placeholders; all scripts complete.
