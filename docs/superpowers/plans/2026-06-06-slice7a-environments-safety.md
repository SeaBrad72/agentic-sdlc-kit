# Slice 7a: Environments & Production Safety — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the Dev→QA→UAT→Prod environment model (gated promotion, prod always human-gated) and make the agent guard environment-aware **additively** — expanded destructive-tool coverage + a prod-context catch-all — plus branch-protection conformance, an env-protected prod-deploy reference, and an honest human-coverage boundary.

**Architecture:** Mostly docs + the guard shell script + conformance. The guard change is purely additive (no existing deny weakened); the 35 existing `agent-autonomy.sh` cases are the regression lock. POSIX `sh`/`grep -E` only (dash-portable).

**Tech Stack:** Markdown · POSIX shell · `grep -E` · `gh` CLI (branch-protection) · GitHub Actions.

**Design source:** `docs/superpowers/specs/2026-06-06-slice7a-environments-safety-design.md`.

---

## Task 1: Environment model (the contract)

**Files:** `DEVELOPMENT-PROCESS.md`, `DEVELOPMENT-STANDARDS.md`, `templates/PROJECT-CLAUDE-TEMPLATE.md`, `templates/RUNBOOK-TEMPLATE.md`

- [ ] **Step 1: `DEVELOPMENT-PROCESS.md`** — add a new subsection "Environments & promotion" (place it logically near the Inception config / Operate sections; pick the spot where environments are first referenced). Content:
```markdown
### Environments & promotion

Changes flow through a promotion pipeline with a gate between each tier:

| Tier | Purpose | Promotion gate into it |
|------|---------|------------------------|
| **Dev** | Active development / integration | CI green on the PR |
| **QA** | Automated + integration acceptance | Dev green + test suite/integration pass |
| **UAT** | Stakeholder / business acceptance | QA green + acceptance sign-off (PO/QA) |
| **Prod** | Live users | UAT sign-off + **human approval (Release Manager)** |

**Production promotion is always human-gated** regardless of agent autonomy tier (§13) — it is in the irreversible/high-blast set. Promotion is forward-only through the tiers; no skipping straight to Prod.

A project may **collapse tiers with a one-line reason** (e.g. a tiny internal tool runs Dev→Prod) — but the contract is: at least one non-prod tier, gated promotion, and a human gate on prod. Environments and per-tier deploy triggers are declared in the project `CLAUDE.md` (§3).
```

- [ ] **Step 2: `DEVELOPMENT-STANDARDS.md` §14** — add a promotion/deploy gate note after the existing branch-protection/provenance content (do NOT alter the 7-gate table): a short paragraph stating production deploys require a green pipeline **and** human approval via a protected environment, and that destructive operations against production are prohibited from automated agents (enforced by the §13 guard; platform controls own the human side). Align §13 factor 9 wording from "dev/prod parity" to parity **across all tiers** (Dev/QA/UAT/Prod).

- [ ] **Step 3: `templates/PROJECT-CLAUDE-TEMPLATE.md`** — replace line 53:
```markdown
- **Environments:** local → [staging?] → production — [deploy triggers]
```
with:
```markdown
- **Environments** (§ "Environments & promotion"): Dev → QA → UAT → Prod — [per-tier deploy trigger]; [if collapsing tiers, name which you use + one-line reason]. Production promotion is human-gated.
```

- [ ] **Step 4: `templates/RUNBOOK-TEMPLATE.md`** — ensure the deploy/rollback section names the promotion path (Dev→QA→UAT→Prod) and a per-tier rollback. (Locate the existing deploy/rollback area; add the promotion line + prod rollback if absent.)

- [ ] **Step 5: Verify + commit.**
```bash
sh conformance/check-links.sh ; echo "exit=$?"   # 0
grep -q "Environments & promotion" DEVELOPMENT-PROCESS.md && echo ok
git add DEVELOPMENT-PROCESS.md DEVELOPMENT-STANDARDS.md templates/PROJECT-CLAUDE-TEMPLATE.md templates/RUNBOOK-TEMPLATE.md
git commit -m "$(printf 'docs(process): Dev/QA/UAT/Prod environment model + gated promotion\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 2: Environment-aware guard + conformance (the security core)

**Files:** `.claude/hooks/guard.sh`, `conformance/agent-autonomy.sh`

**CRITICAL:** additive only. Do NOT remove or narrow any existing deny. All 35 existing `agent-autonomy.sh` cases must still pass.

- [ ] **Step 1: Extend the existing DB-client SQL deny** (`guard.sh` ~line 76) to include `DROP DATABASE`. Change the inner alternation from:
```
(drop[[:space:]]+table|truncate|delete[[:space:]]+from)
```
to:
```
(drop[[:space:]]+(table|database)|truncate|delete[[:space:]]+from)
```

- [ ] **Step 2: Add new destructive blanket-ban blocks** in the `Bash)` case, after the existing migration-runner block (~line 82), each in the established `if printf '%s' "$CMD" | grep -E... ; then emit_deny ...; fi` style:

```sh
    # ORM / framework DB destruction (drop/reset/wipe/fresh) across stacks
    if printf '%s' "$CMD" | grep -Eiq '(rails|rake)[[:space:]]+db:(drop|reset|migrate:reset|purge)|artisan[[:space:]]+(migrate:fresh|migrate:reset|db:wipe)|manage\.py[[:space:]]+(flush|reset_db|sqlflush)|alembic[[:space:]]+downgrade[[:space:]]+base|flyway[[:space:]]+clean|dotnet[[:space:]]+ef[[:space:]]+database[[:space:]]+drop'; then
      emit_deny "13: destructive DB drop/reset via an ORM/framework tool - human-gated."
    fi
    # pg_restore --clean drops objects before restore
    if printf '%s' "$CMD" | grep -Eq 'pg_restore[^|]*(--clean|[[:space:]]-c([[:space:]]|$))'; then
      emit_deny "13: pg_restore --clean drops objects irreversibly - human-gated."
    fi
    # redis flush wipes the datastore
    if printf '%s' "$CMD" | grep -Eiq 'redis-cli[^|]*(flushall|flushdb)'; then
      emit_deny "13: redis FLUSHALL/FLUSHDB wipes the datastore - human-gated."
    fi
    # cluster / container state destruction
    if printf '%s' "$CMD" | grep -Eq 'kubectl[[:space:]]+([^|]*[[:space:]])?delete([[:space:]]|$)'; then
      emit_deny "13: kubectl delete removes cluster resources - human-gated."
    fi
    if printf '%s' "$CMD" | grep -Eq 'docker[[:space:]]+(volume[[:space:]]+(rm|prune)|system[[:space:]]+prune[^|]*-a)'; then
      emit_deny "13: docker volume/system prune destroys persistent state - human-gated."
    fi
    # cloud resource deletion
    if printf '%s' "$CMD" | grep -Eq 'aws[[:space:]]+s3[[:space:]]+rm[^|]*--recursive|aws[[:space:]]+s3[[:space:]]+rb|aws[[:space:]]+rds[[:space:]]+delete-db-instance|aws[[:space:]]+dynamodb[[:space:]]+delete-table|gcloud[[:space:]]+sql[[:space:]]+instances[[:space:]]+delete|az[[:space:]]+group[[:space:]]+delete|az[[:space:]]+sql[^|]*[[:space:]]delete'; then
      emit_deny "13: cloud resource deletion (storage/DB/instance) is irreversible - human-gated."
    fi
```

- [ ] **Step 3: Add the prod-context catch-all** (after the existing deploy/apply block ~line 93), two blocks. Each requires a prod marker AND a mutating verb to co-occur (avoids false positives on reads / "production" in prose):

```sh
    # prod-context catch-all: a mutating kube/helm op against a prod context
    if printf '%s' "$CMD" | grep -Eiq '--(kube-)?context[[:space:]=][^[:space:]]*prod' \
       && printf '%s' "$CMD" | grep -Eiq '(kubectl|helm)[[:space:]]([^|]*[[:space:]])?(apply|delete|create|replace|patch|scale|rollout|upgrade|install|uninstall|destroy)'; then
      emit_deny "13: mutating operation against a production context - human-gated."
    fi
    # prod-env-prefixed destructive/deploy command (NODE_ENV=production ... migrate|deploy|...)
    if printf '%s' "$CMD" | grep -Eq '(^|[;&|][[:space:]]*)([A-Z_]*ENV)=prod[a-z]*[[:space:]]' \
       && printf '%s' "$CMD" | grep -Eiq '(migrate|deploy|apply|reset|drop|delete|destroy|publish|flush|truncate|prune)'; then
      emit_deny "13: destructive/deploy command in a production environment - human-gated."
    fi
    # explicit --env/--environment production with a destructive/deploy verb
    if printf '%s' "$CMD" | grep -Eiq '--(env|environment)[[:space:]=]prod' \
       && printf '%s' "$CMD" | grep -Eiq '(migrate|deploy|apply|reset|drop|delete|destroy|publish|flush|truncate|prune)'; then
      emit_deny "13: destructive/deploy command targeting production - human-gated."
    fi
```

- [ ] **Step 4: Update the guard header comment** (lines 2-15 area) to mention the expanded coverage (ORM/cloud/cluster destruction + prod-context catch-all) in the same descriptive style.

- [ ] **Step 5: Add conformance cases** in `conformance/agent-autonomy.sh`. After the existing bypass-resistance block, add a new labeled block:
```sh
# --- 7a: expanded destructive coverage + prod-context catch-all (must DENY) ---
assert_deny "DROP DATABASE"        '{"tool_name":"Bash","tool_input":{"command":"psql -c \"DROP DATABASE app\""}}'
assert_deny "rails db:drop"        '{"tool_name":"Bash","tool_input":{"command":"rails db:drop"}}'
assert_deny "rake db:reset"        '{"tool_name":"Bash","tool_input":{"command":"bundle exec rake db:reset"}}'
assert_deny "artisan migrate:fresh" '{"tool_name":"Bash","tool_input":{"command":"php artisan migrate:fresh"}}'
assert_deny "manage.py flush"      '{"tool_name":"Bash","tool_input":{"command":"python manage.py flush"}}'
assert_deny "alembic downgrade base" '{"tool_name":"Bash","tool_input":{"command":"alembic downgrade base"}}'
assert_deny "flyway clean"         '{"tool_name":"Bash","tool_input":{"command":"flyway clean"}}'
assert_deny "ef database drop"     '{"tool_name":"Bash","tool_input":{"command":"dotnet ef database drop -f"}}'
assert_deny "pg_restore --clean"   '{"tool_name":"Bash","tool_input":{"command":"pg_restore --clean -d app dump.sql"}}'
assert_deny "redis FLUSHALL"       '{"tool_name":"Bash","tool_input":{"command":"redis-cli FLUSHALL"}}'
assert_deny "kubectl delete"       '{"tool_name":"Bash","tool_input":{"command":"kubectl delete deployment api"}}'
assert_deny "docker volume rm"     '{"tool_name":"Bash","tool_input":{"command":"docker volume rm pgdata"}}'
assert_deny "aws s3 rm recursive"  '{"tool_name":"Bash","tool_input":{"command":"aws s3 rm s3://bucket --recursive"}}'
assert_deny "gcloud sql delete"    '{"tool_name":"Bash","tool_input":{"command":"gcloud sql instances delete prod-db"}}'
assert_deny "prod kube apply"      '{"tool_name":"Bash","tool_input":{"command":"kubectl --context prod-cluster apply -f k8s/"}}'
assert_deny "prod env migrate"     '{"tool_name":"Bash","tool_input":{"command":"NODE_ENV=production npm run migrate"}}'
assert_deny "--env production deploy" '{"tool_name":"Bash","tool_input":{"command":"./deploy.sh --env production"}}'

# --- 7a: false-positive guards (must ALLOW) ---
assert_allow "kubectl get pods"        '{"tool_name":"Bash","tool_input":{"command":"kubectl get pods -n app"}}'
assert_allow "docker build"            '{"tool_name":"Bash","tool_input":{"command":"docker build -t app ."}}'
assert_allow "aws s3 ls"               '{"tool_name":"Bash","tool_input":{"command":"aws s3 ls s3://bucket"}}'
assert_allow "prod-context read"       '{"tool_name":"Bash","tool_input":{"command":"kubectl --context prod-cluster get pods"}}'
assert_allow "NODE_ENV prod build"     '{"tool_name":"Bash","tool_input":{"command":"NODE_ENV=production npm run build"}}'
assert_allow "commit msg flush cache"  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"flush the cache on deploy\""}}'
```

- [ ] **Step 6: Run conformance — prove no weakening + new coverage.**
```bash
sh conformance/agent-autonomy.sh ; echo "exit=$?"
```
Expected: exit 0; the output lists ALL prior PASSes plus the new ones. If ANY prior case flips to FAIL, the additive rule was violated — fix before commit.
Also confirm dash-portability: `dash -n .claude/hooks/guard.sh ; echo "syntax=$?"` (expect 0) and re-run the conformance under `sh`.

- [ ] **Step 7: Commit.**
```bash
git add .claude/hooks/guard.sh conformance/agent-autonomy.sh
git commit -m "$(printf 'feat(guard): env-aware guard — expand destructive coverage + prod catch-all\n\nAdditive only: ORM/cloud/cluster DB-destroy + prod-context catch-all.\nAll 35 prior agent-autonomy cases still pass; new deny+allow cases added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: branch-protection conformance + incept wiring

**Files:** Create `conformance/branch-protection.sh`; modify `scripts/incept.sh`, `conformance/README.md`, `conformance/audit-evidence-checklist.md`

- [ ] **Step 1: Create `conformance/branch-protection.sh`** (POSIX sh, informational-clean-exit when it can't reach the API):
```sh
#!/bin/sh
# branch-protection.sh — conformance check that `main` is actually protected on the
# remote (DEVELOPMENT-STANDARDS.md §14 / DEVELOPMENT-PROCESS.md §12). Requires `gh`
# authenticated against the repo's remote. If gh is absent/unauthenticated or there is
# no GitHub remote, exits 0 with an informational message (cannot verify here — run in
# CI or authenticate), mirroring inception-done.sh's "needs context" behavior.
set -eu

BRANCH="${1:-main}"
if ! command -v gh >/dev/null 2>&1; then
  echo "branch-protection: gh not installed — cannot verify protection here (run in CI / authenticate). Informational."; exit 0
fi
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -z "$REPO" ]; then
  echo "branch-protection: no GitHub repo context — cannot verify here. Informational."; exit 0
fi
PROT=$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>/dev/null || true)
if [ -z "$PROT" ]; then
  echo "FAIL: $BRANCH on $REPO has no branch protection (or it is not readable)."; exit 1
fi
ok=0
printf '%s' "$PROT" | grep -q '"required_pull_request_reviews"' || { echo "FAIL: required PR reviews not enabled on $BRANCH"; ok=1; }
printf '%s' "$PROT" | grep -q '"required_status_checks"' || { echo "FAIL: required status checks not enabled on $BRANCH"; ok=1; }
[ "$ok" -eq 0 ] && echo "OK: $BRANCH on $REPO is protected (PR reviews + status checks required)."
exit "$ok"
```
Make it executable (`chmod +x`).

- [ ] **Step 2: Wire `incept.sh`** — after the CODEOWNERS copy (line 100), attempt-or-hard-remind branch protection. Replace the next-steps item #3 with an actual attempt:
```sh
  # attempt to apply branch protection if gh is available + authed; else hard-remind
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "note: configure branch protection on main now: see profiles/${STACK}/BRANCH-PROTECTION.md (gh api command)."
  fi
```
(Keep it a clear instruction — actually running the `gh api` mutation from incept is itself a privileged action; a hard reminder pointing at the profile's `BRANCH-PROTECTION.md` is the safe default. Update next-steps item #3 to: "Protect main — run the gh-api command in profiles/${STACK}/BRANCH-PROTECTION.md; verify with `sh conformance/branch-protection.sh`.")

- [ ] **Step 3: `conformance/README.md`** — add an index row after `profile-completeness.sh`:
```markdown
| `branch-protection.sh` | script | `DEVELOPMENT-STANDARDS.md` §14 / `DEVELOPMENT-PROCESS.md` §12 — `main` is actually protected | CI (where gh can reach the API) |
```

- [ ] **Step 4: `conformance/audit-evidence-checklist.md`** — update the "Branch protection · builder ≠ sole merger" row's Check column to reference `**Auto (where reachable):** sh conformance/branch-protection.sh` (keep it honest about the API-reachability caveat).

- [ ] **Step 5: Verify + commit.**
```bash
sh conformance/branch-protection.sh ; echo "exit=$?"   # informational clean-exit locally (no FAIL crash)
dash -n conformance/branch-protection.sh ; echo "syntax=$?"
sh conformance/check-links.sh ; echo "links=$?"
git add conformance/branch-protection.sh scripts/incept.sh conformance/README.md conformance/audit-evidence-checklist.md
git commit -m "$(printf 'feat(conformance): branch-protection check + incept reminder\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 4: Prod-deploy reference + human-coverage boundary

**Files:** `DEVELOPMENT-STANDARDS.md` (§14 deploy reference), `.claude/README.md`, `docs/enterprise/README.md`

- [ ] **Step 1: Prod-deploy reference** — in `DEVELOPMENT-STANDARDS.md` §14, add a short reference snippet showing a deploy job gated by GitHub `environment: production` with required reviewers (inert reference, like the profile ci.yml pattern):
```yaml
# Reference: production deploy is human-gated by a protected environment.
deploy-prod:
  needs: ci
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  environment: production   # configure required reviewers on this environment in repo settings
  runs-on: ubuntu-latest
  steps:
    - run: echo "promote the verified artifact to production"
```
with a sentence: required reviewers on the `production` environment make the prod promotion human-gated at the platform level (complements §13).

- [ ] **Step 2: Human-coverage boundary** — append to `.claude/README.md` (after Conformance) and to `docs/enterprise/README.md` (in the Org-owned boundary list) the honest statement:
```markdown
**Coverage boundary.** This guard governs the **Claude Code agent runtime only**. A human at a shell, or a different agent runtime, is not covered — production safety also requires platform controls (database IAM, separate production credentials/accounts, deploy approvals). Those are **Org-owned**.
```

- [ ] **Step 3: Verify + commit.**
```bash
sh conformance/check-links.sh ; echo "exit=$?"
git add DEVELOPMENT-STANDARDS.md .claude/README.md docs/enterprise/README.md
git commit -m "$(printf 'docs(standards): env-protected prod-deploy reference + human-coverage boundary\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 5: VERSION, CHANGELOG, ROADMAP

**Files:** `VERSION`, `CHANGELOG.md`, `docs/ROADMAP-KIT.md`

- [ ] **Step 1: VERSION** → `2.13.0`.
- [ ] **Step 2: CHANGELOG** — prepend above `## [2.12.0]`:
```markdown
## [2.13.0] - 2026-06-06

Slice 7a — Environments & production safety. First sub-slice of Slice 7 (adoption/safety hardening).

### Added
- **Dev → QA → UAT → Prod** environment model with gated promotion (production always human-gated) in `DEVELOPMENT-PROCESS.md` + `DEVELOPMENT-STANDARDS.md` §14 + `PROJECT-CLAUDE-TEMPLATE.md` + `RUNBOOK-TEMPLATE.md`.
- `conformance/branch-protection.sh` — verifies `main` is actually protected (PR reviews + status checks) via `gh api`; informational clean-exit where the API isn't reachable. `incept.sh` now hard-reminds branch protection.
- Env-protected reference prod-deploy workflow; explicit **human-coverage boundary** (the guard governs the Claude Code runtime only; humans/other runtimes are Org-owned platform controls).

### Changed
- **`.claude/hooks/guard.sh` is now environment-aware (additive):** expanded destructive coverage (`DROP DATABASE`, Rails/Laravel/Django/Alembic/Flyway/.NET-EF DB-destroy, `pg_restore --clean`, `redis FLUSHALL`, `kubectl delete`, `docker volume rm/prune`, `aws s3 rm --recursive`, cloud SQL/RDS/instance deletes) plus a **prod-context catch-all** (prod kube/helm context, `*_ENV=prod` prefix, `--env production` co-occurring with a destructive/deploy verb). **No existing deny was weakened** — all 35 prior conformance cases pass; new deny + false-positive-allow cases added.

### Note
No new required CI gate (MINOR). Production destructive-action prevention for humans and non-Claude-Code runtimes is Org-owned (platform IAM / account separation / deploy approvals).
```
- [ ] **Step 3: ROADMAP** — add a `7a ✅` row after the `6d ✅` row (or under a new Slice 7 grouping):
```markdown
| 7a ✅ | **Environments & prod safety** *(shipped v2.13.0)* | process env model + standards §14 | Dev/QA/UAT/Prod + env-aware `guard.sh` + `branch-protection.sh` | `agent-autonomy.sh` + `branch-protection.sh` |
```
- [ ] **Step 4: Verify + commit.**
```bash
cat VERSION; grep -n "2.13.0" CHANGELOG.md docs/ROADMAP-KIT.md; sh conformance/check-links.sh; echo $?
git add VERSION CHANGELOG.md docs/ROADMAP-KIT.md
git commit -m "$(printf 'chore(release): 2.13.0 — environments & production safety (7a)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 6: Final 7a validation

**Files:** none (verification only).

- [ ] **Step 1: No-weakening + new coverage.**
```bash
sh conformance/agent-autonomy.sh ; echo "autonomy=$?"   # 0; all prior 35 + new cases pass
echo -n "case count (>=57): "; grep -c "assert_deny\|assert_allow" conformance/agent-autonomy.sh
```
- [ ] **Step 2: Portability.** `for s in .claude/hooks/guard.sh conformance/branch-protection.sh; do dash -n "$s" && echo "$s ok"; done`
- [ ] **Step 3: No regression.**
```bash
sh conformance/check-links.sh; echo "links=$?"
sh conformance/profile-completeness.sh; echo "completeness=$?"
for p in profiles/*/ci.yml; do sh conformance/ci-gates.sh "$p" >/dev/null 2>&1 || echo "FAIL $p"; done; echo "ci-gates checked"
```
- [ ] **Step 4: incept temp run** — branch-protection reminder appears; `inception-done.sh` still passes (python + terraform).
- [ ] **Step 5: Guard spot-checks (manual deny/allow)** for 3 prod catch-all cases + 3 false-positive allows from Task 2 Step 5 (echo JSON into the guard, confirm decision).

Fix-forward on any failure; no commit unless a defect is found.

---

## Self-review (author)
- **No-weakening is enforced** by Task 2 Step 6 + Task 6 Step 1 (all 35 prior cases must still pass).
- **Spec coverage:** env model → T1; guard+conformance → T2; branch-protection+incept → T3; prod-deploy ref + boundary → T4; meta → T5; validation → T6.
- **Portability:** every new script/regex is POSIX `grep -E`; `dash -n` checks in T2/T3/T6.
- **Honesty:** human/other-runtime Org-owned boundary stated (T4); `kubectl delete` blanket-ban (even dev) is intentional per the approved spec.
