# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.7.1
- **Language**: GDScript
- **Rendering**: GL Compatibility
- **Physics**: Jolt Physics

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC
- **Input Methods**: Keyboard/Mouse
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: None
- **Touch Support**: None
- **Platform Notes**: Keyboard-only input map (A/D movement, Space jump, E interact, Shift crouch). No gamepad or touch events configured.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/functions**: snake_case (e.g., `move_speed`)
- **Signals**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.6ms
- **Draw Calls**: < 500 per frame
- **Memory Ceiling**: 512 MB

## Testing

- **Framework**: GdUnit4
- **Minimum Coverage**: 70%
- **Required Tests**: Balance formulas, gameplay systems

## Forbidden Patterns

<!-- Full list with rationale lives in docs/registry/architecture.yaml -->
36 patterns are recorded, one per architectural decision, in
`docs/registry/architecture.yaml` (`forbidden_patterns:`). See that file for
the pattern name and rejection rationale — not duplicated here to avoid
drift. Representative examples: `private_gravity_copy` (defeats gravity.md
R9 — exactly one gravity vector may exist), `zone_targets_player_directly`
(`Player.set_gravity()` is removed by ADR-0001), `runtime_collision_mask_mutation`,
`tuning_resource_runtime_mutation`.

## Allowed Libraries / Addons

- **gdUnit4** (`addons/gdUnit4/`) — the project's test framework (see Testing section above)

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/. All 12 are Accepted as of 2026-08-16. -->

| ADR | Title | Status |
|---|---|---|
| ADR-0001 | Gravity Ownership and Global Broadcast | Accepted |
| ADR-0002 | Level State Ownership and Injectable State Objects | Accepted |
| ADR-0003 | Level load validation contract | Accepted |
| ADR-0004 | Collision layer allocation | Accepted |
| ADR-0005 | Frame ordering and the `level_complete` guard | Accepted |
| ADR-0006 | Tuning resource strategy | Accepted |
| ADR-0007 | Player component contract and physics step order | Accepted |
| ADR-0008 | Oxygen Drain, Shared Death Path, and the Accessibility Drain-Rate Override | Accepted |
| ADR-0009 | Watering Interaction Model | Accepted |
| ADR-0010 | HUD Composition, Viewport Tracking, and Pause Ownership | Accepted |
| ADR-0011 | Physics prop body, lifetime and speed cap | Accepted |
| ADR-0012 | Spent Jug Throw and Lifetime | Accepted |

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
