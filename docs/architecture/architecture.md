# Gravity Gardener — Master Architecture

## Document Status

- Version: 1.0
- Last Updated: 2026-08-13
- Engine: Godot 4.7 (GL Compatibility, 2D)
- GDDs Covered: `gravity.md`, `watering-system.md`, `suit-oxygen.md`, `physics-props.md`
- Technical Requirements Baseline: 52 requirements (TR-gravity / TR-watering / TR-oxygen / TR-props)
- ADRs Referenced: none exist — 12 required, see Required ADRs
- Technical Director Sign-Off: 2026-08-13 — **APPROVED WITH CONDITIONS**
- Lead Programmer Feasibility: SKIPPED — Lean review mode (`production/review-mode.txt`)

### Sign-off conditions

1. All 6 Foundation ADRs (ADR-0001 … ADR-0006) accepted before implementation
   begins. This is a hard gate: 0 of 52 requirements are covered by an accepted
   decision today.
2. ~~C1 — `GravityAuthority` prop registry has no lifecycle counterpart~~
   **Resolved 2026-08-13**: `unregister_prop()` added to the contract.
3. ~~C2 — `nearest_acceptable_plant()` had no specified input~~
   **Resolved 2026-08-13**: in-range plant tracking inverted to the watering
   component and specified.

Criteria 1 (requirement coverage) and 4 (Foundation ADR gaps) of gate
TD-ARCHITECTURE are unmet by design at this stage — writing the ADRs is the
next action, not a remediation.

## Engine Knowledge Gap Summary

Verified 2026-08-13 by web search against the Godot 4.7 class reference and
release notes. Findings persisted to
`docs/engine-reference/godot/modules/ui-control.md` and `physics-2d.md`.

**No HIGH RISK domains remain.** The initial inventory flagged Control offset
transforms as HIGH because two required scenes (oxygen HUD, pause menu) do not
exist and there was no module reference to check against. Verification closed it:

| Domain | Initial | Verified | Basis |
|---|---|---|---|
| Control offset transforms (4.7) | HIGH | LOW | Full property set and defaults confirmed against the class reference |
| Accessibility / screen reader (4.5+) | MEDIUM | MEDIUM | Real but experimental; `.POT` extraction gap is open (godot#115366) |
| 2D physics | LOW | LOW | No `RigidBody2D`/`Area2D`/`CharacterBody2D` changes 4.4 → 4.7 |
| Jolt Physics (4.6) | — | N/A | 3D only. `project.godot` sets it, but this is a 2D game; the setting is inert |
| AreaLight3D, HDR, stencil | — | N/A | Project renders GL Compatibility 2D |

Two facts from verification constrain decisions below:

1. **`offset_transform_visual_only` defaults to `true`** — input hit-testing uses
   the un-offset layout rect. Harmless for the oxygen HUD (no input); a trap for
   an animated pause menu, where the visible button and the clickable button
   would diverge. Clear the flag explicitly on any animated interactive Control.
2. **`offset_transform_enabled` defaults to `false`** — every other
   `offset_transform_*` property is inert without it. `gravity_zone.tscn:38` sets
   it correctly; that scene is the reference example.

One capability worth recording even though no GDD requires it:
`CollisionShape2D.one_way_collision_direction` (new in 4.7) allows one-way
collision in an arbitrary direction. Under rotating gravity a one-way platform
authored for "up" is wrong in every rotated room, so this removes a constraint
that would otherwise have shaped level design.

## System Layer Map

```
┌────────────────────────────────────────────────────────────────────┐
│ PRESENTATION   PlayerVisualComponent · HUD* · PauseMenu* ·         │
│                StartMenu · Camera rotation · PhysicsProps* ·       │
│                SpentJugThrow* · Debugger                           │
├────────────────────────────────────────────────────────────────────┤
│ FEATURE        GravityZone · Plant · Bucket ·                      │
│                PlayerWateringComponent · Goal(airlock) ·           │
│                SpikeHazard/KillArea · MovingPlatform               │
├────────────────────────────────────────────────────────────────────┤
│ CORE           Player facade · PlayerGravityComponent ·            │
│                PlayerMovementComponent · PlayerJumpComponent ·     │
│                PlayerWallJumpComponent · OxygenDrain*              │
├────────────────────────────────────────────────────────────────────┤
│ FOUNDATION     GameManager · LevelRoot(main.gd) · GravityAuthority*│
│                LevelValidation* · Tuning Resources* ·              │
│                CollisionLayerRegistry                              │
├────────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7 · GL Compatibility · 2D physics server ·  │
│                Input map (A/D · Space · E · Shift)                 │
└────────────────────────────────────────────────────────────────────┘
                                            * = does not exist yet
```

| Module | Layer | Owns exclusively | Status |
|---|---|---|---|
| `GameManager` | Foundation | Cross-level concerns; holds injectable state objects | Exists, needs rework |
| `LevelRoot` (`main.gd`) | Foundation | Wiring, restart path, level transition, camera | Exists |
| `GravityAuthority` | Foundation | The one global gravity vector + broadcast | **New** |
| `LevelValidation` | Foundation | Load-time contract checks | **New** |
| Tuning resources | Foundation | `WateringTuning` / `OxygenTuning` / `PropTuning` `.tres` | **New** |
| `CollisionLayerRegistry` | Foundation | Layer/mask allocation | Partial |
| `Player` facade | Core | Physics-step ordering | Exists |
| `PlayerGravityComponent` | Core | Gravity basis, asymmetry ratio, derived `jump_velocity` | Exists |
| `PlayerMovementComponent` | Core | `max_speed`, accel/friction, carry penalty | Exists |
| `PlayerJumpComponent` | Core | Coyote, buffer, variable height | Exists |
| `PlayerWallJumpComponent` | Core | Wall jump | Exists, undocumented |
| `OxygenDrain` | Core | Per-frame drain, threshold state, death trigger | **New** |
| `PlayerWateringComponent` | Feature | Carry state, held-bucket ref, pour driving | Stub only |
| `Plant` | Feature | `buckets_required`/`received`, intake cap, growth stage | Exists, over-reaching |
| `Bucket` | Feature | Pickup, consumption | Exists, wrong base class |
| `GravityZone` | Feature | Zone direction + multiplier declaration | Exists |
| `Goal` (airlock) | Feature | Unlock presentation, `player_reached_goal` | Exists, no change needed |
| `HUD` | Presentation | Oxygen readout, thresholds, carry indicator | **New** |
| `PhysicsProps` | Presentation | Cosmetic rigid bodies | **New** |
| `PlayerVisualComponent` | Presentation | Sprite rotation, squash/stretch, animation | Exists |

### Binding layer decisions

**D1 — Gravity is owned by a `GravityAuthority` autoload (Foundation).**
`gravity.md` R9 defines gravity as world state and AC12 requires props to adopt a
new vector on the same frame the player does. Today the vector lives in
`PlayerGravityComponent` and `main.gd` wires each zone directly to
`player.set_gravity`, leaving props with nothing to read. `GravityAuthority` holds
the vector and emits `gravity_changed`; zones report to it, and the player and all
props subscribe. This makes R9 structural rather than conventional, and lets AC12
be tested with no `Player` instance.

*Consequence:* `PlayerGravityComponent` stops owning `gravity`/`target_gravity` and
becomes a consumer that derives its basis, asymmetry and `jump_velocity` from the
broadcast vector. Its derivation math (`initialize()`, `apply_gravity()`) is
unchanged.

**D2 — Level state moves into injectable state objects owned by `LevelRoot`.**
*(Amended 2026-08-14 by ADR-0002 — see the revision note below.)*
All three GDDs assign state to `GameManager`, an autoload;
`.claude/docs/coding-standards.md` requires dependency injection over singletons
and demands every public method be unit-testable. Every Logic-type acceptance
criterion across the GDDs must run headlessly. The state therefore moves into
plain `RefCounted` objects — `LevelState` (bucket counters, `goal_unlocked`, carry
state) and `OxygenState` (`remaining`, `capacity`, thresholds) — which tests
construct directly. `GameManager` keeps only cross-level concerns.

**`LevelRoot` constructs and owns both objects and injects them into consumers.**

> **Revision note.** As originally written, D2 had `GameManager` *hold* the two
> objects and clear them in `reset_level_state()`. ADR-0002 moved ownership to
> `LevelRoot` on a user decision taken 2026-08-14. The deciding argument:
> `reset_level_state()` exists only because an autoload survives
> `reload_current_scene()`, and `restart_level()` already reloads the scene. Under
> `LevelRoot` ownership the reload discards both objects and `_ready()` builds
> fresh ones, so `watering-system.md` AC8 and `suit-oxygen.md` AC4/AC5 hold by
> construction instead of depending on a hand-maintained reset function — a
> function that is *already* missing `carrying_bucket` today. `reset_level_state()`
> is deleted and neither object has a `reset()`. Full reasoning, including the
> three rejected alternatives, is in ADR-0002.

*Consequence:* the ownership lines in `watering-system.md` §6 and
`suit-oxygen.md` §6 named `GameManager` directly. **Both were amended on
2026-08-14**, closing Open Question QQ-01.

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `GravityAuthority` *(autoload)* | `gravity`, `target_gravity`, `baseline_ascent_mag`, `ascent_descent_ratio`, ease rate | `gravity_changed(dir, mult)`, `current_gravity`, `up_dir`, `right_dir`, `set_gravity()` | Zone declarations | `Node`, `Signal`, `lerp_angle`, `PhysicsServer2D` |
| `GameManager` *(autoload)* | `player_lives` — cross-level concerns only *(ADR-0002)* | — | — | `Node` |
| `LevelState` *(RefCounted)* | `buckets_consumed`, `buckets_total`, `goal_unlocked`, `carrying_bucket`, `level_complete` | `consume_bucket()`, `goal_unlocked_changed` signal | — | `RefCounted` |
| `OxygenState` *(RefCounted)* | `remaining`, `capacity`, threshold band | `drain(delta)`, `fraction`, `depleted`, `threshold_changed` | `OxygenTuning` | `RefCounted` |
| `LevelRoot` (`main.gd`) | Wiring, camera, `next_level`, restart path. **Constructs and owns `LevelState` + `OxygenState`, and injects them** *(ADR-0002)* | `restart_level()`, `change_level()` | Everything below | `Node2D`, `Camera2D`, `SceneTree`, `Tween` |
| `LevelValidation` | Load-time contract rules | `validate(level) -> Array[String]` | `LevelState`, plants, props | `push_error` |
| Tuning resources | Watering / Oxygen / Prop constants | `@export` properties | — | `Resource` (`.tres`) |
| `CollisionLayerRegistry` | Layer/mask allocation | Named constants | — | `project.godot` `layer_names` |

#### Collision layer allocation

This is what makes `physics-props.md` R2 hold *by construction* rather than by
careful coding.

| Bit | Name | Status | Who masks it |
|---|---|---|---|
| 1 | `world` | exists | player, props |
| 2 | `player` | exists | gravity zones, hazards, pickups |
| 3 | `item` | exists | player only |
| 4 | `prop` | **new** | props only |

Props sit on layer 4 and mask `world | prop`. The player never masks 4 and props
never mask 2 or 3, so AC1 and AC2 — "a prop never collides with the player / with
a plant, bucket, or the airlock" — become structurally impossible to violate.

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `Player` facade | Physics-step ordering, export forwarding | Proxy properties, `win_level()` | All components | `CharacterBody2D`, `move_and_slide()`, `is_on_floor/wall()`, `Input` |
| `PlayerGravityComponent` | Derived basis, magnitudes, `jump_velocity` | `up_dir`, `right_dir`, `jump_velocity`, `apply_gravity()` | `GravityAuthority.gravity_changed` | `Node`, `Vector2` |
| `PlayerMovementComponent` | `max_speed`, accel, friction | `apply()` | Basis dirs, carry multiplier | `Node` |
| `PlayerJumpComponent` | Coyote, buffer, `min_jump_velocity` | `update()`, `jumped`, `landed` | `jump_velocity`, `Input` | `Node`, `Input` |
| `PlayerWallJumpComponent` | Wall-jump forces, cooldown | `try()`, `wall_jumped` | `get_wall_normal()` | `Node` |
| `OxygenDrain` | Nothing — drives `OxygenState` | `depleted` fan-out | `OxygenState`, `OxygenTuning`, pause state | `Node`, `_process` |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `GravityZone` | `zone_gravity_direction`, `zone_gravity_multiplier`, `zone_priority` ⚠ unread | `gravity_changed` | — | `Area2D`, `CollisionShape2D`, `ColorRect` + `offset_transform_*` |
| `PlayerWateringComponent` | `is_watering`, `held_bucket`, `water_progress`, `current_plant` | `lock()`, `unlock()`, `watering_started/stopped` | `Input`, `Plant`, `Bucket`, `LevelState` | `Node`, `Input` |
| `Plant` | `buckets_required`, `buckets_received`, growth stage | `can_accept()`, `accept_pour()`, `pour_completed` | — | `Node2D`, `Area2D`, `AnimatedSprite2D` |
| `Bucket` | Pickup/consumed state | `pick_up()`, `consume()` | — | `Area2D` *(currently `Node`)*, `Tween` |
| `Goal` (airlock) | `is_unlocked` | `player_reached_goal` | `LevelState.goal_unlocked` | `Node2D`, `Area2D`, `AnimatedSprite2D` |

### Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `PhysicsProps` | `mass`, damping, friction, authored transform | — *(pure consumer)* | `GravityAuthority.gravity_changed`, `PropTuning` | `RigidBody2D`, `sleeping`, `VisibleOnScreenNotifier2D` |
| `HUD` | Readout widgets | — | `OxygenState`, `LevelState` | `CanvasLayer`, `Control`, `ProgressBar`, `Label` |
| `PlayerVisualComponent` | Sprite scale/rotation state | `update()`, signal handlers | Velocity, basis dirs, gravity | `AnimatedSprite2D`, `Tween` |

### Dependency direction

```
        GravityZone ──set──▶ GravityAuthority ──gravity_changed──┬──▶ PlayerGravityComponent
                                                                 ├──▶ PhysicsProps
                                                                 └──▶ LevelRoot (camera)

  PlayerWateringComponent ──▶ Plant ──pour_completed──▶ LevelState ──goal_unlocked──▶ Goal
                          └──▶ Bucket

              OxygenDrain ──▶ OxygenState ──depleted──▶ LevelRoot.restart_level()
                                          └──────────▶ HUD
```

Nothing in Foundation reads upward. `Goal` and `HUD` observe `LevelState` rather
than being told by `Plant` — exactly what `watering-system.md` R6 asks for: "no
single plant should be deciding whether the room is breathable."

### Binding ownership decisions

**D3 — Props receive gravity through default-space gravity, not per-prop force.**
`GravityAuthority` writes the vector and magnitude to the default 2D space:

```gdscript
var space := get_viewport().find_world_2d().space
PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, dir)
PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY,
        g_descent_baseline * multiplier * prop_tuning.prop_gravity_scale)
```

Space gravity is naturally symmetric, satisfying `physics-props.md` R4 with no
extra code, and it reaches every `RigidBody2D` on the same physics frame, which
gives AC4 and `gravity.md` AC12 structurally rather than by convention. It costs
no per-prop per-frame work against the 40-prop budget (R8).

This does not affect the player: `CharacterBody2D` ignores space gravity, and the
player's gravity stays manual in `PlayerGravityComponent.apply_gravity()` where
the ascent/descent asymmetry (R4 of `gravity.md`) lives.

Props must still be force-woken on every change — space gravity does not wake
sleeping bodies. This remains the R5 bug `physics-props.md` warns about and is
`GravityAuthority`'s responsibility, not each prop's.

```
⚠️  PhysicsServer2D.area_set_param(AREA_PARAM_GRAVITY_VECTOR) — 2D physics, LOW risk
    Verified against: docs/engine-reference/godot/modules/physics-2d.md
    Behaviour confirmed: yes (2D physics unchanged 4.4 → 4.7)
    Exact enum spelling: confirm at implementation time
```

**D4 — `GravityZone`'s built-in area gravity override is cleared now.**
`gravity_zone.tscn` sets `gravity_space_override = 3` and `gravity = -980.0` on
the `Area2D`. This is inert today because the only body entering a zone is the
player, and `CharacterBody2D` ignores space gravity.

It stops being inert the moment props exist: the override would give props
**per-region** gravity from the physics server, contradicting `gravity.md` R9
("no per-body or per-region gravity") and breaking AC12. It would present as
props behaving correctly only while inside a zone's bounds — a hard bug to read.

`gravity_space_override` is therefore set to `0` (disabled) as part of the
`GravityAuthority` Foundation work, not deferred to the props epic. The change is
behaviourally neutral today and removes the trap before anything depends on it.

## Data Flow

### Frame update path

`process_priority` makes tick order explicit rather than an accident of tree
layout (**D5**).

| Priority | Node | Responsibility |
|---|---|---|
| `-100` | `GravityAuthority` | Ease direction, push space gravity, force-wake props |
| `0` | `Player` + components | Pour progress, movement, `move_and_slide()` |
| `+50` | `Goal` | Airlock entry resolves |
| `+100` | `OxygenDrain` | Drain, **then** death check |

```
GravityAuthority._physics_process(Δ)
   ├─ lerp_angle toward target                      (gravity.md R3)
   ├─ PhysicsServer2D.area_set_param(space, …)      (D3)
   └─ for prop in props: prop.sleeping = false      (props R5)
        │
        ▼
Player._physics_process(Δ)
   ├─ if watering: accumulate water_progress, velocity = ZERO, return
   ├─ update_derived_dirs()   ◀── reads GravityAuthority.gravity
   ├─ apply_gravity() → wall jump → jump → movement (× carry multiplier)
   └─ move_and_slide()
        │
        ▼
Goal._physics_process — airlock entry → level_complete = true
        │
        ▼
OxygenDrain._physics_process(Δ)
   ├─ OxygenState.drain(Δ)
   └─ if remaining <= 0 and not level_complete: → restart_level()
```

**D5 — Frame ordering is a contract, not a detail.** This ordering is what makes
two otherwise-contradictory acceptance criteria pass by construction:

- `watering-system.md` AC13 — final pour on the frame oxygen hits zero must yield
  **death, not completion**. The pour resolves at priority `0`, the death check at
  `+100`. The pour completes and the player still dies. ✅
- `suit-oxygen.md` AC8 — airlock entry on the frame oxygen hits zero must
  **complete the level**. The `level_complete` guard set at `+50` suppresses the
  death check at `+100`. ✅

`level_complete` is the single piece of state separating these two criteria.
Without it they directly contradict each other. Any change to this ordering or to
that flag breaks one of the two ACs — treat both as load-bearing.

### Event / signal path

Every cross-module link is a signal. No module calls upward.

| Signal | Producer | Consumer(s) |
|---|---|---|
| `gravity_changed(dir, mult)` | `GravityZone` | `GravityAuthority` |
| `gravity_changed(dir, mult)` | `GravityAuthority` | `PlayerGravityComponent`, `PhysicsProps`, `LevelRoot` (camera) |
| `pour_completed` | `Plant` | `LevelState` |
| `goal_unlocked` | `LevelState` | `Goal`, `HUD` |
| `threshold_changed(band)` | `OxygenState` | `HUD` |
| `depleted` | `OxygenState` | `OxygenDrain` *(**not** `LevelRoot.restart_level()` — corrected by ADR-0002. `depleted` is a pure state signal meaning "the tank is empty" and carries no policy. `OxygenDrain` owns the kill decision, including the `level_complete` suppression that `suit-oxygen.md` AC8 requires. Wiring this straight to `restart_level()` breaks AC8)* |
| `inc_hazard_dmg` | `SpikeHazard` | `LevelRoot.restart_level()` *(exists)* |
| `player_reached_goal` | `Goal` | `LevelRoot.change_level()` *(exists)* |

`Plant` emitting `pour_completed` and nothing else is the structural fix for
`watering-system.md` R6. Today `plant.gd:76-79` reaches into `GameManager` and
decides the level is over.

### Persistence path

**There is no save system, and no GDD asks for one.** Oxygen explicitly does not
carry between levels (`suit-oxygen.md` R5) and watering state resets fully on
restart. Persistence means exactly two operations:

| Operation | Mechanism | Owner |
|---|---|---|
| Level transition | `change_scene_to_packed(next_level)` | `LevelRoot` |
| Level restart | `reload_current_scene()` alone — the reload discards `LevelState` / `OxygenState` and `_ready()` builds fresh ones *(ADR-0002)* | `LevelRoot` |

Scene reload rebuilds the tree, which gives `physics-props.md` R6 / AC8 — props
return to authored transforms — for free. No prop bookkeeping is needed.

**D6 — Levels declare a default gravity; `LevelRoot._ready()` restores it.**
D1 introduces a regression that cannot occur in the current design: gravity lives
on the player today, so scene reload resets it automatically. An autoload
**survives scene reload**, so without this the player would restart a level
carrying whatever gravity they died under.

Each level root therefore exports `default_gravity_direction` and
`default_gravity_multiplier`, and `LevelRoot._ready()` restores
`GravityAuthority` to them at init step 3e. This covers first load and restart
with one mechanism — restart is a scene reload, which re-runs `_ready()` — and
makes a level's starting orientation explicit and authorable rather than implied.

*(Amended 2026-08-14: originally `reset_level_state()` did the restoring. ADR-0002
deletes that function; the call moves to `LevelRoot._ready()`, which already ran on
both paths. No behavioural change.)*

*Consequence:* all 8 existing levels need the export added. No GDD covers this
requirement — it is a direct consequence of D1.

### Initialisation order

**D7 — Jump constants stay as `@export`s on `Player`; the ordering hazard is
guarded, not designed away.**

The alternative was moving them into a `GravityTuning` resource, which would have
deleted the hazard outright since resources load before any `_ready()`. Keeping
them on `Player` preserves designer knobs on the node they already live on, at the
cost that `gravity.md` §5's "initialisation order is load-bearing" edge case stays
live and must remain in the GDD.

Two mitigations are mandatory:

1. `GravityAuthority.initialize(baseline_ascent_mag, ratio)` is public API, called
   by `Player._ready()`. Tests seed it directly with known values, so AC12 remains
   testable without instantiating a `Player`.
2. `GravityAuthority` refuses to broadcast before `initialize()` has been called —
   an explicit guard that pushes an error, rather than silently broadcasting a
   1.0 ratio and losing the ascent/descent asymmetry.

Godot calls `_ready()` bottom-up, so `Player` (a child of the level root)
initialises before `LevelRoot`. The order resolves cleanly:

*(Corrected 2026-08-14 by ADR-0002. The original had `HUD._ready()` binding to
`OxygenState`/`LevelState` at step 2, before `LevelRoot` creates them at step 3 —
impossible under bottom-up `_ready()`. Binding is a step-3 activity, and every
consumer guards against use before bind.)*

```
1. Autoloads      GameManager, GravityAuthority   (uninitialised, guarded)
2. Level children, bottom-up
   ├─ Player._ready()   derive baseline → GravityAuthority.initialize(…)
   ├─ Plants, Buckets, Props, Zones _ready()
   └─ HUD._ready()      build widgets ONLY — must not touch state yet
3. LevelRoot._ready()   (parent, last)
   a. construct LevelState(buckets_total) and OxygenState(capacity, tuning)
   b. LevelValidation.validate(level)   → push_error on contract breach
   c. bind state into Player, Goal, HUD, OxygenDrain
   d. connect each Plant.pour_completed → LevelState.consume_bucket()
   e. GravityAuthority.reset_to(default_gravity_*)   → first broadcast
   f. wire zones → GravityAuthority ; register props → GravityAuthority
```

`TR-gravity-011` (the hardcoded `32.0` ease rate) is not closed by this decision
and still needs an explicit export on `GravityAuthority`.

## API Boundaries

### Foundation

```gdscript
# GravityAuthority — autoload. The single source of the world gravity vector.
extends Node

signal gravity_changed(direction: Vector2, multiplier: float)

@export var direction_ease_rate: float = 32.0      # closes TR-gravity-011

var gravity: Vector2
var up_dir: Vector2
var right_dir: Vector2

func initialize(baseline_ascent_mag: float, ascent_descent_ratio: float) -> void
func reset_to(direction: Vector2, multiplier: float) -> void
func set_gravity(direction: Vector2, multiplier: float) -> void
func register_prop(prop: RigidBody2D) -> void
func unregister_prop(prop: RigidBody2D) -> void
func ascent_magnitude() -> float
func descent_magnitude() -> float
```

`unregister_prop()` is not optional. `physics-props.md` R7 frees props that leave
level bounds, so without it the registry accumulates freed references and D3's
per-frame force-wake loop iterates invalid instances. `PropBody` calls it from
`_exit_tree()`, which covers both R7 freeing and scene reload.

**Callers must:** call `initialize()` before any `set_gravity()` / `reset_to()`
(D7); pass `multiplier > 0` and a non-zero direction.

**Guarantees:** `ascent_descent_ratio` never changes after `initialize()`
(gravity AC4) · `jump_velocity` is never recomputed (gravity R5) · every
registered prop is woken on the same frame the vector changes (gravity AC12) · a
rejected change leaves gravity untouched (gravity AC7).

```gdscript
class_name LevelState extends RefCounted

signal goal_unlocked_changed(unlocked: bool)

var buckets_total: int
var buckets_consumed: int
var carrying_bucket: bool
var goal_unlocked: bool      # derived, read-only
var level_complete: bool     # D5 — suppresses the oxygen death check

func _init(buckets_total: int) -> void
func consume_bucket() -> void
```

**Callers must:** pass `buckets_total` at construction (immutable thereafter); call
`consume_bucket()` only on a completed pour.

**Guarantees:** `goal_unlocked` flips true exactly when
`buckets_consumed >= buckets_total` and never before (watering AC6) · **no
`reset()`** — restart discards the object and `LevelRoot` builds a fresh one, so
carry state cannot survive (watering AC8, the defect at `gamemanager.gd:12`).
*(ADR-0002 — `reset()` was removed from this contract.)*

```gdscript
class_name OxygenState extends RefCounted

enum Band { NOMINAL, CAUTION, WARNING, CRITICAL }
signal depleted
signal threshold_changed(band: Band)

var capacity: float
var remaining: float
var fraction: float

func _init(capacity: float, tuning: OxygenTuning) -> void
func drain(delta: float) -> void
```

**Callers must:** pass `capacity > 0` at construction — an invalid `OxygenState` is
not constructible, so oxygen AC7's runtime failure mode is unreachable
(`LevelValidation` still reports it at load, for authoring feedback); call
`drain()` exactly once per physics frame.
*(ADR-0002 — `configure()` became constructor injection; `reset()` was removed.)*

**Guarantees:** `remaining` never increases by any path (oxygen AC3) · `depleted`
emits once · drain is unconditional across every player state (oxygen AC1).

```gdscript
class_name LevelValidation
static func validate(level: Node) -> PackedStringArray
```

Checks `buckets_total == Σ buckets_required` (watering AC7) ·
`oxygen_capacity > 0` (oxygen AC7) · prop count ≤ `props_per_level_budget`
(props §7) · every plant `buckets_required >= 1`.

**Guarantees:** returns **all** failures rather than the first; never fails
silently. The caller `push_error()`s each. `watering-system.md` R8 is explicit
that a silently unwinnable level is the dangerous failure mode, and a level can
breach the bucket contract and the oxygen contract simultaneously — returning one
at a time would take two runs to discover.

### Feature

```gdscript
class_name Plant extends Node2D

signal pour_completed(plant: Plant)

@export var buckets_required: int = 1
@export var water_duration: float = 5.0
var buckets_received: int

func can_accept() -> bool
func accept_pour() -> void
func growth_fraction() -> float
```

**Callers must:** call `accept_pour()` only when `can_accept()` is true.

**Guarantees:** `buckets_received` never exceeds `buckets_required` (watering
AC4) · **never touches `GameManager` or `LevelState`** (watering R6).

`Plant` becomes passive — it no longer drives watering in `_process`, which is
where `plant.gd` currently holds it. This is the largest behavioural change in
the set, and it is what makes watering AC12 expressible at all: a plant cannot
know whether a *different* plant is nearer to the player.

```gdscript
class_name Bucket extends Area2D          # was `extends Node` — TR-watering-016

signal picked_up(bucket: Bucket)

func can_pick_up() -> bool
func pick_up() -> void
func consume(gravity_basis: Vector2) -> void   # throw arc, then queue_free (R7)
```

**Guarantees:** static — position never responds to a gravity change (watering
AC11) · freed within `throw_duration + 0.1 s` (AC10) · no physics body and no
collision while in flight.

```gdscript
class_name PlayerWateringComponent extends Node

signal watering_started
signal watering_stopped
signal pour_completed(plant: Plant)

var is_watering: bool
var held_bucket: Bucket
var water_progress: float

func try_pick_up(bucket: Bucket) -> bool
func update(delta: float, interact_held: bool) -> void
func enter_plant_range(plant: Plant) -> void
func exit_plant_range(plant: Plant) -> void
func nearest_acceptable_plant() -> Plant
```

**Guarantees:** at most one held bucket; a second pickup is refused and left in
the world (watering AC5) · early release zeroes `water_progress` and retains the
bucket (AC3) · `nearest_acceptable_plant()` skips capped plants (AC12).

**In-range plant tracking.** `Plant`'s `InteractArea2D` reports body entry and
exit to the player's watering component rather than to the plant itself, and the
component holds the in-range set. This inversion is required, not stylistic:
AC12 asks for the *nearest plant with remaining capacity*, and a plant cannot
know whether a different plant is nearer. It is also what makes `Plant` passive
per its own contract above.

`nearest_acceptable_plant()` filters the in-range set by `can_accept()` and
returns the closest survivor, or `null` when every plant in range is capped — in
which case no interaction engages and no progress accumulates (watering §5).

### Presentation

```gdscript
class_name PropBody extends RigidBody2D
# collision_layer = PROP(4) ; collision_mask = WORLD(1) | PROP(4)
```

**Callers must never:** add the `player` or `item` bits to the mask. Props AC1
and AC2 are enforced by layer allocation, not by conditional logic (props R2).

**Guarantees:** pure consumer — emits no signals and mutates no gameplay state
(props R1).

## ADR Audit

`docs/architecture/` did not exist before this session. **No ADRs exist**, so
there is nothing to audit for engine compatibility, version recording, GDD
linkage or conflicts with the decisions made here.

The binding decisions D1–D7 are currently recorded **only in this document**.
That is the gap the Required ADRs section closes.

### Traceability coverage

**0 of 52 requirements covered. 52 gaps.**

| Bucket | Count | Disposition |
|---|---|---|
| Assigned to a new ADR | 50 | See Required ADRs |
| Parked by GDD design | 1 | `TR-gravity-008` — `zone_priority`. `gravity.md` R8 parks it explicitly, and D1's global broadcast keeps it parked: with one vector in play, overlap is an ordering question, not a spatial one |
| Implemented and stable | 1 | `TR-gravity-010` — camera rotation, working in `main.gd` |

## Required ADRs

### Must exist before any coding starts — Foundation

| ADR | Title | Covers |
|---|---|---|
| ADR-0001 | Gravity ownership and global broadcast | `TR-gravity-001/002/003/009/011/012`, `TR-props-001/004` · D1, D3, D4, D6, D7 |
| ADR-0002 | Level state ownership and injectable state objects | `TR-watering-006/011`, `TR-oxygen-005/012` · D2 |
| ADR-0003 | Level load validation contract | `TR-watering-008/015`, `TR-oxygen-008`, `TR-props-007` |
| ADR-0004 | Collision layer allocation | `TR-props-002` |
| ADR-0005 | Frame ordering and the `level_complete` guard | `TR-watering-012`, `TR-oxygen-010` · D5 |
| ADR-0006 | Tuning resource strategy | `TR-watering-013`, `TR-oxygen-011`, `TR-props-009` |

### Before the relevant system is built — Core & Feature

| ADR | Title | Covers |
|---|---|---|
| ADR-0007 | Player component contract and physics step order | `TR-gravity-004/005/006/007/013`, `TR-watering-002/014` |
| ADR-0008 | Oxygen drain and the shared death path | `TR-oxygen-001/002/003/004/006` |
| ADR-0009 | Watering interaction model | `TR-watering-001/003/004/005/009/010/016` |

### Can defer to implementation — Presentation

| ADR | Title | Covers |
|---|---|---|
| ADR-0010 | HUD architecture and Control offset transform usage | `TR-watering-017/018`, `TR-oxygen-007/009` |
| ADR-0011 | Physics props implementation | `TR-props-003/005/006/008` |
| ADR-0012 | Spent jug throw and lifetime | `TR-watering-007` |

### Acceptance ordering constraints

- **ADR-0005 before ADR-0008 or ADR-0009.** The frame ordering is what lets
  watering AC13 and oxygen AC8 coexist. Either system implemented first without
  it will encode the contradiction between them.
- **ADR-0004 before ADR-0011.** Props AC1/AC2 hold by construction only if the
  layer allocation exists before the first prop does.

ADR-0001 absorbs five of the seven binding decisions because D3, D4, D6 and D7
are consequences of D1 rather than independent choices. Splitting them would
produce four ADRs that cannot be read or accepted separately.

## Architecture Principles

**P1 — One gravity vector governs everything.**
Gravity is world state, not player state (`gravity.md` R9). There is no per-body,
per-region or per-system gravity. Any feature that needs an object to disagree
with the room's gravity is a design change requiring `gravity.md` to be revised
first, not an implementation detail.

**P2 — Contracts are enforced by structure, not by discipline.**
Where a rule can be made impossible to break, it is: collision layers rather than
`if` statements for prop isolation (props R2), `process_priority` rather than
convention for the death-check ordering (D5), a single owner for the unlock
decision rather than cooperating plants (watering R6). A rule that depends on
every future author remembering it is not enforced.

**P3 — Geometric guarantees outrank feel knobs.**
`jump_velocity` is fixed and never recomputed (`gravity.md` R5/R10). This is what
lets level design prove a gap is crossable from the zone multiplier alone. Any
change that gives a second independent lever over reachability — carry weight,
power-ups, per-level jump tuning — breaks that proof and is rejected by default.
Watering AC1 is the automated guard on this and is written first.

**P4 — Level correctness fails loudly at load, never silently at play.**
A mis-authored level is caught by `LevelValidation` and reported with
`push_error`, before the player can encounter it. `watering-system.md` R8 is
explicit that a silently unwinnable level is the more dangerous of the two
failure modes.

**P5 — Tuning lives in data; ownership lives in code.**
Values that vary per instance are `@export`s on the node; values that are global
feel constants live in `.tres` resources. Neither is hardcoded. Which module
*owns* a value is an architectural decision recorded in an ADR, and never
inferred from where the value happens to be read.

## Open Questions

| ID | Summary | Priority | Resolution path |
|---|---|---|---|
| QQ-01 | `watering-system.md` §6 and `suit-oxygen.md` §6 assign state to `GameManager`; D2 reassigns it to `LevelState` / `OxygenState`. The GDDs need amending. | High | `/propagate-design-change` after ADR-0002 |
| QQ-02 | D7 keeps jump constants on `Player`, so `gravity.md` §5's init-order hazard stays live. The guard in `GravityAuthority` is mandatory, and the GDD edge case must not be removed. | High | ADR-0001 |
| QQ-03 | All 8 existing levels need `default_gravity_*` exports (D6), plus bucket-economy migration and computed `oxygen_capacity`. `systems-index.md` confirms every level still uses the old one-bucket model and no `O_level` has been computed. | High | Level migration epic, after ADR-0001/0002/0003 |
| QQ-04 | No pause menu exists, but `suit-oxygen.md` §5 requires drain to halt on pause. Oxygen currently cannot be paused at all. | Medium | ADR-0010 |
| QQ-05 | Wall jump, moving platforms and spike hazards are implemented but have no GDD, no TR IDs and therefore no ADR coverage. They are load-bearing traversal mechanics with no design authority. | Medium | `/reverse-document` or accept as undocumented |
| QQ-06 | No `game-concept.md` or pillars document exists. The four GDDs are internally consistent, so nothing is blocked today, but a conflict between them has no authority to appeal to. | Low | `/brainstorm` if it becomes a blocker |
| QQ-07 | `TR-gravity-008` (`zone_priority`) stays parked. If a future design needs regional gravity, D1's global broadcast and props R9 must both be revisited before it becomes implementable. | Low | Revisit only on a design change |
