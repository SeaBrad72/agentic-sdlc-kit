# `.claude/` — Agent Governance Layer

Enforces the **§13 autonomy matrix** and **§12 separations** (`DEVELOPMENT-PROCESS.md`) for Claude Code agents. This directory is **both** the kit's own governance **and** the reference adopters copy — drop it into your repo and adapt.

## Files
- **`settings.json`** — shared, committed. Permission `allow`/`ask`/`deny` globs + the PreToolUse hook wiring.
- **`settings.local.json`** — personal, **gitignored**. Your machine-local overrides; never committed.
- **`hooks/guard.sh`** — PreToolUse hook. Denies irreversible / high-blast actions (recursive rm, force-push, push-to-main, reset --hard, amend, package publish, destructive SQL / DB resets, curl|sh, prod/infra deploy, writing secret files). Defers everything else to the permission globs. Matches the relevant *field* only (so editing a doc that mentions a dangerous command is not blocked); within a Bash command it errs toward over-blocking quoted dangerous strings.
- **`agents/reviewer.md`**, **`agents/security-reviewer.md`** — read-only review subagents enforcing builder ≠ reviewer and the security gate.

## Prerequisite
`guard.sh` requires **`jq`** (to parse the tool-call JSON safely). Install it (`brew install jq` / `apt-get install jq`). If jq is missing — or the tool input is not valid JSON — the guard denies mutating tools and allows read-only; it never runs unguarded silently.

## Adapting (per `DEVELOPMENT-PROCESS.md` §13)
Start conservative; raise an action's autonomy as agent-quality metrics earn it. Loosen by moving an entry from `deny`→`ask`→`allow` in `settings.json`, or by editing the deny patterns in `hooks/guard.sh`. Keep irreversible/high-blast actions human-gated.

## Conformance
`conformance/agent-autonomy.sh` proves the guard denies the irreversible battery and allows the safe one (including false-positive and bypass-resistance regressions). It runs in CI.

## Coverage boundary

This guard governs the **Claude Code agent runtime only**. A human at a shell, or a different agent runtime, is not covered — production safety also requires platform controls (database IAM, separate production credentials/accounts, deploy approvals). Those are **Org-owned** (see `../docs/enterprise/README.md`).
