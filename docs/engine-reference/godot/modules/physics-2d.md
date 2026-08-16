# Godot — 2D Physics Module Reference

Verified: 2026-08-13 against the Godot 4.7 release notes.

## Stability

No breaking changes to `RigidBody2D`, `Area2D`, `CharacterBody2D` or
`move_and_slide()` across 4.4 → 4.7. The 4.6 physics work was Jolt integration
for 3D only; the 2D engine is untouched.

Training-data knowledge is reliable in this domain. Treat 2D physics decisions
as settled and do **not** mark them as unverified in architecture documents.

## Jolt does NOT apply to this project

`project.godot` sets `3d/physics_engine="Jolt Physics"`, but this is a 2D game.
The setting is inert. No 2D decision may reference Jolt behaviour, Jolt tuning,
or Bullet-era workarounds.

## New in 4.7

- `CollisionShape2D.one_way_collision_direction` — one-way collision in an
  arbitrary direction rather than shape-relative up. Relevant under rotating
  gravity, where a one-way platform authored for "up" is wrong in every rotated
  room. Not currently required by any GDD.

## Sleeping bodies

A settled `RigidBody2D` sleeps and will not react to a change in gravity.
Waking it explicitly is required. This is standard, unchanged 4.x behaviour and
is the mechanism behind `physics-props.md` R5 — the single most likely
implementation bug in the props system.

### A sleeping body receives no `_integrate_forces` call

Verified 2026-08-16 against the `4.7.1-stable` source, during the ADR-0011 engine
gate. `GodotStep2D::step()` iterates **only** the space's active body list
(`modules/godot_physics_2d/godot_step_2d.cpp:140,151`), and
`GodotBody2D::set_active(false)` removes the body from that list when it sleeps
(`godot_body_2d.cpp:139-147`). A sleeping body is therefore never in the list
`step()` walks.

Consequence for architecture work: a per-body `_integrate_forces` override costs
**nothing** once the body settles. This is what lets ADR-0011 D11.2 put a
per-prop speed clamp inside the engine's own steady-state budget of zero
per-frame script cost. A clamp placed in `_physics_process` instead would run
whether or not the body sleeps and would not have that property.

Related: a velocity clamp cannot defeat sleep detection. `GodotBody2D::sleep_test`
(`godot_body_2d.cpp:703-715`) sleeps a body once velocity stays under threshold
for `body_time_to_sleep()`. A clamp only ever *reduces* an over-threshold
velocity, never raises a settled one, and once the body sleeps the clamp does not
run at all.

## Source-tree layout (for anyone reading engine source)

As of 4.7.1 the built-in 2D physics implementation lives under
`modules/godot_physics_2d/`, **not** `servers/physics_2d/`. This is a source-tree
reorganisation, not a scripting-API change — it does not affect the "no breaking
changes" statement above, but it will send anyone hunting by the older path to an
empty directory.

## Sources

- https://godotengine.org/releases/4.7/
- https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html
- `godotengine/godot` at tag `4.7.1-stable`: `modules/godot_physics_2d/godot_step_2d.cpp`,
  `godot_body_2d.cpp`, `godot_space_2d.cpp` — consulted 2026-08-16 for the sleeping-body
  facts above
