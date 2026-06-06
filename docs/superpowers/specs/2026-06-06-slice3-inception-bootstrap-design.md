# Design — Slice 3: Inception Bootstrap (incept.sh + templates + doc-slot refactor)

**Date:** 2026-06-06
**Status:** Approved (brainstorming) — pending spec review
**Author:** Bradley James + agent
**Roadmap:** `docs/ROADMAP-KIT.md` Slice 3. Follows Slice 2 (agent governance, v2.1.0). Absorbs the template work formerly scoped as Slice 4 (roadmap collapses 6→5).

---

## 1. Goal

Turn the kit's documented 8-step Inception gate into a **one-command bootstrap**: `scripts/incept.sh` transforms a freshly-cloned kit into a configured, Inception-complete project — stamping the project `CLAUDE.md`, `RUNBOOK.md`, `BACKLOG.md`, `ADR-000`, and wiring the chosen profile's CI. Deliver the correct templates it stamps, resolve the kit's latent root-`CLAUDE.md` collision, and prove the result with an executable Inception-Done conformance check. This is the "drop-in & go" promise made real.

## 2. Decisions (from brainstorming)

- **Absorb templates:** Slice 3 includes a new `RUNBOOK-TEMPLATE.md` and a rewrite of `BACKLOG-TEMPLATE.md` to the §6 flow-board model (the bootstrap must stamp *correct* artifacts). Slice 4 folds in.
- **Interaction:** interactive prompts by default; non-interactive via `--flags`/env (how CI + conformance drive it).
- **Adoption model:** **in-place**. `incept.sh` runs in the cloned kit repo. It `git mv CLAUDE.md ENGINEERING-PRINCIPLES.md` (freeing the root Claude-Code memory slot) and writes the **project** `CLAUDE.md` at root from the template. The kit repo itself adopts this rename and gains its own project `CLAUDE.md` (continues dogfooding).
- **Version:** **2.2.0** (MINOR) — additive bootstrap + templates; the rename relocates the principles doc but changes no contract or content, and there are no mid-flight adopters. Prominent CHANGELOG note about the rename.

## 3. Deliverables

| Part | Files |
|------|-------|
| **Reference: bootstrap** | `scripts/incept.sh` |
| **Reference: templates** | `templates/RUNBOOK-TEMPLATE.md` (new); `templates/BACKLOG-TEMPLATE.md` (rewrite → flow-board) |
| **Doc-slot refactor** | `git mv CLAUDE.md ENGINEERING-PRINCIPLES.md`; reference updates across the kit; new kit project `CLAUDE.md` |
| **Conformance** | `conformance/inception-done.sh`; CI step: bootstrap-into-temp → inception-done; index in `conformance/README.md` |
| **Meta** | `VERSION` → `2.2.0`; `CHANGELOG.md` 2.2.0 entry; `docs/ROADMAP-KIT.md` (Slice 3 done, 6→5) |

## 4. Detailed design

### 4.1 `scripts/incept.sh` (in-place bootstrap)

POSIX `sh`. Usage: `incept.sh` (interactive) or `incept.sh --noninteractive --name <n> --intent-owner <o> --stack <s> --backlog <md|github|linear|jira>`. Stack default `typescript-node`; backlog default `md`. Inputs also accepted via env (`INCEPT_NAME`, etc.).

Behavior:
1. **Safety guards (refuse + exit non-zero):**
   - If `ENGINEERING-PRINCIPLES.md` already exists OR the root `CLAUDE.md` does not look like the kit principles doc (missing its known heading) → "already incepted or not an un-incepted kit"; abort. Prevents double-runs and running against a real project.
2. Resolve inputs (prompt if interactive + missing; error if non-interactive + missing required).
3. `git mv CLAUDE.md ENGINEERING-PRINCIPLES.md` (fallback to `mv` if not a git repo).
4. Stamp **project `CLAUDE.md`** from `templates/PROJECT-CLAUDE-TEMPLATE.md`: project name, intent owner, stack, **Kit version adopted** (read `VERSION`), Created (from `date +%Y-%m-%d`), Status=Inception. Leave deeper config/charter prose as the template's guided placeholders.
5. Create `RUNBOOK.md` from `templates/RUNBOOK-TEMPLATE.md` (stamp project name).
6. Create `BACKLOG.md` from `templates/BACKLOG-TEMPLATE.md`.
7. Create `docs/architecture/ADR-000-stack.md` from `docs/ADR-000-EXAMPLE.md` (stamp stack + date).
8. Activate CI: `mkdir -p .github/workflows && cp profiles/<stack>/ci.yml .github/workflows/ci.yml` (TS profile today; if the profile has no `ci.yml`, print a note to add one). `.claude/` is already present.
9. Print **next steps it does NOT automate** (human judgment): write charter prose in `CLAUDE.md`; protect `main`; assign roles; declare per-project config; record the real ADR-000 decision — pointing to `START-HERE.md`.

Idempotency/safety: never overwrite an existing project file (if `RUNBOOK.md`/`BACKLOG.md` exist, skip with a warning). Operate only on the current directory.

### 4.2 `templates/RUNBOOK-TEMPLATE.md` (new)

Sections (per standards §11, enabling a cold resume): overview · local setup · environment variables (`.env.example` pointer) · run/test/build · deploy · **rollback** · RPO/RTO (defaults RPO<24h, RTO<4h) · test accounts/credentials location · monitoring/alerting · known issues / tech debt. Guided `[...]` placeholders; `[Project Name]` stamped by incept.

### 4.3 `templates/BACKLOG-TEMPLATE.md` (rewrite → §6 flow-board)

Replace the phase/date model (and the dangling `PROGRESS.md` reference) with the flow-board the process actually defines:
- **States:** `Backlog → Ready → In Progress → In Review → Released → Done` (+ `Blocked`).
- **Work-item fields:** title · intent (why) · acceptance criteria · size (one-flow small) · risk/complexity tag · owner (human/agent) · links (spec/PR/milestone).
- **Ordering:** value × urgency ÷ effort-risk; intent-owner ranks, lead breaks ties. No story points.
- **Work types share one board:** feature · bug · tech-debt · spike · recurring; tech-debt has a standing paydown allocation.
- A short "how to use" header + a couple of example rows in each state.

### 4.4 Doc-slot refactor (CLAUDE.md → ENGINEERING-PRINCIPLES.md)

`git mv CLAUDE.md ENGINEERING-PRINCIPLES.md`. Then update references, **disambiguating two senses of "CLAUDE.md":**
- **Principles doc** (→ `ENGINEERING-PRINCIPLES.md`): the "authoritative" / "principles + Definition of Done" references in `DEVELOPMENT-STANDARDS.md` §12, `DEVELOPMENT-PROCESS.md` (authoritative-on-overlap, gate owners), `README.md`, `START-HERE.md`, `MAINTAINING.md`, `WALKTHROUGH.md`, `.claude/agents/reviewer.md`, `profiles/typescript-node/BRANCH-PROTECTION.md`, and the "Inherited standards → Principles: CLAUDE.md" line in `templates/PROJECT-CLAUDE-TEMPLATE.md`.
- **Project file** (stays `CLAUDE.md`): the template's own "copy to a new project's `CLAUDE.md`" header; the **Kit version adopted** field; `MAINTAINING.md`'s "adopting projects record … in their `CLAUDE.md`"; `DEVELOPMENT-PROCESS.md` §15 artifact-flow row "Project `CLAUDE.md`"; `docs/ROADMAP-KIT.md` mentions of project scaffolding.

Each file is edited individually (per-reference judgment), followed by a grep sweep asserting no "principles/authoritative … `CLAUDE.md`" reference remains and that `ENGINEERING-PRINCIPLES.md` resolves everywhere it's now cited.

**Kit's own project `CLAUDE.md`** (new): created from `templates/PROJECT-CLAUDE-TEMPLATE.md`, identity = "this repo IS the Agentic SDLC Kit" (stack: docs/markdown + POSIX sh; intent owner: Bradley James; backlog: `docs/ROADMAP-KIT.md`). So the kit keeps a root `CLAUDE.md` (its own project memory) and dogfoods the post-rename layout. `ENGINEERING-PRINCIPLES.md` content is the former root `CLAUDE.md` verbatim (only its internal self-reference "this file"/title adjusted).

### 4.5 `conformance/inception-done.sh`

POSIX `sh`. Usage: `inception-done.sh [dir]` (default `.`). Asserts the 7-item Inception-Done gate materially in `dir`:
- `ENGINEERING-PRINCIPLES.md` present
- project `CLAUDE.md` present AND key fields filled (no leftover `[...]` in Project/Intent owner/stack lines)
- `RUNBOOK.md` present
- `BACKLOG.md` present (or declared non-md backend noted in `CLAUDE.md`)
- `docs/architecture/ADR-000*.md` present
- `.claude/` present
- `.github/workflows/ci.yml` present

Exits 0 if all hold; non-zero listing each gap. Indexed in `conformance/README.md`.

### 4.6 CI integration

Add a kit-CI job `bootstrap` (or step in `conformance`) that:
1. Copies the repo to a temp dir (so the kit repo is never transformed).
2. Runs `scripts/incept.sh --noninteractive --name DemoApp --intent-owner "CI" --stack typescript-node --backlog md` there.
3. Runs `conformance/inception-done.sh <tempdir>` → must pass.

This proves the bootstrap yields an Inception-complete project. (Runs on ubuntu; jq not required for this slice.)

## 5. Validation / testing

- **Bootstrap-into-temp:** copy kit → temp → `incept.sh --noninteractive …` → `inception-done.sh` exits 0; the temp project has project `CLAUDE.md` (filled), `ENGINEERING-PRINCIPLES.md`, `RUNBOOK.md`, `BACKLOG.md`, `ADR-000`, `.github/workflows/ci.yml`.
- **Safety:** running `incept.sh` again in the temp project refuses (already incepted).
- **Reference sweep:** no kit doc still calls the *principles* doc `CLAUDE.md`; every `ENGINEERING-PRINCIPLES.md` reference resolves.
- **Templates:** BACKLOG has the §6 states/fields and no `PROGRESS.md`/phase-model remnants; RUNBOOK has rollback + RPO/RTO.
- **Syntax:** `sh -n scripts/incept.sh conformance/inception-done.sh`.
- **Kit still green:** existing conformance (ci-gates, agent-autonomy, check-links, 15-factor) still pass after the rename (update any link the rename touched).
- **Guard non-interference:** `git mv`, `cp`, normal writes are allowed by the active `.claude` guard.

## 6. Risks & mitigations

- **Rename blast radius / broken links.** Mitigation: per-file edits + a grep sweep + `check-links.sh` (already in CI) catches any broken relative link to the renamed doc.
- **`incept.sh` run in the kit repo by mistake (transforming the kit).** Mitigation: safety guard (refuse if `ENGINEERING-PRINCIPLES.md` exists / not an un-incepted kit); CI always copies to temp first.
- **Two senses of CLAUDE.md mis-edited** (changing a project-file reference to the principles doc or vice-versa). Mitigation: §4.4 explicit disambiguation list; reviewer pass on the refactor.
- **check-links.sh excludes `docs/superpowers/`** — spec/plan references to old `CLAUDE.md` won't break the build, but should still read correctly (historical artifacts; left as-is).
- **Stack scaffolding scope creep.** Mitigation: bootstrap stays stack-neutral (wires the profile's CI only); source layout is the profile's/team's job.

## 7. Out of scope

Stack source scaffolding (profile §2, team-applied) · non-TS profiles (Slice 5) · enterprise addendum: compliance/secrets-at-scale/RBAC (Slice 6) · git-submodule/vendored-kit adoption model (we chose in-place).

## 8. Definition of Done (this slice)

- `scripts/incept.sh` bootstraps a temp copy to an Inception-complete project; `inception-done.sh` passes there; second run refuses.
- `RUNBOOK-TEMPLATE.md` added; `BACKLOG-TEMPLATE.md` rewritten to the §6 flow-board (no stale phase/PROGRESS model).
- `CLAUDE.md` → `ENGINEERING-PRINCIPLES.md`; all principles-doc references updated; reference sweep clean; kit has its own project `CLAUDE.md`.
- Kit CI runs the bootstrap-into-temp check green; all prior conformance still green.
- `VERSION` = `2.2.0`; CHANGELOG 2.2.0 entry (notes the rename); roadmap Slice 3 done + 6→5 collapse.
- Feature branch → PR; **human-ratified before merge** (renames/edits governing docs).
