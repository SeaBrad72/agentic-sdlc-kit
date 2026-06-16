# Discovery Layer (FRAME + SHAPE) — Design

**Status:** approved (brainstorm), ready for implementation planning
**Release:** MINOR → **2.61.0**
**Depends on:** PR #90 (Sparkwright naming / 2.60.0) merged first — this layer builds on the named base and a clean 2.60→2.61 version chain.

**Scope:** add the **optional, opt-in discovery front-end** — the two upstream stages (FRAME, SHAPE) that turn a raw signal into a *Ready* backlog the existing Sparkwright engine consumes. Built entirely as **new files**; the existing development process is **not changed** — it becomes the supportive back half.

---

## 1. Context & thesis

Sparkwright today is a complete **execution engine**: it takes a *Ready* backlog → operating, monitored software. The seam it starts from is **Definition of Ready** (`DEVELOPMENT-PROCESS.md` §5 Discovery is deliberately thin: raw idea → validated candidate). What's missing is the **front-end** *before* Ready: how a raw signal becomes a framed problem and a shaped solution.

This design adds that front-end as a **product loop** distilled from a real-world reference flow (anonymized — no "Starman", no "PBS"). The loop has six stages; **stages 3–6 already are Sparkwright's loop**, so we only **build stages 1–2 (FRAME, SHAPE)** and *document* 3–6 as the existing engine.

**The linchpin constraint (non-negotiable):** the discovery layer is **opt-in**. Anyone who arrives with a Ready backlog **skips FRAME/SHAPE entirely** and goes straight to Inception → Build. Discovery is a **front porch, not a turnstile** — it must never become mandatory friction on the path to building. (It plugs into the onboarding **Practitioner lane**, which is exactly "I've got it, route me to the contract.")

## 2. The product loop (vocabulary + mapping)

Each stage carries a consistent frame: **owner · absorbs (the legacy activities it subsumes) · ART (human turns — where a person decides) · AI (the tasks AI does) · gate · loop-backs.** The ART/AI split is the kit's answer to *where AI assists vs. where the human stays in the loop* — expressed as **recommendation**, not an automated gate.

| # | Stage | Owner | Gate | Built or existing? |
|---|-------|-------|------|--------------------|
| 1 | **FRAME** | Product | *Frame approved* | **BUILD (new)** |
| 2 | **SHAPE** | Design | *Direction chosen* | **BUILD (new)** |
| 3 | **PLAN** | Product | *Ready* | existing (`§5`/`§6` + FEATURE-REQUEST/SPEC + Definition of Ready) — front edge lightly *referenced*, not changed |
| 4 | **BUILD** | Engineering | *(build)* | existing (the loop) |
| 5 | **SHIP** | Engineering | *Merge & ship* | existing (Review/Release) |
| 6 | **OBSERVE** | Product+Eng | *(loop back)* | existing (Operate) |

**Loop-backs** (a later stage routing deliberately back to an earlier one — "change, not noise") are documented as part of the model; they map onto the kit's existing retro/outcome-validation routing.

## 3. Components (all new files — no process change)

1. **`docs/discovery/discovery-loop.md`** — the centerpiece. The full 6-stage loop in the vocabulary above; **explicitly maps 3–6 onto Sparkwright's existing engine**; states the **opt-in/skip rule** and the **Ready seam**; shows the loop-backs. This is the "supportive, not disruptive" framing made concrete.
2. **`docs/discovery/frame.md`** — FRAME stage guide: owner (Product), absorbs (intake · research · requirements planning), **ART** (frame the problem · outcomes/OKRs · big ideas · *Frame-approved* decision), **AI** (normalize intake · research synthesis · draft requirements), gate (*Frame approved*), loop-backs. Points to its template.
3. **`docs/discovery/shape.md`** — SHAPE stage guide: owner (Design), absorbs (concept · design · architecture exploration · reviews), **ART** (concept direction · design intent · architecture approach · *Direction-chosen* decision), **AI** (rapid prototypes · design explorations · option synthesis), gate (*Direction chosen*), loop-backs. Points to its template.
4. **`templates/OPPORTUNITY-BRIEF-TEMPLATE.md`** — FRAME's output artifact: problem · who/for-whom · evidence · target outcome/hypothesis · big-idea options · risks/flags · the *Frame-approved* sign-off. Mirrors the kit's existing template style (guidance blockquote, fill-the-`[...]`).
5. **`templates/SHAPING-DOC-TEMPLATE.md`** — SHAPE's output artifact: chosen concept direction · design intent · architecture approach · prototype/asset refs · open questions · the *Direction-chosen* sign-off. **Feeds the existing `FEATURE-REQUEST`/`SPEC` templates at PLAN** → Ready. No duplication of those.
6. **Wiring (no process change):**
   - `ONBOARDING.md` — add a **discovery door**: "Don't have product/design figured out yet? → the discovery layer (`docs/discovery/discovery-loop.md`)." The opt-in entry; pairs with the Practitioner fast-path.
   - `README.md` — flip the milestone line's discovery mention from "roadmap" to **"available (optional upstream layer)"** + link; add a `docs/discovery/` row to "What's inside."
   - `GLOSSARY.md` — entries for the loop vocabulary (the discovery loop · FRAME · SHAPE · ART/AI turns).
7. **`conformance/discovery-complete.sh`** — structural drift-guard (mirrors `onboarding-complete.sh`): the discovery layer is present + wired — `discovery-loop.md` names all six stages + FRAME/SHAPE; `frame.md`/`shape.md` exist; the two templates exist; `ONBOARDING.md` links the discovery door. `--selftest` (gap + complete fixtures). Registered in `verify.sh` + `conformance/README.md`. **CI step folded into the branch** (the #88 lesson: hand Bradley the one ci.yml line before the PR, not after).

## 4. The opt-in guarantee (how it stays supportive, not disruptive)

- **Zero lines of `DEVELOPMENT-PROCESS.md` / `DEVELOPMENT-STANDARDS.md` / `CLAUDE.md` change.** (Core-3 is at its 900/900 cap, which mechanically enforces this.) §5 Discovery stays the handoff point exactly as written.
- The discovery layer is reachable only by **choosing** it (the ONBOARDING door / README link). The default drop-in-and-build path is untouched — the Quickstart still goes straight to Inception.
- The hand-off is the **Ready** gate (Definition of Ready). FRAME→SHAPE produce the Opportunity Brief + Shaping Doc, which feed the *existing* PLAN artifacts. Downstream is never touched.

## 5. Honesty

- The ART/AI split is **guidance** (where AI helps vs. where a human decides), **not** an automated gate — discovery is judgment work; gating it would invite gaming.
- `discovery-complete.sh` green = the layer is **present + wired**, **not** that any actual discovery was good or that a problem was truly validated. Stated in the doc + the check.
- The two new templates are **reference artifacts** an adopter owns and adapts (contract→reference→conformance), not mandatory forms.

## 6. Doc-budget

**Nothing touches the core-3** (CLAUDE/PROCESS/STANDARDS stay 900/900). All new material is uncapped: `docs/discovery/*`, `templates/*`, and the `ONBOARDING.md`/`README.md`/`GLOSSARY.md` wiring. Run `doc-budget.sh` after wiring to confirm 900/900 held.

## 7. Slicing

One coherent slice, internally ordered (TDD-style — the check is the red):
1. `conformance/discovery-complete.sh` (+ `--selftest`) → real run FAILs (the slice's red).
2. `docs/discovery/discovery-loop.md` (the 6-stage overview + mapping + opt-in rule).
3. `docs/discovery/frame.md` + `docs/discovery/shape.md`.
4. `templates/OPPORTUNITY-BRIEF-TEMPLATE.md` + `templates/SHAPING-DOC-TEMPLATE.md`.
5. Wiring: ONBOARDING door + README + GLOSSARY.
6. Register the control in `verify.sh` + README; full green.
7. Release bump → 2.61.0.

Independent review (builder ≠ reviewer) before the PR. Bradley merges. The `discovery-complete.sh` CI step is **folded into the branch** as the one control-plane hand-apply (handed over before the PR, not after).

## 8. Out of scope

- Any change to stages 3–6 (the existing engine) — documented as-is, not modified.
- Any change to the development process / standards / Definition of Ready itself.
- A mandatory discovery gate (it's opt-in by design).
- Prioritization *tooling* (RICE/WSJF calculators) — the templates may *name* a prioritization field, but we don't build a scoring engine (YAGNI; the existing §6 ranking stands).
- PBS-specific content (this layer is the generic framework only).
- The repo-slug rename (a separate pre-launch task).

## 9. Definition of Done

- `docs/discovery/discovery-loop.md` (6 stages + vocabulary + 3–6 mapping + opt-in rule + Ready seam + loop-backs).
- `docs/discovery/frame.md` + `shape.md` (owner/ART/AI/gate/loop-backs each).
- `templates/OPPORTUNITY-BRIEF-TEMPLATE.md` + `templates/SHAPING-DOC-TEMPLATE.md` (feed the existing PLAN templates).
- ONBOARDING discovery door + README milestone/“What's inside” + GLOSSARY entries.
- `conformance/discovery-complete.sh` (+ `--selftest`) registered in `verify.sh` + README; shellcheck-clean; dash-clean; CI step folded into the branch.
- core-3 doc-budget 900/900 held; `verify.sh` RESULT OK; links resolve; independent review → SHIP; ratified PR; **2.61.0** release.
