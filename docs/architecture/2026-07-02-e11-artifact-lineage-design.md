# E11 — Produced-Artifact Lineage (design)

**Date:** 2026-07-02 · **Epic:** E11 (AI-artifact lifecycle / audit) · **Target version:** 3.92.0 (minor)
**Status:** owner-approved design → hand to `skills/plan`.
**Scoping skill:** `superpowers:brainstorming` (E11 outcome). **Design skill:** kit `skills/design`.

---

## 1. Context & scoping decision

E11 was flagged in `docs/ROADMAP-KIT.md` as *"AI-artifact lifecycle / audit vertical (≤2 slices) — may be absorbed by E6; brainstorm to confirm it's distinct."* This slice is the resolution of that scoping brainstorm.

**Grounding (2026-07-02).** The kit already covers four *coarser* altitudes of AI accountability, and a grep confirmed **no** per-output mechanism exists:

| Altitude | Covered by |
|---|---|
| The **system** | `templates/AI-SYSTEM-CARD-TEMPLATE.md` + `conformance/responsible-ai-ready.sh` |
| **What was tested** | `templates/EVAL-PLAN-TEMPLATE.md` + the E6 judge/red-team infra (`profiles/ml/evals/`) |
| **What the agent did** | `scripts/agent-trace.sh` / `agent-scorecard.sh` / OTel |
| **What went into the build** | SBOM + SLSA (`supply-chain-verify.sh`, `provenance-precondition.sh`) |

**The one genuine, distinct gap = per-*output* lineage.** Nothing ties a *produced* AI artifact (a generated dataset, a fine-tuned model, a shipped model output) back to the **model id + version**, **prompt/template version**, **input dataset version**, and **eval-plan + eval-score** that produced it. This is the established ML-ops artifact class (Google **Model Cards**, **Datasheets for Datasets**, experiment lineage). It is a natural **E6 follow-on** — it *composes* the E6 eval infra into a record — which is why the roadmap said "may be absorbed by E6." The brainstorm's verdict: **distinct enough to warrant one small slice.**

**Why this is not the "build-ahead" trap.** That trap is about building *machinery* with no consumer. This slice ships a **template + doc-coherence lock** — the same shape as *every* AI-governance artifact in the kit (all reference-for-adopters). "No live AI system in the kit" is the norm for this whole class, not a disqualifier.

## 2. Goal & non-goals

**Goal.** Give adopters a per-output lineage record that ties a produced AI artifact back to the model + prompt + inputs + eval that made it, plus its governance links — and a kit-self doc-coherence lock that keeps the template structurally honest. Closes E11.

**Non-goals (explicit YAGNI):**
- No running lineage-capture system, CLI, or automation (the kit has no live AI system producing artifacts).
- No verification that any *real* artifact's lineage is accurate or truthful (un-gateable; see §6 Honest ceiling).
- No secret-scanning (the required non-waivable `secret-scan` gate already covers committed keys).
- No fold into `AI-SYSTEM-CARD` (wrong altitude — one System Card per system, but *many* lineage records per system; folding would violate the kit's single-purpose principle).

## 3. The template — `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` (GREEN)

Lean, **6 sections**, self-documenting inline (guidance beside each field, in the style of the existing intake templates). One record per produced artifact.

1. **Artifact** — id/name, version-or-hash, type (dataset / fine-tuned model / generated output), produced-at (date).
2. **Producing model** — model id + version (e.g. `claude-opus-4-8`), provider.
3. **Prompt / template** — prompt or template id + version (or hash).
4. **Inputs** — input dataset / source version(s).
5. **Evaluation** *(the E6 tie-in)* — eval-plan reference, eval-score(s), judge id. Links to `templates/EVAL-PLAN-TEMPLATE.md` and the `profiles/ml/evals/` judge output.
6. **Governance** — linked `AI-SYSTEM-CARD`, intended use, known limitations, **human sign-off** (owner + date).

The file lives in non-control-plane `templates/`, so it is a **GREEN direct-commit** (no `apply.py`).

## 4. The lock — `conformance/artifact-lineage-ready.sh` (AMBER)

A kit-self **doc-coherence check**, structurally mirroring the most recent precedent `conformance/gate-eval-secrets-ready.sh` (E6-d):

- **Target:** `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` (override via an env var for the selftest, per precedent).
- **Assertion:** the template is present **and** carries one distinctive load-bearing marker per section (**6 markers**, one per line in the source). Candidate markers (final strings settled in build): `Artifact version` · `Producing model` · `Prompt/template version` · `Input dataset version` · `Eval score` · `Human sign-off`. Each is distinctive enough that a generic provenance doc lacks it; §5's marker is the eval tie-in that distinguishes this from plain provenance.
- **Kit-self N/A:** outside the kit repo (no `docs/ROADMAP-KIT.md` and no template) the check skip-passes — identical to the precedent.
- **`--selftest`:** a conformant fixture → exit 0 (**liveness anchor**) **+ 6 load-bearing negatives** — drop each marker's line in turn → exit 1. **One-marker-per-line fixture** so each negative isolates exactly one section (the non-vacuity scar: a shared fixture line lets one `grep -v` silently delete a neighbour's evidence).
- **Exit codes:** 0 = OK or N/A · 1 = FAIL · 2 = usage. POSIX sh, dash-clean.

`conformance/` **is** control-plane → the lock and every wiring edit below ship via **AMBER `apply.py`**.

## 5. Wiring, discoverability & registry facts (AMBER)

- **`conformance/verify.sh`** — register the **15th doc-check**: `check doc     artifact-lineage sh conformance/artifact-lineage-ready.sh` (main-path, no `--selftest`, matching the other `check doc` rows).
- **`.github/workflows/ci.yml`** — add a **basename reference** to run `artifact-lineage-ready.sh --selftest` (the `ci-selftest-coverage` scar: a new `--selftest` check must be referenced by basename in `ci.yml`, else `ci-selftest-coverage.sh` goes RED).
- **`CLAUDE.md`** — add `AI-ARTIFACT-LINEAGE` to the `templates/` index line in the document-set table (passive catalog entry, one line).
- **`conformance/responsible-ai-readiness.md`** — add **one `(verified)` Manual checklist row (row 9)** pointing at `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md`, mirroring how row 5 points at `EVAL-PLAN` and row 6 at `AI-TRANSPARENCY-SIGNOFF`. **Active surfacing at the §7 responsible-AI gate** — the discovery path an industry practitioner expects (Model Cards/datasheets *are* responsible-AI artifacts). **No change to `responsible-ai-ready.sh`** — manual rows are not auto-checked; no new marker, claim, or gate.
- **`docs/ROADMAP-KIT.md`** — flip E11 from "loosely scoped / may be absorbed" to **resolved** (one slice: produced-artifact lineage template + lock, v3.92.0).
- **Release finishing folded into `apply.py`** ([[release-finishing-in-apply-py]] scar): `VERSION` 3.91.0 → **3.92.0**, `README`, `CHANGELOG`.

**Registry facts.** **NOT a claim** — doc-ready checks carry no `claims.tsv` / `REQUIRED_IDS` entry (standing scar). Counts move **14 → 15 doc-checks**; **control-check count stays 40**; total **55**.

## 6. Honest ceiling (stated here and in the lock header)

A green `artifact-lineage-ready.sh` proves the template is **present and still carries its six load-bearing marker phrases** — that the record *asks for* model + prompt + inputs + eval + governance. Because the markers are matched fixed-string *anywhere* in the file (not anchored to their field syntax), the check guards the kit's own template against a field being **silently dropped** — but it can **never** prove:
- an adopter filled those fields in **truthfully**, or
- any real artifact's stated lineage is **accurate**.

That is the same ceiling as every kit template (reference-for-adopters). The lock guards marker-phrase presence; truthfulness is the adopter's owner-signed responsibility (the §6 human sign-off row). A green check is *necessary, not sufficient* — matching the exact framing already used in `responsible-ai-readiness.md`. *(A future optional hardening — anchoring each marker to its bold field-label form — is banked; the markers are distinctive multi-word phrases that appear only on their field rows in the shipped template, so field-drop is already caught.)*

## 7. Non-vacuity plan

- **Liveness anchor:** the conformant fixture passes (exit 0).
- **Load-bearing negatives:** one per section marker (6) — the lock must FAIL when any section's marker *phrase* is absent, proving each marker is load-bearing, not decorative (it proves the phrase is load-bearing, not that the field is filled — see §6 honest ceiling).
- **One-marker-per-line fixture** so a per-negative `grep -v` cannot collaterally delete a neighbouring marker (the shared-fixture-line vacuity scar).

## 8. Control-plane completeness — N/A

This slice creates **no new control-plane path** (the template lives in non-CP `templates/`). The three-matcher lock + per-mutation-form agent-autonomy fixture rule (which applies only when a slice *makes* a path control-plane) does **not** apply here. `conformance/*` is already control-plane by the existing `is_control_plane_path` glob; nothing new is guarded.

## 9. Build & ship flow

Hybrid, E6-d shape:
1. **GREEN** — commit `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` directly.
2. **AMBER** — `apply.py` (via `gen.py` → base64+JSON payload; honors an explicit root arg with a loud print; sentinel-gated idempotent; fail-closed anchors) writes the lock + all wiring edits + folds the version finishing. **Clone-prove** idempotent in a real clone.
3. **Dual review** — `reviewer` (builder ≠ reviewer) + `security-reviewer` with the security lens trying to **defeat** the lock (can a vacuous template pass? can a marker hide in a comment?).
4. **Owner ships** — run `apply.py` → commit → push → PR → `gh pr merge --admin` (solo control-plane goes RED on `control-plane-ratification` **by design** — [[control-plane-ratification-by-design]]) → checkout main → `sh scripts/release-tag.sh`.

Build subagent-driven via the kit's own `skills/plan` → `skills/build` (self-hosting commitment; zero superpowers).

## 10. File manifest

| File | Zone | Change |
|---|---|---|
| `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` | GREEN | New lean 6-section template |
| `conformance/artifact-lineage-ready.sh` | AMBER | New doc-coherence lock (mirrors `gate-eval-secrets-ready.sh`) |
| `conformance/verify.sh` | AMBER | Register 15th doc-check |
| `.github/workflows/ci.yml` | AMBER | Basename ref for `--selftest` |
| `CLAUDE.md` | AMBER | Add template to the index line |
| `conformance/responsible-ai-readiness.md` | AMBER | One `(verified)` row 9 → the lineage template |
| `docs/ROADMAP-KIT.md` | AMBER | E11 resolved |
| `VERSION` · `README` · `CHANGELOG` | AMBER | 3.91.0 → 3.92.0, folded into apply.py |
