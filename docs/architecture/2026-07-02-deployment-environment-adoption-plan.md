# Plan — Deployment-Environment Adoption Bridge

**Date:** 2026-07-02
**Design:** `docs/architecture/2026-07-02-deployment-environment-adoption-design.md` (owner-approved, Option A).
**Skill loop:** authored via the kit's own `plan` skill (zero superpowers).

## Goal
Ship the deploy-target adoption bridge — a neutral obligations-contract + worked examples + bring-your-own recipe — so the last missing concretization axis (deploy-target) is as adoptable as stack, harness, tracker, CI, and VC-host.

## Architecture
One new recipe doc `docs/adoption/DEPLOYMENT-ENVIRONMENT.md` mirroring `vc-hosts.md` (contract + AWS/K8s depth + AWS/Azure/GCP × 4-topology breadth table + BYO + honest ceiling). Adopter answers live in RUNBOOK §4 (a pointer added). Discoverability wiring indexes **both** adoption bridges (`vc-hosts` + this) in the CLAUDE.md docs table (a real drift fix — `vc-hosts` is currently indexed 0×) and adds a START-HERE pointer.

## Tech Stack
Markdown docs only. No code, no new conformance check, no new claim. Verification tools: `conformance/check-links.sh`, `conformance/verify.sh --require`.

## Global Constraints (verbatim from the spec)
- **Doc-only — no new conformance lock, no template, no per-platform adapters** (defer-build-ahead; the enforceable half is already gated by `definition-of-deployable.md`).
- **The contract is stated as capability, not mechanism** ("an immutable, addressable, attestable unit" — not "an ECR image"), so it stays platform-neutral.
- **Honest ceiling:** the kit provides the contract + recipe; configuring the platform is the adopter's; a green kit run is necessary, not sufficient.
- **CLAUDE.md must stay ≤120 lines** (Slice A compacted it to 118); the index edit extends the existing `docs/` row inline (adds no new line).

## Build model — HYBRID (GREEN docs on-branch + one AMBER apply.py)
Verified against `.claude/hooks/guard-core.sh:13-53`:
- **GREEN** (agent writes directly, normal branch commits): `docs/adoption/DEPLOYMENT-ENVIRONMENT.md`, `templates/RUNBOOK-TEMPLATE.md`, `START-HERE.md`, `VERSION`, `README.md`, `CHANGELOG.md`, `docs/ROADMAP-KIT.md`.
- **AMBER** (guard-blocked → routed through `apply.py`, human-applied): `CLAUDE.md` only.
- Per `[[release-finishing-in-apply-py]]`, the version finishing (VERSION/README/CHANGELOG/ROADMAP) is folded INTO the same `apply.py` even though those files are GREEN, so the bump can't be skipped.

## File structure (every file, single responsibility)
| File | Change | Plane | Responsibility |
|---|---|---|---|
| `docs/adoption/DEPLOYMENT-ENVIRONMENT.md` | NEW | GREEN | The recipe: contract + depth + breadth table + BYO + ceiling |
| `templates/RUNBOOK-TEMPLATE.md` | MODIFY §4 | GREEN | One pointer bullet → the recipe; answers live here |
| `START-HERE.md` | MODIFY §4 setup | GREEN | One pointer line at the CI/deploy setup step |
| `CLAUDE.md` | MODIFY line 22 | AMBER | Index both adoption bridges in the `docs/` row |
| `VERSION` / `README.md` / `CHANGELOG.md` / `docs/ROADMAP-KIT.md` | MODIFY | GREEN (folded in apply.py) | Version finishing → 3.95.0; ROADMAP marks BUILD #1 done |

---

## Task 1 — Write the recipe doc *(GREEN · parallel-safe with Task 2 · disjoint files)*

**Deliverable:** `docs/adoption/DEPLOYMENT-ENVIRONMENT.md` containing, in order:
1. **Intro** — host-neutral framing mirroring `vc-hosts.md:1-4`: "The kit's deploy discipline is platform-neutral. AWS and Kubernetes are worked examples; any platform works if it maps the contract below. The kit owns the *contract*, you bring the *platform*."
2. **The contract** — the six points from design §3, each stated as a *capability* + the kit surface it ties to:
   1. Deployable artifact & provenance (SBOM+SLSA gate)
   2. Environment promotion path (`progressive-delivery.md`, `definition-of-deployable.md`)
   3. Config & secrets injection (`secrets-for-ai.md`)
   4. Rollback mechanism (DEVELOPMENT-PROCESS §10, RUNBOOK §5)
   5. Post-deploy verification (`definition-of-deployable.md`)
   6. Observability & cost hooks (`cost-governance.md`, `observability-ready.sh`)
3. **AWS (worked)** and **Kubernetes/Helm (worked)** — the two depth mappings from design §4a (reuse RUNBOOK §4 K8s language).
4. **Honest note** that both depth examples are the same topology (orchestrated containers) → the breadth table follows.
5. **Topology-coverage table** — design §4b verbatim (Orchestrated / Serverless / PaaS / Static-edge × AWS/Azure/GCP + rollback shape).
6. **Bring your own** — design §5's six-point mapping recipe with honest fallbacks (waiver register for un-enforceable points).
7. **Honest ceiling** — design §7 + the neutrality stress-test table.

**Steps (TDD-for-docs — the test is link-resolution + a coverage checklist):**
1. Author the doc with the seven sections above, using **exact** relative links to the referenced kit files (verify each path exists: `progressive-delivery.md`, `definition-of-deployable.md`, `secrets-for-ai.md`, `cost-governance.md`, `templates/WAIVER-REGISTER.md`).
2. Run `sh conformance/check-links.sh` → **expect PASS** (no broken/orphaned links; the doc's outbound links resolve). If it reports the doc as orphaned, that's expected until Tasks 2-3 link to it — re-run after the branch is assembled.
3. Coverage self-check (a written checklist in the review, not in the doc): all 6 contract points present · both depth examples present · topology table has 4 rows × 3 clouds · BYO covers all 6 points · ceiling + stress-test present.
4. Commit: `docs(adoption): deploy-target contract + recipe (DEPLOYMENT-ENVIRONMENT)`.

**Honest ceiling (this task):** proves the recipe *exists and its links resolve*, not that any platform is correctly configured (that's the adopter's, stated in the doc).

---

## Task 2 — Discoverability pointers in RUNBOOK + START-HERE *(GREEN · parallel-safe with Task 1)*

**Deliverable:** two one-line pointers; no restructuring.

**Steps:**
1. `templates/RUNBOOK-TEMPLATE.md` — insert as the **first bullet** under `## 4. Deploy` (before the `Target:` line at :28):
   `- **Deploy-target contract:** map your platform to the six-point deploy contract — see `docs/adoption/DEPLOYMENT-ENVIRONMENT.md`; record your answers in this section.`
2. `START-HERE.md` — at the CI/deploy setup step (§4, near :97 "Stand up … CI pipeline"), append a one-line pointer:
   `Choosing a deploy target? Map it to the contract first — see `docs/adoption/DEPLOYMENT-ENVIRONMENT.md`.`
   (Engineer confirms the exact anchor line in the live file; add a pointer, do not restructure the step.)
3. Run `sh conformance/check-links.sh` → **expect PASS** (both new links resolve to the Task-1 doc).
4. Commit: `docs: surface the deploy-target recipe in RUNBOOK §4 + START-HERE`.

**Honest ceiling:** proves the recipe is *reachable* from the adopter's front door + project template.

---

## Task 3 — AMBER apply.py: index both bridges in CLAUDE.md + version finishing *(serialize LAST)*

**Deliverable:** `scratchpad/deploy-env/apply.py` (idempotent, clone-proven) that a human runs. It carries the one AMBER edit + the version finishing.

**apply.py payload:**
1. **`CLAUDE.md` line 22** — extend the existing `docs/` (other) table cell to index both adoption bridges. Insert after `` `adoption/brownfield.md` (…)`` :
   `` `adoption/vc-hosts.md` (bring-your-own git host), `adoption/DEPLOYMENT-ENVIRONMENT.md` (bring-your-own deploy target), `` — **one line edited, no line added** (keeps CLAUDE.md at 118 ≤120).
2. **`VERSION`** → `3.95.0`.
3. **`README.md`** — version badge/reference bump to 3.95.0 (match the existing pattern; grep `3.94.0` → replace the badge occurrence).
4. **`CHANGELOG.md`** — new entry with the exact heading format `## [3.95.0] - 2026-07-02` (matches `CHANGELOG.md:9`), body: "Deploy-target adoption bridge — neutral obligations-contract + AWS/K8s worked examples + AWS/Azure/GCP topology-coverage table + bring-your-own recipe (`docs/adoption/DEPLOYMENT-ENVIRONMENT.md`); indexed both adoption bridges in CLAUDE.md."
5. **`docs/ROADMAP-KIT.md`** — mark BUILD bucket #1 (deployment-platform axis, `:16`) DONE **and reconcile its wording**: it currently says "adopter-filled `DEPLOYMENT-ENVIRONMENT` manifest" — the Option-A decision rejected a manifest, so change to "a neutral obligations-contract recipe (`docs/adoption/DEPLOYMENT-ENVIRONMENT.md`); adopter answers live in RUNBOOK §4." (Also reconcile the identical "manifest" phrasing at `:66`.)

**Idempotency:** each edit is sentinel-guarded (skip if the target string already present); use a **per-file in-memory buffer** for CLAUDE.md/README if >1 edit lands on one file (`[[MAINTAINING §3a]]` per-file-buffer practice); anchors fail loudly if not found.

**Steps:**
1. Author `apply.py` under `scratchpad/deploy-env/` (guard-safe path).
2. Clone-prove: `git clone . /tmp/deploy-env-clone`, `cd` into it, run `python3 …/apply.py` **twice** → expect first run applies all 5, **second run is a full no-op** (idempotent). Assert CLAUDE.md is still ≤120 lines in the clone.
3. In the clone, run `sh conformance/verify.sh --require` → **expect RESULT OK** (doc-budget green, no regression, 41 control · 16 doc · 0 failed unchanged — no new claim).
4. Hand `apply.py` to the human to run on the real tree; the human commits the applied diff (CLAUDE.md is control-plane → agent must not self-commit it) and tags after merge.

**Honest ceiling:** proves the index edit + version finishing apply cleanly and idempotently and keep `verify --require` green; the human owns the control-plane apply + the GO.

---

## Parallel-safety map
- **Task 1 ⟂ Task 2** — disjoint files (`docs/adoption/…` vs `templates/…`+`START-HERE.md`), independently testable → **may fan out.**
- **Task 3 serializes last** — it references the Task-1 doc path and does the version finishing over the assembled branch; run after 1+2 land.

## Dual review (builder ≠ sole reviewer)
- **Reviewer (independent):** whole-branch review — contract neutrality (no leaked AWS/K8s assumption in a "neutral" point), link resolution, coherence-fix correctness (both bridges now indexed), CLAUDE.md ≤120, no accidental control-plane edit outside apply.py, version coherence.
- **Security-Reviewer:** **N/A — reason:** doc-only slice, no guard/CI/auth/secret/data/trust boundary touched, no new executable surface. (Recorded per the DoD's conditional-gate "N/A-with-reason".)

## Spec-coverage check (every design requirement → a task)
- §3 contract → Task 1.2 · §4a depth → Task 1.3 · §4b topology table → Task 1.5 · §5 BYO → Task 1.6 · §6 discoverability (RUNBOOK/START-HERE) → Task 2 · §6 CLAUDE.md index (both bridges) → Task 3.1 · §7 ceiling+stress-test → Task 1.7 · §9 version finishing → Task 3.2-5. All covered.

## Terminal state
A self-reviewed plan handed to the **build** skill (fresh agent per task, dual-review gate). This skill does not start implementation.
