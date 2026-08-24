# Story 002: The fall-speed cap, clamped inside `_integrate_forces`

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (§4 fall speed cap, R3, R4, AC5, AC6, AC7)
**Requirement**: `TR-props-006` (the cap half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, D11.2) · ADR-0006 (secondary — `Tuning.PROP` is
the only sanctioned reach for `prop_max_speed`)
**ADR Decision Summary**: The cap clamps the *magnitude* of `linear_velocity` inside
`_integrate_forces(state)`, preserving direction. Clamping magnitude is what makes the
cap work at every gravity angle with no angle-aware code. `_integrate_forces` is chosen
over `_physics_process` because the engine calls it only on an **active** body, so a
settled prop costs nothing per frame.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `_integrate_forces` and `PhysicsDirectBodyState2D` are pre-4.4 API,
unchanged through 4.7 per `docs/engine-reference/godot/modules/physics-2d.md`.
**GH-115763 does not apply** — `_integrate_forces` returns `void`, so the 4.7
typed-return-inheritance break leaves this override alone. The claim that the engine
does not call `_integrate_forces` on a sleeping body is an **engine fact, and it was
traced rather than assumed**: confirmed against 4.7.1-stable source at the 2026-08-16
review — `godot_step_2d.cpp:140,151` iterates only the active body list, and
`godot_body_2d.cpp:139-147` removes a body from that list when it sleeps. The clamp also
cannot defeat sleep detection, because it only ever *reduces* an over-threshold velocity
and never raises a settled one (`godot_body_2d.cpp:703-715`).

**Performance**: At most 40 clamps per physics frame during a flip, over roughly 6-7
frames per gravity change at 60 FPS. Each clamp is one length comparison and, rarely,
one normalise. **Zero** cost in steady state — that is the whole reason for the
`_integrate_forces` placement, and an implementation in `_physics_process` violates the
guardrail even though it looks correct.

**Control Manifest Rules (this layer)**:
- Required: "The fall-speed cap clamps `linear_velocity` magnitude inside
  `_integrate_forces(state)`, never in `_physics_process` — the engine only calls
  `_integrate_forces` on an active body, so a settled prop costs zero per-frame cost."
  — source: ADR-0011 (D11.2)
- Required: "`prop_max_speed` is read only through `Tuning.PROP`, never a literal path."
  — source: ADR-0011
- Required: "Consumers reach tuning ONLY through `class_name Tuning`." — source:
  ADR-0006 (D6.3)
- Forbidden: "Never write a `res://src/resources/tuning/` path literal outside
  `src/scripts/tuning/`." — source: ADR-0006 (`tuning_path_literal_outside_holder`)
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` / `.PROP`."
  — source: ADR-0006 (`tuning_resource_runtime_mutation`)
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state." — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` §4, AC5, AC6, AC7 and ADR-0011 D11.2 / V1, V2,
V4, scoped to this story:*

- [ ] `PropBody` overrides `_integrate_forces(state: PhysicsDirectBodyState2D) -> void`
      and clamps `state.linear_velocity` to `Tuning.PROP.prop_max_speed` when its length
      exceeds that value.
- [ ] The clamp preserves direction — it normalises and rescales, and contains no
      per-axis or angle-aware branch.
- [ ] `prop_max_speed` is reached through `Tuning.PROP`. No `.tres` path literal and no
      numeric speed literal appears in `prop_body.gd`.
- [ ] A prop at 3 000 px/s in a 2.0× zone reports `linear_velocity.length()` at or below
      `prop_max_speed` on the next physics frame, at gravity angles 0°, 90°, 180° and
      270° (V1).
- [ ] A prop falls 200 px at `m` = 1.0 in 0.229 s ± 5%, **and the clamp never engages
      during that fall** (V2). The second half is as load-bearing as the first.
- [ ] Fall time is identical upward and downward at the same `m`, to float tolerance
      (V4) — the symmetry required by R4.
- [ ] No `_physics_process` override is added to `PropBody`.
- [ ] `prop_body.gd` and the test file are warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 D11.2:*

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    var max_speed: float = Tuning.PROP.prop_max_speed
    if state.linear_velocity.length() > max_speed:
        state.linear_velocity = state.linear_velocity.normalized() * max_speed
```

Three properties make this the right shape, and each is worth preserving through review:

1. **It clamps magnitude and preserves direction**, so it works at every gravity angle
   with no angle-aware code — which is what R3 requires of anything in this system.
2. **It costs nothing in steady state**, because Godot calls `_integrate_forces` only on
   an active body.
3. **It runs before integration**, so the cap holds for the step it is applied in rather
   than one step late.

**The cap must not fight AC5, and the numbers say it does not.** At `m` = 1.0 a prop
falling 200 px reaches about 1 753 px/s (`g_prop` 7 656.25 × `t_fall` 0.229), under the
2 000 px/s default. The clamp is inert there, which is why V2 asserts non-engagement
explicitly. The clamp bites in a 2.0× zone, where an uncapped prop would reach about
2 480 px/s over the same drop — precisely the tunnelling case §4 introduced the cap for.

**Do not implement the cap as damping.** ADR-0011 Alternative 1 (high `linear_damp`
producing a terminal velocity) was rejected because damping slows the *whole* fall, not
only its top end, breaking AC5 and with it the §4 property that props and the player
fall at the same rate. A cap that changes the fall it is not supposed to touch is not a cap.

**Do not move the clamp to `_physics_process`.** Alternative 2 was rejected because
`_physics_process` runs whether or not the body sleeps — 40 callbacks every frame
forever, including in a room where nothing has moved for a minute. Writing
`linear_velocity` from outside the integrator also sets state the solver is concurrently
deriving.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the `PropBody` class, its registry calls and its fixed properties.
- **Story 003**: the `reset_to()` space write.
- **Story 006**: the 40-prop frame-budget measurement. This story's performance claim is
  "zero steady-state cost", which is a structural property of the callback choice, not a
  measured frame time.
- **Tuning value changes.** `prop_max_speed` stays at its committed default of 2 000 px/s.
  ADR-0006 owns the knob; this story only reads it.

---

## QA Test Cases

*Derived from ADR-0011 V1, V2 and V4. The developer implements against these — do not
invent new test cases during implementation.*

- **AC-1** (V1): the cap holds at every gravity angle
  - Given: a `PropBody` in a 2.0× zone, driven to 3 000 px/s
  - When: one physics frame elapses
  - Then: `linear_velocity.length() <= Tuning.PROP.prop_max_speed`
  - Edge cases: repeat at gravity angles 0°, 90°, 180° and 270° — four assertions, not
    one, because a per-axis clamp would pass at 0° and fail at 45°; also assert the
    velocity *direction* is unchanged to float tolerance, since a direction-mangling
    clamp would still pass the magnitude assertion

- **AC-2** (V2): the 200 px fall matches the player, and the clamp stays out of it
  - Given: a `PropBody` at rest, `m` = 1.0, `prop_gravity_scale` = 1.0
  - When: it falls 200 px
  - Then: elapsed time is 0.229 s ± 5%
  - Edge cases: **assert the clamp never engaged during the fall** — instrument the peak
    `linear_velocity.length()` and assert it stayed below `prop_max_speed`. A test that
    checks only the time would pass under a damping implementation, which is the exact
    failure Alternative 1 was rejected for

- **AC-3** (V4): fall time is symmetric
  - Given: two identical `PropBody` instances at the same `m` and the same `mass`
  - When: one falls 200 px with gravity down and the other 200 px with gravity up
  - Then: the two elapsed times are equal to float tolerance
  - Edge cases: R4 exists because `gravity.md` R4's ascent/descent asymmetry is a player
    jump-feel device — assert that no asymmetry leaked in, at `m` = 0.5 and `m` = 2.0 as
    well as 1.0

- **AC-4**: the callback placement is the one the guardrail requires
  - Given: `src/scripts/props/prop_body.gd`
  - When: the file is scanned
  - Then: `_integrate_forces` is present and `_physics_process` is absent
  - Edge cases: also assert no `.tres` path literal and no bare numeric speed constant
    appears in the file — the `tuning_path_literal_outside_holder` ban

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/physics/prop_speed_cap_test.gd` — must exist and pass
(BLOCKING per `.claude/docs/coding-standards.md`)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`PropBody` must exist); `tuning-resources` epic for
  `Tuning.PROP` — **already satisfied**, `src/scripts/tuning/prop_tuning.gd` and
  `src/resources/tuning/prop_tuning.tres` are both in place with `prop_max_speed`
  defaulting to 2 000.0
- **Unlocks**: Story 006 (the frame-budget harness measures a prop that already clamps)
