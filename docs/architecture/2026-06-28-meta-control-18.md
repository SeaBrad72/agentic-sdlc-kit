# Meta-control panel #18 — skill-spine brick #10, the kit's own `continuous-discovery` skill (Phase 2 COMPLETE)

**Date:** 2026-06-28
**Trigger:** per-slice M verdict (condition A5) for skill-spine brick #10 (v3.67.0) — the **last** brick of Skill-Spine Phase 2.
**Profile:** light (5-lens).
**Verdict:** **GO** — 0 blockers, 0 unaddressed highs; the reviewer's lone Minor was **resolved in-slice** (panel-#17 Ledger-2 item 1, the count-neutral sweep, is now CLOSED); 1 new Low (pre-existing hygiene) banked.

Brick #10 = the kit's own `continuous-discovery` skill (`skills/continuous-discovery/SKILL.md`) — problem-space product discovery (Teresa Torres), the front of the loop and the partner to `design`'s solution-space, a **KIT-ORIGINAL** (no superpowers equivalent; its `brainstorming` is solution-space = the kit's `design`). Owner-reframed to the human↔AI **discovery partner** (the human is the PO; the agent structures + keeps honest, never decides). FLOOR-only invoke-by-read, wired **single-seat** to the Orchestrator (new **Product hat**, before the Architect hat). Designed + planned by dogfooding the kit's own design/plan skills (10th self-host). Built AMBER; dual-reviewed (reviewer APPROVE + security-reviewer PASS); independently proven on a fresh clone.

## The 5 lenses

| Lens | Verdict | Evidence |
|------|---------|----------|
| Scope-coherence & proportion | GREEN | 10 files, no new gate/claim-row/guard. Single-seat `check_discovery_skill` mirrors `check_worktrees_skill` (skill-exists + 6 markers + Orchestrator ref); single-seat is correct (the human is the PO → no Product *seat*, agents-vs-skills). The skill POINTS AT existing discovery infra (`FEATURE-REQUEST` template, DoR success-metric item, `discovery-complete.sh`) and hands off to `design` — does not duplicate. The banked count-neutral sweep (orch defs **and** verifier comments `:697`/`:857`) was folded in *because this slice already edited those files* — opportunistic debt-clearing, not scope creep. |
| Honesty & over-claim | GREEN | Kit-original framing verified: claims.tsv + orchestration.md say "bricks #1-8 replace superpowers; evals and continuous-discovery add crafts superpowers lacks" — no "replaces superpowers" coupled to continuous-discovery. The skill states an explicit **Honest ceiling** ("discovery *quality* is un-gateable… never let a green check imply the discovery was good") and cedes outcome-rigor enforcement to the DoR success-metric item + `discovery-complete.sh`. The partner framing is honest about the capability boundary (the human decides; the agent enables). |
| Enforcement integrity (green-while-dark) | GREEN | Re-proven on a fresh clone: security review confirmed the embedded base64 blobs decode **byte-identical** to the reviewed SKILL.md + verifier (no confabulation); selftest 25/25; shellcheck clean; `verify --require` 31/0 failed; idempotent re-run; structural `check_keystone` GREEN with `skills/continuous-discovery` indexed. Cases 24 (marker teeth — drop `outcome over output`) + 25 (Orchestrator omits the reference) **flip-proven load-bearing** (fixing the defect makes the selftest FAIL). |
| Direction & sequencing | GREEN | The right last Phase-2 brick. **The structural keystone check (v3.65.0) protected this slice** — the live (non-selftest) verifier passes only because apply.py added the keystone row in the same slice; a forgotten row goes RED on a fresh clone (the brick-#8 trap, now structurally impossible). **This COMPLETES the intended Phase-2 spine** (debugging → evals → continuous-discovery) — so E10 becomes a *true* zero-superpowers acceptance test against the complete spine, not a partial one. |
| Right-weighting & adoptability | GREEN | Invoke-by-read, zero adopter burden, invisible until an adopter runs discovery. Heavy live discovery/research infra out of scope; this is the cheap FLOOR craft brick. |

Standing "integration-capability / no-dead-ends" lens: **N/A** — FLOOR skill + verifier extension.

## Findings

- **0 blockers · 0 unaddressed highs.**
- **Reviewer Minor (RESOLVED in-slice):** the two stale "all seven" verifier comments (`orchestrator-loop-wired.sh:697`/`:857`) — panel-#17 Ledger-2 item 1. Folded into the generator + apply.py while the file was already open; re-proven on a fresh clone (zero "all seven" remain). **The count-neutral sweep is now fully discharged** (orch defs were the other half, also in this slice).
- **Marker strength (positive note):** unlike evals (panel-#17 Low-1, 4/5 generic vocabulary), continuous-discovery carries **two genuinely kit-distinctive markers** — `discovery partner` (the human-as-PO reframe) + `outcome over output` (the north-star) — that a generic Torres tutorial fails, alongside the genuine-craft anchors (`opportunity solution tree`, `riskiest assumption`, `small bet`). The teeth rest on the kit-coined pair; stronger discrimination than the prior brick.
- **Low-1 (new, hygiene — banked):** `orchestrator-loop-wired.sh` selftest has no `trap`/cleanup removing the `mktemp -d` sandbox (leaves a temp dir). Pre-existing pattern across all spine bricks, not introduced here; no security or correctness impact. Route as an observation for a future verifier touch.

**Nothing blocks.** The one reviewer Minor was fixed before ship; the new Low is pre-existing hygiene.

## Two ledgers

**Ledger 1 — verified-as-quality (ship with confidence):** base64 applied==reviewed, byte-identical (SKILL + verifier, security-confirmed, no confabulation); selftest 25/25; cases 24/25 flip-proven load-bearing (2 distinct teeth); shellcheck clean; live verifier exit 0; `verify --require` 31/0 failed; idempotent; structural `check_keystone` GREEN with continuous-discovery indexed (the v3.65.0 check forced the row — it protected this slice); single-seat check correct (mirrors worktrees); kit-original claim wording verified; honest ceiling explicit (discovery quality un-gateable, cedes to DoR + discovery-complete.sh); skill points-at-not-duplicates the discovery infra; `skills/` immutability confirmed by security (no two-matcher gap — live guard exercised against the new path); no new control-plane surface / no guard/registry/verify.sh/export edits; **the count-neutral sweep fully discharged** (orch defs + verifier comments); one-term-one-meaning naming honored; exactly 10 files; FLOOR-only; zero adopter burden.

**Ledger 2 — fix-forward (ranked):**
1. **Guard-hardening slice (banked from #16)** — add `conformance/` to `guard-core.sh:82/85` shell-redirect regex (two-matcher symmetry for `conformance/` specifically; security confirmed `skills/` is already covered in both matchers).
2. **Tag-time CI gate (promoted to BUILD at panel #17)** — `release-tag.sh` refuses to tag a commit whose main CI conclusion is `failure` (wait-for-conclusion, forge-neutral graceful skip). The brick-#8 incident filled the "empty surface."
3. **mktemp cleanup (Low-1, observation)** — add a `trap … EXIT` to the verifier selftest sandbox when next touching it.
4. **Optional conformance grep** banning a hardcoded spine-count in *live* (non-historical) prose, so the count-drift class self-closes (the sweep is done, but nothing prevents reintroduction).

## Retro

- **Fold banked cosmetic debt into any slice that already opens the file.** Panel #17's count-neutral sweep (orch defs + verifier comments) was a separate banked slice; brick #10 edited those exact files anyway, so the whole sweep got discharged for ~free — and the reviewer caught the two comments I'd missed. Lesson: when a slice touches a file carrying banked cosmetic debt, clear it in the same slice; a standalone cosmetic slice is pure overhead by comparison.
- **Rename at creation beats coexistence when a new concept shares a word with an entrenched term.** "Discovery" already meant skill-discovery (the keystone). Naming the new craft `continuous-discovery` (not bare `discovery`) cost nothing at creation — the artifact didn't exist yet — and avoided a permanent two-meanings-one-word ambiguity in the orchestrator def. Had it shipped as `discovery`, the rename later would have touched the marker, the keystone row, the claim, and the wiring. One-term-one-meaning is cheapest enforced up front.
- **Phase-2 is complete and E10 is now a true acceptance test.** The spine covers Discover → Plan → Build → Review plus the debugging/evals crosscuts. E10 (build a real slice using only the kit's roster + skills) now measures against the *complete* intended spine — the honest precondition for calling the self-hosting thesis proven.

**Next: E10 — zero-superpowers acceptance** (build a real slice using only the kit's own roster + skills, measured against the FLOOR convention's honest ceiling). The Phase-2 skill spine is complete. Banked hardening (guard-hardening, tag-time CI gate) can batch before or alongside E10.
