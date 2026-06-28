# Meta-control panel #10 — skill-spine brick #3 (the kit's own `tdd` skill)

**Date:** 2026-06-28
**Trigger:** per-slice M verdict (condition A5) for skill-spine brick #3 (v3.59.0).
**Profile:** light (5-lens).
**Verdict:** **GO.**

Brick #3 = the kit's own `tdd` skill (`skills/tdd/SKILL.md`), a harness-neutral test-driven-development-equivalent, FLOOR-only, referenced by the **Engineer** (not the Orchestrator — the seat that builds via TDD). **Designed by dogfooding `skills/design/SKILL.md` and planned by dogfooding `skills/plan/SKILL.md`** — the 2nd real self-host use, and the plan skill's first use. Built AMBER; dual-reviewed (reviewer APPROVE + security-reviewer PASS, no findings at any severity); independently proven on a clone (selftest 8/8, `verify --require` 31 controls / 0 failed, idempotent, orchestrator defs byte-unchanged, bricks #1/#2 markers preserved).

## The 5 lenses

| Lens | Verdict | Evidence |
|------|---------|----------|
| Honesty / no-overclaim | GREEN | Claim scoped to "structural"; honest-ceiling (design §5) concedes the skill was leaner than superpowers on the cycle itself — mitigated in-slice by adding the rationalizations + red-flags teeth. Bootstrap (superpowers TDD authoring its own replacement; design+plan skills producing the slice) stated honestly. |
| Right-weight / anti-ceremony | GREEN | FLOOR-only; **zero** new gate/claim/guard/registry/export edits — reused `skills/*` glob + the `skill-spine` claim. 10 files. Tight `skills/tdd/` scope chosen over a broad `skills/build/` (agents-vs-skills + 1:1 replacement + cohesion + no overlap with the future worktrees/verification bricks). |
| Enforcement-integrity / non-vacuity | GREEN | Reviewer verified a verbatim superpowers copy fails **5 of 6** markers (`name: tdd`, `## When to use`, `non-vacuity`, `critical path`, `evals` all absent; only `Red-Green-Refactor` overlaps). Case 7 (marker teeth) + case 8 (Engineer-omits-reference teeth) both load-bearing; **case 8 also closes the brick-#2 banked reference-teeth follow-on**. |
| Harness-neutrality | GREEN | Pure-markdown SKILL, invoke-by-read floor; native `.claude/agents/engineer.md` mirror is a bonus, not required. |
| Is-the-provable-thing-meaningful | GREEN | Reviewer adversarially confirmed genuinely kit-distinctive (the "watch-it-fail IS non-vacuity" framing is the kit's own concept, not a paraphrase). The meaningful thing — the 2nd self-host (design+plan skills authored this brick) — is real. |

Standing "integration-capability / no-dead-ends" lens: **N/A** — no industry-standard integration surface in this slice.

## Findings

- **0 blockers · 0 High.**
- **1 Minor — IMPLEMENTED in-slice:** reviewer noted the skill was leaner than superpowers on the cycle itself (missing the anti-rationalization / red-flags behavioral teeth that stop TDD-skipping). Added a compact "Rationalizations & red flags — STOP" section (excuse→reality table + red-flags list); re-proven on clone (markers/selftest/verify all green). This directly serves the self-hosting bar ("good enough the maintainer would choose it over superpowers").
- **1 Low — BANKED (optional):** backfill the orchestrator-*reference* negative selftest for `check_skill`/`check_plan_skill` (bricks #1/#2). Case 8 proves the reference-teeth pattern is sound for `check_tdd_skill`; backfilling the identical pattern for the older two is low-value but would fully discharge the original banked item.

## Retro

- **Self-host compounding is now visible across a whole slice:** brick #3 was *designed* with the design skill and *planned* with the plan skill — two of the three built bricks authored by the kit's own earlier bricks. Each brick shrinks the superpowers surface the next one needs, making the E10 zero-superpowers acceptance progressively more true in practice.
- **Process applied (brick-#2 lesson):** the panel #10 governance close (this artifact + marker + log row) is folded INTO the feature PR rather than trailing as a separate post-merge docs PR — avoiding the blocked direct-push-to-main.
- The agents-vs-skills rule did real work again: it kept brick #3 scoped to the TDD craft (Engineer's skill) instead of a broad `skills/build/` that would have duplicated the seat def and pre-empted later spine bricks.

**Next spine brick: #4 = the code-review skill** (`requesting-code-review`-equivalent), wired to the Reviewer seat.
