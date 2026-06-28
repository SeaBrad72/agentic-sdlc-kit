# Meta-control panel #13 — skill-spine brick #6 (the kit's own `verification` skill)

**Date:** 2026-06-28
**Trigger:** per-slice M verdict (condition A5) for skill-spine brick #6 (v3.62.0).
**Profile:** light (5-lens).
**Verdict:** **GO.**

Brick #6 = the kit's own `verification` (verification-before-completion) skill (`skills/verification/SKILL.md`), a harness-neutral evidence-before-claims discipline, FLOOR-only, wired **DUAL-SEAT** to the **Engineer** (evidence-before-claims) and the **Orchestrator** (confabulation-proofing). **Designed by dogfooding `skills/design/SKILL.md` and planned by dogfooding `skills/plan/SKILL.md`** — 5th self-host use. Built AMBER; dual-reviewed (reviewer APPROVE + security-reviewer PASS); independently proven on a clone (selftest 15/15, `verify --require` 31 controls / 0 failed, idempotent, all 4 defs wired, Reviewer correctly not wired). The panel independently sabotage-reproduced the "generic paraphrase fails" claim and flip-proved both new reference-teeth (cases 14 AND 15) load-bearing.

## The 5 lenses

| Lens | Verdict | Evidence |
|------|---------|----------|
| Scope-coherence & proportion (incl. **dual-seat scrutiny**) | GREEN | Steady-state economics held a 6th time: 1 new SKILL.md + extend the shared verifier + extend the one `skill-spine` claim + version finishing — **no new gate/claim/guard** (`skills/*` glob already covers the file — confirm-don't-add, empirically proven: the guard blocked scratchpad writes of `skills/verification/SKILL.md`+`>>`). The DUAL-SEAT 2nd seat is a **real distinct gate, not decoration**: Engineer ref = evidence-before-claims (self-verify own slice); Orchestrator ref = confabulation-proofing (verify the *integrated* subagent diff). The `## Verification` Orchestrator section mirrors its existing `## Design` and `## Isolation` hat sections — established pattern, not accretion. Honest cost = exactly one extra selftest case (13/14/15 vs the single-seat bricks' 2). |
| Honesty & over-claim | GREEN | CHANGELOG/claim scoped to "toward full replacement (zero runtime dependency on superpowers)" — gated on E10, consistent verbatim across bricks #3–6. The skill does NOT imply runtime enforcement: §5 + SKILL.md state it is craft, "quality un-gateable"; the conformance/clone gates enforce. No superpowers runtime read in the floor defs. |
| Enforcement integrity (green-while-dark) | GREEN (ceiling disclosed) | Cases 14+15 independently flip-to-FAIL (distinct "Engineer/Orchestrator reference teeth vacuous" messages); case 13 marker-teeth fires on dropping `confabulation`. Generic-paraphrase fixture (name+`fresh`+`evidence before claims`, both refs, NO `confabulation`/`clone dry-run`) → rejected exit 1. Teeth rest on the 2 kit-distinctive markers. Declaration-check ceiling (a hollow stub stuffing all 5 markers passes) is intrinsic to FLOOR markdown skills, identical to #1–5, named in §5. |
| Direction & sequencing | GREEN | Verification is the correct brick #6 — the evidence-before-claims discipline this whole effort has lived. Spine converging: only the `using-superpowers`-equivalent discovery keystone remains → E10. The dual-seat precedent is bounded and safe (and useful) for the cross-cutting keystone. No accretion; nothing to resequence/merge/drop. |
| Right-weighting & adoptability | GREEN | ~58-line markdown SKILL, FLOOR-only invoke-by-read, progressive (when-to-use → Iron Law → gate function → confabulation → evidence → tagless → non-vacuity → rationalizations → red-flags). Invisible to a vibe-coder until they claim "done"; a precondition discipline for an architect. Orchestrator 3 refs / Engineer 2 refs = structural-parity wiring (hat section + Responsibilities + Stance), not ceremony. |

Standing "integration-capability / no-dead-ends" lens: **N/A** — pure-markdown FLOOR skill.

## Findings

- **0 blockers · 0 High.**
- **2 Low — confirmed non-blocking, no fix (both = the dual-review Minors, independently re-confirmed):**
  - **L1 — `fresh` (and `evidence before claims`, `name: verification`) are individually weak markers.** A generic-paraphrase fixture containing those three was still rejected exit 1 — the teeth are carried entirely by `confabulation` + `clone dry-run`. Dropping `fresh` to a 4-marker set would change no verdict; keeping it is harmless brick-#1–5 parity (5 markers each). Banked: consider trimming low-entropy markers at a future brick (cosmetic, cross-brick; do not churn this slice). Same class as brick #5's `native`.
  - **L2 — Orchestrator 3 refs / Engineer 2 (asymmetry).** The 3rd Orchestrator ref is the dedicated `## Verification` hat section (structurally identical to `## Design`/`## Isolation`); the Engineer (a non-hat doer) folds into Responsibilities + Stance. The verifier requires ≥1 ref per seat, so the extra refs are emphasis, not vacuity risk. Intentional, parity-consistent.
- **Enforcement caveat (standing, not a finding):** the check is a declaration check — a hollow stub stuffing all 5 marker strings passes. Identical to bricks #1–5, named in §5 ("quality un-gateable — correct for a skill"). The real enforcement is the conformance/clone gate this skill describes, not the skill text.

## Two ledgers

**Ledger 1 — verified-as-quality (ship with confidence):** apply clean + idempotent on the clone (re-run no-op, VERSION pinned 3.62.0); `verify --require` 31 controls / 0 failed / 0 unverified, skill-spine PASS; selftest 15/15 with cases 14 AND 15 independently proven load-bearing; "generic paraphrase fails" sabotage-reproduced (rejected on `confabulation`+`clone dry-run`); dual-seat wiring structurally parity-consistent with the #5 Isolation hat; FLOOR+native mirror parity; `skills/` immutability glob empirically live (two-matcher gap not recurring); honest-ceiling + "toward full replacement" framing consistent across SKILL/CHANGELOG/claim/orchestration.md.

**Ledger 2 — fix-forward (ranked):** nothing blocking. Optional/banked: (a) at a future brick, trim low-entropy markers (`fresh`, `name:`, `evidence before claims`) toward a maximally high-entropy set — cosmetic, cross-brick; (b) the declaration-check ceiling is intrinsic to FLOOR markdown skills — only revisit if a later brick adds real behaviour to verify.

## Retro

- **The dual-seat fork was correctly bounded and self-justifying.** It is the first deviation from the emergent single-seat convention (#1–5), and the design forced it to pay for itself: the 2nd seat is a genuinely distinct gate (self-verify vs integrate-and-confabulation-proof), and dual-seat **strengthened** non-vacuity by requiring two independent reference-teeth (cases 14+15, both proven load-bearing). **Lesson banked:** *a pattern (single-seat) is not a rule; deviating is fine when each leg is independently proven and a first-principles audit clears it.* Routes to [[self-hosting-commitment]] — the keystone (`using-superpowers`-equivalent discovery) is cross-cutting too and may legitimately reference multiple seats; this slice establishes the honest-cost pattern (N seats ⇒ N reference-teeth) it should follow.
- **Steady-state economics held a 6th time:** bricks #1→#6 each cost exactly 1 SKILL + per-seat reference-teeth + extend-the-shared-verifier + extend-the-one-claim + version finishing — zero new gates/claims/guards across six slices.
- **The slice dogfooded its own discipline:** brick #6 was designed + planned by the kit's own skills (5th self-host), and its clone-dry-run build *is a live use of the very verification skill it ships* — the loop is closing on itself.
- **Standing process held:** governance close folds INTO the feature PR; release-tag only after `git checkout main && git pull`.

**Next spine brick: the `using-superpowers`-equivalent discovery keystone** (invoke-by-read floor made kit-native) → then **E10 zero-superpowers acceptance.** No resequencing proposed.
