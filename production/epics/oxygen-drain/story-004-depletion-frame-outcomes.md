# Story 004: The depletion-frame outcomes — `suit-oxygen` AC8 and `watering-system` AC13

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (3-4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §5 · §8 AC8 ·
`design/gdd/watering-system.md` §5 · §8 AC13 · `design/gdd/level-flow.md` R2, R9
**Requirement**: `TR-oxygen-003` *(completes it)*, `TR-oxygen-010`,
`TR-watering-012` *(the depletion-frame halves only — the latch halves closed in
`level-state` story 005)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **This story exists because `level-state` story 005 wrote the handover out
> explicitly.** That story's acceptance criteria carry a section headed
> *"Explicitly NOT closed by this story — do not tick these anywhere"*, naming
> `watering-system.md` **AC13** and `suit-oxygen.md` **AC8**, and stating they
> "close in the `oxygen-drain` epic, against the latch this story provides."
> This is that story. It is the only place either AC may be ticked.

**ADR Governing Implementation**: ADR-0005: Frame ordering and the
`level_complete` guard (D5.2, D5.3, D5.4, D5.6) *(primary — the asymmetry is
entirely a frame-ordering property)* · ADR-0008 Decision §1 *(secondary — it
supplies the arm-and-defer behaviour both ACs depend on)* · ADR-0002 *(secondary
— it corrected `architecture.md` on who owns the kill decision)*

**ADR Decision Summary**: Two opposite outcomes fall out of the same physics
frame, and the `level_complete` latch is what lets them coexist. Entering the
airlock at zero oxygen **completes the level**; landing the final pour at zero
oxygen **kills**. The difference is that unlocking the airlock and entering it are
different events — R6 unlocks the door, it does not teleport the player to it.
Completion sets the latch at priority `0`; `OxygenDrain` reads the latch at `+100`,
after, and freezes.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Facts that bind an integration test here:

- **`-a "res://path/test.gd:test_name"` is NOT a supported selector.** It exits
  `0` having run nothing, which looks exactly like a pass. Isolate with a scratch
  suite under `tests/scratch/` and delete it afterwards.
- **The runner command changed on 2026-08-24 and must include
  `-a res://tests/integration`.** Unit-only was the documented command until then
  and silently excluded 8 integration cases, **including BUG-0001's regression
  guard**. Use `-c` as well, or a red run reports one failure and hides the rest.
  See `tests/README.md`.
- **A freed `Object` compares `== null` as TRUE and `as` on one RAISES.** Both
  outcomes here tear down or transition the level while references are live.
- `reload_current_scene` logging `Parameter "current_scene" is null` in a headless
  test is not a failure.

**Control Manifest Rules (this layer)**:
- Required: "`level_complete` is a write-once latch, owned by `LevelState`,
  written ONLY via `mark_complete()` from `LevelRoot._on_player_reached_goal()`.
  No path anywhere may set it back to `false`." — ADR-0005 (D5.3)
- Required: "`level_complete` freezes `OxygenDrain` entirely — no `drain()` call,
  not only no kill." — ADR-0005 (D5.6)
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path must
  check and set `_transition_pending`." — ADR-0005 (D5.4, A5-02)
- Required: "`OxygenDrain` arms on depletion and evaluates the kill at the TOP of
  its NEXT physics callback." — ADR-0005 (D5.2)
- Forbidden: "Never restart the level in the same `_physics_process` callback
  that observed `remaining <= 0`." — ADR-0005 (`same_frame_oxygen_kill`)
- Forbidden: "Never connect `OxygenState.depleted` directly to
  `LevelRoot.restart_level()`" — breaks `suit-oxygen.md` AC8. — ADR-0002
  (`depleted_wired_to_restart`)
- Forbidden: "`Plant` (or any single objective) must never write level-wide state
  or decide the level is complete." — ADR-0002 (`plant_decides_level_outcome`)

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md` and `design/gdd/watering-system.md`, scoped to
this story:*

- [ ] **`suit-oxygen.md` AC8** — entering the airlock **on the frame oxygen
      reaches zero completes the level**. A frame-perfect entry at zero counts as
      a win, not a death
- [ ] **`watering-system.md` AC13** — completing the **final pour** on the frame
      oxygen reaches zero results in **death, not level completion**
- [ ] Both outcomes are produced by the **same** unmodified mechanism from
      stories 002 and 003. No special case, no new branch, no ordering exception
      is added for either
- [ ] The asymmetry holds **in both signal-delivery orders** within the tick —
      the outcome does not depend on which area handler happens to run first
- [ ] Neither AC is asserted by connection order. Both are asserted on the
      observable outcome

---

## Implementation Notes

*Derived from ADR-0005 D5.3's frame walkthrough:*

- **This story should write very little production code, and that is the point.**
  If AC8 and AC13 do not already fall out of stories 002, 003 and `level-state`
  005 unchanged, the mechanism is wrong and the fix belongs in those stories —
  not in a special case added here. The deliverable is the integration test that
  proves the asymmetry, plus whatever wiring gap it exposes.
- **Why the two outcomes differ, in one line each.** AC8: the goal handler runs
  at priority `0` and sets the latch; `OxygenDrain` runs at `+100`, reads the
  latch, and freezes before it can evaluate its armed kill. AC13: the final pour
  unlocks the airlock but does not enter it, so nothing sets the latch, and the
  armed kill fires on the next frame exactly as it would with no pour at all.
- **`watering-system.md` §5 states the asymmetry in prose**: "R6 unlocks the
  airlock; it does not teleport the player to it — the door must be physically
  reached." Read it before writing the test; it is the design intent the test
  encodes.
- **Do not test AC8 by controlling connection order.** ADR-0005 D5.4 is explicit
  that inter-area signal delivery order within one physics tick is undetermined —
  that undecidability is *why* `_transition_pending` exists alongside the latch. A
  test that passes only under one delivery order is asserting the bug, not the
  guarantee. Drive both orders, or drive the outcome through the single ordered
  handler `level-state` story 005 established.
- **`_transition_pending` must exist on `LevelRoot` for the both-orders case to
  hold.** It is owed by ADR-0005 migration step 3 (`main.gd:59`) and no story in
  `level-state` or this epic claims it — stories 005 and 006 there both decline it
  by name. **If it is still absent, this story is where it becomes observable.**
  Raise it as a gap; do not add the field from this story, because a second
  author writing it in a second place is the exact failure the single-chokepoint
  decision exists to prevent.
- **AC13's "final pour" needs the watering system.** `PlayerWateringComponent`
  exists in `src/`, but the `LevelState` bucket/plant accounting it must drive
  comes from `level-state` stories 001 and 004. If the Feature watering epic has
  not landed the pour-completion path, scope the AC13 half to the mechanism —
  arm at zero, latch never set, kill fires — and record the end-to-end pour run as
  owed. Say so in the Implementation Record rather than ticking AC13 quietly.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **Stories 002 and 003**: the drain, the composition, and the kill mechanism.
  This story asserts them; it does not reimplement them.
- **`level-state` story 005**: the write-once latch, `mark_complete()`, and
  `LevelRoot._on_player_reached_goal()` as its sole caller.
- **`restart_level()`'s `_transition_pending` early return** — ADR-0005 migration
  step 3, owned by the level-migration work. Surface it; do not add it.
- **The pour mechanic itself** — `PlayerWateringComponent.update_pour()`,
  ADR-0009. This story consumes pour completion as an event.
- **What happens after the level completes** — `level-flow.md` R10 is an open
  design question BLOCKED on the owner, and belongs to the `level-outcomes` epic.
  This story stops at "the level completed".
- **The HUD holding its final reading through the transition.** D5.6's freeze is
  asserted here on `remaining`; what the HUD *displays* is the Presentation HUD
  epic (ADR-0010).

---

## QA Test Cases

*Story type: **Integration** — automated test specs.*

- **AC-1 — airlock entry on the depletion frame completes the level (AC8)**
  - Given: a synthetic level with a `Goal`, an unlocked airlock, and an
    `OxygenState` one step from zero
  - When: the player enters the airlock on the same physics frame that brings
    `remaining` to `0.0`
  - Then: the level completes, `level_complete` is true, and **no restart fires**
    — on that frame or any later one
  - Edge cases: run the arming frame and at least two frames past it. The kill is
    armed on the depletion frame and would fire on the *next* one, so a test that
    stops at the boundary frame passes against a broken implementation.

- **AC-2 — the final pour on the depletion frame kills (AC13)**
  - Given: the same level with one plant left unwatered
  - When: the final pour completes on the same physics frame that brings
    `remaining` to `0.0`, and the player does **not** reach the airlock
  - Then: `level_complete` stays false, and the restart fires on the following
    frame
  - Edge cases: assert the airlock is *unlocked* in this case — that is what makes
    AC13 a genuine near-miss rather than an ordinary death. If the pour path is
    not yet available, drive the state directly and record the end-to-end run as
    owed.

- **AC-3 — the outcome is delivery-order independent**
  - Given: the AC8 scenario
  - When: it is run twice, with the airlock area handler and the hazard/other
    area handler delivered in each order within the tick
  - Then: the level completes in both runs
  - Edge cases: **this is the test `_transition_pending` exists for.** If it
    cannot be made to hold in both orders, that is the gap to report, not a test
    to relax. Do not pin the delivery order to make the test green.

- **AC-4 — no special case was added**
  - Given: `oxygen_drain.gd` and `level_root`'s handler after this story
  - When: diffed against their state at the end of story 003 and `level-state`
    story 005
  - Then: no new branch, flag or ordering exception mentions the airlock, the
    pour, or a depletion-frame case by name
  - Edge cases: structural. Both ACs are supposed to be emergent; a named special
    case makes them pass while proving the frame contract does not actually work.

- **AC-5 — the freeze is total, through the transition**
  - Given: the AC8 scenario, immediately after completion
  - When: several further physics frames are stepped
  - Then: `remaining` never changes again for that level instance
  - Edge cases: D5.6 is "no `drain()` call", not "no kill". Assert on `remaining`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/oxygen/depletion_frame_outcomes_test.gd` — must exist and
  pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (the kill mechanism) · Story 002 · `level-state`
  stories 004 and 005 (`LevelRoot`, injection, and the latch). AC13's end-to-end
  half additionally depends on the Feature watering epic's pour-completion path —
  see Implementation Notes.
- **Unlocks**: None in this epic. It closes `TR-oxygen-003` and the
  depletion-frame halves that `level-state` story 005 deferred.
