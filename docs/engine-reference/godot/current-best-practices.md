# Godot — Current Best Practices (4.5–4.7)

Last verified: 2026-08-13

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
- **@export annotations**: Prefer `@export` over `export` (Godot 4 syntax).
- **Signal syntax**: Use `signal_name.emit()` not `emit_signal("signal_name")`.
- **Type hints on signals**: `signal health_changed(new_health: int)`.
