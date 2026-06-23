# E3 — Agentic specialization & orchestration (architecture / design)

**Date:** 2026-06-22
**Epic:** E3 (the headline E-series differentiator)
**Status:** Design converged (brainstorm). **Build deferred to AFTER E4** (per the ratified E2 → E4 → E3 order). This doc's primary jobs: (1) lock E3's frame, (2) **size E4** (the "What E3 requires of E4" section), (3) seed the E3 build slices.
**Tracked here (not `docs/superpowers/specs/`)** because E4's build depends on it and it must be resumable by a fresh instance (the C7/R4 guidance: tracked design → `docs/architecture/`).

---

## 1. Vision — the enablement thesis

The kit already gives a founder *discipline* (guardrails) and a *process* (the loop). **E3 gives them a team.** Someone shows up with an epic; an **Orchestrator** convenes the right cast for each phase, **fans the work out** across as many agents as it's worth, each **contained in its own safe area (E4)** so they do no harm in parallel, and **re-integrates through the same gates** that already make the work ironclad.

The guardrails stop being a brake and become **the thing that lets you floor it** — many agents moving at once *because* nothing can escape the rails. The unlock: **idea → production at team-velocity, one person in the lead seat, quality that doesn't bend because the gates don't move.**

Scope of the team: the adopter's **product** (product · design · architecture · engineering · QA · security · ops) **and** the **kit instance itself** (a steward that tends conformance + agent-ops telemetry within the guardrails). Not enterprise headcount — the realization of what *one* founder can do with this kit in place.

---

## 2. Operating model (how the team works)

- **The Orchestrator = the lead / EM.** The adopter's primary agent acting as coordinator. It takes an epic/story, runs the kit's loop, **convenes the right cast per phase**, **decides when to parallelize and how wide** (5 or 10 engineers — its call, via the strategies in §6), divvies the work, **re-integrates**, and **enforces the gates**. It conducts; it does not specialize.
- **Each phase convenes a cast.** The right actors in the room for that phase; others advise.
- **Fan-out within a phase.** The Orchestrator spawns **N parallel instances of a role**, each in its own isolated worktree (E4-contained), then reconvenes and integrates. Not engineer-only — Product fans out across research threads, Design across explorations, Review across lenses; **Engineer×N is the headline.**
- **Handoff = Task-Context-Contract in, artifact out**, with the kit's gates between phases. Everything still runs through the SDLC + guardrails.

---

## 3. The roster — the standing cast

**The agents-vs-skills rule (the anti-cumbersome principle):** an actor earns a **standing seat** only if it has a **distinct skill** AND (**distinct tools/authority** OR it **must run in parallel / independently**, e.g. builder≠reviewer). Everything else is a **skill a standing agent invokes**. Superpowers proves the ratio: ~3 agents + ~20 skills — the power is the skill library; the agents are few.

| Seat | Stance | Absorbs (as skills/hats) | Conditional? | Status |
|---|---|---|---|---|
| **Orchestrator** (lead) | conductor | convene · divvy · integrate · release-conductor (§7) | always | new |
| **Product** (PM/PO) | doer + facilitator | research, stories, INVEST slicing, success metrics | always | new |
| **Design** | doer + facilitator | ideation, flows, a11y | **only if a UI surface** | new |
| **Architect** | doer + critic | system design **+ planning** (absorbs a separate Planner), ADRs, blueprint | always | new |
| **Engineer ×N** | doer (**fan-out**) | **TDD test-authoring, migrations, docs** | always — the headline | new |
| **Reviewer** | critic | correctness, standards, §14 gates, perf + a11y lenses | always | **ships today** (`.claude/agents/reviewer.md`) |
| **Security** | critic | **threat-model** (Shape/Plan) **+ security-review** (Ship) | always | **ships today** (`.claude/agents/security-reviewer.md`) |
| **Ops/SRE** | doer | deploy, smoke, progressive delivery, **observability/telemetry**, on-call | **only if a live system** | new |
| **Kit-Steward** | doer + critic | conformance, **agent-ops telemetry** (`agent-trace`/`scorecard`/`tier-advice` exist), proposes guardrail/standards updates **the human ratifies** | always | new (composes existing scripts) |

**~7 always-on + 2 conditional.** Two existing seats (Reviewer, Security) are already ours, shipped in `.claude/agents/`, and battle-tested every slice — so E3 *grows a directory we already ship from 2 → ~9*, not a new paradigm.

**Not seats (deliberately):** test-author / migration-author / doc-writer / a11y-critic / perf-optimizer = **skills** the standing agents wear. **Retro-facilitator → E8** (cadence/retros is its own epic).

---

## 4. The skill spine (the flow)

The superpowers flow is the backbone, taken as **skills** and broadened to the full SDLC: **ideate/brainstorm → write (spec) → plan → do (build, TDD) → review.** Made *ours*: broader (adds product/design/ops), harness-neutral (§5), not a verbatim copy. The Orchestrator drives the spine; the cast supplies the craft. "Ideation, brainstorming, spec-writing, planning, TDD, review" must all be well-represented as skills.

---

## 5. Harness neutrality — floor + native (the kit's essence)

**Principle:** harness-neutral and technology-agnostic, **without diminishing Claude.** These are not in tension — they are the kit's existing **floor + native** adapter pattern (`harness-adapter.sh`), extended from the harness boundary to the **agent roster**:

- **Neutral agent definition (the FLOOR)** — each agent authored once, harness-neutrally: role · responsibilities · stance · Task-Context-Contract (I/O) · tools-needed · success criteria. Any harness can invoke it and get **the same work done in the same manner**.
- **Per-harness native binding (the NATIVE)** — each adapter (claude-code · codex · cursor · gemini · generic) binds the neutral definition to its harness's native agent mechanism. **Claude Code gets a rich subagent using Claude's full Task/subagent power; Gemini/Codex get their native equivalent.** The existing "lying-native" guard rejects unproven native claims.
- **Result:** same agent, same outcome, every harness; Claude never reduced to a lowest common denominator.

**Conformance implication:** extend `named-adapters.sh` / `harness-adapter.sh` so each adapter must **bind the roster** (behaviour: the agent is invocable and does its job), not merely declare it.

> **Open item (resolve at E3 build, post-E4):** the concrete neutral agent-definition format (a new `templates/AGENT-DEFINITION` schema vs. extending `adapter.json`). The adapter floor+native pattern already exists; the format is a build-time detail, not a frame decision.

---

## 6. Orchestration strategies (the Orchestrator's "process")

The Orchestrator's coordination playbook — the primitives that are prose-only today and become **provided** in E3:

- **Fan-out** — spawn N parallel role-instances on N independent slices; the Orchestrator sets N.
- **Pipeline** — stage work so item A is in review while item B is still building.
- **Parallel-review panels** — multiple review lenses concurrently (correctness · security · a11y · perf).
- **Adversarial-verify** — independent skeptics try to refute a finding before it's trusted.
- **WIP-limits** — cap concurrent work-in-progress per stage (pull flow, not push).
- **Conflict resolution / re-sync** — defined precedence + procedure when parallel work overlaps on integration.
- **Integration** — reconvene parallel outputs, resolve conflicts, run the gates on the merged result.

**Split by the portability seam:** the **mechanics** (worktree setup, atomic-claim, WIP tracking, conflict re-sync) are **harness-neutral git/shell** — runnable anywhere. The **patterns** (fan-out, panels, adversarial-verify) are **LLM-driven** — prose recipes + per-harness wiring. This split is the E3b/E3c decomposition (§9).

---

## 7. The release-conductor (E2 composing into E3)

The Orchestrator wears a **release-conductor** hat in Ship: it runs the release train — deciding what ships and **what's toggled off** — using **E2's feature flags** as the tool, informed by Reviewer/Security (what passed the gates) and Ops/SRE (deploy mechanics). E2 built the kill-switch *tool*; E3's Orchestrator is the *hand* that uses it ("ship the train, flag off what isn't ready"). Evidence the epics snap together, not a pile of features.

---

## 8. Human-map agnosticism

The kit keeps **its** canonical loop as the internal spine, but the roster is organized by **activity/intent, not phase name**, so an adopter maps *their* flow onto the kit's casts. The kit **enables** the human map without **imposing** one — portable from a solo vibe-coder (no ceremony) to an enterprise with its own (SAFe, Scrum, etc.).

Worked example — the adopter's six-bucket map → the casts:

| Adopter bucket | Activities | Cast convened |
|---|---|---|
| **Frame** | intake, kickoff, research, requirements | Product *(Orchestrator kicks off)* |
| **Shape** | design + engineering explorations, reviews | Product · Design · Architect/Engineer · Reviewer — **fan-out heavy** |
| **Plan** | definition, prioritization, sequencing, sprint planning | Architect/Planner · Product |
| **Build** | assignment, tech plan, implementation, self-verify | **Engineer ×N** |
| **Ship** | PR review, merge, UAT, regression | Reviewer · Security · **Orchestrator (release-train)** · Ops/SRE |
| **Observe** | stability, triage, KPIs, impact, OKRs, future planning | Ops/SRE · Kit-Steward · Product · *(Retro → E8)* |

---

## 9. Decomposition & build order (build AFTER E4)

E3 builds as **proven vertical slices** (the E2 playbook — smallest complete vertical that *proves* it), not a 9-agent dump:

- **E3a — Roster (neutral definitions + adapter bindings).** Grow `.claude/agents/` + neutral defs from 2 → the cast; extend `named-adapters.sh` to prove each adapter binds them. **Thin first slice:** the 4-seat **Orchestrator + Engineer×N + Reviewer + Security** build→review loop, made to fan out, contain, and integrate end-to-end.
- **E3b — Orchestration mechanics (harness-neutral).** Worktree-isolation, atomic-claim, WIP-limits, conflict re-sync as runnable git/shell + conformance they work.
- **E3c — Orchestration patterns (LLM-driven).** Fan-out · pipeline · parallel-review · adversarial-verify as recipes + per-harness wiring.
- **E3d — Phase→agent flow + conformance.** The activity→cast routing; conformance that the roster/orchestration is **wired and behaves** (declaration → behaviour, per the E-series thesis).

**Conformance philosophy:** prove the roster is **invocable and does its job per harness**, and that orchestration **runs** (golden-path-style execution) — not merely that definitions exist.

---

## 10. What E3 requires of E4 — **the containment contract (this sizes E4)**

E3 ships **parallel, file-mutating doer-agents.** That is only safe if E4 provides the safe area each one runs in. E4 must deliver, as **proven** controls (not attestation), the containment that E3's orchestration assumes:

1. **Per-agent filesystem scope** — each parallel Engineer runs in an **isolated git worktree / sandbox**; it cannot read or write outside its assigned slice. (Worktree-isolation is the E3b mechanic; E4 must make the *boundary enforced*, not conventional.)
2. **Egress control** — a parallel agent cannot exfiltrate or reach unapproved network destinations (the egress-allowlist, today attestation-only).
3. **Scoped, least-privilege tokens** — each agent gets only the credentials its task needs; no shared god-token across the fleet.
4. **Prod-credential separation of duties** — no build-phase agent holds production credentials; the release-conductor path is separated.
5. **Resource / cost ceilings + a runaway kill-switch** — a fan-out of N agents has a bounded token/compute budget and a circuit-breaker; a misbehaving agent can be killed without taking down the train (ties to E2's kill-switch + the cost-governance surface).
6. **Conflict-safe parallel writes** — the integration boundary must prevent two agents' concurrent writes from silently corrupting shared state (the conflict-resolution mechanic needs a containment guarantee underneath it).
7. **The guard at fleet scale** — the existing PreToolUse guard (a ~91% speed-bump per the hardening-watch) must hold when many agents act concurrently; E4's DAST/runtime-security + image-vuln blind spots are in-scope because a parallel fleet widens the attack surface.

**In one line:** E4 must turn the orchestration's *assumed* safe area into a *proven* one — per-agent FS/egress/token isolation, bounded cost with a kill-switch, and conflict-safe integration — so the Orchestrator can fan out to a dozen agents and the founder can **trust** it.

---

## 11. Deferred / out of scope (named, not built here)

- **Retro-facilitator → E8** (cadence/retros).
- **A11y / perf as standing seats** — they are Reviewer lenses; promote only if evidence demands.
- **The neutral agent-definition format** — finalized at E3 build (post-E4), §5 open item.
- **Multi-team fleet orchestration at enterprise scale** — E3 proves the pattern; scale-out is a later concern.

---

## 12. Convergence record

Owner-affirmed in the 2026-06-22 brainstorm: the enablement thesis (a team behind the guardrails) · the ~7+2 cast with the agents-vs-skills rule · the superpowers skill-spine, broadened · Orchestrator-owns-fan-out · the release-conductor (E2 composing) · **harness-neutral floor+native without diminishing Claude** · human-map agnosticism (activity-based roster) · build E3 as proven slices **after E4**. **Next concrete step: brainstorm + build E4, sized by §10.**
