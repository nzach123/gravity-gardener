# Story 003: Variable jump height — release caps upward velocity at `min_jump_velocity`

> **Epic**: Player Core
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/gravity.md` (R6, R5, AC9, AC10)
**Requirement**: `TR-gravity-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Player component contract and physics step order
**Governing ADRs**: ADR-0007 (primary, D7.3 step 5)
**ADR Decision Summary**: `PlayerJumpComponent` owns coyote time, input buffering and
variable jump height. It runs at D7.3 step 5, after wall jump and before movement, and
receives `up_dir` and `right_dir` as parameters rather than deriving them. It never
recomputes `jump_velocity` — that value is `PlayerGravityComponent`'s, assigned once at
`initialize()`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No new engine API. `Input.is_action_just_pressed`,
`Input.is_action_just_released` and `Vector2.dot` are unchanged since before 4.4.
**GH-115763 does not apply** — `update()` is declared fresh on `PlayerJumpComponent` and
overrides nothing. The jump input action is keyboard-only (Space) per
`.claude/docs/technical-preferences.md`; no gamepad or touch event is configured, so no
analogue-hold path exists.

**Control Manifest Rules (Core layer)**:
- Required: fixed call order — jump is step 5, after wall jump (4) and before movement (6)
  — source ADR-0007 (D7.3).
- Required: `Player._physics_process` threads `up_dir`/`right_dir` in as parameters; the
  component stores neither — source ADR-0007 (D7.1).
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`).
- Forbidden: accumulating a rule-bearing timer in `_process` — coyote and buffer timers are
  rule-bearing and must advance in `_physics_process` — source ADR-0005
  (`gameplay_timing_in_idle_process`).

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md`, scoped to this story:*

- [ ] AC9 — releasing jump during ascent caps upward velocity at `min_jump_velocity`.
- [ ] AC10 — AC9 holds at gravity angles 0°, 90°, 180° and 270°.
- [ ] Releasing jump while **descending** changes velocity by nothing.
- [ ] Releasing jump while ascending at a speed already **below** `min_jump_velocity`
      changes velocity by nothing — the rule is a cap, never a boost.
- [ ] Coyote time (`coyote_time`, 0.12 s) and jump buffering (`jump_buffer_time`, 0.15 s)
      keep their current behaviour and are unaffected by any gravity change (R10).
- [ ] `jump_velocity` is read from `PlayerGravityComponent` and is not assigned anywhere in
      `player_jump_component.gd`.
- [ ] The coyote and buffer timers advance by the `delta` passed into `update()`, not by
      any independently sourced time.

---

## Implementation Notes

*Derived from ADR-0007 D7.3 step 5 and gravity.md R6:*

- Target: `src/scripts/components/player_jump_component.gd`. The reference shape is
  `prototypes/gravity-gardener-vertical-slice/scripts/components/player_jump_component.gd`.
- The cap is one-directional and applies only to the component of velocity along `up_dir`:

  ```
  ascent_speed = velocity · up_dir
  if released_this_frame and ascent_speed > min_jump_velocity:
      velocity -= up_dir * (ascent_speed - min_jump_velocity)
  ```

  Subtracting the excess along `up_dir` rather than rewriting the whole vector preserves
  the perpendicular (walk-axis) component, which matters because at 90° and 270° gravity
  the "upward" axis is horizontal on screen and the walk axis is vertical.
- **`min_jump_velocity` is an `@export` on `Player`** (0.12/0.15/100.0 sit alongside the
  other jump constants at `player.gd:27-31`). ADR-0007 D7 deliberately keeps the jump
  constants as `Player` exports rather than moving them to a tuning resource — that is
  `architecture.md` QQ-02, rated High and knowingly accepted. **Do not migrate them to a
  `.tres` in this story**; ADR-0006 has no `PlayerTuning` resource and inventing one here
  would be an unasked architecture change.
- R10 is a constraint on this story, not a feature of it: carrying a bucket must leave
  `coyote_time`, `jump_buffer_time` and `jump_velocity` untouched. There is nothing to
  implement — there is something not to add. Story 004 asserts the consequence.
- Do not gate the release cap on `is_on_floor()`. A release on the exact landing frame is a
  real input, and the `ascent_speed > min_jump_velocity` test already makes the grounded
  case a no-op.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the callback and the call order this component sits at step 5 of.
- Story 002: gravity integration. This component sets velocity; story 002's function then
  accelerates it.
- Story 004: the carry-invariance assertion.
- Story 005: the input basis. Jump reads `up_dir` and `right_dir` but inverts no axis.
- Story 006: wall jump, which runs at step 4 and is a separate component. **Wall jump also
  produces upward velocity** — do not extend the release cap to cover it here; that is a
  behaviour change to an undocumented mechanic and is Blocked.
- `gravity-authority` story 003: it already asserts `jump_velocity` stays bit-identical
  across gravity broadcasts (its AC-5). Do not duplicate that test.

---

## QA Test Cases

*Story type: **Logic** — every criterion is a numeric assertion against a headless
component driven at a fixed `delta`. No scene is required.*

Fixture: a `PlayerJumpComponent` on a `Player` initialized with `h`=200, `d_peak`=128,
`d_land`=80, `s`=350, giving `jump_velocity` = 1093.75 and `min_jump_velocity` = 100.0.
Drive `update(delta, velocity, is_on_floor, up_dir, right_dir)` at `delta` = 1/60.

- **AC-1 — release during ascent caps at `min_jump_velocity` (GDD AC9)**
  - Given: a launched player, `velocity = up_dir * 1093.75`, gravity down
  - When: the jump action is released on the frame after launch and `update()` is called
  - Then: `velocity.dot(up_dir)` equals 100.0 ±0.01
  - Edge cases: assert `velocity.dot(right_dir)` is unchanged by the release — the cap must
    not zero the walk-axis component

- **AC-2 — the cap holds at every gravity angle (GDD AC10)**
  - Given: the fixture
  - When: AC-1 is repeated with `up_dir` set to each of `(0,-1)`, `(-1,0)`, `(0,1)`, `(1,0)`
    and a non-zero walk-axis velocity component seeded each time
  - Then: `velocity.dot(up_dir)` equals 100.0 ±0.01 at every angle, and
    `velocity.dot(right_dir)` is unchanged at every angle
  - Edge cases: include one off-axis `up_dir` (45°, normalized) — a projection written with
    an axis-aware branch passes the four cardinals and fails here

- **AC-3 — release while descending is a no-op**
  - Given: a descending player, `velocity = -up_dir * 500.0`
  - When: the jump action is released and `update()` is called
  - Then: the returned velocity is exactly equal to the input velocity
  - Edge cases: also test `velocity.dot(up_dir) == 0.0` exactly (the apex frame) — that must
    also be a no-op, since 0.0 is not greater than 100.0

- **AC-4 — release below the cap is a no-op, never a boost**
  - Given: an ascending player, `velocity = up_dir * 50.0`
  - When: the jump action is released and `update()` is called
  - Then: `velocity.dot(up_dir)` equals 50.0, **not** 100.0
  - Edge cases: test the exact boundary `velocity = up_dir * 100.0` — result must be 100.0,
    and the implementation must not add or subtract a floating-point epsilon there

- **AC-5 — coyote time and buffering survive a gravity change (GDD R10)**
  - Given: a player that has just left a ledge, with the coyote timer running
  - When: `GravityAuthority.set_gravity(Vector2.RIGHT, 2.0)` is broadcast mid-coyote, and
    a jump is pressed before `coyote_time` elapses
  - Then: the jump fires, with launch speed 1093.75 along the *new* `up_dir`
  - Edge cases: repeat with a buffered jump pressed 0.10 s before landing and a gravity
    change in between — it must still fire on the landing frame. Also assert the coyote
    timer's elapsed value is unchanged by the broadcast itself

- **AC-6 — the timers advance on the passed `delta`, in `_physics_process`**
  - Given: `src/scripts/components/player_jump_component.gd` as text, and the fixture
  - When: the file is scanned, and `update()` is called 8 times at `delta` = 1/60 with the
    player airborne after leaving a ledge
  - Then: the file declares no `func _process` and no `func _physics_process`; and the
    coyote window (0.12 s) is still open at call 7 and closed at call 8
  - Edge cases: the no-`_physics_process` assertion is load-bearing — Godot auto-schedules
    any override it detects, which would double-drive the timers and halve every window.
    ADR-0009 records this exact failure for `PlayerWateringComponent`
    (`watering_component_gains_own_physics_process`); the same hazard applies here

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player/player_jump_variable_height_test.gd` — must exist
and pass. BLOCKING gate.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the callback threads `up_dir`/`right_dir` into step 5), and
  `gravity-authority` story 001 (`GravityAuthority` must exist in `src/` for AC-5).
- Unlocks: None. Stories 002, 003 and 004 are independent of each other once 001 lands.
