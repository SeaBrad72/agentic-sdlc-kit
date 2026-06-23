# E4a — Containment-audit: prove the reference sandbox actually contains

**Status:** Design approved 2026-06-22 (owner-ratified). First build slice of the E4 epic.
**Tracked here** (not `docs/superpowers/specs/`) per the C7 lesson — the superpowers spec path is kit-gitignored, so `git add` silently no-ops there; design docs that must be committed live in `docs/architecture/`.

---

## 0. Context

E4 is the **containment** epic of the E-series strategic arc — the safety floor under E3's
parallel, file-mutating doer-agents. The E3 orchestration design (`docs/architecture/2026-06-22-e3-agentic-orchestration-design.md`)
§10 is E4's starting requirements: the containment that E3's fan-out *assumes* must become
**proven**, not attestation.

**The gap-assessment thesis (the whole reason E4 exists):** the four platform containment
controls — egress · sandboxed FS · scoped tokens · prod-cred SoD — are **attestation-only**
today. `conformance/containment-ready.sh` greps a RUNBOOK line (`<aspect>: … enforced: <date>`)
and `egress-policy.sh` does the same for egress; the presence of a `read_only: true` compose
config bumps an aspect FAIL→UNVERIFIED but **never to PASS, and never boots anything**. The kit
verifies the posture is *declared*, not that a packet drops or a mount is read-only.

**The honest boundary (owner-ratified, "prove-what-we-ship; honest rest"):** the kit can only
behaviourally prove controls whose **enforcement artifact it actually ships**. It ships the
sandbox container (`profiles/typescript-node/compose.yaml` `agent` service + the devcontainer);
it does **not** own the adopter's cloud IAM. So:

- **FS-scope, egress, caps** — provable by booting the shipped `agent` sandbox and probing it. **← E4a (this slice).**
- **Scoped tokens (§10 #3), prod-cred SoD (§10 #4)** — not container-bootable (cloud-IAM owned).
  Get a stronger *static* check, honestly labelled attestation. **← E4a′ (separate slice).**
- **Conflict-safe parallel writes (§10 #6)** — an E3b integration mechanic, **not** E4.

---

## 1. Scope of E4a

**In:** boot the reference `agent` sandbox in CI and **prove** the three controls the kit's own
artifact enforces, each negative probe paired with a positive control:

1. **FS-scope** — write outside `/work` fails (read-only root); write inside `/work` and to `/tmp`
   (tmpfs) succeeds. Host secret paths (`~/.aws`, `~/.ssh`, `/var/run/docker.sock`) are absent
   (only the work tree is mounted).
2. **Egress** — an outbound network connect fails (`network_mode: none`).
3. **Caps** — a CAP-gated operation fails (`cap_drop: [ALL]` + `no-new-privileges`).

**Out (named, not built here):**
- E4a′ — scoped-tokens / prod-cred-SoD honest static check (assert the shipped `ci.yml` uses OIDC
  `id-token` per-job, no long-lived cloud secrets; labelled static-not-behavioural).
- E4b — image-vuln gate (CVE scan on the built image).
- E4c — DAST / runtime-security reference.
- E4d — cost-ceiling / runaway kill-switch reference (§10 #5).
- E4e — R2 bot-identity ratification gate (author ≠ approver).
- E4f — G8 per-segment guard refactor (guard at fleet scale, §10 #7).

Each is its own brainstorm → spec → plan → build. **Only E4a is built now.**

**Profile scope:** typescript-node only, mirroring `golden-path` (the maintainer-verified
reference). Six other profiles ship a `compose.yaml`; those are reference configs — the audit
pattern transfers but is proven on the reference, not fanned across all stacks (resists the
E-series scope-creep meta-flag).

---

## 2. The enforcement artifact (what we boot)

`profiles/typescript-node/compose.yaml`, the `agent` service — the containment reference:

```yaml
agent:
  build: { context: ., target: builder }   # node + a shell (runtime stage is distroless)
  profiles: [agent]                         # opt-in; excluded from `docker compose up`
  read_only: true                           # root filesystem read-only
  network_mode: none                        # no egress
  cap_drop: [ALL]
  security_opt: [ no-new-privileges:true ]
  tmpfs: [ /tmp ]                            # the only writable path besides the mount
  volumes: [ ./:/work:rw ]                  # ONLY the work tree — nothing from $HOME/host
  working_dir: /work
  environment: { HOME: /tmp, npm_config_cache: /tmp/.npm }
  command: ["bash"]
```

Invoked as: `docker compose --profile agent run --rm agent <probe>`. A plain `docker compose up`
ignores it (the `agent` profile gates it) — the verified app path is untouched.

---

## 3. Components (4 artifacts)

### 3.1 `scripts/containment-audit.sh` (new, control-plane)
The probe runner — the behavioural proof. Given a project dir containing an `agent` compose
service + a Dockerfile:

1. `docker compose --profile agent build agent`
2. Run the probe matrix (§4) via `docker compose --profile agent run --rm agent`.
3. Exit **0 only if every probe holds** (fail-closed). Any positive-control failure (container not
   alive) fails as hard as any negative-probe breach (boundary broken).

- **Adopter-runnable** against their own compose — a genuine capability, like `dr-drill.sh` /
  `smoke.sh`. (This is why it's a first-class script, not inline workflow YAML — the gap-assessment
  literally names `containment-audit.sh`.)
- **Made control-plane:** added to `is_control_plane_path()` in `.claude/hooks/guard-core.sh` so an
  agent cannot silently weaken the security gate.
- **CI fail-closed:** under `CI`/`--require`, docker-or-compose-absent is **FAIL, not skip** — no
  fail-open in the gate. The skip-with-reason path exists only for adopter local runs without docker.

### 3.2 `containment-audit` job in `.github/workflows/golden-path.yml`
Reuses the docker-capable, path-filtered, ts-node end-to-end workflow (cohesive with the existing
`golden-path` + `generator-golden-path` jobs).

- Incept a temp ts-node project → **stage `compose.yaml` + `Dockerfile`** into it (incept copies
  neither — established by G2 for the Dockerfile) → run `scripts/containment-audit.sh <project>`
  → assert green.
- Path filter extended to include `compose.yaml`, the audit script, and the workflow.
- **Alternative considered:** a dedicated `containment-audit.yml`. Rejected — reuse the incept+build
  setup rather than duplicate it; noted as a future split if the workflow grows.

### 3.3 `conformance/containment-audit-wired.sh` (new, control-plane)
Kit-self regression lock — runs in the docker-less `verify.sh` aggregate (static, like
`golden-path-wired.sh`). Asserts:

- `scripts/containment-audit.sh` exists and parses as `sh`.
- The `golden-path.yml` `containment-audit` job exists and invokes the audit script.
- **The probe matrix has each control's negative probe AND its paired positive control** — the
  anti-vacuous-pass guarantee, locked structurally so the audit can never silently regress to
  negative-only.
- (Optional) the script is referenced in `is_control_plane_path`.
- `--selftest` with fixtures: a neg-only audit script FAILS the lock; a complete one passes; a
  missing job fails.
- Claim `containment-audit` registered → claims **25 → 26**; id added to `REQUIRED_IDS` in
  `claims-registry.sh`.

### 3.4 `docs/operations/containment.md` tie-in (agent-editable)
Point to `scripts/containment-audit.sh` as the runnable behavioural backing and the kit-self proof
that the shipped reference config actually contains. **`containment-ready.sh` logic is untouched** —
the portable adopter attestation state-machine stays, and the honest boundary stays clean: the kit
proves *its artifact* behaviourally; the adopter *attests their deployment*.

---

## 4. The probe matrix

Exact commands belong in the plan; this is the contract. Each negative probe distinguishes
*blocked-by-boundary* (right errno) from *harness-broken* (e.g. command-not-found), and is paired
with a positive control so a dead container cannot vacuously pass.

| Control | Negative probe (MUST fail, right errno) | Positive control (MUST succeed) |
|---|---|---|
| **FS-scope** | write to `/etc/<probe>`, `/<probe>` → EROFS (read-only root) | write to `/work/<probe>` and `/tmp/<probe>` → succeed |
| **Host-unreachable** | `~/.aws`, `~/.ssh`, `/var/run/docker.sock` absent | `/work` holds the staged project (mount live) |
| **Egress** | outbound connect → ENETUNREACH, via `node` (guaranteed in the builder stage — not a maybe-missing `curl`) | (FS positives prove the container is alive; no positive network control exists under `network_mode: none`) |
| **Caps** | a CAP-gated op (`mknod` needs CAP_MKNOD, or `chown` to another uid needs CAP_CHOWN) → EPERM | a non-privileged op succeeds |

**Anti-vacuous-pass discipline (the headline hardening invariant):** in a `read_only` +
`network_mode: none` container almost every command fails, so "expect the forbidden op to fail" is
trivially satisfied by a broken harness. The audit FAILS if any positive control fails, AND
requires negatives to fail with the *expected* errno — not a generic non-zero. This is the same
defect class security-review caught on R1 (line-grep passing over unparseable YAML): structure that
*looks* right vs behaviour that *actually* holds. The wired-lock (§3.3) enforces the pairing
structurally so it cannot regress.

---

## 5. Proof model (mirrors G2 exactly)

- **Live behavioural proof:** the `containment-audit` job GREEN on the PR **and** on the main push
  (real GHA, real docker boot+probe) — the same bar `golden-path` met, proven 3× in G2.
- **Static regression proof:** `containment-audit-wired.sh --selftest` — CI-aggregate-safe, no
  docker, runs in `verify.sh --require` every slice.

---

## 6. Cross-cutting (pre-empted traps)

### 6.1 adopter-export carve (the banked E2 lesson)
`containment-audit-wired.sh` reads the **export-ignored** `golden-path.yml`, so per the E2 lesson it
**must be carved from the adopter export — both loops in `scripts/adopter-export.sh`** (the strip and
the selftest assert), mirroring `golden-path-wired.sh` / `drift-watch` / `adopter-export`. Otherwise
the adopter's `claims-registry.sh` fails on a missing maintainer-only file. CI's
`adopter-export-wired` catches a miss, but **only at the committed HEAD** (`git archive HEAD`) — the
local pre-commit verify is blind to it (the "validated against the wrong tree state" trap that cost a
CI round on #154). The `containment-audit.sh` **script itself does ship** to adopters (it's a
capability); only the kit-self wired-lock is carved.

### 6.2 Control-plane footprint → AMBER mechanic
Control-plane (built in flat `/tmp` scratch, landed by human-run `apply.py`, **security-review-of-
scratch MANDATORY** — most security-sensitive epic; it has caught a real defect on every
control-plane slice this arc):
- `scripts/containment-audit.sh` (new) + adding it to `is_control_plane_path` in `guard-core.sh`.
- `conformance/containment-audit-wired.sh` (new) + `claims.tsv` row + `REQUIRED_IDS` in `claims-registry.sh`.
- `.github/workflows/golden-path.yml` new job + path filter.
- `scripts/adopter-export.sh` carve (both loops).

Agent-editable (authored on-branch): `docs/operations/containment.md`, `VERSION`, `CHANGELOG.md`,
README version badge, `docs/ROADMAP-KIT.md` (E4a ✅ + the E4 decomposition), this design doc.

**Flat-scratch build note (S2 lesson):** flat names like `/tmp/e4a_scratch/containment-audit.sh` do
NOT match the guard's `*/scripts/...` / `*/conformance/*` patterns, so build subagents can Write
there; `apply.py` lands them at their real (now-protected) paths.

### 6.3 apply.py invariants (banked lessons)
REQUIRES an explicit ROOT arg (bare run errors), idempotent, atomic, fail-loud anchors, and
**`os.chmod(tmp, os.stat(dst).st_mode)`** to preserve dest mode on overwrite (the S1/S2/S3 mode-drop
bug). New executable scripts land `755`.

---

## 7. Verification / Definition of Done

- `containment-audit` job GREEN on the PR and on the main push (live docker proof).
- `containment-audit-wired.sh --selftest` green; claim registered; `claims-registry.sh` green (26).
- `verify.sh --require` green; `sparkwright doctor` Overall PASS.
- adopter-export carve verified (exported tree's `claims-registry.sh` passes — no orphaned
  maintainer-only claim).
- builder ≠ reviewer + security-review-of-scratch both APPROVE (nits folded in scratch).
- Merge landed verified (main HEAD + tag + PR state = MERGED) before claiming done.
- VERSION bumped, CHANGELOG + README badge + ROADMAP updated.

---

## 8. The full E4 decomposition (for sizing; only E4a built now)

| Slice | Control(s) | What it adds |
|---|---|---|
| **E4a** (this) | §10 #1 FS-scope, #2 egress, caps | Boot the sandbox, prove it contains. PROVEN. |
| E4a′ | §10 #3 tokens, #4 prod-SoD | Honest static check (OIDC per-job, no long-lived secrets). |
| E4b | §10 #7 | Image-vuln CVE-scan gate on the built image. |
| E4c | §10 #7 | DAST / runtime-security reference. |
| E4d | §10 #5 | Cost-ceiling / runaway kill-switch reference (composes E2 flags). |
| E4e | (R2 deferred) | Bot-identity ratification gate — author ≠ approver. |
| E4f | §10 #7 (G8 deferred) | Per-segment guard refactor — guard at fleet scale. |

E3 (orchestration) builds **after** E4. Build order: E2 ✓ → E4 → E3 → E1/E5/E6.
