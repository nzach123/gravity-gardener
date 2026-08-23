# Story 006: Default-space gravity write, rewritten every eased frame

> **Epic**: Gravity Authority
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3-4 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story)*

## Context

**GDD**: `design/gdd/gravity.md` (primary) · `design/gdd/physics-props.md` (R3, R4)
**Requirement**: `TR-gravity-012`, `TR-props-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**Governing ADRs**: ADR-0001 (primary, decision parts 4 and 4a) · ADR-0006 (secondary —
`Tuning.PROP` is the only sanctioned way to reach `prop_gravity_scale`)
**ADR Decision Summary**: Props receive gravity through the `PhysicsServer2D` default
2D space, not per-prop force. Space gravity is symmetric by nature, which satisfies
`physics-props.md` R4 with no code, and it reaches every `RigidBody2D` in the same
physics frame, which gives GDD AC12 structurally. The write is rewritten every physics
frame while the vector is easing, and idles once it settles.

**Engine**: Godot 4.7.1 | **Risk**: LOW *(with one open verification item — see below)*
**Engine Notes**: `PhysicsServer2D.area_set_param` is pre-4.4 and unchanged through 4.7.
The `AREA_PARAM_GRAVITY = 1` / `AREA_PARAM_GRAVITY_VECTOR = 2` spellings were
**confirmed 2026-08-14** by engine-specialist review; `World2D.space` is documented as
deliberately dual-registered as both space and area, which makes ADR-0001's part-4
snippet the officially sanctioned pattern, not a workaround. Jolt is inert — this is 2D.

> **ADR-0001 Verification Required item 2 is OPEN and this story discharges it.**
> The same-frame guarantee holds only if the write happens in `_physics_process`. That a
> default-space write made there reaches every `RigidBody2D` in *that same step* has not
> been confirmed against the 4.7.1 binary. **Do not close TR-gravity-012 on the strength
> of the ADR text alone** — the epic's Risks table says so explicitly. Record the
> empirical result in the ADR's Verification Required field as part of this story.

**Performance**: Two `area_set_param` calls per physics frame while easing (roughly 6-7
frames per gravity change at 60 FPS), and **zero** per-frame cost in steady state. The
guardrail is `prop_gravity`: 0 per-frame script cost when settled. Any implementation
that writes unconditionally every frame violates it even though it looks correct.

**Control Manifest Rules (this layer)**:
- Required: "The gravity space write (`PhysicsServer2D.area_set_param`) must happen in
  `_physics_process`, never `_process`, every frame while `gravity != target_gravity`."
  — source: ADR-0001 (part 4a)
- Required: "Consumers reach tuning ONLY through `class_name Tuning` (`Tuning.WATERING`
  / `.OXYGEN` / `.PROP`); no consumer names a `.tres` path itself." — source: ADR-0006
  (D6.3)
- Forbidden: "Never use `apply_central_force()` for gravity, or per-prop `gravity_scale`
  tuning — costs 40 script callbacks/frame for variation the design forbids; use
  default-space gravity." — source: ADR-0001 (`per_prop_gravity_application`)
- Forbidden: "Never set `gravity_space_override` (or `gravity`) on any `Area2D`." —
  source: ADR-0001 (`area2d_gravity_space_override`)
- Forbidden: tuning-resource runtime mutation and `.tres` path literals outside the
  `Tuning` const holder (`tuning_resource_runtime_mutation`,
  `tuning_path_literal_outside_holder`) — source: ADR-0006
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state." — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` AC12 and `design/gdd/physics-props.md` R3, R4,
scoped to this story:*

- [ ] `GravityAuthority` writes both `AREA_PARAM_GRAVITY_VECTOR` (the normalized
      direction) and `AREA_PARAM_GRAVITY` (the magnitude) to the default 2D space
      obtained via `get_viewport().find_world_2d().space`.
- [ ] The magnitude written is `descent_magnitude() * Tuning.PROP.prop_gravity_scale`,
      reached through the `Tuning` const holder and never via a `.tres` path literal.
- [ ] The write happens in `_physics_process`, never `_process`.
- [ ] The write repeats on **every** physics frame while `gravity != target_gravity`,
      so props tip and slide through the rotation rather than snapping at its end
      (`physics-props.md` R3).
- [ ] The write does not run once the ease has settled — steady-state per-frame cost is
      zero.
- [ ] Prop gravity is symmetric: the same magnitude applies whether a body is rising or
      falling (`physics-props.md` R4). This must fall out of using space gravity, not
      from added code.
- [ ] AC12 — a `RigidBody2D` in the scene adopts the new vector on the same physics
      frame the player does.
- [ ] **ADR-0001 Verification Required item 2 is discharged**: the same-frame guarantee
      is confirmed empirically against the 4.7.1 binary and the result is written back
      into the ADR and into `tr-registry.yaml`'s `TR-gravity-012` note.

---

## Implementation Notes

*Derived from ADR-0001 decision parts 4 and 4a, as amended 2026-08-15 by ADR-0006:*

- The sanctioned snippet, verbatim from ADR-0001 part 4:

  ```gdscript
  var space := get_viewport().find_world_2d().space
  PhysicsServer2D.area_set_param(space,
          PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized())
  PhysicsServer2D.area_set_param(space,
          PhysicsServer2D.AREA_PARAM_GRAVITY,
          descent_magnitude() * Tuning.PROP.prop_gravity_scale)
  ```

  The `Tuning.PROP` reach is the 2026-08-15 ADR-0006 amendment. The line as originally
  written named the resource directly and is the evidence ADR-0006's Problem Statement
  cites — do not restore the earlier form.
- **`descent_magnitude()`, not `ascent_magnitude()`.** Props are symmetric and
  `physics-props.md` section 4 defines `g_prop = g_descent0 * m * prop_gravity_scale`.
  Using the ascent magnitude makes props float relative to the player's fall, and
  `physics-props.md` AC5 pins prop fall time to the player's `t_down`.
- This is why one vector serves two contradictory magnitude models: the space carries
  the symmetric prop magnitude, and `PlayerGravityComponent` applies the asymmetric one
  to itself. `CharacterBody2D` ignores space gravity, so the two cannot contaminate each
  other. Nothing here touches the player.
- The write belongs **inside story 002's existing ease branch** in `_physics_process`,
  after the angle update. It must also run once on the frame a change is accepted, so a
  zone entry that happens to target the current direction still applies a new magnitude.
- `_physics_process` is not a style choice. `_process` runs once per rendered frame with
  no defined phase relationship to the fixed-timestep loop — relative to a given physics
  step it may run zero, one or several times, so AC12 would hold only by accident.
  ADR-0005 later assigns this node `process_physics_priority = -100`, which presupposes
  `_physics_process`; the requirement originates in ADR-0001 part 4a.
- **`Tuning.PROP` is a cross-epic dependency.** `PropTuning`, the `Tuning` const holder,
  and `prop_tuning.tres` are built by the tuning-resources epic (stories 002, 003, 004).
  If they do not exist yet, that epic is a hard prerequisite — do **not** substitute a
  literal `1.0` or a local constant, either of which is a registered forbidden pattern.
- Do not add `gravity_scale = 0` to any prop, and do not call `apply_central_force()`.
  Both belong to the rejected Alternative 2, which costs 40 script callbacks per frame
  for per-prop variation the design explicitly forbids.
- **Discharging the verification item is part of the work, not a follow-up.** Build a
  scene with a `RigidBody2D`, drive one gravity change, and sample the body's applied
  gravity and the player's on the same physics frame. Write the observed result into
  ADR-0001's Engine Compatibility "Verification Required" field with the date and the
  4.7.1 build, and update the `TR-gravity-012` note in `tr-registry.yaml`. If the
  guarantee does **not** hold, stop and escalate to technical-director rather than
  working around it — AC12 and `physics-props.md` AC4 both rest on it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the prop registry and the force-wake pass. Space gravity does **not** wake
  a sleeping body; that is a separate mechanism and a separate story.
- Story 002: the ease loop this write lives inside.
- Story 004: clearing `gravity_space_override` from `gravity_zone.tscn` — a prerequisite
  for this story to behave correctly, but already done there.
- `PropBody` itself, prop lifetime, the speed cap, and out-of-bounds freeing — ADR-0011,
  physics-props epic.
- `prop_gravity_scale`'s value and range — owned by `PropTuning` in the tuning-resources
  epic. `physics-props.md` section 7 says leave it at 1.0.
- `physics-props.md` AC10 (a room of props at budget holds 60 FPS during a flip) —
  ADR-0001 assigns that acceptance test to ADR-0011.

---

## QA Test Cases

*Story type: **Integration** — spans the authority, `PhysicsServer2D`, and a real
`RigidBody2D`. The same-frame case cannot be faked; it needs a live physics step.*

Fixture: an initialized authority (`initialize(2990.72, 0.390625)`), a `RigidBody2D`
with default `gravity_scale = 1.0` in a headless scene, and `Tuning.PROP` loaded.

- **AC-1 / AC-2 — both params are written, with the right magnitude**
  - Given: gravity settled at `Vector2.DOWN`, multiplier `1.0`
  - When: `set_gravity(Vector2.RIGHT, 2.0)` and one physics frame elapses
  - Then: reading the space back via `PhysicsServer2D.area_get_param` returns a
    direction stepping toward `Vector2.RIGHT` and a magnitude equal to
    `descent_magnitude() * Tuning.PROP.prop_gravity_scale`
  - Edge cases: assert the magnitude uses **descent**, not ascent — at the GDD's current
    ratio those differ by 2.56x, so the wrong one is unmistakable. Assert the vector
    param is normalized: writing an unnormalized vector multiplies the magnitude twice
    and produces gravity roughly 3000x too strong, which reads as "props explode" rather
    than as a normalization bug.

- **AC-3 — the write is in the physics callback**
  - Given: the authority source
  - When: the test greps for `area_set_param`
  - Then: every occurrence is inside `_physics_process`, and none is inside `_process`
  - Edge cases: a source grep is the honest test — the two callbacks are
    indistinguishable from their effects headlessly. Assert `func _process` either does
    not exist or contains no `area_set_param`.

- **AC-4 — the write repeats through the ease (`physics-props.md` R3)**
  - Given: a counter wrapping `area_set_param`
  - When: a 90-degree `set_gravity()` is stepped to completion at `1.0 / 60.0`
  - Then: the counter increments on every frame of the ease, and the direction written
    differs between consecutive frames
  - Edge cases: assert the *values differ*, not only that the call happened. An
    implementation that writes the unchanging `target_gravity` every frame passes a
    call-count test and still snaps props to the end orientation, which is exactly what
    R3 forbids.

- **AC-5 — steady state costs nothing (guardrail `prop_gravity`)**
  - Given: gravity settled
  - When: 100 physics frames elapse with no zone entry
  - Then: `area_set_param` is called zero times
  - Edge cases: also assert zero calls before the *first* `reset_to()` — an
    unconditional write in `_physics_process` would push an uninitialized vector into
    the space at load, giving every prop garbage gravity for the frames before the level
    root runs.

- **AC-6 — prop gravity is symmetric (`physics-props.md` R4)**
  - Given: a `RigidBody2D` given an initial velocity along `-gravity` (rising) and, in a
    second run, along `+gravity` (falling)
  - When: each is stepped for the same number of physics frames
  - Then: the acceleration magnitude observed is identical in both runs
  - Edge cases: run this with an asymmetric player present in the same scene and assert
    the player's magnitudes still differ by the 0.390625 ratio in the same frames. The
    point of the decision is that one vector produces two magnitude models; a test that
    checks only the prop cannot detect the two paths contaminating each other.

- **AC-7 / AC-8 — same-frame adoption (GDD AC12) and the verification discharge**
  - Given: a scene containing both a `Player` and a `RigidBody2D`, gravity settled
  - When: a gravity change is issued and exactly one physics step is advanced
  - Then: within that single step, the player's applied gravity direction and the body's
    applied gravity direction agree
  - Edge cases: sample **within** the step, not after `N` steps — an off-by-one-frame
    lag is precisely the failure ADR-0001's open verification item names, and it is
    invisible to any test that settles first. Test at 60 FPS and again at a modified
    `Physics 2D > Default Physics FPS` (e.g. 30) to confirm the guarantee is phase-based
    and not a coincidence of the default tick rate. Also test with the body **asleep** at
    the moment of the change and record the result: space gravity alone is not expected
    to wake it, and that expected failure is what motivates story 007. Do not "fix" it
    here.
  - **Discharge**: write the observed same-frame result, the date, and the engine build
    into ADR-0001's Verification Required field, and update the `TR-gravity-012` note in
    `docs/architecture/tr-registry.yaml`. `/story-done` must not close this story with
    that field still reading "Item 2 remains".

**Estimated test count**: ~30 assertions.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/gravity/space_gravity_write_test.gd` — must exist and pass
- ADR-0001 Verification Required item 2 updated with a recorded empirical result, and
  the matching `tr-registry.yaml` note for `TR-gravity-012` updated. This is a **gating**
  deliverable of the story, named in the epic's Definition of Done.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (the `_physics_process` ease branch this write lives in),
  Story 004 (`gravity_space_override` must be cleared, or a prop inside a zone reads a
  stale `-980.0` regardless of this write), and **`Tuning.PROP` from the
  tuning-resources epic (ADR-0006, stories 002-004)** — cross-epic, hard prerequisite
- Unlocks: Story 007
