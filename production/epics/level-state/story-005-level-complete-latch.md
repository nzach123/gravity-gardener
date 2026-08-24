# Story 005: The `level_complete` write-once latch and the ordered goal handler

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/watering-system.md` §5 · §8 AC13 ·
`design/gdd/suit-oxygen.md` §5 · §8 AC8 · `design/gdd/level-flow.md` R2, R9
**Requirement**: `TR-watering-012`, `TR-oxygen-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **Both TRs close only in part here, and that is stated in the acceptance
> criteria rather than left for `/story-done` to discover.** `watering-system.md`
> AC13 and `suit-oxygen.md` AC8 are the depletion-frame outcomes. Both need
> `OxygenDrain`'s arm-and-defer behaviour (ADR-0005 D5.2), which is ADR-0008 and
> the Core `oxygen-drain` epic. This story lands the latch half: write-once,
> `LevelRoot` as sole writer, and no path back to `false`. **Do not close either
> AC on this story.**

**ADR Governing Implementation**: ADR-0005: Frame ordering and the
`level_complete` guard (D5.3) *(primary)* · ADR-0002 *(secondary — it declares the
field and deliberately does not define when it is read or written)*

**ADR Decision Summary**: `level_complete` is a write-once latch owned by
`LevelState` and written **only** via `mark_complete()`, called from
`LevelRoot._on_player_reached_goal()`. `Goal` continues to emit
`player_reached_goal` and writes no level state, which holds
`watering-system.md` §6's "behaviour unchanged" and stays clear of ADR-0002's
`plant_decides_level_outcome` ban. The two existing signal connections are replaced
by **one ordered handler** — relying on signal connection order to get the latch set
before the scene change is exactly the implicit ordering this ADR exists to remove.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**:

- **Signal connection order is not a contract.** `main.gd:16-18` currently connects
  `player_reached_goal` to `player.win_level` and to `change_level` as two separate
  connections. Whether the latch would be set before the scene change depends on
  connection order, which is precisely what D5.3 removes.
- **Inter-area `body_entered` delivery order within one physics tick is genuinely
  undetermined** in the engine — `process_physics_priority` governs
  `_physics_process` dispatch, not signal-callback dispatch during
  `flush_queries()`. No deterministic order could be established from documentation
  or source (A5-02). **Do not reintroduce an ordering assumption between the
  airlock area and any other area.** The `_transition_pending` guard that closes
  this is D5.4 and belongs to `level-outcomes` — see Out of Scope.

**Control Manifest Rules (this layer)**:
- Required: "`level_complete` is a write-once latch, owned by `LevelState`, written
  ONLY via `mark_complete()` from `LevelRoot._on_player_reached_goal()`. No path
  anywhere may set it back to `false`." — ADR-0005 (D5.3)
- Forbidden: "Never write `level_complete` from any node other than
  `LevelRoot._on_player_reached_goal()`, and never set it back to `false`
  anywhere." — ADR-0005 (`level_complete_written_outside_level_root`)
- Forbidden: "`Plant` (or any single objective) must never write level-wide state
  or decide the level is complete." — ADR-0002 (`plant_decides_level_outcome`)
- Forbidden: "Never add `reset()` to `LevelState` or `OxygenState`." — ADR-0002
  (`level_state_reset_method`)

---

## Acceptance Criteria

*From ADR-0005 D5.3 and `design/gdd/level-flow.md` R2:*

- [ ] `LevelState.mark_complete()` sets `_level_complete` to `true` and is the
      only path that writes it
- [ ] `level_complete`, once true, is still true on every subsequent frame of that
      level instance — no method, property or path sets it back to `false`
- [ ] `LevelRoot._on_player_reached_goal()` is the only caller of
      `mark_complete()`
- [ ] The two existing `player_reached_goal` connections in `main.gd` are replaced
      by one ordered handler that sets the latch **before** anything else it does
- [ ] `Goal` emits `player_reached_goal` and writes no level state
- [ ] Calling `mark_complete()` a second time is harmless and does not re-emit
      anything

*Explicitly NOT closed by this story — do not tick these anywhere:*

- `watering-system.md` **AC13** (final pour on the depletion frame yields death)
  and `suit-oxygen.md` **AC8** (airlock entry on the depletion frame completes the
  level) both require `OxygenDrain`. They close in the `oxygen-drain` epic, against
  the latch this story provides.

---

## Implementation Notes

*Derived from ADR-0005 D5.3 and the D5.2 frame walkthrough:*

- **The latch is what makes the two opposite outcomes coexist.** The asymmetry is
  that *unlocking* the airlock and *entering* it are different events —
  `watering-system.md` §5 says so in prose ("R6 unlocks the airlock; it does not
  teleport the player to it — the door must be physically reached"), and ADR-0005
  is that sentence expressed as frame ordering. Do not try to make the latch
  itself distinguish the two cases; it does not need to.
- **One handler, in order.** Replace the two connections with a single
  `_on_player_reached_goal()` that calls `mark_complete()` first and then does
  whatever else the completion path does. The current second connection,
  `change_level`, is the level transition — **that belongs to `level-outcomes`**,
  so preserve the existing call rather than reworking it, and leave a comment
  naming the epic that owns it.
- **`mark_complete()` must be idempotent, not guarded by an error.** A second call
  is not a contract breach; it is a possibility the engine's undetermined signal
  delivery leaves open. Make it a no-op.
- **Do not add a `_transition_pending` field here.** It is real, it is required by
  D5.4, and it is `level-outcomes`' to add — because it must be checked *and set*
  by both the completion path and the restart path, and the restart path is
  explicitly outside this epic. Adding half of a two-sided guard is worse than not
  adding it, because it looks done.
- **`OxygenDrain` retains its own `level_complete` check** when it is built. That
  is deliberate redundancy, not an oversight: ADR-0002 assigns the oxygen kill
  decision to `OxygenDrain`, and the chokepoint is a backstop for every path,
  including ones added later by an author who never reads the ADR. Nothing to do
  here — recorded so this story's author does not "simplify" it away later.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **`restart_level()`'s `_transition_pending` chokepoint (D5.4)** — the
  `level-outcomes` epic. Both the guard and the requirement that both paths check
  and set it.
- **`OxygenDrain`'s arm-and-defer death evaluation (D5.2) and the completion
  freeze (D5.6)** — the `oxygen-drain` epic under ADR-0008. The latch this story
  lands is what those read.
- **The completion sequence, the hold, and pause gating** — `level-outcomes` under
  ADR-0014.
- **`plant.gd`'s `_process` → `_physics_process` migration (D5.5)** — Feature
  watering epic. Without it AC13 cannot be written as a deterministic test, which
  is another reason AC13 does not close here.
- **Story 003**: the `FramePriority` constants. This story depends on the ordering
  contract conceptually but assigns no priorities.

---

## QA Test Cases

*Story type: **Logic** — automated test specs.*

- **AC-1 — the latch is write-once**
  - Given: a `LevelState` with `level_complete` false
  - When: `mark_complete()` is called
  - Then: `level_complete` is true
  - Edge cases: call it 5 more times — still true, no error, no re-emit.

- **AC-2 — no path sets it back to `false`**
  - Given: a `LevelState` with the latch set
  - When: every public method on the type is called, and a script assigns
    `level_complete = false`
  - Then: the latch is still true, and the assignment failed at runtime
  - Edge cases: this is the whole point of the getter-only property from story 001.
    Enumerate the methods rather than testing a representative one — the failure
    mode is a method added later that clears it.

- **AC-3 — `LevelRoot` is the sole writer**
  - Given: `src/**/*.gd` after this story
  - When: searched for `mark_complete(`
  - Then: exactly one call site, in `LevelRoot._on_player_reached_goal()`
  - Edge cases: structural. The forbidden pattern
    `level_complete_written_outside_level_root` exists because a second writer is
    the natural way someone will "fix" a future ordering bug.

- **AC-4 — the handler sets the latch before it transitions**
  - Given: a synthetic level with a `Goal`
  - When: `player_reached_goal` is emitted
  - Then: the latch was true at the moment the transition call was made
  - Edge cases: **this must not be tested by connection order.** Assert the
    ordering inside the single handler, which is the guarantee D5.3 actually
    provides.

- **AC-5 — `Goal` writes no level state**
  - Given: the `Goal` script
  - When: it is read
  - Then: it holds no reference to `LevelState` and calls no method on one
  - Edge cases: `Goal` *is* bound with `LevelState` by story 004, for reading
    `goal_unlocked`. Reading is permitted; writing is not. Scope the assertion to
    writes or it will contradict story 004.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_state/level_complete_latch_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the `_level_complete` backing field and its getter) and
  Story 004 (`LevelRoot` must already own the handler it is adding to), both DONE.
- Unlocks: the Core `oxygen-drain` epic's depletion-frame behaviour, and
  `level-outcomes`' chokepoint guard, both of which read this latch.
