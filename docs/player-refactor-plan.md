# Player Refactor Plan — Composition-Based Architecture

**Date:** 2026-08-13
**Status:** Ready for implementation

---

## 1. External Contracts (Preserved)

### 1.1 Public properties read/written by other scripts

| Property | Type | Used by | Notes |
|---|---|---|---|
| `camera_rotation_enabled` | `bool` | `main.gd` (sets), `debugger.gd` (reads), `player.gd` (self) | Must remain exported |
| `player_died` | `bool` | `hazard.gd` (sets), `plant.gd` (reads) | Must remain exported |
| `is_watering` | `bool` | `plant.gd` (sets), `player.gd` self | Must remain |
| `current_plant` | `Plant` | `plant.gd` (sets) | Must remain |
| `target_gravity` | `Vector2` | `debugger.gd` (reads) | Read by debugger UI |
| `right_dir` | `Vector2` | `debugger.gd` (reads) | Read by debugger UI |
| `up_dir` | `Vector2` | `debugger.gd` (reads) | Read by debugger UI |
| `velocity` | `Vector2` | `debugger.gd` (reads) | Inherited from CharacterBody2D |
| `is_on_floor()` | `func` | `debugger.gd` (reads) | Inherited from CharacterBody2D |

### 1.2 Public methods called by other scripts

| Method | Called by | Notes |
|---|---|---|
| `set_gravity(new_vector: Vector2)` | `main.gd` via `gravity_changed` signal | Must be kept as public facade |
| `win_level()` | `main.gd` via `player_reached_goal` signal | Currently a no-op, must remain |

### 1.3 Input actions (from `project.godot`)

- `move_left` (A key)
- `move_right` (D key)
- `jump` (Space key)
- `interact` (E key)

### 1.4 Groups and signals received

- `gravityzone` group → `gravity_changed(new_vector)` signal → `player.set_gravity()`
- `hazards` group → `inc_hazard_dmg` signal → `main.restart_level()`
- `plants` group — Plant sets `player.is_watering` and `player.current_plant` directly
- Goal → `player_reached_goal` → `player.win_level()` + `main.change_level()`

### 1.5 Node references (current scene tree)

```
Player (CharacterBody2D)
├── PlayerAnimatedSprite2D (AnimatedSprite2D)
├── PlayerArea2D (Area2D)
│   └── PlayerCollisionShape2D (CollisionShape2D)
```

---

## 2. Architecture Overview

### 2.1 Components

```
Player (CharacterBody2D) — root + facade
├── PlayerMovementComponent (Node)      — lateral acceleration, friction, camera-aware input
├── PlayerGravityComponent (Node)       — gravity smoothing, ascent/descent, up/right derivation
├── PlayerJumpComponent (Node)          — jump math, coyote, buffer, variable release, landing
├── PlayerWallJumpComponent (Node)      — wall detection, impulse, cooldown, enable flag
├── PlayerWateringComponent (Node)      — is_watering lockout, current_plant, start/stop events
└── PlayerVisualComponent (Node)        — sprite rot, flip, animation, optional squash/stretch
```

### 2.2 Execution Order (preserved from original)

In `Player._physics_process(delta)`:

1. **Watering lockout check** → `PlayerWateringComponent` — if active, zero velocity & return
2. **Gravity update** → `PlayerGravityComponent.update(delta)` — lerp toward target
3. **Gravity apply** → `PlayerGravityComponent.apply(delta, velocity, is_on_floor)` — ascent/descent
4. **Wall jump** → `PlayerWallJumpComponent.try(delta, velocity, up_dir, right_dir)` — if enabled
5. **Jump handle** → `PlayerJumpComponent.update(delta, is_on_floor, up_dir, right_dir)` — coyote/buffer/release/landing
6. **Movement apply** → `PlayerMovementComponent.apply(delta, velocity, is_on_floor, right_dir, up_dir)`
7. **`move_and_slide()`** — called by Player
8. **Visual update** → `PlayerVisualComponent.update(delta, velocity, is_on_floor, right_dir, up_dir, input_axis)`

### 2.3 Signals

| Signal | Emitter | Receiver | Purpose |
|---|---|---|---|
| `jumped` | PlayerJumpComponent | PlayerVisualComponent | Trigger jump animation/squash |
| `landed` | PlayerJumpComponent | PlayerVisualComponent | Trigger land squash |
| `wall_jumped` | PlayerWallJumpComponent | PlayerVisualComponent | Trigger wall jump feedback |
| `watering_started` | PlayerWateringComponent | PlayerVisualComponent | Lock visuals |
| `watering_stopped` | PlayerWateringComponent | PlayerVisualComponent | Unlock visuals |

### 2.4 Data Flow

```
GravityZone.gravity_changed ──→ Player.set_gravity() ──→ PlayerGravityComponent.set_gravity()
Plant._process() ──→ Player.is_watering / Player.current_plant ──→ PlayerWateringComponent
Player._physics_process() ──→ each component in order ──→ velocity modified in place ──→ move_and_slide()
```

---

## 3. Files to Create / Modify

| File | Action | Purpose |
|---|---|---|
| `_res/scripts/player.gd` | **Modify** | Slim facade, owns components and move_and_slide |
| `_res/scripts/components/player_movement_component.gd` | **Create** | Lateral movement |
| `_res/scripts/components/player_gravity_component.gd` | **Create** | Gravity smoothing + derivation |
| `_res/scripts/components/player_jump_component.gd` | **Create** | Jump mechanics |
| `_res/scripts/components/player_wall_jump_component.gd` | **Create** | Wall jump (disabled by default) |
| `_res/scripts/components/player_watering_component.gd` | **Create** | Watering lockout |
| `_res/scripts/components/player_visual_component.gd` | **Create** | Sprite rotation/flip/animation/squash |
| `_res/scripts/main.gd` | **No change** | Already compatible with public API |
| `_res/scripts/plant.gd` | **No change** | Already compatible |
| `_res/scripts/gravity_zone.gd` | **No change** | Already compatible |
| `_res/scripts/debugger.gd` | **No change** | Already compatible (reads player properties) |

---

## 4. Scene Setup Instructions

The `player.tscn` should have this hierarchy after refactoring:

```
Player (CharacterBody2D, player.gd)
├── PlayerAnimatedSprite2D (AnimatedSprite2D)
├── PlayerArea2D (Area2D)
│   └── PlayerCollisionShape2D (CollisionShape2D)
├── PlayerMovementComponent (Node, player_movement_component.gd)
├── PlayerGravityComponent (Node, player_gravity_component.gd)
├── PlayerJumpComponent (Node, player_jump_component.gd)
├── PlayerWallJumpComponent (Node, player_wall_jump_component.gd)
├── PlayerWateringComponent (Node, player_watering_component.gd)
└── PlayerVisualComponent (Node, player_visual_component.gd)
```

**Steps:**
1. Open `player.tscn`
2. Add 6 child `Node` nodes as listed above
3. Attach each component script to its respective node
4. Player's exported vars from components will appear in the inspector (via `@export` in components loaded as child nodes — they'll need to be on Player itself or the components exposed via Player's `@export` forwarding)

**⚠️ Note:** Since child `Node` exports don't show in the parent inspector automatically, the refactored `player.gd` will use `@export` forwarding — all designer-facing values remain on `Player` and are forwarded to components in `_ready()`.

---

## 5. Regression Checklist

- [ ] Horizontal movement feels identical (acceleration, friction, air control)
- [ ] Jump height and distance match original at `jump_height=200`, `jump_distance_to_peak=128`, `jump_distance_to_land=80`
- [ ] Variable jump height works (tap vs hold)
- [ ] Coyote time works (walk off ledge, jump within 0.12s)
- [ ] Jump buffer works (press jump just before landing)
- [ ] Gravity zone switching: gravity smoothly rotates + magnitude changes correctly
- [ ] Camera rotation follows gravity change (main.gd connection)
- [ ] Wall jump works when `enable_wall_jump = true` (disabled by default, matching commented-out call)
- [ ] Watering lockout freezes player, releases on completion/cancel
- [ ] Sprite rotates to match gravity, flips to face movement
- [ ] Animations: Idle, Run, Jump, Falling
- [ ] Death on hazard → `player_died = true` → restart_level
- [ ] Goal reach → `win_level()` + `change_level()`
- [ ] Debugger overlay still reads all properties correctly
- [ ] Squash/stretch optional, disabled by default