# E11 — Produced-Artifact Lineage (implementation plan)

**Spec:** `docs/architecture/2026-07-02-e11-artifact-lineage-design.md` (owner-approved).
**Plan skill:** kit `skills/plan`. **Next:** kit `skills/build`.

## Header

- **Goal.** Ship a lean per-output AI-artifact lineage template + a kit-self doc-coherence lock, closing E11.
- **Architecture.** A GREEN template in non-control-plane `templates/`, guarded by a new AMBER doc-coherence check in `conformance/` (mirroring `gate-eval-secrets-ready.sh`), wired as the 15th `check doc` in `verify.sh`, self-tested in CI, and surfaced from the responsible-AI checklist + the `CLAUDE.md` template index. All control-plane edits land via one idempotent `apply.py`.
- **Tech stack.** POSIX sh (dash-clean), Markdown, GitHub Actions YAML, a Python `apply.py`/`gen.py` (base64+JSON payload).
- **Global constraints (verbatim from spec §5–§8).** NOT a claim (no `claims.tsv`/`REQUIRED_IDS`). Counts: **14→15 doc-checks; 40 control unchanged; 55 total.** Non-vacuity: anchor + 6 load-bearing negatives, **one marker per fixture line.** No new control-plane path is created → three-matcher/autonomy-fixture rule N/A. Honest ceiling: proves structural completeness, never truthfulness.
- **Build model: AMBER.** Tasks 2–3 touch control-plane (`conformance/*`, `verify.sh`, `ci.yml`, `CLAUDE.md`, `docs/ROADMAP-KIT.md`) → authored under `scratchpad/`, assembled into `apply.py`, clone-proven, human-applied. Task 1 is GREEN (non-CP `templates/`).

## The 6 load-bearing markers (pinned — identical strings in template AND lock)

`Artifact version` · `Producing model` · `Prompt/template version` · `Input dataset version` · `Eval score` · `Human sign-off`. The lock greps each with `grep -qiF` (case-insensitive, fixed-string); each must be a verbatim substring of the template. **Marker parity is the slice's key risk — both tasks use these exact strings.**

## File structure map

| File | Zone | Responsibility |
|---|---|---|
| `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` | GREEN | The 6-section lineage record adopters fill (one per artifact) |
| `conformance/artifact-lineage-ready.sh` | AMBER | Doc-coherence lock: template present + 6 markers; `--selftest` anchor+6 negatives |
| `conformance/verify.sh` | AMBER | Register 15th `check doc` |
| `.github/workflows/ci.yml` | AMBER | `- run: sh conformance/artifact-lineage-ready.sh --selftest` (basename ref) |
| `conformance/responsible-ai-readiness.md` | AMBER | Manual `(verified)` row 9 → the template |
| `CLAUDE.md` | AMBER | Add `AI-ARTIFACT-LINEAGE` to the templates index line |
| `docs/ROADMAP-KIT.md` | AMBER | Flip E11 to resolved |
| `VERSION`·`README.md`·`CHANGELOG.md` | AMBER | 3.91.0 → 3.92.0, folded into apply.py |

## Task 1 (GREEN, serial-first) — the lineage template

**Deliverable:** `templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md` committed directly (non-CP; the engineer may Write it in place). No `apply.py`.

**TDD.**
1. Write the failing test first — a throwaway assertion the engineer runs:
   `for m in "Artifact version" "Producing model" "Prompt/template version" "Input dataset version" "Eval score" "Human sign-off"; do grep -qiF "$m" templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md || echo "MISSING: $m"; done`
   Run it → every marker prints MISSING (file absent). Confirms the test bites.
2. Author the template (exact content):
   ```markdown
   # AI Artifact Lineage Record

   > One record per **produced AI artifact** (a generated dataset, a fine-tuned model, or a
   > shipped model output). Ties the artifact back to the model, prompt, inputs, and evaluation
   > that produced it, plus its governance links. Pair with the per-*system* `AI-SYSTEM-CARD.md`
   > and the `EVAL-PLAN.md` (which describes the tests).
   >
   > **Honest ceiling:** this record is an attestation. `conformance/artifact-lineage-ready.sh`
   > checks it is present and structurally complete — it cannot verify the values are accurate.
   > Accuracy is the signer's responsibility (§6).

   ## 1. Artifact
   - **Artifact ID / name:** <e.g. sentiment-classifier, support-summaries-2026-07>
   - **Artifact version / hash:** <semver or content hash — the immutable identifier>
   - **Type:** <dataset | fine-tuned model | generated output>
   - **Produced-at:** <YYYY-MM-DD>

   ## 2. Producing model
   - **Model ID + version:** <e.g. claude-opus-4-8>
   - **Provider:** <e.g. Anthropic>

   ## 3. Prompt / template
   - **Prompt/template version:** <id + version or hash of the prompt/template used>

   ## 4. Inputs
   - **Input dataset version(s):** <dataset id + version/hash of every input source>

   ## 5. Evaluation  *(the quality gate — links EVAL-PLAN + the pinned judge)*
   - **Eval-plan reference:** <path/link to EVAL-PLAN.md>
   - **Eval score:** <score(s) from the eval run, with the metric>
   - **Judge id:** <the judge/model that scored it, e.g. the pinned PINNED_JUDGE_MODEL>

   ## 6. Governance
   - **Linked AI System Card:** <path/link to AI-SYSTEM-CARD.md>
   - **Intended use:** <what this artifact is / isn't for>
   - **Known limitations:** <bias, coverage gaps, out-of-distribution caveats>
   - **Human sign-off:** <owner name + date — the accountable signer attesting the above is accurate>
   ```
3. Re-run the step-1 loop → zero MISSING. Test passes.
4. Commit (GREEN): `git add templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md && git commit -m "feat(e11): AI artifact lineage template"`.

**Honest ceiling (task):** proves the template asks for the 6 dimensions; not that any record is truthful.

## Task 2 (AMBER, serial after 1) — the doc-coherence lock

**Deliverable:** `conformance/artifact-lineage-ready.sh` authored under `scratchpad/e11/`, `--selftest` green, staged for `apply.py`. (Guard blocks Writing `conformance/` directly.)

**TDD** — mirror `conformance/gate-eval-secrets-ready.sh` structure exactly:
1. Write the `--selftest` first (anchor + 6 negatives), run against a not-yet-written check → fails.
2. Implement:
   - `DOC="${LINEAGE_DOC:-templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md}"`
   - `MARKERS` = the 6 pinned strings, **one per line.**
   - `check_doc()`: `[ -f "$d" ]` else FAIL; loop markers with `grep -qiF -- "$m" "$d"`, accumulate `miss=1` on absence.
   - `--selftest`: `build_fixture` writes a conformant template with **one marker per line**; `expect "conformant -> exit 0" 0`; then `for m in <6 markers>: fresh; grep -viF -- "$m" > tmp; mv; expect "missing '$m' -> exit 1" 1`.
   - Kit-self N/A: `if [ ! -f docs/ROADMAP-KIT.md ] && [ ! -f "$DOC" ]; then echo N/A; exit 0; fi`.
   - `case "${1:-}"` usage-guard (exit 2 on unknown arg), `set -eu`, dash-clean.
3. Run `sh scratchpad/e11/artifact-lineage-ready.sh --selftest` → `OK (anchor + 6 load-bearing negatives)`.
4. Run the main path against the real template: `LINEAGE_DOC=templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md sh scratchpad/e11/artifact-lineage-ready.sh` → OK.
5. `dash -n scratchpad/e11/artifact-lineage-ready.sh && shellcheck scratchpad/e11/artifact-lineage-ready.sh` → clean (the subagent-shell lint scar).

**Honest ceiling (task):** the lock proves the template is present + structurally complete; it cannot prove adopter values are accurate. State this in the script header verbatim.

## Task 3 (AMBER, serial after 2) — wiring, apply.py, version finishing

**Deliverable:** `scratchpad/e11/apply.py` (+ `gen.py`) that places the lock and all edits idempotently, clone-proven.

**Edits the apply.py performs:**
1. Write `conformance/artifact-lineage-ready.sh` (chmod 0755) from the base64 payload.
2. `conformance/verify.sh` — insert after line 111 (`check doc gate-eval-secrets …`):
   `check doc     artifact-lineage sh conformance/artifact-lineage-ready.sh`
3. `.github/workflows/ci.yml` — add a step (mirror the format of the existing `- run: sh conformance/<x>.sh --selftest` steps; place near the eval/AI selftests):
   `      - run: sh conformance/artifact-lineage-ready.sh --selftest`
4. `conformance/responsible-ai-readiness.md` — add row 9 to the checklist table (mirroring rows 5/6):
   `| 9 | Produced-artifact lineage recorded where the AI ships outputs/models/datasets (\`templates/AI-ARTIFACT-LINEAGE-TEMPLATE.md\`) *(verified)* | | | Manual |`
   (No change to `responsible-ai-ready.sh` — manual rows are not auto-checked.)
5. `CLAUDE.md` — append `AI-ARTIFACT-LINEAGE` to the `templates/` enumeration in the document-set table row.
6. `docs/ROADMAP-KIT.md` — under "Loosely scoped", change the E11 bullet to: `**E11 — AI-artifact lifecycle / audit:** ✅ RESOLVED v3.92.0 — one slice: produced-artifact lineage template + doc-coherence lock. (Distinct per-*output* altitude; not absorbed by E6.)`
7. Version finishing (folded in): `VERSION` → `3.92.0`; `README.md` badge → 3.92.0; `CHANGELOG.md` new entry.

**apply.py conventions (E6-d shape):** honors an explicit root arg with a loud print; sentinel-gated idempotent (re-run = no-op, exit 0); fail-closed anchors (abort loudly if an insert anchor is missing).

**Clone-prove (confabulation-proof):**
```
git clone . /tmp/e11-clone && cd /tmp/e11-clone
python3 scratchpad/e11/apply.py .        # cd-in then run; never pass the clone as arg to a CWD-only apply.py
sh conformance/artifact-lineage-ready.sh --selftest      # OK
sh conformance/artifact-lineage-ready.sh                 # OK (real template)
sh conformance/ci-selftest-coverage.sh                   # WIRED: artifact-lineage-ready.sh
sh conformance/verify.sh --require                       # 40 control · 15 doc · 0 failed
python3 scratchpad/e11/apply.py .        # 2nd run = idempotent no-op
```
Note the standing scar: **version-tag-coherent is legitimately RED between apply and commit** (HEAD still at v3.91.0 until the bump commits) — apply → commit → then verify coherence.

**Honest ceiling (task):** wiring proves the check runs in verify+CI and is discoverable; it does not change the lock's own ceiling.

## Parallelism

Strictly **serial**: T1 → T2 → T3 (T2's markers must match T1's headings; T3 packages both). No fan-out.

## Dual review (after build, before ship)

- **`reviewer`** (builder ≠ reviewer): marker parity, non-vacuity (does each negative truly bite?), idempotency, counts (40/15/55), no-claim correctness.
- **`security-reviewer`** (try to **defeat** the lock): can a vacuous/empty template pass? can a marker hide in an HTML comment and still satisfy `grep -qiF`? can the kit-self N/A be tricked into skipping inside the kit? is the responsible-AI row a real surfacing or dead text?

## Ship flow (owner runs — [[merge-tag-authority]])

`python3 scratchpad/e11/apply.py .` → `git add -A && git commit` → push → PR → `gh pr merge <#> --squash --admin --delete-branch` (solo control-plane RED on `control-plane-ratification` by design) → `git checkout main && git pull` → `sh scripts/release-tag.sh`.

## Self-review (plan ↔ spec)

- **Spec coverage:** template §3 → T1 · lock §4 → T2 · wiring/discoverability/registry §5 → T3 · honest ceiling §6 → stated per-task + script header · non-vacuity §7 → T2 selftest · CP-completeness §8 (N/A) → header · ship §9 → ship-flow. All spec sections map to a task. ✓
- **Placeholder scan:** template + lock + all 8 edits carry literal content/anchors. Only bounded deferral: exact ci.yml step placement (engineer mirrors existing selftest steps). ✓
- **Name/count consistency:** 6 markers pinned once, reused verbatim; 40 control / 15 doc / 55 total consistent with spec. ✓
