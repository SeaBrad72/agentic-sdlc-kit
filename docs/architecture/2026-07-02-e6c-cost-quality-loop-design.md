# Design — E6-c: LLM cost/quality tracing loop (into the agent scorecard)

**Date:** 2026-07-02
**Author:** Orchestrator (Architect hat), via `skills/design`
**Status:** Proposed — owner approved E6-c + build-end-to-end 2026-07-02.
**Epic:** E6 (AI-native eval depth), slice 3 of ~4. Builds on the E5 operate-loop sensor.

## Goal

Give the kit's proven per-agent scorecard an **LLM cost + quality dimension**: extend `agent-scorecard.sh` with `cost_per_run` + `eval_score_mean`, mapped from OTel span attributes by `otel-to-scorecard.sh`, feeding the **existing** `regressed → auto-downgrade` tier directive. So a cost spike or a quality drop closes the same loop that a denial/error regression already does — advisory, never actuating.

## The gap

`agent-scorecard.sh` scores *behavior* (denial/error/retry/review-rounds) over a trailing window and emits an auto-downgrade directive on regression. It has **no cost or quality metric** — the two dimensions that matter most for an LLM agent (budget burn, output quality). `otel-to-scorecard.sh` maps OTel spans → scorecard records but carries no cost/eval fields. The roadmap's "LLM cost/quality tracing closed loop" (E6-c) fills this.

## What ships (slice 3)

**Build-model correction (found during build):** `scripts/agent-scorecard.sh` and `scripts/fixtures/*` ARE control-plane (`is_control_plane_path` lines 27, 25) — the scorecard emits tier directives and fixtures back conformance selftests, so a human must review + apply. So this is an **all-AMBER** slice: everything is authored GREEN and applied via a human-run `apply.py`; only `scripts/otel-to-scorecard.sh` is non-CP (folded into the same apply.py for one coherent artifact). The branch carries only the design doc. (My initial "GREEN-direct" read was wrong — retro: verify `is_control_plane_path` membership per file at design time.)

1. **`scripts/agent-scorecard.sh`** (GREEN) — add two metrics to the jq `score`:
   - `cost_per_run` = mean of the numeric `.cost` field over the window (`null` if **no** run carries it — exclude-unknown, never 0).
   - `eval_score_mean` = mean of the numeric `.["eval.score"]` field (`null` if absent — exclude-unknown).
   Extend the classification with two regression dimensions (either → `regressed` → the existing `auto-downgrade` directive):
   - **cost spike:** `recent.cost > baseline.cost * (1 + $cost_margin)` (relative — cost is unbounded, unlike a 0–1 rate). New `--cost-margin` flag, default `0.25` (a 25% spike).
   - **quality drop:** `baseline.eval - recent.eval >= $margin` (absolute — eval score is 0–1, reuses the existing `--margin`).
   Both fire **only when the data is present** in both halves (thin/absent → no signal, fail-safe steady).
2. **`scripts/otel-to-scorecard.sh`** (GREEN) — map, exclude-unknown (emit the field only when the attribute is present, do NOT default to 0):
   - `attributes["gen_ai.usage.cost"]` → `.cost` (OTel GenAI semconv-aligned; adopter supplies a currency-agnostic number — no pricing table embedded, LLM-neutral).
   - `attributes["eval.score"]` → `.["eval.score"]`.
3. **Fixtures** (GREEN) — add `cost`/`eval.score` to `fixtures/scorecard/*.json` and two new fixture agents: `cost-spike-bot` (rising cost → regressed) and `quality-drop-bot` (falling eval → regressed); add `gen_ai.usage.cost`/`eval.score` attributes to `fixtures/otel-trace-sample.ndjson`.
4. **Selftests** (GREEN) — extend both `--selftest`s: assert the new metrics compute; the cost-spike and quality-drop agents classify `regressed` with an auto-downgrade directive; and **exclude-unknown honesty** — an agent with no cost/eval data reports `cost_per_run: null` / `eval_score_mean: null`, never 0, and gets no false regression.
5. **`conformance/agentops-sensor-wired.sh`** *(AMBER, small)* — add `sh scripts/agent-scorecard.sh --selftest` to the four sensor-selftest assertions (§1 block). Today the lock runs the other three sensor scripts' selftests but **not** the scorecard's — so the cost/quality logic would have no `verify --require` coverage. This closes that gap (no new claim; the `agentops-sensor` control gains the scorecard selftest). Extend the lock's own `--selftest`/comments accordingly.
6. **Version finishing** *(AMBER apply.py)* — VERSION 3.89.0 → 3.90.0, README badge, CHANGELOG.

## Honest ceiling

- **Provable (offline, on fixtures):** the cost/quality metrics compute correctly; a cost spike / quality drop classifies `regressed` and emits the auto-downgrade directive; exclude-unknown honesty holds (null, never 0; no false regression on thin data). Proven by the extended `--selftest`s (run in CI + now in the `agentops-sensor` control).
- **NOT provable (un-gateable):** that any **real** agent's cost/quality was measured — the kit has no live LLM system emitting cost/eval spans; the metrics compute over synthetic traces (exactly as the existing behavior metrics do: "LLM agent work exercised live, substituted in CI"). Ceiling: *computation + mapping + regression proven on fixtures; live cost/quality is the adopter's run.*
- **Why this is NOT build-ahead:** it extends a *proven, shipped* mechanism (the scorecard + the `regressed→auto-downgrade` directive + the sensor lock) with two new dimensions and reuses the existing directive — it does not build a new speculative loop. It is also the prerequisite half of the already-banked `auto-GO ← scorecard-live` item (which stays deferred).

## Neutrality

`cost` is an adopter-supplied number (no embedded pricing); token/cost attribute names align with the OTel GenAI semantic conventions (`gen_ai.usage.*`). No Claude-specificity — any LLM's telemetry maps in.

## Build model & process

Hybrid: GREEN `scripts/` + fixtures TDD'd + committed direct; AMBER apply.py for the one `agentops-sensor-wired.sh` edit + version finishing. Engineer TDD (jq + sh) → dual review (security lens = the exclude-unknown honesty can't be gamed into a false regression/false-clean; the directive stays advisory-not-actuating) → clone-prove (both selftests, the sensor lock, `verify --require` 40/0, `dash -n`/`shellcheck`). Note: `jq` is a dependency of these scripts (already so).

## Riskiest assumption

That cost/quality-as-scorecard-dimensions is *meaningfully* provable offline, not theater. **Verdict: yes** — the regression math + exclude-unknown honesty + the directive are the same proven shape as the shipped behavior metrics; the new fixtures (cost-spike / quality-drop) discriminate a real classification change. The un-gateable part (live measurement) is honestly disclosed, exactly as the existing scorecard.

## Out of scope (later)

E6-d (gate-eval secret-exposure). Token-derived cost with a pricing config, and wiring auto-GO to the live scorecard, stay banked.

## Terminal state

Committed, owner-approved spec → handed to `skills/plan`.
