#!/bin/sh
# conditional-gates.sh — assert the a11y/load/eval CONDITIONAL gates are named in §7 (Slice 9j).
# The honest-demote: these are first-class but conditional (trigger-bound), not universal.
# Asserts DEVELOPMENT-PROCESS.md §7 names Accessibility, Resilience (load), and Eval as gates.
#   sh conformance/conditional-gates.sh [--selftest]
# Exit: 0 = ok · 1 = a gap · 2 = bad usage. POSIX sh; dash-clean.
set -eu

GATE_DOC="DEVELOPMENT-PROCESS.md"
GATES="Accessibility Eval Resilience"

# check_doc <doc>: print PASS/FAIL; return 1 on any gap.
check_doc() {
  d=$1; f=0
  if [ ! -f "$d" ]; then echo "FAIL: missing $d"; return 1; fi
  for g in $GATES; do
    if grep -q "$g" "$d"; then echo "PASS: $d names the $g gate"; else echo "FAIL: $d omits the $g gate"; f=1; fi
  done
  return $f
}

if [ "${1:-}" = "--selftest" ]; then
  sfail=0
  g=$(mktemp -d)
  printf '# proc\nEval gate\nResilience readiness\n' > "$g/proc.md"   # missing Accessibility
  if check_doc "$g/proc.md" >/dev/null 2>&1; then
    echo "FAIL: selftest — missing conditional gate not detected"; sfail=1
  else
    echo "PASS: selftest — missing conditional gate detected"
  fi
  ok=$(mktemp -d)
  printf '# proc\nAccessibility\nEval gate\nResilience readiness\n' > "$ok/proc.md"
  if check_doc "$ok/proc.md" >/dev/null 2>&1; then
    echo "PASS: selftest — complete trio passes"
  else
    echo "FAIL: selftest — complete trio wrongly rejected"; sfail=1
  fi
  [ "$sfail" -eq 0 ] && { echo "OK: conditional-gates selftest"; exit 0; } || { echo "FAIL: conditional-gates selftest"; exit 1; }
fi

case "${1:-}" in
  "") : ;;
  *) echo "usage: conditional-gates.sh [--selftest]" >&2; exit 2 ;;
esac

echo "Conditional-gate naming (§7):"
if check_doc "$GATE_DOC"; then
  echo "OK: a11y / load / eval are named as conditional gates in §7"
  exit 0
else
  echo "FAIL: a conditional gate is unnamed in §7 (see above)"
  exit 1
fi
