# Godot — Current Best Practices (4.5–4.7.1)

Last verified: 2026-08-15

## Architecture & Code Organization

- **Component-based design**: Use composition over inheritance. Small, modular scenes
  rather than monolithic "God scripts." This project already follows this pattern
  (see `src/scripts/components/`).
- **SOLID principles**: Apply separation of concerns through dedicated helper classes
  or services rather than embedding all logic in a single Node.
- **Resources for data**: Use Godot Resources to store data independently of nodes.
  Prefer `.tres` for serialized game data over raw dictionaries.
- **Signals for decoupling**: Use signals to communicate between systems rather than
  direct method calls. Avoids tight coupling.
- **State machines**: Manage complex entity state (player states, enemy AI) through
  dedicated state machine patterns.

## Physics (4.6+)

- **Jolt Physics is the default 3D engine**: Use Jolt-specific features and settings.
  Do not reference Bullet-specific workarounds.
- **2D physics unchanged**: The 2D physics engine remains Godot's built-in implementation.

## Rendering (4.5+)

- **Stencil buffer**: Available for custom rendering effects since 4.5. Use for
  outline effects, portals, and masking instead of older shader-only approaches.
- **AreaLight3D** (4.7): New light type for realistic area lighting in 3D.
- **HDR output** (4.7): Desktop platforms support HDR. Configure in project settings
  if targeting HDR displays.

## UI / Control (4.7+)

- **`Control.offset_transform_*`**: Use these to slide, rotate, or scale a Control for
  juice and transitions. Containers apply their own transform to children and discard
  child transform changes whenever they re-sort (on add, remove, or reorder) — the
  offset transform survives that, the way a CSS `transform` does. This replaces the
  pre-4.7 workarounds of wrapping the Control in a spacer node or re-applying the
  transform after every sort.
- **`offset_transform_enabled` defaults to `false`** — setting `offset_transform_position`
  alone is a silent no-op. The scene (or code) must enable it. This project relies on it:
  `src/scripts/gravity_zone.gd:42` writes `offset_transform_position`, and it only works
  because `gravity_zone.tscn:38` sets `offset_transform_enabled = true`. Verified 2026-08-13.
- **`offset_transform_visual_only` defaults to `true`** — mouse input hits the *un-offset*
  rect. Harmless for a read-only HUD; a real trap for an animated pause menu, where a
  moved button stays clickable at its original position. Set it `false` when input must
  follow the transform.
- **`RichTextLabel` images**: pass `width_unit`/`height_unit` with `RichTextLabel.ImageUnit`.
  The old `width_in_percent`/`height_in_percent` booleans are gone (4.7).

## Editor Workflow (4.6+)

- **"Modern" editor theme**: Improved readability. Use as the default.
- **Inspector improvements** (4.7): Drag-and-drop enhancements, category copy-pasting.
- **Path snapping** (4.7): Improved path node editing tools.

## Accessibility (4.5+)

- **Screen reader support**: GUI elements should implement accessibility metadata
  for screen reader compatibility. New in 4.5.

## GDScript Best Practices

- **Static typing**: Use static typing everywhere for performance and editor support:
  ```gdscript
  var speed: float = 200.0
  func get_direction() -> Vector2:
  ```
- **Overrides need an explicit `return`** (4.7): An override inherits the return type of
  the method it overrides, so a body that used to fall off the end is now an error:
  ```gdscript
  # Base declares:  func get_target() -> Node2D:
  func get_target():        # inherits -> Node2D in 4.7
      if not _has_target:
          return null       # required — implicit fallthrough no longer compiles
      return _target
  ```
  This matters more than it looks: gdUnit4 treats GDScript warnings as errors during
  test discovery, so one missing `return` fails the entire suite at compile time.
- **@export annotations**: Prefer `@export` over `export` (Godot 4 syntax).
- **Signal syntax**: Use `signal_name.emit()` not `emit_signal("signal_name")`.
- **Type hints on signals**: `signal health_changed(new_health: int)`.
