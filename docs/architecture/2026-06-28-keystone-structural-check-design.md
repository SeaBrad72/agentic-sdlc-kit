# Keystone structural self-check — hardening slice (v3.65.0)

**Date:** 2026-06-28
**Epic / slice:** E3 → **hardening slice** (not a skill brick — verifier-only). Closes the keystone-coupling failure mode that caused the brick-#8 v3.64.1 hotfix. Sits between brick #8 (`debugging`, shipped v3.64.1) and brick #9 (`evals`). Toward [[self-hosting-commitment]] / E10.
**Status:** Design converged — **designed by dogfooding `skills/design/SKILL.md`** (8th self-host use), owner-ratified 2026-06-28 (verifier-only; the tag-time CI gate explicitly NOT folded in — separate slice). Ready for the implementation plan (dogfoods `skills/plan/SKILL.md`).
**Tracked here** because it changes a conformance gate's enforcement model and must be resumable cold.

**Reads-first for a cold resume:** [[reprioritized-backlog]] (the INCIDENT note + the banked structural fix this implements), `conformance/orchestrator-loop-wired.sh` (the verifier — `check_keystone` at ~line 150), `skills/using-skills/SKILL.md` (the keystone), and `docs/architecture/2026-06-28-meta-control-15.md` (panel #15, which surfaced H1).

## 0. Why this slice (the decision trail)

Brick #8 (`debugging`) bit the keystone coupling **twice**: (H1) the slice grew the spine to a 7th content skill but did not update the discovery keystone's index — caught by the meta-control panel, not per-slice review; then (the incident) the H1 fix itself **half-landed** (the verifier change requiring `skills/debugging` committed, but the matching keystone index row did not), shipping a RED commit to main via an `--admin` merge that bypassed the `conformance` gate → v3.64.1 hotfix. Root cause of the *latent fragility*: `check_keystone` greps a **hardcoded path list**, so "forgot to index a new skill" only fails the gate if the verifier's own list was also updated — and the keystone index can drift green relative to what's actually on disk. **Every remaining brick (#9 evals, #10 discovery) must update the keystone, so this fragility will recur** until the check is made structural. Owner-ratified (2026-06-28): do this small verifier-only hardening BEFORE brick #9.

### Scope decision (owner-ratified): verifier-only; the tag-time CI gate is a SEPARATE slice
This slice is tightly scoped to the keystone structural check. The tag-time CI gate (release-tag.sh refusing to tag a red-CI commit — the incident's *other* failure mode, now trigger-fired) is a bigger forge-neutral design and is NOT folded in here.

## 1. What this slice is
Replace `check_keystone`'s hardcoded index-path list with a **dynamic enumeration of every `skills/*/SKILL.md` on disk**, so any skill not indexed by the keystone fails the gate — no per-skill verifier edit required. Verifier-only (+ one keystone wording tweak). **FLOOR-only**, AMBER (control-plane verifier).

## 2. The change

### 2a. `conformance/orchestrator-loop-wired.sh` — `check_keystone` becomes structural
Today (post-hotfix) `check_keystone` does:
```
for p in "skills/design" "skills/plan" "skills/tdd" "skills/review" "skills/worktrees" "skills/verification" "skills/debugging"; do
  grep -qF "$p" "$s" || { echo "FAIL: ... index not exhaustive"; miss=1; }
done
```
Change to: derive `SKILLS_DIR` from the keystone path (`SKILLS_DIR=$(dirname "$(dirname "$s")")` → the `skills/` dir, real-run or fixture), then enumerate:
```
for d in "$SKILLS_DIR"/*/; do
  name=$(basename "$d")
  [ "$name" = "using-skills" ] && continue          # the keystone need not index itself
  [ -f "$d/SKILL.md" ] || continue                  # only real skills
  grep -qF "skills/$name" "$s" || { echo "FAIL: $s does not index on-disk spine skill 'skills/$name' (index not exhaustive)"; miss=1; }
done
```
The discipline-marker greps (`name: using-skills`, `invoke by reading`, `before acting`, `user instructions`) and the Orchestrator-reference assertion are unchanged. **Effect:** the index is now checked against ground truth (the filesystem), not a list the verifier author must remember to update.

### 2b. New selftest **case 20** — the structural teeth (load-bearing)
A hardcoded list and a dynamic enumeration are indistinguishable to the *existing* cases (which only drop a *known* path). To prove the enumeration is real: case 20 builds a conformant fixture, then adds a skill dir with a **novel name not in any prior hardcoded list** — `skills/zzz-probe/SKILL.md` — and does NOT add `skills/zzz-probe` to the keystone → assert **exit 1**. A structural check catches it; a hardcoded-list check would not. This is the distinctive non-vacuity proof for this slice.
- Existing **case 16** (keystone omits a known path, e.g. `skills/verification`) keeps working and now exercises the same enumeration — kept as the "drops a real skill" case.
- Cases 1–19 fixtures are unaffected (their `skills/*` dirs are all indexed by `_keystone_ok`).

### 2c. `skills/using-skills/SKILL.md` — one wording tweak
The hotfix added "…the index is exhaustive by design, and `check_keystone` enforces it, so every new skill brick must add its row here." Tighten to make the *structural* enforcement literal: "…`check_keystone` enforces it **against every `skills/*` on disk**, so every new skill brick must add its row here." (Markdown only; no marker churn — `check_keystone`'s discipline markers are unchanged.)

## 3. Conformance (right-weighted — no new gate, no new claim row)
- Reuses the existing `skill-spine` claim + the `orchestrator-loop-wired.sh` verifier. Optionally tighten the claim's wording ("…`check_keystone` enforces the index against every on-disk `skills/*`…") — a text tweak, same claim id + command.
- The single new selftest case 20 is the slice's non-vacuity proof; case 16 retained.
- No new claim, no new gate, no guard edit (`skills/*` + `conformance/*` already control-plane).

## 4. Honest ceiling & scope
- **Closes the index-drift hole for real** — after this, a skill on disk but absent from the keystone is RED on a fresh clone (the brick-#8 H1 failure mode becomes un-shippable-green). It does NOT prevent a *half-landed commit* (the incident's other half) — that is the human-process discipline (`git show --stat` after committing) + the tag-time CI gate (separate slice).
- **Verifier-only** — no new skill, no seat change, no behavior change to the keystone content beyond one wording line.
- **Bootstrap** — the kit's design + plan skills produced this slice (8th dogfood).
- **Does not renumber the spine** — still 7 content skills + the keystone; this is hardening, not a brick.

## 5. Build approach
Control-plane slice (`conformance/orchestrator-loop-wired.sh` + one line of `skills/using-skills/SKILL.md` + optional `conformance/claims.tsv` wording; version finishing **3.64.1 → 3.65.0**) → **AMBER `apply.py`**, clone dry-run incl. shellcheck + `verify --require` + the case-20 flip proof → **dual review** (reviewer: is the enumeration correct + case 20 genuinely load-bearing [a hardcoded list would miss the novel skill]; security: low surface — verifier logic only, confirm no path-traversal/glob-injection in the enumeration, confirm `skills/*` immutability holds) → **light 5-lens meta-control panel #16** (A5) → **fold the governance close INTO the feature PR**. Subagent-driven build; the human applies/merges/release-tags — **and this time: `git show --stat HEAD` to confirm the keystone + verifier are both in the commit, admin-merge only when `conformance` is GREEN.**

## 6. Convergence record (owner-ratified 2026-06-28)
Designed by dogfooding `skills/design/SKILL.md` (8th self-host use). Verifier-only hardening: `check_keystone` enumerates every on-disk `skills/*/SKILL.md` (excluding the keystone) instead of a hardcoded list, so the keystone index cannot drift green relative to disk. Distinctive non-vacuity = case 20 (a novel-named skill on disk, unindexed → exit 1; a hardcoded list would miss it). One keystone wording tweak makes the structural enforcement literal. Tag-time CI gate explicitly NOT folded in (separate slice). Right-weighted (no new gate/claim/guard). **Next: the implementation plan, dogfooding `skills/plan/SKILL.md`; then brick #9 `evals` on the now-hardened keystone coupling.**
