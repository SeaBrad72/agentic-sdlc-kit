# Meta-control panel #14 — skill-spine brick #7, the discovery KEYSTONE (`using-skills`) — SPINE COMPLETE

**Date:** 2026-06-28
**Trigger:** per-slice M verdict (condition A5) for skill-spine brick #7 (v3.63.0) — the spine's capstone gate.
**Profile:** light (5-lens).
**Verdict:** **GO.**

Brick #7 = the kit's own `using-skills` discovery keystone (`skills/using-skills/SKILL.md`) — the discovery discipline + the index of all 6 spine skills, the kit's harness-neutral `using-superpowers`-equivalent, FLOOR-only, wired single-seat to the **Orchestrator**. **This completes the skill spine** (7 skills: design / plan / tdd / review / worktrees / verification + using-skills). Designed + planned by dogfooding the kit's own design/plan skills (6th self-host). Built AMBER; dual-reviewed (reviewer APPROVE + security-reviewer PASS); independently proven on a clone (selftest 17/17, `verify --require` 31 controls / 0 failed, idempotent). The panel independently sabotage-reproduced the "generic paraphrase fails" claim and flip-proved both new teeth (case 16 index + case 17 reference) load-bearing.

## The 5 lenses

| Lens | Verdict | Evidence |
|------|---------|----------|
| Scope-coherence & proportion | GREEN | Steady-state economics held a 7th time: 1 new SKILL.md + extend the shared verifier (`check_keystone` + cases 16/17) + extend the one `skill-spine` claim + surgical Orchestrator inserts (FLOOR+native) + version finishing — **no new gate/claim/guard** (`skills/*` already control-plane; empirically blocked probe writes). Discipline+index scope correct (discipline-only loses the index teeth, index-only is mere docs — both rejected design §0). Single-seat Orchestrator sound (discovery is the conductor's entry, not a dual gate; "a hat, not a seat"). Index-names-all-6 coupling sound + stable *because the spine is complete*. |
| Honesty & over-claim (the big one) | GREEN (ceiling honestly named) | The entry-point ceiling is stated consistently in 4 places (SKILL §Entry-point honesty, design §5, CHANGELOG, orchestration.md): on the FLOOR the kit cannot force harness auto-load; first-contact is a documented convention, not enforcement. "Provided + structurally-proven; auto-load un-gateable" is the correct claim verb. "Replacing superpowers (content + discovery)" is honest — verbatim-consistent with bricks #1–6 (gated on E10), and no runtime superpowers read exists in any floor def/script. "Completes the spine" is honest (6 content + 1 keystone; design §5 "Spine remaining: NONE"). |
| Enforcement integrity (green-while-dark) | GREEN (declaration-ceiling disclosed) | Sabotage-tested against the LIVE check: a generic `using-superpowers` paraphrase → rejected exit 1 (`name: using-skills` absent); index dropping `skills/verification` → rejected (**case 16 index-tooth load-bearing**); dropping `user instructions` → rejected; minimal conformant keystone → PASS. Case 17 (Orchestrator omits the keystone ref) → exit 1. The all-6-index requirement forces kit-specificity (a generic copy names none of the kit's 6 paths). Disclosed ceiling (intrinsic, §5): a hollow stub stuffing the strings passes — the FLOOR-markdown declaration-check limit identical to #1–6; the real enforcement is the conformance/clone gate. |
| Direction & sequencing | GREEN | The spine **is** complete. Discovery was the one remaining gap ([[self-hosting-commitment]]: "content skills alone is NOT zero-dependency; the discovery meta-skill must be kit-native"). Invoke-by-read FLOOR + the index + the Orchestrator start-here reference close it. "No part of the kit's loop depends on superpowers" holds at runtime (no live read). **E10 is correctly next and honestly runnable.** Nuance banked: E10 measures against the FLOOR *convention* (the conductor consults the keystone), since auto-load is un-gateable. |
| Right-weighting & adoptability | GREEN | 64-line markdown, FLOOR-only invoke-by-read, progressive (when-to-use → discipline → instruction-priority → index table → honest ceiling → rationalizations → red-flags). Invisible to a vibe-coder until they start a task; the entry map an architect wants. Discoverability handled correctly vs the honest-ceiling caveat: the conductor reads it first by convention (orchestration.md), NATIVE may auto-surface — functions as an entry-point without over-promising enforcement. |

Standing "integration-capability / no-dead-ends" lens: **N/A** — pure-markdown FLOOR skill + verifier extension.

## Findings

- **0 blockers · 0 High.**
- **2 Low — confirmed non-blocking, no fix this slice (= the dual-review Minors, independently re-confirmed):**
  - **L1 — `skill-spine` claim has a redundant double-phrase** ("referenced by the orchestrator" appears twice; `discovery` named in both). Cosmetic apply.py string-assembly artifact; the claim still verifies (doctor claims PASS). Fix-forward at the next conformance touch — do not churn this slice.
  - **L2 — `check_keystone` index greps are path-prefixes** (`skills/review` would match a hypothetical `skills/reviewer`). Purely theoretical — requires the spine to grow a colliding-prefix skill, which it won't (spine complete). No fix.
- **Standing caveat (not a finding):** declaration-check ceiling — a hollow stub passes. Intrinsic to FLOOR markdown skills, identical to #1–6, named §5. Real enforcement is the conformance/clone gate.
- **Banked cross-brick cosmetic (pre-existing, NOT this slice):** `skills/design/SKILL.md` + `skills/plan/SKILL.md` still name `docs/superpowers/specs|plans/` as artifact-output dirs (with "or the project's plan location" fallbacks) — naming residue from #1/#2, not a runtime dependency. One-line rename at a future touch.

## Two ledgers

**Ledger 1 — verified-as-quality (ship with confidence):** apply clean + idempotent on the clone (re-run no-op, VERSION pinned 3.63.0); selftest 17/17 with cases 16 AND 17 load-bearing; generic-paraphrase rejection independently reproduced; SHA-256 of apply payload == shipped keystone; `skills/*` immutability glob live (two-matcher gap not recurring); FLOOR+native Orchestrator inserts honest about convention-vs-auto-load; honest-ceiling framing consistent across SKILL/CHANGELOG/claim/orchestration.md; no live superpowers runtime read anywhere.

**Ledger 2 — fix-forward (ranked, all Low — none gating):** (a) L1 dedupe the `skill-spine` claim's repeated "referenced by the orchestrator" phrase — cosmetic, next conformance touch; (b) banked: rename the `docs/superpowers/specs|plans` artifact-dir residue in design/plan SKILLs to a kit-native path — cross-brick cosmetic; (c) the declaration-check ceiling is intrinsic to FLOOR markdown skills — revisit only if a later artifact adds runtime behaviour; (d) E10 design note: measure self-host against the FLOOR convention (conductor consults the keystone), since auto-load is un-gateable.

## Retro — the completed spine (bricks #1–7) + E10 readiness

- **The spine is complete and the loop closes on itself.** Seven slices (design → plan → tdd → review → worktrees → verification → using-skills), each designed+planned by the kit's own *earlier* skills (this keystone was the 6th dogfood). The kit now owns its full discovery + content disciplines with **zero runtime dependency on superpowers** — the central [[self-hosting-commitment]] bet is paid in full at the FLOOR.
- **Steady-state economics held a 7th consecutive time:** every brick cost exactly 1 SKILL + per-seat reference-teeth + extend-the-shared-verifier + extend-the-one-claim + version finishing — zero new gates/claims/guards across seven slices. The strongest available evidence the seam was correctly scoped from the start.
- **The keystone's honest ceiling is the spine's most mature honesty move.** It would have been easy to over-claim "the kit auto-loads its discovery skill." Instead the slice names the un-gateable gap (convention, not enforcement) in four artifacts and proves what it can (exists, indexes all 6, conductor references it). Routes to [[self-hosting-commitment]] as the template for how E10 frames its own acceptance.
- **E10 is unblocked and honestly runnable.** No discovery/invocation gap remains. E10's design should bank: acceptance is measured against the FLOOR convention — the conductor demonstrably consults the keystone and reaches the right skills by reading — not against an auto-injection the FLOOR deliberately does not provide.
- **Standing process held:** governance close folds INTO the feature PR; release-tag only after `git checkout main && git pull`.

**Next: E10 — build a real slice using ONLY the kit's roster + skills, zero superpowers (the acceptance test).** No resequencing proposed.
