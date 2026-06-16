#!/bin/sh
# check-links.sh — assert every relative Markdown link in the kit's distributable
# docs points to a TRACKED file (one that exists in a fresh `git clone`, not merely
# on the local disk). Resolving against the tracked set — `git ls-files`, not a
# filesystem `[ -e ]` test — is deliberate: an untracked-but-on-disk target (e.g. a
# gitignored file) would otherwise false-pass locally and ship as a dead link
# publicly. Ignores http(s)/mailto/pure-anchor links. Scans every tracked Markdown
# file — no directory is excluded from validation.
# Usage: sh conformance/check-links.sh   (run from repo root)
set -eu

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

git ls-files '*.md' | while IFS= read -r f; do
  dir=$(dirname "$f")
  grep -oE ']\([^)]+\)' "$f" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r link; do
    case "$link" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    target=$(printf '%s' "$link" | sed -E 's/[#?].*$//')
    [ -z "$target" ] && continue
    case "$target" in
      /*) resolved=".${target}" ;;
      *)  resolved="${dir}/${target}" ;;
    esac
    # Tracked-set test (NOT [ -e ]): matches a tracked file, or a directory that
    # contains tracked files. git normalizes ./ and ../ in the pathspec.
    [ -n "$(git ls-files -- "$resolved" 2>/dev/null)" ] || echo "BROKEN: $f: $link -> $resolved" >> "$tmp"
  done
done

if [ -s "$tmp" ]; then
  echo "FAIL: broken relative Markdown links:" >&2
  cat "$tmp" >&2
  exit 1
fi
echo "OK: all relative Markdown links resolve"
exit 0
