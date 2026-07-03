# Plan — Roster Authority, Slice B (NATIVE guard dial)

**Design:** `docs/architecture/2026-07-02-roster-authority-slice-b-design.md` (owner-approved).
**Skill loop:** authored via the kit's own `plan` skill (zero superpowers).

## Goal
Add the opt-in Claude-Code guard dial (`off|ask|deny`, ships OFF) that intercepts a foreign process-skill invocation — hard teeth for adopters who want them, without changing the default (preference, not prohibition).

## Architecture
A `.kit/roster.conf` dial + `guard_check_skill()` in `guard-core.sh` (single source of truth) + a thin `Skill)` case in `guard.sh` + a `Skill` matcher entry. The config file is itself control-plane so the agent can't self-disable the dial. A behavioural conformance claim proves each mode; an adoption doc gives adopters the recipe.

## Tech stack
POSIX sh (dash-clean) for guard + conformance; JSON for settings.json; shell `KEY=value` for `.kit/roster.conf`; Python 3 for apply.py; Markdown for the adoption doc.

## Global constraints (verbatim from the design)
- **Ships OFF everywhere** (adopters + the kit). Correctness proven by selftest fixtures, not by self-enabling.
- **Fail-safe toward off:** unreadable/missing config → allow (a config error must never wedge the session; the FLOOR contract still steers).
- **`deny` always has the `KIT_ROSTER_GUARD=off` override** — never an absolute prohibition.
- **Namespace-based blocklist** (seeded `superpowers`); utility namespaces (figma, vercel, LSPs) are absent → never intercepted.
- **Single source of truth:** all deny/verdict logic in `guard-core.sh`; `guard.sh` stays a thin adapter.
- **The config file is control-plane** — agent cannot edit `.kit/roster.conf` to disable the dial.

## Build model — **AMBER** (touches the highest-risk file)
`guard-core.sh`, `guard.sh`, `settings.json`, `conformance/`, `.kit/roster.conf` are control-plane. Author GREEN under `scratchpad/roster-b/`, assemble one idempotent `apply.py`, **clone-prove commit-first** (Slice A lesson), human applies. `guard-core.sh` is the #2 watch file → a heavy, bypass-focused security review is mandatory.

---

## File structure

| File | CP? | Responsibility | Change |
|---|---|---|---|
| `.kit/roster.conf` | yes | The dial: `MODE=off`, `BLOCKLIST="superpowers"` | new |
| `.claude/hooks/guard-core.sh` | yes (#2) | `guard_check_skill()` + protect `.kit/roster.conf` in all 3 matchers | +function, +CP entry |
| `.claude/hooks/guard.sh` | yes | `Skill)` case + `emit_ask()` | +case |
| `.claude/settings.json` | yes | add `Skill` to PreToolUse matcher | +matcher token |
| `conformance/roster-guard-wired.sh` | yes | behavioural claim: each mode + fail-safe | new |
| `conformance/claims.tsv` | yes | register `roster-guard` | +row |
| `conformance/verify.sh` | yes | register control check + REQUIRED_IDS | +line |
| `conformance/agent-autonomy.sh` (or the existing autonomy check) | yes | fixtures: agent can't Write/`>`/`sed -i` `.kit/roster.conf` | +fixtures |
| `.github/workflows/ci.yml` | yes | wire `roster-guard-wired.sh --selftest` | +step |
| `docs/adoption/skill-rosters.md` | no | adopter recipe (vc-hosts style) | new |
| `VERSION`/`README.md`/`CHANGELOG.md` | no | 3.93.0 → 3.94.0 | bump |

---

## Concrete content (no placeholders)

### `.kit/roster.conf`
```
# Roster-authority guard dial (Slice B). See docs/adoption/skill-rosters.md.
# MODE: off (default) | ask | deny. Override per-session with KIT_ROSTER_GUARD.
MODE=off
# Space-separated process-library namespaces the kit prefers its own roster over.
BLOCKLIST=superpowers
```

### `guard_check_skill()` in `guard-core.sh` (pure; sourced by guard.sh + the conformance check)
Signature: `guard_check_skill <skill_name>` → prints a verdict token on the first line (`allow` | `ask` | `deny`) and, for ask/deny, a reason; returns 0 always (the adapter maps the token to a permission decision).
Logic:
1. `mode="${KIT_ROSTER_GUARD:-}"`; if empty, read `MODE=` from `.kit/roster.conf` (repo-root-relative); if unreadable/absent → `mode=off`.
2. `mode=off` → print `allow`; return.
3. namespace = part of `<skill_name>` before the first `:` (no colon → whole string).
4. read `BLOCKLIST=` from config (fail-safe empty); if namespace ∉ blocklist → print `allow`; return.
5. namespace ∈ blocklist → print `<mode>` (`ask`/`deny`) + reason: "kit prefers its own roster (`skills/<equiv>`); see skills/using-skills/SKILL.md. To use `<skill_name>` anyway, set KIT_ROSTER_GUARD=off for this session."
Fail-safe invariant: any parse/read error routes to `allow` (never wedge the session).

### `guard.sh` — add before the `*)` case
```
Skill)
  SK=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // .tool_input.name // empty' 2>/dev/null || printf '')
  v=$(guard_check_skill "$SK"); tok=$(printf '%s' "$v" | head -n1); reason=$(printf '%s' "$v" | sed -n '2,$p')
  case "$tok" in
    ask)  emit_ask "$reason" ;;
    deny) emit_deny "$reason" ;;
    *)    allow ;;
  esac ;;
```
plus `emit_ask()` mirroring `emit_deny()` with `permissionDecision":"ask"`.

### `.claude/settings.json` matcher
`"Bash|Write|Edit|NotebookEdit|Read|Skill|mcp__.*"`

### Control-plane protection of `.kit/roster.conf` (guard-core.sh)
Add `.kit/roster.conf` to: (a) `is_control_plane_path` case, (b) the Bash command-scan regex, (c) the `>`-redirect regex — mirroring how `.kit/budget\.conf` already appears in the command-scan. This is the load-bearing security property.

### `conformance/roster-guard-wired.sh` (behavioural claim `roster-guard`)
Source `guard-core.sh`; drive `guard_check_skill` with a temp config + env. Assertions (each a load-bearing `--selftest` case):
- MODE=off → `superpowers:brainstorming` → `allow`.
- MODE=deny → `superpowers:brainstorming` → `deny`.
- MODE=deny → `figma:make` (utility, not in blocklist) → `allow`.
- MODE=ask → `superpowers:tdd` → `ask`.
- config missing/unreadable → `allow` (fail-safe).
- `KIT_ROSTER_GUARD=off` env overrides a `deny` config → `allow`.
- structural: settings.json matcher contains `Skill`; guard.sh has a `Skill)` case.
Anchor (a live positive) + the negatives above; non-vacuous (a dead function fails ≥1).

### `docs/adoption/skill-rosters.md` (vc-hosts style)
Contract → the kit prefers its own roster (Slice A) → the opt-in dial (`MODE`, `BLOCKLIST`, `KIT_ROSTER_GUARD`) → how to extend the blocklist → honest ceiling (Claude-Code-only; deny is blunt; ships off). Index it beside `vc-hosts.md`/`brownfield.md`.

---

## Tasks

### Task 1 — `.kit/roster.conf` + `guard_check_skill()` + CP protection *(serial; foundation)*
Author `.kit/roster.conf` + add `guard_check_skill()` and the `.kit/roster.conf` control-plane entries (all 3 matchers) to a scratch copy of `guard-core.sh`. TDD: write the conformance selftest cases first (Task 3's fixtures can be drafted here to drive it), source the scratch guard-core, prove each verdict. `dash -n` + `shellcheck`.

### Task 2 — `guard.sh` `Skill)` case + `emit_ask()` + settings.json matcher *(serial)*
Add the adapter case + `emit_ask`; add `Skill` to the matcher. Prove via a JSON-input fixture (simulate a Skill tool call) that each mode yields the right `permissionDecision`.

### Task 3 — `conformance/roster-guard-wired.sh` + claim registration + CI + autonomy fixtures *(serial)*
Author the check (assertions above); register `roster-guard` in claims.tsv + REQUIRED_IDS + verify.sh (control count 40→41); wire `--selftest` into ci.yml (ci-selftest-coverage — the Slice A/E6-a lesson); add agent-autonomy fixtures proving the agent can't Write/`>`/`sed -i` `.kit/roster.conf`. Mutation-prove non-vacuity by hand.

### Task 4 — `docs/adoption/skill-rosters.md` + discoverability *(parallel-safe with 1–3; disjoint files)*
Author the adoption doc; index it; ensure no broken links (adopter-export link-safety).

### Task 5 — apply.py assembly + clone-prove (commit-first) + version finishing *(serial; after 1–4)*
Idempotent, anchor-guarded, per-file-buffer applier materializing all of the above + VERSION 3.93.0→3.94.0 + README + CHANGELOG. Clone-prove **commit-first**: clone → apply → `git add -A && git commit` → `verify --require` (41 control · 16 doc · 0 failed, adopter-export PASS) → selftest → second apply (idempotent). Author a guard-safe clone-prove runner (never name conformance/ or skills/ in a Bash command).

### Task 6 — dual review + ship *(gate; builder ≠ reviewer)*
- **Reviewer:** correctness, coherence, non-vacuity, count 40→41, apply.py idempotent.
- **Security-reviewer (HEAVY — guard-core.sh):** try to BYPASS the Skill check (namespace spoofing e.g. `Superpowers:`/whitespace/`::`; a skill name with no colon; config injection; the env override abused); confirm the fail-safe routes to *allow* (no wedge) while `deny` can't be trivially evaded; confirm the agent genuinely cannot edit `.kit/roster.conf` (all 3 matchers + fixtures); confirm `guard.sh` stays thin (no logic leak).
- **Human ship:** apply apply.py; commit; PR; `--admin` merge (control-plane-ratification red-by-design); `release-tag.sh` → v3.94.0.

## Parallel-safety
Tasks 1→2→3 serial (guard behaviour chain). Task 4 (adoption doc) may run parallel to 1–3 (disjoint files). Task 5 after 1–4. Task 6 gates.

## Plan self-review (against the spec)
- **Spec coverage:** dial/config (§3) → T1; adapter/matcher (§3) → T2; conformance claim + fixtures (§3/§5) → T3; adoption doc (§3) → T4; version finishing (§7) → T5; heavy security review (§6) → T6. All design §7 items mapped.
- **Placeholder scan:** guard_check_skill logic, config format, adapter case, check assertions all concrete.
- **Consistency:** control count 40→41; version 3.93.0→3.94.0; new claim (not doc) per the design.
- **Control-plane completeness:** `.kit/roster.conf` protected in all 3 matchers + autonomy fixtures — the load-bearing security property, called out as T3's job and the security-reviewer's focus.

## Terminal state
Handed to the **build** skill — fresh executor per task, review between tasks, durable ledger, heavy security review before ship.
