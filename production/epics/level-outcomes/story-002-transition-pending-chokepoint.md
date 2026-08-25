# Story 002: `_transition_pending` — the guarded chokepoint both endings route through

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R7, R9 · §5 · §8 AC7, AC10
**Requirement**: `TR-flow-009` *(the chokepoint)*, `TR-flow-007` *(death unreachable
after the latch)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **`level-state` story 005 wrote this handover out by name.** Its Out of Scope
> section reads: "`restart_level()`'s `_transition_pending` chokepoint (D5.4) — the
> `level-outcomes` epic. Both the guard and the requirement that both paths check
> and set it." Its Implementation Notes go further: "Do not add a
> `_transition_pending` field here… Adding half of a two-sided guard is worse than
> not adding it, because it looks done." **This story is the other half. Land both
> sides or land neither.**

**ADR Governing Implementation**: ADR-0005: Frame ordering and the `level_complete`
guard (D5.4) *(primary)* · ADR-0002 *(secondary — restart is reconstruction, so the
guard dies with the scene rather than being unwound)*

**ADR Decision Summary**: The guard lives at the single point every death path
already passes through — `LevelRoot.restart_level()` — rather than being repeated at
each caller. That covers `OxygenDrain`, `spike_hazard`'s `inc_hazard_dmg` and
`_on_kill_area_2d_body_entered` uniformly. **The latch alone is not sufficient.**
`body_entered` for *different* `Area2D` nodes delivered in the same
`flush_queries()` batch is not ordered by `process_physics_priority`, and no
deterministic inter-area order could be established from documentation or source
(A5-02). If a hazard handler happens to run first, `restart_level()` queues a reload
while `level_complete` is still `false`; the goal handler then latches completion and
queues a scene change, leaving both pending on the same frame. An **idempotent
transition latch checked and set by both paths** closes it regardless of order.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Facts that bind this story:

- **Inter-area `body_entered` delivery order within one physics tick is genuinely
  undetermined.** The 2026-08-14 architecture review confirmed this is a real gap in
  the engine, not an unknown to be researched away. D5.4 closes it **by design**, not
  by verification. Do not attempt to establish an order and guard on it instead.
- **`reload_current_scene` logs `Parameter "current_scene" is null` in a headless
  test with no current scene, and that is not a failure** —
  `kill_area_death_test.gd` passes while logging it. Do not chase the line.
- **A freed `Object` held in a `Variant` compares `== null` as TRUE on 4.7.1, and
  `value as Node` on one RAISES** "Trying to cast a freed object". A plain null check
  already catches a freed object; `as` is not a safe probe. Relevant because both
  guarded paths tear down or replace the scene while references are still live.
- gdUnit4 treats one GDScript warning as a discovery-time error for the whole suite.

**Control Manifest Rules (this layer)**:
- Required: "**`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path must
  check and set `_transition_pending`.** The latch alone is insufficient —
  inter-area signal delivery order within one physics tick is undetermined." —
  ADR-0005 (D5.4, A5-02)
- Required: "`level_complete` is a write-once latch… written ONLY via
  `mark_complete()` from `LevelRoot._on_player_reached_goal()`." — ADR-0005 (D5.3)
- Forbidden: "**Never reload the level from a death/reset path that does not consult
  `level_complete`.** All death paths route through the guarded `restart_level()`." —
  ADR-0005 (`unguarded_restart_path`)
- Forbidden: "Never restart the level in the same `_physics_process` callback that
  observed `remaining <= 0`." — ADR-0005 (`same_frame_oxygen_kill`)

---

## Acceptance Criteria

*From `design/gdd/level-flow.md` §8, scoped to this story:*

- [ ] **AC7** — A death armed on the frame `level_complete` latches never presents.
      It is **discarded, not queued** (`level-flow.md` §5)
- [ ] **AC10** — Firing the completion handler and a death handler on the same
      frame, **in either order**, produces exactly one transition
- [ ] `LevelRoot.restart_level()` returns early when `level_complete` is true **or**
      when `_transition_pending` is already set
- [ ] `LevelRoot._on_player_reached_goal()` returns early when `_transition_pending`
      is already set, and sets it **before** calling `mark_complete()`
- [ ] Two death causes arriving on the same frame produce exactly one sequence — the
      guard admits the first and refuses the second (`level-flow.md` §5)
- [ ] A restart requested while the completion sequence is playing is refused
- [ ] `_transition_pending` is never cleared. Both endings terminate the level
      instance, so it dies with the scene
- [ ] `OxygenDrain` retains its own `level_complete` check. It is deliberate
      redundancy, not duplication to be simplified away

*Explicitly NOT closed by this story — do not tick these anywhere:*

- **AC5** (zero oxygen on the entry frame yields completion) is the
  *depletion-frame* half and closes in `oxygen-drain` story 004, against this guard.
- **AC6** (three causes, one identical sequence) is story 005. This story makes the
  paths converge; story 005 makes what they converge on identical.

---

## Implementation Notes

*Derived from ADR-0005 D5.4 and its Key Interfaces block:*

- **The shape is fixed by the ADR and should be copied, not reinvented:**

  ```gdscript
  var _transition_pending: bool = false   # D5.4 — order-independent guard

  func _on_player_reached_goal() -> void:
      if _transition_pending:
          return
      _transition_pending = true
      level_state.mark_complete()
      change_level()

  func restart_level() -> void:
      if level_state.level_complete or _transition_pending:
          return
      _transition_pending = true
      get_tree().call_deferred("reload_current_scene")
  ```

- **Both conditions in `restart_level()`, not one.** `level_complete` alone cannot
  close the ordering hole, because the order the two handlers run in is the very
  thing in question. `_transition_pending` alone would let a death fire after a
  completion that had already returned early on some other path. Keep both.
- **Set the flag before doing the work, in both functions.** A guard set after
  `mark_complete()` or after `call_deferred` leaves a window on the same frame.
- **`restart_level()` currently calls `GameManager.reset_level_state()`**
  (`main.gd`). Leave that call alone — deleting it is `level-state` story 006's
  work under ADR-0002, and removing it here would close that story's AC by accident
  and outside its test. Add the guard around what is there.
- **`_on_kill_area_2d_body_entered` currently sets `body.player_died = true` before
  calling `restart_level()`.** That write happens *outside* the guard and so still
  runs on a refused death. Story 005 owns removing the cause-specific side channel;
  note it here and leave it, but **do not** add new pre-guard side effects.
- **The guard is a field on `LevelRoot`, not an autoload and not shared state.**
  ADR-0002's injection contract does not carry it, and `PauseController` deliberately
  keeps a *local* lock rather than reading this flag (D14.4) — see story 003.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 003**: `PauseController.set_pause_locked()`. It is set at the same instant
  as this flag but is a separate, local flag by decision — D14.4 rejected having
  `PauseController` read `_transition_pending` directly.
- **Story 004**: the hold between setting the flag and the transition firing. This
  story keeps `change_level()` / `reload_current_scene()` immediate, exactly as
  shipped.
- **Story 005**: making the three death causes indistinguishable.
- **`level-state` story 005**: the latch and `mark_complete()`.
- **`level-state` story 006**: deleting `GameManager.reset_level_state()` and making
  restart pure reconstruction.
- **`oxygen-drain` stories 003–004**: arm-and-defer, the completion freeze, and the
  depletion-frame outcomes that read this guard.

---

## QA Test Cases

*Story type: **Logic** — automated test specs. AC-2 is the load-bearing one: it must
be run in **both** orders, because a guard that only works in the order the author
happened to test is the exact defect D5.4 exists to prevent.*

- **AC-1**: A death armed before the latch does not present after it
  - Given: a `LevelRoot` with `level_complete` false and `_transition_pending` false
  - When: `_on_player_reached_goal()` runs, then `restart_level()` is called on the
    same frame
  - Then: `restart_level()` returns without queueing a reload; exactly one
    transition was queued, and it is the completion
  - Edge cases: call `restart_level()` a second and third time — still no reload

- **AC-2**: Either firing order produces exactly one transition *(run both)*
  - Given: a fresh `LevelRoot`
  - When: **(a)** `_on_player_reached_goal()` then `restart_level()`; **(b)** a fresh
    instance with `restart_level()` then `_on_player_reached_goal()`
  - Then: in both cases exactly one transition is queued and no second one is
  - Edge cases: in order **(b)** assert the queued transition is the **restart**, and
    that `mark_complete()` was not reached — the completion is refused because the
    restart won the race, which is correct: the guard makes them mutually exclusive,
    it does not re-rank them

- **AC-3**: Two death causes on one frame yield one sequence
  - Given: a `LevelRoot` with no transition pending
  - When: `restart_level()` is invoked twice in the same frame, simulating a spike
    and a kill area delivered in one `flush_queries()` batch
  - Then: exactly one deferred `reload_current_scene` is queued
  - Edge cases: three causes in one frame still yields one

- **AC-4**: The completion path is itself re-entrant-safe
  - Given: a `LevelRoot`
  - When: `_on_player_reached_goal()` is called twice in one frame — which the
    engine's undetermined signal delivery leaves possible
  - Then: one scene change is queued, and `mark_complete()` being called twice is a
    harmless no-op
  - Edge cases: assert no error is raised on the second call

- **AC-5**: Structural — no unguarded restart path exists
  - Given: the whole of `src/`
  - When: grepped for `reload_current_scene` and `change_scene_to_packed`
  - Then: every call site is inside `LevelRoot.restart_level()` or
    `LevelRoot.change_level()`, both of which check the guard first
  - Edge cases: also assert `_transition_pending` is never assigned `false` anywhere

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/flow/transition_guard_test.gd` — must exist and
pass.

> **Runner note.** The command changed on **2026-08-24** and must include
> `-a res://tests/integration`; `-a "…test.gd:test_name"` is not a supported
> selector and exits `0` having run nothing. Isolate a single case with a scratch
> suite under `tests/scratch/` and delete it afterwards. See `tests/README.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the emit this guard receives); `level-state` story 005 (the
  ordered handler the guard is added to — this story edits that function)
- Unlocks: Story 004, Story 005, Story 006; `oxygen-drain` story 004
