# SNP-1 — Cross-stack Test-Data Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the kit a stack-neutral **test-data-management** pattern (synthetic / anonymized / never-raw-prod) + a light conditional `test-data-ready` check — Slice 1 of the Safe Non-Prod arc, and the foundation preview environments will seed from.

**Architecture:** `test-data-ready.sh` mirrors `dr-ready.sh`'s **data-surface trigger** (`has_data_surface`) + the `observability-ready` N/A·OK·FAIL·`--selftest` shape with L1-clean placeholder detection. `docs/operations/test-data-management.md` is a stack-neutral guidance doc (sibling of `egress-control.md`). `test-data-readiness.md` mirrors `observability-readiness.md`.

**Tech Stack:** POSIX sh (dash-clean; `set -eu`), Markdown, GitHub Actions YAML (CI step folds into this slice's PR — apply on the branch before opening it).

**Release:** `VERSION` → 2.51.0; MINOR.

**Honesty invariant:** a green `test-data-ready` proves the test-data approach is **recorded**, never that the data is *actually* synthetic/masked or that no prod data leaked. Those are Manual rows. US-aware: PII / children's data → synthetic or masked (COPPA-grade).

**Doc-budget:** core-3 — `CLAUDE.md` 111/120, `DEVELOPMENT-PROCESS.md` 466/470, `DEVELOPMENT-STANDARDS.md` 311/320. Only core-doc edit: a STANDARDS testing principle (+1, → 312) or +0 append. RUNBOOK/operations docs are non-core. Run `doc-budget.sh` after.

**Governance:** branch `feature/safe-nonprod-snp1-test-data` (created; arc spec + this plan live here) → PR → **Bradley merges**. STANDARDS edit → security-owner lens. **CI step folds into this PR** (per the post-RAI-1 convention — apply on the branch before the PR, not a separate PR). Generic/anonymized ([[kit-anonymization]]).

---

## File Structure
- Create: `docs/operations/test-data-management.md` (Task 1).
- Modify: `templates/RUNBOOK-TEMPLATE.md` — `Test data:` record line (Task 2).
- Create: `conformance/test-data-ready.sh` (Task 3), `conformance/test-data-readiness.md` (Task 4).
- Modify: `conformance/verify.sh`, `conformance/README.md`, `conformance/audit-evidence-checklist.md`, `DEVELOPMENT-STANDARDS.md` (Task 5).
- Modify (control-plane `cp`, Bradley applies on the branch): `.github/workflows/ci.yml` (Task 6).
- Modify: `VERSION`, `CHANGELOG.md`, `README.md` (Task 7).

---

## Task 1: Test-data-management guidance doc

**Files:** Create `docs/operations/test-data-management.md`

- [ ] **Step 1: Write the doc**

```markdown
# Test-Data Management

How to give non-prod environments **realistic data without the privacy risk of real data**. Stack-neutral; the per-stack tool is a profile choice. Pairs with the env strategy (`DEVELOPMENT-PROCESS.md` §9) and the privacy rules (`DEVELOPMENT-STANDARDS.md` §2). It is the data preview environments seed from (`preview-environments.md`).

## The rule: classify, then handle
| Data class | Non-prod handling |
|---|---|
| Public / non-sensitive | real data is fine |
| Internal / confidential | synthetic, or a masked subset |
| **PII / children's data** | **synthetic, or masked — never raw prod** (COPPA-grade; ties to the AI System Card data-minimization line) |

**Never copy raw production data into dev/QA/UAT.** If you must derive from prod, **mask on extract** (irreversibly transform PII before it leaves prod), never after.

## Three patterns
- **Synthetic generation** — generate fake-but-realistic data with a per-stack faker/factory tool (→ profile). Best default: no prod data ever touches non-prod.
- **Anonymization / masking** — for volume/shape realism, take a prod subset and irreversibly mask PII (names, emails, identifiers, children's data) at extraction time.
- **Deterministic seeds** — seed fixtures from a fixed seed so tests are reproducible and previews are consistent.

## Anti-patterns
- Raw prod dump in a shared dev DB · masking *after* the copy lands in non-prod · a "temporary" prod snapshot that becomes permanent · children's data in a preview environment.

## What the readiness check proves — and doesn't
`conformance/test-data-ready.sh` confirms a data-handling project **records** its test-data approach (RUNBOOK). It does **not** verify the data is *actually* synthetic/masked or that no prod data leaked — that is a **Manual** row (`test-data-readiness.md`). Necessary, not sufficient.
```

- [ ] **Step 2: Links + commit.** `sh conformance/check-links.sh` → OK.
```bash
git add docs/operations/test-data-management.md
git commit -m "docs(operations): test-data-management — synthetic/masked/never-raw-prod patterns (SNP-1)"
```

---

## Task 2: RUNBOOK test-data record line

**Files:** Modify `templates/RUNBOOK-TEMPLATE.md` (§2 Test / build)

- [ ] **Step 1:** In §2 Test/build, add a terse, comment-free record line (L1-clean — no HTML comment to hold the token):
```
- **Test data** *(data-handling projects — see `docs/operations/test-data-management.md`)*: [approach]
```
(e.g. "synthetic via faker · seeded fixtures · masked subset — never raw prod".)

- [ ] **Step 2:** `sh conformance/check-links.sh && sh conformance/doc-budget.sh` → OK. Commit:
```bash
git add templates/RUNBOOK-TEMPLATE.md
git commit -m "feat(templates): RUNBOOK records the test-data approach (SNP-1)"
```

---

## Task 3: `test-data-ready.sh`

**Files:** Create `conformance/test-data-ready.sh`

- [ ] **Step 1: Write the script**

```sh
#!/bin/sh
# test-data-ready.sh — conditional, fail-closed test-data-record check (Safe Non-Prod, SNP-1).
#
# Companion to conformance/test-data-readiness.md. For a project with a DATA SURFACE it asserts the
# test-data approach is RECORDED: the RUNBOOK has a "Test data:" line (not the [approach] placeholder).
# Projects with no data surface are N/A (skip-pass) — a pure-compute CLI/library has no test data to manage.
#
# SCOPE — a green run proves the approach is RECORDED, NOT that the data is actually synthetic/masked
# or that no prod data leaked into non-prod. Those are Manual rows in test-data-readiness.md. Necessary,
# not sufficient.
#
# Usage:
#   sh conformance/test-data-ready.sh [project-dir]   (default: .)
#   sh conformance/test-data-ready.sh --selftest
set -eu

# Does $1 have a persistent-data surface? (same signals as dr-ready.sh)
has_data_surface() {
  _d="$1"
  if [ -f "$_d/.env.example" ] && grep -Eiq 'DATABASE_URL|DB_URL|POSTGRES|MYSQL|MARIADB|MONGO|REDIS_URL|CONNECTION_STRING' "$_d/.env.example"; then
    return 0
  fi
  for _md in prisma migrations db/migrate alembic; do
    if [ -d "$_d/$_md" ]; then return 0; fi
  done
  for _cf in "$_d/compose.yaml" "$_d/compose.yml" "$_d/docker-compose.yml" "$_d/docker-compose.yaml"; do
    [ -f "$_cf" ] || continue
    if grep -Eiq 'image:[[:space:]]*"?(postgres|mysql|mariadb|mongo|redis)' "$_cf"; then return 0; fi
  done
  return 1
}

check_dir() {
  dir="$1"
  fail=0
  if ! has_data_surface "$dir"; then
    echo "N/A: $dir has no persistent-data surface (no DB url in .env.example / migrations dir / compose db) — no test data to manage"
    return 0
  fi
  rb="$dir/RUNBOOK.md"
  if [ ! -f "$rb" ]; then
    echo "FAIL: $dir handles data but has no RUNBOOK.md (need a Test-data record) — see conformance/test-data-readiness.md"
    return 1
  fi
  # Record string must stay in sync with templates/RUNBOOK-TEMPLATE.md §2.
  if ! grep -Eiq 'test data:' "$rb"; then
    echo "FAIL: RUNBOOK has no 'Test data:' record — declare the non-prod data approach (synthetic / masked / never raw prod)"
    fail=1
  elif grep -Eiq 'test data:.*\[approach\]' "$rb"; then
    echo "FAIL: 'Test data:' still holds the [approach] placeholder — record a real approach"
    fail=1
  fi
  if [ "$fail" -ne 0 ]; then return 1; fi
  echo "test-data-ready: OK — test-data approach is RECORDED. NOTE: does NOT verify the data is actually synthetic/masked or that no prod data leaked — those are Manual rows (test-data-readiness.md)."
  return 0
}

# mktemp fixtures; outcomes asserted. Fixtures LEFT in place (no rm -rf; 7e guard).
selftest() {
  st=0
  base=$(mktemp -d)

  d="$base/no-data"; mkdir -p "$d"; printf '# a stateless CLI\n' > "$d/README.md"
  if check_dir "$d" >/dev/null 2>&1; then echo "selftest PASS: no-data -> N/A"; else echo "selftest FAIL: no-data should be N/A"; st=1; fi

  d="$base/data-ok"; mkdir -p "$d"
  printf 'DATABASE_URL=postgres://localhost/app\n' > "$d/.env.example"
  printf '# RUNBOOK\n\n## 2. Test / build\n- Test data: synthetic via faker; seeded fixtures; never raw prod\n' > "$d/RUNBOOK.md"
  if check_dir "$d" >/dev/null 2>&1; then echo "selftest PASS: data + recorded -> OK"; else echo "selftest FAIL: recorded should pass"; st=1; fi

  d="$base/data-placeholder"; mkdir -p "$d"
  printf 'DATABASE_URL=postgres://localhost/app\n' > "$d/.env.example"
  printf '# RUNBOOK\n- Test data: [approach]\n' > "$d/RUNBOOK.md"
  if check_dir "$d" >/dev/null 2>&1; then echo "selftest FAIL: [approach] placeholder should FAIL"; st=1; else echo "selftest PASS: [approach] placeholder -> FAIL"; fi

  d="$base/data-missing"; mkdir -p "$d"
  printf 'DATABASE_URL=postgres://localhost/app\n' > "$d/.env.example"
  printf '# RUNBOOK\n\n## 2. Test / build\n- build: make\n' > "$d/RUNBOOK.md"
  if check_dir "$d" >/dev/null 2>&1; then echo "selftest FAIL: missing test-data record should FAIL"; st=1; else echo "selftest PASS: missing record -> FAIL"; fi

  if [ "$st" -ne 0 ]; then echo "test-data-ready --selftest: FAIL" >&2; return 1; fi
  echo "test-data-ready --selftest: OK (no-data/recorded/placeholder/missing all behaved; fixtures left in $base)"
  return 0
}

case "${1:-}" in
  --selftest) selftest; exit $? ;;
  *)          check_dir "${1:-.}"; exit $? ;;
esac
```

- [ ] **Step 2: chmod + syntax + selftest + kit-root N/A + coupling**
```bash
chmod +x conformance/test-data-ready.sh
dash -n conformance/test-data-ready.sh && echo "dash OK"
sh conformance/test-data-ready.sh --selftest
sh conformance/test-data-ready.sh; echo "kit-root exit=$?"   # N/A (kit has no .env.example DB / migrations), exit 0
```
Expected: dash OK; 4/4 selftest; kit-root N/A exit 0.
> **Kit-root note:** confirm the kit itself has no data surface (no `migrations/`/`prisma`/`alembic` dir, no DB url in a root `.env.example`, no DB service in a root compose). If it does, the check would bind at root — verify N/A; if it FAILs, that is a real signal the kit gained a data surface and needs the record (unlikely for a framework).

- [ ] **Step 3: Commit**
```bash
git add conformance/test-data-ready.sh
git commit -m "feat(conformance): test-data-ready.sh — conditional test-data-record check (data-surface trigger) (SNP-1)"
```

---

## Task 4: `test-data-readiness.md` checklist

**Files:** Create `conformance/test-data-readiness.md` (mirror `observability-readiness.md`)

- [ ] **Step 1: Write it**

```markdown
# Conformance Check — Test-Data Readiness

Proves a **data-handling project** declares how it gets **safe non-prod data**: synthetic, masked, or seeded — never raw prod. **Checklist-type**, run at Review and as recurring maintenance. **Conditional:** a project with no data surface marks the whole check **N/A — no test data to manage**. Verifies the patterns in `docs/operations/test-data-management.md` and the privacy rules in `DEVELOPMENT-STANDARDS.md` §2.

> **What the Auto row proves — and doesn't.** `test-data-ready.sh` confirms the approach is *recorded* (a RUNBOOK "Test data:" line). It does **not** verify the data is *actually* synthetic/masked or that no prod data leaked into non-prod. Those are the **Manual** rows. **A green script is necessary, not sufficient.**

## Checklist (blank)
| # | Item | Applies? | Evidence | Check |
|---|------|----------|----------|-------|
| 1 | Test-data approach recorded (RUNBOOK §2) *(documented)* | | | **Auto:** `test-data-ready.sh` |
| 2 | Non-prod data is actually synthetic / masked — no raw prod *(verified)* | | | Manual |
| 3 | PII / children's data masked or synthetic (COPPA-grade) where applicable *(verified)* | | | Manual |
| 4 | Masking happens on-extract (never raw prod copied down then masked) *(verified)* | | | Manual |

> A pure-compute project (CLI, library, no datastore) marks the whole check **N/A — no test data to manage**; `test-data-ready.sh` skip-passes it automatically.
```

- [ ] **Step 2:** Links + commit.
```bash
git add conformance/test-data-readiness.md
git commit -m "docs(conformance): test-data-readiness checklist (Auto: approach recorded; Manual: actually safe) (SNP-1)"
```

---

## Task 5: Wiring (verify.sh · README · audit · STANDARDS)

- [ ] **Step 1: verify.sh** — after the `responsible-ai-ready` row, add:
```
check doc     test-data-ready  sh conformance/test-data-ready.sh
```
- [ ] **Step 2: conformance/README.md** — add a row (mirror the dr-ready style) + name `test-data-ready.sh` in the documentation/evidence bullet:
```
| `test-data-ready.sh` | script | Safe Non-Prod — the test-data approach is recorded (RUNBOOK §2: synthetic/masked/never-raw-prod); conditional on a data surface. Pairs with `test-data-readiness.md` / `../docs/operations/test-data-management.md` | Review / CI (conditional on a data surface) |
```
- [ ] **Step 3: audit-evidence-checklist.md** — add a row:
```
| Test data · non-prod safety (if data surface) | CC6.1, C1.1 / A.8.10, A.8.11 (data masking) | RUNBOOK §2 test-data record + masking/synthetic evidence | **Auto (conditional):** `sh conformance/test-data-ready.sh` (+ Manual no-prod-data) | |
```
(Match the column layout; A.8.10 information deletion / A.8.11 data masking are the natural ISO 27001 anchors.)
- [ ] **Step 4: DEVELOPMENT-STANDARDS.md** — in the testing section, add a principle (append to an existing line if possible, else +1):
```
- **Test data** — non-prod uses synthetic or anonymized data; **never raw production data** (PII / children's → masked or synthetic, COPPA-grade). Patterns: `docs/operations/test-data-management.md`; recorded in RUNBOOK §2.
```
- [ ] **Step 5: Verify** — `sh conformance/verify.sh` (doc-checks now 7) · `doc-budget` · `check-links` → green. Commit:
```bash
git add conformance/verify.sh conformance/README.md conformance/audit-evidence-checklist.md DEVELOPMENT-STANDARDS.md
git commit -m "docs(conformance): wire test-data readiness — verify.sh + README/audit rows + STANDARDS principle (SNP-1)"
```

---

## Task 6: CI selftest step — fold into this PR (control-plane `cp`, Bradley applies on the branch)

Per the convention set after the RAI-1 straggler: the CI step is applied to **this slice's branch before the PR**, not a separate PR.

- [ ] **Step 1:** Prepare the step — after the Responsible-AI-ready selftest step in `.github/workflows/ci.yml`:
```yaml
      - name: Test-data-ready self-test (non-prod data discipline)
        run: sh conformance/test-data-ready.sh --selftest
```
- [ ] **Step 2:** Hand Bradley the diff to apply on `feature/safe-nonprod-snp1-test-data` and commit (`ci(snp-1): run test-data-ready.sh --selftest`) **before** the PR opens, so it rides in the one slice PR. The agent cannot edit `.github/workflows/`.

---

## Task 7: Release v2.51.0 + verification + PR

- [ ] **Step 1:** `VERSION` → `2.51.0`.
- [ ] **Step 2:** CHANGELOG `## [2.51.0] - <date>` (match prior shape): test-data-management doc + `test-data-ready` conditional check + RUNBOOK record + STANDARDS principle; US-aware (PII/children's → masked); conditional (N/A for non-data); Slice SNP-1 of the Safe Non-Prod arc.
- [ ] **Step 3:** README badge → `v2.51.0`; `badge-version.sh` → OK.
- [ ] **Step 4: Full verification**
```bash
dash -n conformance/test-data-ready.sh && echo "dash OK"
sh conformance/test-data-ready.sh --selftest
sh conformance/test-data-ready.sh; echo "kit-root exit=$?"   # N/A exit 0
sh conformance/check-links.sh && sh conformance/doc-budget.sh && sh conformance/badge-version.sh && echo "aux OK"
sh conformance/verify.sh 2>&1 | tail -4   # 7 doc-checks
```
- [ ] **Step 5:** Commit release: `chore(release): 2.51.0 — SNP-1 test-data management (Safe Non-Prod arc)`.
- [ ] **Step 6: Independent security-owner review** over the branch diff: honesty (recorded ≠ actually-safe); trigger correctness (no-data → N/A, data+placeholder → FAIL, data+missing → FAIL, fresh RUNBOOK → FAIL); POSIX/dash + set-e; US-aware privacy framing; doc-budget; the CI step (if applied) is labeled. Fold Critical/High/Medium.
- [ ] **Step 7:** Push + open PR (Bradley merges). Title `SNP-1 — cross-stack test-data management (v2.51.0)`. Report PR # + merge command. Do not self-merge.

---

## Verification (whole slice)
- `test-data-ready.sh`: `dash -n` clean; `--selftest` 4/4; kit-root N/A (exit 0); fresh RUNBOOK template → FAIL.
- `verify.sh` RESULT: OK at **7 doc-checks**; `check-links`/`doc-budget`/`badge-version` green; bootstrap unaffected.
- Conditional: non-data projects → N/A (zero overhead). US-aware: PII/children's → masked/synthetic.

## Out of scope (this slice)
- Preview environments (SNP-2) — seeds from this.
- Generating the actual dataset / the per-stack faker wiring beyond a profile note — team's job.
