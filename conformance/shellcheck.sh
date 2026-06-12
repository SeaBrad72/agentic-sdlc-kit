#!/bin/sh
# Kit shell regression-lock: lint the kit's OWN shell code (dogfooding quality).
# Floor: error + warning (POSIX -s sh). The kit's scripts are currently shellcheck-clean;
# this keeps them that way (dash -n only checks syntax, not lint). CONDITIONAL on shellcheck
# being installed: SKIP-pass if absent (a dev may not have it) — the kit CI installs it and
# runs it for real, so drift is caught in CI regardless.
#   sh conformance/shellcheck.sh [--selftest]
# Exit: 0 = clean or SKIP · 1 = a finding · 2 = bad usage. POSIX sh; dash-clean.
set -eu

# collect existing kit shell files into the positional params
collect() {
  set --
  for f in scripts/*.sh conformance/*.sh; do [ -f "$f" ] && set -- "$@" "$f"; done
  [ -f scripts/kit-guard ] && set -- "$@" scripts/kit-guard
  [ -f hooks/pre-push ]    && set -- "$@" hooks/pre-push
  printf '%s\n' "$@"
}

run() {
  command -v shellcheck >/dev/null 2>&1 || { echo "SKIP: shellcheck not installed (kit CI runs it for real)"; return 0; }
  # shellcheck disable=SC2046  # word-splitting the file list is intended here
  set -- $(collect)
  [ "$#" -gt 0 ] || { echo "shellcheck: no kit shell files found"; return 1; }
  if shellcheck -s sh -S warning "$@"; then
    echo "shellcheck: OK ($# kit shell file(s) clean at the error/warning floor)"
    return 0
  fi
  echo "shellcheck: FAIL (findings above) — fix or justify with a '# shellcheck disable=SCnnnn' + reason"
  return 1
}

selftest() {
  command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck --selftest: SKIP (shellcheck not installed)"; return 0; }
  d=$(mktemp -d)
  printf '#!/bin/sh\nx="hello"\nprintf "%%s\\n" "$x"\n' > "$d/clean.sh"
  printf '#!/bin/sh\nx=$1\nif [ "$x" == "bad" ]; then echo bad; fi\n' > "$d/dirty.sh"  # SC3014 (== in POSIX sh)
  shellcheck -s sh -S warning "$d/clean.sh" >/dev/null 2>&1 || { echo "selftest FAIL: clean fixture flagged"; return 1; }
  if shellcheck -s sh -S warning "$d/dirty.sh" >/dev/null 2>&1; then
    echo "selftest FAIL: dirty fixture not flagged"; return 1
  fi
  echo "shellcheck --selftest: OK (clean passes, dirty fails; fixtures left in $d)"
  return 0
}

case "${1:-}" in
  --selftest) selftest ;;
  "")         run ;;
  *)          echo "usage: shellcheck.sh [--selftest]" >&2; exit 2 ;;
esac
exit $?
