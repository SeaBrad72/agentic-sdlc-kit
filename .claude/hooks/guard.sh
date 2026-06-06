#!/bin/sh
# guard.sh — PreToolUse hook enforcing the §13 autonomy matrix (DEVELOPMENT-PROCESS.md).
# Denies irreversible / high-blast-radius actions; defers everything else to normal
# permission handling. Reads the tool-call JSON on stdin and, when a denied pattern
# matches the relevant input FIELD ONLY (Bash .command / Write|Edit .file_path) — not
# the whole payload — prints a deny decision and exits 0. Field-scoping means editing a
# doc that merely *mentions* a dangerous command is NOT blocked.
#
# Requires `jq`. If jq is absent, mutating tools (Bash/Write/Edit/NotebookEdit) are denied
# with an install message (fail-safe toward caution); read-only tools are allowed.
set -eu

INPUT=$(cat)

emit_deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}
allow() { exit 0; }   # no output = defer to normal permission flow

if ! command -v jq >/dev/null 2>&1; then
  tool=$(printf '%s' "$INPUT" | tr -d '\n' | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  case "$tool" in
    Bash|Write|Edit|NotebookEdit)
      emit_deny "agent-guard: jq is required to evaluate tool safety (DEVELOPMENT-PROCESS.md 13). Install jq; mutating tools are denied until then." ;;
    *) allow ;;
  esac
fi

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    case "$CMD" in
      *"rm -rf"*|*"rm -fr"*)        emit_deny "13: rm -rf is irreversible - human-gated." ;;
      *"git reset --hard"*)         emit_deny "13: git reset --hard discards work irreversibly - human-gated." ;;
      *"git commit --amend"*)       emit_deny "13: git commit --amend rewrites history - human-gated." ;;
      *"npm publish"*|*"yarn publish"*|*"pnpm publish"*) emit_deny "13: publishing a package is externally irreversible - human-gated." ;;
    esac
    if printf '%s' "$CMD" | grep -Eq 'git[[:space:]]+push.*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
      emit_deny "13: force-push rewrites published history - human-gated."
    fi
    if printf '%s' "$CMD" | grep -Eq 'git[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(main|master)([[:space:]]|$)'; then
      emit_deny "13: pushing directly to main/master bypasses review - open a PR (human-gated)."
    fi
    if printf '%s' "$CMD" | grep -Eiq '(psql|mysql|mariadb|sqlite3|mongosh?).*(drop[[:space:]]+table|truncate)'; then
      emit_deny "13: destructive SQL (DROP/TRUNCATE via a DB client) - human-gated."
    fi
    if printf '%s' "$CMD" | grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)([[:space:]]|$)'; then
      emit_deny "13: piping a remote script into a shell is high-blast-radius - human-gated."
    fi
    if printf '%s' "$CMD" | grep -Eiq '(vercel[[:space:]]+(deploy[[:space:]]+)?--prod|railway[[:space:]]+up|fly[[:space:]]+deploy|terraform[[:space:]]+apply|kubectl[[:space:]]+apply|helm[[:space:]]+(install|upgrade))'; then
      emit_deny "13: production deploy / infra apply is high-blast-radius - human-gated."
    fi
    allow ;;
  Write|Edit|NotebookEdit)
    FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    BASE=$(basename "$FP" 2>/dev/null || printf '%s' "$FP")
    if [ "$BASE" = ".env.example" ]; then allow; fi
    case "$FP" in
      *.env|*/.env|*.env.local|*.env.production|*.env.development|*.pem|*.key|*id_rsa*|*/secrets/*|*/secret/*)
        emit_deny "13: writing secret material ($BASE) - human-gated (use .env.example + a secrets manager)." ;;
    esac
    allow ;;
  *)
    allow ;;
esac
