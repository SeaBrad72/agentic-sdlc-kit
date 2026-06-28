# Skill-spine brick #5 — the kit's own `worktrees` (isolation) skill

**Date:** 2026-06-28
**Epic / slice:** E3 → **skill-spine brick #5** (the kit's own worktrees/isolation skill). Fifth brick of the kit's fresh-authored skill spine, toward the [[self-hosting-commitment]] (replace external superpowers; E10 = build a slice using only the kit's own roster + skills).
**Status:** Design converged — **designed by dogfooding `skills/design/SKILL.md`** (4th self-host use), owner-ratified 2026-06-28. Ready for the implementation plan (which will dogfood `skills/plan/SKILL.md`).
**Tracked here** because the skill spine + the E10 self-host test depend on the convention, and it must be resumable cold.

**Reads-first for a cold resume:** [[self-hosting-commitment]], brick #4's design doc (`docs/architecture/2026-06-28-review-skill-design.md`, the convention this mirrors), the shipped skills (`skills/{design,plan,tdd,review}/SKILL.md`), the shared verifier (`conformance/orchestrator-loop-wired.sh`), and the seat this wires (`agents/orchestrator.agent.md`).

## 0. Why this slice (the decision trail)

Bricks #1–2 wired the Orchestrator's Architect hat (design + plan); brick #3 wired the Engineer (tdd); brick #4 wired the Reviewer (review). Brick #5 is the next spine piece superpowers supplies — `using-git-worktrees` → a kit-authored `worktrees` skill — and it wires the **Orchestrator** seat (the seat that *creates and ensures* isolation).

### The fork (owner-ratified 2026-06-28): worktrees/isolation before verification-before-completion
The remaining spine had two equally-defensible next bricks. Worktrees won brick #5 because it has **clean single-seat ownership** that fits the established FLOOR pattern with zero contortion: the Orchestrator already "Set[s] up an isolated worktree per fanned-out Engineer" and its tools already include `git (worktrees, merge)` — the isolation *mechanism is already live and proven* (orchestrator-run.sh fan-out + E3b conflict-safe integration). verification-before-completion is cross-cutting (every seat uses it) so its seat-wired verifier leg gets artificial — it is deferred to brick #6.

### Scope decision: `skills/worktrees/` = the isolation CRAFT, wired to the Orchestrator
The Orchestrator *creates/ensures* isolation; the Engineer *operates within* an assigned worktree (its boundary discipline already lives in `agents/engineer.agent.md`). superpowers' `using-git-worktrees` is fundamentally a workspace-*creation* flow (detect existing → native tools → git fallback → setup), which maps to the Orchestrator. So the skill wires single-seat to the Orchestrator (matching every other brick); the Engineer's existing worktree-boundary language is left as-is and **not** asserted.

### Name decision: `worktrees` (concrete), framing isolation-as-principle
Named `worktrees` for discoverability and parity with the source skill — but the SKILL frames **isolation** as the principle and worktrees as one mechanism (native-tools-first; git is a fallback). This mirrors `tdd` being a concrete name that encodes the non-vacuity principle.

### Intent (unchanged): FULL REPLACEMENT, not enhancement
Zero runtime dependency on superpowers; acceptance = E10.

## 1. What this slice is
Author the kit's **fifth own skill — `worktrees`**: the craft of working in isolation, invoked by the Orchestrator seat. **FLOOR-only** (invoke-by-read).

## 2. The skill's content — where the kit *improves on* superpowers (the real value)

`skills/worktrees/SKILL.md` is **not a copy** of superpowers' `using-git-worktrees`. It keeps the proven isolation spine — detect existing isolation FIRST (never nest; submodule guard); prefer the platform's native worktree mechanism; git fallback only when none exists; safety-verify the worktree dir is ignored — and **bakes in the kit's own hard-won disciplines as first-class steps:**

- **The kit's parallel-safety rule (distinctive).** Two slices are safely parallel **only** with **disjoint file sets, no shared mutable state, and each independently testable**. Isolation is a *precondition the Orchestrator checks before fan-out*, not merely a directory. (This is the Orchestrator's slicing heuristic, made the heart of the skill.)
- **The two halves of isolation.** Create-time (one worktree per Engineer) **and** integrate-time **conflict-safe** detection — before merging parallel branches, detect overlapping changed-file sets (`git diff --name-only --no-renames` vs the run cut-point) and **refuse fail-closed** with a `kit.conflict` span (the E3b link). Isolation that only creates but doesn't guard integration is half a discipline.
- **Never-fight-the-harness (the kit's neutrality stance).** Native worktree tools first; `git worktree` only as fallback. Using `git worktree add` when a native tool exists creates phantom state the harness can't manage. This is the kit's LLM/harness-neutrality goal applied to isolation.
- **The Engineer boundary.** Stay inside the assigned worktree; **zero out-of-slice edits**; return a diff + a self-verify report; the Orchestrator integrates (builder ≠ integrator).
- **Metering.** Every fanned-out step is metered through the runaway kill-switch (`scripts/runaway-guard.sh step`); a guard STOP halts further fan-out.

This is "take inspiration, improve, make it inherent": isolation reframed around the kit's disjoint-set parallel-safety rule + conflict-safe integration + harness-neutrality, not just worktree mechanics.

## 3. Wiring (mirrors #1–4, on the Orchestrator)
- **Orchestrator def (the seat that owns isolation):** make "Set up an isolated worktree per fanned-out Engineer" concrete — a new "Isolation" reference: "follow the kit's own `skills/worktrees/SKILL.md`." Edit `agents/orchestrator.agent.md` (FLOOR) + `.claude/agents/orchestrator.md` (native). The verifier asserts the Orchestrator def references the skill.
- **Engineer def:** unchanged — its worktree-boundary language already exists and is not asserted by this brick (single-seat parity).
- **Guard:** none — `skills/*` already in `is_control_plane_path` + both shell-redirect regexes; `skills/worktrees/SKILL.md` is agent-immutable for free (confirm-don't-add).

## 4. Conformance (right-weighted — no new gate, no new claim)
- **Extend the `skill-spine` claim** text (`conformance/claims.tsv:39`) → "… + worktrees skills … referenced by the orchestrator (Architect hat **+ Isolation**) … bricks #1–5 …".
- **Extend `conformance/orchestrator-loop-wired.sh`:** add `check_worktrees_skill "$WORKTREES_SKILL_FILE" "$ORCH_DEF"` asserting the skill exists + ASCII-safe kit-distinctive markers + the **Orchestrator** def references it. Candidate markers (locked at plan time, `grep -qF`, ASCII-only): `name: worktrees`, `disjoint file sets`, `--no-renames` (or `conflict`), `out-of-slice`, `native` (native-first). A generic `using-git-worktrees` paraphrase fails.
- **New selftest case 11** (marker teeth: drop a kit-distinctive marker → exit 1) + **case 12** (Orchestrator omits the reference → exit 1 — the reference-teeth pattern bricks #3/#4 established).
- Update cases 1–10 fixtures so each builds a conformant worktrees skill + Orchestrator reference. Wired via the existing orchestrator-loop entries — no new registration surface.

## 5. Honest ceiling & scope (named, not built)
- **Provided + structurally-proven; quality un-gateable** — correct for a skill.
- **Isolation bounds blast-radius; it is NOT a security sandbox.** A worktree limits accidental cross-slice writes; it is not containment (that is E4 harness-sandbox). Worktree cleanup of unchanged trees is best-effort / harness-owned.
- **Bootstrap** — the kit's design + plan skills produced this slice (4th dogfood).
- **FLOOR-only-first** — formal `skills` adapter dimension still deferred.
- **Single-seat** — the Engineer's worktree-boundary discipline is referenced informally in its def but not asserted, to keep the verifier teeth clean.
- **Spine remaining after #5** — verification-before-completion, then the META discovery skill (`using-superpowers`-equiv, the keystone) → then E10 zero-superpowers acceptance.

## 6. Build approach
Control-plane slice (new `skills/worktrees/SKILL.md`; orchestrator defs ×2 — FLOOR + native; `conformance/orchestrator-loop-wired.sh` + `conformance/claims.tsv` + `docs/operations/orchestration.md`; version finishing **3.60.0 → 3.61.0**) → **AMBER `apply.py`**, clone dry-run incl. shellcheck + `verify --require` → **dual review** (reviewer: is the skill genuinely the kit's isolation craft + the conformance non-vacuous incl. case 12; security: low surface — read-only guidance, confirm `skills/` immutability holds) → **light 5-lens meta-control panel #12** (A5) → **fold the governance close INTO the feature PR** (standing process). Subagent-driven build; the human applies/merges/release-tags (run `release-tag.sh` only after `git checkout main && git pull`).

## 7. Convergence record (owner-ratified 2026-06-28)
Designed by dogfooding `skills/design/SKILL.md` (4th self-host use). The worktrees/isolation brick won brick #5 over verification-before-completion on clean single-seat Orchestrator ownership of an already-live mechanism. `skills/worktrees/` = isolation craft wired to the Orchestrator (the seat that creates/ensures isolation; agents-vs-skills + 1:1). The skill reframes isolation around the kit's **disjoint-set parallel-safety rule + conflict-safe integration + harness-neutrality** atop the proven detect-first/native-first spine. Right-weighted conformance (extend the shared verifier + the one `skill-spine` claim; +case 11 marker-teeth + case 12 reference-teeth). FLOOR-only. **Next: the implementation plan, dogfooding `skills/plan/SKILL.md`.**
