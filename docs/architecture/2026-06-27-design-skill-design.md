# Skill-spine brick #1 — the kit's own `design` skill (architecture / design)

**Date:** 2026-06-27
**Epic / slice:** E3 → **skill-spine brick #1** (the kit's own design/brainstorm skill). First brick of the kit's fresh-authored skill spine, toward the [[self-hosting-commitment]] (replace external superpowers; E10 = build a slice using only the kit's own roster + skills).
**Status:** Design converged (brainstorm, owner-ratified 2026-06-27). Ready for the implementation plan.
**Tracked here** (not `docs/superpowers/specs/`) because later skill-spine bricks + the E10 self-host test depend on the convention this establishes, and it must be resumable cold by a fresh instance.

**Reads-first for a cold resume:** [[self-hosting-commitment]] (the why), the e3-spine §3 agents-vs-skills rule + §4 skill spine + §5 FLOOR+NATIVE (`docs/architecture/2026-06-22-e3-agentic-orchestration-design.md`), and the orchestrator the skill plugs into (`agents/orchestrator.agent.md`).

## 0. Why this slice (the decision trail)

The "Architect seat" was reframed twice on grounding: (1) by the kit's own **agents-vs-skills rule** (§3), design+plan is a **skill**, not a seat — it has no parallelism/independence requirement (unlike Engineer's fan-out or Reviewer's builder≠reviewer). (2) The skill it should be is **kit-authored**, not the external superpowers `brainstorming` — because the self-hosting commitment is to *replace* superpowers with the kit's own, improved, inherent craft. **Roles are not dropped** — roles (earned seats: independence/parallelism) and skills (craft the seats invoke) are complementary; this slice is the *skill-library* track, the roster track continues in parallel.

## 1. What this slice is

Establish the kit's **skill-invocation floor** and author its **first own skill — `design`** (a brainstorm/spec-equivalent), invoked by the Orchestrator as the **Architect hat** in Shape/Plan. FLOOR-only-first: the skill is invoked by being **read + followed** (universal across harnesses); the formal `skills` adapter dimension + native per-harness bindings are **deferred to brick #2** (avoid build-ahead for a single skill).

## 2. The convention (FLOOR-only-first)

- **FLOOR location:** `skills/design/SKILL.md` — the methodology authored once, harness-neutral markdown (a new top-level `skills/` dir, mirroring superpowers' shape; signals "the kit's own skill library").
- **Invocation (universal floor):** an agent invokes the skill by **reading + following `skills/design/SKILL.md`**. Any agent on any harness can load a markdown methodology — no plugin mechanism required. This is the equal-enforcement floor.
- **NATIVE bonus — DEFERRED to brick #2:** a harness's richer skill mechanism (Claude's Skill tool / a `.claude/skills/` binding) + the formal `skills` dimension in `adapter.json` + the lying-native proof. Named here, not built — invoke-by-read is sufficient and honest for brick #1.
- **Orchestrator wiring:** `agents/orchestrator.agent.md` + `.claude/agents/orchestrator.md` gain an **Architect-hat** line: for design/planning (Shape/Plan), follow `skills/design/SKILL.md`.

## 3. The skill's content — where the kit *improves on* superpowers (the real value)

`skills/design/SKILL.md` is **not a copy** of superpowers' `brainstorming`. It keeps the proven spine (explore context → clarify one question at a time → propose 2-3 approaches with a recommendation → present design → **HARD GATE: no implementation until the design is approved** → write the spec → hand to the plan skill) and **bakes in the kit's own hard-won disciplines as first-class steps:**

- **Architecture-first** + the **design-intent lens** (default-KEEP unless redundant/dead — not default-cut).
- **"Is the provable thing the meaningful thing?"** — the FS-isolation lesson: don't behaviourally prove an easy adjacent thing while the thing that matters stays unproven.
- **Proven-not-prescribed slice-selection** — if a slice's only harness-neutral proof is a fixture tautology, or it re-proves an existing slice, or its value is mostly future/declarative → **re-select the slice.**
- **The agents-vs-skills rule** — seat only if distinct-skill AND (distinct-tools OR parallel/independent); else a skill.
- **Honest-ceiling discipline** — name what's behaviourally provable vs. attestation; never let a green check imply more than it proves.
- **Right-weight / anti-ceremony** — prefer extending an existing gate to a new one; defer build-ahead (F5).
- **Non-vacuity** — every proof needs a positive liveness anchor + a load-bearing negative.

This is "take inspiration, improve, make it inherent" made concrete: the skill encodes the exact judgment exercised across the E-series (FS-isolation, E3d, the honest pivots).

## 4. Conformance (right-weighted — no new gate)

- **New claim `skill-spine`:** "the kit ships its own invocable `design` skill (`skills/design/SKILL.md`), referenced by the Orchestrator — brick #1 of the kit's own skill spine, toward self-hosting." Honest qualifier: *structural (the skill exists, is well-formed, and is referenced by the orchestrator def); methodology quality ("improves on superpowers") is the un-gateable ceiling, as for any LLM-followed guidance.*
- **Extend `orchestrator-loop-wired.sh`** (shared verifier, the E3b precedent): assert `skills/design/SKILL.md` exists + carries its required sections (frontmatter `name`/`description`; a "when to use"; the HARD-GATE; the kit-distinctive checks of §3) + the orchestrator def references `skills/design/SKILL.md`. `--selftest` teeth: a missing HARD-GATE or a missing orchestrator reference → exit 1.
- Wired into verify/CI/drift-watch/doctor via the existing orchestrator-loop entries + the new claim.

## 5. Honest ceiling & scope (named, not built)

- **Provided + structurally-proven; quality un-gateable** — but for a *skill*, authored methodology *is* the correct shape (a skill is guidance), and encoding the kit's own disciplines is a real improvement over generic brainstorming.
- **Bootstrap** — superpowers' `brainstorming` is being used to author its kit-native replacement. Fine — that is how you self-host.
- **FLOOR-only-first** — the formal `skills` adapter dimension + native bindings + the lying-native proof are **brick #2**, when a second skill / native bonus earns the formalization.
- **One skill** — the plan skill (brick #2), build/TDD skill, review skill, etc. follow, each its own proven slice. The full E10 self-host test ("build a real slice using only the kit's roster + skills") is the eventual acceptance.

## 6. Build approach

Control-plane (new `skills/design/SKILL.md`, `agents/orchestrator.agent.md` + `.claude/agents/orchestrator.md` Architect-hat edit, `conformance/orchestrator-loop-wired.sh` + `claims.tsv` + `claims-registry.sh` + `verify.sh` + adopter-export carve, `skills/` added to guard `is_control_plane_path` so the methodology is agent-immutable, `orchestration.md` note) → **AMBER** `apply.py`, clone dry-run incl. shellcheck, **dual review** (reviewer: is the skill content genuinely the kit's disciplines + the conformance non-vacuous; security: low surface — the skill is read-only guidance, no trust boundary; confirm `skills/` is guard-immutable so an agent can't rewrite its own methodology), **light 5-lens meta-control panel** (A5 — expect a hard look at "is authored guidance genuinely improving on superpowers, or restating it"), version finishing folded in. Async; the human applies/merges when back.

## 7. Convergence record (owner-ratified 2026-06-27)

Architect-seat → reframed to a kit-authored `design` **skill** (agents-vs-skills rule + self-hosting; roles NOT dropped — complementary tracks). FLOOR-only-first (invoke-by-read; formal `skills` dimension deferred to brick #2). The skill encodes the kit's own disciplines (the improvement on superpowers). Right-weighted conformance (extend `orchestrator-loop-wired.sh` + one claim). First brick of the kit's own skill spine toward E10 self-host. **Next: the implementation plan (writing-plans).**
