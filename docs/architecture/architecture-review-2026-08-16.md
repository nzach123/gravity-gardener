# Architecture Review Report

Date: 2026-08-16
Engine: Godot 4.7.1 (GL Compatibility, 2D)
GDDs Reviewed: 4 (`gravity.md`, `watering-system.md`, `suit-oxygen.md`, `physics-props.md`)
ADRs Reviewed: 12 (ADR-0001–0012, all `Accepted`)

**Argument**: `full` (invoked with the note "to resync the stale docs")

---

## Trigger and Scope

This run followed today's `production/gate-checks/gate-check-2026-08-16-pre-production.md`
(verdict FAIL), which named `/architecture-review` full pass as the fix for two
of its three blockers: `architecture.md`'s self-contradiction (header says
"12 of 12 Accepted," body still said "7 ADRs" / "28 of 52") and
`requirements-traceability.md` being a stale session-18 snapshot. This review
also independently found a third stale document —
`docs/registry/architecture.yaml` carrying 13 entries still marked
`status: proposed` for two ADRs (ADR-0008, ADR-0009) that have been Accepted
since session 19. That gap was already self-diagnosed in
`production/session-state/active.md`'s session-23 entry but never closed.

`docs/architecture/tr-registry.yaml` — the actual source of truth for
requirement coverage — was **already fully current** (49/52 covered, 12/12
ADRs Accepted, correctly distinguishing `TR-watering-002`'s unowned-by-design
status). No changes were needed there. The staleness was entirely in the three
documents that are supposed to be generated or kept in sync from it.

---

### Traceability Summary

Total requirements: 52
✅ Covered: 49 (94%)
❌ Gap (deliberately unowned): 1 — `TR-watering-002`
◻ Parked / Implemented: 2 — `TR-gravity-008` (parked), `TR-gravity-010` (implemented)

### Coverage Gaps

**`TR-watering-002`** — carry scales `max_speed` only (`watering-system.md` R2).
Not an oversight: ADR-0007 and ADR-0009 both explicitly decline it in their own
GDD Requirements Addressed tables. Closing it requires a new decision that
reopens ADR-0007's frozen `Player._physics_process` D7.3 signature, most likely
adding a carry-state parameter to `PlayerMovementComponent.apply()`.

- Suggested action: `/architecture-decision watering carry-speed penalty` (or
  fold into whichever ADR ends up reopening D7.3), before the watering epic is
  scheduled — both the Technical Director and Producer panels flagged this in
  today's gate check.
- Domain: Core / Physics
- Engine Risk: LOW (no new engine surface — reuses the existing `max_speed`
  scaling mechanism `PlayerMovementComponent` already owns)

### Cross-ADR Conflicts

No new conflicts. Every conflict recorded by earlier reviews (C1–C8, and the
session-18 traceability snapshot's "new findings" F1/F2) is closed by a later
ADR's text or a registry correction, with one exception carried forward as an
**open, unowned item** rather than a new finding:

**Camera's first-broadcast gap** (originally session-18 finding, old F2 in the
stale traceability doc): if the camera's `gravity_changed` subscription wires
after `GravityAuthority.reset_to()`'s first broadcast (ADR-0003 D3.1's step
order puts wiring at step (f), after `reset_to()` at step (e)), the camera
renders unrotated on level load until the first subsequent zone change.
ADR-0011 named it explicitly; ADR-0010 explicitly declined it ("no planned ADR
remains to absorb it, so closing it now requires a new ADR"). Still unowned.

### ADR Dependency Order (topologically sorted)

All 12 ADRs are Accepted with no cycles and no unresolved dependencies.
Recorded for implementation-sequencing reference, not as a blocker:

```
Foundation (no dependencies):
  ADR-0001, ADR-0002, ADR-0004, ADR-0006

Depends on Foundation:
  ADR-0003 (requires 0001, 0002)
  ADR-0005 (requires 0002)
  ADR-0011 (requires 0001, 0004, 0006)

Depends on the above:
  ADR-0007 (requires 0001, 0005)

Feature layer:
  ADR-0008 (requires 0002, 0005, 0006)
  ADR-0009 (requires 0002, 0004, 0005, 0007)

Presentation layer:
  ADR-0010 (requires 0002, 0003, 0005, 0006, 0008)
  ADR-0012 (requires 0006, 0009)
```

### GDD Revision Flags

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|---|---|---|---|
| `suit-oxygen.md` R3/§5 | Oxygen death is **"immediate"** | ADR-0005 D5.2 / ADR-0008 §1 deliberately defer the kill one physics frame (armed-death mechanism, reconciles `suit-oxygen.md` AC8 with `watering-system.md` AC13) | Revise GDD — flagged since 2026-08-15, still not applied |
| `suit-oxygen.md` §2 vs §4 | §2 wants ~30-seconds-out awareness | §4's caution threshold fires at 24 s for a 48 s level (after the 30 s mark) | Internal GDD tension, not architecture-caused; `hud.md` resolves the practical UX intent but the GDD's own numbers remain unreconciled |

Both flags are carried forward from prior reviews, not new. Neither was
actioned against `systems-index.md` in this pass — see Handoff below for the
proposed next step.

### Engine Compatibility Issues

**Engine**: Godot 4.7.1 · **ADRs with Engine Compatibility section**: 12 / 12

No deprecated API usage found (all 12 ADRs cross-checked against
`deprecated-apis.md`; the one `RichTextLabel` hit in ADR-0010 is a correct
citation confirming the API is *avoided*, not a violation). No stale version
references — all 12 ADRs stamp "Godot 4.7," consistent with the 4.7.1 pin
(imprecise but not contradictory). No post-cutoff API conflicts between ADRs.

#### Engine Specialist Findings (godot-specialist, second-opinion pass)

Four precision refinements to already-open "Verification Required" items in
individual ADRs — none blocking, none contradicting the ADRs' own conclusions:

- **ADR-0006 T4** (`@export_range` does not clamp a hand-edited `.tres`) —
  confirmed by the property system's actual structure (`PropertyHint` is pure
  `EditorInspector` metadata; `ResourceFormatLoaderText` calls the setter
  directly with no hint-based validation), not merely by documentation
  wording. Can be downgraded from "open" to "settled" — the planned empirical
  test (Migration Plan step 5) is no longer load-bearing, just confirmatory.
- **ADR-0010 V-E2** (`get_global_transform_with_canvas()` under rotation +
  zoom) — right API confirmed, but `Camera2D.process_callback` defaults to
  physics-timed while the HUD reads position in idle `_process`. That is a
  distinct claim from V-E9 (which was established for `OxygenState`, not for
  `canvas_transform`). Recommend an explicit note in V1/V2 that idle-frame
  reads of camera-driven canvas transform also see post-physics state.
- **ADR-0011 V-E2** (synchronous `area_set_param` in `LevelRoot._ready()`
  lands before the first physics step) — reasoning is sound, but the ADR
  doesn't state whether `physics/2d/run_on_separate_thread` is enabled for
  this project. If off (Godot's default), the write is trivially synchronous;
  if on, correctness rests on the scene-tree/physics-thread sync barrier
  instead — same conclusion, different argument. Worth stating the project's
  actual setting explicitly.
- **ADR-0012 `top_level` reassignment** — confirmed idiom, no code change
  needed. Minor framing correction: since `top_level = true` and the
  `global_position` reassignment run synchronously in the same function with
  no `await` between them, no frame is ever rendered in the intermediate
  state — the reassignment prevents a *permanent* offset after that point, not
  a transient one-frame jump. Simplifies what the validation test needs to
  assert (post-state equality, not intra-statement timing).

No Godot 4-specific anti-patterns found beyond what the ADRs already
self-flag. Node-type choices are idiomatic throughout (`RigidBody2D` for
props, `Area2D` detectors at layer 0, `CanvasLayer` siblings for the HUD, a
scene-wrapped autoload for `GravityAuthority` specifically to preserve
`@export` inspector surface). `set_deferred()` vs. synchronous writes for
`Area2D.monitoring`/`monitorable` is correctly reasoned against
`flush_queries()` timing in both ADR-0009 and ADR-0012. No divergence found
between ADR-0012's Tween/Animation claims and current Tween API behavior,
despite that domain's HIGH knowledge-risk rating (no `modules/animation.md`
reference exists) — the rating is appropriately conservative, not wrong.

### Architecture Document Coverage

All four GDD systems (Gravity, Watering, Suit Oxygen, Physics Props) appear in
`architecture.md`'s System Layer Map and Module Ownership tables. All
cross-system signals named in the GDDs (`gravity_changed`, `pour_completed`,
`goal_unlocked`, `threshold_changed`, `depleted`, `inc_hazard_dmg`,
`player_reached_goal`) appear in the Event/signal path table. No orphaned
architecture — every module in the layer map traces to a GDD system or an
explicitly-scoped infrastructure concern (state ownership, validation,
tuning, collision layers).

---

### Verdict: **PASS**

All Foundation and Core layer requirements are covered by an Accepted ADR. No
blocking cross-ADR conflicts exist. Engine assumptions are consistent across
all 12 ADRs and were independently re-verified by a second engine-specialist
pass with no contradicting findings. The one uncovered requirement
(`TR-watering-002`) and the one open cross-cutting gap (camera first-broadcast)
are both deliberate, named, and owned-by-decision rather than overlooked.

### Blocking Issues

None.

### Required ADRs

None. All 12 planned ADRs exist and are Accepted. If `TR-watering-002` is
prioritized, it needs a 13th ADR (or an amendment reopening ADR-0007's D7.3) —
not currently required, since the project has deliberately deferred it.

---

## Stale Documents Found and Resynced This Pass

| Document | Was | Now |
|---|---|---|
| `docs/architecture/architecture.md` §ADR Audit / §Traceability coverage | "7 ADRs (ADR-0001–0007)... 28/52 covered, 22 gaps" | "12 ADRs, all Accepted... 49/52 covered, 1 unowned gap, 2 parked/implemented" |
| `docs/registry/architecture.yaml` | 13 entries (5 tied to ADR-0008, 8 tied to ADR-0009) reading `status: proposed` | All 13 corrected in place to `status: accepted`, matching their owning ADRs' actual status |
| `docs/architecture/requirements-traceability.md` | Full session-18 snapshot (28/52, 7 ADRs, two open "new findings" since resolved) | Fully regenerated from the current `tr-registry.yaml`; carries forward only genuinely still-open items |

`docs/architecture/tr-registry.yaml` required no changes — it was already
current and was the source used to resync the three documents above.

---

## Handoff

**Immediate actions** (highest-impact first):

1. Decide an owner for `TR-watering-002` (carry-speed penalty) before the
   watering epic is scheduled — flagged independently by both this review and
   today's gate check's Technical Director / Producer panels.
2. Decide an owner for the camera first-broadcast gap — currently declined by
   both ADR-0010 and ADR-0011; needs a 13th ADR or a camera-specific one if
   pursued.
3. Apply the `suit-oxygen.md` R3/§5 GDD revision flag ("immediate" → "deferred
   one physics frame by design") — this has been open since 2026-08-15.

**Pre-gate checklist** (per skill protocol):

- `tests/unit/` and `tests/integration/` — ✅ both exist (`tests/integration/`
  holds only a placeholder — noted by today's gate check as a real gap for the
  brownfield migration, not a directory-existence problem)
- `.github/workflows/tests.yml` — ✅ exists
- `design/accessibility-requirements.md` — ✅ exists
- `design/ux/interaction-patterns.md` — ✅ exists

All four items are ✅. `/gate-check pre-production` is available, though today's
run already found it at **FAIL** for reasons entirely outside this review's
scope (missing art bible, unratified `game-concept.md`) — the two blockers
that *were* in scope (`architecture.md` and `requirements-traceability.md`
staleness) are now resolved by this pass.

**Rerun trigger**: re-run `/architecture-review` after any future ADR is
written or Accepted, to verify these three documents stay in sync.
