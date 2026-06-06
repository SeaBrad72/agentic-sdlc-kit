# Design — Slice 5c: ML Stack Profile (eval-gate-centric)

**Date:** 2026-06-06
**Status:** Approved (brainstorming) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** First of the two shape-different profiles. Followed by Slice 5c2 (data-engineering), Slice 5d (Terraform/IaC), then Slice 6.

---

## 1. Goal

Ship a first-class **ML** stack profile (`profiles/ml/`) covering the ML lifecycle — data/features → training → **evaluation** → optional serving. Its headline is a real **`gate-eval`** CI step that fails the build below an eval threshold, finally wiring the kit's long-standing "evals = the dev-time bar / AI analog of TDD" doctrine (`DEVELOPMENT-STANDARDS.md` §7) into an executable gate. It also exercises the 15-factor *conditional* mechanism for the canonical batch case (training pipeline).

## 2. Decisions (from brainstorming)

- **Two-profile split:** this slice = `profiles/ml/`; data-engineering is its own next slice (5c2).
- **Eval gate:** a dedicated `gate-eval` step (beyond the 8 standard gates) running an eval harness that supports **metric-thresholds** (curated dataset + rubric/exact-match, classic ML) **and** **LLM-as-judge** (pinned judge, genAI), failing the build below threshold.
- **Tooling defaults:** MLflow (tracking + model registry) · DVC (data/model versioning) · pandera (data validation) · nbstripout + jupytext + nbqa + nbmake (notebook hygiene/tests) · scikit-learn/PyTorch + Anthropic SDK · FastAPI/BentoML (optional serving).
- **Conditional §14/15-factor:** training pipeline = batch → port-binding/concurrency/stateless/disposability **N/A-with-reason**; serving path satisfies them. Backing-services (warehouse, registry, DVC remote) + telemetry apply.
- **Version:** **2.5.0** (MINOR, additive).

## 3. Deliverables

| Part | Files |
|------|-------|
| ML profile | `profiles/ml.md` (11 sections) |
| Companion | `profiles/ml/{ci.yml,CODEOWNERS,BRANCH-PROTECTION.md}` |
| Meta | `VERSION` → `2.5.0`; `CHANGELOG.md` 2.5.0; `docs/ROADMAP-KIT.md` note |

Profile name = `ml`; `--stack ml` and `profiles/ml/` align so `incept.sh --stack ml` wires CI. Validated by the existing `conformance/ci-gates.sh` (8 ids) + `conformance/profile-completeness.sh` (11 sections, no `[...]`) — no new conformance logic.

## 4. Detailed design

### 4.1 `profiles/ml.md` (11 sections, modern toolchain)

1. **Toolchain:** Python 3.12+ · uv · ruff · mypy · pytest + pytest-cov · MLflow · DVC · pandera · nbstripout/jupytext/nbqa/nbmake. Frameworks: scikit-learn / PyTorch; Anthropic SDK for LLM features.
2. **Scaffold:** `src/<pkg>/{data,features,models,training,eval,serving}/`, `evals/` (JSONL datasets + rubric + `run.py`), `notebooks/`, `conf/`, `dvc.yaml`, `tests/`, `.github/workflows/ci.yml`, `pyproject.toml`/`uv.lock`/`.env.example`/`ruff.toml`/`mypy.ini`.
3. **Standard commands:** install `uv sync --frozen`; lint `ruff check . && nbqa ruff notebooks/`; type `mypy .`; test `pytest --cov --cov-fail-under=80`; **eval `python -m evals.run --threshold 0.8`**; build `uv build`; data/pipeline `dvc repro`; track `mlflow`.
4. **CI/CD:** implements §14's 7 gates **+ the §7 eval gate**; points to `profiles/ml/ci.yml`. Note: `gate-eval` is the headline; `gate-test` includes pandera data-validation + nbmake notebook smoke.
5. **Security:** secrets via `pydantic-settings` + fail-fast; **never commit data/models** (DVC remote) or secrets; **PII** redaction in logs, right-to-erasure on training data; validation via Pydantic/pandera; **AI/agent security** (prompt-injection defense, output validation against schema, capability boundaries) for LLM features; model/artifact integrity (signed/attested).
6. **Testing:** unit + integration + **data validation (pandera)** + **notebook smoke (nbmake)** + **AI evals** — the eval suite is the dev-time bar (curated dataset + rubric; metric thresholds and/or LLM-as-judge with a pinned judge; safety/red-team adversarial set). Eval set is versioned with code, grows from production misses; eval-score decline is tracked as tech debt.
7. **Resilience & observability:** serving retry/backoff + circuit breaker (tenacity/pybreaker); structured logs (structlog); **experiment/model tracking (MLflow)**; **data & model drift monitoring**; eval scores tracked as a quality metric; Sentry.
8. **Data & models:** **DVC** for data/model/artifact versioning (remote storage; data never in git); reproducibility (pinned `uv.lock`, fixed seeds, recorded params via MLflow); dataset schema versioning (pandera schemas); model registry (MLflow Models) with stages.
9. **Release & deploy:** versioned model artifact in the MLflow registry; **build provenance attested on the model artifact**; staged/shadow/canary rollout for model changes (watch eval + live metrics); rollback = promote previous registered model version; serving via container (FastAPI/BentoML).
10. **Recommended libraries:** scikit-learn / PyTorch · MLflow · DVC · pandera · nbstripout + jupytext + nbqa + nbmake · pytest + pytest-cov · the eval harness (`evals/run.py`, pytest-driven; Anthropic SDK pinned judge) · FastAPI/BentoML · pydantic + pydantic-settings · structlog + Sentry · Anthropic SDK. Default Claude models: `claude-sonnet-4-6` (workhorse + as the pinned eval judge unless a project pins another), escalate to Opus for hard reasoning.
11. **Stack-specific gotchas:** never commit data/models/secrets — DVC remote + `.env`; install `nbstripout` as a pre-commit hook (strip notebook outputs — they leak secrets + bloat diffs); pin seeds **and** `uv.lock` for reproducibility; **pin the LLM judge model** (a moving judge invalidates eval comparisons); the eval set is code — version it, grow it from prod misses; evals gate like tests (`gate-eval` fails the build below threshold); **conditional §14** — a training pipeline is batch, so port-binding/concurrency/stateless/disposability are N/A-with-reason; the serving path (if present) must satisfy them.

### 4.2 `profiles/ml/ci.yml`

GitHub Actions, 8 standard `gate-*` ids **+ `gate-eval`**:
- `gate-install`=`uv sync --frozen`; `gate-lint`=`uv run ruff check . && uv run nbqa ruff notebooks/`; `gate-type-check`=`uv run mypy .`; `gate-test`=`uv run pytest --cov --cov-fail-under=80` (suite includes pandera + nbmake); `gate-build`=`uv build`; `gate-secret-scan`=gitleaks; `gate-dep-scan`=`uvx pip-audit`; `gate-sbom`=`uvx cyclonedx-py environment --output-format JSON --outfile sbom.json` (upload `sbom.json`); **`gate-eval`**=`uv run python -m evals.run --threshold 0.8` (the eval harness; non-zero exit below threshold) — placed before build/after test; `gate-provenance`=`actions/attest-build-provenance` on `dist/**` (and/or the registered model artifact), release/build path.
- `ci-gates.sh` requires the 8 standard ids; `gate-eval` is an allowed **extra** (verified — ci-gates checks presence, not absence of extras).

### 4.3 Companions
`profiles/ml/CODEOWNERS` + `BRANCH-PROTECTION.md` derived from the Python reference (stack-neutral; retitled "ml profile").

## 5. Validation / testing

- `sh conformance/ci-gates.sh profiles/ml/ci.yml` → exit 0 (8 ids present; gate-eval extra is fine).
- `sh conformance/profile-completeness.sh` → passes all 8 profiles (the 7 existing + ml).
- `profiles/ml/ci.yml` is valid YAML; SBOM upload path matches the tool output (`sbom.json`).
- **incept wiring:** `incept.sh --noninteractive --stack ml` into a temp copy wires CI + `inception-done.sh` passes; the wired `ci.yml` passes `ci-gates.sh`.
- Existing 7 profiles unchanged (additive). Kit CI green (conformance over 8 profiles, bootstrap, docs-links); check-links covers `ml.md`.

## 6. Risks & mitigations

- **`gate-eval` is the kit's first eval gate — must be real, not decorative.** Mitigation: the profile specifies a concrete harness contract (`python -m evals.run --threshold`, non-zero below threshold) and §6 describes the dataset/rubric/pinned-judge discipline; ci-gates verifies the id is present. (The harness *implementation* is the adopter's, scaffolded in `evals/` — the kit ships the contract + reference invocation, consistent with the reference-impl philosophy.)
- **SBOM/coverage accuracy** (the Slice-5/5b lesson): `gate-sbom` uses `cyclonedx-py environment` → `sbom.json` (matches upload); coverage enforced via `--cov-fail-under=80`. Verified against the Python profile (same tools).
- **Conditional §14 mis-applied** (someone treats training-batch port-binding as a failure). Mitigation: §11 + §4 explicitly mark which factors are N/A-with-reason and which the serving path must still meet.
- **Notebook-leaked secrets/outputs.** Mitigation: nbstripout pre-commit + gitleaks gate + the §11 gotcha.

## 7. Out of scope

Data-engineering profile (Slice 5c2) · Terraform/IaC (5d) · enterprise addendum (Slice 6) · executing the ML pipeline in kit CI (adopter-side; kit checks declaration + completeness).

## 8. Definition of Done

- `profiles/ml.md` (11 sections, no `[...]`) + `profiles/ml/{ci.yml,CODEOWNERS,BRANCH-PROTECTION.md}`; `ci.yml` passes `ci-gates.sh` (8 ids) and declares the extra `gate-eval`.
- `profile-completeness.sh` green over all 8 profiles.
- `incept.sh --stack ml` wires CI + passes `inception-done.sh` (verified in temp).
- Kit CI green; existing 7 profiles unchanged.
- `VERSION` = `2.5.0`; CHANGELOG 2.5.0; roadmap note.
- Feature branch → PR; **human-ratified before merge**.
