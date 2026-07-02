# Design — E6-d: gate-eval secret-exposure reference (C5) — closes epic E6

**Date:** 2026-07-02
**Author:** Orchestrator (Architect hat), via `skills/design`
**Status:** Proposed — owner approved E6-d (doc-reference + coherence lock) + build-end-to-end 2026-07-02.
**Epic:** E6 (AI-native eval depth), slice 4 of 4 — **the epic closer.**

## Goal

Fill the one gap in the kit's AI-secret story: a written **gate-eval secret-handling reference** for how the eval runner obtains its live credential securely — a short-lived OIDC-minted token, never an embedded long-lived key — plus a small kit-self coherence lock so the reference can't silently rot. This closes E6.

## Why this is a reference, not a scanner (the honest scope)

The kit's **`secret-scan` gate is required and non-waivable** (`DEVELOPMENT-STANDARDS.md` line 218, the Brownfield-exception clause) with no `profiles/` exclusion, so a hardcoded key committed into the eval runner/plan is **already caught**. Building a new eval-specific secret scanner would be redundant (proven-but-already-covered). The genuine gap: `docs/operations/secrets-for-ai.md` today shows only static `gh secret set` and *points at* `secrets-at-scale.md` for OIDC — there is no written OIDC/short-lived-credential guidance for the **eval runner** specifically. E6-d writes that reference and locks its presence. (The roadmap literally says "gate-eval secret-exposure **reference** (C5).")

## What ships (slice 4)

- **`docs/operations/secrets-for-ai.md`** *(GREEN-direct — `docs/operations/` is NOT control-plane)* — a new **"## Gate-eval secret handling (C5)"** section: the eval CI job mints a **short-lived** credential via **OIDC** (restricted to push-to-main), the key is **never embedded** in the repo/image/logs, and the existing non-waivable **`secret-scan`** gate catches any committed key in eval artifacts. Provider-neutral. Cross-links `secrets-at-scale.md` (managed stores/rotation) and the guard secret-read speed-bump.
- **`conformance/gate-eval-secrets-ready.sh`** *(AMBER, new)* — a **kit-self doc-coherence lock** (mirrors `eval-ready`/`responsible-ai-ready`, kit-self N/A pattern like `eval-harness-wired`): asserts `secrets-for-ai.md` carries the gate-eval section with its load-bearing markers. `--selftest`: a conformant fixture → PASS + one negative per marker → FAIL (non-vacuous). Kit-self N/A outside the kit repo.
- **`conformance/verify.sh`** *(AMBER)* — `check doc gate-eval-secrets sh conformance/gate-eval-secrets-ready.sh` (doc-check; 13 → 14 doc-checks; **control count stays 40**; doc-checks aren't claims, so NO claims.tsv/REQUIRED_IDS edit).
- **`.github/workflows/ci.yml`** *(AMBER)* — a `--selftest` step (required by `ci-selftest-coverage`, which the E6-a clone-proof taught us).
- **Version finishing** *(AMBER apply.py)* — VERSION 3.90.0 → 3.91.0, README badge, CHANGELOG.

## Marker contract (doc + lock agree, byte-exact)

The lock greps `secrets-for-ai.md` for: `gate-eval secret handling` · `OIDC` · `short-lived` · `never embedded` · `secret-scan`. The doc section carries all five verbatim; a generic paraphrase fails the lock.

## Honest ceiling

- **Provable (structural):** the reference exists in the kit's doc, carries the load-bearing markers, and is locked (a dropped marker fails `--selftest`). Committed-key detection in eval artifacts is the **existing non-waivable `secret-scan`** gate (pointed at, not rebuilt).
- **NOT provable (un-gateable):** that an adopter's live OIDC/secrets-manager setup is actually secure — that is the adopter's infrastructure. The kit documents + locks the *reference*, not the adopter's runtime. Ceiling: *reference provided + structurally proven; live secret-infra security is the adopter's.*

## Build model & process

Hybrid: GREEN `secrets-for-ai.md` (engineer, direct commit) + AMBER `apply.py` (lock + verify.sh + ci.yml + version). Independent Reviewer + Security-Reviewer (security lens: the reference is sound guidance — OIDC short-lived beats embedded key — and the lock's non-vacuity; confirm no secret material is written into the doc). Clone-prove (`--selftest`, `verify --require` 40 control/14 doc / 0 failed, `dash -n`/`shellcheck`, ci-selftest-coverage).

## Riskiest assumption

That a documented + locked reference is *meaningful* here (vs a pure-doc slice). **Verdict: yes** — the lock's teeth are the OIDC/short-lived/never-embedded markers (a reference that lost them would silently regress to "just use a static secret"); and the scope is honest (enforcement lives in the existing secret-scan, not a redundant new scanner). It fills a real, named gap without rebuilding covered ground.

## Epic close

After E6-d: **epic E6 (AI-native eval depth) is COMPLETE** — real eval harness (a) · red-team/injection defense (b) · cost/quality loop (c) · gate-eval secret reference (d). Follow-on: a short **E11 scoping brainstorm** (AI-artifact lifecycle/audit — likely largely covered).

## Terminal state

Committed, owner-approved spec → handed to `skills/plan`.
