#!/bin/sh
# otel-trace.sh — zero-dep OTel-shaped span emitter (E5-thin sensor).
# Emits one OTel-semantic span per NDJSON line to a pluggable sink. Fields map
# 1:1 to OTLP (scripts/otlp-export.sh wraps them). NOT a gate — a reference
# adapter, like scripts/agent-trace.sh. sh + jq.
set -eu

# portable: 16/8-byte random hex id (trace=32 hex, span=16 hex)
rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }
new_trace() { rand_hex 16; }

# portable unix-nanos: prefer date +%s%N (GNU); fall back to seconds * 1e9 (macOS/BSD)
now_nano() {
  _n=$(date +%s%N 2>/dev/null)
  case "$_n" in *N|"") printf '%s000000000' "$(date +%s)";; *) printf '%s' "$_n";; esac
}

# emit_span TRACE NAME PARENT STATUS START END [k=v ...]  -> prints span_id, writes a line
emit_span() {
  _trace="$1"; _name="$2"; _parent="$3"; _status="${4:-OK}"; _start="${5:-}"; _end="${6:-}"
  shift 6 || shift $#
  _sid=$(rand_hex 8)
  [ -n "$_start" ] || _start=$(now_nano)
  [ -n "$_end" ]   || _end=$(now_nano)
  # build the attributes object from remaining k=v args (jq, never hand-built)
  _attrs='{}'
  for kv in "$@"; do
    _k=${kv%%=*}; _v=${kv#*=}
    _attrs=$(printf '%s' "$_attrs" | jq --arg k "$_k" --arg v "$_v" '.[$k]=$v')
  done
  _line=$(jq -nc \
    --arg t "$_trace" --arg s "$_sid" --arg p "$_parent" --arg n "$_name" \
    --argjson st "$_start" --argjson en "$_end" \
    --argjson attrs "$_attrs" --arg code "$_status" \
    '{ trace_id:$t, span_id:$s,
       parent_span_id: (if $p=="" then null else $p end),
       name:$n, start_unix_nano:$st, end_unix_nano:$en,
       attributes:$attrs, status:{code:$code} }')
  if [ -n "${OTEL_TRACE_FILE:-}" ]; then
    printf '%s\n' "$_line" >> "$OTEL_TRACE_FILE"
  else
    printf '%s\n' "$_line"
  fi
  printf '%s' "$_sid"
}

selftest() {
  st_fail=0
  tid=$(new_trace)
  [ "$(printf '%s' "$tid" | wc -c | tr -d ' ')" = "32" ] || { echo "FAIL: trace_id not 32 hex"; st_fail=1; }
  sink=$(mktemp)
  root=$(OTEL_TRACE_FILE="$sink" emit_span "$tid" "orchestrator-run" "" "OK" "" "" "agent.id=orchestrator")
  # shellcheck disable=SC2034  # child is verified indirectly via sink (tail-1 assertion below)
  child=$(OTEL_TRACE_FILE="$sink" emit_span "$tid" "agent:engineer" "$root" "OK" "" "" "agent.id=engineer")
  # one span per line
  [ "$(wc -l < "$sink" | tr -d ' ')" = "2" ] || { echo "FAIL: expected 2 span lines"; st_fail=1; }
  # OTel-semantic keys present on line 1
  for k in trace_id span_id parent_span_id name start_unix_nano end_unix_nano attributes status; do
    [ "$(head -1 "$sink" | jq -e "has(\"$k\")")" = "true" ] || { echo "FAIL: missing key $k"; st_fail=1; }
  done
  # parent linkage: child.parent_span_id == root span_id; root parent is null
  [ "$(head -1 "$sink" | jq -r '.parent_span_id')" = "null" ] || { echo "FAIL: root parent not null"; st_fail=1; }
  [ "$(tail -1 "$sink" | jq -r '.parent_span_id')" = "$root" ] || { echo "FAIL: child not linked to root"; st_fail=1; }
  [ "$(tail -1 "$sink" | jq -r '.attributes["agent.id"]')" = "engineer" ] || { echo "FAIL: attr lost"; st_fail=1; }
  rm -f "$sink"
  [ "$st_fail" -eq 0 ] || { echo "otel-trace --selftest: FAIL" >&2; return 1; }
  echo "otel-trace --selftest: OK (ids, span lines, OTel keys, parent linkage, attrs)"; return 0
}

# --- dispatch ---
case "${1:-}" in
  --selftest) selftest; exit $? ;;
  new-trace)  new_trace; echo; exit 0 ;;
  span)
    shift
    _trace=""; _name=""; _parent=""; _status="OK"; _start=""; _end=""
    _attrs_list=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --trace)  _trace="${2:?--trace needs a value}"; shift 2 ;;
        --name)   _name="${2:?--name needs a value}"; shift 2 ;;
        --parent) _parent="${2:?--parent needs a value}"; shift 2 ;;
        --attr)
          _kv="${2:?--attr needs k=v}"
          if [ -z "$_attrs_list" ]; then _attrs_list="$_kv"; else _attrs_list="$_attrs_list
$_kv"; fi
          shift 2 ;;
        --status) _status="${2:?--status needs OK|ERROR}"; shift 2 ;;
        --start)  _start="${2:?--start needs nanos}"; shift 2 ;;
        --end)    _end="${2:?--end needs nanos}"; shift 2 ;;
        --sink)
          OTEL_TRACE_FILE="${2:?--sink needs a path}"; export OTEL_TRACE_FILE; shift 2 ;;
        -*)       printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
        *)        break ;;
      esac
    done
    # shellcheck disable=SC2086  # word-splitting the newline-delimited attr list is intended
    if [ -n "$_attrs_list" ]; then
      emit_span "$_trace" "$_name" "$_parent" "$_status" "$_start" "$_end" $_attrs_list
    else
      emit_span "$_trace" "$_name" "$_parent" "$_status" "$_start" "$_end"
    fi
    echo
    exit 0
    ;;
  "")
    printf 'usage: otel-trace.sh new-trace | span --trace ID --name NAME [opts] | --selftest\n' >&2
    exit 2
    ;;
  *)
    printf 'unknown subcommand: %s\n' "$1" >&2; exit 2
    ;;
esac
