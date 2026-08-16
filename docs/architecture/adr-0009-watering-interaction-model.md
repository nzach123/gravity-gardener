# ADR-0009: Watering Interaction Model

## Status
Accepted

## Date
2026-08-15 (Accepted 2026-08-16)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Physics (2D), with Core frame-ordering facts consumed from ADR-0005/ADR-0007 |
| **Knowledge Risk** | LOW — no breaking changes to `Area2D`, `CharacterBody2D`, or `move_and_slide()` across 4.4–4.7 (`modules/physics-2d.md`); no breaking changes to `Node`/`SceneTree` either (`modules/core.md`) |
| **References Consulted** | `docs/engine-reference/godot/modules/physics-2d.md`, `docs/engine-reference/godot/modules/core.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None. `process_physics_priority` (4.1) is already established by ADR-0005; this ADR uses no API introduced after 4.3 |
| **Verification Required** | None new. The `CollisionShape2D` owner-reassignment claim in Migration Plan step 2 is confirmed by standing Godot scene-serialization semantics, not by any citation in this repo's `docs/engine-reference/godot/` set — none of the reference docs discuss node `owner`/scene-save behavior (godot-specialist validation, 2026-08-16) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted — `LevelState.carrying_bucket` read-write interface; `Plant.pour_completed` signal name and its `LevelRoot`-mediated wiring to `LevelState.consume_bucket()`), ADR-0004 (Accepted — detector layer/mask convention for the new Area2D nodes this ADR adds), ADR-0005 (Accepted — D5.5 clock-discipline rule, `frame_ordering_contract`), ADR-0007 (Accepted — `Player._physics_process` step 2, reserved for the watering lockout check) |
| **Enables** | ADR-0012 (spent jug throw) — consumes `Bucket.consume()`'s hand-off point |
| **Blocks** | None. HUD pour-prompt and burdened-read work (ADR-0010) reads `carrying_bucket`, already available via ADR-0002 |
| **Ordering Note** | None beyond Depends On |

## Context

### Problem Statement

`watering-system.md` R1–R5 need a concrete implementation: bucket pickup and carry, the time-based pour lock, early release, and the per-plant intake cap. TR-watering-009 (nearest plant with capacity) and TR-watering-010 (gravity-flip survival, area-exit equals early release) need a targeting mechanism. TR-watering-016 needs `Bucket` to stop extending `Node`.

One inherited conflict must be resolved first: ADR-0005's D5.5 text names `plant.gd` as the thing whose `water_progress` accumulation migrates to `_physics_process`, but the approved `watering-system.md` §6 Code table assigns pour-driving to `PlayerWateringComponent`, not `Plant` — written after D5.5, as part of the same refactor D5.5 anticipated. This ADR resolves the conflict in the GDD's favor (user decision, see Decision §1) and restates D5.5's clock-discipline rule for the actual owner.

### Constraints

- `LevelState.carrying_bucket` is already frozen as genuinely read-write (ADR-0002). This ADR must not add a setter method or otherwise narrow that interface.
- `Plant.pour_completed` is already a fixed signal name, wired by `LevelRoot` to `LevelState.consume_bucket()` (ADR-0002). This ADR must not rename it or wire it from anywhere but `LevelRoot`.
- `Player._physics_process` step 2 is frozen by ADR-0007 as the watering-lockout check (`if watering_component.is_watering: velocity = Vector2.ZERO, jump to step 8`). This ADR must fill in what sets `is_watering` without changing that step's shape or position.
- `water_duration` is a per-plant `@export`, not a `WateringTuning` field (`watering-system.md` §7 Placement). Any completion check must read it from the currently targeted `Plant`.
- Buckets and spent jugs are explicitly excluded from prop physics (`physics-props.md` §6) — no `RigidBody2D`, no `CollisionLayers.PROP`.

### Requirements

- Pickup on contact, one bucket carried at a time, refused pickups leave the second bucket untouched (R1).
- Carrying penalises `max_speed` only, never jump velocity (R2 — `TR-watering-002`; jump velocity is already bounded structurally by `gravity.md` R5 and `AC1`'s load-bearing status). **This ADR does not implement the `max_speed` penalty itself** — see Consequences → Negative.
- The pour accumulates only while interact is held inside the target plant's interact area, and locks player movement for the duration (R3).
- Early release — button release or leaving the interact area — zeroes progress and keeps the bucket, with no partial credit (R4).
- A capped plant refuses the interaction outright; the check must happen before any progress accumulates, not inside the accumulation loop (R5).
- Among overlapping interact areas, the nearest plant with remaining capacity is the target (TR-watering-009).
- A gravity flip must not interrupt a pour or spuriously toggle interact-area overlap (TR-watering-010).

## Decision

### 1 — Pour-driving lives on `PlayerWateringComponent` (resolves C3, C8)

**`PlayerWateringComponent` owns `water_progress`, the interact/target-plant check, and the completion and early-release logic**, matching `watering-system.md` §6's Code table. `Plant` "reports a completed pour and nothing more" — it holds `buckets_required` / `buckets_received`, the capacity check, and growth visuals, but drives no per-frame accumulation of its own.

This restates ADR-0005 D5.5 for the actual owner: *any quantity whose value on a specific frame decides completion belongs on the physics clock.* `water_progress` is exactly such a quantity — `AC13` depends on the pour resolving before the oxygen death check in the same frame batch (ADR-0005's frame contract). `PlayerWateringComponent`'s accumulation therefore runs inside `Player._physics_process`, at step 2, never in `_process`.

`PlayerWateringComponent` is a `Node`, present in the scene tree as a child of `Player` — the same shape as its sibling components (`PlayerGravityComponent`, `PlayerMovementComponent`, etc., all Accepted by ADR-0007). Like them, its script overrides neither `_process` nor `_physics_process`, so Godot never schedules it independently; `update_pour()` runs only when `Player._physics_process` calls it inline, at step 2. It is not a bare `RefCounted` and not scheduled by any `process_physics_priority` of its own.

**`Plant` carries no `process_physics_priority` assignment** (resolves C8). It has no per-frame rule-bearing work left once pour-driving moves off it — `ADR-0005` D5.1's diagram named `Plant` at priority 0 only because, at the time, `plant.gd` still drove its own accumulation. `Plant`'s growth-visual playback (`speed_scale`, `play()`) legitimately stays in `_process`, per D5.5's own cosmetic carve-out — it decides nothing on a specific frame.

**Rejected**: keeping pour-driving on `Plant`, per ADR-0005's literal D5.5 text. User decision. This would contradict the already-approved `watering-system.md` §6 Code table, which would then need to be reopened and amended — a design-document change, not an architecture one, and out of this ADR's authority to make unilaterally.

### 2 — `Player._physics_process` step 2, filled in

ADR-0007 froze the shape of step 2 (`if watering_component.is_watering: freeze, else: continue`) and reserved it for this ADR. The step now reads, immediately before that check:

```gdscript
# Step 2 (ADR-0007 slot, filled in by this ADR):
watering_component.update_pour(delta, Input.is_action_pressed("interact"))
# NOTE: reads the hold-input action directly. TR-watering-003's committed
# toggle alternative (accessibility-requirements.md, Motor) is not wired
# here — see Consequences → Negative.
if watering_component.is_watering:
    velocity = Vector2.ZERO
    # jump to step 8 — visuals still run unconditionally (ADR-0007 D7.3, AC9)
else:
    # continue to step 3 (gravity) — unchanged
```

`update_pour()` is the only place `is_watering`, `water_progress`, and the locked target change. No other code path may write them.

### 3 — Targeting: `LevelRoot`-mediated candidate registration

Each `Plant` owns a child `InteractArea2D` (detector: layer 0 / mask `PLAYER`, per `CollisionLayers.DETECTOR_MASK`, ADR-0004). `Plant` connects that area's `body_entered` / `body_exited` internally and re-broadcasts two signals of its own:

```gdscript
# Plant
signal player_entered_range
signal player_exited_range
signal pour_completed          # already fixed, ADR-0002

func is_capped() -> bool
func receive_pour() -> void     # increments buckets_received, updates growth, emits pour_completed
```

`LevelRoot`, at the same wiring step that already connects `Plant.pour_completed → LevelState.consume_bucket()` (ADR-0002 Migration Plan step 3d), adds two more connections per plant:

```gdscript
plant.player_entered_range.connect(player.watering_component.register_candidate.bind(plant))
plant.player_exited_range.connect(player.watering_component.unregister_candidate.bind(plant))
```

`PlayerWateringComponent` maintains `_candidates: Array[Plant]` — every plant the player currently overlaps, regardless of capacity. Nothing but this registration writes it.

**Two plants' interact areas can overlap the player at once**, and per ADR-0005 F2/D5.4, the delivery order between two *different* areas' `body_entered`/`body_exited` signals landing in the same physics-step batch is genuinely undetermined — the engine gives no ordering guarantee across areas. This is harmless here, unlike the race ADR-0005 D5.4 needed an idempotency latch for: `register_candidate`/`unregister_candidate` each touch only their own plant's entry in `_candidates`, an array with no shared field two calls could race on. Whichever of two plants' handlers runs first, the resulting array contents are the same.

```gdscript
func update_pour(delta: float, interact_held: bool) -> void:
    if is_watering:
        if not interact_held or _target_plant not in _candidates:
            _reset_pour()                                    # R4
        else:
            water_progress += delta
            if water_progress >= _target_plant.water_duration:
                _complete_pour()
    elif interact_held and carrying_bucket:
        var target := _nearest_available_candidate()          # TR-watering-009
        if target != null:
            _target_plant = target
            is_watering = true
            water_progress = 0.0

func _nearest_available_candidate() -> Plant:
    var best: Plant = null
    var best_dist_sq := INF
    for plant in _candidates:
        if plant.is_capped():
            continue
        var dist_sq := global_position.distance_squared_to(plant.global_position)
        if dist_sq < best_dist_sq:
            best_dist_sq = dist_sq
            best = plant
    return best
```

Re-targeting (the `_nearest_available_candidate()` scan) happens only while **not** watering. Once locked, the target is fixed until completion or early release (R3/R4) — this is what makes `_target_plant not in _candidates` the correct area-exit check: `_candidates` only loses an entry when that specific plant's area is exited, which is exactly TR-watering-010's "area exit equals early release," reusing the same list that drives targeting with no separate plumbing.

**Capacity is checked at target selection, never inside the accumulation loop.** A capped plant is never assigned to `_target_plant`, so `water_progress` never accumulates against one (R5, AC4) — the interaction "never engages," matching the GDD's wording exactly.

### 4 — Pickup, carry, and pour completion

```gdscript
# PlayerWateringComponent
var carrying_bucket: bool = false     # mirrored into LevelState.carrying_bucket
var is_watering: bool = false
var water_progress: float = 0.0
var _held_bucket: Bucket = null
var _target_plant: Plant = null
var _candidates: Array[Plant] = []

func register_candidate(plant: Plant) -> void
func unregister_candidate(plant: Plant) -> void
func pickup_bucket(bucket: Bucket) -> void
func update_pour(delta: float, interact_held: bool) -> void

func pickup_bucket(bucket: Bucket) -> void:
    if carrying_bucket:
        return                                    # R1 — refuse while already carrying
    _held_bucket = bucket
    bucket.on_picked_up()                          # stops monitoring (deferred — see on_picked_up())
    carrying_bucket = true
    level_state.carrying_bucket = true             # ADR-0002 interface

func _complete_pour() -> void:
    _target_plant.receive_pour()
    _held_bucket.consume()
    _held_bucket = null
    carrying_bucket = false
    level_state.carrying_bucket = false
    is_watering = false
    _target_plant = null
    water_progress = 0.0

func _reset_pour() -> void:                        # R4 — bucket retained
    is_watering = false
    _target_plant = null
    water_progress = 0.0
```

`Bucket` calls `pickup_bucket()` directly on the player it detects — a two-party spatial interaction, not level-wide state, so it does not need `LevelRoot` mediation the way `Plant.pour_completed` did:

```gdscript
class_name Bucket
extends Area2D                                      # TR-watering-016

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        body.watering_component.pickup_bucket(self)

func on_picked_up() -> void:
    set_deferred("monitoring", false)   # deferred: called from _on_body_entered, itself
                                         # fired during PhysicsServer2D::flush_queries() —
                                         # mutating Area2D.monitoring synchronously mid-flush
                                         # raises a runtime error; set_deferred() is the
                                         # engine-sanctioned fix. Stops detecting on pickup,
                                         # not only at pour completion — a carried bucket
                                         # (e.g. reparented onto a hand marker) would
                                         # otherwise keep monitoring and could re-fire
                                         # against anything else on the PLAYER mask

func consume() -> void:
    # monitoring is already false, set at on_picked_up() — this call is idempotent
    # the throw arc, tween, and eventual queue_free() are ADR-0012's —
    # this method only guarantees the bucket stops being pickable
```

`Bucket`'s own pickup detection is a detector area (layer 0 / mask `PLAYER`), the same ADR-0004 convention as `Plant.InteractArea2D`.

**`Bucket`'s root-type change is a scene restructure, not a script edit.** Today `bucket.tscn`'s root is a `Node2D` with a *child* `Area2D`, wired via an editor `[connection]`. Changing `Bucket` to `extends Area2D` moves the root node type itself, reparents `CollisionShape2D` directly under the new root, and moves the `body_entered` connection from editor-wired to code-wired in `_ready()` — three coupled edits to the one `.tscn`, not a one-line diff. Called out explicitly so the migration epic doesn't under-scope it.

### 5 — Gravity-flip survival (TR-watering-010, first clause)

No code in `PlayerWateringComponent`, `Plant`, or `Bucket` subscribes to `GravityAuthority.gravity_changed`. Interact-area and pickup-area overlap are pure `Area2D` layer/mask detection (ADR-0004), which does not consult gravity direction at all — a flip does not move the player's `CollisionShape2D`, so it cannot spuriously enter or exit an area. This holds automatically from the detector-layer convention; no additional code is needed, and none should be added.

**Rejected**: pausing or re-validating the pour on `gravity_changed`, "to be safe." Nothing about a flip threatens pour state, and subscribing to the signal only for this purpose would be the first coupling between watering and gravity broadcast — a coupling nothing in the GDD asks for and `watering-system.md` §5 explicitly rules out ("the pour is unaffected... the lock holds through the transition").

### Architecture Diagram

```
LevelRoot._ready()  [extends ADR-0002 step 3d]
  for each Plant:
    connect plant.pour_completed        → level_state.consume_bucket()      [ADR-0002]
    connect plant.player_entered_range  → player.watering_component.register_candidate.bind(plant)
    connect plant.player_exited_range   → player.watering_component.unregister_candidate.bind(plant)

Player._physics_process(delta)                                              [ADR-0007]
  step 1: up_direction sync                                                 [ADR-0007]
  step 2: watering_component.update_pour(delta, interact_held)  ← this ADR
          if is_watering: freeze, jump to step 8
  steps 3-7: gravity / wall-jump / jump / movement / move_and_slide         [ADR-0007]
  step 8: visual_component.update()  — unconditional                       [ADR-0007]

Bucket.body_entered(player) → player.watering_component.pickup_bucket(self)
Plant.InteractArea2D.body_entered/exited(player) → player_entered/exited_range → candidate list
```

### Key Interfaces

```gdscript
# PlayerWateringComponent
var carrying_bucket: bool
var is_watering: bool
var water_progress: float
func register_candidate(plant: Plant) -> void
func unregister_candidate(plant: Plant) -> void
func pickup_bucket(bucket: Bucket) -> void
func update_pour(delta: float, interact_held: bool) -> void

# Plant
signal player_entered_range
signal player_exited_range
signal pour_completed
func is_capped() -> bool
func receive_pour() -> void
@export var buckets_required: int
@export var water_duration: float

# Bucket
extends Area2D
func consume() -> void
```

## Alternatives Considered

### Alternative 1: Keep pour-driving on Plant (D5.5 literal reading)

- **Description**: Follow ADR-0005's D5.5 text as written; `Plant` keeps `process_physics_priority = 0` and drives its own `water_progress`.
- **Pros**: No conflict to resolve; ADR-0005's diagram stays literally accurate with no narrowing note.
- **Rejection Reason**: User decision (Decision §1). Contradicts the approved `watering-system.md` §6 Code table, which assigns pour-driving to `PlayerWateringComponent` by name.

### Alternative 2: PlayerWateringComponent polls `get_overlapping_bodies()` on every plant, every frame

- **Description**: Instead of a registered candidate list, `update_pour()` iterates all `Plant` nodes in a group and calls `interact_area.get_overlapping_bodies()` on each to find the player.
- **Pros**: No signal wiring needed; no `LevelRoot` involvement.
- **Rejection Reason**: Group-based discovery inside a per-frame gameplay loop is the same class of hazard ADR-0003 already rejected for `LevelValidation` (`group_based_level_discovery`) — invisible bookkeeping that silently drops a plant an author forgot to add to the group. A registered candidate list, wired explicitly by `LevelRoot` like every other cross-node connection in this project, keeps the wiring visible and testable.

### Alternative 3: Bucket pickup mediated by LevelRoot, like Plant's signals

- **Description**: `Bucket` emits a `picked_up` signal; `LevelRoot` connects it to `player.watering_component.pickup_bucket`.
- **Pros**: Consistent with the `Plant` wiring pattern; `Bucket` never references `Player` by type.
- **Cons**: `LevelRoot` would need to discover and wire every `Bucket` in the level in addition to every `Plant`, for a two-party interaction that does not touch shared level state the way `pour_completed → consume_bucket()` does.
- **Rejection Reason**: `Plant`'s mediation exists because `pour_completed` must reach `LevelState`, an object `Plant` has no reference to and should not be given (ADR-0002: "Plant receives no state at all"). Bucket pickup reaches only the `Player` node `Bucket` already detected via its own `body_entered` — no shared state object is involved, so the mediation `Plant` needs buys nothing here.

## Consequences

### Positive

- TR-watering-001, 003, 004, 005, 009, 010, and 016 gain a written ADR. `docs/architecture/tr-registry.yaml` moves these seven from `adr_status: not_written` to `accepted` once this ADR is Accepted. **TR-watering-002 is excluded** — this ADR does not implement the `max_speed` carry penalty; it remains `gap` (see GDD Requirements Addressed table and Consequences → Negative).
- The D5.5/GDD conflict (C3) is resolved in the approved GDD's favor, and ADR-0005's `frame_ordering_contract` gains a narrowing note rather than being silently contradicted.
- `LevelState.carrying_bucket` and `Plant.pour_completed`, both frozen by ADR-0002, are consumed exactly as specified — no new setter, no rename.
- Targeting and pour-lock maintenance share one data structure (`_candidates`), so TR-watering-009 and the area-exit half of TR-watering-010 need no separate implementation.

### Negative

- `Plant` gains two new signals (`player_entered_range`, `player_exited_range`) beyond the one ADR-0002 already fixed, growing its public surface.
- `Bucket` knows about the concrete `Player` type (`body is Player`), a small coupling Alternative 3 would have avoided at the cost of `LevelRoot` wiring every bucket in the level.
- **TR-watering-002 (carry `max_speed` penalty) remains unimplemented and unowned.** ADR-0007 previously flagged it as "gap, owned by ADR-0009" (`architecture.md:333`); this ADR does not close it. Wiring `carrying_bucket` into `PlayerMovementComponent.apply()` needs a new decision — most likely a new parameter on `apply()`, which reopens ADR-0007's frozen D7.3 signature and needs its own sign-off. Flagged here explicitly rather than left as a silent gap.
- **TR-watering-003's gesture-agnostic pour-abandonment requirement is not addressed.** `accessibility-requirements.md` T7 commits to a toggle alternative to the interact hold; `tr-registry.yaml`'s note on TR-watering-003 requires hold-release and toggle-press to fire the same event. This ADR's call site (`Input.is_action_pressed("interact")` at D7.3 step 2) reads the hold action directly and inline, with no abstraction a toggle handler could hook without editing this slot again. Flagged here explicitly rather than left as a silent gap — closing it needs a future decision for a toggle handler that drives `Input.action_press()`/`action_release()` so the read at this call site stays uniform regardless of input scheme.

### Risks

- **A future author re-adds `process_physics_priority` to `Plant`**, "for consistency" with `GravityAuthority` / `Player` / `OxygenDrain`, not realizing D5.5's per-frame requirement no longer applies to it. *Mitigation*: stated explicitly in Decision §1; the forbidden-pattern registry entry names this case.
- **A future author adds a `_physics_process` override to `PlayerWateringComponent`'s script** — plausibly by copy-pasting boilerplate from a sibling component. Godot auto-detects the override and starts scheduling it independently, so `update_pour()` would then run twice per frame: once via the phantom auto-call, once via `Player`'s existing inline call at step 2 — silently double-advancing `water_progress` and halving the effective `water_duration`. No compile error, no crash, just a pour that completes twice as fast as authored. *Mitigation*: stated explicitly in Decision §1; the forbidden-pattern registry entry names this case, the same class of hazard ADR-0005 already registered for `process_thread_group_split_in_frame_chain`.
- **A future author subscribes `PlayerWateringComponent` to `GravityAuthority.gravity_changed`** "to be safe" during a flip, coupling watering to gravity broadcast for no reason the GDD asks for. *Mitigation*: stated explicitly in Decision §5; forbidden-pattern registry entry.
- **`Bucket`'s direct reference to `Player.watering_component`** breaks with a null-property error if that property is ever renamed, with no compile-time signal beyond a runtime crash on the next pickup. *Mitigation*: `body is Player` guards the type; the property name itself has no automated check. Acceptable for a single-player-type project; revisit if a second body type is ever added to the `PLAYER` layer.
- **`_nearest_available_candidate()` is an O(n) scan over `_candidates`, run every physics frame while idle-and-carrying.** *Mitigation*: `n` is the count of interact areas simultaneously overlapping the player, bounded by level geometry to a handful at most — immeasurable against the 16.6 ms budget. Not a real risk, recorded so a future reviewer doesn't need to re-derive it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `watering-system.md` | R1 — buckets are single-use; pickup on contact; one carried at a time | `Bucket.consume()` disables further pickup; `PlayerWateringComponent.pickup_bucket()` refuses while `carrying_bucket` is true |
| `watering-system.md` | R2 / AC1 / TR-watering-002 — carry penalises `max_speed` only | **Not addressed by this ADR.** Nothing in Decision, Key Interfaces, or Migration Plan wires `carrying_bucket` into `PlayerMovementComponent.apply()` — ADR-0007's D7.3 signature has no carry-state parameter. TR-watering-002 remains `gap`; closing it needs a future decision adding that parameter, which reopens ADR-0007. Jump velocity remaining untouched is unaffected and already guaranteed structurally (`gravity.md` R5, ADR-0001's `recompute_jump_velocity` forbidden pattern) |
| `watering-system.md` | R3 — pour is time-based, held-input, and locks the player | `update_pour()` accumulates `water_progress` against the locked `_target_plant.water_duration`; `Player` step 2 freezes movement while `is_watering` |
| `watering-system.md` | R4 — early release keeps the bucket and resets progress | `_reset_pour()` zeroes `water_progress` and clears the lock without touching `carrying_bucket` or `_held_bucket` |
| `watering-system.md` | R5 / AC4 — plants cap intake at `buckets_required` | `Plant.is_capped()` excludes a capped plant from `_nearest_available_candidate()`; a capped plant is never assigned as `_target_plant`, so `water_progress` never accumulates against it |
| `watering-system.md` | §5 / TR-watering-003 — pour abandonment must be gesture-agnostic (accessibility toggle alternative) | **Not addressed by this ADR.** The call site reads `Input.is_action_pressed("interact")` directly with no toggle abstraction; see Consequences → Negative |
| `watering-system.md` | §5, AC12 / TR-watering-009 — nearest plant with remaining capacity | `_nearest_available_candidate()` scans `_candidates`, filtered by `is_capped()`, by squared distance |
| `watering-system.md` | §5 / TR-watering-010 — pour survives a gravity flip; area exit equals early release | Decision §5 (no `gravity_changed` coupling); Decision §3 (`_target_plant not in _candidates` triggers `_reset_pour()`) |
| `watering-system.md` | §6 — `Bucket` must stop declaring `extends Node` | `Bucket extends Area2D` (TR-watering-016) |

## Performance Implications

- **CPU**: One `update_pour()` call and, while idle-and-carrying, one bounded scan over `_candidates` per physics frame. Immeasurable against the 16.6 ms budget (see Risks).
- **Memory**: `_candidates` holds a handful of `Plant` references at most, sized by level geometry.
- **Load Time**: None. `Plant`'s two new signals need no preload or resource.
- **Network**: Not applicable.

## Migration Plan

`src/` does not yet implement `PlayerWateringComponent`'s pour-driving logic, the candidate-list targeting, or `Bucket` as an `Area2D` (verified 2026-08-15 against the session's known-bugs list, which finds `bucket.gd` and `plant.gd` still on the pre-refactor model). This ADR's migration lands with ADR-0002's and ADR-0007's, as one epic:

1. `plant.gd` — remove `water_progress` accumulation, the `water_duration` completion check, and the `_complete_watering()` / `_reset_watering()` calls (already scheduled for removal by ADR-0005's Migration Plan step 6, now retargeted: they move to `PlayerWateringComponent`, not merely to `_physics_process` on `Plant`). Add `is_capped()`, `receive_pour()`, `player_entered_range`, `player_exited_range`.
2. `bucket.tscn` / `bucket.gd` — **a scene restructure, not a one-line script edit** (see Decision §4). The root node type changes from `Node2D` to `Area2D`; the existing child `CollisionShape2D` reparents directly under the new root; the `body_entered` connection moves from the editor `[connection]` block to code in `_ready()`. Add `on_picked_up()` and `consume()`. Remove the `GameManager.carrying_bucket` write already scheduled for deletion by ADR-0002 step 6.
   Reparenting `CollisionShape2D` also requires re-setting its `owner` property to the new root node — the editor's reparent operation does not always carry this over, and an unset owner causes the shape to silently fail to persist when the scene is saved.
3. New `player_watering_component.gd` — implement `update_pour()`, `register_candidate()` / `unregister_candidate()`, `pickup_bucket()`, per Decision §2–4.
4. `main.gd` (`LevelRoot`) — extend the existing per-plant wiring loop (ADR-0002 step 3d) with the two new signal connections from Decision §3.

## Validation Criteria

- Unit test: a capped `Plant` (`buckets_received == buckets_required`) returns `true` from `is_capped()`, and a `PlayerWateringComponent` with that plant as the only candidate selects no target (AC4).
- Unit test: `_nearest_available_candidate()` returns the nearer of two candidates when both have capacity, and skips a nearer capped plant in favor of a farther uncapped one (AC12).
- Unit test: `_reset_pour()` leaves `carrying_bucket` unchanged and zeroes `water_progress` (AC3).
- Integration test: releasing interact mid-pour and re-approaching resets progress to zero, never partial (AC3).
- Integration test: a gravity flip mid-pour does not change `is_watering`, `water_progress`, or `_target_plant` (AC9, TR-watering-010).
- Integration test: `Bucket.consume()` followed by a second `body_entered` on the same (now-hidden) bucket does not re-trigger pickup (R1).

## Related Decisions

- **ADR-0002** — Level state ownership. Freezes `LevelState.carrying_bucket` (read-write) and `Plant.pour_completed`; this ADR extends the `LevelRoot` wiring step it defined but does not modify either interface.
- **ADR-0004** — Collision layer allocation. Supplies the detector layer/mask convention this ADR reuses for `Plant.InteractArea2D` and `Bucket`'s pickup area.
- **ADR-0005** — Frame ordering. D5.5 is restated here for its actual owner (Decision §1); `frame_ordering_contract` gains a narrowing note removing `Plant` from the priority table.
- **ADR-0007** — Player component contract. Freezes `Player._physics_process` step 2's shape; this ADR fills it in.
- **ADR-0012** (not yet written) — Spent jug throw. Owns what happens after `Bucket.consume()` — the tween arc, angle spread, and eventual `queue_free()`.
