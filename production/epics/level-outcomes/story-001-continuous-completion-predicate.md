# Story 001: The continuous completion predicate — `Goal` stops gating on the signal edge

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R1 · §4 *Completion predicate* · §5 ·
§8 AC1, AC2, AC8
**Requirement**: `TR-flow-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **The epic file is stale on traceability and this story is not.**
> `production/epics/level-outcomes/EPIC.md` states that `level-flow.md` has "no TR
> IDs" and traces by rule anchor R1–R10. The ARCH-1 sweep of **2026-08-24**
> allocated `TR-flow-001`–`010`, one per rule. Trace to the TR ID. The rule anchors
> are kept alongside it because the GDD prose is still the readable source.

**ADR Governing Implementation**: ADR-0005: Frame ordering and the `level_complete`
guard *(primary — D5.2's asymmetry is what this predicate must not break)* ·
ADR-0002 *(secondary — `plant_decides_level_outcome`: `Goal` writes no level state)*

**ADR Decision Summary**: `Goal` continues to emit `player_reached_goal` and writes
no level state; `LevelRoot` is the sole writer of the latch (D5.3, landed by
`level-state` story 005). What changes here is **when** `Goal` emits. The GDD's
completion predicate is evaluated **every physics frame**, never on a signal edge:

```
level_complete ← level_complete ∨ (goal_unlocked ∧ player_overlaps_airlock)
```

`player_overlaps_airlock` is continuous state — `body_entered` sets it,
`body_exited` clears it — and is **not** read from the entry signal itself.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. `Area2D.body_entered` / `body_exited` are far
older than the training cutoff. Facts that bind this story:

- **This is a silent-failure trap and it has already shipped once.** The vertical
  slice's `goal.gd` checks the unlock only on the `body_entered` edge. A player
  already standing in the airlock when the final pour lands never wins, and the
  broken and working cases are indistinguishable to the player. It cost a live
  debugging session (`prototypes/gravity-gardener-vertical-slice/REPORT.md`,
  2026-08-17).
- **Inter-area `body_entered` delivery order within one physics tick is genuinely
  undetermined** in the engine — `process_physics_priority` orders
  `_physics_process` dispatch, not signal-callback dispatch during
  `flush_queries()` (A5-02). **Do not reintroduce an ordering assumption between
  the airlock area and any hazard or plant area.** Moving the decision off the edge
  and onto a per-frame read is part of how that dependency is removed.
- **`Goal` takes no row in the frame-ordering table.** D5.1 states this explicitly
  and calls it the correction to `architecture.md`'s `+50` row. Do **not** assign
  `Goal` a `process_physics_priority`.

**Control Manifest Rules (this layer)**:
- Required: "**Zone-entry triggers evaluate their condition every frame, never on
  the signal edge.** Track overlap as continuous state — `body_entered` sets it,
  `body_exited` clears it — and test the trigger condition in `_physics_process`.
  A trigger gated on the raw `body_entered` edge silently never fires when the body
  is already inside the area at the moment the condition becomes true." — source:
  `level-flow.md` §4, vertical-slice `REPORT.md` 2026-08-17
- Required: "`level_complete` is a write-once latch, owned by `LevelState`, written
  ONLY via `mark_complete()` from `LevelRoot._on_player_reached_goal()`." —
  ADR-0005 (D5.3)
- Forbidden: "Never write `level_complete` from any node other than
  `LevelRoot._on_player_reached_goal()`." — ADR-0005
  (`level_complete_written_outside_level_root`)
- Forbidden: "Never accumulate or evaluate a rule-bearing quantity in `_process`." —
  ADR-0005 (`gameplay_timing_in_idle_process`)

---

## Acceptance Criteria

*From `design/gdd/level-flow.md` §8, scoped to this story:*

- [ ] **AC1** — Entering the airlock with `goal_unlocked` true causes `Goal` to emit
      `player_reached_goal` on that physics frame
- [ ] **AC2** — A player **already overlapping** the airlock when the final pour
      completes triggers the emit on the frame `goal_unlocked` becomes true, with no
      exit and re-entry
- [ ] **AC8** — Entering the airlock with `goal_unlocked` false produces no emit, no
      state change, and no on-screen element. No refusal prompt is shown — the
      airlock's own locked appearance is the message (`hud.md` #11, Hidden-diegetic)
- [ ] The player leaving the airlock before the final pour and returning behaves
      normally: `player_overlaps_airlock` clears and re-sets, and the predicate
      re-evaluates every frame either way
- [ ] `Goal` emits `player_reached_goal` **at most once** per level instance
- [ ] `Goal` writes no level state and assigns no `process_physics_priority`
- [ ] The predicate is evaluated in `_physics_process`, not `_process`

*Explicitly NOT closed by this story — do not tick these anywhere:*

- `level-flow.md` **AC5** (zero oxygen on the entry frame yields completion) needs
  `OxygenDrain`'s arm-and-defer. It closes in `oxygen-drain` story 004.
- **AC3/AC4** (the latch's write-once property and its sole writer) closed in
  `level-state` story 005.

---

## Implementation Notes

*Derived from `level-flow.md` §4 and ADR-0005 D5.1/D5.3:*

- **Two changes to `src/scripts/goal.gd`, and no more.** Add a
  `player_overlaps_airlock` bool set by `_on_body_entered` and cleared by a new
  `_on_body_exited`; move the unlock test out of the entry handler and into a
  `_physics_process` that evaluates the conjunction. The entry handler stops
  deciding anything.
- **Keep the emit-once property in `Goal`, not only in the latch.** A local
  `_emitted` bool is the right shape. `LevelState.mark_complete()` is idempotent
  and `_transition_pending` (story 002) is a second backstop, but a signal that
  fires every frame for the duration of the hold is noise that later readers will
  have to reason about.
- **The unlock read stays where it is for now.** `goal.gd` currently reads
  `GameManager.goal_unlocked`. Migrating that read to the injected `LevelState` is
  ADR-0002's work and belongs to `level-state` story 004, not here. Change **when**
  the predicate is evaluated, not **where** the flag lives.
- **`goal.gd`'s existing `_process` unlock animation legitimately stays in
  `_process`.** It is cosmetic — it reads state and plays a sprite. The manifest
  line draws the boundary at "whether a rule reads the value", and the animation
  reads nothing a rule depends on.
- **Do not add a refusal prompt for a locked-airlock entry.** `level-flow.md` §5
  states this as a deliberate decision: E4 exists for capped plants, not for the
  airlock.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 002**: `_transition_pending` and the guarded chokepoint. This story emits;
  story 002 makes the two endings mutually exclusive.
- **Story 004**: the completion sequence and the hold that follows the emit.
- **`level-state` story 005**: the latch, `mark_complete()`, and the single ordered
  `_on_player_reached_goal()` handler that replaces `main.gd:16-18`'s two
  connections. This story assumes that handler exists.
- **`oxygen-drain` story 004**: the depletion-frame outcomes, including AC5.
- **The airlock's visual unlock state** — presentation, not covered by any story in
  this epic.

---

## QA Test Cases

*Story type: **Logic** — automated test specs. AC-2 is the one that matters: it is
the exact case the shipped build gets wrong, and an edge-gated implementation
passes AC-1 and AC-3 while failing only this.*

- **AC-1**: Entering the airlock with `goal_unlocked` true emits on that frame
  - Given: a `Goal` with `player_overlaps_airlock` false and `goal_unlocked` true
  - When: a `Player` body enters the airlock area and one physics frame advances
  - Then: `player_reached_goal` has been emitted exactly once
  - Edge cases: a non-`Player` body entering emits nothing; a second physics frame
    with the player still inside emits nothing further

- **AC-2**: A player already inside wins when the unlock arrives *(the regression guard)*
  - Given: a `Goal` with `player_overlaps_airlock` already true and `goal_unlocked`
    **false**, with no emit yet
  - When: `goal_unlocked` flips to true with **no** further `body_entered` signal,
    and one physics frame advances
  - Then: `player_reached_goal` has been emitted exactly once
  - Edge cases: assert the emit happens on the **first** frame after the flip, not a
    later one; assert no `body_entered` was delivered during the test

- **AC-3**: A locked airlock is inert
  - Given: `goal_unlocked` false
  - When: the player enters, remains for ten physics frames, and exits
  - Then: no emit, and no property of `Goal` outside `player_overlaps_airlock`
    changed
  - Edge cases: assert nothing is displayed — no prompt node is instanced

- **AC-4**: Exit clears the overlap and re-entry restores it
  - Given: the player inside a locked airlock
  - When: the player exits, `goal_unlocked` flips to true, then the player re-enters
  - Then: `player_overlaps_airlock` reads false after the exit, and one emit follows
    the re-entry
  - Edge cases: flipping `goal_unlocked` true **while the player is outside** must
    emit nothing until re-entry

- **AC-5**: Structural — `Goal` stays out of the frame-ordering table
  - Given: the `Goal` scene and script
  - When: grepped for `process_physics_priority` and for any write to
    `level_complete` / `mark_complete`
  - Then: no match in either grep
  - Edge cases: also assert `goal.gd` contains no `_process`-resident evaluation of
    the completion conjunction

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/flow/completion_predicate_test.gd` — must exist
and pass.

> **Runner note.** The command changed on **2026-08-24** and must include
> `-a res://tests/integration` alongside the unit path, or integration cases are
> silently excluded. Use `-c` as well, or a red run reports one failure and hides
> the rest. See `tests/README.md`. `-a "res://path/test.gd:test_name"` is **not** a
> supported selector — it exits `0` having run nothing, which looks exactly like a
> pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `level-state` story 005 (the ordered `_on_player_reached_goal()`
  handler and the latch this emit feeds). Implementable ahead of it, but the
  integration is not observable until that handler exists.
- Unlocks: Story 002, Story 004
