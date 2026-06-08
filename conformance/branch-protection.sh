#!/bin/sh
# branch-protection.sh — conformance check that `main` is actually protected on the
# remote (DEVELOPMENT-STANDARDS.md §14 / DEVELOPMENT-PROCESS.md §12). Requires `gh`
# authenticated against the repo's remote. If gh is absent/unauthenticated or there is
# no GitHub remote, exits 0 with an informational message (cannot verify here — run in
# CI or authenticate), mirroring inception-done.sh's "needs context" behavior.
set -eu

BRANCH="${1:-main}"
if ! command -v gh >/dev/null 2>&1; then
  echo "branch-protection: gh not installed — cannot verify protection here (run in CI / authenticate). Informational."; exit 0
fi
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -z "$REPO" ]; then
  echo "branch-protection: no GitHub repo context — cannot verify here. Informational."; exit 0
fi
PROT=$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>/dev/null || true)
if [ -z "$PROT" ]; then
  echo "FAIL: $BRANCH on $REPO has no branch protection (or it is not readable)."; exit 1
fi
ok=0
printf '%s' "$PROT" | grep -q '"required_pull_request_reviews"' || { echo "FAIL: required PR reviews not enabled on $BRANCH"; ok=1; }
printf '%s' "$PROT" | grep -q '"required_status_checks"' || { echo "FAIL: required status checks not enabled on $BRANCH"; ok=1; }
[ "$ok" -eq 0 ] && echo "OK: $BRANCH on $REPO is protected (PR reviews + status checks required)."
exit "$ok"
