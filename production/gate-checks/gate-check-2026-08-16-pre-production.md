# Gate Check: Technical Setup → Pre-Production

- **Date**: 2026-08-16
- **Checked by**: `/gate-check pre-production`
- **Review mode**: `lean` (`production/review-mode.txt`)
- **Branch / commit**: `claude-refactor` @ `9bc3e46` — working tree clean
- **Prior run**: `production/gate-checks/gate-check-2026-08-15-pre-production.md` (2026-08-15, **FAIL**, 4 blockers)
- **Verdict**: **FAIL**

---

## Required Artifacts — 11 of 13 present (2 present-but-stale)

| | Artifact | Evidence |
|---|---|---|
| ✅ | Engine chosen | `CLAUDE.md:8` — Godot 4.7.1 |
| ⚠️ | Technical preferences configured | `.claude/docs/technical-preferences.md` populated, but the same 3 stale placeholders from the 2026-08-15 gate are still unfixed — see Concerns |
| ❌ | Art bible §1–4 | **MISSING** — `design/art/` does not exist. Only the unfilled template at `.claude/docs/templates/art-bible.md` exists |
| ✅ | ≥3 Foundation ADRs | **12 of 12 ADRs exist, all `Accepted`** — verified by reading each file's `## Status` field directly |
| ✅ | Engine reference docs | `docs/engine-reference/godot/` — VERSION.md, breaking-changes.md, deprecated-apis.md, current-best-practices.md, modules/ |
| ✅ | `tests/unit/` + `tests/integration/` | Both exist; `integration/` still holds only a placeholder, no test files |
| ✅ | CI test workflow | `.github/workflows/tests.yml` |
| ✅ | Example test file | 3 suites — **52/52 pass, 0 errors, 0 failures, exit 0**, executed live during this gate |
| ✅ | `docs/architecture/architecture.md` | Exists, Document Status header correctly says "12 of 12 exist, all Accepted" |
| ⚠️ | `docs/architecture/requirements-traceability.md` | **Exists but stale.** Still says "28 of 52 requirements / 7 of 12 ADRs written," last regenerated 2026-08-15 session 18. The actual source of truth (`tr-registry.yaml`) has moved to **49/52 covered, 0 gap_assigned_to_unwritten_adr** as of session 23 (2026-08-16) — this file was never regenerated to match |
| ✅ | `/architecture-review` report | 4 reports exist in `docs/architecture/` (most recent: `architecture-review-2026-08-15-c.md`, verdict CONCERNS, since resolved — see Quality Checks) |
| ✅ | `design/accessibility-requirements.md` | Exists. **Fixed since last gate.** Tier: **Standard, with reduced motion elevated from Comprehensive** |
| ✅ | `design/ux/interaction-patterns.md` | Exists. **Fixed since last gate.** Minimal (all patterns `Draft`), acceptable per gate wording "even if minimal" |

Three of the four 2026-08-15 blockers are now resolved (accessibility, interaction patterns, traceability index — the index exists but its *content* is stale, a new and different problem from "missing"). **Art bible is the one blocker that survived unchanged.**

---

## Quality Checks — 8 of 11 passing

| | Check | Result |
|---|---|---|
| ✅ | ADR dependency graph acyclic | All 12 "Depends On" sections read directly. No cycle: 0001/0002/0004/0006 depend on nothing; 0003→{0001,0002}; 0005→0002; 0007→{...}; 0008→{0002,0005,0006}; 0009→{0002,0004,0005,0007}; 0010→{0002,0003,0005,0006,0008}; 0011→{0001,0004,0006}; 0012→{0006,0009} |
| ✅ | All ADRs have an Engine Compatibility section | 12 / 12 |
| ✅ | All ADRs have a GDD Requirements Addressed section | 12 / 12 |
| ✅ | No deprecated API usage | Every row of `deprecated-apis.md` grepped against all 12 ADRs — the one hit (ADR-0010) is a correct citation confirming `RichTextLabel` is *avoided*, not a violation |
| ✅ | HIGH RISK engine domains addressed | Control offset transforms closed HIGH→LOW in `architecture.md`; RichTextLabel `add_image` break avoided by design (ADR-0010 V-E8); Jolt/AreaLight3D/HDR/stencil correctly N/A for a 2D GL-Compatibility game |
| ✅ | Naming conventions + performance budgets set | `technical-preferences.md` — 60 FPS / 16.6 ms / <500 draw calls / 512 MB |
| ✅ | Accessibility tier defined | **Fixed.** Standard + reduced motion, with documented rationale |
| ⚠️ | Traceability matrix has zero Foundation gaps | **True by the registry** (`tr-registry.yaml`: 0 `gap_assigned_to_unwritten_adr`), **false by the generated document** (`requirements-traceability.md` still shows 22 gaps). Whoever reads the artifact instead of the registry gets the wrong answer |
| ✅ | Architecture covers rendering / input / state management | Input now closed by ADR-0007 (Accepted); state by ADR-0002; rendering N/A for 2D GL-Compat |
| ⚠️ | All ADRs agree on engine version | All 12 stamp "Godot 4.7"; project pins 4.7.1. Consistent internally, imprecise vs. the pin — same as last gate, still unfixed |
| ⚠️ | `architecture.md` internally self-consistent | **New finding.** The Document Status header (line 10) says "12 of 12, all Accepted," but the ADR Audit and Traceability coverage sections further down (lines 747–765) still say "7 ADRs (0001–0007)" and "28 of 52" — one file contradicting itself, not yet reconciled by `/architecture-review` |

---

## Director Panel Assessment

Creative Director:  **NOT READY**
  Two blockers. (1) The pillars were never ratified — `game-concept.md` is `status: reverse-documented`, and its own checklist item "Get concept approval from creative-director" is **unchecked**. CD-PILLARS never ran. Committing sprint capacity in Pre-Production against a vision document that itself says it isn't authoritative yet is the concern. (2) No art bible — Pillar 1 (gravity-flip legibility) delivers visually, and that delivery mechanism has no spec. Concern raised separately: a possible ludonarrative tension (oxygen never refills, plants never give air back) is real but unnamed in any doc.

Technical Director: **CONCERNS**
  No blockers — architecture is sound enough to begin. Six ranked concerns, top two: `architecture.md` and `requirements-traceability.md` are stale and contradict the file's own header (matches this report's findings independently); `TR-watering-002` (carry-speed penalty) is deliberately unowned by any ADR and needs a decision before the watering epic is scheduled. Also flagged: performance budgets are global, not allocated per-system; `tests/integration/` is empty against exactly the cross-system contracts (ADR-0005, ADR-0008) that need it; wall jump / moving platforms / spike hazards are implemented in `src/` with zero GDD or TR coverage (QQ-05).

Producer: **CONCERNS**
  **Correction to this gate's own briefing**: `src/` is not untouched — it holds **1,107 files, 18 scenes, 8 playable levels**, verified directly. This gate is validating a **brownfield migration of already-shipped behavior**, not a greenfield Pre-Production start, and `tests/integration/` being empty means the first sprints would refactor working code with no regression net. Also: no timeline exists to size epics against (only a single "1–3 months, Full Vision" estimate, predating all 12 ADRs' added scope); four items (settings screen, camera-subscription defect, `TR-gravity-010`, `TR-watering-002`) enter Pre-Production with no owning ADR; no `production/milestones/` or risk register exists yet.

Art Director:       **NOT READY**
  `design/art/art-bible.md` does not exist — confirmed by direct filesystem check. This is a named required artifact at this exact gate. Two documents are already blocked on it: `interaction-patterns.md` states outright it cannot cite visual standards without it, and `hud.md` has parked a project-wide 56-colour NES palette constraint in a screen-specific doc for lack of anywhere else to put it. Contributing gap: no evidence `AD-CONCEPT-VISUAL` ever ran — the visual identity anchor has no confirmed foundation for the art bible to draft from.

**Escalation applied**: two directors returned NOT READY (Creative, Art) → verdict floor is **FAIL**, independent of and consistent with the artifact-check result below.

---

## Blockers

### 1. No art bible (carried from 2026-08-15, unresolved)

`design/art/art-bible.md` required at this gate; still missing entirely. Two documents (`interaction-patterns.md`, `hud.md`) are already working around its absence. **Fix**: `/art-bible` — sections 1–4 satisfy this gate.

### 2. Game concept was never formally ratified (new finding, surfaced by CD-PHASE-GATE)

`design/gdd/game-concept.md` carries `status: reverse-documented` and its own checklist still shows "Get concept approval from creative-director" unchecked. Every ADR, GDD, and UX doc in this project ultimately traces back to a concept document that has never received a formal creative sign-off. This didn't block the Technical Setup gate (which doesn't check it), but it blocks here because Pre-Production is where sprint capacity gets committed against that vision.

**Fix**: Run the `CD-PILLARS` gate against `game-concept.md` (or fold it into a `/design-review` pass) and check the approval box, or explicitly accept the risk in writing.

### 3. `requirements-traceability.md` and `architecture.md` are stale and self-contradictory

Both documents were last synced 2026-08-15 (session 18) and never regenerated after ADR-0008 through ADR-0012 were Accepted (sessions 19 and 23). `architecture.md`'s own header says "12 of 12 ADRs Accepted" while its body says "7 ADRs" two hundred lines later. This is not a blocking artifact-existence problem, but it is a correctness problem: implementers who read either document literally, rather than `tr-registry.yaml`, get a materially wrong picture (28/52 vs. actual 49/52).

**Fix**: Run `/architecture-review` (full pass) to regenerate both from the current registry.

---

## Concerns — not blocking this gate, but should not carry into Pre-Production unaddressed

- **`src/` already has substantial implementation** (1,107 files, 8 levels) that this gate's own briefing template assumed was untouched. Pre-Production planning (epics, vertical slice) needs to account for this as a brownfield migration, not a fresh build — this changes the shape of `/vertical-slice` and epic scoping materially.
- **`tests/integration/`** is still empty — exactly the layer that would catch regressions in the brownfield migration above.
- **`TR-watering-002`** (carry-speed penalty) remains deliberately unowned by any ADR — flag before the watering epic, per both TD and PR.
- **`technical-preferences.md`** placeholders (Forbidden Patterns, Allowed Libraries, ADR log) are unchanged since the last gate despite 27 forbidden patterns and 12 Accepted ADRs existing elsewhere.
- **QQ-05**: wall jump, moving platforms, and spike hazards are implemented in `src/` with no GDD, no TR IDs, no ADR coverage.
- **No `production/milestones/` or risk register** — Producer flagged these should exist before epics are scoped.
- **Four unowned gaps** enter Pre-Production without a decision: settings screen, camera-subscription defect, `TR-gravity-010` (camera decouple), `TR-watering-002`.
- **`production/stage.txt`** still says `Concept` — wrong regardless of this verdict; left untouched since this gate did not PASS.
- **BUG-0001** (dead out-of-bounds kill plane) is still Open.

---

## Chain-of-Verification

**5 questions checked — verdict unchanged (FAIL, same as prior gate, for different and narrower reasons).**

1. *Have I accurately separated hard blockers from strong recommendations?* — Yes. Art bible is a named required artifact. The two NOT READY director verdicts trigger the escalation rule's automatic FAIL floor by definition, independent of my own artifact scoring. Everything else (stale docs, unowned TRs, empty integration tests) is listed as Concern, not Blocker, because none of them are named required artifacts or named quality gates at *this* gate.
2. **[TOOL ACTION]** *Are there PASS items I was too lenient about?* — Re-read `requirements-traceability.md` and `tr-registry.yaml` directly (not from memory/session-state): confirmed the artifact exists but is stale, downgraded from clean ✅ to ⚠️. Re-ran the actual test suite rather than trusting the last recorded pass — 52/52, exit 0, confirmed live.
3. **[TOOL ACTION]** *Am I missing additional blockers?* — Grepped `game-concept.md` directly for its status and approval checkbox rather than trusting the Creative Director's summary alone — confirmed `status: reverse-documented` and the unchecked box independently. Also ran `find src -type f | wc -l` directly to verify the Producer's brownfield correction (1,107 files) rather than accepting it unverified.
4. *Can I provide a minimal path to PASS — the specific things that must change?* — Three items: (1) `/art-bible` sections 1–4, (2) ratify `game-concept.md` via a `CD-PILLARS` pass or explicit accepted-risk note, (3) `/architecture-review` full pass to resync `architecture.md` and `requirements-traceability.md` against `tr-registry.yaml`.
5. *Is the fail condition resolvable, or does it indicate a deeper design problem?* — Resolvable, not a design problem. The architecture tier remains genuinely strong (12/12 Accepted ADRs, acyclic dependency graph, 52/52 tests, no deprecated API use). The gap is entirely in visual-identity documentation and one skipped formal-approval step — both are process gaps, not defects in the design itself.

---

## Verdict: FAIL

### Minimal path to PASS — three actions

1. `/art-bible` — sections 1–4 satisfy this gate's artifact requirement.
2. Ratify `design/gdd/game-concept.md` — run `CD-PILLARS`, or explicitly accept the risk of proceeding without formal sign-off, and check the box.
3. `/architecture-review` (full pass) — resync `architecture.md`'s ADR Audit / Traceability coverage sections and regenerate `requirements-traceability.md` from `tr-registry.yaml`.

### Not blocked by any of the above

Everything else — the 12 Accepted ADRs, the 52/52 test suite, the accessibility tier, the interaction pattern library — is in good shape and does not need rework to pass this gate.
