# Skill-spine brick #3 — the kit's own `tdd` skill (test-driven development)

**Date:** 2026-06-28
**Epic / slice:** E3 → **skill-spine brick #3** (the kit's own TDD skill). Third brick of the kit's fresh-authored skill spine, toward the [[self-hosting-commitment]] (replace external superpowers; E10 = build a slice using only the kit's own roster + skills).
**Status:** Design converged — **designed by dogfooding `skills/design/SKILL.md`** (2nd real self-host use; brick #2 was the 1st), owner-ratified 2026-06-28. Ready for the implementation plan (which will dogfood `skills/plan/SKILL.md`).
**Tracked here** (not `docs/superpowers/specs/`) because the skill spine + the E10 self-host test depend on the convention, and it must be resumable cold by a fresh instance.

**Reads-first for a cold resume:** [[self-hosting-commitment]] (the why), brick #2's design doc (`docs/architecture/2026-06-27-plan-skill-design.md`, the convention this mirrors), the shipped skills (`skills/design/SKILL.md`, `skills/plan/SKILL.md`), the shared verifier (`conformance/orchestrator-loop-wired.sh`), and the seat this brick wires (`agents/engineer.agent.md` — "Follow TDD" is its Responsibility, made concrete here).

## 0. Why this slice (the decision trail)

Bricks #1–2 wired the **Orchestrator's Architect hat** (design + plan). Brick #3 is the next spine piece superpowers supplies — `test-driven-development` → a kit-authored `tdd` skill. Unlike #1/#2, it is the **Engineer's** craft (the Engineer is the seat that "builds via TDD", `engineer.agent.md:4,8`), so it wires the Engineer def, not the Orchestrator.

### Scope decision (owner-ratified 2026-06-28): tight `skills/tdd/`, NOT a broad `skills/build/`
By the kit's own **agents-vs-skills rule**, the Engineer is the seat; its done-bar (self-verify, zero out-of-slice edits, return a diff + report) is already in `engineer.agent.md`. A skill is the *craft a seat invokes*, not a restatement of the seat. A broad `skills/build/` would (a) duplicate the seat def (drift), (b) build-ahead / overlap the dedicated future bricks `using-git-worktrees` + `verification-before-completion`, (c) map to three superpowers skills at once, muddying the E10 "have we replaced X?" audit, and (d) break one-skill-one-responsibility. So brick #3 = the **TDD craft only**, 1:1 with `test-driven-development`. Composability (few seats, many small skills) is the intended design.

### Intent (unchanged): FULL REPLACEMENT, not enhancement
Zero runtime dependency on superpowers; the kit's process served by kit-authored, harness-neutral skills. "Improves on superpowers" = the re-authoring quality bar. Acceptance = E10.

## 1. What this slice is
Author the kit's **third own skill — `tdd`**: red-green-refactor + the kit's testing disciplines, invoked by the **Engineer** as its build craft, BEFORE/while implementing a slice. **FLOOR-only** (invoke-by-read), mirroring #1/#2.

## 2. The skill's content — where the kit *improves on* superpowers (the real value)

`skills/tdd/SKILL.md` is **not a copy** of superpowers' `test-driven-development`. It keeps the proven spine — the Iron Law (NO production code without a failing test first), Red → **verify it fails for the right reason** → Green (minimal) → Verify green → Refactor, real-code-not-mocks, delete-and-restart-if-code-came-first — and **bakes in the kit's own hard-won disciplines as first-class steps:**

- **"Watch it fail" IS non-vacuity.** TDD's verify-red is the *same law* the kit applies to every conformance lock: a test (or proof) that cannot fail proves nothing — it needs a positive liveness anchor AND a load-bearing negative. The skill frames red-green-refactor explicitly as the unit-test instance of the kit's non-vacuity discipline. (This is the connective tissue that makes it the kit's TDD, not generic TDD.)
- **Coverage floor.** 80%+ line coverage as the floor, **100% on critical paths** (auth, payments, money/calc) — from DEVELOPMENT-STANDARDS, not generic TDD. Coverage of the right code beats a vanity number.
- **Test at the right layer.** The testing pyramid (unit → integration → api/route → contract → e2e), and choose the layer that matches the behaviour under test; mock at boundaries, not internals; test behaviour, not implementation (survives refactors). Ties to the E1 test-battery + the `test-layers-ready` gate.
- **AI features → evals.** For AI behaviour, the eval *is* the failing-test-first (write the eval, watch it fail, make it pass); evals gate like tests and must not regress. Named here as a first-class parallel to tests; deep eval methodology is deferred to E6 (right-weight — no build-ahead).
- **Self-verify maps to the Engineer's done-bar.** The skill ends by pointing at the seat's done-bar (tests green + pristine output) rather than restating it — keeping seat-vs-skill clean.

This is "take inspiration, improve, make it inherent": TDD reframed as one expression of the discipline the whole kit already runs on (non-vacuity), plus the kit's coverage/pyramid/eval standards.

## 3. Wiring (mirrors #1/#2, but on the Engineer)
- **Engineer def:** make the Responsibility "Follow TDD: write the failing test, make it pass minimally, refactor" concrete — "follow the kit's own `skills/tdd/SKILL.md`." Edit both `agents/engineer.agent.md` (FLOOR) and `.claude/agents/engineer.md` (native mirror).
- **Guard:** none needed. `skills/*` is already in `is_control_plane_path` + both shell-redirect regexes (brick #1's glob), so `skills/tdd/SKILL.md` is agent-immutable for free — confirm-don't-add (brick #2 proved this pattern).

## 4. Conformance (right-weighted — no new gate, no new claim)
- **Extend the `skill-spine` claim** text → "the kit ships its own `design` + `plan` + `tdd` skills … bricks #1–3 …".
- **Extend `conformance/orchestrator-loop-wired.sh`:** add `check_tdd_skill "$TDD_SKILL_FILE" "$ENGINEER_DEF"` asserting `skills/tdd/SKILL.md` exists + ASCII-safe kit-distinctive markers + the **Engineer** def references it. Candidate markers (final set locked at plan time, `grep -qF`, ASCII-only): `name: tdd`, `## When to use`, `Red-Green-Refactor`, `non-vacuity`, `critical path`, `evals`. A generic `test-driven-development` paraphrase lacking the kit's disciplines **fails** here.
- **New selftest case 7** (non-vacuity): a `tdd` skill missing a kit-distinctive marker → exit 1.
- **Close the brick-#2 banked follow-on (cheap, same verifier):** add a negative selftest for the *orchestrator-/engineer-reference* branch — a conformant skill whose referencing def OMITS the path → exit 1 — so the reference assertion is provably load-bearing (currently only proven live by CI).
- Wired via the existing orchestrator-loop entries (verify/CI/drift-watch/doctor) — no new registration surface.

## 5. Honest ceiling & scope (named, not built)
- **Provided + structurally-proven; quality un-gateable** — correct for a skill (authored guidance); encoding the kit's coverage/pyramid/non-vacuity/eval disciplines is a real improvement over generic TDD.
- **Bootstrap** — superpowers' `test-driven-development` authored its own replacement; the kit's design + plan skills produced this slice (2nd dogfood).
- **FLOOR-only-first (again)** — formal `skills` adapter dimension still deferred.
- **AI-evals named, not built** — deep eval methodology = E6.
- **Spine remaining after #3** — requesting-code-review, using-git-worktrees, verification-before-completion, and the META discovery skill (`using-superpowers`-equiv) → then E10.

## 6. Build approach
Control-plane slice (new `skills/tdd/SKILL.md`; `agents/engineer.agent.md` + `.claude/agents/engineer.md` edits; `conformance/orchestrator-loop-wired.sh` + `claims.tsv` + `docs/operations/orchestration.md`; version finishing **3.58.0 → 3.59.0**) → **AMBER `apply.py`**, clone dry-run incl. shellcheck + `verify --require` → **dual review** (reviewer: is the skill genuinely the kit's TDD disciplines + the conformance non-vacuous, incl. the new negative-reference case; security: low surface — read-only guidance, confirm `skills/` immutability holds for the new file) → **light 5-lens meta-control panel #10** (A5) → version finishing folded in. **★ Fold the governance close (panel #10 marker+log) INTO the feature PR this time** (brick #2 lesson: a post-merge close forces a blocked direct-push-to-main + a separate docs PR). Subagent-driven build; the human applies/merges/release-tags (run `release-tag.sh` only after `git checkout main && git pull`).

## 7. Convergence record (owner-ratified 2026-06-28)
Designed by dogfooding `skills/design/SKILL.md` (2nd self-host use). Tight `skills/tdd/` scope (agents-vs-skills + right-weight + 1:1 replacement + cohesion overrode the broad `skills/build/`). Wires the **Engineer** (not the Orchestrator) — the seat that does TDD. The skill reframes red-green-refactor as the unit-test instance of the kit's **non-vacuity** law + adds coverage-floor / testing-pyramid / AI-evals disciplines. Right-weighted conformance (extend the shared verifier + the one `skill-spine` claim; +case 7 + the banked negative-reference case). FLOOR-only. **Next: the implementation plan, authored by dogfooding `skills/plan/SKILL.md`.**
