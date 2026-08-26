# Story 002: Direction easing in _physics_process with an exported ease rate

> **Epic**: Gravity Authority
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-26

## Context

**GDD**: `design/gdd/gravity.md`
**Requirement**: `TR-gravity-003`, `TR-gravity-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**ADR Decision Summary**: Direction easing moves from `PlayerGravityComponent` to
`GravityAuthority`, driven by the exported `direction_ease_rate` rather than a
hardcoded `32.0`. The dead `move_toward` magnitude ease is dropped in the move —
strength snaps, only direction eases.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `lerp_angle`, `clampf` and `_physics_process` all predate 4.4 and
are unchanged through 4.7 (`modules/physics-2d.md`, verified 2026-08-13). No
post-cutoff API. Note that `Physics 2D > Default Physics FPS` affects the number of
ease steps but not the wall-clock duration — write the test against elapsed seconds,
not frame counts.

**Performance**: One `lerp_angle` per physics frame while easing — exactly 5 frames
for a 90-degree change at 60 FPS with the 2.5-degree settle threshold (probed
2026-08-25), not the 6-7 estimated before the threshold existed. Zero cost once
`gravity` reaches `target_gravity`. The idle path must return before doing any work.

**Control Manifest Rules (this layer)**:
- Required: "Gravity is owned exclusively by the `GravityAuthority` autoload ...
  Written ONLY by `set_gravity()` / `reset_to()`." — source: ADR-0001
- Required: "The gravity space write (`PhysicsServer2D.area_set_param`) must happen in
  `_physics_process`, never `_process`, every frame while `gravity != target_gravity`."
  — source: ADR-0001 (part 4a). *This story establishes the `_physics_process` ease
  loop that the story 006 write lives inside.*
- Forbidden: "Never cache gravity/target_gravity on any node instead of reading
  `GravityAuthority`." — source: ADR-0001 (`private_gravity_copy`)

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` R3, section 4, section 5 and AC5, scoped to this story:*

- [x] AC5 — a 90-degree gravity direction change completes within 100 ms and the angle
      is monotonic throughout (no overshoot, no reversal).
      **CLAUSE CLARIFIED 2026-08-25 — "completes" means the settle snap below, not
      `is_equal_approx`.** The pure ease never satisfies `is_equal_approx` inside
      100 ms and is not intended to; see the settle-threshold criterion below. GDD
      `gravity.md` AC5 is unchanged and is met at 83.3 ms.
- [x] The ease snaps to `target_gravity` once the remaining angle falls below
      `DIRECTION_SETTLE_EPSILON` (2.5 degrees). This makes "settled" a single,
      exact, testable state rather than two competing ones.
- [x] R3 — strength snaps. `ascent_magnitude()` and `descent_magnitude()` reach their
      new values on the *same* call to `set_gravity()`, before any ease frame runs.
- [x] The ease runs in `_physics_process(delta)`, never `_process(delta)`.
- [x] The ease uses `direction_ease_rate` from the export. No literal `32.0` appears
      anywhere in `gravity_authority.gd` outside the export's default value
      (TR-gravity-011).
- [x] Changing `direction_ease_rate` changes the observed ease duration — a smaller
      rate produces a measurably slower rotation.
- [x] The magnitude half of the old `update_gravity_lerp()` is gone. No `move_toward`
      on `gravity.length()` exists on the authority (GDD section 5, "Gravity magnitude
      easing" row).
- [x] Once `gravity` equals `target_gravity`, `_physics_process` returns without
      recomputing the angle or re-emitting.
- [x] `gravity_changed` fires on the `set_gravity()` / `reset_to()` call, not once per
      ease frame — consumers receive the *target* direction and multiplier, and read the
      eased `gravity` themselves.

---

## Implementation Notes

*Derived from ADR-0001 decision parts 1, 3 and 4a, and GDD section 4:*

- The ease formula is unchanged from the code being replaced, with the constant
  substituted:
  `angle = lerp_angle(gravity.angle(), target_gravity.angle(), clampf(direction_ease_rate * delta, 0.0, 1.0))`.
  This is a relocation, not a retune — do not adjust the curve.
- Reconstruct the vector as `Vector2.RIGHT.rotated(new_angle) * ascent_magnitude()`.
  The magnitude comes from the already-snapped ascent magnitude, **not** from
  `move_toward` on the old length. Dropping that `move_toward` is explicitly part of
  the decision (ADR-0001 part 3) and resolves the GDD section 5 edge-case note.
- `_physics_process` is mandatory and is not a style preference. `_process` runs once
  per rendered frame with no defined phase relationship to the physics step, so a write
  made there reaches integration by accident rather than by guarantee. Story 006's
  same-frame requirement (GDD AC12) depends on this loop being the physics one.
- **Settle threshold — added 2026-08-25, resolving a spec contradiction.** After
  computing each eased vector, snap when the remaining angle is small:

  ```gdscript
  const DIRECTION_SETTLE_EPSILON: float = 0.0436332  # 2.5 degrees, in radians

  if absf(angle_difference(gravity.angle(), target_gravity.angle())) < DIRECTION_SETTLE_EPSILON:
      gravity = target_gravity
  ```

  Then guard the top of `_physics_process` with
  `if gravity == target_gravity: return`. Because the snap assigns the target
  vector itself, `==` is now correct and exact — `is_equal_approx` is no longer
  needed for the idle test.

  *Why this exists.* The story previously required `is_equal_approx` to become
  true within 100 ms. It cannot. Probed in Godot 4.7.1 on 2026-08-25 with
  `rate = 32.0`, `delta = 1/60`, over a 90-degree change: the retained error per
  step is `1 - 32/60 = 0.4667`, so the residual runs 42.0, 19.6, 9.15, 4.27,
  1.99, 0.93, 0.43, 0.20 degrees — and `is_equal_approx` is STILL false at step 8
  (133 ms). It needs roughly 19 steps (~317 ms). A correct implementation would
  have failed QA AC-1 as written.

  *Why 2.5 degrees.* It snaps at step 5 = 83.3 ms, leaving 16.7 ms of headroom
  under GDD AC5's 100 ms and +0.51 degrees of margin over the 1.9919-degree
  step-5 residual. **Do not use 1.0 or 2.0 degrees.** 1.0 snaps at step 6 =
  exactly 100.0 ms — zero timing margin. 2.0 snaps at step 5 but clears the
  residual by only +0.008 degrees, which float drift can erase. 2.5 is the
  smallest value with margin on both axes.

  This does not retune the curve. Steps 1-4 are bit-identical to the ease being
  relocated; only the tail is truncated.
- `direction_ease_rate` was declared in story 001. This story is where it is first
  *read*. Removing the hardcoded `32.0` is the whole of TR-gravity-011 — an exported
  field that nothing consumes does not close it.
- Do not emit `gravity_changed` per ease frame. Consumers that need the live eased
  vector read `GravityAuthority.gravity` directly (the manifest's required read path);
  a per-frame signal would add ~7 emissions per zone entry for no consumer benefit.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the node, the API surface, the guards, and the export declaration itself.
- Story 003: `PlayerGravityComponent` losing `update_gravity_lerp()` and consuming the
  authority's eased vector instead.
- Story 006: the `PhysicsServer2D` space write that will live inside this same
  `_physics_process` ease branch.
- Story 007: the prop wake pass, which also runs on each frame the vector changes.
- Camera easing and the camera tween — untouched by this story. The camera-follow /
  camera-rotation split is Blocked (ADR-0013 D13.5, epic Risks table).

---

## QA Test Cases

*Story type: **Logic**. Headless, no `Player`, no scene. Drive the ease by calling
`_physics_process(delta)` directly with a fixed `delta` rather than awaiting real
frames — this keeps the test deterministic, as the testing standards require.*

Fixture: `initialize(2990.72, 0.390625)`, then `reset_to(Vector2.DOWN, 1.0)`.

- **AC-1 — 90-degree rotation completes within 100 ms and is monotonic (GDD AC5)**
  - Given: gravity settled at `Vector2.DOWN`, `direction_ease_rate = 32.0`
  - When: `set_gravity(Vector2.RIGHT, 1.0)`, then `_physics_process(1.0 / 60.0)` is
    called in a loop, recording `gravity.angle()` after each step
  - Then: `gravity == target_gravity` becomes true at accumulated elapsed time
    <= 0.100 s, and the angular delta between consecutive samples never changes sign

    **DEFECT RESOLVED 2026-08-25.** This clause read
    `gravity.is_equal_approx(target_gravity)`. That assertion was unsatisfiable: probed
    in Godot 4.7.1, `is_equal_approx` is still false at step 8 (133 ms) and needs about
    19 steps (~317 ms), so a CORRECT implementation failed it. The story carried two
    meanings of "settled" — the visual settle its Performance note budgeted, and the
    `is_equal_approx` settle this clause demanded. The `DIRECTION_SETTLE_EPSILON` snap
    in Implementation Notes collapses them into one, and makes `==` exact rather than
    approximate. Expect the snap at step 5 = 83.3 ms.
  - Edge cases: test all four 90-degree transitions (DOWN to RIGHT, RIGHT to UP, UP to
    LEFT, LEFT to DOWN) — `lerp_angle` wraps at the +/-pi boundary and a naive
    subtraction-based monotonicity check produces a false failure exactly there. Compare
    wrapped deltas via `angle_difference()`. Also test a 180-degree flip (DOWN to UP),
    where `lerp_angle`'s shortest-path choice is ambiguous: assert only that it
    terminates and stays monotonic, not which way it turns.

- **AC-2 — strength snaps while direction eases (GDD R3)**
  - Given: gravity settled at `Vector2.DOWN` with multiplier `1.0`
  - When: `set_gravity(Vector2.RIGHT, 2.0)` is called and **no** `_physics_process`
    step has yet run
  - Then: `ascent_magnitude()` already equals `baseline * 2.0` and `descent_magnitude()`
    equals that over the ratio, while `gravity.angle()` is still the pre-call angle
  - Edge cases: assert the magnitude at the *first* ease frame too — an implementation
    that ramps magnitude alongside direction passes an end-state check and fails this one.

- **AC-3 — the ease runs in the physics callback**
  - Given: the authority script source
  - When: the test greps `gravity_authority.gd`
  - Then: `func _physics_process` is declared and `func _process` is not
  - Edge cases: a source grep is the honest test here — a behavioural test cannot
    distinguish the two callbacks headlessly. If `_process` is ever needed for an
    unrelated purpose, this case must be narrowed to "the ease body is not inside
    `_process`", not deleted.

- **AC-4 / AC-5 — the exported rate is what drives the ease (TR-gravity-011)**
  - Given: two authorities, one with `direction_ease_rate = 32.0` and one with `8.0`
  - When: both are given the same 90-degree `set_gravity()` and stepped at
    `1.0 / 60.0` until settled
  - Then: the `8.0` authority takes strictly more steps than the `32.0` one
  - Edge cases: grep the source for the literal `32.0` and assert it appears exactly
    once — on the `@export` default line. A hardcoded rate inside the ease body still
    produces a correct-looking 100 ms result at the default value, so a duration-only
    test passes on the exact defect TR-gravity-011 names. Both cases are required.

- **AC-6 — no magnitude easing survives**
  - Given: the authority script source and a running ease
  - When: the test greps for `move_toward` and separately samples `gravity.length()`
    on each ease frame of a `set_gravity(Vector2.RIGHT, 2.0)` transition
  - Then: `move_toward` does not appear, and `gravity.length()` equals the post-snap
    `ascent_magnitude()` on every sampled frame including the first
  - Edge cases: the multiplier must change in this test. With multiplier held at `1.0`
    the length is constant anyway and a magnitude ease would be invisible.

- **AC-7 — the settled state costs nothing**
  - Given: gravity settled, `gravity == target_gravity` (exact — the settle snap
    assigns the target vector itself, so no approximate test is needed here)
  - When: `_physics_process(1.0 / 60.0)` is called 100 times
  - Then: `gravity` is bit-identical to its value before the loop, and `gravity_changed`
    did not fire
  - Edge cases: bit-identical, not approximate. A loop that recomputes `lerp_angle`
    against an already-reached target accumulates float drift, which an approximate
    assertion would hide until it became visible in play. The settle snap gives this
    criterion an exact target it previously lacked: before the snap existed, `gravity`
    was never bit-equal to anything, so "bit-identical" had no defined reference.

- **AC-8 — signal fires once per change, not once per frame**
  - Given: a signal counter connected to `gravity_changed`
  - When: `set_gravity(Vector2.RIGHT, 1.0)` then the ease is stepped to completion
  - Then: the counter is exactly `1`, and the payload is the *target* direction
    (normalized `Vector2.RIGHT`) and multiplier, not an intermediate eased direction
  - Edge cases: include a second `set_gravity()` issued mid-ease, before the first
    settles. Expect exactly `2` emissions total and the ease to retarget to the newer
    direction without snapping. This is the last-entered-wins case of GDD R8.

**Estimated test count**: ~28 assertions.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Assert the margin, not only the pass** *(retro action item 4)*. The settle
  snap at step 5 = **83.3 ms** against GDD AC5's **100 ms** leaves **16.7 ms of
  headroom**, and the 2.5-degree threshold clears the 1.9919-degree retained
  residual by **+0.51 degrees**. Write both numbers into the assertions, so a
  later `direction_ease_rate` change that erodes either one fails loudly instead
  of passing at zero margin.
- **Suite-count reconciliation is gating.** This story deletes the two
  `test_gravity_lerp_*` cases in `tests/unit/gravity/gravity_component_test.gd`,
  because `update_gravity_lerp()` ceases to exist. Record at `/story-done`: the
  suite count before, the count after, and that disposition. Sprint baseline is
  178/178.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/gravity/gravity_authority_easing_test.gd` — must exist and pass

**Status**: [x] Created and passing — 13 test cases, all green (2026-08-26)

---

## Dependencies

- Depends on: Story 001 (the authority node, its API, and the `direction_ease_rate`
  export must exist)
- Unlocks: Story 003, Story 006

---

## Completion Notes

**Completed**: 2026-08-26
**Criteria**: 9/9 passing (none deferred, none untested — every criterion maps to an
asserting test in `gravity_authority_easing_test.gd`)
**Test Evidence**: Logic — `tests/unit/gravity/gravity_authority_easing_test.gd`,
13 test cases, all passing. `.uid` sidecar generated via `--import`.
**Code Review**: Complete — `/code-review` run 2026-08-26, verdict APPROVED WITH
SUGGESTIONS. One reported BLOCKING finding (misplaced `@warning_ignore` annotations
failing test discovery) was verified and downgraded to INFO: `project.godot` sets no
`unsafe_*` warning levels, the suite runs green, and the identical placement exists in
all seven other test files — it is a project-wide convention, not a defect introduced here.

### Suite reconciliation (gating, per the QA-plan addendum)

| | Suites | Cases |
|---|---|---|
| Before | 11 | 178 |
| After | 12 | **191** |
| Delta | +1 | +13 new, **0 deleted** |

Exit code 0 — 0 errors, 0 failures, 0 flaky, 0 orphans (`reports/report_8`).
Settle snap fires at step 5 = 83.333 ms on all four 90-degree transitions; the
180-degree flip settles at step 6 = 100.0 ms.

### Deviations (all advisory — logged to `docs/tech-debt-register.md`)

1. **The addendum's test deletion is deferred, not done.** The QA-plan addendum asked
   GA-002 to delete `test_gravity_lerp_moves_toward_target` and
   `test_gravity_lerp_noop_when_already_at_target` from `gravity_component_test.gd`.
   Verified they must not be deleted yet: `update_gravity_lerp()` is still live at
   `player_gravity_component.gd:69` and still called from `player.gd:138`, so both
   tests cover real shipping code. This story's **Out of Scope** section assigns that
   removal to Story 003 and outranks the addendum. This is why the delta shows 0
   deletions rather than -2.
2. **Addendum rounding corrected.** The addendum quotes 16.7 ms headroom and +0.51
   degrees of residual margin; the measured values are 16.667 ms and 0.50806 degrees.
   The addendum rounds up in both places, so assertion floors set at the quoted figures
   would fail a correct implementation by ~33 microseconds and ~0.002 degrees. Floors
   are set at 0.01666 and 0.508.
3. **`control-manifest.md:170` is stale.** It still budgets the prop wake pass at
   "~6-7 frames per gravity change". The settle epsilon makes it 5. Doc drift only —
   no code impact, and this story's own Performance note already states 5.
4. **`direction_ease_rate` has no range floor.** Set to 0 or negative, `clampf` yields
   0, the residual never shrinks, the settle epsilon never trips, and the turn freezes
   silently with no diagnostic — unlike every other externally-supplied value here,
   which is guarded. The export *declaration* is Story 001's scope, so this is a
   follow-up rather than a GA-002 fix.
5. **`_settle_steps()` lacks a ceiling assertion.** It caps at `SETTLE_STEP_CEILING`
   and returns that count, so a non-terminating slow-rate ease would still read as
   "more steps than fast" and pass `test_a_lower_ease_rate_takes_strictly_more_steps`.
   Its sibling `_run_transition()` does assert the ceiling.

No blocking deviations. ADR-0001 decision parts 1, 3 and 4a verified compliant, as is
every Foundation-layer control manifest rule: scene autoload, no `class_name`, ease in
`_physics_process` with no `_process` declared, no `private_gravity_copy`, no
`GravityTuning` resource, and `push_error` rather than `assert` in the guards.
