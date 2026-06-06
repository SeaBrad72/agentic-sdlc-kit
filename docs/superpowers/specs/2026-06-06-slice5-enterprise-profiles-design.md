# Design — Slice 5: Enterprise Profiles (Python + Java/Spring) + profile-completeness

**Date:** 2026-06-06
**Status:** Approved (brainstorming) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** `docs/ROADMAP-KIT.md` Slice 5. Follows Slice 3 (bootstrap, v2.2.0).

---

## 1. Goal

Broaden the kit beyond TypeScript so a **Python** or **Java/Spring** enterprise team can adopt with a real, conformant profile. Each profile fills all 11 `_TEMPLATE.md` sections and ships a companion directory (`ci.yml`, `CODEOWNERS`, `BRANCH-PROTECTION.md`) mirroring the proven `typescript-node` profile — so `incept.sh --stack python|java-spring` wires a §14-conformant pipeline. Add a `profile-completeness` conformance check that guards every profile (including the existing TS one).

## 2. Decisions (from brainstorming)

- **Scope:** both **Python** and **Java/Spring** in this slice.
- **Toolchains (modern opinionated defaults):**
  - **Python:** `uv` (deps/build) · `ruff` (lint/format) · `mypy` (type-check) · `pytest` + coverage · `gitleaks` (secrets) · `pip-audit` (dep-scan) · CycloneDX-py (SBOM) · `actions/attest-build-provenance`. Reference web/ORM: **FastAPI + SQLAlchemy/Alembic**.
  - **Java/Spring:** **Maven** · Spring Boot · Spotless + Checkstyle (lint/format) · `mvn compile` (type-check) · JUnit 5 + JaCoCo (test+coverage) · `mvn package` (build) · `gitleaks` · OWASP dependency-check (dep-scan) · CycloneDX-maven (SBOM) · attest. Migrations: **Flyway**.
- **Version:** **2.3.0** (MINOR) — additive profiles + a new conformance check; no contract change.

## 3. Deliverables

| Part | Files |
|------|-------|
| **Python profile** | `profiles/python.md` (11 sections); `profiles/python/{ci.yml,CODEOWNERS,BRANCH-PROTECTION.md}` |
| **Java profile** | `profiles/java-spring.md` (11 sections); `profiles/java-spring/{ci.yml,CODEOWNERS,BRANCH-PROTECTION.md}` |
| **Conformance** | `conformance/profile-completeness.sh`; index in `conformance/README.md`; CI step in the `conformance` job |
| **Meta** | `VERSION` → `2.3.0`; `CHANGELOG.md` 2.3.0; `docs/ROADMAP-KIT.md` Slice 5 done |

## 4. Detailed design

### 4.1 Profile structure (mirror `typescript-node`)

Each `profiles/<stack>.md` fills the 11 `_TEMPLATE.md` sections: 1 Toolchain · 2 Project scaffold · 3 Standard commands · 4 CI/CD pipeline (points to the companion `ci.yml`, lists the 7 §14 gates) · 5 Security implementation · 6 Testing · 7 Resilience & observability · 8 Data & migrations · 9 Release & deploy · 10 Recommended libraries · 11 Stack-specific gotchas. Status: `reference`. Each companion `ci.yml` uses the 8 standardized `gate-*` step ids so `conformance/ci-gates.sh` validates it.

### 4.2 Python — `profiles/python.md` + `profiles/python/`

- **Toolchain:** Python 3.12+; `uv` (deps + lockfile `uv.lock`, build); `ruff` (lint+format), `mypy --strict` (types); `pytest` + `pytest-cov` (coverage ≥80, gate fails under). Build: `uv build` (wheel/sdist).
- **`ci.yml` gate map:** `gate-lint`=`ruff check .`; `gate-type-check`=`mypy .`; `gate-test`=`pytest --cov --cov-fail-under=80`; `gate-build`=`uv build`; `gate-secret-scan`=gitleaks; `gate-dep-scan`=`pip-audit`; `gate-sbom`=`cyclonedx-py environment -o sbom.json` (CycloneDX); `gate-provenance`=`actions/attest-build-provenance` on `dist/**` (push-to-main path). Setup via `astral-sh/setup-uv` + `actions/setup-python`.
- **Security (§5):** secrets via `os.environ` + `pydantic-settings` fail-fast; validation via **Pydantic** at boundaries; injection-safe via **SQLAlchemy** (parameterized); auth via `passlib[bcrypt]` + `pyjwt`; HTTP headers via FastAPI middleware / `secure`.
- **Resilience/observability:** `tenacity` (retry/backoff), `pybreaker` (circuit breaker), `structlog` (JSON logs), Sentry SDK.
- **Data/migrations:** SQLAlchemy + **Alembic** (expand-contract, reversible).
- **Recommended libs:** Pydantic, FastAPI, SQLAlchemy, Alembic, pytest, ruff, mypy, tenacity, structlog, Anthropic SDK for AI features.
- **Gotchas:** pin via `uv.lock`; `ruff` replaces flake8/isort/black; mypy strictness; venv isolation.

### 4.3 Java/Spring — `profiles/java-spring.md` + `profiles/java-spring/`

- **Toolchain:** JDK 21 (LTS); Maven (wrapper `./mvnw`); Spring Boot 3.x; Spotless + Checkstyle; JUnit 5 + JaCoCo (coverage ≥80 via JaCoCo check rule); build `mvn package`.
- **`ci.yml` gate map:** `gate-lint`=`./mvnw -q spotless:check checkstyle:check`; `gate-type-check`=`./mvnw -q compile` (compilation = type-checking); `gate-test`=`./mvnw -q test` (JaCoCo enforces ≥80); `gate-build`=`./mvnw -q -DskipTests package`; `gate-secret-scan`=gitleaks; `gate-dep-scan`=`./mvnw -q org.owasp:dependency-check-maven:check` (fail on CVSS≥7); `gate-sbom`=`./mvnw -q org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom`; `gate-provenance`=attest on `target/*.jar` (push-to-main). Setup via `actions/setup-java` (temurin 21, cache maven).
- **Security (§5):** secrets via Spring `@Value`/`Environment` + fail-fast; validation via **Bean Validation (Jakarta `@Valid`)**; injection-safe via **Spring Data JPA**/parameterized; auth via **Spring Security** (BCrypt + JWT); HTTP headers via Spring Security defaults.
- **Resilience/observability:** **Resilience4j** (retry, circuit breaker); SLF4J + Logback JSON; Micrometer + Spring Boot Actuator (metrics/health/traces); Sentry.
- **Data/migrations:** JPA/Hibernate + **Flyway** (versioned, reversible).
- **Recommended libs:** Spring Boot starters (web, security, data-jpa, actuator, validation), Resilience4j, Flyway, JUnit5, JaCoCo, Testcontainers, CycloneDX/OWASP plugins.
- **Gotchas:** `./mvnw` for reproducible builds; JaCoCo check binds to `verify`; dependency-check first-run downloads the NVD DB (cache it); Spring profiles for env config.

### 4.4 `conformance/profile-completeness.sh`

POSIX `sh`. For each `profiles/*.md` except `_TEMPLATE.md`:
- assert all 11 section headings `## 1.` … `## 11.` are present;
- assert no leftover `[...]` placeholder (the `_TEMPLATE` fill marker) remains;
- if a companion `profiles/<stack>/ci.yml` exists, assert it passes `conformance/ci-gates.sh`.
Exits 0 if all profiles pass; non-zero listing each gap. Runs against **all** profiles, so it also regression-guards `typescript-node.md`.

### 4.5 CI + index

Add a step to the `conformance` job: `sh conformance/profile-completeness.sh`. Index `profile-completeness.sh` in `conformance/README.md` and drop `profile-completeness` from the "future" note.

## 5. Validation / testing

- `profile-completeness.sh` passes for `typescript-node.md`, `python.md`, `java-spring.md` (11 sections each, no `[...]`).
- `ci-gates.sh profiles/python/ci.yml` and `ci-gates.sh profiles/java-spring/ci.yml` both pass (all 8 gate ids present).
- Each new `ci.yml` is valid YAML.
- **incept wiring:** `incept.sh --noninteractive --stack python` (and `java-spring`) into a temp copy wires `.github/workflows/ci.yml` from the new profile and `inception-done.sh` passes — proving the profiles plug into the bootstrap.
- Kit's existing conformance (ci-gates on TS, agent-autonomy, check-links, 15-factor, inception-done) still green; `check-links.sh` covers the new profile docs.
- `sh -n conformance/profile-completeness.sh`.

## 6. Risks & mitigations

- **`[...]` false positives:** a profile might legitimately use square brackets. Mitigation: match only the literal `[...]` ellipsis token (the template marker), not all brackets; verify TS profile passes.
- **Java `gate-type-check` = compile ambiguity:** documented in the profile (compilation is type-checking); `gate-build` is `package`. Distinct ids, both present.
- **Toolchain drift / unrunnable in CI:** the kit CI does NOT execute the Python/Java pipelines (no Python/JVM project exists here) — it only checks the workflows *declare* the gates (ci-gates) and the profiles are complete. Real execution happens in an adopting project. This keeps kit CI fast and stack-free.
- **incept `--stack` value vs dir name:** profiles use `python` / `java-spring`; incept copies `profiles/<stack>/ci.yml`. Names must match exactly — verified in §5.

## 7. Out of scope

Other stacks (Go, Rust, .NET — generate from `_TEMPLATE.md` as needed) · executing the Python/Java pipelines in kit CI (adopter-side) · the enterprise addendum: compliance/secrets-at-scale/RBAC (Slice 6).

## 8. Definition of Done (this slice)

- `profiles/python.md` + `profiles/python/{ci.yml,CODEOWNERS,BRANCH-PROTECTION.md}` and `profiles/java-spring.md` + `profiles/java-spring/{…}` present; all 11 sections filled; companion `ci.yml`s pass `ci-gates.sh`.
- `conformance/profile-completeness.sh` passes for all three profiles; indexed; in CI.
- `incept.sh --stack python` and `--stack java-spring` wire CI and pass `inception-done.sh` (verified in temp).
- Kit CI green (conformance incl. profile-completeness, bootstrap, docs-links).
- `VERSION` = `2.3.0`; CHANGELOG 2.3.0; roadmap Slice 5 done.
- Feature branch → PR; **human-ratified before merge**.
