# Slice 8b — Definition of Deployable (release-readiness gate) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a conditional Release-readiness gate — a `deployable-ready.sh` script (auto-checks the documented release-safety artifacts, with a `--selftest` battery) paired with a `definition-of-deployable.md` checklist (judgment items), wired into §7 as a conditional gate for deployable services.

**Architecture:** Docs + one POSIX-sh conformance script. The script is conditional (skip-passes with no deploy surface) and fail-closed, mirroring `container-supply-chain.sh`. It self-discloses its scope (documents present ≠ tested) and carries a `--selftest` mode that builds `mktemp` fixtures (skip/OK/FAIL) so the positive path is regression-locked in kit CI. The checklist mirrors `15-factor-checklist.md` (blank table + worked example) and carries a "necessary, not sufficient" callout.

**Tech Stack:** POSIX `sh` (sh + dash compatible), Markdown, GitHub Actions YAML, `git`.

**Spec:** `docs/superpowers/specs/2026-06-09-slice8b-definition-of-deployable-design.md`

---

## File structure

| File | Responsibility | Change |
|------|----------------|--------|
| `conformance/deployable-ready.sh` | Auto-check documented release-safety + `--selftest` | **Create** |
| `conformance/definition-of-deployable.md` | Release-readiness checklist (Manual + Auto rows) | **Create** |
| `templates/RUNBOOK-TEMPLATE.md` | Give incepted projects a smoke-test slot (consistency) | Add a smoke bullet under §4 Deploy |
| `DEVELOPMENT-PROCESS.md` | §7 gate row + conditional sentence; §4 Release; §10 rollback line | Modify (4 edits) |
| `conformance/README.md` | Index the two new checks | Add 2 rows |
| `conformance/audit-evidence-checklist.md` | Release-readiness control row | Add 1 row |
| `.github/workflows/ci.yml` | Dogfood: present + N/A + selftest | Add 3 steps |
| `VERSION` / `CHANGELOG.md` / `docs/ROADMAP-KIT.md` | Release meta | Modify |

**Build order rationale:** the script (Task 1) and checklist (Task 2) are the deliverables; the RUNBOOK smoke fix (Task 3) keeps the kit's own scaffolding passing the new check; wiring (Tasks 4–6) references files that now exist; meta + sweep last (Tasks 7–8).

---

### Task 1: Create `conformance/deployable-ready.sh`

**Files:**
- Create: `conformance/deployable-ready.sh`

- [ ] **Step 1: Verify deploy-surface detection won't false-positive at the kit root (pre-check)**

Run:
```bash
grep -nE '^[[:space:]]*environment:' .github/workflows/ci.yml; echo "env-key exit=$?"
grep -nEi '^[[:space:]]+deploy[A-Za-z0-9_-]*:[[:space:]]*$|^[[:space:]]*(-[[:space:]]+)?(id|name):[[:space:]].*deploy' .github/workflows/ci.yml; echo "deploy-job exit=$?"
ls Dockerfile 2>&1
```
Expected: both greps exit 1 (no match), and no root `Dockerfile`. This confirms the kit root has no deploy surface → the script must hit the N/A path there. (If any matches, STOP and report — the detection patterns or the assumption is wrong.)

- [ ] **Step 2: Write the script**

Create `conformance/deployable-ready.sh` with EXACTLY this content:

```sh
#!/bin/sh
# deployable-ready.sh — conditional, fail-closed release-readiness DOC check.
#
# Companion to conformance/definition-of-deployable.md (the Release gate,
# DEVELOPMENT-PROCESS.md §7). For a project WITH a deploy surface — a Dockerfile,
# OR a workflow with an `environment:` key, OR a deploy job/step — it asserts the
# release-safety procedures are DOCUMENTED: RUNBOOK.md has a Deploy section and a
# Rollback section, and a smoke test is referenced. Projects with NO deploy surface
# are N/A (skip-pass) — release-readiness is not forced on libraries/CLIs/batch jobs.
#
# SCOPE — read this before trusting a green run: this verifies release-safety is
# WRITTEN DOWN, NOT that the rollback was tested or that alerts are wired. Those are
# Manual rows in definition-of-deployable.md, signed off by the release manager with
# evidence. A green run here is necessary, not sufficient.
#
# Usage:
#   sh conformance/deployable-ready.sh [project-dir]   (default: .)
#   sh conformance/deployable-ready.sh --selftest      (build fixtures, assert skip/OK/FAIL)
#
# Run at the Release gate (DEVELOPMENT-PROCESS.md §7); also self-tested in kit CI.
set -eu

# Does $1 (a workflow file) indicate a deploy surface?
wf_is_deploy() {
  wf="$1"
  if grep -Eq '^[[:space:]]*environment:' "$wf"; then return 0; fi
  if grep -Eq '^[[:space:]]+deploy[A-Za-z0-9_-]*:[[:space:]]*$' "$wf"; then return 0; fi
  if grep -Eiq '^[[:space:]]*(-[[:space:]]+)?(id|name):[[:space:]].*deploy' "$wf"; then return 0; fi
  return 1
}

# Core check over a single project directory. Returns 0 (OK or N/A) / 1 (FAIL).
check_dir() {
  dir="$1"
  fail=0

  deployable=0
  if [ -f "$dir/Dockerfile" ]; then deployable=1; fi
  if [ "$deployable" -eq 0 ] && [ -d "$dir/.github/workflows" ]; then
    for wf in "$dir"/.github/workflows/*.yml "$dir"/.github/workflows/*.yaml; do
      [ -f "$wf" ] || continue
      if wf_is_deploy "$wf"; then deployable=1; break; fi
    done
  fi

  if [ "$deployable" -eq 0 ]; then
    echo "N/A: $dir has no deploy surface (no Dockerfile / deploy workflow) — skipping (not a deployable service)"
    return 0
  fi

  rb="$dir/RUNBOOK.md"
  if [ ! -f "$rb" ]; then
    echo "FAIL: $dir is deployable but has no RUNBOOK.md (need Deploy + Rollback sections) — see conformance/definition-of-deployable.md"
    return 1
  fi

  if ! grep -Eiq '^#{1,6}[[:space:]].*deploy' "$rb"; then
    echo "FAIL: $rb has no Deploy section (a heading matching 'deploy')"
    fail=1
  fi
  if ! grep -Eiq '^#{1,6}[[:space:]].*rollback' "$rb"; then
    echo "FAIL: $rb has no Rollback section (a heading matching 'rollback')"
    fail=1
  fi

  smoke=0
  if grep -iq 'smoke' "$rb"; then smoke=1; fi
  if [ "$smoke" -eq 0 ] && [ -d "$dir/.github/workflows" ]; then
    for wf in "$dir"/.github/workflows/*.yml "$dir"/.github/workflows/*.yaml; do
      [ -f "$wf" ] || continue
      if grep -iq 'smoke' "$wf"; then smoke=1; break; fi
    done
  fi
  if [ "$smoke" -eq 0 ]; then
    echo "FAIL: no smoke test referenced (in $rb or a workflow)"
    fail=1
  fi

  if [ "$fail" -ne 0 ]; then return 1; fi
  echo "deployable-ready: OK — release-readiness DOCS present. NOTE: this verifies documentation only, NOT that rollback/alerts/migrations were tested. Those are Manual rows in definition-of-deployable.md requiring release-manager evidence."
  return 0
}

# Build mktemp fixtures and assert each outcome. Fixtures are LEFT in place
# (no rm -rf — avoids tripping the .claude/ runtime guard; see docs/adoption).
selftest() {
  st_fail=0
  base=$(mktemp -d)

  d1="$base/na"; mkdir -p "$d1"
  if check_dir "$d1" >/dev/null 2>&1; then
    echo "selftest PASS: empty dir -> N/A skip"
  else
    echo "selftest FAIL: empty dir should skip-pass"; st_fail=1
  fi

  d2="$base/ok"; mkdir -p "$d2"
  printf 'FROM scratch\n' > "$d2/Dockerfile"
  printf '# RUNBOOK\n\n## Deploy\nrun a smoke test after deploy\n\n## Rollback\nflag-off\n' > "$d2/RUNBOOK.md"
  if check_dir "$d2" >/dev/null 2>&1; then
    echo "selftest PASS: complete deployable -> OK"
  else
    echo "selftest FAIL: complete deployable should pass"; st_fail=1
  fi

  d3="$base/fail"; mkdir -p "$d3"
  printf 'FROM scratch\n' > "$d3/Dockerfile"
  printf '# RUNBOOK\n\n## Deploy\nsmoke test here\n' > "$d3/RUNBOOK.md"
  if check_dir "$d3" >/dev/null 2>&1; then
    echo "selftest FAIL: missing-rollback should FAIL"; st_fail=1
  else
    echo "selftest PASS: missing-rollback -> FAIL as expected"
  fi

  d4="$base/wf"; mkdir -p "$d4/.github/workflows"
  printf 'jobs:\n  deploy:\n    environment: production\n' > "$d4/.github/workflows/deploy.yml"
  printf '# RUNBOOK\n\n## Deploy\nsmoke\n\n## Rollback\nrevert\n' > "$d4/RUNBOOK.md"
  if check_dir "$d4" >/dev/null 2>&1; then
    echo "selftest PASS: workflow-deployable -> OK"
  else
    echo "selftest FAIL: workflow-deployable should pass"; st_fail=1
  fi

  if [ "$st_fail" -ne 0 ]; then
    echo "deployable-ready --selftest: FAIL" >&2
    return 1
  fi
  echo "deployable-ready --selftest: OK (skip/OK/FAIL/workflow all behaved; fixtures left in $base)"
  return 0
}

case "${1:-}" in
  --selftest) selftest ;;
  *)          check_dir "${1:-.}" ;;
esac
```

- [ ] **Step 3: Run the self-test (the positive/FAIL regression-lock)**

Run: `sh conformance/deployable-ready.sh --selftest; echo "exit=$?"`
Expected: four `selftest PASS:` lines, final `deployable-ready --selftest: OK …`, `exit=0`.

- [ ] **Step 4: Run at the kit root (must be N/A)**

Run: `sh conformance/deployable-ready.sh; echo "exit=$?"`
Expected: `N/A: . has no deploy surface … skipping`, `exit=0`.

- [ ] **Step 5: Verify the scope-disclaimer wording is present (anti-false-assurance)**

Run: `grep -c "documentation only, NOT that rollback/alerts/migrations were tested" conformance/deployable-ready.sh`
Expected: `1`.

- [ ] **Step 6: Lint for the subshell-`fail` trap and dash-compat (quick read)**

Run: `sh -n conformance/deployable-ready.sh && echo "syntax OK"` and, if `dash` is available, `dash -n conformance/deployable-ready.sh && echo "dash OK"` (skip the dash line if not installed).
Expected: `syntax OK` (and `dash OK` if run).

- [ ] **Step 7: Commit**

```bash
chmod +x conformance/deployable-ready.sh
git add conformance/deployable-ready.sh
git commit -m "feat(conformance): add deployable-ready.sh — conditional release-readiness check

Auto-verifies documented release-safety (RUNBOOK Deploy+Rollback sections,
smoke reference) for projects with a deploy surface; N/A skip-pass otherwise.
Self-discloses scope (docs present != tested). --selftest fixture battery
(skip/OK/FAIL) regression-locks the positive path.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Create `conformance/definition-of-deployable.md`

**Files:**
- Create: `conformance/definition-of-deployable.md`

- [ ] **Step 1: Create the checklist**

Create `conformance/definition-of-deployable.md` with EXACTLY this content:

```markdown
# Conformance Check — Definition of Deployable

Proves a **release** is safe to promote: rollback ready, smoke + monitoring wired, migrations reversible. **Checklist-type**, run at the **Release gate** (`DEVELOPMENT-PROCESS.md` §7, after Review). **Conditional:** non-deployable projects (library, CLI, batch) mark the whole check **N/A — not a deployable service**. Aligns with OWASP DSOMM (deployment/release maturity) and the Safe Change Delivery contract (`DEVELOPMENT-PROCESS.md` §10).

> **What the Auto rows prove — and don't.** The `deployable-ready.sh` rows confirm the release-safety procedures are *written down* (RUNBOOK has Deploy + Rollback sections) and a smoke test is *referenced*. They do **not** verify the rollback was tested, alerts are wired, or the migration down-path works — those are the **Manual** rows, signed off by the release manager with evidence. **A green script is necessary, not sufficient.**

## How to use
Copy this file into your project (or your release record). For each item: mark **Applies? (Y / N+reason)** and give **Evidence** (where/how it's met). Items tagged *(documented)* are auto-checkable via `sh conformance/deployable-ready.sh`; items tagged *(tested / wired)* require the release manager's evidence. The reviewer signs off only when every applicable item has evidence.

## Checklist (blank)

| # | Item | Applies? | Evidence (where/how) | Check |
|---|------|----------|----------------------|-------|
| 1 | Rollback path **declared before ship** — flag-off → redeploy previous → revert (§10) *(documented)* | | | **Auto:** `deployable-ready.sh` (RUNBOOK Rollback section) |
| 2 | Rollback path **tested** — the chosen path was actually exercised *(tested)* | | | Manual |
| 3 | DB migration **reversible** — down-path tested, expand-contract; N/A if no migration *(tested)* | | | Manual |
| 4 | Feature flags have **owner + expiry**; N/A if no flags (no-expiry flag is a defect, §10) *(wired)* | | | Manual |
| 5 | Progressive-delivery plan — canary / blue-green / staged (§10); N/A at Stage 1 with reason *(wired)* | | | Manual |
| 6 | Smoke test **defined** and post-deploy result recorded *(tested)* | | | Manual |
| 7 | Smoke test **referenced** in RUNBOOK or a workflow *(documented)* | | | **Auto:** `deployable-ready.sh` |
| 8 | Monitoring / alerts wired on the change's critical paths (§3) *(wired)* | | | Manual |
| 9 | Supply-chain CI gates green — SBOM + provenance (§14) *(documented)* | | | **Auto:** `ci-gates.sh <workflow>` |
| 10 | RUNBOOK has a **Deploy** section + a **Rollback** section *(documented)* | | | **Auto:** `deployable-ready.sh` |
| 11 | CHANGELOG entry recorded for this release (§15) | | | Manual |

## Worked example — TypeScript/Node reference profile (a deployable HTTP service, no DB change this release)

| # | Item | Applies? | Evidence | Check |
|---|------|----------|----------|-------|
| 1 | Rollback declared *(documented)* | Y | RUNBOOK §5 Rollback: flag-off → redeploy previous digest | Auto ✅ |
| 2 | Rollback tested *(tested)* | Y | staging rollback drill run 2026-06-08, screenshot in release record | Manual ✅ |
| 3 | Migration reversible *(tested)* | **N/A** | no schema change this release | — |
| 4 | Flags owner + expiry *(wired)* | Y | `checkout-v2` flag — owner @release-mgr, expiry 2026-07-01 (flag registry) | Manual ✅ |
| 5 | Progressive delivery *(wired)* | Y | staged: 10% canary → full, watch error rate (§9) | Manual ✅ |
| 6 | Smoke defined + result *(tested)* | Y | post-deploy smoke job; run #1423 green | Manual ✅ |
| 7 | Smoke referenced *(documented)* | Y | `smoke` step in `deploy.yml` + RUNBOOK §4 | Auto ✅ |
| 8 | Monitoring/alerts *(wired)* | Y | Sentry alert rule + p95 latency alert on the changed route (§3) | Manual ✅ |
| 9 | Supply-chain gates *(documented)* | Y | `gate-sbom` + `gate-provenance` green (profile ci.yml) | Auto ✅ |
| 10 | RUNBOOK Deploy + Rollback *(documented)* | Y | RUNBOOK §4, §5 | Auto ✅ |
| 11 | CHANGELOG entry | Y | CHANGELOG `## [1.4.0]` | Manual ✅ |

> A library or CLI marks the whole check **N/A — not a deployable service** (no promotion to a running environment); `deployable-ready.sh` skip-passes such a project automatically.
```

- [ ] **Step 2: Verify the callout + labels are present**

Run:
```bash
grep -c "A green script is necessary, not sufficient" conformance/definition-of-deployable.md
grep -c "(documented)" conformance/definition-of-deployable.md
grep -c "(tested" conformance/definition-of-deployable.md
```
Expected: first `1`; second ≥ 4; third ≥ 3.

- [ ] **Step 3: Link check**

Run: `sh conformance/check-links.sh; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add conformance/definition-of-deployable.md
git commit -m "feat(conformance): add Definition of Deployable release-readiness checklist

Conditional Release-gate checklist (blank + worked ts-node example),
Manual judgment rows + Auto rows, with a 'necessary not sufficient'
callout and (documented)/(tested/wired) row labels. DSOMM anchor.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Add a smoke-test slot to `templates/RUNBOOK-TEMPLATE.md`

**Files:**
- Modify: `templates/RUNBOOK-TEMPLATE.md` (§4 Deploy, after line 29 `- Steps:`)

Consistency fix: the RUNBOOK template currently has no smoke reference, so an incepted deployable project would FAIL `deployable-ready.sh`'s smoke check. Give it a slot.

- [ ] **Step 1: Assert no smoke mention exists yet**

Run: `grep -ci "smoke" templates/RUNBOOK-TEMPLATE.md; echo done`
Expected: `0`.

- [ ] **Step 2: Add the smoke bullet**

In `templates/RUNBOOK-TEMPLATE.md`, find this exact line (in §4 Deploy):
```
- Steps: `[deploy command(s)]`
```
Insert a new line directly AFTER it:
```
- Smoke test: after each deploy run the post-deploy smoke test (`[smoke test command]`) and record the result before declaring the release live — gates the **Definition of Deployable** (`conformance/definition-of-deployable.md`).
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -ci "smoke" templates/RUNBOOK-TEMPLATE.md
sh conformance/check-links.sh; echo "exit=$?"
```
Expected: smoke count `1`; links `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add templates/RUNBOOK-TEMPLATE.md
git commit -m "docs(templates): add a smoke-test slot to RUNBOOK Deploy section

So an incepted deployable project satisfies deployable-ready.sh's
smoke-signal check — the kit's own scaffolding passes its own gate.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Wire the §7 gate + §4 Release + §10 rollback references

**Files:**
- Modify: `DEVELOPMENT-PROCESS.md` (§7 line 185 + line 189; §4 line 112; §10 line 285)

- [ ] **Step 1: Add the §7 gate row**

Find this exact line (§7 gates table):
```
| **15-Factor conformance** *(deployable services)* | Does the architecture satisfy the applicable 15 factors? (`conformance/15-factor-checklist.md`) | Reviewer + lead |
```
Insert this row directly AFTER it:
```
| **Definition of Deployable** *(deployable services)* | Is the release safe to promote — rollback ready, smoke + monitoring wired? (`conformance/definition-of-deployable.md`) | Release manager + reviewer |
```

- [ ] **Step 2: Update the conditional-gates sentence**

Find this exact text (line 189):
```
Threat-model, eval, compliance, and 15-factor gates are **conditional** — they apply to sensitive / AI / regulated / deployable-service work respectively, not every item (don't impose them where they optimize nothing).
```
Replace with:
```
Threat-model, eval, compliance, 15-factor, and Definition-of-Deployable gates are **conditional** — they apply to sensitive / AI / regulated / deployable-service work respectively, not every item (don't impose them where they optimize nothing).
```

- [ ] **Step 3: Reference the checklist from the §4 Release stage**

Find this exact line (§4, line 112):
```
| **Release** | "Done → Live": deploy, feature flags, staged rollout, smoke test, CHANGELOG, rollback ready — see **Safe Change Delivery (§10)**. Breaking changes need explicit approval. | Live in production |
```
Replace with:
```
| **Release** | "Done → Live": deploy, feature flags, staged rollout, smoke test, CHANGELOG, rollback ready — see **Safe Change Delivery (§10)**; verified against `conformance/definition-of-deployable.md`. Breaking changes need explicit approval. | Live in production |
```

- [ ] **Step 4: Reference the checklist from the §10 rollback line**

Find this exact line (§10, line 285):
```
- Preference order: **flag-off → redeploy previous → revert + redeploy**. Every release declares its rollback path *before* it ships (the "rollback ready" in §4).
```
Replace with:
```
- Preference order: **flag-off → redeploy previous → revert + redeploy**. Every release declares its rollback path *before* it ships (the "rollback ready" in §4) — captured in `conformance/definition-of-deployable.md`.
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -c "Definition of Deployable" DEVELOPMENT-PROCESS.md
grep -c "Definition-of-Deployable gates are" DEVELOPMENT-PROCESS.md
grep -c "conformance/definition-of-deployable.md" DEVELOPMENT-PROCESS.md
sh conformance/check-links.sh; echo "exit=$?"
```
Expected: first ≥ 1; second `1`; third `3` (the gate row + §4 + §10); links `exit=0`.

- [ ] **Step 6: Commit**

```bash
git add DEVELOPMENT-PROCESS.md
git commit -m "feat(process): wire Definition of Deployable as a conditional Release gate

New §7 gate row (deployable services); §4 Release and §10 rollback now
reference conformance/definition-of-deployable.md.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Index the checks (README + audit-evidence)

**Files:**
- Modify: `conformance/README.md` (index table, after the `15-factor-checklist.md` row)
- Modify: `conformance/audit-evidence-checklist.md` (after the `RUNBOOK · DR / rollback` row)

- [ ] **Step 1: Add two README index rows**

In `conformance/README.md`, find this exact row:
```
| `15-factor-checklist.md` | checklist | `DEVELOPMENT-STANDARDS.md` §13 (15-Factor Architecture) | Review (conditional) |
```
Insert these two rows directly AFTER it:
```
| `definition-of-deployable.md` | checklist | `DEVELOPMENT-PROCESS.md` §10 / §4 (release readiness) | Release (conditional) |
| `deployable-ready.sh` | script | `DEVELOPMENT-PROCESS.md` §10 — documented release-safety (RUNBOOK deploy/rollback + smoke); pairs with the checklist | Release / CI (conditional on a deploy surface) |
```

- [ ] **Step 2: Add the audit-evidence row**

In `conformance/audit-evidence-checklist.md`, find this exact row:
```
| RUNBOOK · DR / rollback | CC7.4, CC7.5 / A.5.29, A.8.13 | RUNBOOK | Manual (file present) | |
```
Insert this row directly AFTER it:
```
| Release readiness · Definition of Deployable | CC8.1 / A.8.31, A.8.32 | filled `definition-of-deployable.md` + script output | **Auto (conditional):** `sh conformance/deployable-ready.sh` | |
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -c "definition-of-deployable.md" conformance/README.md
grep -c "deployable-ready.sh" conformance/README.md
grep -c "Release readiness · Definition of Deployable" conformance/audit-evidence-checklist.md
sh conformance/check-links.sh; echo "exit=$?"
```
Expected: first `1`; second `1`; third `1`; links `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add conformance/README.md conformance/audit-evidence-checklist.md
git commit -m "docs(conformance): index definition-of-deployable + deployable-ready; audit row

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Dogfood in kit CI

**Files:**
- Modify: `.github/workflows/ci.yml` (conformance job — after the Profile-completeness step)

- [ ] **Step 1: Read the conformance job to find the insertion point**

Run: `grep -n "Profile-completeness conformance" .github/workflows/ci.yml`
Expected: one match (the last step in the `conformance` job, currently). Insert the new steps directly after its `run:` line.

- [ ] **Step 2: Add the three steps**

After the Profile-completeness step (its `run: sh conformance/profile-completeness.sh` line), insert these three steps at the same indentation as the sibling steps (6-space `- name:`):
```yaml
      - name: Definition-of-Deployable checklist present
        run: test -f conformance/definition-of-deployable.md
      - name: Deployable-ready conditional (N/A at kit root)
        run: sh conformance/deployable-ready.sh
      - name: Deployable-ready self-test (skip/OK/FAIL fixtures)
        run: sh conformance/deployable-ready.sh --selftest
```

- [ ] **Step 3: Verify YAML + that ci-gates still passes (no gate-id change)**

Run:
```bash
grep -c "Deployable-ready self-test" .github/workflows/ci.yml
sh conformance/ci-gates.sh profiles/typescript-node/ci.yml; echo "ci-gates=$?"
```
Expected: first `1`; `ci-gates=0` (the kit's reference profile still declares all 8 gates — this slice added no gate-id).

> Note: the kit's `.github/workflows/ci.yml` is NOT validated by `ci-gates.sh` (it is the meta-CI pipeline, not an app pipeline). Adding steps to it is safe; `ci-gates.sh` runs against `profiles/typescript-node/ci.yml`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: dogfood deployable-ready (present + N/A + selftest)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Version bump, CHANGELOG, ROADMAP

**Files:**
- Modify: `VERSION`, `CHANGELOG.md`, `docs/ROADMAP-KIT.md`

- [ ] **Step 1: Bump VERSION**

Replace the contents of `VERSION` (`2.19.0`) with:
```
2.20.0
```

- [ ] **Step 2: Add the CHANGELOG entry**

Insert this entry immediately ABOVE the `## [2.19.0] - 2026-06-09` line:
```markdown
## [2.20.0] - 2026-06-09

Slice 8b — Definition of Deployable. Second sub-slice of Slice 8 (continuity & safe-delivery hardening). Closes gap B1 (release-readiness contract not enforced): converts §10's "every release declares its rollback path before it ships" into a conditional Release gate.

### Added
- **`conformance/definition-of-deployable.md`** — a conditional release-readiness checklist (Release gate, `DEVELOPMENT-PROCESS.md` §7) mixing **Manual** judgment rows (rollback tested, alerts wired, migration reversible) and **Auto** rows. Carries a "a green script is necessary, not sufficient" callout and *(documented)* / *(tested / wired)* row labels. OWASP DSOMM anchor.
- **`conformance/deployable-ready.sh`** — a conditional, fail-closed companion script: for a project with a deploy surface (Dockerfile / `environment:` workflow / deploy job) it asserts RUNBOOK has Deploy + Rollback sections and a smoke test is referenced; non-deployable projects skip-pass (N/A). Its success output self-discloses scope (documents present, **not** tested). A **`--selftest`** fixture battery (skip/OK/FAIL) regression-locks the positive path in CI.
- **`DEVELOPMENT-PROCESS.md` §7** — new conditional **Definition of Deployable** gate (deployable services; Release manager + reviewer); §4 Release and §10 rollback reference the checklist.
- **`templates/RUNBOOK-TEMPLATE.md`** — a smoke-test slot under §4 Deploy, so an incepted deployable project satisfies the new check.
- **`conformance/audit-evidence-checklist.md`** — a Release-readiness row (CC8.1 / A.8.31, A.8.32; Auto-conditional).

### Note
MINOR (2.20.0): additive — a **conditional** Release gate at a human checkpoint (like the threat-model / eval / 15-factor gates), not a new universally-required CI gate. The 8 application CI gate-ids and §14 are unchanged.
```

- [ ] **Step 3: Add the ROADMAP row**

In `docs/ROADMAP-KIT.md`, insert this row immediately AFTER the `8a ✅` row:
```
| 8b ✅ | **Definition of Deployable** *(shipped v2.20.0)* | process §7/§4/§10 (release readiness) | `definition-of-deployable.md` + `deployable-ready.sh` (conditional, --selftest) | `deployable-ready.sh --selftest` + `check-links.sh` |
```

- [ ] **Step 4: Verify**

Run:
```bash
cat VERSION
grep -c "## \[2.20.0\]" CHANGELOG.md
grep -c "8b ✅" docs/ROADMAP-KIT.md
sh conformance/check-links.sh; echo "exit=$?"
```
Expected: `2.20.0`; `1`; `1`; links `exit=0`.

- [ ] **Step 5: Commit**

```bash
git add VERSION CHANGELOG.md docs/ROADMAP-KIT.md
git commit -m "chore(release): 2.20.0 — Definition of Deployable release gate (8b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Full conformance sweep + push + PR (stop for ratification)

**Files:** none (verification + push only)

- [ ] **Step 1: Run every conformance check**

Run:
```bash
sh conformance/check-links.sh; echo "links=$?"
for p in profiles/*/ci.yml; do sh conformance/ci-gates.sh "$p" >/dev/null 2>&1 || echo "FAIL $p"; done; echo "ci-gates done"
sh conformance/profile-completeness.sh >/dev/null 2>&1; echo "profiles=$?"
sh conformance/agent-autonomy.sh >/dev/null 2>&1; echo "autonomy=$?"
sh conformance/container-supply-chain.sh >/dev/null 2>&1; echo "containers=$?"
sh conformance/backlog-adapters.sh >/dev/null 2>&1; echo "backlog=$?"
sh conformance/guard-wired.sh >/dev/null 2>&1; echo "guard=$?"
sh conformance/deployable-ready.sh; echo "deployable-root=$?"
sh conformance/deployable-ready.sh --selftest; echo "deployable-selftest=$?"
```
Expected: `links=0`, no `FAIL` lines from ci-gates, `profiles=0`, `autonomy=0`, `containers=0`, `backlog=0`, `guard=0`, `deployable-root=0` (N/A), `deployable-selftest=0`. (`inception-done.sh` is expected to fail at the kit root and is NOT run.)

- [ ] **Step 2: Final spec-coverage greps**

Run:
```bash
ls conformance/deployable-ready.sh conformance/definition-of-deployable.md
grep -c "documentation only, NOT that rollback/alerts/migrations were tested" conformance/deployable-ready.sh   # 1
grep -c "A green script is necessary, not sufficient" conformance/definition-of-deployable.md                   # 1
grep -c "Definition of Deployable" DEVELOPMENT-PROCESS.md                                                       # >=1
cat VERSION                                                                                                     # 2.20.0
```

- [ ] **Step 3: Confirm clean tree + push**

```bash
git status --short    # only the pre-existing untracked .firecrawl/ (not part of this slice)
git push -u origin feature/slice-8b-definition-of-deployable
```

- [ ] **Step 4: Open the PR (do NOT merge — human ratification gate)**

```bash
gh pr create --title "Slice 8b — Definition of Deployable release gate (v2.20.0)" \
  --body "$(cat <<'EOF'
Closes gap B1 (Slice 8 arc). Converts §10's 'every release declares its rollback path before it ships' into an enforced, conditional Release gate.

## What
- **`conformance/definition-of-deployable.md`** — conditional Release-gate checklist (Manual judgment rows + Auto rows), with a 'necessary, not sufficient' callout and (documented)/(tested/wired) labels. DSOMM anchor.
- **`conformance/deployable-ready.sh`** — conditional, fail-closed companion: asserts documented release-safety (RUNBOOK Deploy+Rollback + smoke reference) for a project with a deploy surface; N/A skip-pass otherwise. Self-discloses scope (docs present != tested). `--selftest` fixture battery regression-locks the positive path in CI.
- **§7** new conditional **Definition of Deployable** gate; §4 Release + §10 rollback reference the checklist.
- **RUNBOOK template** smoke slot (so incepted projects pass); **audit-evidence** release-readiness row; **kit CI** runs present + N/A + selftest.

## Anti-false-assurance (raised at design review, remedied in-contract)
A green automated check could be misread as 'safe to deploy'. So: the script self-discloses it verifies *documentation only, not testing*; the checklist carries a bold 'necessary, not sufficient' callout; behavioural items stay **Manual**, signed by the release manager. Verified by grep in CI.

## Verification
All conformance green; `deployable-ready.sh --selftest` exercises skip/OK/FAIL in CI; MINOR -> 2.20.0 (conditional human-checkpoint gate; no new CI gate-id; §14 unchanged).

## Governance
Governing-doc surface (PROCESS §7/§4/§10) -> **security-owner lens**. Agent does not self-merge — this PR stops for human ratification.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: STOP for human ratification**

Do not merge. Report the PR URL + green conformance results to Bradley for review (governing-doc change → security-owner lens per §13/RBAC).

---

## Self-Review

**1. Spec coverage:**
- Deliverable A (checklist) → Task 2. ✅
- Deliverable B (script, disclaimer, --selftest) → Task 1. ✅
- Deliverable C (§7 gate row) → Task 4 Steps 1–2. ✅
- Deliverable D (§4 + §10 refs) → Task 4 Steps 3–4. ✅
- Deliverable E (README index) → Task 5 Step 1. ✅
- Deliverable F (audit-evidence row) → Task 5 Step 2. ✅
- Deliverable G (CI: present + N/A + selftest) → Task 6. ✅
- Meta → Task 7. ✅
- Anti-false-assurance (§3, §5, §6) → Task 1 (disclaimer output + grep), Task 2 (callout + labels). ✅
- RUNBOOK smoke consistency fix (surfaced in planning; needed so kit scaffolding passes its own gate) → Task 3. ✅ (additive to the spec's deliverables; documented rationale.)

**2. Placeholder scan:** The `[smoke test command]` etc. in the RUNBOOK bullet and checklist are intended template fill-ins (house style), not plan placeholders. The script and checklist are given in full. No "TBD/implement later" in plan instructions. ✅

**3. Consistency:** `deployable-ready.sh` and `definition-of-deployable.md` names are identical across all tasks, CI, README, audit row, CHANGELOG, ROADMAP. The disclaimer string in Task 1 Step 2 (the script) matches the grep in Task 1 Step 5, Task 8 Step 2, and the §8 spec assertion verbatim ("documentation only, NOT that rollback/alerts/migrations were tested"). The `--selftest` outcomes (skip/OK/FAIL/workflow) match between the script body (Task 1) and the spec. Detection triggers (Dockerfile / `environment:` / deploy job) are consistent between `wf_is_deploy()` and the Task 1 Step 1 pre-check greps. ✅
