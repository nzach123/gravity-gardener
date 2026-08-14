# Godot — UI / Control Module Reference

Verified: 2026-08-13 against the Godot 4.7 class reference and 4.7 release notes.

## Control offset transforms (new in 4.7)

An additive, CSS-like visual transform layer on `Control`. Survives container
re-sort, so a Control can be translated, rotated or scaled without the parent
container overwriting it on the next layout pass.

| Property | Type | Default |
|---|---|---|
| `offset_transform_enabled` | bool | `false` |
| `offset_transform_visual_only` | bool | `true` |
| `offset_transform_position` | Vector2 | `(0, 0)` |
| `offset_transform_position_ratio` | Vector2 | `(0, 0)` |
| `offset_transform_rotation` | float | `0.0` |
| `offset_transform_scale` | Vector2 | `(1, 1)` |
| `offset_transform_pivot` | Vector2 | `(0, 0)` |
| `offset_transform_pivot_ratio` | Vector2 | `(0.5, 0.5)` |

### Rules

- `offset_transform_enabled` MUST be set `true` or every other
  `offset_transform_*` property is inert. Set it in the `.tscn`, not at runtime,
  so the dependency is visible in the scene rather than buried in a script.
- `offset_transform_visual_only` defaults `true`: input hit-testing uses the
  **un-offset** layout rect. A visually displaced button is still clicked at its
  original position. Clear this flag only when an animated Control must remain
  clickable where it appears.
- `*_ratio` variants express position and pivot as a fraction of the node's own
  size; the non-ratio variants are absolute pixels.

### In-project use

`src/scenes/gravity_zone.tscn:38` sets `offset_transform_enabled = true` on the
`ColorRect`; `src/scripts/gravity_zone.gd:42` drives
`offset_transform_position` from the collision shape offset. Verified correct —
this is the reference example for the pattern.

## Accessibility (4.5+, landmark navigation 4.7)

- AccessKit-backed screen reader support. All `Control` nodes gained an
  Accessibility tab exposing Name and Description.
- 4.7 adds landmark navigation, giving the screen reader context on entering a
  region.
- Status: experimental. Coverage of standard UI nodes is incomplete.
- Known gap: accessibility strings are **not** extracted into `.POT` files
  (godotengine/godot#115366). Do not rely on them being localisable.

## Sources

- https://docs.godotengine.org/en/stable/classes/class_control.html
- https://godotengine.org/releases/4.7/
- https://github.com/godotengine/godot/pull/87081
- https://github.com/godotengine/godot/issues/115366
