#!/bin/sh
# doctor.sh — adopter-facing POSTURE report. Composes existing conformance checks into one
# "am I conformant + have I drifted?" summary. Automates the *mechanizable* half of
# docs/operations/drift-self-check.md (axes D claim-integrity + E git ground-truth).
#
# Three posture dimensions:
#   conformance [GATING]   — sh conformance/verify.sh
#   claims      [GATING]   — sh conformance/claims-registry.sh
#   git         [ADVISORY] — branch, dirty-tree, tag alignment (WARN-only; never hard-fails alone)
#
# Exit policy (mirrors verify.sh):
#   exit 1  — a GATING dimension FAILs, or UNVERIFIED when --require/CI
#   exit 0  — PASS or WARN (git advisory warnings do not cause exit 1)
#
# Usage: sh scripts/doctor.sh [--require] | --selftest
# POSIX sh; dash-clean.
set -eu
cd "$(dirname "$0")/.."

if [ "${1:-}" = "--selftest" ]; then
  # Verify the render contract: output contains the required sections and labels.
  out=$(sh "$0" 2>&1) || true
  sfail=0
  printf '%s\n' "$out" | grep -q "POSTURE"             || { echo "doctor --selftest: FAIL (no POSTURE section)"; sfail=1; }
  printf '%s\n' "$out" | grep -q "conformance"         || { echo "doctor --selftest: FAIL (no conformance dimension)"; sfail=1; }
  printf '%s\n' "$out" | grep -q "claims"              || { echo "doctor --selftest: FAIL (no claims dimension)"; sfail=1; }
  printf '%s\n' "$out" | grep -qE 'git[[:space:]]+(OK|WARN)' || { echo "doctor --selftest: FAIL (no git dimension row)"; sfail=1; }
  printf '%s\n' "$out" | grep -q "Overall:"            || { echo "doctor --selftest: FAIL (no Overall verdict)"; sfail=1; }
  printf '%s\n' "$out" | grep -q "drift-self-check.md" || { echo "doctor --selftest: FAIL (no drift-self-check.md footer)"; sfail=1; }

  # T2a: --full output contains METRICS heading and non-gating label
  full_out=$(sh "$0" --full 2>&1) || true
  printf '%s\n' "$full_out" | grep -q "METRICS"                  || { echo "doctor --selftest: FAIL (--full: no METRICS section)"; sfail=1; }
  printf '%s\n' "$full_out" | grep -q "does not affect exit"     || { echo "doctor --selftest: FAIL (--full: no 'does not affect exit' label)"; sfail=1; }

  # T2b: forced-failing metrics commands must NOT change the exit code
  # Capture posture-only exit (no --full)
  posture_rc=0
  sh "$0" >/dev/null 2>&1 || posture_rc=$?
  # Capture --full exit when metrics commands are forced to fail
  forced_rc=0
  DOCTOR_DORA_CMD=false DOCTOR_SCORECARD_CMD=false sh "$0" --full >/dev/null 2>&1 || forced_rc=$?
  [ "$forced_rc" = "$posture_rc" ] || {
    echo "doctor --selftest: FAIL (non-gating invariant broken: forced-failing metrics changed exit from $posture_rc to $forced_rc)"
    sfail=1
  }

  [ "$sfail" -eq 0 ] && { echo "doctor --selftest: OK"; exit 0; } || exit 1
fi

REQUIRE=0
FULL=0
[ -n "${CI:-}" ] && REQUIRE=1
for _arg in "$@"; do
  case "$_arg" in
    --require) REQUIRE=1 ;;
    --full)    FULL=1    ;;
  esac
done

# Variable-indirected metrics commands — override in tests to inject failures
# without touching the real scripts.  The [ -f ] guard is applied only on the
# default path; an overridden command is invoked directly.
DOCTOR_DORA_CMD="${DOCTOR_DORA_CMD:-}"
DOCTOR_SCORECARD_CMD="${DOCTOR_SCORECARD_CMD:-}"

gate_fail=0
warns=0

# — HEADER ——————————————————————————————————————————————————————————————————
_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
_version=$(tr -d '[:space:]' < VERSION 2>/dev/null || echo "unknown")
_latest_tag=$(git tag --list 'v*' --sort=-version:refname 2>/dev/null | head -1 || echo "none")

echo "sparkwright doctor"
echo "------------------"
printf 'branch: %s  sha: %s  VERSION: %s  latest-tag: %s\n' \
  "$_branch" "$_sha" "$_version" "$_latest_tag"
echo ""

# — POSTURE ——————————————————————————————————————————————————————————————————
echo "POSTURE"
echo "-------"

# 1. conformance [GATING]
if [ -f "conformance/verify.sh" ]; then
  _args=""
  [ "$REQUIRE" = "1" ] && _args="--require"
  # shellcheck disable=SC2086
  if _vout=$(sh conformance/verify.sh $_args 2>&1); then _vrc=0; else _vrc=$?; fi
  case "$_vrc" in
    0) _vstatus="PASS" ;;
    2) _vstatus="UNVERIFIED" ;;
    *) _vstatus="FAIL" ;;
  esac
  printf '  %-14s %s\n' "conformance" "$_vstatus"
  case "$_vstatus" in
    FAIL)       gate_fail=1 ;;
    UNVERIFIED) [ "$REQUIRE" = "1" ] && gate_fail=1 || true ;;
  esac
else
  printf '  %-14s UNVERIFIED (not present)\n' "conformance"
  warns=$((warns+1))
  [ "$REQUIRE" = "1" ] && gate_fail=1 || true
fi

# 2. claims [GATING]
if [ -f "conformance/claims-registry.sh" ]; then
  if _cout=$(sh conformance/claims-registry.sh 2>&1); then _crc=0; else _crc=$?; fi
  case "$_crc" in
    0) _cstatus="PASS" ;;
    *) _cstatus="FAIL" ;;
  esac
  printf '  %-14s %s\n' "claims" "$_cstatus"
  [ "$_cstatus" = "FAIL" ] && gate_fail=1 || true
else
  printf '  %-14s UNVERIFIED (not present)\n' "claims"
  warns=$((warns+1))
  [ "$REQUIRE" = "1" ] && gate_fail=1 || true
fi

# 3. git [ADVISORY — WARN-only; never sets gate_fail]
_git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
_git_dirty=$(git status --porcelain 2>/dev/null || true)
_git_tag_for_ver=$(git tag --list "v$_version" 2>/dev/null || true)

_git_warn=0
_git_notes=""

case "$_git_branch" in
  HEAD|detached)
    _git_notes="${_git_notes}WARN: detached HEAD; "
    _git_warn=1
    ;;
  *)
    _git_notes="${_git_notes}branch=${_git_branch}; "
    ;;
esac

if [ -n "$_git_dirty" ]; then
  _git_notes="${_git_notes}WARN: dirty working tree; "
  _git_warn=1
else
  _git_notes="${_git_notes}clean; "
fi

if [ -z "$_git_tag_for_ver" ]; then
  _git_notes="${_git_notes}WARN: v${_version} untagged/unreleased"
  _git_warn=1
else
  _git_notes="${_git_notes}tagged=v${_version}"
fi

if [ "$_git_warn" = "1" ]; then
  warns=$((warns+1))
  printf '  %-14s WARN  [%s]\n' "git" "$_git_notes"
else
  printf '  %-14s OK    [%s]\n' "git" "$_git_notes"
fi

# — VERDICT ——————————————————————————————————————————————————————————————————
echo ""
if [ "$gate_fail" = "1" ]; then
  echo "Overall: FAIL  (a gating dimension failed — fix conformance/claims before shipping)"
elif [ "$warns" != "0" ]; then
  echo "Overall: WARN  (review above — gating dimension(s) unverified or git advisory warnings present)"
else
  echo "Overall: PASS"
fi

# — FOOTER (honest ceiling) ——————————————————————————————————————————————————
echo ""
echo "Note: doctor automates the mechanizable drift axes (D claim-integrity, E git ground-truth"
echo "from docs/operations/drift-self-check.md) but does NOT detect semantic drift (intent,"
echo "scope, or overclaim) — that remains an agent/human judgment check."

# — METRICS (informational — does not affect exit) ————————————————————————————
if [ "$FULL" = "1" ]; then
  echo ""
  echo "METRICS (informational — does not affect exit)"
  echo "-----------------------------------------------"

  # dora
  if [ -n "$DOCTOR_DORA_CMD" ]; then
    # overridden (test path) — run directly, discard rc
    _dora_out=$($DOCTOR_DORA_CMD 2>&1) || true
    printf '%s\n' "$_dora_out"
  elif [ -f "scripts/dora.sh" ]; then
    _dora_out=$(sh scripts/dora.sh 2>&1) || true
    printf '%s\n' "$_dora_out"
  else
    echo "  dora:           N/A (not present)"
  fi

  # agent-scorecard
  if [ -n "$DOCTOR_SCORECARD_CMD" ]; then
    # overridden (test path) — run directly, discard rc
    _sc_out=$($DOCTOR_SCORECARD_CMD 2>&1) || true
    printf '%s\n' "$_sc_out"
  elif [ -f "scripts/agent-scorecard.sh" ]; then
    _sc_out=$(sh scripts/agent-scorecard.sh 2>&1) || true
    printf '%s\n' "$_sc_out"
  else
    echo "  agent-scorecard: N/A (not present)"
  fi
fi

[ "$gate_fail" = "1" ] && exit 1 || exit 0
