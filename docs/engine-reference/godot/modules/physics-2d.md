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

## Sources

- https://godotengine.org/releases/4.7/
- https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html
