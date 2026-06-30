# Meta-control panel #28 — orchestrator-loop-wired.sh data-driven refactor

**Date:** 2026-06-29 · **Version:** 3.76.0 → 3.77.0 (on ship) · **Trigger:** per-slice (A5) — roadmap #3, Refactoring lens #1 · **Profile:** light (5-lens) · **Steward:** kit-steward (read-mostly; proposes, human ratifies)

## Verdict: **GO**

0 blockers · 0 highs · 1 inherited Low (CI marker-coverage, accurately disclosed) · 2 follow-ups to route. A clean behaviour-preserving refactor of a control-plane verifier, proven equivalent old-vs-applied across an 81-fixture matrix and independently re-verified by this panel. Both dual reviews (correctness APPROVE, security PASS-WITH-NOTES) are accurate. No global drift, no over-claim, right-weight bar met.

---

## What I independently re-verified (not just trusted the reviews)

| Claim | Re-check | Result |
|---|---|---|
| 1064 → 333 lines | `wc -l` old vs `new.sh` | **1064 / 333** confirmed |
| Differential old-vs-**applied** = ALL MATCH (the corrected check from correctness Low #1) | ran `cloneproof.sh`: clone → apply.py → `DIFF_NEW=conformance/... diff-harness.sh` | **ALL MATCH (81/81)** against the real applied tree |
| Harness is non-vacuous | mutation: neutered the marker `grep` in `new.sh` (`grep…→ true`) → ran harness | **DIVERGENCE: 56/81** — the harness genuinely detects weakened teeth |
| Shipped selftest 32 PASS / 0 FAIL | `--selftest` on `new.sh`, counted PASS lines | **32 PASS**, `OK:` exit 0 |
| shellcheck clean | `shellcheck new.sh` | exit 0, no findings |
| apply.py integrity is real | Python-decoded `new.b64`, sha256 vs `EXPECTED_SHA` and vs `new.sh` | **MATCH** (`5f7cd901…`); whole-file replace, all-or-abort, idempotent |
| Clone proof end-to-end | `cloneproof.sh`: apply → selftest `OK` → main-path `OK` on real tree → 2nd apply = no-op → exactly 4 tracked files change (`conformance/…`, VERSION, README, CHANGELOG) | **all green**; VERSION → 3.77.0 |
| 3 backed claims unchanged | grep `claims-registry.sh` `REQUIRED_IDS` | `orchestrator-loop`, `conflict-safe-integration`, `skill-spine` all present; **no new/removed claim** |
| No new gate/guard | `check_*()` count old vs new; guard-token scan | 14 → 5 (10 uniform collapsed to 1 generic + 4 bespoke kept); the 7 "guard/gate" tokens are `<HARD-GATE>`/`runaway-guard` *markers it asserts*, not new infrastructure |

> One false alarm worth recording for future stewards: macOS `base64 -d new.b64` silently emitted empty output (sha of empty string `e3b0c442…`), which *looks* like a payload mismatch. Decoding via Python (apply.py's actual path) gives the correct byte-identical match. The apply.py integrity gate is sound; the discrepancy was a host-tool artifact, not a real defect.

---

## The 5 lenses

### Lens 1 — Scope-coherence & proportion → **PASS**
This is a textbook right-weight refactor, not over-build. The roadmap (`docs/ROADMAP-KIT.md:72`) measured the actual pain (super-linear ~128 lines/brick from triple redundancy: 10 near-identical functions × the quadratic 27-case fixture term). The fix collapses to one `spine_table()` + one generic `check_spine_skill` + a table-driven selftest, and **adds zero new infrastructure** (no gate, no claim, no guard matcher). Doing it *now*, before more bricks compound it, is the correct timing per `defer-build-ahead`'s inverse — the surface is already crowded, not empty. The 4 structurally-distinct checks (`check_roster`, `check_loop`, `check_gp`, `check_keystone`) are correctly kept bespoke rather than force-fit into the table — `check_keystone` in particular stays filesystem-enumerated (the protection the v3.65.0 hardening earned), `new.sh:161-182`. No ceremony.

### Lens 2 — Honesty & over-claim → **PASS**
The honest ceiling is stated plainly and in the right places, not implied by green:
- The shipped file itself discloses the split (`new.sh:262-264`): "One representative marker-drop per skill… EXHAUSTIVE per-marker teeth are the build-time differential harness's job… not CI's."
- The CHANGELOG block (`apply.py:28`) says exactly what is proven by what: "proven by a build-time differential characterization harness… and the shipped 32-case selftest (ongoing non-vacuity teeth)," and names the message-generalization honestly ("Reference FAIL messages are preserved verbatim via per-row labels; diagnostic text for the file-absent and one operating-marker branches is generalized — exit codes identical, paths still named").
- Design §8 names what is **not** proven: that the marker lists are the "right" distinctiveness bar (unchanged from today, out of scope). Correct — this is a refactor, not a re-spec.

No headline/README/badge claim moves except the version bump. No over-claim.

### Lens 3 — Enforcement integrity (green-while-dark hunt) → **PASS**
This is the lens that matters most for a control-plane verifier refactor, and it holds:
- **The teeth are the same teeth.** The differential harness proves old≡new on exit codes across 81 fixtures (every marker-drop, every seat-reference omission, keystone structural breaks, roster/loop/golden-path negatives), and I proved the harness is **non-vacuous** by mutation (neuter the marker grep → 56/81 DIVERGENCE). A co-refactored selftest cannot fool it because the oracle is `git show HEAD:` (the pre-refactor file), independent of the rewritten test.
- **No green-while-dark introduced.** `grep -qF --` is now used uniformly (safer for `-`-leading markers like `--no-renames`); `set -f` guards the intentional word-splits (`new.sh:142`); `IFS` is saved/restored. The `eval`-free indirection uses `skill_path()`/`def_path()` `case` lookups on table-internal names only — no external-input eval surface (security PASS confirmed, I concur).
- The applied main-path passes against the **real** kit tree (not just fixtures) — the verifier still bites on the actual `agents/`, `skills/`, `scripts/`.

### Lens 4 — Direction & sequencing → **PASS (no divergence)**
This is exactly roadmap priority #3 (`ROADMAP-KIT.md:17`), and #3 is still the right next thing: it is the *only* real refactoring candidate, it worsens with every future brick, and it is behaviour-preserving + selftest-guarded (low risk) — correctly sequenced *before* T4 (#4) and the guard-touching Promotion-Contract enforcement slices (#5). The deliberate scope discipline holds: the `fresh`/`native` weak-marker cleanup is **not** smuggled in (plan global-constraint: "strictly behaviour-preserving… the marker cleanup is a SEPARATE follow-up slice"). No plan accretion. Nothing to resequence.

### Lens 5 — Right-weighting & adoptability → **PASS**
Net adopter-facing complexity **decreases**: a control-plane verifier they may read or extend goes 1064 → 333 lines, and the env-override contract (`ORCH_LOOP_*`) is unchanged so adopter overrides and `--selftest` keep working. The kit-self N/A guard (`new.sh:299-302`) still spares non-kit adopters entirely. Progressive disclosure intact; rigor did not outrun fit — this *reduces* rigor's surface area while preserving its teeth.

---

## Adversarial verify pass (material findings)

| Finding (source) | Status | Independent re-check |
|---|---|---|
| Correctness Low #1 — in-clone differential was OLD-vs-OLD baseline (now fixed to OLD-vs-applied) | **confirmed-resolved** | `cloneproof.sh:21` runs `DIFF_NEW=conformance/orchestrator-loop-wired.sh` against the *applied* file → ALL MATCH (81/81). The OLD-vs-OLD path only survives as the harness's own self-sanity default (`diff-harness.sh:20`), which is correct (it proves the oracle agrees with itself). Real run targets the applied verifier. |
| Correctness Low #2 — message-wording changes disclosed in CHANGELOG | **confirmed** | `apply.py:28` names the two generalized branches; exit codes identical (differential proves it). Non-material. |
| Security Low — CI runs only 32-case selftest (10 of 56 markers probed); exhaustive per-marker is build-time-only | **confirmed, correctly classed as INHERITED not regression** | Counted: 56 spine markers across the 10 rows; the original probed one marker per skill too. The shipped selftest matches the original's coverage exactly — this property is *inherited*, disclosed in `new.sh:262-264` + CHANGELOG. Not a teeth-weakening. Their suggestion (promote high-value markers to shipped cases) is a legitimate future improvement → routed below. |

No finding was refuted; none rises above Low; nothing material left unverified.

---

## Ledger 1 — verified-as-quality (ship with confidence)

1. **Behaviour-preservation is exhaustively and independently proven** — 81-fixture old-vs-applied differential = ALL MATCH, harness mutation-proven non-vacuous (56/81 divergence when teeth removed).
2. **apply.py is a trustworthy AMBER applier** — SHA256-gated whole-file replace, all-or-abort, idempotent (2nd run = clean no-op), exactly 4 files change, version finishing folded in per the `release-finishing-in-apply.py` standing fix.
3. **No global drift** — 3 backed claims unchanged, no new gate/claim/guard, env-override contract preserved, kit-self N/A guard intact.
4. **Honest ceiling stated in the load-bearing places** — the shipped file and the CHANGELOG both name the build-time-harness vs shipped-selftest split; no green-implies-equivalence over-claim.
5. **Right-weight win** — −731 lines on a control-plane verifier, future bricks ~1 row, zero new infrastructure.

## Ledger 2 — fix-forward (ranked; all post-ship, none blocking)

| # | Severity | Item | Route |
|---|---|---|---|
| F1 | Low | Promote a few high-value markers (e.g. `red-team`, `<HARD-GATE>`) from build-time-only to shipped selftest cases, narrowing the CI/build coverage gap | Banked follow-on (pairs with the marker-cleanup slice) |
| F2 | Low | `fresh` + `native` weak/brittle marker cleanup (owner-approved as the immediate next slice) | Already owner-approved; add as the next refactoring-lens slice |
| F3 | Housekeeping | The `cloneproof.sh` / `diff-harness.sh` artifacts are scratchpad-only (gitignored) — ensure they are not expected to ship | No action; correctly build-time |

---

## Retro — what the last N slices taught, and where it routes

This slice is the **first refactoring-lens slice** after a long brick-laying run (skill-spine #1–#10, then E5/E5-ops). The lesson it banks:

- **The differential-characterization-harness pattern is now a proven kit technique** for any "rewrite the net and the thing it protects at once" change: oracle = `git show HEAD:`, fixture matrix = every break the verifier should catch, equivalence on exit codes, and a **mutation test of the harness itself** to prove non-vacuity. This is reusable for #2 (`guard-core.sh is_control_plane_path`) if/when it is ever refactored — and it materially de-risks that high-risk file. **Route:** worth a one-line note in the refactoring lens of `ROADMAP-KIT.md` (or a `MAINTAINING.md` technique reference) so the next refactor reaches for it by default rather than re-inventing.
- **Super-linear growth is a measurable refactor trigger.** The roadmap caught this by *measuring* lines/brick, not by feel — the kit's continuous-right-weighting discipline working as intended. No process change needed; this confirms the existing discipline.

No artifact contradicts the plan; nothing to silently re-plan.

---

## Guardrail / standards proposals (for human ratification — I propose, I do not ratify)

**None required.** This slice touches no guardrail, weakens no gate, and adds no standard. The only routed items are the two backlog follow-ups (F1, F2) and the optional technique-note (retro). I propose **no** change to any control-plane guard, conformance check, or standards doc.

---

## Governance close (human-authored per M2-S5)

On ship, the human appends to `docs/governance/meta-control-log.md` and sets `docs/governance/.meta-control-last`:

- **Marker (`.meta-control-last`):** `3.77.0 GO`
- **Log row:**
  `| 2026-06-29 | 3.77.0 | orchestrator-loop refactor per-slice M verdict (A5) | light (5-lens) | GO | docs/architecture/2026-06-29-meta-control-28.md | 0 blockers · 0 highs · 1 inherited Low (CI probes 10/56 markers — matches original, build-time harness carries exhaustive teeth; disclosed in file+CHANGELOG) · 2 follow-ups routed (F1 promote high-value markers; F2 fresh/native cleanup = next slice). 1064→333 lines, no new gate/claim/guard. Behaviour-preservation independently re-verified: clone→apply→differential OLD-vs-APPLIED ALL MATCH (81/81); harness mutation-proven non-vacuous (neuter marker-grep → 56/81 DIVERGENCE); selftest 32/0; shellcheck clean; apply.py SHA-gated + idempotent, exactly 4 files. 3 backed claims (orchestrator-loop / conflict-safe-integration / skill-spine) unchanged. Dual-reviewed (correctness APPROVE + security PASS-WITH-NOTES, both accurate). RETRO: differential-characterization-harness now a proven kit refactor technique → de-risks the guard-core.sh #2 candidate. |`
