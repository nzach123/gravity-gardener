# Story 006: Completion advances to the next authored level

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (2 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R10 · §5 *"The next level's scene fails to
load"* · §5 *"Final level completed"*
**Requirement**: `TR-flow-010` — **the not-blocked half only**
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **`TR-flow-010` is `status: gap` with `adr: null` and it does not close here.**
> The GDD marks R10 ⚠ **TBD** because *what happens after the final level* is
> undecided, and depends on `game-concept.md`'s open question of whether a session is
> one level or several. The epic's risk table records the split precisely:
> "**Single-level completion and the advance-to-next-level path are not blocked and
> can proceed**"; the multi-level arc and the end-of-game state are Blocked. **This
> story is the not-blocked half. Story 007 is the blocked half.** Ticking
> `TR-flow-010` closed anywhere before story 007 lands would claim a decision nobody
> has made.

**ADR Governing Implementation**: ADR-0005: Frame ordering and the `level_complete`
guard (D5.4) *(primary — `change_level()` is the completion side of the guarded
chokepoint)* · ADR-0003: Level load validation contract *(secondary — it owns
load-time validity of the next level's scene, which is a **different** question and
does not close this one)*

**ADR Decision Summary**: No ADR decides what the authored sequence *is*. What is
decided is where the advance happens: inside `LevelRoot.change_level()`, on the far
side of the `_transition_pending` guard and the hold, called only from the single
ordered `_on_player_reached_goal()` handler. Today that is
`get_tree().change_scene_to_packed(next_level)` against a `@export var next_level:
PackedScene` on `main.gd` — a per-level forward pointer authored in the scene.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. `SceneTree.change_scene_to_packed` is
pre-cutoff and unchanged through 4.7.

- **The instant scene change is the current shipped behaviour and is not a defect.**
  `t_transition` is ⚠ unset and **no transition effect is specified**. The epic risk
  table says this in as many words. Treat a transition effect as **new scope**, not
  as this story finishing an unfinished thing.
- **A null `next_level` is a load-time authoring error, not a runtime branch.**
  ADR-0003's `LevelValidation.validate()` runs at `LevelRoot._ready()` and owns the
  Required-consumer table. If `next_level` is to be required, it belongs in that
  table — see Implementation Notes.
- **A freed `Object` compares `== null` as TRUE and `as` on one RAISES.** Relevant to
  any test asserting the old scene is gone after the change.

**Control Manifest Rules (this layer)**:
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path must
  check and set `_transition_pending`." — ADR-0005 (D5.4)
- Required: "`level_complete` is a write-once latch, owned by `LevelState`, written
  ONLY via `mark_complete()` from `LevelRoot._on_player_reached_goal()`." —
  ADR-0005 (D5.3)
- Required: "Every level must declare `default_gravity_direction` /
  `default_gravity_multiplier` exports on `LevelRoot`; `GravityAuthority.reset_to()`
  is called from `LevelRoot._ready()` (**not** `GameManager`)." — ADR-0001, amended
  by ADR-0002
- Forbidden: "Never reload the level from a death/reset path that does not consult
  `level_complete`." — ADR-0005 (`unguarded_restart_path`)

---

## Acceptance Criteria

*From `design/gdd/level-flow.md` §3 R10, scoped to the not-blocked half:*

- [ ] A completion in a level whose `next_level` is authored loads that scene, and
      only after the hold has elapsed
- [ ] The advance happens inside `LevelRoot.change_level()`, called only from
      `_on_player_reached_goal()`, on the far side of the `_transition_pending`
      guard
- [ ] The new level's `LevelRoot._ready()` re-asserts the level's authored
      `default_gravity_direction` / `default_gravity_multiplier`. `GravityAuthority`
      is an autoload and survives the change, so gravity does **not** reset on its
      own (ADR-0001 D6)
- [ ] The new level constructs fresh `LevelState` and `OxygenState` objects — nothing
      carries across the change
- [ ] Whether `next_level` is a Required consumer in ADR-0003's `V-WIRING` table is
      **decided and recorded**, not left implicit — see Implementation Notes. Either
      outcome is acceptable; leaving it undecided is not
- [ ] No transition effect is added. The change stays instant

*Explicitly NOT closed by this story — do not tick these anywhere:*

- **`TR-flow-010` does not close.** Its remainder — what a completion does when
  `next_level` is the last one — is **story 007** and is Blocked on a design decision
  owed by the game-designer.
- **`level-flow.md` §5 "Final level completed" stays ⚠ TBD.** Do not invent a
  behaviour for a null `next_level` in the last level. Story 007's Implementation
  Notes say what to do in the interim.
- **`TR-flow-008`** (restart is a total reset) closed in `level-state` story 006.
  This story asserts the *forward* transition, not the restart.

---

## Implementation Notes

*Derived from ADR-0005 D5.4 and ADR-0003:*

- **The change is small: move the existing call to the far side of the hold.**
  `main.gd`'s `change_level()` already does
  `get_tree().change_scene_to_packed(next_level)`. Story 004 introduced the hold;
  this story wires `change_level()` as what the hold fires at its end, and confirms
  the guard is checked before the hold starts, not after it.
- **Decide the `V-WIRING` question and record it.** ADR-0003 owns a Required-consumer
  table, and ADR-0010 D10.9 already added the `hud` `NodePath` to it as precedent.
  `next_level` is the same shape of authoring error: a level shipped with it unset
  silently dead-ends on completion. **Two acceptable outcomes:**
  1. Add `next_level` to the Required table — but then **every** level must have one,
     which the final level by definition cannot, and that is R10's undecided question
     leaking into a validation rule. This is the reason not to.
  2. Leave it out of the table and record *why* in the story's completion notes,
     naming R10 as the blocker.
  **Recommendation: option 2.** Do not add a validation rule whose correctness
  depends on a decision that has not been made. Record the choice either way —
  ADR-0003 is not this story's to edit, so this is a note, not an amendment.
- **Do not add a null-guard branch that does something invented.** A null
  `next_level` today produces whatever `change_scene_to_packed(null)` produces. That
  is story 007's territory. If a guard is added to prevent a crash during
  development, it must be inert and obviously provisional — a `push_warning` and a
  return, with a comment naming story 007 — never a silent fallback to a menu, a
  restart, or level 01, each of which would be a design decision made by
  implementation.
- **Gravity is the one thing that does not reset on its own.** `GravityAuthority` is
  an autoload and outlives the scene change exactly as it outlives
  `reload_current_scene()`. ADR-0001 D6 already requires `LevelRoot._ready()` to
  re-assert the authored default. Nothing new to build — assert it in the test, so a
  future change that drops the re-assert fails here rather than as a player-visible
  wrong-gravity level start.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 007**: the final level, the end-of-game state, and the multi-level arc.
  **Blocked.**
- **Story 004**: the hold this transition waits for.
- **Story 002**: the guard this transition sits behind.
- **Any transition effect or fade.** `t_transition` ⚠ unset, no effect specified,
  new scope.
- **`level-state` story 006**: restart-is-reconstruction. Fresh state on the *new*
  level is a consequence of that story's work, asserted here, not built here.
- **`level-validation` epic**: the `V-WIRING` Required-consumer table itself. This
  story records a decision about `next_level`'s membership; it does not edit the
  rule set.
- **Level authoring** — which scene follows which. That is content, not code.

---

## QA Test Cases

*Story type: **Integration** — automated test specs.*

- **AC-1**: A completion loads the authored next scene
  - Given: a level whose `next_level` export points at a valid scene, and a
    completion triggered through the normal path
  - When: the hold elapses
  - Then: the tree's current scene is the authored next one
  - Edge cases: assert the change happens **after** `t_hold`, not on the latch frame

- **AC-2**: The advance is behind the guard
  - Given: a level with `_transition_pending` already true
  - When: `_on_player_reached_goal()` fires again
  - Then: no second scene change is queued
  - Edge cases: a death firing during the hold queues no reload either

- **AC-3**: The new level starts from its own authored state
  - Given: a completed level whose gravity had been flipped away from its default
  - When: the next level loads
  - Then: `GravityAuthority`'s direction and multiplier equal the **new** level's
    authored defaults, and the new `LevelState` / `OxygenState` are fresh objects,
    not the previous ones
  - Edge cases: assert the previous `LevelState` is unreachable — remembering that
    `== null` is TRUE for a freed object and `as` on one raises, so probe with a
    plain null check

- **AC-4**: Structural — one advance path, no effect added
  - Given: the whole of `src/`
  - When: grepped for `change_scene_to_packed` and `change_scene_to_file`
  - Then: the only call site is `LevelRoot.change_level()`
  - Edge cases: assert no tween, fade, or `AnimationPlayer` was introduced on the
    transition path — the instant change is the specified behaviour

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flow/advance_to_next_level_test.gd` — must
exist and pass.

> **Runner note.** Include `-a res://tests/integration` and `-c`. See
> `tests/README.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (the guard), Story 004 (the hold); `level-state` story 006
  for AC-3's fresh-state assertion
- Unlocks: Story 007 *(which is Blocked on a design decision, not on this story)*
