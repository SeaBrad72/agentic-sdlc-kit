# E5-ops-skill — the `operating` craft skill (blast-radius-aware, advisory-not-actuating)

**Date:** 2026-06-29
**Status:** Approved (owner-ratified design gate)
**Epic:** E5 (live observability / operate-loop). **Second and final E5-ops sub-slice**, after E5-ops-query (v3.74.0 — the queryable-backend trace round-trip). E5-ops-query proved the *capability* (an operator can find the trace); this slice writes the *craft* that uses it.

## Why this is its own slice (decomposition)

"E5-ops" was decomposed into two cohesive sub-slices (owner-approved 2026-06-29): **(1) E5-ops-query** — concrete behavioural proof (queryable-backend round-trip), shipped v3.74.0; **(2) E5-ops-skill (this slice)** — the `operating` skill brick: the operate-phase craft (investigate telemetry → triage → decide *safely*). Build order is proven-not-prescribed: prove the capability first, then write the craft that leans on it.

## Decision (owner-ratified)

A **pure FLOOR skill brick** — `skills/operating/SKILL.md` — in the proven `continuous-discovery` shape (~8 files, single-seat, no new gate/claim/guard, extends the existing `skill-spine` claim). It encodes the operate craft and *points at* the kit's existing surfaces (the E5 telemetry stack, the L0–L3 autonomy tiers, the escalation seam, the never-actuate principle) without adding tooling.

Two forks resolved at the design gate:

1. **Seat = the Orchestrator's Ops hat, single-seat** (not a standing Ops/SRE seat, not the Engineer). The operate craft is *monitor → triage → assess blast radius → decide/escalate* — on-call-commander altitude, which is the Orchestrator's (it already wears the Product and integration hats). The Engineer *builds* slices; it does not command incidents. The one adjacency — an Engineer reading telemetry to fix its own slice — is already `debugging`'s; `operating` must not duplicate it. Ops/SRE remains a **hat, not a seat**: the kit has no live system of its own to operate, so the agents-vs-skills rule denies a standing seat (demand-gated on a live system **+** distinct prod authority — a clean future promotion). Mirrors the Product→`continuous-discovery` hat precedent.

2. **Escalation scope = point only (pure brick); the `escalate.sh` ops-trigger is banked, not wired.** The skill *teaches* "high-risk → route through `escalate.sh`" and points at the seam, but does not add an ops-specific trigger. Rationale (the `design` skill's *defer-build-ahead*): there is no live system raising ops escalations yet, and wiring a trigger would couple a craft brick to a guarded control-plane script — a different *kind* of slice. The honest ceiling discloses the ops-trigger as a documented extension point. Banked as `escalate-ops-trigger-banked` (add an `ops-irreversible` trigger + option set + `--selftest` to `escalate.sh` when a concrete consumer exists; the record schema is already B-ready).

## The craft — what `skills/operating/SKILL.md` teaches

The taught flow for handling a live signal safely (the operator-agent = Orchestrator wearing the Ops hat):

1. **Observe.** Read the telemetry the kit already emits — the Factor-14 quartet (health `/healthz` + structured logs + OTel spans + Prometheus `/metrics`); retrieve a trace by id via the E5 query path (`GET /api/traces/{id}`). The skill *points at* the E5 stack as the observable surface; it adds no tooling.
2. **Triage.** Correlate signals (the `request_id` ↔ `trace_id` correlation E5-log/E5-trace established), establish severity. Root-cause work **composes with `debugging`** (reproduce as a red→green regression) — the skill defers to it, not duplicates it.
3. **Assess blast radius** *(the signature discipline).* Before proposing *any* remediation, characterize what the action touches, whether it is reversible, and the radius if it is wrong.
4. **Map to an autonomy tier.** L0–L3 from `DEVELOPMENT-PROCESS §13` (governed by risk × reversibility × blast radius). Investigation/triage is L0–L1 (act+report); **anything irreversible or high-blast-radius is human-gated regardless of tier.**
5. **Advisory, not actuating.** The agent *surfaces* findings + a recommended action; it does **not** actuate catastrophic/irreversible changes. **The human commands the catastrophic action.** High-risk actions route through the escalation seam (`escalate.sh raise → await → resolve`).
6. **Close the loop.** Operate signals feed back to Discover — postmortem → backlog via the existing `operate-loop` tooling; **never-actuate** (the tool scaffolds and parses; it does not auto-detect incidents or auto-create tracker items).

The kit-original value is steps 3–5 — the **blast-radius → tier → advisory/escalate** judgment, which no existing skill carries. Boundary vs `debugging`: debugging finds a bug's root cause; `operating` handles a *live signal safely* (and may invoke debugging for RCA).

## Load-bearing markers (the verifier teeth)

`conformance/orchestrator-loop-wired.sh` greps `skills/operating/SKILL.md` for kit-distinctive, high-entropy markers — chosen so a generic SRE tutorial that paraphrases the concept fails the `grep -qF` check (the *generic-paraphrase-must-fail* property):

`name: operating` · `blast radius` · `advisory, not actuating` · `the human commands the catastrophic action` · `autonomy tier` · `surface, don't actuate`

(Final marker set confirmed at build against the generic-paraphrase-fails test; a positive liveness anchor — the real SKILL.md passes — plus a load-bearing negative — a generic paraphrase and a missing-reference fixture both FAIL — per non-vacuity.)

## Scope & files — FLOOR brick (~8 files, the `continuous-discovery` shape)

- **Create** `skills/operating/SKILL.md` (frontmatter + craft flow + markers + honest-ceiling + rationalizations table + terminal state; the conformance-comment naming the load-bearing markers).
- `conformance/orchestrator-loop-wired.sh` — add `OPERATING_SKILL_FILE` path var + `check_operating_skill()` (single-seat: assert the SKILL.md markers AND that the Orchestrator def references `skills/operating/SKILL.md`) + main-body call + fixture wiring in every existing case + **2 new negative selftest cases** (marker-teeth: drop a marker → FAIL; reference-teeth: Orchestrator def missing the path → FAIL).
- `skills/using-skills/SKILL.md` — add the index row (`| operating | skills/operating | … |`) + add `skills/operating` to the conformance-comment path list (the structural `check_keystone` enforces this against every `skills/*` on disk).
- `agents/orchestrator.agent.md` + `.claude/agents/orchestrator.md` — add `## Operations (operating hat)` referencing `skills/operating/SKILL.md`, placed at **loop-close** (operate → feeds back to discover).
- `conformance/claims.tsv` — extend the `skill-spine` claim description to name the new brick (same `id`, same verifier — **no new claim**).
- `docs/operations/orchestration.md` — note the Ops hat in the hat ordering.
- Version finishing folded into `apply.py`: `VERSION` 3.74.0 → 3.75.0, `README.md` badge, `CHANGELOG.md` `## [3.75.0]` entry.

No edit to `conformance/verify.sh`, `ci.yml`, or `adopter-export.sh`: the `skill-spine` check is already registered, `ci.yml` already runs `orchestrator-loop-wired.sh --selftest`, and `skill-spine` is already in the adopter carve list.

## Build model — GREEN (skill brick), AMBER apply

Authored in `scratchpad/e5-ops-skill/`, assembled into one idempotent `apply.py` (base64-embeds `SKILL.md`, idempotent text edits, version finishing), clone-proven (`shellcheck`, `orchestrator-loop-wired.sh --selftest` incl. the 2 new negatives, `verify --require` under `env -u KIT_GUARD_SELFEDIT`, `check_keystone` GREEN with `skills/operating` indexed), human-applied. Dual-reviewed (reviewer: marker non-vacuity + the 2 negatives load-bearing + keystone row present + single-seat wiring; security: the skill prescribes advisory-not-actuating + escalation hand-off and ships no actuation path — confirm it cannot be read as authorizing autonomous catastrophic action). Per-slice meta-control panel #26.

## Honest ceiling

- **What is provable:** the craft is *provided* (the SKILL.md exists, carries the load-bearing markers, and is indexed by the keystone), the **agents-vs-skills rule is respected** (Ops is a hat, not a seat), and the keystone/reference wiring is structurally locked. Generic paraphrase fails the markers (non-vacuity).
- **What is NOT provable (the tight ceiling):** triage *quality* is un-gateable — there is no CI check that an agent triaged a real production alert well; the relationship is inherently advisory. The structural proof is wiring + provision, not good judgement.
- **Documented extension point:** the `escalate.sh` **ops-trigger is not wired** (banked) — the skill prescribes the escalation hand-off, and an ops trigger fail-closes today (`escalate.sh` knows only `runaway-breach`). Disclosed, not implied.
- **Relationship to existing docs:** the skill *references* the operate substrate (`docs/operations/operate-loop.md`, `docs/operations/agentic-ops.md`, the §13 tier matrix) and encodes the *judgement* on top — it does **not** duplicate the tooling docs (default-KEEP / anti-ceremony).

## What this closes

Completes **E5-ops** (both sub-slices) and the E5 epic's operate-loop back half: the kit now both *proves* an operator can find a trace (E5-ops-query) and *carries the craft* for acting on it safely (E5-ops-skill). The skill spine grows to **10 content skills + the using-skills keystone** (design · plan · tdd · review · worktrees · verification · debugging · evals · continuous-discovery · **operating**).
