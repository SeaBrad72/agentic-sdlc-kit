# Slice 11b — Egress-allowlist reference + conformance (the honest W2)

**Status:** design approved (brainstorm), pre-plan.
**Arc:** Containment & the Platform Boundary (`docs/ROADMAP-SLICE11.md`). Follows 11a (MCP capability gate, W3). Aimed by [A8 §2.4](../reviews/2026-06-10-A8-mcp-egress-attack-surface.md).
**Version target:** v2.41.0 — **MINOR** (conditional three-state check + reference docs; no new universal required gate).

---

## Problem (what W2 is, and what it is not)

Residual **W2** = the kit has no control over interpreter / DNS / build-tool data exfiltration. [A8 Part 2](../reviews/2026-06-10-A8-mcp-egress-attack-surface.md) enumerated the tail (`python -c` sockets, `node -e`, `ruby -e`, `deno run`, DNS-label exfil, `postinstall`/`make`/`npm run` out-of-band, encode-then-allowed-channel) and proved, per case, that **no reliable command signature exists** — any in-process deny-list either strangles the agent (banning `python -c` bans scripting) or is trivially bypassed (write a temp `.py`).

The honest conclusion, already recorded in [`platform-safety-boundary.md`](../../enterprise/platform-safety-boundary.md) control #1: the **only real exfiltration defense is a default-deny network-egress allowlist** at the platform. It neutralizes the entire §2.2 tail uniformly — an un-allowlisted destination simply does not connect, regardless of whether the socket came from `curl`, `python -c`, `/dev/tcp`, or a DNS lookup.

So 11b is **not** an in-process egress guard (that would be the false assurance the arc exists to kill). It is: **ship the platform-control reference, and make its presence + wiring verifiable** — three-state, UNVERIFIED-honest, never a false PASS.

## Goals

1. Ship a copy-pasteable **default-deny network-egress reference** (k8s concrete + cloud/proxy patterns).
2. Add **`conformance/egress-policy.sh`** — conditional three-state: the platform egress control is *declared and attested-wired*, or honestly UNVERIFIED, or FAIL on a networked project that declares nothing, or N/A with reason.
3. Move the compliance-crosswalk egress row **Org-owned → Kit-assisted** (reference shipped + wiring verified), never Kit-enforced.
4. Preserve the honesty invariant: no green check implies the kit inspects or blocks traffic.

## Non-goals

- **No in-process egress enforcement / traffic inspection.** The script verifies the platform control is declared+attested; it never claims to see packets.
- **No per-profile manifests.** Egress is deploy-target-specific, not language-specific — one canonical reference, not 10.
- Sandbox / scoped-credential / separate-prod-credential controls → **11c**.
- Crosswalk responsibility-tier moves for sandbox/tokens, and the full honesty restatement → **11d**.

---

## Components

### 1. `docs/operations/egress-control.md` (new reference)
Pairs with `egress-policy.sh` exactly as `resilience-verification.md` pairs with `resilience-ready.sh`. Contains:
- **The principle** — default-deny outbound; allow only DNS + package registries + your required APIs.
- **k8s paved road (concrete):** a default-deny-egress `NetworkPolicy` (deny all egress via `policyTypes: [Egress]` with no/empty allow, then an explicit allow policy for DNS/registries/APIs). Copy-pasteable.
- **Non-k8s patterns (documented):** cloud egress firewall (AWS security-group egress rules / GCP egress firewall / Azure NSG) and a forward-proxy allowlist pattern.
- **How to attest** in the RUNBOOK (the exact line `egress-policy.sh` keys on) and what counts as "wired."
- **The ceiling note:** the reference only neutralizes the §2.2 exfil tail **if actually applied at the platform**; a repo with the YAML but no CNI/firewall that honors it is UNVERIFIED, by design.

### 2. `conformance/egress-policy.sh` (new check + `--selftest`)
Conditional, fail-closed, three-state. Reuses `resilience-ready.sh`'s deploy-surface detection verbatim (`Dockerfile` / a deploy workflow / a GitHub `environment:` key).

**Network-surface trigger:** no deploy/network surface → **N/A skip-pass**. Also **N/A** if the RUNBOOK explicitly records `Network egress: N/A — <reason>`.

**Definitions:**
- **declared** = *either* an in-repo egress manifest (a file containing `kind: NetworkPolicy` with `Egress` in `policyTypes`) *or* a RUNBOOK egress section that **names the mechanism** (NetworkPolicy / cloud egress firewall / forward proxy).
- **attested-wired** = the RUNBOOK egress line records enforcement — a real date or `enforced`, **not** the `[date]`/`[mechanism]` template placeholder (same placeholder-rejection `resilience-ready.sh` performs).

**States:**

| State | Condition | Exit |
|-------|-----------|------|
| **PASS** | declared **and** attested-wired | 0 |
| **UNVERIFIED** | declared but **not** attested (placeholder / missing enforcement record) | 2 (escalates to FAIL under CI / `--require`) |
| **FAIL** | networked surface, **not declared at all** | 1 |
| **N/A** | no network surface, or RUNBOOK `Network egress: N/A — <reason>` | 0 |

**Rationale for generalized "declared":** a committed `NetworkPolicy.yaml` proves *intent*, not *enforcement* (it can sit unapplied — no CNI honoring it, wrong namespace, never `kubectl apply`'d). The authoritative "wired" signal is therefore the operator attestation (as in `resilience-ready.sh` / `dr-ready.sh`), and many correct setups enforce egress at the cloud/proxy layer with **no in-repo file** (often in a separate infra repo). Requiring an in-repo manifest would red-flag those correct setups into permanent UNVERIFIED — a false negative that gets the check waived and ignored. The in-repo k8s `NetworkPolicy` stays the recommended paved road and the strongest evidence; it is simply not the *sole* road to green. PASS still requires *both* declared and attested.

### 3. `conformance/egress-readiness.md` (new checklist)
Mirrors `resilience-readiness.md`: **Auto** rows (what the script proves — declared + attested) vs **Manual** rows (what it cannot — *traffic is actually blocked*; operator/platform evidence). A green run is necessary, not sufficient.

### 4. `templates/RUNBOOK-TEMPLATE.md` (attestation line)
A dated egress attestation in the deploy/security area, same shape as §8's `Load/soak tested: [date]`. The record strings stay in sync with `egress-policy.sh` (single source of the keyed phrase), e.g.:
```
Network egress: default-deny via <mechanism: k8s NetworkPolicy | cloud egress firewall | forward proxy> — enforced: [date]
```
(or `Network egress: N/A — <reason>` for a project with no outbound network).

### 5. Enterprise / audit wiring
- Compliance crosswalk + `conformance/audit-evidence-checklist.md`: egress row **Org-owned → Kit-assisted** (reference shipped + wiring verified), with `egress-policy.sh` as the evidence pointer.
- `platform-safety-boundary.md`: a note that egress is now reference-shipped + verify-wired — enforcement remains platform-owned (control #1 unchanged).

### 6. Meta / CI
- `.github/workflows/ci.yml` (control-plane → human `cp`): add an `egress-policy.sh --selftest` step (self-test only; the kit root has no deploy surface, so a live run is N/A).
- `conformance/README.md`: index row.
- `VERSION` → `2.41.0`; `CHANGELOG.md`; `docs/ROADMAP-SLICE11.md` 11b → ✅ shipped.

---

## Honesty boundary (load-bearing)

- The script **never inspects traffic.** PASS = "default-deny egress is declared and the operator attested enforcement," explicitly **not** "the kit verified packets are dropped." Live-blocking is a **Manual** row, never Auto.
- **UNVERIFIED is a first-class non-pass** (exit 2), escalating to FAIL under CI / `--require` (as `branch-protection.sh` does) so a dashboard can't hide it.
- Crosswalk: **Kit-assisted**, never Kit-enforced. `platform-safety-boundary.md` keeps enforcement platform-owned; 11b only narrows the open gap by making the control verifiable.

## Testing

`--selftest` fixture battery (wired into kit CI like `resilience-ready.sh --selftest`):

| Fixture | Expected |
|---------|----------|
| No deploy/network surface | N/A (skip-pass) |
| RUNBOOK `Network egress: N/A — <reason>` | N/A |
| Networked, nothing declared | FAIL |
| Manifest present, RUNBOOK enforcement = `[date]` placeholder | UNVERIFIED |
| RUNBOOK names mechanism, no enforcement date | UNVERIFIED |
| In-repo `NetworkPolicy` (Egress) + dated RUNBOOK attestation | PASS |
| No manifest + RUNBOOK names mechanism + dated attestation | PASS (cloud/proxy path) |

Plus: `dash -n` clean; `check-links.sh` resolves the new doc links; bootstrap-into-temp still green; full conformance suite + `verify.sh` green.

## Governance

Feature branch → PR → **human ratification** (Bradley merges; agent never self-merges). The `ci.yml` change goes via the control-plane `cp` (`KIT_GUARD_SELFEDIT=1`). Security-owner lens on the honesty framing before the PR. Kit stays generic/anonymized ([[kit-anonymization]]).

## Out of scope / deferred
- In-process egress enforcement (impossible-by-construction per A8 Part 2; not attempted).
- 11c — sandbox / read-only FS / scoped + short-lived tokens / separate prod credentials.
- 11d — honesty & assurance restatement (crosswalk tier moves once 11b/c land).
- A9 — red-team re-test (arc exit gate).
