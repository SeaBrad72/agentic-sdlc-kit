# Version-Control Host Adapter Guide

The kit's git workflow is **host-neutral**. GitHub and GitLab are worked examples; **any host works if it maps the contract below.** This mirrors `docs/work-tracking/adapters.md` (trackers) for the version-control-host axis — the kit owns the *contract*, you bring the *host*.

## The contract every host must satisfy

The kit needs six things from your git host. The **names** differ per host; the **mechanics** don't:

1. **Protected default branch** — no direct pushes to `main`/`master`; changes land through a merge unit.
2. **Change-proposal unit** — a PR (GitHub) / MR (GitLab) / equivalent that carries the diff, its CI run, and its review in one place.
3. **Non-author review** — at least one approval from someone *other than the author* (builder ≠ sole reviewer; the §13 separation-of-duties control in `DEVELOPMENT-STANDARDS.md`).
4. **Required status checks** — the CI **gate-IDs** (`conformance/ci-gates.sh` defines the contract; `docs/operations/ci-platforms.md` explains it) must pass before merge. The contract is the *IDs*, not a specific YAML.
5. **Solo-override + team-mode paths** — a sanctioned, *logged* way for a solo maintainer to merge when no second reviewer exists, and its team-mode counterpart (branch-admin enforcement). See `docs/operations/review-lane.md`.
6. **Release tagging** — annotated tags for versioned releases (`scripts/release-tag.sh` / `release-tag.gitlab-ci.yml`).

If your host provides these — under whatever names — the kit runs unchanged.

## GitHub *(worked)*

- **Protect** `main`: Settings → Branches (require PR, require review, require status checks). `enforce_admins` on paid/org repos; it **404s on free-tier private** repos — see `review-lane.md`.
- **Proposal:** Pull Request. **Review:** required reviewers / `CODEOWNERS`. **Checks:** the `.github/workflows/ci.yml` gate-IDs.
- **Solo override:** `gh pr merge --admin` (control-plane-ratification goes red-by-design for a solo maintainer; `--admin` is the sanctioned, logged bypass). **Tag:** `scripts/release-tag.sh`.

## GitLab *(worked)*

- **Protect** branches + **MR approval rules**: Settings → Repository → Protected branches; Settings → Merge requests → Approvals. See `docs/operations/gitlab-adoption.md`.
- **Proposal:** Merge Request. **Checks:** the `.gitlab-ci.yml` gate-IDs. **Tag:** `release-tag.gitlab-ci.yml`.

## Bring your own host *(Bitbucket, Gitea, self-managed, Gerrit, …)*

Any host works if you map the six contract points:

1. Find its **protected-branch** setting; forbid direct pushes to your default branch.
2. Identify its **change-proposal unit** (Bitbucket PR, Gitea PR, Gerrit change) — that's where diff + CI + review live.
3. Require **≥1 non-author approval**. If the host can't *enforce* it, record it as a waived control with a compensating process (`templates/WAIVER-REGISTER.md`) — don't silently drop the SoD point.
4. Wire the **CI gate-IDs** as required status checks on that unit (the CI contract is host-agnostic — `ci-platforms.md`).
5. Document the host's **solo-override** and **team-mode** equivalents (the honest counterparts of `--admin` / `enforce_admins`) in your project `RUNBOOK.md`.
6. Point release tagging at the host's tag/release API — or tag locally and push.

**Honest ceiling:** the kit provides the *contract* and this *recipe*; actually enforcing branch protection and non-author review is your **host's** configuration. `conformance/branch-protection.sh` verifies it where the host exposes an API (three-state: PASS / UNVERIFIED / FAIL), and marks it UNVERIFIED where it cannot reach the host — a green kit run is *necessary, not sufficient* for host enforcement.
