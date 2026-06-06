#!/bin/sh
# profile-completeness.sh — verify every stack profile fills the _TEMPLATE.md contract.
# For each profiles/*.md except _TEMPLATE.md: all 11 section headings present, no leftover
# [...] placeholder, and (if a companion profiles/<stack>/ci.yml exists) it passes ci-gates.sh.
# Usage: sh conformance/profile-completeness.sh   (run from repo root)
set -eu

HERE=$(dirname "$0")
fail=0

for prof in profiles/*.md; do
  base=$(basename "$prof")
  [ "$base" = "_TEMPLATE.md" ] && continue
  name="${base%.md}"

  miss=""
  i=1
  while [ "$i" -le 11 ]; do
    grep -Eq "^## ${i}\. " "$prof" || miss="$miss §${i}"
    i=$((i + 1))
  done
  if [ -n "$miss" ]; then echo "FAIL $base: missing section(s):$miss"; fail=1; else echo "PASS $base: 11 sections"; fi

  if grep -Fq '[...]' "$prof"; then echo "FAIL $base: leftover [...] placeholder(s)"; fail=1; fi

  if [ -f "profiles/${name}/ci.yml" ]; then
    if sh "${HERE}/ci-gates.sh" "profiles/${name}/ci.yml" >/dev/null 2>&1; then
      echo "PASS $base: companion ci.yml satisfies §14"
    else
      echo "FAIL $base: companion ci.yml missing required gates"; fail=1
    fi
  fi
done

if [ "$fail" -ne 0 ]; then echo "FAIL: profile-completeness"; exit 1; fi
echo "OK: all profiles complete and conformant"
exit 0
