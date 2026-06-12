# Security Scanning — SAST & License Compliance

Two **conditional** gates (the a11y/load/eval family — first-class but trigger-bound,
N/A-with-reason). They sit alongside the universal `gate-secret-scan` and `gate-dep-scan`:
secret-scan finds committed secrets, dep-scan finds *known-vulnerable dependencies*, and
these two add **first-party code analysis** and **license policy**.

## SAST — `gate-sast` (trigger: first-party application code)

Static analysis of *your own* code for injection, auth-bypass, SSRF, unsafe deserialization,
and similar patterns — the class `gate-dep-scan` (deps) and `gate-secret-scan` (secrets) miss.

- **Reference tool: Semgrep** (multi-language, OSS) — `semgrep --config auto --error`. Portable default.
- **Alternative: CodeQL** (GitHub-native code scanning) where the repo is on GitHub Advanced Security.
- **N/A-with-reason** for a repo with no first-party application code (pure IaC modules, docs).
- **Honesty:** a green `gate-sast` proves the scan ran with no findings above the configured
  severity — not that the code is secure. Tune rulesets per project; triage findings, don't suppress.

## License compliance — `gate-license` (trigger: an SBOM is produced)

The kit already emits a CycloneDX SBOM (`gate-sbom`). `gate-license` **acts on it**:
`scripts/license-check.sh --sbom <sbom.json>` flags denylisted strong-copyleft licenses
(default: `AGPL`, `GPL`, `SSPL`, `OSL`, `EUPL`, `CC-BY-NC` — the anchor deliberately excludes
weak-copyleft `LGPL`) and **counts undetermined / NOASSERTION components**, which it surfaces
for review rather than silently passing. Override the policy with `--policy <file>` (a newline
list of anchored SPDX patterns); make undetermined a hard failure with `--strict`.

### Stack-neutral by default — and its blind spot

The SBOM-based check is uniform across all stacks and reuses output you already produce, but the
SBOM can emit `NOASSERTION` / incomplete license fields. The check **tells you** when it hits
this (`N component(s) have undetermined licenses … see per-stack upgrade`). It is
**necessary, not sufficient** — it clears declared licenses against policy; it is not a legal
clearance.

### Per-stack upgrade ladder (higher fidelity — contract-preserving)

When you need stronger license detection, replace the default implementation with your stack's
native tool **but keep the same `gate-license` id and the same policy intent**, so conformance
still passes (the kit's "rewrite the reference, keep the contract" rule):

| Stack | Higher-fidelity native tool |
|-------|------------------------------|
| typescript-node | `license-checker` / `license-compliance` |
| python · ml · data-engineering | `pip-licenses` |
| go | `go-licenses` |
| rust | **`cargo-deny`** (license + advisory + ban in one) |
| java-spring · kotlin | `license-maven-plugin` / `gradle-license-report` |
| dotnet | `nuget-license` |
| terraform | mostly N/A (providers, not libraries) |

### When to upgrade (concrete triggers)
1. The default repeatedly reports undetermined-license components.
2. A strict / audited legal license-compliance obligation.
3. Shipping a proprietary product with copyleft exposure.
4. You need build-graph scoping (allow a dev-only copyleft tool, deny it at runtime).
