# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-08-17 (second run this date — supersedes `gate-check-2026-08-17-pre-production.md`)
**Checked by**: gate-check skill
**Review mode**: lean (all four PHASE-GATE directors run — phase gates are lean mode's purpose)
**Context**: re-run following session 28's four concern-resolution fixes, committed at `163b73d`
("test: add ADR-0004 migration safety net; scope-resolve pre-production concerns").

---

## Required Artifacts: 13/13 present

| Artifact | Status |
|---|---|
| Engine chosen (CLAUDE.md) | Godot 4.7.1 |
| `.claude/docs/technical-preferences.md` populated | Yes — Forbidden Patterns, Allowed Libraries, ADR Log all correctly point at the registry (session 27 fix, re-verified) |
| `design/art/art-bible.md` Sections 1–4 | Present, real content |
| ≥3 Accepted ADRs, Foundation layer | 12/12 ADRs exist, all Accepted |
| `docs/engine-reference/godot/` | VERSION.md, breaking-changes.md, deprecated-apis.md, current-best-practices.md, modules/ |
| `tests/unit/` + `tests/integration/` | Both populated — `tests/integration/main/kill_area_death_test.gd` is the first integration test file (new this session) |
| CI workflow | `.github/workflows/tests.yml` exists |
| Example test file functional | Confirmed via live headless run |
| `docs/architecture/architecture.md` | Exists, 47.9KB |
| `docs/architecture/requirements-traceability.md` | Exists, 57 TR rows |
| `/architecture-review` report | 5 reports exist, most recent `architecture-review-2026-08-16.md` |
| `design/accessibility-requirements.md` | Tier committed (Standard, reduced motion elevated) |
| `design/ux/interaction-patterns.md` | Exists, 19.9KB |

## Quality Checks

- [x] Circular ADR dependency check — clean DAG, no cycles (0001/0002/0004/0006 roots, no back-edges)
- [x] Foundation-layer traceability gaps — zero
- [x] Deprecated API scan — clean
- [x] Test suite, fresh headless run — 54/54 pass, 0 failures, 0 orphans, exit 0
- [ ] ADR Engine Compatibility stamps — **10/12 read "4.7.1", not 12/12 as session 27 claimed.** `adr-0003` and `adr-0004` still read "Godot 4.7 (project runs 4.7.1-stable)"
- [ ] ADR-0003's required-consumer table — **stale.** The `hud` row still reads "ADR-0010 — unwritten / No," even though ADR-0010 was Accepted 2026-08-16 and its own text states acceptance should flip that row to Required. Left as-is, `V-WIRING` could pass green while no level wires a HUD.

## Director Panel Assessment

**Creative Director: CONCERNS**
- The props-as-flip-proof footnote fix (session 27/28) landed at `game-concept.md:123-126` but the same superseded framing survives at `game-concept.md:87` (MDA Sensation row), `game-concept.md:168-171` (30-second core loop description), and `physics-props.md:33` (Player Fantasy section).
- The Unique Hook (geometry-driven oxygen budget) is not testable with a 1-level MVP — a playtester has no second geometry to contrast against.
- **Confirmed by direct re-read**: the Scope Tiers table (`game-concept.md:372-378`) implies no HUD until Vertical Slice ("Core + props + HUD"), but the prose immediately below (`:387-389`) states a minimal oxygen readout is required at MVP per `suit-oxygen.md` R7's own edge-case table. This touches Pillar 2's fairness clause ("the player must never be surprised by the tank running out").
- `game-concept.md:41`'s "Small (1–3 months, solo)" summary line is now stale against the re-estimate two sections later.

**Technical Director: CONCERNS**
- **Confirmed by direct re-read**: `tests/integration/main/kill_area_death_test.gd:37` calls `runner.simulate_frames(10)` without `await`. `simulate_frames` is a coroutine; unawaited, it returns immediately and zero frames run. The assertion two lines later checks `player_died == false` against a value set to `false` two lines above it — a tautology. It passes today and will keep passing after ADR-0004 step 3 fixes the underlying bug, providing false assurance rather than real coverage.
- ADR-0003's stale HUD consumer row (see Quality Checks above).
- Engine Compatibility stamps are 10/12, not 12/12 as claimed.
- Confirmed non-blocking: ADR-0010's per-frame `get_global_transform_with_canvas()` projection still has no per-system performance budget entry — one call per tracked widget per frame is not a plausible threat at this scale.

**Producer: CONCERNS**
- The new migration safety net covers ADR-0004's cheapest step (3, `level_05` only) but not its riskiest (step 4 — deleting `PlayerArea2D` from `player.tscn`, the one scene instanced by all 8 levels) or `level_06` (identical unwired kill-plane, zero coverage, despite step 3 explicitly requiring a playtest of both levels).
- Narrowing the settings-system GDD scope (session 28) orphaned ADR-0008's explicit delegation of `drain_rate` slider ownership to "a future settings-screen ADR" — that delegation now has no named owner in the settings-system entry.
- The accessibility tier's "reduced motion elevated from Comprehensive" commitment still has no path forward — blocked on the unowned `TR-gravity-010`.
- ADR-0001 Changeset A (the gravity-authority migration) is the largest unsplittable task in the plan and received no characterization tests this session — larger regression exposure than ADR-0004, and the one item that got no safety net.

**Art Director: READY**
- Footnote change correctly cites art-bible §1.3 in both directions; no drift introduced.
- Art bible Sections 5–7/9 remaining `[To be designed]` is acceptable for this gate (only §1–4 required).

## Blockers

None. No director returned NOT READY, so per the escalation rule (strictest verdict wins, and CONCERNS is the ceiling three directors independently reached) the gate floor is CONCERNS, not FAIL.

Two items are urgent enough to fix before anyone relies on them, even though they don't block the gate:
1. Missing `await` in `kill_area_death_test.gd:37` — the migration safety net currently provides no real protection.
2. Scope Tiers table / prose contradiction on whether MVP ships a HUD.

## Recommendations (non-blocking, fold into next epic's definition-of-done)

- Propagate the props-as-flip-proof footnote to `game-concept.md:87`, `:168-171`, and `physics-props.md:33`.
- Update ADR-0003's HUD consumer row to Required.
- Stamp `adr-0003` and `adr-0004` to "4.7.1".
- Point the settings-system GDD entry back at ADR-0008's `drain_rate` delegation so it isn't lost.
- Extend the migration safety net to `level_06` and to ADR-0004 step 4 before that step is executed.
- Consider a 2-level MVP if the Unique Hook needs to be player-legible before Alpha.

## Verdict: CONCERNS

## Chain-of-Verification

5 questions checked, 2 via direct tool re-read (`game-concept.md:372-399` for the HUD-tier
contradiction, `kill_area_death_test.gd:37` for the missing `await`) — both independently
confirmed, not taken on the sub-agent reports alone. All four session-28 fixes are genuinely
resolved; the concerns surfaced by this run are a different, smaller-scope set than the ones
that produced the prior CONCERNS verdict. Nothing found compounds into a phase blocker.
**Chain-of-Verification: 5 questions checked — verdict unchanged (CONCERNS).**

---

`production/stage.txt` left at `Concept` — unchanged, since this is not a PASS verdict.
