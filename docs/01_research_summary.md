# Research Summary: Plant Watering Mechanic Audit

## `plant.gd` / `plant.tscn`

- **Class**: `Plant` extends `Node2D` (has `class_name Plant`)
- **Nodes**:
  - `AnimatedSprite2D` — "Filling" (6 frames, looped, speed 2.0), "Idle" (1 frame, speed 5.0). Currently starts on "Filling".
  - `InteractArea2D` (Area2D) — `collision_layer=0`, `collision_mask=2` (player layer). `body_entered` → `_on_interact_body_entered`.
  - `AreaCollisionShape2D` — CircleShape2D radius 16.
- **Script**:
  - `@export var item: String = "item"`
  - `_on_interact_body_entered(body)`: if `body is Player`, calls `body.collect(item)` then `queue_free()`.
- **Missing**: No `AnimationPlayer`. No `body_exited` signal connection. No hold-timer logic. No "watered" state.

## `player.gd` / `player.tscn`

- **Class**: `Player` extends `CharacterBody2D`
- **Relevant state**: `items: Array[String]`, `camera_rotation_enabled: bool`
- **Relevant methods**:
  - `collect(item)` — appends to `items` array.
  - `win_level()` — empty stub.
  - `set_gravity(new_vector)` — sets `target_gravity`.
  - `_physics_process(delta)` — full movement: gravity rotation, wall jump, coyote time, jump buffer, squash & stretch. Uses `Input.get_axis("move_left", "move_right")` and `Input.is_action_just_pressed("jump")`.
- **Missing**: No interact input handling. No watering state (`is_watering` bool, movement lock). No reference to the plant being watered.

## `goal.gd` / `goal.tscn`

- **Class**: `Goal` extends `Node2D`, in group `"goal"`
- **Nodes**:
  - `GoalAnimatedSprite2D` — "Idle" (1 frame, non-looping), "goal_begin" (1 frame, looping), "goal_interact" (5 frames, non-looping, speed 8.0). Currently starts on "goal_interact".
  - `GoalArea2D` (Area2D) — `collision_layer=0`, `collision_mask=2`.
  - `AnimationPlayer` — exists but has **no animations** defined.
- **Script**:
  - Signal: `player_reached_goal`
  - `_on_body_entered(body)`: checks `if body.items:` (truthy check on non-empty array), then emits `player_reached_goal` and `queue_free()`.
  - `@export var flip_sprite: bool = false`
- **Missing**: No locked/unlocked state. No visual distinction between locked and unlocked. The `AnimationPlayer` is unused.

## `main.gd`

- **Connections**:
  - `goal.player_reached_goal` → `player.win_level()` + `change_level()`
  - `hazards.inc_hazard_dmg` → `restart_level()`
  - `gravityzone.gravity_changed` → `player.set_gravity()` + `_rotate_camera_to_gravity()`
- **Methods**: `change_level()` (changes to `next_level` PackedScene), `restart_level()` (reloads current scene), camera follow in `_process`.
- **Missing**: No plant-watering orchestration. No connection between plants and goal unlock.

## `gamemanager.gd` (Autoload)

- **State**: `var player_lives = 5` only.
- **Missing**: No goal unlock flag. No plant-watered tracking.

## `project.godot` (Input Map)

- **Existing**: `interact` action already mapped to **E key** (physical_keycode=69). No changes needed.
- **Physics layers**: layer 1="world", layer 2="player", layer 3="item".