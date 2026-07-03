# Deployment-Environment Adoption Bridge

**Date:** 2026-07-02
**Status:** Design — owner-approved in shape (2026-07-02, Option A); spec under owner review.
**Skill loop:** authored via the kit's own `design` skill (zero superpowers).
**Roadmap:** BUILD bucket #1 — the deployment-PLATFORM adoption axis (the last missing concretization axis: stack ✓ / harness ✓ / deploy-target ✗). See `docs/ROADMAP-KIT.md` and the 3-bucket path to 1.0.

---

## 1. Problem / what this adds

The kit makes every adoption axis portable through the **same shape**: the kit owns a neutral **contract**, the adopter brings the **implementation**, delivered as *contract + worked examples + bring-your-own recipe*. This exists for **stack** (`STACK-SELECTION` + `profiles/`), **harness** (`adapters/`), **work-tracking** (`docs/work-tracking/adapters.md`), **CI** (the gate-ID contract in `conformance/ci-gates.sh`), and **version-control host** (`docs/adoption/vc-hosts.md`).

**The deploy-target axis is the one axis missing its recipe.** The kit concretizes *where code is built and reviewed*, but never states — portably — what any **deployment target** must provide for the kit's release discipline to hold. Deployment surface is already rich (`progressive-delivery.md`, `preview-environments.md`, `resilience-verification.md`, `definition-of-deployable.md`, RUNBOOK §4/§5), but it is **stack- and platform-assuming prose**, not a neutral obligations-contract an adopter can map to AWS / Kubernetes / Fly / bare-metal with confidence.

This slice adds that recipe, mirroring `vc-hosts.md` exactly, so the promise holds on every axis: *"we don't want to build for everything, but we want everything to be easily adopted."*

## 2. Owner decisions (ratified 2026-07-02)

- **Option A — recipe doc, answers in the RUNBOOK.** One lean `docs/adoption/DEPLOYMENT-ENVIRONMENT.md` carries the neutral obligations-contract + worked examples + bring-your-own recipe. The adopter records their **answers** in their existing `RUNBOOK.md` §4 (which already covers deploy triggers, K8s/Helm, rollback, smoke, cost caps). **No new template.**
- **Doc-only — no new conformance lock.** Mirrors `vc-hosts.md` (which has none); the enforceable half is already covered by `definition-of-deployable.md` + `progressive-delivery.md`. Adding a lock here would be ceremony and would inflate the check count the self-eval already flagged.
- **One slice.** Recipe doc + RUNBOOK §4 pointer + discoverability wiring for **both** adoption bridges (`vc-hosts` + this), shipped in the same motion.

### Why Option A (recorded, since the memory sketched a "manifest")
- **First principles / coherence:** the sibling `vc-hosts.md` added *no* template — it points at the RUNBOOK. Faithful pattern-mirroring *is* Option A; a bespoke manifest would make this the one snowflake axis. The "manifest" in the memory was a sketch of the *how*; the eval's load-bearing finding was the bridge = *contract + recipe*.
- **Best practice (DRY / twelve-factor / GitOps):** deployment declaration wants a single source of truth. RUNBOOK §4 already is it; a parallel manifest = two places to drift.
- **UX / cold-start:** one recipe to read, one place to answer (where the adopter already writes deploy notes).
- **Right-weight / anti-ceremony + defer-build-ahead:** a first-class template is justified only when a real consumer needs *structured, machine-parseable* deploy fields (e.g., a future conformance check). No such consumer exists → don't build it yet.

## 3. The neutral obligations-contract (the heart — kit owns this)

What **any** deploy target must satisfy for the kit's release discipline to hold. Names are platform-specific; the mechanics are not. Six points, each anchored to the kit surface that already relies on it:

1. **Deployable artifact & provenance** — a single, immutable, addressable unit (image digest / signed bundle) whose provenance is attestable (the SBOM+SLSA supply-chain gate already required in the DoD). *You must be able to name exactly what shipped and prove where it came from.*
2. **Environment promotion path** — ordered tiers (e.g. Dev → QA/UAT → Prod) with prod human-gated, and a declared gate at each boundary (`DEVELOPMENT-PROCESS.md` "Environments & promotion"; `progressive-delivery.md`; `definition-of-deployable.md`).
3. **Config & secrets injection** — env/config/secrets reach the running workload **without being committed**, via the platform's secret store (`secrets-for-ai.md`; the Security non-negotiable "never commit secrets").
4. **Rollback mechanism** — a declared, *tested* path back to the last-good release, named **before** shipping (`DEVELOPMENT-PROCESS.md` §10; RUNBOOK §5; the DoD "rollback path ready").
5. **Post-deploy verification** — a smoke/health check at each promotion boundary that **stops promotion / rolls back on failure** (not just logs) — the executable post-deploy gate (`definition-of-deployable.md`; `progressive-delivery.md` "Smoke / validation gates").
6. **Observability & cost hooks** — where telemetry/SLOs land and how metered/platform spend is capped (`observability-ready.sh`; `cost-governance.md`; the DoD "monitoring/alerting on critical paths").

*If your platform provides these — under whatever names — the kit's release discipline runs unchanged.*

## 4. Worked examples + topology-coverage table (depth + breadth)

Two **depth** examples make the mapping concrete; a **breadth** table shows the contract reaching across every deployment topology and the major clouds — without elevating N platforms to full worked examples (the profile-rot trap). This mirrors `vc-hosts.md`'s two-examples-plus-BYO, and answers "sufficient coverage?" by making coverage *visible*.

### 4a. Depth — two worked examples

- **AWS (ECS/Fargate, ECR)** — artifact = ECR image digest; promotion = per-account/env services + CodeDeploy/manual prod gate; secrets = SSM Parameter Store / Secrets Manager; rollback = redeploy prior task-definition revision; verification = ALB health check + post-deploy smoke; observability = CloudWatch/OTel + Budgets.
- **Kubernetes / Helm** — artifact = image digest in a Helm release; promotion = per-namespace/cluster + gated prod apply; secrets = Kubernetes Secrets / external-secrets operator; rollback = `helm rollback` / re-apply prior digest (`kubectl rollout undo`); verification = liveness/readiness probes + smoke job; observability = Prometheus/OTel + a spend policy.

*(These reuse language already in RUNBOOK §4's "Container / Kubernetes deploy" block — consistency, not duplication.)*

**Honest note on the depth pair:** AWS-ECS and Kubernetes are the *same topology* (orchestrated long-lived containers). They give depth for the market-leading pair, but the breadth table below is what demonstrates the contract also covers serverless, PaaS, and edge — so an adopter on a different shape sees themselves.

### 4b. Breadth — deployment-topology coverage table

Rows = the four genuinely distinct topologies; cells name the canonical service per cloud. A table is documentation (it can't rot the way executable per-platform adapters would):

| Topology | AWS | Azure | GCP | Rollback shape |
|---|---|---|---|---|
| **Orchestrated containers** | ECS/Fargate, EKS | Container Apps, AKS | Cloud Run, GKE | redeploy prior digest / `helm rollback` |
| **Serverless / FaaS** | Lambda | Functions | Cloud Functions | shift alias/version to prior |
| **PaaS / git-push** | App Runner, Elastic Beanstalk | App Service | App Engine | redeploy prior slug/version |
| **Static / edge** | Amplify, CloudFront | Static Web Apps | Firebase Hosting | atomic re-point to prior deploy |

*The six contract points map cleanly across every cell (the neutrality stress-test is in §7). Non-cloud and self-managed targets (Fly, Render, Railway, Nomad, bare-metal) are the bring-your-own recipe in §5.*

## 5. Bring-your-own recipe (Fly / Render / Vercel / Nomad / bare-metal / …)

"Any platform works if you map the six points." For each contract point, the recipe tells the adopter what to find on their platform and the **honest fallback** when the platform can't enforce it:
1. Identify the platform's **immutable artifact** unit; if it only deploys from source, pin the commit/digest.
2. Map the **promotion tiers**; if the platform has one environment, document the compensating manual gate.
3. Point config/secrets at the platform's **secret store**; never commit — if it lacks one, record a waived control + compensating process (`templates/WAIVER-REGISTER.md`).
4. Declare + **test** the rollback path; if immutable-redeploy isn't available, document the forward-fix procedure and its RTO.
5. Wire a **post-deploy smoke** that gates the boundary.
6. Point telemetry + a spend cap at the platform's equivalents; record in RUNBOOK §4/§9.

## 6. Discoverability wiring (index BOTH bridges in the same motion)

- **RUNBOOK-TEMPLATE.md §4** — a lightweight pointer: *"Map your platform to the deploy-target contract — see `docs/adoption/DEPLOYMENT-ENVIRONMENT.md`; record your answers below."* (Answers stay here; the contract stays discoverable in `docs/adoption/`.)
- **`CLAUDE.md` docs table** — the `docs/` (other) row currently names `work-tracking/adapters.md` and `adoption/brownfield.md`; add both `adoption/vc-hosts.md` and `adoption/DEPLOYMENT-ENVIRONMENT.md` so the adoption-bridge family is visible in one place. *(Fixes a latent gap: `vc-hosts.md` shipped in #243 but isn't indexed in the CLAUDE.md table.)*
- **`START-HERE.md` / Inception** — surface the deploy-target recipe alongside stack + host selection so a cold adopter meets it at the right moment (verify current wording at build-time; add a one-line pointer, don't restructure Inception).

## 7. Honest ceiling

- The kit provides the **contract** and this **recipe**; actually provisioning and configuring the platform is the **adopter's** work. A green kit run is *necessary, not sufficient* for a correctly configured deploy target — identical to `vc-hosts.md`'s ceiling.
- **No new machine-checkable proof** is added by this slice (it's a recipe doc). The enforceable deploy obligations remain proven where they already are: `definition-of-deployable.md` (post-deploy gate) and the DoD's supply-chain/rollback/observability items. This doc makes those obligations *portable and discoverable*, it does not re-prove them.

### Neutrality stress-test (why the contract is platform-neutral, not AWS/K8s-shaped)

Each contract point is stated as a **capability, not a mechanism** ("an immutable, addressable, attestable unit" — not "an ECR image"), so it maps across clouds and topologies. Verified per-point:

| Contract point | Azure | GCP | Serverless (FaaS) | PaaS / git-push | Static / edge |
|---|---|---|---|---|---|
| **1 Artifact & provenance** | ACR image digest | Artifact Registry digest | versioned function + alias | build slug (pin commit) | immutable deploy ID |
| **2 Promotion path** | deployment slots | projects / env | stages + aliases | pipelines (or 1-env + manual gate) | preview → prod promote |
| **3 Config & secrets** | Key Vault | Secret Manager | platform secret store | config vars | env bindings |
| **4 Rollback** | slot swap | Cloud Run traffic-split rollback | shift alias to prior version | redeploy prior slug | atomic re-point |
| **5 Post-deploy verify** | health probe + smoke | health check + smoke | canary alias + smoke | release health check | edge smoke |
| **6 Observability & cost** | Azure Monitor + Cost Mgmt | Cloud Monitoring + Budgets | provider metrics + budget | platform metrics + cap | analytics + budget |

Every cell maps — the neutrality is demonstrated, not asserted. **Ceiling:** worked examples can never be exhaustive; the contract + the §4b topology table + the §5 bring-your-own recipe are the bridge, and a platform the adopter maps themselves is as first-class as a worked one.

## 8. Kit design-discipline check (from `skills/design`)

- **Right-weight / anti-ceremony:** extends an existing pattern (a fourth sibling in `docs/adoption/`) + a RUNBOOK pointer + index rows; adds **no** template, **no** conformance script, **no** new claim. Leanest shape that keeps axis symmetry.
- **Design-intent lens (default-KEEP):** nothing cut; the slice is purely additive discoverability + a missing recipe.
- **Is the provable thing the meaningful thing?** The meaningful thing here is *adoptability*, which is a documentation/coherence property, not a runtime one — so a doc recipe (not a tautological conformance lock) is the honest artifact. Adding a lock to manufacture a "proof" would prove an easier adjacent thing (that a phrase exists), not the real value. Correctly doc-only.
- **Honest ceiling:** stated (§7), matching `vc-hosts.md`.
- **Portability:** the whole point — platform-neutral contract, adopter brings the platform.
- **Coherence:** reconciles a real drift (unindexed `vc-hosts.md`) while adding the sibling.

## 9. Build scope (what ships — for the `plan` skill)

1. `docs/adoption/DEPLOYMENT-ENVIRONMENT.md` — the recipe: §3 contract + §4a AWS/K8s depth examples + §4b topology-coverage table (AWS/Azure/GCP × 4 topologies) + §5 bring-your-own + §7 honest ceiling incl. the neutrality stress-test. (New doc; **not** control-plane → GREEN.)
2. `templates/RUNBOOK-TEMPLATE.md` §4 — add the one-line pointer beside the existing deploy content.
3. `CLAUDE.md` docs table — add `adoption/vc-hosts.md` + `adoption/DEPLOYMENT-ENVIRONMENT.md` rows.
4. `START-HERE.md` — a one-line pointer to the deploy-target recipe at the right Inception moment (verify wording at build-time).
5. Version finishing folded into the apply/finishing step (doc-only minor → **3.95.0**), README/CHANGELOG/ROADMAP-KIT.md updated (ROADMAP: mark BUILD #1 deploy-platform axis DONE).

**Control-plane note (verified against `.claude/hooks/guard-core.sh:13-53`):** of the touched files, **only `CLAUDE.md` is control-plane (AMBER)** — its edit is guard-blocked to agent Write/Edit and must be routed through `apply.py`. Everything else is **GREEN** (agent writes directly): `docs/adoption/DEPLOYMENT-ENVIRONMENT.md`, `templates/RUNBOOK-TEMPLATE.md`, `START-HERE.md`, `VERSION`, `README.md`, `CHANGELOG.md`, `docs/ROADMAP-KIT.md`. So this is a **hybrid slice**: GREEN docs on the branch + a minimal `apply.py` carrying only the CLAUDE.md docs-table edit and the version finishing. Check the core-3 doc-budget when the CLAUDE.md row grows (Slice A compacted CLAUDE.md to ≤120 lines; the edit adds two short table entries to one existing row — confirm it stays ≤120).

## 10. Out of scope (defer-build-ahead)

- A structured `DEPLOYMENT-ENVIRONMENT` **template/manifest** — build only when a real consumer needs machine-parseable deploy fields (Option B; no consumer today).
- A **conformance lock** for this axis — build only if the recipe develops a checkable invariant beyond what `definition-of-deployable.md` already gates.
- **Per-platform adapters** (an AWS profile, a K8s profile) — the profile-rot trap; the recipe + two worked examples are the adoption bridge, not N adapters.

## Terminal state
A committed, owner-approved spec, handed to the **plan** skill. This design does not start implementation.
