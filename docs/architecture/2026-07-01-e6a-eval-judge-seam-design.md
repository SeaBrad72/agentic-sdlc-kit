# Design — E6-a: pluggable eval-judge seam + pinned Claude reference adapter

**Date:** 2026-07-01
**Author:** Orchestrator (Architect hat), via `skills/design`
**Status:** Proposed — awaiting owner HARD-GATE approval
**Epic:** E6 (AI-native eval depth), slice 1 of ~4. Owner-approved E6 + reference-not-run framing 2026-07-01.

---

## Goal

Turn the kit's reference eval harness (`profiles/ml/evals/`) from a monolithic offline **stub** into a **provider-neutral pluggable judge seam** with a **pinned, independent, Claude-backed reference adapter** — the AI-native oracle the `evals` skill already prescribes but the harness doesn't yet embody. Ship it green-on-clone (offline default), with a conformance lock proving the seam + the pinned/independent/threshold contract, and an honest ceiling: *the reference is provided + structurally proven; live-eval-quality is the adopter's run.*

## Why (first principles, reconciled)

- **Eval-driven is a core principle** (`CLAUDE.md` #2): AI features gate on evals like code gates on tests. Exact-match can't score real AI output (summaries, classifications, replies) — LLM-as-judge is the standard oracle. Today's `score()` is exact-match with no seam.
- **LLM-neutrality** ([[llm-neutrality-goal]]): the judge **interface** is provider-neutral; **Claude is the default reference adapter**, not the interface — mirroring "Claude Code is the default harness, the kit is portable." An adopter can swap OpenAI/Gemini/local/human.
- **No-live-keys / green-on-clone** (the eval honesty invariant, `rubric.md`): the kit's CI runs offline judges; the live Claude judge is reference code an adopter runs with their key. Never read a live key into context.
- **Right-weight:** extend the existing harness + reuse the `conditional-gates`/`eval-ready` surface; add exactly one kit-self structural lock (the non-vacuity teeth for the seam). No heavyweight eval framework.

## What ships (slice 1)

All under `profiles/ml/evals/` (NOT control-plane → engineer TDDs + commits directly) except the lock/claim/version (AMBER):

1. **`judges.py`** *(new)* — the seam. A judge is a callable `score(input, candidate, expected, rubric) -> float in [0,1]`. Three reference judges behind one interface:
   - **`ExactMatchJudge`** — today's exact-match (the default; offline; preserves current behaviour for the toy task).
   - **`FakeRubricJudge`** — offline, **rubric-shaped** (takes the rubric, returns a deterministic score by keyword coverage). Its purpose: let CI exercise the *judge-dispatch + rubric-plumbing code path* green-on-clone, without a network — so the seam itself is non-vacuously tested, not just the exact-match path.
   - **`ClaudeJudge`** — the **pinned, independent** reference adapter. Lazily imports the `anthropic` SDK (so the harness never requires the SDK/key unless selected); pins model + version + `temperature=0`; sends `(input, candidate, expected, rubric)` to the judge model and parses a 0..1 score; asserts judge-independence (the judge model id must differ from the system-under-test id). **Not invoked by the default/CI path.** Exact model id per the `claude-api` skill at build time (do not hardcode a stale id).
2. **`run.py`** *(refactor)* — replace the hardcoded `score()` call with a `--judge {exact,fake,claude}` selector (default `exact`) resolved through `load_judge()`; the harness loop calls the selected judge. `generate()` (the system-under-test stub) stays; the seam is on the *scoring* side (the judge), which is E6-a's scope.
3. **`test_run.py`** *(new)* — the TDD proof: loads the golden set, runs the harness with `ExactMatchJudge` and `FakeRubricJudge`, asserts threshold gating (mean ≥ threshold → exit 0; a seeded-miss set → exit 1), asserts `load_judge("claude")` imports lazily (no `anthropic` needed to construct the others), and asserts `ClaudeJudge` refuses a self-grading config (judge id == SUT id → error). Runs offline.
4. **`rubric.md`** *(update)* — document the seam + the three judges + how to point `ClaudeJudge` at your pinned model; keep the offline-by-default honesty note.
5. **`conformance/eval-harness-wired.sh`** *(new, AMBER)* — kit-self structural lock (scope like `orchestrator-loop-wired.sh`): asserts the reference harness carries the seam (≥2 judges behind the `score(...rubric...)` interface, one rubric-shaped), a **pinned** + **independent** Claude adapter, a **threshold** gate, and **offline-by-default** (the default judge needs no network/key; Claude is lazy-imported + not the default). `--selftest` with a positive liveness anchor + load-bearing negatives (remove pinning → FAIL; make Claude the default/CI judge → FAIL; single-judge/no-seam → FAIL).
6. **`conformance/claims.tsv` + registry wiring** *(AMBER)* — new claim `eval-harness` mapped to the lock (the 3-edit registry: `claims.tsv` + `REQUIRED_IDS` + `verify.sh`). `verify --require` 39 → 40 controls.
7. **Version finishing** *(AMBER, folded into apply.py)* — VERSION 3.87.0 → 3.88.0, README badge, CHANGELOG.

## Honest ceiling (stated, per the design skill)

- **Provable (structural):** the seam exists (≥2 judges behind one rubric-shaped interface); the harness mechanics + seam dispatch run green-on-clone (proven by `test_run.py` with the fake judge + the lock's selftest); the Claude adapter is **pinned + independent + threshold-gated** and is **not** the default/CI judge; offline-by-default holds.
- **NOT provable (un-gateable):** that any real Claude model clears the quality bar — the kit's CI never calls the live provider. That is the adopter's live run with their key. **Judge calibration** (does the judge agree with humans?) and judge biases (verbosity/position/self-preference) are taught in `rubric.md`/`evals` skill, not gated. Ceiling: *"provided + wired + mechanics-proven; live-eval-quality un-gateable"* — the same ceiling as the `evals` skill.

## Build model & process

Hybrid: **GREEN code committed directly** by an engineer on the feature branch (`profiles/ml/evals/` — TDD: `test_run.py` red → seam green) + **AMBER `apply.py`** (human-run) for the control-plane lock + claim + version finishing. Subagent-driven: engineer builds the seam TDD; the `ClaudeJudge` author consults `skills/claude-api` for the pinned model id + SDK usage; independent Reviewer + Security-Reviewer (security lens: the adapter must not run in CI / leak keys, the lock's non-vacuity, judge-independence enforcement). Clone-prove the AMBER lock (`--selftest` flips, `verify --require` 40/0, `dash -n`/`shellcheck`).

## Riskiest assumption (tested here)

That a pluggable seam + pinned/independent Claude reference is *meaningfully* more provable than "stub + rubric.md prose." **Verdict: yes** — today the harness has no interface (you rewrite `score()` by hand) and nothing asserts pinning/independence; this slice ships a real seam + a lock that KILLs an unpinned or self-grading or run-in-CI judge. That is provable value the prose cannot give. (If the lock could only assert "a file exists," it would be hollow — so the lock's teeth are the pinned/independent/offline-default mutations, not mere presence.)

## Out of scope (later E6 slices)

Red-team/prompt-injection reference (E6-b) · LLM cost/quality closed loop into `agent-scorecard` (E6-c) · `gate-eval` secret-exposure/OIDC reference (E6-d). The seam is the foundation they build on.

## Terminal state

A committed, owner-approved spec, handed to `skills/plan`.
