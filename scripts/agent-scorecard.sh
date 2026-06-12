#!/bin/sh
# agent-scorecard.sh — per-agent behavior scorecard over a window of traces (MP-3b).
# Reads MP-3a-schema traces (scripts/agent-trace.sh output), groups by agent.id,
# computes trace-derivable behavior metrics over a window, classifies each agent
# regressed|steady|earned vs its OWN trailing baseline, and emits a scorecard +
# the asymmetric tier directive (auto-downgrade on regression / ratified-raise
# recommendation on earned). It EMITS directives; it NEVER actuates (never touches
# .claude/, the guard, or any tier store). sh + jq, mirroring scripts/agent-trace.sh.
#
# Honesty: "unknown" trace fields are EXCLUDED from a metric (never coerced to 0).
# Thin data (< --min-runs) or absent data -> steady, no directive (fail-safe).
# A green --selftest proves correct COMPUTATION on a fixture, not that any real
# agent behaved. It is a tool, not a gate; it fails no PR.
#
# Usage:
#   scripts/agent-scorecard.sh [--traces DIR] [--window N] [--min-runs N] \
#       [--margin F] [--out DIR] [--stdout]
#   scripts/agent-scorecard.sh --selftest
set -eu

TRACES="traces"; WINDOW=20; MIN_RUNS=5; MARGIN="0.15"; OUTDIR="scorecards"; STDOUT=0
DO_SELFTEST=0

# --- arg parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --selftest)  DO_SELFTEST=1; shift ;;
    --traces)    TRACES="${2:?--traces needs a dir}"; shift 2 ;;
    --window)    WINDOW="${2:?--window needs a value}"; shift 2 ;;
    --min-runs)  MIN_RUNS="${2:?--min-runs needs a value}"; shift 2 ;;
    --margin)    MARGIN="${2:?--margin needs a value}"; shift 2 ;;
    --out)       OUTDIR="${2:?--out needs a dir}"; shift 2 ;;
    --stdout)    STDOUT=1; shift ;;
    -*)          printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *)           printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

# score_agent: stdin = JSON array of an agent's trace objects; args control thresholds.
# Emits the per-agent scorecard object (metrics + classification + directive).
# All metric math + classification is in jq (no JSON parsed in sh).
score_agent() {
  jq -s --argjson window "$WINDOW" --argjson minruns "$MIN_RUNS" \
        --argjson margin "$MARGIN" '
    (sort_by(.start) | (if length > $window then .[-$window:] else . end)) as $runs
    | ($runs | length) as $n
    | ($runs[: ($n/2 | floor)]) as $base
    | ($runs[($n/2 | floor):]) as $rec
    | def denial($a): ($a | [.[].steps[]?.outcome] | if length==0 then 0
                       else (map(select(.=="denied")) | length) / length end);
      def errrate($a): ($a | if length==0 then 0
                       else (map(select(.outcome=="error" or .outcome=="blocked")) | length)/length end);
      def retry($a): ($a | if length==0 then 0 else (map([.steps[]?.retries] | add // 0) | add / length) end);
      def reviews($a): ($a | [.[]."review.rounds" | select(type=="number")]
                       | if length==0 then null else (add/length) end);
    {
      "agent.id": ($runs[0]["agent.id"] // "unknown"),
      runs: $n,
      metrics: {
        denial_rate: denial($runs), error_blocked_rate: errrate($runs),
        retry_rate: retry($runs), review_rounds_mean: reviews($runs),
        gate_skip_rate: "unknown"
      },
      baseline: {denial: denial($base), err: errrate($base)},
      recent:   {denial: denial($rec), err: errrate($rec)}
    }
    | .classification = (
        if $n < $minruns then "steady"
        elif (.recent.denial - .baseline.denial) >= $margin
             or (.recent.err - .baseline.err) >= $margin then "regressed"
        elif (.recent.denial == 0 and .recent.err == 0)
             and (.baseline.denial > 0 or .baseline.err > 0) then "earned"
        else "steady" end )
    | .directive = (
        if .classification == "regressed" then
          {action:"auto-downgrade", reason:"recent risk metrics exceed trailing baseline by >= margin",
           recommend:"lower this agent'\''s autonomy tier one level (fail-safe; no ratification needed)"}
        elif .classification == "earned" then
          {action:"raise-recommendation", reason:"sustained improvement vs trailing baseline",
           recommend:"route to Security owner to ratify a one-level autonomy-tier raise (§13)"}
        else null end )
  '
}

# run_all: group all traces by agent.id, score each, collect into one report array.
run_all() {
  _dir="$1"
  # Handle missing or empty traces dir gracefully
  if [ ! -d "$_dir" ] || [ -z "$(ls "$_dir"/*.json 2>/dev/null)" ]; then
    printf '[]'
    return 0
  fi
  _agents=$(jq -r '."agent.id" // "unknown"' "$_dir"/*.json 2>/dev/null | sort -u)
  if [ -z "$_agents" ]; then
    printf '[]'
    return 0
  fi
  printf '['
  _first=1
  for _a in $_agents; do
    _card=$(jq -c --arg a "$_a" 'select(."agent.id" == $a)' "$_dir"/*.json | score_agent)
    [ "$_first" -eq 1 ] && _first=0 || printf ','
    printf '%s' "$_card"
  done
  printf ']'
}

selftest() {
  st_fail=0
  fx="$(dirname "$0")/fixtures/scorecard"
  WINDOW=6; MIN_RUNS=2; MARGIN="0.15"
  out=$(run_all "$fx")
  _cls() { printf '%s' "$out" | jq -r --arg a "$1" '.[] | select(."agent.id"==$a) | .classification'; }
  [ "$(_cls good-bot)" = "earned" ]     || { echo "selftest FAIL: good-bot should be earned (got $(_cls good-bot))"; st_fail=1; }
  [ "$(_cls bad-bot)" = "regressed" ]   || { echo "selftest FAIL: bad-bot should be regressed (got $(_cls bad-bot))"; st_fail=1; }
  [ "$(_cls thin-bot)" = "steady" ]     || { echo "selftest FAIL: thin-bot should be steady (got $(_cls thin-bot))"; st_fail=1; }
  # directive presence matches classification
  [ "$(printf '%s' "$out" | jq -r '.[]|select(."agent.id"=="bad-bot")|.directive.action')" = "auto-downgrade" ] \
      || { echo "selftest FAIL: bad-bot needs an auto-downgrade directive"; st_fail=1; }
  [ "$(printf '%s' "$out" | jq -r '.[]|select(."agent.id"=="good-bot")|.directive.action')" = "raise-recommendation" ] \
      || { echo "selftest FAIL: good-bot needs a raise-recommendation"; st_fail=1; }
  [ "$(printf '%s' "$out" | jq -r '.[]|select(."agent.id"=="thin-bot")|.directive')" = "null" ] \
      || { echo "selftest FAIL: thin-bot must have no directive"; st_fail=1; }
  # honesty: gate_skip_rate stays unknown (never coerced to a number)
  [ "$(printf '%s' "$out" | jq -r '.[0].metrics.gate_skip_rate')" = "unknown" ] \
      || { echo "selftest FAIL: gate_skip_rate must be unknown"; st_fail=1; }
  if [ "$st_fail" -ne 0 ]; then echo "agent-scorecard --selftest: FAIL" >&2; return 1; fi
  echo "agent-scorecard --selftest: OK (earned/regressed/steady + directives + unknown-honesty all match the fixtures)"
  return 0
}

# --- dispatch ---
if [ "$DO_SELFTEST" -eq 1 ]; then
  selftest; exit $?
fi

result=$(run_all "$TRACES")

if [ "$STDOUT" -eq 1 ]; then
  printf '%s\n' "$result"
else
  mkdir -p "$OUTDIR"
  # Write each agent's card to its own file; slug agent-id for filesystem safety.
  printf '%s' "$result" | jq -c '.[]' | while IFS= read -r card; do
    _aid=$(printf '%s' "$card" | jq -r '."agent.id" // "unknown"')
    _slug=$(printf '%s' "$_aid" | tr -c 'A-Za-z0-9._-' '_')
    printf '%s\n' "$card" | jq . > "$OUTDIR/$_slug.json"
    printf 'agent-scorecard: wrote %s/%s.json\n' "$OUTDIR" "$_slug"
  done
fi
