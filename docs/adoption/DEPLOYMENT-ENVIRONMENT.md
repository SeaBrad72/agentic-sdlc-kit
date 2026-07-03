# Deployment-Environment Adapter Guide

The kit's release discipline is **platform-neutral**. AWS and Kubernetes are worked examples; **any deploy target works if it maps the contract below.** This mirrors `vc-hosts.md` (version-control hosts) and `docs/work-tracking/adapters.md` (trackers) for the deploy-target axis — the kit owns the *contract*, you bring the *platform*.

## The contract every deploy target must satisfy

The kit needs six things from wherever your software runs. Each is stated as a **capability, not a mechanism** — the *names* differ per platform, the *obligations* don't:

1. **Deployable artifact & provenance** — a single, immutable, addressable unit (an image digest, a signed bundle) whose provenance is attestable. You must be able to name exactly what shipped and prove where it came from (the SBOM + provenance gate in the Definition of Done).
2. **Environment promotion path** — ordered tiers (e.g. Dev → QA/UAT → Prod) with **prod human-gated**, and a declared gate at each boundary. See `docs/operations/progressive-delivery.md` and the Release gate `conformance/definition-of-deployable.md`.
3. **Config & secrets injection** — env/config/secrets reach the running workload from a secret store, **never committed**. See `docs/operations/secrets-for-ai.md` and the Security rule "never commit secrets".
4. **Rollback mechanism** — a declared, *tested* path back to the last-good release, named **before** you ship (`DEVELOPMENT-PROCESS.md` §10; RUNBOOK §5).
5. **Post-deploy verification** — a smoke/health check at each promotion boundary that **stops promotion / rolls back on failure** — it gates, it does not merely log (`conformance/definition-of-deployable.md`; `docs/operations/progressive-delivery.md`).
6. **Observability & cost hooks** — where telemetry/SLOs land and how metered/platform spend is capped (`docs/operations/cost-governance.md`; verified by `conformance/observability-ready.sh`).

If your platform provides these — under whatever names — the kit's release discipline runs unchanged.

## AWS *(worked)*

- **Artifact:** ECR image digest. **Promotion:** per-account / per-environment services; CodeDeploy or a manual prod approval gate.
- **Secrets:** SSM Parameter Store / Secrets Manager (injected at task start, never baked into the image). **Rollback:** redeploy the prior task-definition revision.
- **Verify:** ALB/target-group health check + a post-deploy smoke. **Observe:** CloudWatch / OTel + AWS Budgets for the spend cap.

## Kubernetes / Helm *(worked)*

- **Artifact:** image digest pinned in a Helm release. **Promotion:** per-namespace / per-cluster; a gated prod `helm upgrade`/apply.
- **Secrets:** Kubernetes Secrets or the external-secrets operator. **Rollback:** `helm rollback` / re-apply the prior digest (`kubectl rollout undo deployment/<name>`).
- **Verify:** liveness/readiness probes + a smoke Job. **Observe:** Prometheus / OTel + a spend policy.

> **Note on the worked pair:** AWS-ECS and Kubernetes are the *same topology* (orchestrated, long-lived containers). They give depth for the market-leading pair; the table below is what shows the contract also reaching serverless, PaaS, and edge — so an adopter on a different shape sees themselves.

## Topology coverage *(breadth across the major clouds)*

The six contract points map across every deployment topology, not just orchestrated containers. This table names the canonical service per cloud so you can find your cell — it is documentation, **not** a set of executable per-platform adapters (which would rot):

| Topology | AWS | Azure | GCP | Rollback shape |
|----------|-----|-------|-----|----------------|
| **Orchestrated containers** | ECS/Fargate, EKS | Container Apps, AKS | Cloud Run, GKE | redeploy prior digest / `helm rollback` |
| **Serverless / FaaS** | Lambda | Functions | Cloud Functions | shift alias/version to prior |
| **PaaS / git-push** | App Runner, Elastic Beanstalk | App Service | App Engine | redeploy prior slug/version |
| **Static / edge** | Amplify, CloudFront | Static Web Apps | Firebase Hosting | atomic re-point to prior deploy |

*Non-cloud and self-managed targets (Fly, Render, Railway, Nomad, bare-metal) are the bring-your-own recipe below.*

## Bring your own platform *(Fly, Render, Railway, Nomad, bare-metal, …)*

Any platform works if you map the six contract points. For each, find the platform's equivalent — and where it can't *enforce* a point, record the honest fallback rather than silently dropping it:

1. Identify the platform's **immutable artifact** unit. If it only deploys from source, pin the commit/digest so "what shipped" is still nameable.
2. Map the **promotion tiers**. If the platform has one environment, document the compensating **manual** prod gate.
3. Point config/secrets at the platform's **secret store** — never commit. If it lacks one, record a waived control + a compensating process (`templates/WAIVER-REGISTER.md`); don't drop the point.
4. Declare and **test** the rollback path. If immutable-redeploy isn't available, document the forward-fix procedure and its RTO.
5. Wire a **post-deploy smoke** that gates the boundary (stops promotion on failure).
6. Point telemetry + a spend cap at the platform's equivalents; record them in your `RUNBOOK.md` §4/§9.

Record your platform's answers to all six in your project `RUNBOOK.md` §4 (Deploy) — that is where the kit expects them.

## Honest ceiling

The kit provides the *contract*, these *worked examples*, the *topology map*, and this *recipe*; actually provisioning and configuring the platform is **your** work. A green kit run is *necessary, not sufficient* for a correctly-configured deploy target — identical to `vc-hosts.md`'s ceiling. This guide adds no new machine-checkable proof: the enforceable deploy obligations remain gated where they already are (`conformance/definition-of-deployable.md` for the post-deploy gate; the Definition of Done for supply-chain / rollback / observability). It makes those obligations *portable and discoverable*, it does not re-prove them. A platform you map yourself is as first-class as a worked one.
