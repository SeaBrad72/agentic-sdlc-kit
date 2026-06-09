#!/bin/sh
# waivers-valid.sh — validate a brownfield WAIVER-REGISTER.md (governed exceptions to the
# CI gates). A waiver is the honest alternative to faking green; this proves the register
# is well-formed, owned, time-boxed, and not abused. FAILS if any active waiver is:
#   - expired (Expires < today),
#   - on a NON-NEGOTIABLE gate (secret-scan / branch-protection — never waivable),
#   - missing a required field, or
#   - longer than the 90-day max lifetime (Expires - Opened > 90d).
# N/A-pass when no register exists (greenfield needs none) — adoption-conditional.
#   usage: sh conformance/waivers-valid.sh [REGISTER.md] | --selftest
# Portable POSIX sh; dates via GNU `date -d` or BSD `date -j -f`. See docs/adoption/brownfield.md §5.
set -eu

NONNEGOTIABLE="secret-scan branch-protection"
MAX_DAYS=90

to_epoch() {  # YYYY-MM-DD -> epoch seconds (GNU then BSD)
  date -d "$1" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null
}
is_date() { printf '%s' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; }
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Print the data rows of the "## Active waivers" table only (skip header/separator/other sections).
extract_rows() {
  awk '
    /^##[[:space:]]+Active waivers/ { insec=1; next }
    /^##[[:space:]]/ { insec=0 }
    insec && /^\|/ {
      if ($0 ~ /Gate/ && $0 ~ /Reason/) next       # header
      if ($0 ~ /^\|[[:space:]]*-+/) next            # separator
      print
    }
  ' "$1"
}

# validate_register FILE -> 0 valid / 1 invalid (prints findings). Current-shell fail accumulator.
validate_register() {
  reg=$1; today=$(date +%Y-%m-%d); tnum=$(printf '%s' "$today" | tr -d -); vfail=0
  tmp=$(mktemp 2>/dev/null || printf '/tmp/wv.%s' "$$")
  extract_rows "$reg" > "$tmp"
  if [ ! -s "$tmp" ]; then
    echo "waivers-valid: register present but no active waivers — OK ($reg)"; return 0
  fi
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    gate=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $2}')")
    owner=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $4}')")
    opened=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $5}')")
    expires=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $6}')")
    remediation=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $7}')")
    ratified=$(trim "$(printf '%s' "$row" | awk -F'|' '{print $8}')")
    label="${gate:-<no-gate>}"
    # required fields
    if [ -z "$gate" ] || [ -z "$owner" ] || [ -z "$opened" ] || [ -z "$expires" ] || [ -z "$remediation" ] || [ -z "$ratified" ]; then
      echo "FAIL: waiver '$label' is missing a required field (gate/owner/opened/expires/remediation/ratified-by)"; vfail=1; continue
    fi
    # non-negotiable gate
    for ng in $NONNEGOTIABLE; do
      if [ "$gate" = "$ng" ]; then echo "FAIL: waiver targets NON-NEGOTIABLE gate '$gate' — never waivable"; vfail=1; fi
    done
    # date formats
    if ! is_date "$opened" || ! is_date "$expires"; then
      echo "FAIL: waiver '$label' has a non-YYYY-MM-DD date (opened='$opened' expires='$expires')"; vfail=1; continue
    fi
    # expired
    enum=$(printf '%s' "$expires" | tr -d -)
    if [ "$enum" -lt "$tnum" ]; then
      echo "FAIL: waiver '$label' EXPIRED on $expires (today $today) — renew or remove"; vfail=1
    fi
    # 90-day max lifetime
    oe=$(to_epoch "$opened" || true); ee=$(to_epoch "$expires" || true)
    if [ -n "$oe" ] && [ -n "$ee" ]; then
      span=$(( (ee - oe) / 86400 ))
      if [ "$span" -gt "$MAX_DAYS" ]; then
        echo "FAIL: waiver '$label' lifetime ${span}d exceeds ${MAX_DAYS}d max (opened $opened, expires $expires)"; vfail=1
      fi
    else
      echo "FAIL: waiver '$label' has unparseable dates"; vfail=1
    fi
  done < "$tmp"
  if [ "$vfail" -eq 0 ]; then echo "waivers-valid: OK — all active waivers are owned, in-date, within ${MAX_DAYS}d, and not on a non-negotiable gate ($reg)"; fi
  return "$vfail"
}

selftest() {
  st=0; d=$(mktemp -d 2>/dev/null || printf '/tmp/wvst.%s' "$$"); mkdir -p "$d"
  mk() { printf '## Active waivers\n\n| Gate | Reason | Owner | Opened | Expires | Remediation plan | Ratified-by |\n|--|--|--|--|--|--|--|\n%s\n' "$2" > "$d/$1"; }
  expect() { # file expect-rc label
    validate_register "$d/$1" >/dev/null 2>&1 && g=0 || g=$?
    if [ "$g" = "$2" ]; then echo "selftest PASS: $3"; else echo "selftest FAIL: $3 (want $2 got $g)"; st=1; fi
  }
  mk valid   '| coverage | legacy at 41% | @jdoe | 2099-01-01 | 2099-03-01 | ratchet to 80 | @sec |'
  expect valid 0 "valid waiver -> OK"
  mk expired '| coverage | x | @jdoe | 2020-01-01 | 2020-02-01 | y | @sec |'
  expect expired 1 "expired waiver -> FAIL"
  mk nonneg  '| secret-scan | x | @jdoe | 2099-01-01 | 2099-02-01 | y | @sec |'
  expect nonneg 1 "non-negotiable gate -> FAIL"
  mk over90  '| coverage | x | @jdoe | 2099-01-01 | 2099-12-31 | y | @sec |'
  expect over90 1 "over-90-day lifetime -> FAIL"
  mk missing '| coverage | x | | 2099-01-01 | 2099-02-01 | y | @sec |'
  expect missing 1 "missing field (owner) -> FAIL"
  mk badbranch '| branch-protection | x | @jdoe | 2099-01-01 | 2099-02-01 | y | @sec |'
  expect badbranch 1 "branch-protection waiver -> FAIL"
  # no register -> N/A pass (handled in main); simulate
  if main "$d/does-not-exist.md" >/dev/null 2>&1; then echo "selftest PASS: no register -> N/A pass"; else echo "selftest FAIL: no register should N/A-pass"; st=1; fi
  [ "$st" = "0" ] && echo "waivers-valid --selftest: OK"
  return "$st"
}

main() {
  reg="${1:-./WAIVER-REGISTER.md}"
  if [ ! -f "$reg" ]; then
    echo "waivers-valid: no $reg — N/A (greenfield / no governed exceptions)."; return 0
  fi
  validate_register "$reg"
}

case "${1:-}" in
  --selftest) selftest; exit $? ;;
  *) main "$@"; exit $? ;;
esac
