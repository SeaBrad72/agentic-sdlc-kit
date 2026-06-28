# Meta-control panel #16 — keystone structural self-check (hardening slice, v3.65.0)

**Date:** 2026-06-28
**Trigger:** per-slice M verdict (condition A5) for the keystone structural hardening slice (v3.65.0) — between bricks #8 and #9.
**Profile:** light (5-lens).
**Verdict:** **GO** — 0 blockers, 0 unaddressed highs; 2 Low routed fix-forward.

The slice makes `check_keystone` **enumerate every on-disk `skills/*/SKILL.md`** (excluding the `using-skills` keystone) instead of grepping a hardcoded path list — closing the brick-#8 keystone-index-drift root cause that caused the v3.64.1 hotfix. Verifier-only + one keystone wording tweak. Designed + planned by dogfooding the kit's own design/plan skills (8th self-host). Built AMBER; dual-reviewed (reviewer APPROVE + security-reviewer PASS); independently proven on a fresh clone.

## The 5 lenses

| Lens | Verdict | Evidence |
|------|---------|----------|
| Scope-coherence & proportion | GREEN | Verifier-only: +39/-10 in one file + a 1-line keystone swap + same-id claim wording + version finishing = exactly 6 files; zero new gate/claim-row/guard/seat. Proportionate — the incident's latent root cause was the hardcoded list; disk-enumeration is the minimal fix. Doing it before brick #9 is correct (every remaining brick must update the keystone). |
| Honesty & over-claim | GREEN (1 Low routed) | Design §4 honestly scopes: closes index-DRIFT, NOT the half-landed-commit failure mode (human git-discipline + the separate tag-time CI gate). CHANGELOG matches behaviour. Low residual: keystone PROSE still hardcodes "all seven / seven spine skills" — structural *enforcement* is now literal but the *count prose* is not enforced and will narrate a false count when brick #9 adds the 8th content skill → Low-1 (route to #9). |
| Enforcement integrity (green-while-dark) | GREEN | The key lens, independently re-proven on a clone: **SHA-256 applied == reviewed == decoded base64 payload** (no confabulation); shellcheck clean; selftest 20/20; `verify --require` 31 controls / 0 failed; idempotent no-op; live real-repo run GREEN. **Load-bearing proof (the regression):** on an identical fixture tree with an unindexed novel skill, the STRUCTURAL enumeration exits 1 (catches it) while the OLD hardcoded list exits 0 (passes green) — the teeth ARE the enumeration, not a longer list. Vacuity probe: keystone-only tree exits 0 benignly (the 4 discipline-marker greps + Orchestrator-ref still gate a hollow tree). Injection: a skill dir named `a.b*c d` is matched literally via `grep -qF` (no regex/glob false-match); no-match glob filtered by `[ -f "$d/SKILL.md" ]`. |
| Direction & sequencing | GREEN | Inserting this between #8 and #9 is the panel-#15 banked fix pulled FORWARD (was banked for #10) — a strict improvement: closes recurrence before #9 rather than after #10, protecting #9 (evals) and #10 (discovery). The incident's OTHER half (tag-time CI gate for the admin-merge-of-red-CI) is correctly scoped out and routed. |
| Right-weighting & adoptability | GREEN | Kit-internal conformance gate; N/A outside the kit repo (golden-path scope check). Zero adopter burden, invisible to a vibe-coder, no new infrastructure. |

Standing "integration-capability / no-dead-ends" lens: **N/A** — verifier-only change to an existing gate.

## Findings

- **0 blockers · 0 unaddressed highs.**
- **Low-1 (honesty, route to brick #9):** keystone prose still hardcodes "all seven / seven spine skills" (`skills/using-skills/SKILL.md` lines 3/8/29/42/65). Structural enforcement is now literal but prose count is not enforced — brick #9 (8th content skill) must replace it with count-neutral wording ("every spine skill on disk"). Pre-existing pattern (panel-#15 retro lesson recurring); prose, not a gate; not a blocker.
- **Low-2 (security, pre-existing, route to a separate guard-hardening slice — DO NOT fix here):** CONFIRMED — `conformance/*` is in the guard's path matcher (`is_control_plane_path`, `guard-core.sh:23`, covers Edit/Write tool denials) but NOT in the shell-command-redirect regex (`guard-core.sh:82` and `:85`, which lists `skills/`, `agents/`, `scripts/orchestrator-run.sh`, `.claude`, `.github/workflows` but not `conformance/`). So a shell `sed -i`/redirect against `conformance/*.sh` would be denied by the tool path but NOT by the command matcher — the two-matcher-completeness class, for `conformance/`. Not introduced by this slice. Fix in a dedicated guard-hardening slice (add `conformance/` to lines 82/85).
- **Observation (no action):** the v3.64.1 hotfix is not a meta-control log row (hotfixes aren't panels); marker was `3.64.0 GO`. This slice's row advances it to `3.65.0 GO`.

## Two ledgers

**Ledger 1 — verified-as-quality (ship with confidence):** apply clean + idempotent no-op on a fresh clone (VERSION 3.65.0); SHA-256 applied==reviewed==decoded payload (no confabulation); shellcheck clean; selftest 20/20; `verify --require` 31 controls / 0 failed; live real-repo `check_keystone` GREEN; hardcoded-list regression independently reproduced (struct exits 1 / old list exits 0 on identical tree); case-20 non-vacuity confirmed; `grep -qF` defuses glob/regex-meta injection; literal-glob-no-match filtered; FLOOR-only scope held (6 files, no new gate/claim/guard); honest ceiling consistent across design/plan/CHANGELOG.

**Ledger 2 — fix-forward (ranked):** (1) **Low-1 (brick #9):** count-neutral keystone prose. (2) **Low-2 (separate guard-hardening slice):** add `conformance/` to `guard-core.sh:82/85` shell-redirect regex (symmetry with the path matcher). (3) **Banked (separate slice):** the tag-time CI gate (refuse to tag a red-CI commit) — the incident's other failure mode.

## Retro

- **The panel's own banked fix came home one slice early, and that was right.** Panel #15 banked the structural `check_keystone` for brick #10; pulling it forward to a hardening slice between #8 and #9 was a strict improvement — closes recurrence before #9 reopens it. **Lesson: when a banked anti-drift fix protects all subsequent slices, do it at the next boundary, not the originally-banked one — the stopgap's cost compounds per slice.**
- **Structural enforcement and prose honesty are separate surfaces.** This slice made the *enforcement* disk-truth-based, but the keystone *prose* still hardcodes "seven" — the exact pattern #15's retro flagged. A structural check closes the green-while-dark hole but does not make the narrative count-neutral; do both (→ Low-1).
- **The guard kept blocking the panel's live mutation probes — again — working as designed.** Non-vacuity substantiated via {SHA payload identity + selftest flip + an out-of-tree minimal repro of the enumeration loop}, not in-place mutation. Standing method for control-plane-teeth panels. No proof gap. (It also incidentally surfaced Low-2: the probes were blocked via the `skills/` token, masking that `conformance/` is absent from the command matcher.)
- **Right-weight economics held a 9th time at zero new infrastructure** — verifier-only, 6 files, the incident's latent root cause closed for real on a fresh clone.

**Next: brick #9 (`evals`)** — fold in the count-neutral keystone prose (Low-1). Separately: a guard-hardening slice for Low-2; the tag-time CI gate remains banked. No resequencing of the Phase-2 arc.
