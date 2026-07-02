# Roster Authority — Slice B (NATIVE teeth: the opt-in guard dial)

**Date:** 2026-07-02
**Status:** Design — owner-approved in shape (2026-07-02); spec under owner review.
**Skill loop:** authored via the kit's own `design` skill (zero superpowers).
**Parent design:** `docs/architecture/2026-07-02-roster-authority-design.md` (§4 NATIVE scoped this slice).
**Slice A (FLOOR):** shipped v3.93.0, PR #244 — the portable contract + keystone self-defense + `[doc]` lock.

---

## 1. Problem / what this adds
Slice A made the kit's roster the default *by contract* (CLAUDE.md/AGENTS.md + keystone) — a strong steer, but un-gated on the FLOOR (an agent can still be talked past it). Slice B adds the **opt-in hard teeth for adopters who want enforcement**: a Claude-Code guard dial that intercepts a foreign *process-skill* invocation and either asks or blocks — **shipped OFF**, so out of the box it stays preference, not prohibition. This is the NATIVE half of the layered design; it does not replace the FLOOR (other harnesses still rely on the contract alone).

## 2. Owner decisions (ratified 2026-07-02)
- **Ship OFF everywhere** — `.kit/roster.conf` ships `MODE=off` for adopters AND the kit itself. The dial's correctness is proven by its conformance selftest fixtures, so the kit need not self-enable to prove it; the kit stays zero-superpowers by discipline + the FLOOR contract.
- **Config file + env override** — `.kit/roster.conf` is the durable setting; `KIT_ROSTER_GUARD` overrides `MODE` per session.

## 3. Architecture (all touched paths are control-plane → AMBER)
- **`.kit/roster.conf`** (new, mirrors `.kit/budget.conf`): `MODE=off` + `BLOCKLIST="superpowers"` (space-separated process-library **namespaces**, adopter-extensible). Ships OFF.
- **`.claude/hooks/guard-core.sh`** (the #2 high-risk file): new pure `guard_check_skill(name)`:
  - resolve `MODE` = `KIT_ROSTER_GUARD` env if set, else `.kit/roster.conf` `MODE`, else `off`;
  - `MODE=off` → allow;
  - split `name` on `:` to get the namespace; if it is in `BLOCKLIST` → return the dial verdict (`ask`/`deny`) + a redirect reason naming the kit equivalent and the override; else allow.
  - **Fail-safe:** unreadable/missing config → treat as `off` (never block on a config error — a broken config must not wedge the session; the FLOOR contract still steers).
- **`.claude/hooks/guard.sh`** (thin adapter): add a `Skill)` case that extracts `.tool_input.skill` and calls `guard_check_skill`, plus an `emit_ask()` (`permissionDecision:"ask"`). Delegates all logic to the core (single-source-of-truth preserved).
- **`.claude/settings.json`**: add `Skill` to the PreToolUse matcher (`Bash|Write|Edit|NotebookEdit|Read|Skill|mcp__.*`).
- **`conformance/roster-guard-wired.sh`** (new control check): asserts the matcher includes `Skill`, `guard_check_skill` exists, defaults off, and honors the blocklist — with agent-autonomy-style fixtures: `off→allow`, `deny`+`superpowers:brainstorming`→deny, `deny`+`figma:*`→allow (utility passes), `ask`→ask, config-missing→allow (fail-safe). Non-vacuous (each fixture a load-bearing negative). New claim `roster-guard`.
- **`docs/adoption/skill-rosters.md`** (new, vc-hosts style): the adopter recipe — your env may carry foreign process-skill libraries; the kit prefers its own (Slice A contract); the opt-in dial (`MODE`, `BLOCKLIST`, the env override); how to extend the blocklist; the honest ceiling. Indexed beside `vc-hosts.md`/`brownfield.md`.

## 4. Dial semantics
- **off** (default): never intercept; Slice A's contract does the steering.
- **ask**: `permissionDecision:"ask"` — the user confirms; reason names the kit equivalent ("kit has its own `design` — proceed with superpowers anyway?").
- **deny**: blocked + redirect reason. **Override:** a user who genuinely wants the foreign skill sets `KIT_ROSTER_GUARD=off` (or `ask`) for that session — so `deny` is never an absolute prohibition (preserves "preference, not prohibition" even at the hard setting).
- **Blocklist is namespace-based** (seeded `superpowers`): superpowers is a process library, so blocking its namespace is right; utility namespaces (figma, vercel, LSPs) are absent → never intercepted.

## 5. Honest ceiling
- **Claude-Code-only (NATIVE).** Other harnesses get only the FLOOR contract; this dial is a bonus where the harness supports PreToolUse hooks.
- **The guard sees a tool call, not intent** — it cannot distinguish drift from a deliberate choice, so `deny` is blunt by nature. That is *why* it ships `off` and `ask` is the recommended middle, and why `deny` always has the env override.
- **Proves the mechanism is wired + each mode behaves** (selftest fixtures), NOT that any real session had the dial on — enforcement is the adopter's opt-in.

## 6. Kit design-discipline check (from `skills/design`)
- **Right-weight:** extends the existing guard (new function + one adapter case + matcher entry) rather than adding a parallel enforcement mechanism; config reuses the `.kit/` precedent.
- **Control-plane completeness:** edits `guard-core.sh` (the highest-risk file) — gets the full **security review** whose job is to try to *bypass* the Skill check (namespace-spoofing, config-tampering, the fail-safe direction) and to confirm the fail-safe is toward `off` (a config error must not wedge the session) while a *deny* can't be trivially evaded. Uses the differential/fixture approach: agent-autonomy fixtures per mode.
- **Non-vacuity:** every fixture is load-bearing (a dead check fails at least one).
- **Progressive disclosure:** off → ask → deny is the same dial, surfaced by need.
- **Honest ceiling stated** (above), matching the FLOOR's.

## 7. Build scope (what ships)
1. `.kit/roster.conf` (MODE=off, BLOCKLIST=superpowers).
2. `guard_check_skill()` in `guard-core.sh` + fail-safe.
3. `Skill)` case + `emit_ask()` in `guard.sh`.
4. `Skill` added to the settings.json PreToolUse matcher.
5. `conformance/roster-guard-wired.sh` + claim `roster-guard` + verify.sh/CI registration + non-vacuous selftest.
6. `docs/adoption/skill-rosters.md` + discoverability (index beside the other adoption bridges; Slice A's keystone/contract can point to it).
7. Version finishing folded into apply.py (→ 3.94.0).

Build model: **AMBER** (guard-core.sh, guard.sh, settings.json, conformance/, .kit/ are control-plane). GREEN bricks under scratchpad + idempotent apply.py, clone-proven **commit-first** (Slice A lesson), human applies.

## 8. Open questions for owner review
- Check name `roster-guard-wired.sh` + claim id `roster-guard` — acceptable?
- `.kit/roster.conf` key names (`MODE`, `BLOCKLIST`) + env var `KIT_ROSTER_GUARD` — acceptable?
- Is a new **claim** (control check) right here (vs a `[doc]` check)? This one asserts *behaviour* (the guard actually allows/asks/denies per mode via fixtures), so it is a genuine control/claim — unlike Slice A's presence-only `[doc]` lock.
