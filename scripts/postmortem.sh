#!/bin/sh
# postmortem.sh — postmortem stub generator + action-item backlog parser.
#
# Two modes:
#   new        — scaffold a postmortem stub from incident metadata
#   to-backlog — parse the action-items table and emit backlog-row stubs to stdout
#
# Usage:
#   sh scripts/postmortem.sh new --id <ID> --severity <P0|P1|P2|P3> --title <title> \
#       [--commander <name>] [--date <YYYY-MM-DD>] [--out <dir>]
#   sh scripts/postmortem.sh to-backlog <postmortem.md>
#   sh scripts/postmortem.sh --selftest
#
# Notes:
#   new:        reads templates/POSTMORTEM-TEMPLATE.md, substitutes header placeholders,
#               writes to <out>/<ID>.md (default out: postmortems/). No-clobber.
#   to-backlog: parses "## 7. Action items" table; skips header, separator, blank, and
#               placeholder rows ([action] etc.). Emits Ready-row stubs to stdout.
# POSIX sh; dash-clean.
set -eu
cd "$(dirname "$0")/.."

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
usage:
  sh scripts/postmortem.sh new --id <ID> --severity <P0|P1|P2|P3> --title <title> \
      [--commander <name>] [--date <YYYY-MM-DD>] [--out <dir>]
  sh scripts/postmortem.sh to-backlog <postmortem.md>
  sh scripts/postmortem.sh --selftest
EOF
  exit 2
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# mode: new
# ---------------------------------------------------------------------------
cmd_new() {
  # parse args
  _id=""
  _severity=""
  _title=""
  _commander="[name / role]"
  _date="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
  _out="postmortems"

  while [ $# -gt 0 ]; do
    case "$1" in
      --id)        _id="$2";        shift 2 ;;
      --severity)  _severity="$2";  shift 2 ;;
      --title)     _title="$2";     shift 2 ;;
      --commander) _commander="$2"; shift 2 ;;
      --date)      _date="$2";      shift 2 ;;
      --out)       _out="$2";       shift 2 ;;
      *) printf 'error: unknown option: %s\n' "$1" >&2; usage ;;
    esac
  done

  # validate required
  if [ -z "$_id" ] || [ -z "$_title" ]; then
    printf 'error: --id and --title are required\n' >&2; usage
  fi
  case "$_severity" in
    P0|P1|P2|P3) ;;
    *) printf 'error: --severity must be one of P0 P1 P2 P3 (got: %s)\n' "$_severity" >&2; usage ;;
  esac

  _template="templates/POSTMORTEM-TEMPLATE.md"
  [ -f "$_template" ] || die "template not found: $_template"

  _dest="${_out}/${_id}.md"
  [ -f "$_dest" ] && die "target already exists (no-clobber): $_dest"

  mkdir -p "$_out"

  # awk-based substitution: safer than sed when replacement values may contain
  # the sed delimiter (/) — e.g. a title like "DB/cache failover" or a
  # commander of "alice / SRE lead".  awk gsub() uses a regex pattern and a
  # literal replacement string with no special meaning for /.
  awk \
    -v title="$_title" \
    -v id="$_id" \
    -v severity="$_severity" \
    -v commander="$_commander" \
    -v dateval="$_date" \
    'BEGIN {
       # escape & and \ in replacement strings (the only special chars in awk gsub)
       gsub(/\\/, "\\\\", title);     gsub(/&/, "\\&", title)
       gsub(/\\/, "\\\\", id);        gsub(/&/, "\\&", id)
       gsub(/\\/, "\\\\", severity);  gsub(/&/, "\\&", severity)
       gsub(/\\/, "\\\\", commander); gsub(/&/, "\\&", commander)
       gsub(/\\/, "\\\\", dateval);   gsub(/&/, "\\&", dateval)
     }
     {
       gsub(/\[Incident Title\]/, title)
       gsub(/\[id\]/, id)
       gsub(/\[P0 \/ P1 \/ P2 \/ P3\]/, severity)
       gsub(/\[name \/ role\]/, commander)
       gsub(/\[date\]/, dateval)
       gsub(/\[open \/ closed\]/, "open")
       print
     }' \
    "$_template" > "$_dest"

  printf 'created: %s\n' "$_dest"
}

# ---------------------------------------------------------------------------
# mode: to-backlog
# ---------------------------------------------------------------------------
cmd_to_backlog() {
  _pmfile="${1:-}"
  [ -z "$_pmfile" ] && { printf 'error: to-backlog requires a postmortem file path\n' >&2; usage; }
  [ -f "$_pmfile" ] || die "file not found: $_pmfile"

  # Derive incident ID from the basename (strip .md extension)
  _id="$(basename "$_pmfile" .md)"

  # Use awk to:
  #   1. Detect "## 7. Action items" → start collecting
  #   2. Stop at the next "## " heading
  #   3. Skip header row (contains "Action" and "Owner"), separator (|---), blank lines,
  #      and placeholder rows (first cell trimmed matches ^\[.*\]$)
  #   4. Emit one backlog Ready row per real action
  _rows="$(awk '
    BEGIN { in_section = 0 }

    # Enter the action-items section
    /^## 7[.] Action items/ { in_section = 1; next }

    # Leave the section when we hit the next ## heading
    in_section && /^## / { in_section = 0; next }

    !in_section { next }

    # Skip blank lines
    /^[[:space:]]*$/ { next }

    # Only process lines starting with |
    !/^\|/ { next }

    {
      # Split on |; field [2] = Action, [3] = Owner, [6] = Type
      # (fields: "" | Action | Owner | Due | Backlog link | Type | "")
      n = split($0, f, "|")

      action = f[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", action)
      owner  = f[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
      type   = f[6]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", type)
      if (n < 6) { type = "prevent" }

      # Skip header row
      if (action == "Action" && owner == "Owner") { next }

      # Skip separator row (contains ---)
      if (action ~ /^-/) { next }

      # Skip placeholder row: action cell is a bracketed placeholder [...]
      if (action ~ /^\[.*\]$/) { next }

      # Skip blank action cells
      if (action == "") { next }

      # Emit backlog Ready row
      print "| " action " | incident INCIDENT_ID follow-up — " type " | " action " completed | S | [set] | tech-debt | " owner " | PMFILE |"
    }
  ' "$_pmfile" | sed \
      -e "s|INCIDENT_ID|${_id}|g" \
      -e "s|PMFILE|${_pmfile}|g")"

  if [ -z "$_rows" ]; then
    printf 'no action items found in %s\n' "$_pmfile"
    return 0
  fi

  # Emit stubs with header comment
  echo "# Backlog stubs (review before pasting into BACKLOG.md or creating in your tracker)"
  echo "| Item | Intent (why) | Acceptance criteria | Size | Risk | Type | Owner | Links |"
  echo "|------|--------------|---------------------|------|------|------|-------|-------|"
  printf '%s\n' "$_rows"
}

# ---------------------------------------------------------------------------
# selftest
# ---------------------------------------------------------------------------
selftest() {
  _fail=0
  _tmpdir="$(mktemp -d)"
  trap 'rm -rf "$_tmpdir"' EXIT

  # --- fixture: postmortem with 2 real rows + 1 placeholder + 1 empty-action ---
  _pm_fixture="${_tmpdir}/INC-001.md"
  cat > "$_pm_fixture" <<'PMEOF'
# Test Incident — Postmortem

**Incident ID:** INC-001 · **Severity:** P1 · **Date:** 2026-01-01 · **Incident commander:** alice · **Status:** open

## 7. Action items

| Action | Owner | Due | Backlog link | Type |
|--------|-------|-----|--------------|------|
| [action] | [owner] | [date] | [#id] | [prevent / detect-faster / mitigate-faster] |
| Add rate-limit to login endpoint | alice | 2026-01-15 | #42 | prevent |
| Set up alert for error-rate spike | bob | 2026-01-20 | #43 | detect-faster |

## 8. Blameless statement

This postmortem examines systems and processes, not people.
PMEOF

  # --- fixture: postmortem with no real action rows ---
  _pm_empty="${_tmpdir}/INC-002.md"
  cat > "$_pm_empty" <<'PMEOF2'
# Empty — Postmortem

## 7. Action items

| Action | Owner | Due | Backlog link | Type |
|--------|-------|-----|--------------|------|
| [action] | [owner] | [date] | [#id] | [prevent / detect-faster / mitigate-faster] |
PMEOF2

  # ---- T1: to-backlog with 2 real rows ----------------------------------------
  _out="$(sh "$0" to-backlog "$_pm_fixture" 2>&1)"

  printf '%s\n' "$_out" | grep -q "Add rate-limit to login endpoint" || {
    echo "postmortem --selftest: FAIL (T1: real action row 1 missing)" >&2; _fail=1
  }
  printf '%s\n' "$_out" | grep -q "Set up alert for error-rate spike" || {
    echo "postmortem --selftest: FAIL (T1: real action row 2 missing)" >&2; _fail=1
  }
  printf '%s\n' "$_out" | grep -q "INC-001" || {
    echo "postmortem --selftest: FAIL (T1: incident ID not in output)" >&2; _fail=1
  }
  printf '%s\n' "$_out" | grep -q '\[action\]' && {
    echo "postmortem --selftest: FAIL (T1: placeholder row was emitted)" >&2; _fail=1
  }
  # Exactly 2 data rows (lines starting with | that contain "completed")
  _row_count="$(printf '%s\n' "$_out" | grep -c '| tech-debt |' || true)"
  [ "$_row_count" = "2" ] || {
    echo "postmortem --selftest: FAIL (T1: expected 2 backlog rows, got $_row_count)" >&2; _fail=1
  }

  # ---- T2: new mode — stub is created with correct tokens ---------------------
  _outdir="${_tmpdir}/postmortems"
  sh "$0" new --id INC-001 --severity P1 --title "Test Incident" \
      --commander alice --date 2026-01-01 --out "$_outdir" >/dev/null 2>&1 || {
    echo "postmortem --selftest: FAIL (T2: new command exited non-zero)" >&2; _fail=1
  }
  _stub="${_outdir}/INC-001.md"
  [ -f "$_stub" ] || {
    echo "postmortem --selftest: FAIL (T2: stub file not created)" >&2; _fail=1
  }
  grep -q "INC-001" "$_stub" || {
    echo "postmortem --selftest: FAIL (T2: ID not in stub)" >&2; _fail=1
  }
  grep -q "Test Incident" "$_stub" || {
    echo "postmortem --selftest: FAIL (T2: title not in stub)" >&2; _fail=1
  }

  # ---- T3: no-clobber — second new to same target must fail -------------------
  _clobber_rc=0
  sh "$0" new --id INC-001 --severity P1 --title "Test Incident" \
      --out "$_outdir" >/dev/null 2>&1 || _clobber_rc=$?
  [ "$_clobber_rc" != "0" ] || {
    echo "postmortem --selftest: FAIL (T3: no-clobber did not reject duplicate)" >&2; _fail=1
  }

  # ---- T4: empty action table → "no action items found" notice ----------------
  _empty_out="$(sh "$0" to-backlog "$_pm_empty" 2>&1)"
  printf '%s\n' "$_empty_out" | grep -q "no action items found" || {
    echo "postmortem --selftest: FAIL (T4: expected 'no action items found' notice)" >&2; _fail=1
  }

  # ---- T5: missing file → exit 1 (error, not usage exit 2) -------------------
  _missing_rc=0
  sh "$0" to-backlog /nonexistent/path.md >/dev/null 2>&1 || _missing_rc=$?
  [ "$_missing_rc" != "0" ] || {
    echo "postmortem --selftest: FAIL (T5: missing file did not exit non-zero)" >&2; _fail=1
  }

  [ "$_fail" -eq 0 ] && { echo "postmortem --selftest: OK"; exit 0; } || exit 1
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------
case "${1:-}" in
  --selftest)  selftest ;;
  new)         shift; cmd_new "$@" ;;
  to-backlog)  shift; cmd_to_backlog "${1:-}" ;;
  *)           usage ;;
esac
