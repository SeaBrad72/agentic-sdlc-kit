# Roster Authority — the kit prefers its own roster, portably, without prohibiting the adopter's

**Date:** 2026-07-02
**Status:** Design — owner-approved in shape (2026-07-02); spec under owner review.
**Skill loop:** authored via the kit's own `design` skill (zero superpowers).
**Slices:** A (FLOOR — this design's build scope) · B (NATIVE teeth — deferred follow-on, scoped here).

---

## 1. Problem

The kit self-hosts a complete process roster — 12 spine skills (`skills/`) + the seats/hats in `agents/` — that replaces (and, by the self-hosting commitment, is meant to *retire*) the external **superpowers** plugin. But the kit has **no mechanism that makes its roster authoritative inside its own repo** when a foreign skill library is present in the adopter's environment.

The failure is concrete and was reproduced this session: superpowers injects a forceful "you MUST invoke my skill before acting" keystone via a `SessionStart` **hook** (`hooks/hooks.json → run-hook.cmd session-start`). The kit's own discovery keystone (`skills/using-skills/SKILL.md`) is, by its own honest admission (its "Entry-point honesty" section), a **convention** — un-gated on the FLOOR. Hard injection beat soft convention: the agent drifted to `superpowers:brainstorming` instead of `skills/design`.

**This is not a Bradley-only problem.** Every adopter runs the kit inside their own harness with their own plugins. The kit cannot assume a clean environment; it must **defend its own roster** against whatever foreign process-skill injection the adopter's environment contains — portably.

### What this is NOT
- **Not** "remove/disable superpowers." The owner uses superpowers legitimately in *other* projects; global disable is the wrong lever. The concern is scoped to *this repo* and to *every adopter's repo*.
- **Not** prohibition. The owner's stance: the kit is **preferred, not mandatory**. Adopters keep the freedom to use what works best for them.

## 2. The load-bearing distinction: drift ≠ choice

Two events look identical at the tool call:
1. **Drift** — the agent auto-reaches for a foreign process skill because the foreign library *injected* a "use me first" prompt. **Nobody chose it.**
2. **Choice** — the user explicitly says "use superpowers' brainstorming here." **A deliberate instruction.**

The kit's existing keystone already encodes the resolution (Instruction priority): **explicit user instruction → governing skill → default behaviour.** A foreign injection lives at the *default/skill* tier, so the kit's roster should beat it — but a genuine user instruction beats the kit too. We are not inventing a rule; we are **enforcing the one already written.**

Therefore the design axis is **default + awareness + override**, never "prohibit vs allow." Prohibition may fire against *drift*; it must never fire against a *user's explicit choice*.

## 3. Stance (owner-approved)

> **Preferred, not mandatory. Default to the kit, surface that a kit equivalent exists, always honor an explicit user choice.**

Four behaviours:
1. **Kit roster is the default** for process work in this repo — declared once, authoritatively.
2. **Awareness, not silence** — when a foreign process skill would duplicate a kit spine skill, the agent uses the kit's *and says so* ("using the kit's `design` skill — it has its own; say the word if you'd rather use superpowers"). The user is never left unaware a kit equivalent exists.
3. **Drift is redirected; choice is honored** — unprompted reach → redirect to the kit; explicit "use X" → allowed (instruction priority).
4. **A dial for teeth (opt-in), shipped OFF** — the enforcement escalates `off → ask → deny` but ships `off` (soft), so out of the box it is preference, not prohibition. Progressive disclosure: a team that mandates the kit turns the same dial up.

## 4. Architecture — two layers

### FLOOR (portable, primary — Slice A, builds now)
Works on any harness; solves the drift for everyone.

- **The contract** — a **"Roster authority"** section added to **`CLAUDE.md`** *and* **`AGENTS.md`**. It must be written as *action-anchored and as forceful* as the injected competitor it overrides (specificity beats specificity — see §7): in this repo the kit roster is the default for process work; a foreign **injected** "use me first" keystone does **not** govern here; precedence is *explicit user instruction → kit roster → foreign default*; an explicit user request for a foreign skill is always honored.
- **Keystone self-defense** — `skills/using-skills/SKILL.md` gains an explicit adversarial clause: the reader may be running where a foreign library injected its own keystone; that injection sits at the *default* tier and **this keystone supersedes it by `CLAUDE.md`/`AGENTS.md` authority**; plus the *prefer-and-surface* behaviour and a pointer to the equivalence map.
- **The equivalence map** (§5) — lives in the keystone (portable source of truth).
- **Conformance lock** (§6) — a doc-coherence check that keeps the FLOOR from rotting.

### NATIVE (Claude Code, opt-in teeth — Slice B, deferred; scoped here)
- Extend the guard (`.claude/hooks/`): add `Skill` to the PreToolUse matcher; a mode dial `off | ask | deny` (**default `off`**); a **configurable blocklist of process-libraries** seeded with `superpowers` (adopter-extensible), sourced from the same equivalence map so the two never diverge.
- A short **adopter-facing doc** (`docs/adoption/`, vc-hosts style) explaining: your environment may carry foreign skill libraries; the kit prefers its own roster by default; here is the dial and how to extend the blocklist.
- **Not built now** (YAGNI teeth until the FLOOR is in place; the owner chose FLOOR-first). Scoped here so Slice B is a second caller, not a rebuild.

## 5. The foreign→kit equivalence map (the substance)

Every superpowers process skill already has a 1:1 kit counterpart. This map is what "surface awareness" (Slice A) and the guard blocklist (Slice B) both read:

| Foreign (superpowers) | Kit equivalent |
|---|---|
| `brainstorming` | `skills/design` |
| `writing-plans` | `skills/plan` |
| `subagent-driven-development` / `executing-plans` | `skills/build` |
| `test-driven-development` | `skills/tdd` |
| `requesting-code-review` / `receiving-code-review` | `skills/review` |
| `verification-before-completion` | `skills/verification` |
| `systematic-debugging` | `skills/debugging` |
| `using-git-worktrees` | `skills/worktrees` |
| `using-superpowers` | `skills/using-skills` |

**Utility skills with no kit counterpart** (figma, vercel, LSPs, git helpers, MCP tools) are deliberately **absent** from the map → never intercepted, never surfaced against. The map targets *process overlap* only. The map is **directional and non-exhaustive by design**: it seeds the known competitor (superpowers); the portable contract is the generalizing catch-all for any other injected process framework.

## 6. Conformance / anti-rot (Slice A)

A doc-coherence check `conformance/roster-authority-ready.sh` (modelled on `artifact-lineage-ready.sh` / `gate-eval-secrets-ready.sh`; a **`[doc]` check, not a claim** — doc-ready checks are not claims, so no `claims.tsv`/`REQUIRED_IDS` entry; registered in `verify.sh`, doc-check count 15 → 16).

Asserts (positive liveness anchor + load-bearing negatives):
- the **"Roster authority"** section is present in **both** `CLAUDE.md` and `AGENTS.md` (delete from either → FAIL);
- the keystone carries the **self-defense clause** (remove it → FAIL);
- the equivalence map **covers every spine skill on disk** — cross-checked against `skills/*` so a new spine brick that isn't mapped → FAIL (mirrors how `check_keystone` enforces index-completeness);
- non-vacuity: a fixture with the section/clause/map entry removed must make the check FAIL (each negative load-bearing, one assertion per fixture line per the shared-fixture-line non-vacuity retro).

**kit-self applicability:** this check runs on the kit itself (the kit *is* the reference adopter for its own roster) — unlike adopter-conformance checks it is not N/A.

## 7. Why this actually stops the drift (root cause)

The drift this session was **not** an impossibility — the kit's `CLAUDE.md` was loaded and authoritative, and both keystones document that user/CLAUDE.md instructions outrank skills. It happened because the injected superpowers block was **specific and action-oriented** ("invoke brainstorming BEFORE any response"), while `CLAUDE.md` was principle-oriented. **Specificity beat specificity.** The fix is to make the contract *as action-anchored and forceful as the competitor*, delivered through the one channel that is **guaranteed-loaded every session on Claude Code — `CLAUDE.md`** (a stronger guarantee than any skill auto-load). That is the load-bearing property of Slice A.

## 8. Honest ceiling

- On **Claude Code**, the contract is *guaranteed-delivered* (`CLAUDE.md` auto-loads every session) → a **strong steer**, not a hard block.
- On a **neutral harness**, delivery depends on the harness loading `AGENTS.md` — provided-and-coherence-proven, but consultation is un-gateable on the FLOOR (same honest gap the keystone already discloses).
- With the dial **`off`** (the shipped default), drift is **steered, not hard-prevented** — a guarantee exists only at `ask`/`deny` (Slice B).
- Even **`deny`** is blunt: the guard sees a tool call, not intent, so it can over-block a genuine user choice unless overridden (env/flag). This bluntness is *why* the honest default is `off`/soft.
- The check proves the contract is **present and coherent**, not that an agent **obeyed** it at runtime — presence, not behaviour.

## 9. Kit design-discipline check (from `skills/design`)
- **Is the provable thing the meaningful thing?** Yes — the meaningful thing (agent uses the kit roster) is steered by a guaranteed-loaded, action-forceful contract; the *provable* thing (contract present + coherent + map-complete) is the honest, non-tautological floor beneath it. We do **not** claim to prove runtime obedience (that would be the easier adjacent lie).
- **Right-weight / anti-ceremony.** Slice A adds **one** doc-coherence check and edits existing authority files + one keystone — no new gate machinery, no new claim. Slice B *extends* the existing guard rather than adding a parallel mechanism.
- **Control-plane completeness.** Slice A touches control-plane paths (`skills/`, `conformance/`, and likely `CLAUDE.md`/`AGENTS.md`) → built as GREEN bricks + an AMBER `apply.py` that materializes them (the dev guard blocks direct agent Write/Edit there). Slice B (guard edit) is the higher-risk control-plane change and gets the full three-matcher + agent-autonomy-fixture treatment then.
- **Progressive disclosure.** Soft by default (preference); teeth are an opt-in dial.
- **Non-vacuity.** The lock ships with load-bearing negatives (§6).

## 10. Slice A build scope (what ships now)
1. "Roster authority" section in `CLAUDE.md`.
2. "Roster authority" section in `AGENTS.md` (harness-neutral mirror).
3. Self-defense clause + prefer-and-surface behaviour + equivalence-map pointer in `skills/using-skills/SKILL.md`.
4. The equivalence map (§5) in the keystone.
5. `conformance/roster-authority-ready.sh` + `verify.sh` registration + non-vacuous `--selftest`.
6. Version/README/CHANGELOG finishing folded into `apply.py` (per the standing release-finishing-in-apply-py practice).

Slice B (guard dial + adopter doc) is a separate design→plan→build once Slice A is merged.

## 11. Open questions for owner review
- Naming: `conformance/roster-authority-ready.sh` — acceptable, or prefer a different name (e.g. `own-roster-ready.sh`)?
- Does the equivalence map (§5) miss any foreign process skill you care about, or include one that shouldn't be there?
- Confirm Slice A is `[doc]`-check-only (no new claim) — consistent with E11/E6-d precedent.
