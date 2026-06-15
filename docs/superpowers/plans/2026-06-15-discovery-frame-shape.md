# Discovery Layer (FRAME + SHAPE) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the opt-in discovery front-end (FRAME + SHAPE) — new docs + templates + one structural conformance check — that turns a raw signal into a *Ready* backlog the existing Sparkwright engine consumes, without changing the existing process.

**Architecture:** All new files under `docs/discovery/` + `templates/`, surfaced via `ONBOARDING.md`/`README.md`/`GLOSSARY.md`. Stages 3–6 are *documented* as the existing engine, not built. A `conformance/discovery-complete.sh` (mirrors `onboarding-complete.sh`) proves the layer is present + wired.

**Tech Stack:** POSIX sh (conformance), Markdown (docs/templates). No runtime deps.

**Branch:** `feature/discovery-frame-shape`. **PREREQUISITE: PR #90 (2.60.0 naming) must be merged and this branch rebased onto the updated `main` BEFORE Task 1** — so the layer builds on the Sparkwright name + a clean 2.60→2.61 chain (avoids the CHANGELOG/VERSION/verify.sh collision the onboarding slice hit).

**Doc-budget rule:** the core-3 (`CLAUDE.md`, `DEVELOPMENT-PROCESS.md`, `DEVELOPMENT-STANDARDS.md`) must stay **900/900** — **none of these tasks touch them.** Confirm with `doc-budget.sh` in Task 6.

**Spec:** `docs/superpowers/specs/2026-06-15-discovery-frame-shape-design.md`

---

## File map
- Create: `conformance/discovery-complete.sh`
- Create: `docs/discovery/discovery-loop.md`, `docs/discovery/frame.md`, `docs/discovery/shape.md`
- Create: `templates/OPPORTUNITY-BRIEF-TEMPLATE.md`, `templates/SHAPING-DOC-TEMPLATE.md`
- Modify: `ONBOARDING.md` (discovery door), `README.md` (milestone line + What's-inside row), `GLOSSARY.md` (entries)
- Modify: `conformance/verify.sh` + `conformance/README.md` (register control)
- Modify: `VERSION`, `README.md` badge, `CHANGELOG.md` (2.61.0)
- Control-plane hand-apply (folded into branch, pre-PR): one `ci.yml` step running `discovery-complete.sh`

---

### Task 1: `conformance/discovery-complete.sh` (the slice's failing test)

**Files:** Create `conformance/discovery-complete.sh`

- [ ] **Step 1: Write the check** (exact content):

```sh
#!/bin/sh
# discovery-complete.sh — completeness drift-guard for the OPT-IN discovery layer (FRAME + SHAPE).
# Asserts the layer is present + wired: (a) discovery-loop.md names all six loop stages; (b) the
# frame.md + shape.md stage guides exist; (c) the two upstream templates exist; (d) ONBOARDING.md
# links the discovery door. Completeness only — green means present + wired, NOT that any actual
# discovery was good (discovery is judgment work; the guard + gates remain the safety net).
#   sh conformance/discovery-complete.sh [--selftest]
# Exit: 0 = complete · 1 = a gap · 2 = bad usage. POSIX sh; dash-clean.
set -eu

STAGES="FRAME SHAPE PLAN BUILD SHIP OBSERVE"

# check_tree <root>: print PASS/FAIL per requirement; return 1 if any gap.
check_tree() {
  root=$1; f=0
  loop="$root/docs/discovery/discovery-loop.md"
  frame="$root/docs/discovery/frame.md"
  shape="$root/docs/discovery/shape.md"
  brief="$root/templates/OPPORTUNITY-BRIEF-TEMPLATE.md"
  shaping="$root/templates/SHAPING-DOC-TEMPLATE.md"
  onb="$root/ONBOARDING.md"
  if [ -f "$loop" ]; then
    for s in $STAGES; do
      if grep -q "$s" "$loop"; then echo "PASS: discovery-loop names $s"; else echo "FAIL: discovery-loop omits $s"; f=1; fi
    done
  else echo "FAIL: missing $loop"; f=1; fi
  if [ -f "$frame" ]; then echo "PASS: frame.md exists"; else echo "FAIL: missing $frame"; f=1; fi
  if [ -f "$shape" ]; then echo "PASS: shape.md exists"; else echo "FAIL: missing $shape"; f=1; fi
  if [ -f "$brief" ]; then echo "PASS: OPPORTUNITY-BRIEF template exists"; else echo "FAIL: missing $brief"; f=1; fi
  if [ -f "$shaping" ]; then echo "PASS: SHAPING-DOC template exists"; else echo "FAIL: missing $shaping"; f=1; fi
  if [ -f "$onb" ] && grep -q "docs/discovery" "$onb"; then echo "PASS: ONBOARDING links the discovery door"; else echo "FAIL: ONBOARDING omits the discovery door"; f=1; fi
  return $f
}

if [ "${1:-}" = "--selftest" ]; then
  sfail=0
  g=$(mktemp -d); mkdir -p "$g/docs/discovery" "$g/templates"
  if check_tree "$g" >/dev/null 2>&1; then echo "FAIL: selftest — gap not detected"; sfail=1; else echo "PASS: selftest — missing discovery artifacts detected"; fi
  ok=$(mktemp -d); mkdir -p "$ok/docs/discovery" "$ok/templates"
  printf '# loop\nFRAME SHAPE PLAN BUILD SHIP OBSERVE\n' > "$ok/docs/discovery/discovery-loop.md"
  printf '# frame\n' > "$ok/docs/discovery/frame.md"
  printf '# shape\n' > "$ok/docs/discovery/shape.md"
  printf '# brief\n' > "$ok/templates/OPPORTUNITY-BRIEF-TEMPLATE.md"
  printf '# shaping\n' > "$ok/templates/SHAPING-DOC-TEMPLATE.md"
  printf 'see docs/discovery/discovery-loop.md\n' > "$ok/ONBOARDING.md"
  if check_tree "$ok" >/dev/null 2>&1; then echo "PASS: selftest — complete layer passes"; else echo "FAIL: selftest — complete layer wrongly rejected"; sfail=1; fi
  [ "$sfail" -eq 0 ] && { echo "OK: discovery-complete selftest (fixtures left in $g, $ok)"; exit 0; } || { echo "FAIL: discovery-complete selftest"; exit 1; }
fi

case "${1:-}" in
  "") : ;;
  *) echo "usage: discovery-complete.sh [--selftest]" >&2; exit 2 ;;
esac

echo "Discovery layer completeness:"
if check_tree "."; then
  echo "OK: discovery layer present + wired (loop overview + FRAME/SHAPE guides + 2 templates + ONBOARDING door)"
  exit 0
else
  echo "FAIL: discovery layer incomplete (see above)"
  exit 1
fi
```

- [ ] **Step 2:** `chmod +x conformance/discovery-complete.sh && dash -n conformance/discovery-complete.sh && shellcheck -s sh -S warning conformance/discovery-complete.sh && echo OK` → `OK`.
- [ ] **Step 3:** `sh conformance/discovery-complete.sh --selftest` → 2 PASS + `OK: discovery-complete selftest`.
- [ ] **Step 4:** `sh conformance/discovery-complete.sh; echo "exit=$?"` → multiple `FAIL:` + `exit=1` (expected red; later tasks turn it green).
- [ ] **Step 5:** Commit: `git add conformance/discovery-complete.sh && git commit -m "feat(conformance): discovery-complete — structural drift-guard for the discovery layer"`

---

### Task 2: `docs/discovery/discovery-loop.md` — the 6-stage overview

**Files:** Create `docs/discovery/discovery-loop.md`

- [ ] **Step 1: Write it.** Must contain the six literal stage names `FRAME SHAPE PLAN BUILD SHIP OBSERVE` (the check greps them). Required structure:

```markdown
# The Discovery Loop — from raw signal to Ready (optional, upstream)

> **Optional layer.** Sparkwright's engine starts at a **Ready** backlog. If you already have product
> and design figured out, **skip this entirely** — go to [START-HERE.md](../../START-HERE.md) and build.
> This layer is the *front porch* for turning raw signals into Ready work; it is never a turnstile.

## The whole loop at a glance

A product moves through six stages. Each stage names an **owner**, what it **absorbs** (the legacy
activities it replaces), its **ART** (human turns — where a person decides), its **AI** (the tasks AI
does), a **gate**, and **loop-backs** (a later stage routing deliberately back — *change, not noise*).

| # | Stage | Owner | Gate | Where it lives |
|---|-------|-------|------|----------------|
| 1 | **FRAME** | Product | Frame approved | this layer → [frame.md](frame.md) |
| 2 | **SHAPE** | Design | Direction chosen | this layer → [shape.md](shape.md) |
| 3 | **PLAN** | Product | Ready | **Sparkwright engine** — `DEVELOPMENT-PROCESS.md` §5–6 + FEATURE-REQUEST/SPEC + Definition of Ready |
| 4 | **BUILD** | Engineering | (build) | **Sparkwright engine** — the loop |
| 5 | **SHIP** | Engineering | Merge & ship | **Sparkwright engine** — Review/Release |
| 6 | **OBSERVE** | Product+Eng | (loop back) | **Sparkwright engine** — Operate |

**Stages 3–6 already are Sparkwright's loop** (Plan → Build → Review/Release → Operate). They are
shown here only to place FRAME and SHAPE; they are unchanged by this layer.

## The seam: Ready

FRAME produces an **Opportunity Brief** ([template](../../templates/OPPORTUNITY-BRIEF-TEMPLATE.md));
SHAPE produces a **Shaping Doc** ([template](../../templates/SHAPING-DOC-TEMPLATE.md)). Together they
feed PLAN, which produces a **Ready** story via the existing FEATURE-REQUEST/SPEC templates and the
**Definition of Ready**. That gate is the handoff into the engine — the layer touches nothing downstream.

## Where AI assists vs. where the human decides

Across all stages, the rule is the same: **AI does the tasks; the human takes the turns that carry
judgment, accountability, or a gate.** AI normalizes, synthesizes, drafts, prototypes, scores; the
human frames the problem, chooses direction, sets priorities, and approves each gate. The per-stage
split is in [frame.md](frame.md) and [shape.md](shape.md). It is **guidance, not an automated gate** —
discovery is judgment work.

## Honesty

A green `conformance/discovery-complete.sh` means this layer is **present and wired** — not that your
discovery was good or your problem truly validated. The guard and gates remain the safety net.
```

- [ ] **Step 2:** `sh conformance/discovery-complete.sh 2>&1 | grep -E "names (FRAME|OBSERVE)"` → shows FRAME…OBSERVE PASS lines. `sh conformance/check-links.sh | tail -1` (forward-ref links to frame.md/shape.md/templates resolve after later tasks — mid-slice failure acceptable; re-checked in Task 6).
- [ ] **Step 3:** Commit: `git add docs/discovery/discovery-loop.md && git commit -m "feat(discovery): discovery-loop overview — 6 stages, 3-6 map to the existing engine, opt-in"`

---

### Task 3: `docs/discovery/frame.md` + `docs/discovery/shape.md`

**Files:** Create both stage guides.

- [ ] **Step 1: `frame.md`:**

```markdown
# FRAME — turn raw signals into a framed problem

**Owner:** Product · **Gate:** Frame approved · **Absorbs:** intake · research · requirements planning

FRAME is where a raw signal (an idea, a stakeholder ask, research, a support trend) becomes a
**framed problem** worth pursuing — with evidence and a target outcome — *before* anyone designs or
builds. Output: an **[Opportunity Brief](../../templates/OPPORTUNITY-BRIEF-TEMPLATE.md)** that clears
the *Frame approved* gate.

## Human turns (ART) — where you decide
- **Frame the problem** — what, for whom, why now; the pain in one sentence.
- **Target outcome / OKR** — the measurable change you want (a hypothesis, not a feature).
- **Big ideas** — the candidate directions worth shaping.
- **Frame approved** — the gate: this is real and worth Design's time. (Owner decision.)

## AI tasks — where AI helps
- **Normalize intake** — turn messy signals (tickets, notes, transcripts) into a structured brief.
- **Research synthesis** — summarize evidence, prior art, comparable solutions.
- **Draft requirements** — propose a first-cut problem statement + outcome for you to sharpen.

## Loop-backs
From SHAPE or later: if shaping reveals the problem was mis-framed, route back here deliberately —
re-frame, don't paper over it.
```

- [ ] **Step 2: `shape.md`:**

```markdown
# SHAPE — turn a framed problem into a chosen direction

**Owner:** Design · **Gate:** Direction chosen · **Absorbs:** concept · design · architecture exploration · reviews

SHAPE takes a Frame-approved problem and explores **how** to solve it — concept, design intent, and a
viable architecture approach — far enough to commit a direction, *not* to final pixels or code.
Output: a **[Shaping Doc](../../templates/SHAPING-DOC-TEMPLATE.md)** that clears *Direction chosen* and
feeds PLAN.

## Human turns (ART) — where you decide
- **Concept direction** — the approach you're committing to.
- **Design intent** — the experience and the non-negotiables (incl. the a11y obligation the DoD checks).
- **Architecture approach** — the shape of the solution; feasibility and big risks named.
- **Direction chosen** — the gate: enough to plan and slice. (Owner decision.)

## AI tasks — where AI helps
- **Rapid prototypes** — generate low-fidelity options to react to.
- **Design explorations** — variations, comparisons, edge-case probing.
- **Option synthesis** — pull the explorations into a small set of real choices + tradeoffs.

## Loop-backs
From PLAN/BUILD: if planning or building invalidates the direction, route back here — re-shape, then
re-enter PLAN. From FRAME: a re-frame restarts shaping.
```

- [ ] **Step 3:** `sh conformance/discovery-complete.sh 2>&1 | grep -E "frame.md|shape.md"` → both `PASS: … exists`.
- [ ] **Step 4:** Commit: `git add docs/discovery/frame.md docs/discovery/shape.md && git commit -m "feat(discovery): FRAME + SHAPE stage guides (owner/ART/AI/gate/loop-backs)"`

---

### Task 4: the two upstream templates

**Files:** Create `templates/OPPORTUNITY-BRIEF-TEMPLATE.md` + `templates/SHAPING-DOC-TEMPLATE.md`. Match the kit's existing template style (a guidance blockquote at top; `[...]` fill-ins).

- [ ] **Step 1: `OPPORTUNITY-BRIEF-TEMPLATE.md`:**

```markdown
# Opportunity Brief — [short title]

> **Template (FRAME output).** Fill every `[...]`; delete guidance blockquotes once filled. Clears the
> **Frame approved** gate, then feeds SHAPE. Keep it to a page — this is a framed problem, not a PRD.

**Owner (Product):** [name] · **Date:** [date] · **Status:** [Framing / Frame approved]

## Problem
- **What & for whom:** [the problem, and who has it]
- **Current pain / why now:** [what's wrong today; why it matters now]

## Evidence (not assumption)
- [signal · request volume · telemetry · support tickets · research — what tells us this is real]

## Target outcome (hypothesis)
- [the measurable change we want — e.g. "X% of users do Y within Z"; a hypothesis, not a feature]

## Big-idea directions
- [candidate direction A] · [B] · [C — the options worth shaping]

## Risks / flags
- [obvious risk · complexity · compliance/privacy/security flag the DoR will pick up]

## Frame approved
- [ ] Owner sign-off: this is real, evidenced, and worth Design's time. — **[name], [date]**
```

- [ ] **Step 2: `SHAPING-DOC-TEMPLATE.md`:**

```markdown
# Shaping Doc — [short title]

> **Template (SHAPE output).** Fill every `[...]`; delete guidance blockquotes once filled. Clears the
> **Direction chosen** gate, then feeds PLAN (→ FEATURE-REQUEST / SPEC → Ready). Shape, don't finalize.

**Owner (Design):** [name] · **Date:** [date] · **Status:** [Shaping / Direction chosen]
**Frames:** [link to the Opportunity Brief]

## Chosen concept direction
- [the approach being committed to, and why over the alternatives]

## Design intent
- [the experience + non-negotiables; note the WCAG 2.1 AA obligation the Definition of Done checks]

## Architecture approach
- [the shape of the solution; key components; feasibility + big risks named]

## Prototypes / assets
- [links to low-fi prototypes, explorations, design assets]

## Open questions for PLAN
- [what still needs decisions during planning/slicing]

## Direction chosen
- [ ] Owner sign-off: enough to plan, slice, and write acceptance criteria. — **[name], [date]**
```

- [ ] **Step 3:** `sh conformance/discovery-complete.sh 2>&1 | grep -E "OPPORTUNITY|SHAPING"` → both `PASS: … exists`. `sh conformance/check-links.sh | tail -1` → should now be `OK` (all forward-refs from discovery-loop now resolve).
- [ ] **Step 4:** Commit: `git add templates/OPPORTUNITY-BRIEF-TEMPLATE.md templates/SHAPING-DOC-TEMPLATE.md && git commit -m "feat(discovery): Opportunity Brief + Shaping Doc templates (feed the existing PLAN artifacts)"`

---

### Task 5: Wiring — ONBOARDING door + README + GLOSSARY

**Files:** Modify `ONBOARDING.md`, `README.md`, `GLOSSARY.md`.

- [ ] **Step 1: `ONBOARDING.md` — add the discovery door.** After the 3-lane self-select block (before/near the Learning lane), add:

```markdown
> **Don't have the product or design figured out yet?** Most of this kit assumes you arrive with a
> *Ready* backlog. If you're upstream of that — raw idea, no validated problem yet — start with the
> optional **[discovery loop](docs/discovery/discovery-loop.md)** (FRAME → SHAPE → Ready), then come back.
```

- [ ] **Step 2: `README.md` — flip the milestone discovery mention + add a What's-inside row.** In the milestone blockquote, change the discovery sentence from "is a separate, optional upstream layer; see the roadmap" to: "is an optional upstream layer — see **[docs/discovery/discovery-loop.md](docs/discovery/discovery-loop.md)**." Add a "What's inside" row after the `WALKTHROUGH.md` row:

```markdown
| **`docs/discovery/`** | The optional upstream **discovery loop** (FRAME → SHAPE → Ready) — turn a raw signal into a Ready backlog. Skip it if you already have one. |
```

- [ ] **Step 3: `GLOSSARY.md` — add entries** (match the file's existing `**Term** — …` style):

```markdown
**Discovery loop** — the optional upstream front-end (FRAME → SHAPE → Ready) that turns a raw signal into a Ready backlog the Sparkwright engine consumes. Opt-in; skip it if you already have a Ready backlog. See `docs/discovery/discovery-loop.md`.

**FRAME / SHAPE** — the two discovery stages this kit adds: FRAME (Product-owned) frames a raw signal into an evidenced problem (gate: Frame approved); SHAPE (Design-owned) explores it into a chosen direction (gate: Direction chosen). Stages 3–6 of the loop (PLAN/BUILD/SHIP/OBSERVE) are the existing engine.
```

- [ ] **Step 4:** `sh conformance/discovery-complete.sh; echo "exit=$?"` → all PASS + `exit=0`. `sh conformance/check-links.sh | tail -1` → `OK`.
- [ ] **Step 5:** Commit: `git add ONBOARDING.md README.md GLOSSARY.md && git commit -m "feat(discovery): wire the discovery door (ONBOARDING + README + GLOSSARY)"`

---

### Task 6: Register the control + full green

**Files:** Modify `conformance/verify.sh` + `conformance/README.md`.

- [ ] **Step 1: `verify.sh`** — after the `check control onboarding …` line add:

```sh
check control discovery        sh conformance/discovery-complete.sh
```

- [ ] **Step 2: `conformance/README.md`** — after the `onboarding-complete.sh` row add:

```markdown
| `discovery-complete.sh` | script | the optional discovery layer is structurally present + wired — `discovery-loop.md` names all six loop stages, the FRAME/SHAPE guides + the two upstream templates exist, and `ONBOARDING.md` links the discovery door. Completeness only — green means present + wired, NOT that any discovery was good; `--selftest` covers gap + complete fixtures | CI |
```

- [ ] **Step 3: full suite:**
```
sh conformance/discovery-complete.sh; echo "real=$?"
sh conformance/discovery-complete.sh --selftest >/dev/null && echo "selftest OK"
sh conformance/shellcheck.sh | tail -1
sh conformance/check-links.sh | tail -1
sh conformance/doc-budget.sh | tail -1
sh conformance/verify.sh 2>&1 | grep -E "discovery|Summary|RESULT"
```
Expected: `real=0`; `selftest OK`; shellcheck OK; links OK; `OK: core docs within budget`; `[control] discovery PASS`. NOTE: `verify.sh` RESULT will be **FAIL** until the CI step (Step 4 control-plane) lands, because `ci-selftest-coverage` flags `discovery-complete.sh` as unwired — expected; the kit's actual CI doesn't run aggregate verify.sh.

- [ ] **Step 4 (CONTROL-PLANE — human hand-apply on this branch, before the PR):** add to `.github/workflows/ci.yml` in the `conformance` job's step list (colon-free name, 6/8 indent):
```yaml
      - name: Discovery layer completeness (present + wired)
        run: sh conformance/discovery-complete.sh
```
Validate (`ruby -ryaml -e "YAML.load_file('.github/workflows/ci.yml'); puts 'YAML OK'"`), then `KIT_GUARD_SELFEDIT=1 git add .github/workflows/ci.yml` if needed.

- [ ] **Step 5:** Commit (control + the hand-applied CI step together): `git add conformance/verify.sh conformance/README.md && git commit -m "feat(conformance): register discovery-complete control in verify.sh + README"`

---

### Task 7: Release bump → 2.61.0

**Files:** `VERSION`, `README.md` badge, `CHANGELOG.md`.

- [ ] **Step 1:** `printf '2.61.0\n' > VERSION`
- [ ] **Step 2:** README badge `` `v2.60.0` `` → `` `v2.61.0` ``.
- [ ] **Step 3: CHANGELOG entry** above the most recent:

```markdown
## [2.61.0] - 2026-06-15

**Discovery loop (FRAME + SHAPE)** — an **optional, opt-in** upstream front-end that turns a raw signal into a *Ready* backlog the Sparkwright engine consumes. **MINOR** — new docs + templates + one structural control; **no change to the existing process** (stages 3–6 are documented as the existing engine).

### Added
- **`docs/discovery/discovery-loop.md`** — the six-stage product loop (owner · ART=human turns · AI=tasks · gate · loop-backs); maps stages 3–6 onto Sparkwright's existing loop; states the opt-in/skip rule and the Ready seam.
- **`docs/discovery/frame.md` + `shape.md`** — the two new stage guides (FRAME = Product/Frame-approved; SHAPE = Design/Direction-chosen), each with its human-turns vs AI-tasks split.
- **`templates/OPPORTUNITY-BRIEF-TEMPLATE.md` + `SHAPING-DOC-TEMPLATE.md`** — the upstream artifacts that feed the existing FEATURE-REQUEST/SPEC at PLAN → Ready (no duplication).
- **`conformance/discovery-complete.sh`** — structural drift-guard (present + wired); wired into CI.
- Wiring: an ONBOARDING discovery door, README milestone link + What's-inside row, GLOSSARY entries.

### Honesty / engineering notes
- **Opt-in, never a turnstile** — arrive with a Ready backlog and you skip discovery entirely (the onboarding Practitioner fast-path). The default drop-in-and-build path is untouched.
- **Zero process change** — the core-3 docs are unchanged (900/900); the layer is all new files. The ART/AI split is guidance, not an automated gate (discovery is judgment work).
```

- [ ] **Step 4:** `sh conformance/badge-version.sh && sh conformance/check-links.sh | tail -1` → badge PASS; links OK.
- [ ] **Step 5:** Commit: `git add VERSION README.md CHANGELOG.md && git commit -m "chore(release): 2.61.0 — discovery loop (FRAME + SHAPE)"`

---

## After all tasks
1. **Independent review** (`reviewer`) on `git diff main...HEAD` — confirm: no process-doc/core-3 change; opt-in framing honest; 3–6 documented-not-modified; check + selftest green; the only `verify.sh` red (if any) is the pending CI wiring (which Step 6.4 already folded in on the branch).
2. **Open the PR** with `--body-file`. Bradley merges.
3. After merge: `git tag v2.61.0 && git push origin v2.61.0`.
