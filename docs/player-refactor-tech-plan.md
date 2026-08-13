# Player Refactor — Technical Implementation Plan

**Date:** 2026-08-13
**Author:** Godot Specialist
**Status:** Approved — await implementation sign-off

---

## 0. Summary

Split the monolithic `player.gd` (~230 lines) into a lightweight `Player` facade + six child `Node` components, each owning a single gameplay concern. The external API (public properties, methods, signals) is preserved byte-for-byte — no other script changes.

---

## 1. Component API Design

### 1.1 PlayerMovementComponent (`player_movement_component.gd`)

**Responsibility:** Lateral acceleration, friction, ground/air control, camera-aware axis mapping.

```
class_name PlayerMovementComponent
extends Node

## Exports (forwarded from Player)
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

## Public API
func apply(
    delta: float,
    velocity: Vector2,          # IN/OUT — modified in place
    is_on_floor: bool,
    right_dir: Vector2,
    up_dir: Vector2,
    input_axis: float,
    camera_rotation_enabled: bool
) -> void
```

**Data flow:**
1. Compute lateral axis from `input_axis` — if `camera_rotation_enabled` is `false`, invert axis when gravity is flipped
2. `move_toward()` lateral speed toward target
3. Apply ground friction when no input + on floor
4. Rebuild velocity: `right_dir * lateral + up_dir * vertical`

**Pulled from original:** Lines 156–175 of `player.gd` (`_apply_movement`).

---

### 1.2 PlayerGravityComponent (`player_gravity_component.gd`)

**Responsibility:** Gravity magnitude derivation from jump params, smooth rotation & magnitude lerp toward target, ascent/descent gravity application, `up_dir`/`right_dir` derivation.

```
class_name PlayerGravityComponent
extends Node

## Exports (forwarded from Player)
@export var jump_height: float = 200.0
@export var jump_distance_to_peak: float = 128.0
@export var jump_distance_to_land: float = 80.0

## Runtime state (owned by this component)
var gravity: Vector2 = Vector2.ZERO
var target_gravity: Vector2 = Vector2.ZERO
var gravity_ascent_mag: float = 0.0
var gravity_descent_mag: float = 0.0
var ascent_descent_ratio: float = 1.0
var up_dir: Vector2 = Vector2.UP
var right_dir: Vector2 = Vector2.RIGHT

## Public API
func initialize() -> void
    # Called in _ready(). Derives gravity_ascent_mag, gravity_descent_mag,
    # jump_velocity, ascent_descent_ratio from jump params + max_speed.
    # Seeds gravity = Vector2(0, gravity_ascent_mag).

func set_gravity(new_vector: Vector2, max_speed: float) -> void
    # Called from Player.set_gravity().
    # Updates gravity_ascent_mag, gravity_descent_mag, target_gravity.
    # Re-derives jump_velocity so the JumpComponent can read it.

func update_derived_dirs() -> void
    # Computes up_dir = -gravity.normalized()
    # Computes right_dir = Vector2(-up_dir.y, up_dir.x)
    # Called at the top of _physics_process (before any other component).

func update_gravity_lerp(delta: float) -> void
    # Lerp angle + move_toward magnitude toward target_gravity.

func apply_gravity(delta: float, velocity: Vector2, is_on_floor: bool) -> void
    # Ascent/descent gravity application on velocity (IN/OUT).
```

**Data flow:**
1. `Player._ready()` → `gravity_component.initialize()` (needs `max_speed`)
2. `Player._physics_process()` → `gravity_component.update_derived_dirs()` then `update_gravity_lerp(delta)` then `apply_gravity(delta, velocity, is_on_floor)`
3. `Player.set_gravity(v)` → `gravity_component.set_gravity(v, max_speed)`
4. Other components read `gravity_component.up_dir`, `gravity_component.right_dir`, `gravity_component.gravity`

**Pulled from original:** `_ready()` gravity init, `_update_gravity()`, `_apply_gravity()`, `set_gravity()`.

---

### 1.3 PlayerJumpComponent (`player_jump_component.gd`)

**Responsibility:** Jump impulse, coyote time, jump buffer, variable jump height (early release), landing detection.

```
class_name PlayerJumpComponent
extends Node

## Exports (forwarded from Player)
@export var min_jump_velocity: float = 100.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

## Runtime state (owned by this component)
var jump_velocity: float = 0.0        # set by GravityComponent.init / set_gravity
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jumping: bool = false
var was_on_floor: bool = false

## Signals
signal jumped
signal landed

## Public API
func set_jump_velocity(v: float) -> void
    # Called by GravityComponent after deriving from jump params.

func update(
    delta: float,
    velocity: Vector2,          # IN/OUT
    is_on_floor: bool,
    up_dir: Vector2,
    right_dir: Vector2
) -> void
```

**Data flow:**
1. `GravityComponent` calls `jump_component.set_jump_velocity(v)` after deriving it
2. `Player._physics_process()` → `jump_component.update(delta, velocity, is_on_floor, up_dir, right_dir)`
3. Emits `jumped` → `PlayerVisualComponent` for animation/squash
4. Emits `landed` → `PlayerVisualComponent` for landing squash

**Pulled from original:** Lines 137–154 of `player.gd` (`_handle_jumping`).

---

### 1.4 PlayerWallJumpComponent (`player_wall_jump_component.gd`)

**Responsibility:** Wall detection, impulse upon jump press, cooldown timer. **Disabled by default** (matching the currently commented-out call in original code).

```
class_name PlayerWallJumpComponent
extends Node

## Exports (forwarded from Player)
@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15
@export var enable_wall_jump: bool = false

## Runtime state
var wall_jump_timer: float = 0.0

## Signals
signal wall_jumped

## Public API
func try(
    delta: float,
    velocity: Vector2,          # IN/OUT
    is_on_floor: bool,
    is_on_wall: bool,
    up_dir: Vector2,
    get_wall_normal: Callable    # Player passes a lambda wrapping get_wall_normal()
) -> void
```

**Why `get_wall_normal` as a `Callable`?**  
`is_on_wall()` and `get_wall_normal()` are `CharacterBody2D` methods. The component (a plain `Node`) cannot call them directly. Player passes them as arguments or callables. `is_on_wall` is passed as a bool (computed once per frame by Player), and `get_wall_normal` as a lambda: `func(): return get_wall_normal()`.

**Pulled from original:** Lines 126–133 of `player.gd` (`_handle_wall_jump`).

---

### 1.5 PlayerWateringComponent (`player_watering_component.gd`)

**Responsibility:** Watering lockout flag, current plant reference. **Minimal** — most watering logic lives in `plant.gd`.

```
class_name PlayerWateringComponent
extends Node

## Public properties (read/written by plant.gd)
var is_watering: bool = false
var current_plant: Plant = null

## Signals
signal watering_started
signal watering_stopped

## Public API
func lock() -> void
    # Sets is_watering = true, emits watering_started.
    # Called by Player._physics_process when the lockout check passes.

func unlock() -> void
    # Sets is_watering = false, current_plant = null, emits watering_stopped.
```

**Data flow:**
1. `plant.gd` sets `player.is_watering = true` and `player.current_plant = plant` directly
2. `Player` reads `watering_component.is_watering` to decide lockout
3. `plant.gd` sets `player.is_watering = false` on complete/cancel
4. `watering_started`/`watering_stopped` → `PlayerVisualComponent` for visual lock

**Note:** `Player.is_watering` and `Player.current_plant` remain as proxy properties on the facade (see §2).

---

### 1.6 PlayerVisualComponent (`player_visual_component.gd`)

**Responsibility:** Sprite rotation to match gravity, horizontal flip to face movement, animation state machine, optional squash & stretch (disabled by default).

```
class_name PlayerVisualComponent
extends Node

## Exports (forwarded from Player)
@export var squash_stretch_speed: float = 15.0
@export var scale_base: Vector2 = Vector2(2.0, 2.0)
@export var scale_jump: Vector2 = Vector2(1.6, 2.4)
@export var scale_land: Vector2 = Vector2(2.6, 1.4)
@export var scale_run: Vector2 = Vector2(2.2, 1.9)
@export var squash_stretch_enabled: bool = false

## Node ref (set in _ready)
var sprite: AnimatedSprite2D

## Signals (received)
# jumped, landed, wall_jumped, watering_started, watering_stopped
# Connected by Player in _ready().

var land_squash_timer: float = 0.0
var was_on_floor: bool = false
var is_jumping: bool = false

## Public API
func update(
    delta: float,
    velocity: Vector2,
    is_on_floor: bool,
    right_dir: Vector2,
    up_dir: Vector2,
    input_axis: float,
    gravity: Vector2,
    camera_rotation_enabled: bool
) -> void
```

**Data flow:**
1. Receives signals from Jump/WallJump/Watering components
2. `update()` is called last in `_physics_process`, after `move_and_slide()`

**Pulled from original:** Lines 180–217 of `player.gd` (`_update_visuals`).

---

## 2. Player Facade Design (`player.gd` — refactored)

The refactored `Player` class is a thin orchestrator: owns exported vars, forwards them to components, runs the physics loop, and exposes the external API.

### 2.1 Exported properties (all preserved)

```gdscript
@export_group("Movement")
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

@export_group("Jump")
@export var jump_height: float = 200.0
@export var jump_distance_to_peak: float = 128.0
@export var jump_distance_to_land: float = 80.0
@export var min_jump_velocity: float = 100.0

@export_group("Timing")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

@export_group("Wall Jump")
@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15

@export_group("Squash and Stretch")
@export var squash_stretch_speed: float = 15.0
@export var scale_base: Vector2 = Vector2(2.0, 2.0)
@export var scale_jump: Vector2 = Vector2(1.6, 2.4)
@export var scale_land: Vector2 = Vector2(2.6, 1.4)
@export var scale_run: Vector2 = Vector2(2.2, 1.9)
```

### 2.2 Component references

```gdscript
@onready var sprite: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var col_shape: CollisionShape2D = $PlayerArea2D/PlayerCollisionShape2D

@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var gravity_component: PlayerGravityComponent = $PlayerGravityComponent
@onready var jump_component: PlayerJumpComponent = $PlayerJumpComponent
@onready var wall_jump_component: PlayerWallJumpComponent = $PlayerWallJumpComponent
@onready var watering_component: PlayerWateringComponent = $PlayerWateringComponent
@onready var visual_component: PlayerVisualComponent = $PlayerVisualComponent
```

### 2.3 Proxy properties (preserve external contract)

```gdscript
## Proxy — plant.gd reads/writes this; debugger.gd reads it
var camera_rotation_enabled: bool = true

## Proxy — hazard.gd sets; plant.gd reads
var player_died: bool = false

## Proxy — plant.gd reads/writes
var is_watering: bool:
    get: return watering_component.is_watering
    set(v): watering_component.is_watering = v

## Proxy — plant.gd writes
var current_plant: Plant:
    get: return watering_component.current_plant
    set(v): watering_component.current_plant = v

## Proxy — debugger.gd reads
var target_gravity: Vector2:
    get: return gravity_component.target_gravity

## Proxy — debugger.gd reads
var right_dir: Vector2:
    get: return gravity_component.right_dir

## Proxy — debugger.gd reads
var up_dir: Vector2:
    get: return gravity_component.up_dir
```

### 2.4 `_ready()`

```gdscript
func _ready() -> void:
    # Forward exports to components
    _forward_exports()

    # Initialize gravity (needs max_speed to derive jump_velocity)
    gravity_component.initialize(max_speed)

    # Give derived jump_velocity to jump component
    jump_component.set_jump_velocity(gravity_component.jump_velocity)

    # Give sprite reference to visual component
    visual_component.sprite = sprite

    # Wire component signals
    jump_component.jumped.connect(_on_jumped)
    jump_component.landed.connect(_on_landed)
    wall_jump_component.wall_jumped.connect(_on_wall_jumped)
    watering_component.watering_started.connect(_on_watering_started)
    watering_component.watering_stopped.connect(_on_watering_stopped)
```

### 2.5 `_forward_exports()` helper

```gdscript
func _forward_exports() -> void:
    movement_component.max_speed        = max_speed
    movement_component.ground_accel     = ground_accel
    movement_component.ground_friction  = ground_friction
    movement_component.air_accel        = air_accel

    gravity_component.jump_height           = jump_height
    gravity_component.jump_distance_to_peak = jump_distance_to_peak
    gravity_component.jump_distance_to_land = jump_distance_to_land

    jump_component.min_jump_velocity  = min_jump_velocity
    jump_component.coyote_time        = coyote_time
    jump_component.jump_buffer_time   = jump_buffer_time

    wall_jump_component.wall_jump_h_force  = wall_jump_h_force
    wall_jump_component.wall_jump_v_force  = wall_jump_v_force
    wall_jump_component.wall_jump_cooldown = wall_jump_cooldown

    visual_component.squash_stretch_speed = squash_stretch_speed
    visual_component.scale_base           = scale_base
    visual_component.scale_jump           = scale_jump
    visual_component.scale_land           = scale_land
    visual_component.scale_run            = scale_run
```

### 2.6 `_physics_process(delta)` — execution order

```gdscript
func _physics_process(delta: float) -> void:
    # 1. Watering lockout
    if watering_component.is_watering:
        velocity = Vector2.ZERO
        return

    # 2. Derive directions from current gravity
    gravity_component.update_derived_dirs()

    # 3. Smooth gravity rotation + magnitude toward target
    gravity_component.update_gravity_lerp(delta)

    # 4. Apply ascent/descent gravity to velocity
    gravity_component.apply_gravity(delta, velocity, is_on_floor())

    # 5. Wall jump (only if enabled)
    if wall_jump_component.enable_wall_jump:
        wall_jump_component.try(
            delta, velocity, is_on_floor(), is_on_wall(),
            gravity_component.up_dir,
            func(): return get_wall_normal()
        )

    # 6. Jump (coyote, buffer, release, landing)
    jump_component.update(
        delta, velocity, is_on_floor(),
        gravity_component.up_dir, gravity_component.right_dir
    )

    # 7. Lateral movement
    var input_axis: float = Input.get_axis("move_left", "move_right")
    movement_component.apply(
        delta, velocity, is_on_floor(),
        gravity_component.right_dir, gravity_component.up_dir,
        input_axis, camera_rotation_enabled
    )

    # 8. Resolve collisions
    move_and_slide()

    # 9. Visuals
    visual_component.update(
        delta, velocity, is_on_floor(),
        gravity_component.right_dir, gravity_component.up_dir,
        input_axis, gravity_component.gravity, camera_rotation_enabled
    )
```

### 2.7 External API (preserved)

```gdscript
func set_gravity(new_vector: Vector2) -> void:
    gravity_component.set_gravity(new_vector, max_speed)
    jump_component.set_jump_velocity(gravity_component.jump_velocity)

func win_level() -> void:
    pass
```

---

## 3. Data Flow Diagram

```
                    ┌──────────────────────────────┐
                    │         Player (facade)        │
                    │  @exports → _forward_exports() │
                    │  proxy props → external reads  │
                    └──────────┬───────────────────┘
                               │ owns & orchestrates
       ┌───────────────────────┼───────────────────────┐
       │                       │                       │
       ▼                       ▼                       ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ GravityComp  │    │   JumpComponent   │    │ MovementComp     │
│              │    │                   │    │                  │
│ gravity ─────┼────├─ jump_velocity ◄─┼────┤ max_speed etc.   │
│ up_dir ──────┼────├─ coyote/buffer    │    │ apply()          │
│ right_dir ───┼────├─ update(velocity) │    │                  │
│ set_gravity()│    │ signals: jumped,  │    │                  │
│ apply()      │    │          landed   │    │                  │
└──────┬───────┘    └────────┬─────────┘    └──────────────────┘
       │                     │
       │    ┌────────────────┤
       │    │                │
       ▼    ▼                ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ WallJumpComp │    │ WateringComp     │    │ VisualComponent  │
│              │    │                  │    │                  │
│ enable flag  │    │ is_watering      │    │ sprite ref       │
│ try()        │    │ current_plant    │    │ update()         │
│ signal:      │    │ signals: start,  │    │ receives: jumped │
│   wall_jumped│    │         stop     │    │          landed  │
└──────────────┘    └──────────────────┘    │          wall_   │
                                            │          jumped  │
                                            │          watering│
                                            └──────────────────┘
```

---

## 4. Scene Changes (`player.tscn`)

Add 6 child `Node` nodes under Player:

```
Player (CharacterBody2D, player.gd)
├── PlayerAnimatedSprite2D (AnimatedSprite2D)     ← existing
├── PlayerCollisionShape2D (CollisionShape2D)     ← existing
├── PlayerArea2D (Area2D)                         ← existing
│   └── PlayerCollisionShape2D (CollisionShape2D) ← existing
├── CanvasLayer                                   ← existing
│   └── Debugger                                  ← existing
├── PlayerMovementComponent (Node)                ← NEW
├── PlayerGravityComponent (Node)                 ← NEW
├── PlayerJumpComponent (Node)                    ← NEW
├── PlayerWallJumpComponent (Node)                ← NEW
├── PlayerWateringComponent (Node)                ← NEW
└── PlayerVisualComponent (Node)                  ← NEW
```

Each new node:
- Type: `Node` (no transform, no rendering — pure logic)
- Script: assigned to the respective `.gd` file
- Name: must match the `@onready var` names in the facade

---

## 5. Edge Cases & Defensive Checks

### 5.1 Missing components
If a component node is missing from the scene, `@onready` will be `null`. The facade should guard:

```gdscript
func _physics_process(delta: float) -> void:
    if not gravity_component or not movement_component or not jump_component:
        return  # silently skip — components not ready
```

### 5.2 Initialization order
`_ready()` runs parent-first (Player before children). This is correct — Player's `_ready()` configures components, then children's `_ready()` can safely run.

### 5.3 `camera_rotation_enabled` propagation
This flag is checked in both `MovementComponent.apply()` and `VisualComponent.update()`. It's passed as a parameter each frame (not cached) so runtime toggling works.

### 5.4 `set_gravity()` called before `_ready()`
`main.gd` connects `gravity_changed` signals in its `_ready()`. Since `main.gd` is a child of the level scene root, and Player is deeper, Player's `_ready()` runs before `main.gd`'s signal connections. Safe.

### 5.5 Plant sets `is_watering` mid-frame
`plant.gd` runs `_process()` (not `_physics_process()`), while Player runs `_physics_process()`. The property set takes effect immediately, and Player's next physics frame will see it. No race condition.

### 5.6 `jump_velocity` re-derivation
When `set_gravity()` is called (gravity zone change), both `GravityComponent` and `JumpComponent` must agree on `jump_velocity`. Player's `set_gravity()` calls both:

```gdscript
func set_gravity(new_vector: Vector2) -> void:
    gravity_component.set_gravity(new_vector, max_speed)
    jump_component.set_jump_velocity(gravity_component.jump_velocity)
```

---

## 6. Files to Create / Modify

| # | File | Action | Lines (est.) |
|---|------|--------|-------------|
| 1 | `_res/scripts/player.gd` | **Rewrite** | ~130 lines |
| 2 | `_res/scripts/components/player_movement_component.gd` | **Create** | ~55 lines |
| 3 | `_res/scripts/components/player_gravity_component.gd` | **Create** | ~75 lines |
| 4 | `_res/scripts/components/player_jump_component.gd` | **Create** | ~70 lines |
| 5 | `_res/scripts/components/player_wall_jump_component.gd` | **Create** | ~40 lines |
| 6 | `_res/scripts/components/player_watering_component.gd` | **Create** | ~30 lines |
| 7 | `_res/scripts/components/player_visual_component.gd` | **Create** | ~85 lines |
| 8 | `_res/scenes/player/player.tscn` | **Edit** | Add 6 Node children |

**Total new code:** ~485 lines across 7 files (6 new + 1 rewrite).  
**Original `player.gd`:** ~230 lines → ~130 lines (facade).

**No changes needed:** `main.gd`, `plant.gd`, `gravity_zone.gd`, `spike_hazard.gd`, `goal.gd`, `debugger.gd`, `gamemanager.gd`.

---

## 7. Implementation Task List

### Phase 1 — Create component scripts (order: least-dependent first)

| Step | Task | File | Depends On |
|------|------|------|-----------|
| 1.1 | Create `player_watering_component.gd` | New | Nothing |
| 1.2 | Create `player_gravity_component.gd` | New | Nothing |
| 1.3 | Create `player_jump_component.gd` | New | GravityComponent (reads jump_velocity) |
| 1.4 | Create `player_movement_component.gd` | New | Nothing |
| 1.5 | Create `player_wall_jump_component.gd` | New | Nothing |
| 1.6 | Create `player_visual_component.gd` | New | Nothing |

### Phase 2 — Rewrite Player facade

| Step | Task | File | Depends On |
|------|------|------|-----------|
| 2.1 | Rewrite `player.gd` as slim facade | Modify | All 6 components exist |

### Phase 3 — Update scene

| Step | Task | File | Depends On |
|------|------|------|-----------|
| 3.1 | Add 6 child `Node` nodes to Player scene | `player.tscn` | All scripts exist |
| 3.2 | Assign scripts to each new node | `player.tscn` | All scripts exist |
| 3.3 | Name nodes to match `@onready` references | `player.tscn` | Facade written |

### Phase 4 — Verification

| Step | Task | Method |
|------|------|--------|
| 4.1 | Launch test level, verify no console errors | Run `test_main.tscn` |
| 4.2 | Run regression checklist from design doc | Manual playtest |
| 4.3 | Verify debugger overlay reads all properties | Check debugger panel |
| 4.4 | Test gravity zone transitions | Walk through zones |
| 4.5 | Test watering lockout | Interact with plant |
| 4.6 | Test hazard death → restart | Touch spikes |
| 4.7 | Test goal reach → level change | Water all plants, reach goal |

---

## 8. Rollback Plan

If the refactor introduces a regression that cannot be quickly fixed:

1. Revert `player.gd` to the original monolithic version (git checkout)
2. Delete the 6 component files from `_res/scripts/components/`
3. Remove the 6 child Node nodes from `player.tscn`

No other files are touched, so rollback is clean and instantaneous.

---

## 9. Known Limitations / Future Improvements

1. **Export forwarding is manual.** If a designer changes an export on Player, it only takes effect on next scene load (because `_forward_exports()` runs in `_ready()`). A `@tool` script with setters could make it real-time, but adds complexity. Not needed for v1.

2. **Squash & stretch is disabled.** The current code has it commented out. The `VisualComponent` will include the commented-out code for easy re-enabling.

3. **Wall jump is disabled.** Controlled by `enable_wall_jump = false` on `PlayerWallJumpComponent`. This matches current behavior (the `_handle_wall_jump` call is commented out).

4. **No unit tests.** Godot 4's GDScript test framework (GUT) could be added later for component-level tests. Currently not in scope.