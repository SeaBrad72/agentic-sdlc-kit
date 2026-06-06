# Slice 6d: Audit-Evidence Checklist (capstone) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The finale — `conformance/audit-evidence-checklist.md`, a checklist-type conformance check that points, per control, to **where the evidence lives in a kit-built repo** (CI logs, SBOM, PR approvals, the executable `conformance/*.sh`, the §6c governed-exception records, the §6b managed-secret config). Ties back to the 6a crosswalk; completes the enterprise addendum and the kit roadmap.

**Architecture:** Documentation/checklist only — no code, no gate. Mirrors `conformance/15-factor-checklist.md` (checklist-type, copied into a project/review record). Rows backed by an executable check are **Auto** (with the command); the rest are **Manual** attestation. Completeness tie-off: every 6a crosswalk control has an evidence row here.

**Tech Stack:** Markdown · `conformance/check-links.sh`.

**Design source:** `docs/superpowers/specs/2026-06-06-slice6-enterprise-umbrella-design.md` §4d.

**Versioning:** VERSION → `2.12.0` (the 6d MINOR; the kit's MAINTAINING reserves MAJOR for a new required gate, which this is not). A `v3.0.0` **milestone tag** marking "enterprise addendum complete" is applied to main **after merge** (out of this plan's file scope).

---

## Task 1: `conformance/audit-evidence-checklist.md` (the capstone)

**Files:**
- Create: `conformance/audit-evidence-checklist.md`

- [ ] **Step 1: Write the file** with exactly this content:

```markdown
# Conformance Check — Audit Evidence

Proves that a repo built with this kit can produce the **evidence** an auditor expects for the controls mapped in [`../docs/enterprise/compliance-crosswalk.md`](../docs/enterprise/compliance-crosswalk.md). **Checklist-type**, run at the **Review gate** / before an audit (`../DEVELOPMENT-PROCESS.md` §7). The capstone of the enterprise addendum (`../docs/enterprise/README.md`).

## How to use

Copy this file into your project (or your audit/review record). For each control, fill **Present?** (`Y` / `N` / `N/A + reason`) and point **Evidence** at the concrete artifact. For **Auto** rows, run the named command and attach its output. A reviewer (Security Owner for governing controls — see [`../docs/enterprise/ratification-rbac.md`](../docs/enterprise/ratification-rbac.md)) signs off only when every applicable control has evidence **or** a governed, time-boxed exception on record. A waived control cites its exception ID; nothing is silently skipped.

## Security & engineering controls

| Control | Crosswalk ref | Evidence artifact (where) | Check | Present? |
|---------|---------------|---------------------------|-------|----------|
| Lint / type-check / test + coverage | CC8.1 / A.8.28–29 | CI gate run logs (gates 1–3) | **Auto:** `sh conformance/ci-gates.sh .github/workflows/ci.yml` | |
| Reproducible build | CC8.1 / A.8.25 | build CI log / artifact (gate-build) | **Auto:** `sh conformance/ci-gates.sh .github/workflows/ci.yml` | |
| Secret scanning | CC6.1 / A.8.28 | secret-scan CI log (gate-secret-scan) | **Auto:** `sh conformance/ci-gates.sh …` | |
| Dependency vulnerability scan | CC7.1 / A.8.8 | dep-scan CI log (gate-dep-scan) | **Auto:** `sh conformance/ci-gates.sh …` | |
| SBOM + build provenance | CC7.1, CC9.2 / A.8.8, A.5.21 | SBOM file + attestation (gate-sbom / gate-provenance) | **Auto:** `sh conformance/ci-gates.sh …` + the SBOM artifact | |
| Least-privilege OIDC in CI | CC6.1, CC6.3 / A.8.2 | the workflow's push-only `provenance` job (no workflow-level `id-token`) | Manual (review the workflow) | |
| Branch protection · builder ≠ sole merger | CC8.1, CC6.1 / A.8.32, A.8.4 | branch-protection settings + PR approval records | Manual (GitHub settings + PR history) | |
| Agent autonomy · human gates for irreversible actions | CC6.1, CC6.3 / A.8.2 | guard hook denies the gated set | **Auto:** `sh conformance/agent-autonomy.sh` | |
| Inception completed (project resumable cold) | — | the Inception gate passes | **Auto:** `sh conformance/inception-done.sh` | |
| Profile completeness (chosen stack) | — | the profile fills all sections; companion CI conformant | **Auto:** `sh conformance/profile-completeness.sh` | |
| Docs link integrity | A.5.x (documentation) | all relative links resolve | **Auto:** `sh conformance/check-links.sh` | |
| 15-factor architecture (services) | CC8.1 / A.8.9 | the completed checklist | **Auto/Checklist:** `conformance/15-factor-checklist.md` | |
| Immutable audit logging | CC7.2, CC7.3 / A.8.15, A.8.16 | audit log stream (who/what/when/resource) | Manual | |
| Secrets management & secrets-at-scale | CC6.1 / A.8.24 | `.env.example` + managed-store config (→ `../docs/enterprise/secrets-at-scale.md`) | Manual | |
| Input validation / injection prevention | CC6.1, CC6.6 / A.8.28, A.8.26 | schema-validation code + tests | Manual | |
| Authentication & authorization | CC6.1–6.3 / A.8.5, A.5.15 | auth code/config | Manual | |
| Encryption at rest & in transit | CC6.1, CC6.7 / A.8.24 | infra/config | Manual | |
| Observability / monitoring | CC7.2 / A.8.15, A.8.16 | dashboards, alerts | Manual | |
| Architecture decisions recorded | CC1.2, CC3.1 / A.5.4 | `docs/ADR-*` files | Manual (files present) | |
| RUNBOOK · DR / rollback | CC7.4, CC7.5 / A.5.29, A.8.13 | RUNBOOK | Manual (file present) | |
| Cost governance · rate-limiting | CC7.1 / A.8.6 | config, budget alerts | Manual | |
| Personnel / physical / vendor controls | CC1.4, CC6.4, CC9.2 / A.6, A.7, A.5.19–22 | org programs (outside the kit) | Manual — **Org-owned** | |

## Privacy & data-protection controls

Mark **N/A (no personal data)** for projects that handle none. Most are **Org-owned** — the kit assists; the program is the org's (see [`../docs/enterprise/compliance-crosswalk.md`](../docs/enterprise/compliance-crosswalk.md) privacy family and the [responsibility boundary](../docs/enterprise/README.md)).

| Control | Crosswalk ref | Evidence artifact (where) | Check | Present? |
|---------|---------------|---------------------------|-------|----------|
| Notice / privacy communication | P1.0 / A.5.34 | privacy notice | Manual — Org-owned | |
| Choice & consent (incl. age-gating) | P2.0 / A.5.34 | consent records / age-gate | Manual — Org-owned | |
| Collection limitation | P3.0 / A.5.34 | data inventory + boundary validation | Manual | |
| Use, retention & disposal | P4.0 / A.8.10, A.5.34 | retention policy + deletion path | Manual | |
| Data-subject access | P5.0 / A.5.34 | DSAR process | Manual — Org-owned | |
| Right to erasure | P4.0 / A.8.10 | erasure process + code path | Manual | |
| Disclosure & third-party/affiliate sharing | P6.0 / A.5.34, A.5.19 | data-sharing agreements | Manual — Org-owned | |
| PII redaction in logs | P4.0, P8.0 / A.8.15 | log config | Manual | |
| Privacy monitoring & enforcement | P8.0 / A.8.16, A.5.34 | audit log + reviews | Manual | |

## Governed exceptions

Any waived control above must cite a **governed exception** (`../docs/enterprise/ratification-rbac.md`): a Security-Owner-ratified, time-boxed record (what / why / expiry / compensating control). List active exception IDs here at review time. An expired exception means the control is back in force.

| Exception ID | Control waived | Ratified by (Security Owner) | Expires | Compensating control |
|--------------|----------------|------------------------------|---------|----------------------|
| | | | | |
```

- [ ] **Step 2: Verify.**
```bash
sh conformance/check-links.sh ; echo "exit=$?"   # exit=0 — the ../docs/enterprise/* links resolve
ls conformance/audit-evidence-checklist.md
```

- [ ] **Step 3: Commit.**
```bash
git add conformance/audit-evidence-checklist.md
git commit -m "$(printf 'conformance: audit-evidence checklist — the enterprise capstone (6d)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 2: Wiring — live links + conformance index

**Files:**
- Modify: `docs/enterprise/README.md`, `docs/enterprise/secrets-at-scale.md`, `docs/enterprise/ratification-rbac.md`, `conformance/README.md`

- [ ] **Step 1: `docs/enterprise/README.md`** — make the Contents row a live link:
Change:
```markdown
| conformance/audit-evidence-checklist.md *(Slice 6d)* | Per-control evidence checklist for an audit. |
```
to:
```markdown
| [audit-evidence-checklist.md](../../conformance/audit-evidence-checklist.md) | Per-control evidence checklist for an audit. |
```

- [ ] **Step 2: `docs/enterprise/secrets-at-scale.md`** — make the back-reference live. Change the plain-text `audit-evidence-checklist.md` (in the Break-glass paragraph) so it reads:
```markdown
This is itself an auditable control (ties to [audit-evidence-checklist.md](../../conformance/audit-evidence-checklist.md), Slice 6d).
```

- [ ] **Step 3: `docs/enterprise/ratification-rbac.md`** — make the back-reference live. Change the plain-text `conformance/audit-evidence-checklist.md` (Governed-exceptions paragraph) so it reads:
```markdown
An expired exception that hasn't been renewed means the requirement is back in force. Exceptions are evidence (see [audit-evidence-checklist.md](../../conformance/audit-evidence-checklist.md), Slice 6d).
```

- [ ] **Step 4: `conformance/README.md`** — add the new check to the Index table (after the `profile-completeness.sh` row):
```markdown
| `audit-evidence-checklist.md` | checklist | enterprise addendum (`../docs/enterprise/`) — per-control audit evidence | Review / pre-audit |
```
And update the trailing note from:
```markdown
> Future slices add: enterprise addendum checks (compliance/audit-evidence). See `../docs/ROADMAP-KIT.md`.
```
to:
```markdown
> The enterprise addendum (`../docs/enterprise/`) adds the compliance crosswalk and this audit-evidence checklist.
```

- [ ] **Step 5: Verify.**
```bash
sh conformance/check-links.sh ; echo "exit=$?"   # exit=0 (all four edits keep links resolving)
grep -c "audit-evidence-checklist.md" docs/enterprise/README.md docs/enterprise/secrets-at-scale.md docs/enterprise/ratification-rbac.md conformance/README.md
```
Expected: exit=0; each file shows ≥1.

- [ ] **Step 6: Commit.**
```bash
git add docs/enterprise/README.md docs/enterprise/secrets-at-scale.md docs/enterprise/ratification-rbac.md conformance/README.md
git commit -m "$(printf 'docs(enterprise): wire audit-evidence capstone into README, back-refs, conformance index (6d)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: VERSION, CHANGELOG, ROADMAP (completes the roadmap)

**Files:**
- Modify: `VERSION`, `CHANGELOG.md`, `docs/ROADMAP-KIT.md`

- [ ] **Step 1: VERSION** → exactly:
```
2.12.0
```

- [ ] **Step 2: CHANGELOG** — insert above `## [2.11.0] - 2026-06-06`:
```markdown
## [2.12.0] - 2026-06-06

Slice 6d — Enterprise addendum, pillar 4 (capstone): the audit-evidence checklist. **Completes the enterprise addendum and the kit roadmap.** Tagged `v3.0.0` as the "enterprise layer complete" milestone (a marker, not a semver-major — no new required gate; the kit's contract version is 2.12.0, per `MAINTAINING.md`).

### Added
- `conformance/audit-evidence-checklist.md` — checklist-type conformance check mapping every control in the compliance crosswalk to **where its evidence lives** in a kit-built repo (CI gate logs, SBOM + provenance, PR approvals, the executable `conformance/*.sh`, the §6b managed-secret config, the §6c governed-exception records). Auto rows name the runnable check; Manual rows are attestation; waived controls cite a governed exception.
- Wired into `docs/enterprise/README.md`, the 6b/6c back-references, and the `conformance/README.md` index.

### Note
Documentation/checklist only — no new gate, no code. Completeness tie-off: every crosswalk control has an evidence row. With this, the enterprise addendum (6a crosswalk · 6b secrets-at-scale · 6c ratification RBAC · 6d audit evidence) is complete.
```

- [ ] **Step 3: ROADMAP** — insert after the `6c ✅` row:
```markdown
| 6d ✅ | **Audit-evidence capstone** *(shipped v2.12.0; `v3.0.0` milestone)* | umbrella §4d | `conformance/audit-evidence-checklist.md` — per-control evidence, ties to 6a | `check-links.sh` + the checklist itself |
```
Then update the `| 6 |` (or `| 6 🔄 |`) Enterprise-addendum row to mark it shipped: change its order cell to `| 6 ✅ |` and its reference cell to note `enterprise addendum complete (6a–6d), v3.0.0 milestone`. If the row's structure makes that ambiguous, leave it and rely on the 6a–6d rows.

- [ ] **Step 4: Verify.**
```bash
cat VERSION   # 2.12.0
grep -n "2.12.0\|v3.0.0" CHANGELOG.md docs/ROADMAP-KIT.md
sh conformance/check-links.sh ; echo "links exit=$?"
```

- [ ] **Step 5: Commit.**
```bash
git add VERSION CHANGELOG.md docs/ROADMAP-KIT.md
git commit -m "$(printf 'chore(release): 2.12.0 — enterprise addendum complete (6d capstone); v3.0.0 milestone\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 4: Final validation (whole-slice + Slice-6 tie-off)

**Files:** none (verification only; fix-forward if needed).

- [ ] **Step 1: Links + structure.**
```bash
sh conformance/check-links.sh ; echo "links exit=$?"
ls -1 docs/enterprise/ conformance/audit-evidence-checklist.md
```
Expected: links exit=0; all four enterprise docs + the checklist present.

- [ ] **Step 2: Completeness tie-off — every 6a crosswalk control has an evidence row.**
Read `docs/enterprise/compliance-crosswalk.md` and `conformance/audit-evidence-checklist.md`. Confirm each crosswalk control (security table + privacy family) has a corresponding row in the audit-evidence checklist (by control name). List any crosswalk control missing an evidence row — there should be none.

- [ ] **Step 3: Auto rows name real checks.**
```bash
for s in ci-gates agent-autonomy inception-done profile-completeness check-links; do grep -q "conformance/$s.sh" conformance/audit-evidence-checklist.md && echo "$s referenced" || echo "$s NOT referenced (ok if intentionally manual)"; done
```
Every `conformance/*.sh` named in an Auto row must exist (they all do).

- [ ] **Step 4: No regression across the whole kit.**
```bash
sh conformance/agent-autonomy.sh >/dev/null 2>&1; echo "agent-autonomy exit=$?"
sh conformance/profile-completeness.sh >/dev/null 2>&1; echo "profile-completeness exit=$?"
sh conformance/inception-done.sh >/dev/null 2>&1; echo "inception-done exit=$? (may need bootstrap; informational)"
for p in profiles/*/ci.yml; do sh conformance/ci-gates.sh "$p" >/dev/null 2>&1 || echo "FAIL $p"; done; echo "ci-gates checked"
cat VERSION   # 2.12.0
```
Expected: agent-autonomy + profile-completeness exit=0; no ci-gates FAIL.

No commit unless a defect is found; fix-forward and re-run.

---

## Post-merge (out of this plan's file scope — controller action after the user merges)

- Apply an annotated milestone tag to the squash-merge commit on `main`:
  `git tag -a v3.0.0 -m "Milestone: enterprise addendum complete (6a–6d). Kit contract version 2.12.0; v3.0.0 marks the enterprise-layer-complete milestone, not a semver-major (no new required gate — see MAINTAINING.md)." && git push origin v3.0.0`

---

## Self-review (author)

- **Spec coverage (umbrella §4d):** checklist (controls → evidence, Auto/Manual, exceptions) → Task 1; wiring (README live link + 6b/6c back-refs + conformance index) → Task 2; version/changelog/roadmap + roadmap-complete → Task 3; validation incl. the crosswalk↔checklist tie-off → Task 4.
- **Capstone references resolve:** every Auto row names an existing `conformance/*.sh`; the checklist links to the 6a crosswalk + 6c RBAC + 6b secrets docs (all on main / created earlier this slice).
- **3.0.0 handled honestly:** VERSION=2.12.0 (no false MAJOR); v3.0.0 is a documented milestone tag applied post-merge.
- **No placeholders:** full checklist content inline; the exception table ships with a blank row for adopters (intentional — it's a fill-in checklist).
