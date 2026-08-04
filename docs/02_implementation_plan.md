# Implementation Plan: Hold-E Watering Mechanic + Goal Unlock

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Plant destroyed after watering? | **Remains**, transitions to watered idle | The plant is an objective marker, not a collectible. It must stay visible so the player can see progress. Multiple plants per level need persistent state. |
| Timer resets on early release? | **Resets to 0** | Standard "hold to interact" pattern. Creates tension — the player commits to 5 seconds of vulnerability. |
| Player can move while holding [E]? | **No** — movement locked | The 5s hold is the core challenge. Allowing movement would trivialize it. Player must find a safe position. |
| Goal unlocked state communication? | **GameManager flag** (`goal_unlocked`) | Autoload persists across scene reloads. Cleaner than signals for cross-scene state. |
| Goal's `body.items` check? | **Replaced** with `GameManager.goal_unlocked` | The items array was a placeholder for the old system. The new unlock state is authoritative. |
| AnimatedSprite2D vs AnimationPlayer? | **AnimatedSprite2D is sufficient** | The 6-frame "Filling" animation stretched via `speed_scale` to fill 5 seconds is clean and simple. No AnimationPlayer needed. |
| Multiple plants per level? | **All must be watered** | GameManager tracks `plants_watered` / `plants_total`. Goal unlocks when all are done. |

---

## Scaffolding Checklist

### New variables
- `GameManager.goal_unlocked: bool = false`
- `GameManager.plants_watered: int = 0`
- `GameManager.plants_total: int = 0`
- `Player.is_watering: bool = false`
- `Player.current_plant: Plant = null`
- `Plant.water_progress: float = 0.0`
- `Plant.is_watered: bool = false`
- `Plant.water_duration: float = 5.0`
- `Goal.is_unlocked: bool = false`

### New signals
- `Plant.plant_watered` — emitted when watering completes
- `Goal.goal_activated` — emitted when goal becomes enterable (optional)

### New methods
- `Player._handle_interact()` — checks for `interact` input, manages watering state
- `Plant._process_watering(delta)` — advances progress while player holds E in range
- `Plant._complete_watering()` — marks plant done, emits signal, updates GameManager
- `Goal._update_unlocked_state()` — checks GameManager and updates visuals

### Scene changes
- `plant.tscn`: Connect `InteractArea2D.body_exited` → `_on_interact_body_exited`
- `goal.tscn`: Add "locked" animation to `AnimationPlayer` (or use AnimatedSprite2D "Idle" for locked, "goal_interact" for unlocked)

### Input map
- No changes — `interact` (E) already exists.

---

## Ordered Tasks

### Task 1: Add GameManager state variables

- **File(s) affected**: `gamemanager.gd`
- **What to add/modify/delete**:
  - Add `var goal_unlocked: bool = false`
  - Add `var plants_watered: int = 0`
  - Add `var plants_total: int = 0`
  - Add `func reset_level_state() -> void` that resets `goal_unlocked`, `plants_watered`, `plants_total` to defaults (called on level load).
- **Dependencies**: None (first task).
- **Verification**: Add a temporary `print()` in `_ready()` of any scene to confirm autoload values are accessible. Check that `GameManager.goal_unlocked` is `false` at startup.

---

### Task 2: Rewrite Plant script — body enter/exit tracking + hold-to-water logic

- **File(s) affected**: `plant.gd`, `plant.tscn`
- **What to add/modify/delete**:
  - **Remove**: `@export var item: String`, the old `_on_interact_body_entered` body (instant collect + queue_free).
  - **Add variables**:
    - `var water_progress: float = 0.0`
    - `var is_watered: bool = false`
    - `@export var water_duration: float = 5.0`
    - `var player_in_range: Player = null`
  - **Add signal**: `signal plant_watered`
  - **Rewrite `_on_interact_body_entered`**: If body is Player, set `player_in_range = body`. Start playing "Filling" if not already watered.
  - **Add `_on_interact_body_exited`**: If body is Player, set `player_in_range = null`. Reset `water_progress = 0.0`. Set animation to "Idle" (or frame 0 of "Filling").
  - **Add `_process(delta)`**: If `player_in_range != null` and `!is_watered` and `Input.is_action_pressed("interact")`:
    - Lock player movement: `player_in_range.is_watering = true`
    - Advance `water_progress += delta`
    - Drive animation: `animated_sprite_2d.speed_scale = 3.0 / water_duration`
    - If `water_progress >= water_duration`: call `_complete_watering()`.
    - If `Input.is_action_just_released("interact")`: reset `water_progress = 0.0`, unlock player.
  - **Add `_complete_watering()`**: Set `is_watered = true`. Set animation to "Idle" (watered frame). Emit `plant_watered`. Increment `GameManager.plants_watered`. If `GameManager.plants_watered >= GameManager.plants_total`, set `GameManager.goal_unlocked = true`. Unlock player.
- **Scene changes** (`plant.tscn`):
  - Connect `InteractArea2D.body_exited` → `_on_interact_body_exited`.
  - Set initial animation to "Idle" (not "Filling").
- **Dependencies**: Task 1 (GameManager variables).
- **Verification**: Place a plant in a test level. Walk into range — animation should start "Filling" only while holding E. Release E — progress resets, animation stops. Hold E for 5s — plant transitions to "Idle", `GameManager.plants_watered` increments. Print debug to confirm.

---

### Task 3: Add watering state + movement lock to Player

- **File(s) affected**: `player.gd`
- **What to add/modify/delete**:
  - **Add variables**:
    - `var is_watering: bool = false`
    - `var current_plant: Plant = null` (optional, for future UI reference)
  - **Modify `_physics_process`**: At the very top, add early return: `if is_watering: return` (skip all movement, gravity, and visual updates). This locks the player in place.
  - **Add `_input(event)` or `_process` check**: When `is_watering` is true and `interact` is released, the Plant's `_process` handles the reset. But we also need the Player to know when it's unlocked. The Plant sets `player_in_range.is_watering = false` on release/completion.
  - **Remove or deprecate**: `items: Array[String]` and `collect(item)` — no longer needed. (Can be removed now or in a cleanup task.)
- **Dependencies**: Task 2 (Plant sets `is_watering` on the player).
- **Verification**: Walk into plant range, hold E. Player should freeze in place (no movement, no gravity). Release E — player resumes normal movement. Hold E for full 5s — player unlocks after completion.

---

### Task 4: Rewrite Goal — replace items check with GameManager flag

- **File(s) affected**: `goal.gd`, `goal.tscn`
- **What to add/modify/delete**:
  - **Add variable**: `var is_unlocked: bool = false`
  - **Modify `_on_body_entered`**: Replace `if body.items:` with `if GameManager.goal_unlocked:` (or check `is_unlocked` synced from GameManager).
  - **Add `_process(delta)` or `_ready` polling**: Continuously check `GameManager.goal_unlocked`. When it flips to `true`, set `is_unlocked = true`, play "goal_interact" animation (or use AnimationPlayer for a transition), change sprite to indicate it's active.
  - **Visual states**:
    - **Locked** (default): Show "Idle" or "goal_begin" animation. Area2D could be disabled or just visually distinct.
    - **Unlocked**: Show "goal_interact" animation. Area2D active.
  - **Alternative simpler approach**: In `_on_body_entered`, just check `GameManager.goal_unlocked` directly. Keep the visual always showing "goal_begin" when locked and "goal_interact" when unlocked (poll in `_process`).
- **Dependencies**: Task 1 (GameManager.goal_unlocked), Task 2 (plants set the flag).
- **Verification**: Before watering any plants, walk into goal — nothing happens. Water all plants — goal animation changes, walk into goal — level changes.

---

### Task 5: Update main.gd — initialize plant count, handle scene reload

- **File(s) affected**: `main.gd`
- **What to add/modify/delete**:
  - In `_ready()`: Count all plants in the scene and set `GameManager.plants_total`. Connect each plant's `plant_watered` signal if needed (or let plants self-manage via GameManager).
    ```gdscript
    var plants = get_tree().get_nodes_in_group("plants")
    GameManager.plants_total = plants.size()
    GameManager.plants_watered = 0
    GameManager.goal_unlocked = false
    ```
  - Ensure plants are in group `"plants"` (add to `plant.tscn`).
  - In `restart_level()`: Call `GameManager.reset_level_state()` before reloading (or the reload itself will re-trigger `_ready` which resets counts).
- **Dependencies**: Task 1, Task 2, Task 4.
- **Verification**: Place 2 plants in a level. Check `GameManager.plants_total == 2`. Water one — `plants_watered == 1`, goal still locked. Water both — goal unlocks. Die and restart — counts reset to 0.

---

### Task 6: Add plant to "plants" group in scene

- **File(s) affected**: `plant.tscn`
- **What to add/modify/delete**: Add `"plants"` to the Plant node's groups in the scene file (or via editor).
- **Dependencies**: Task 5.
- **Verification**: `get_tree().get_nodes_in_group("plants")` returns all plants in the level.

---

### Task 7: Cleanup — remove deprecated items system

- **File(s) affected**: `player.gd`, `goal.gd`
- **What to add/modify/delete**:
  - Remove `var items: Array[String]` from Player.
  - Remove `func collect(item)` from Player.
  - Remove the old `if body.items:` check from Goal (already replaced in Task 4).
- **Dependencies**: Task 4 (Goal no longer references `body.items`).
- **Verification**: Game compiles and runs without errors. No references to `items` or `collect` remain.

---

### Task 8: Polish — animation tuning and edge cases

- **File(s) affected**: `plant.gd`, `goal.gd`
- **What to add/modify/delete**:
  - **Plant**: Tune `speed_scale` calculation so the 6-frame "Filling" animation exactly spans `water_duration`. Formula: `animated_sprite_2d.speed_scale = 3.0 / water_duration` (since default speed 2.0 plays 6 frames in 3 seconds; to stretch to 5 seconds, multiply by 3/5 = 0.6).
  - **Plant**: On early release, reset animation to frame 0 of "Idle" (not "Filling" frame 0) so the plant looks inactive.
  - **Goal**: Use the existing `AnimationPlayer` to create a "goal_activate" animation (scale pulse, color flash) that plays when `GameManager.goal_unlocked` becomes true.
  - **Edge case**: If player dies while watering, `is_watering` must be reset. Add `player_died` check in Plant's `_process` to release the lock.
  - **Edge case**: If player is in range of multiple plants, only the first one that captured `player_in_range` should respond. The current design (one `player_in_range` per plant) handles this naturally since each plant has its own Area2D.
- **Dependencies**: Tasks 1–7.
- **Verification**: Visual check — filling animation smoothly progresses over 5s. Release early — snaps back to idle. Die while watering — player resets properly on restart. Two overlapping plants — only the one whose area you're in responds.

---

## Summary of Signal Flow (Final State)

```
Player holds [E] in Plant's InteractArea2D
  → Plant._process() advances water_progress, locks Player.is_watering
  → AnimatedSprite2D "Filling" plays at stretched speed
  → On completion: Plant._complete_watering()
      → GameManager.plants_watered += 1
      → If plants_watered >= plants_total: GameManager.goal_unlocked = true
      → Plant plays "Idle", emits plant_watered

Goal._process() polls GameManager.goal_unlocked
  → When true: plays activation animation, enables Area2D

Player enters GoalArea2D
  → Goal._on_body_entered() checks GameManager.goal_unlocked
  → If true: emits player_reached_goal → main.gd changes level
```