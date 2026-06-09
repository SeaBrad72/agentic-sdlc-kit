# Slice 9b — Runtime Safety: Honest Reframe + Hardened Guard + Self-Protection (design)

**Date:** 2026-06-09 · **Arc:** Slice 9 (Honest Assurance & Adoption Reach) · **Version target:** MINOR → **v2.25.0**
**Inputs:** the 9-agent review ([2026-06-09-independent-multiagent-review.md](../reviews/2026-06-09-independent-multiagent-review.md)) and the A2 guard red-team ([2026-06-09-guard-redteam.md](../reviews/2026-06-09-guard-redteam.md)).
**Architecture decision (ratified):** Hybrid — reframe the guard as a best-effort speed bump, harden the deny-list, add an absolute self-protection core, and document the real boundary as Org-owned platform controls.

---

## Problem

The A2 red-team proved `.claude/hooks/guard.sh` is **~16% effective and self-disabling**: 183 adversarial payloads → 111 confirmed bypasses (88 P0), independently re-verified by the orchestrator (20/22 destructive payloads ALLOWED). Five systemic root causes:

1. **"Irreversible == recursive rm"** — single-file/glob `rm`, `truncate`, `find -delete`, `dd`, `shred`, redirect-truncation all pass.
2. **Zero exfiltration model** — 0/20; `scp`, `curl -T`, `nc`, `python3 -c requests.post` all pass; secrets are also *readable*.
3. **Trivial obfuscation** — `$X`, `r''m`, `base64 -d | sh`, `git -c … push` defeat literal matching.
4. **The guard does not protect itself** (the P0) — `rm guard.sh`, `> guard.sh`, `chmod 000`, `Write` over `guard.sh`/`settings.json` all ALLOWED → one command disables all gating.
5. **Cloud rules are vendor+verb enumerations** — `terraform destroy`, `aws ec2 terminate-instances`, etc. pivot past them.

The deeper truth: **a regex deny-list over free-form shell is not a security boundary** and cannot be made into one. So this slice makes the guard a *much better speed bump*, makes its self-protection *absolute*, and moves the *boundary* to documented platform controls — and corrects every doc that currently oversells the guard.

---

## Design — three layers + conformance + honesty

### Layer 1 — Harden the deny-list (`guard.sh`, Bash branch)

Add deny rules (each a new `grep -Eq … && emit_deny` block, matching the existing field-scoped, over-block-on-quoting style):

**1a. Non-rm destruction primitives**
- `truncate` (`-s 0`/any), `dd … of=` (to a file or `/dev/*`), `shred`, `mkfs.*`, `wipefs`, `blkdiscard`, `fallocate -d`.
- Redirect/empty truncation: `: > FILE`, `> FILE` fed from `/dev/null`, `cat /dev/null > FILE`, `cp /dev/null FILE`, `echo -n > FILE`, `tee FILE < /dev/null`-style — i.e. truncation of an existing non-trivial target.
- `find … -delete` and `find … -exec rm`/`-exec shred`.
- `rsync … --delete`, `git clean -f`(d/x), `git reflog expire … --expire=now` + `git gc --prune=now`, recursive `chmod`/`chown` (`-R`) on non-project/system paths.
- `mv … /dev/null`.

**1b. `rm` without a recursive flag — scalpel rule (do NOT deny all `rm`)**
- DENY `rm` when the target is: a **glob** (`*`, `?`, `[`), a **data/critical extension** (`.db .sqlite .sqlite3 .sql .dump .pgdump .bak .rdb .mdb`), an **absolute path** (`/…`) or a **dotfile of record** (`.env*`, `.git`).
- KEEP ALLOWING plain relative single files (`rm stale.txt`, `rm dist/bundle.js`) — preserve the existing `assert_allow "rm single file"` regression. This is the circumvention-avoidance boundary; over-blocking here is a failure.

**1c. Obfuscation — deny the technique, don't try to decode**
- `… | base64 -d | (sh|bash)` and any `base64 -d | <shell>` (generalize the existing `curl|wget | sh` rule to "anything decoded/fetched piped into a shell").
- `eval` with command substitution (`eval "$(…)"`, `` eval `…` ``).
- Command assembled via `${IFS}` or single-char var indirection used to reconstruct a blocked verb (best-effort: deny `$IFS` in a command position; deny `X=…;$X` patterns where the value reconstructs `rm`/`dd`/etc.).
- `git -c <opt> push …` (close the indirection that defeats the force-push / push-to-main anchors — broaden those two rules to tolerate `-c …` between `git` and `push`).

**1d. Exfiltration (partial, honestly labelled)**
- DENY `scp`, `sftp`, `rsync … <remote>:`, `nc`/`ncat` (data piped to a host), `curl … (-T|-F|--upload-file|--data-binary @)`, `wget --post-file`, `rclone copy/sync … <remote>:`, `… | mail`, DNS-exfil (`nslookup`/`dig` with `$(…)`).
- **Honest caveat in code + docs:** binary-name denial is *partial* — `python3 -c`, `node -e`, and arbitrary interpreters remain exfil channels. The real control is the Layer-3 egress allowlist. The guard rule is a speed bump, not a boundary. (Do NOT claim exfil is "covered.")

**1e. Cloud/infra — capability families, not single verbs**
- Generalize to verb-families across vendors: `terraform (destroy|apply)`, `aws … (delete-*|terminate-*|remove-*)`, `gcloud … delete`, `az … delete`, `kubectl (delete|drain|scale --replicas=0|rollout restart)`, `helm (delete|uninstall)`, non-listed DB clients invoking `drop*` (`mongosh --eval db.dropDatabase()`, `cockroach sql -e DROP`), `liquibase dropAll`, `flyway undo`.

### Layer 2 — Absolute self/control-plane protection (`guard.sh`, both branches)

**2a. Tier A — the guard's own integrity (absolute, default):**
- Across `Bash` (any mutation verb targeting these paths: `rm`, `mv`, `>`, `truncate`, `chmod`, `tee`, `cp`, `dd`, `sed -i`, `ln -sf`…) AND `Write`/`Edit`/`NotebookEdit` (`file_path` / `notebook_path`): DENY any modification of `.claude/hooks/guard.sh`, `.claude/settings.json`, `.claude/settings.local.json`.
- **Maintenance escape (human-only):** if `KIT_GUARD_SELFEDIT=1` is in the *hook process* environment, allow self-edits (so the kit and adopters can intentionally maintain the guard). An agent cannot set this — per-Bash-call env does not reach the hook process; it must be exported in the human's session. The conformance test asserts: **without** the escape, guard/settings edits DENY; the escape is documented as an audited, deliberate human action.

**2b. Tier B — control plane (denied for agents, pointer to human ratification):**
- `.git/` internals (`.git/config`, hooks, `objects`), `.github/workflows/`, `CODEOWNERS`, branch-protection config files. Silently rewriting a gate is an attack; legitimate changes are human-ratified governing-surface edits.
- Same `KIT_GUARD_SELFEDIT` escape applies (these are the files the kit itself edits during development).

**2c. Fix the `NotebookEdit` blind spot:** the Write|Edit branch must also read `notebook_path` (NotebookEdit does not send `file_path`), so notebook writes are subject to the same path checks.

**2d. Prod-context → default-deny posture:** keep the existing prod-context detection but, when a production context/namespace/env is detected, deny mutating operations by default rather than relying on the verb enumeration alone.

### Layer 3 — Document the real boundary (Org-owned)

New `docs/enterprise/platform-safety-boundary.md`:
- **Network-egress allowlist** — the only real exfil defense; deny-by-default egress, allow known registries/APIs.
- **Separate production credentials** — agents/dev never hold prod write creds; prod access is broker/approval-gated.
- **Read-only / sandboxed filesystem** — agent workspaces can't reach host data or other projects.
- **Scoped, short-lived tokens** — least-privilege, time-boxed.
- Map each into `docs/enterprise/compliance-crosswalk.md` (Org-owned rows) and reference from the guard README.

### Honesty — correct the oversell (required, not optional)

- **`guard.sh` header:** add a caveat — "Best-effort speed bump for honest mistakes, NOT a security boundary. A determined agent can bypass a shell deny-list; the boundary is platform-owned (see docs/enterprise/platform-safety-boundary.md). This guard reduces accidental blast radius; it does not contain a hostile process."
- **`.claude/README.md`** and any guard description: replace "strong/strongest control" framing with the speed-bump framing + the boundary pointer.
- **The two review artifacts** already state this; align the kit's own shipped docs to match.

### Conformance — prove and lock it (`agent-autonomy.sh`)

- Add `assert_deny` cases for every Layer-1 family and a representative subset of the **111 red-team bypasses** as the regression corpus (grouped with comments by class).
- Add `assert_allow` cases that protect against over-blocking: `rm stale.txt`, `rm dist/bundle.js`, `truncate` *not present* in a normal `npm test`, a doc that merely mentions `scp`, a benign `curl https://api … ` GET, `chmod +x script.sh`.
- Add a **self-protection block:** `assert_deny` Write/Edit/Bash-mutation of `guard.sh`/`settings.json`/`.github/workflows/ci.yml`/`CODEOWNERS`; (optionally) assert the `KIT_GUARD_SELFEDIT=1` escape path allows them.
- This check already runs in CI (`conformance` job) — no `ci.yml` change required, which conveniently sidesteps the dogfooding tension for *this* slice.

---

## Files

| File | Change |
|------|--------|
| `.claude/hooks/guard.sh` | Layers 1+2: new deny families, scalpel-rm rule, obfuscation/exfil/cloud-family rules, absolute self/control-plane protection w/ `KIT_GUARD_SELFEDIT` escape, NotebookEdit `notebook_path`, prod default-deny; honest caveat header |
| `conformance/agent-autonomy.sh` | New deny corpus (from the 111 bypasses) + over-block allow-guards + self-protection block |
| `docs/enterprise/platform-safety-boundary.md` | **New** — Org-owned real boundary (egress allowlist, prod creds, sandbox FS, scoped tokens) |
| `docs/enterprise/compliance-crosswalk.md` | Add Org-owned rows for the platform boundary controls |
| `.claude/README.md` | Reframe guard as speed bump + boundary pointer |
| `docs/enterprise/README.md` | Note the platform-safety-boundary doc |
| `DEVELOPMENT-PROCESS.md` §13 | One line: the guard is a speed bump; the boundary is platform-owned |
| `CHANGELOG.md`, `VERSION` | 2.25.0 entry |
| `docs/ROADMAP-SLICE9.md` | Mark 9b done; note design-level outcome |

## Known implications (state, don't hide)

- **Dogfooding cost:** once shipped, an agent editing the kit's own `guard.sh`/`settings.json`/CI is denied unless a human exports `KIT_GUARD_SELFEDIT=1`. This is correct shipped behavior; for kit maintenance it means guard/CI changes are explicitly human-gated (which they already are via ratification). Future slices that edit `ci.yml` will need the escape or a human edit.
- **Partial exfil by design:** interpreters remain exfil channels; the guard says so and points to the egress allowlist. We do not claim closure.
- **Still a deny-list:** a longer, self-protecting deny-list is still enumerated. The honesty framing is load-bearing — the conformance corpus prevents silent regression but not novel bypasses.

## Out of scope (later slices / Org)
- Building the egress allowlist / sandbox itself (Org-owned platform work).
- A non-Claude runtime guard reference (Slice 9d).
- Allow-list/default-deny inversion of all Bash (considered and not chosen this slice).

## Verification
- `sh conformance/agent-autonomy.sh` green (new denies + preserved allows).
- Re-run the orchestrator's `/tmp/guard_verify.py`-style battery: the 20 previously-ALLOWED payloads now DENY (controls still behave).
- `sh conformance/check-links.sh` green (new doc links resolve).
- Full sweep: all `--selftest` batteries, profile `ci-gates`, links — green.
- Governance: feature branch → PR → **human ratification** (Bradley); Security-Owner lens (this is the guard itself).
