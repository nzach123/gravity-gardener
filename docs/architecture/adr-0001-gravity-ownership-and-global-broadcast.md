# ADR-0001: Gravity Ownership and Global Broadcast

## Status

Proposed

## Date

2026-08-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Physics (2D) / Core |
| **Knowledge Risk** | **LOW** for this domain. `VERSION.md` rates the 4.7 project HIGH overall, but `modules/physics-2d.md` (verified 2026-08-13) states the 2D physics engine is unchanged 4.4 → 4.7 and instructs that 2D decisions be treated as settled. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` · `docs/engine-reference/godot/modules/physics-2d.md` · `docs/engine-reference/godot/breaking-changes.md` · `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | **None.** `PhysicsServer2D.area_set_param`, `RigidBody2D.sleeping`, `lerp_angle`, and autoload registration all predate 4.4 and are unchanged through 4.7. `CollisionShape2D.one_way_collision_direction` is new in 4.7 and is deliberately **not** used by this decision. |
| **Verification Required** | 1. Exact enum spelling of `PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR` / `AREA_PARAM_GRAVITY` — confirm at implementation, not at decision time. 2. Confirm a default-space gravity write reaches every `RigidBody2D` on the same physics frame. 3. Confirm a sleeping `RigidBody2D` still requires an explicit wake after a space-gravity change (this is the assumption `physics-props.md` R5 rests on). |

Jolt is explicitly out of scope. `project.godot` sets `3d/physics_engine="Jolt Physics"`,
but this is a 2D game and the setting is inert. No part of this decision may be
implemented or reviewed against Jolt behaviour.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. This is the root Foundation decision. |
| **Enables** | ADR-0004 (collision layer allocation) · ADR-0006 (tuning resource strategy — `PropTuning`) · ADR-0007 (player component contract) · ADR-0011 (physics props implementation) |
| **Blocks** | Every epic touching gravity, player movement/jump, or physics props. Nothing in those areas may be coded until this ADR is Accepted. |
| **Ordering Note** | ADR-0011 cannot be Accepted before this one — props have no broadcast to subscribe to until `GravityAuthority` exists. ADR-0007 likewise depends on the `PlayerGravityComponent` contract narrowing defined here. |

## Context

### Problem Statement

`gravity.md` R9 declares gravity to be **world state**, and AC12 requires that every
rigid prop adopt a new gravity vector *on the same frame the player does*. The
current implementation cannot satisfy either.

Today the vector lives in `PlayerGravityComponent` (`gravity`, `target_gravity`,
`baseline_ascent_mag`, `ascent_descent_ratio`), and `main.gd:27` wires each zone
directly to `player.set_gravity`. Gravity is therefore *player* state by
construction. A prop has nothing to read: the only object that knows which way is
down is the player, and props are not permitted to depend on the player
(`physics-props.md` R1 — props must never influence or be influenced by gameplay
objects).

This must be resolved before the first prop is written, because the fix relocates
ownership of the single most widely-consumed value in the game. Retrofitting it
after props, HUD, and watering all read gravity would be a far larger change.

A second, quieter problem: `gravity_zone.tscn` sets `gravity_space_override = 3`
and `gravity = -980.0` on the `Area2D`. This is inert today because the only body
entering a zone is the player, and `CharacterBody2D` ignores space gravity. It
stops being inert the moment a `RigidBody2D` exists in the level.

### Constraints

- **`gravity.md` R4/R5 must survive the move.** The ascent/descent asymmetry and
  the fixed `jump_velocity` are jump-feel devices tuned against a specific curve.
  Relocating ownership must not alter a single number.
- **`physics-props.md` R4 contradicts `gravity.md` R4.** Props need *symmetric*
  gravity; the player needs *asymmetric* gravity. One vector, two magnitude models.
- **Coding standards require dependency injection over singletons**, and every
  Logic-type acceptance criterion must run headless with no `Player` instance.
- **An autoload survives `reload_current_scene()`.** Today gravity resets on
  restart for free because it lives on the player. Moving it to an autoload
  introduces a regression that must be closed in the same decision.
- **Props must follow the *eased* vector** (`physics-props.md` R3), not snap to the
  target — so whatever carries gravity to props must update continuously during
  the ~100 ms rotation window, not once per zone entry.
- **Performance budget**: 60 FPS / 16.6 ms frame, 40 props per level
  (`props_per_level_budget`).

### Requirements

- One vector governs the player and every prop, with no per-body or per-region
  divergence (`gravity.md` R2, R9).
- Props adopt a change on the same frame as the player (`gravity.md` AC12,
  `physics-props.md` AC4).
- Sleeping props are woken on every change (`physics-props.md` R5, AC3).
- `ascent_descent_ratio` is invariant across any sequence of zone changes
  (`gravity.md` AC4).
- `jump_velocity` is never recomputed (`gravity.md` R5), **including while the
  player is carrying a bucket** (`gravity.md` R10, AC11; `watering-system.md` R2,
  AC1).
- A rejected zone change — zero-length direction or non-positive multiplier —
  leaves gravity untouched (`gravity.md` R7, AC7).
- Gravity is testable headless, with no `Player` and no rendered scene.

## Decision

Gravity ownership moves out of the player and into a **`GravityAuthority`
autoload**, which is the single source of the world gravity vector. Zones declare;
the authority owns; the player and props consume. Seven parts:

**1 — `GravityAuthority` owns the vector.** It holds `gravity`, `target_gravity`,
`baseline_ascent_mag`, `ascent_descent_ratio`, and the direction ease rate. It
emits `gravity_changed(direction, multiplier)`. This makes `gravity.md` R9
structural rather than conventional.

**2 — Zones declare, they do not set the player.** `GravityZone` keeps
`zone_gravity_direction` / `zone_gravity_multiplier` and reports to
`GravityAuthority.set_gravity()`. `LevelRoot` no longer connects zones to
`player.set_gravity`; it connects them to the authority, and connects the camera
to `GravityAuthority.gravity_changed`. Validation (zero-length direction,
multiplier ≤ 0) moves to the authority, so a single implementation guards every
caller.

**3 — `PlayerGravityComponent` becomes a consumer.** It stops owning
`gravity`/`target_gravity` and derives its basis (`up_dir`, `right_dir`),
its ascent/descent magnitudes, and `jump_velocity` from the broadcast vector. Its
derivation math in `initialize()` and `apply_gravity()` is **unchanged** — this is
a relocation, not a retune. The dead magnitude half of `update_gravity_lerp()`
(`move_toward` on length; every consumer reads `gravity.normalized()`) is dropped
during the move, resolving the `gravity.md` §5 edge-case note.

**4 — Props receive gravity through default-space gravity, not per-prop force.**
`GravityAuthority` writes the vector and magnitude to the default 2D space:

```gdscript
var space := get_viewport().find_world_2d().space
PhysicsServer2D.area_set_param(space,
        PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized())
PhysicsServer2D.area_set_param(space,
        PhysicsServer2D.AREA_PARAM_GRAVITY,
        descent_magnitude() * prop_tuning.prop_gravity_scale)
```

Space gravity is symmetric by nature, which satisfies `physics-props.md` R4 with
no code, and it reaches every `RigidBody2D` in the same physics frame, which gives
`gravity.md` AC12 and `physics-props.md` AC4 structurally. It costs no per-prop
per-frame work against the 40-prop budget.

This does not affect the player. `CharacterBody2D` ignores space gravity, so the
player's gravity stays manual in `PlayerGravityComponent.apply_gravity()`, where
the R4 asymmetry lives. **This is how one vector produces two magnitude models**:
the space carries the symmetric prop magnitude, the player applies the asymmetric
one to itself.

**4a — The space write is per-frame during easing, not one-shot.**
`physics-props.md` R3 requires props to tip and slide *through* the rotation. The
authority therefore rewrites both space params every physics frame while
`gravity != target_gravity`, and idles once the ease completes.

**4b — Registered props are woken while the vector is moving.** Space gravity does
**not** wake a sleeping body. `GravityAuthority` owns a prop registry
(`register_prop` / `unregister_prop`) and force-wakes every registered prop on each
frame the vector changes — not only on the frame the zone fires, since a prop can
settle part-way through the ease. This is the single most likely implementation bug
in the game (`physics-props.md` R5, AC3), and it is the authority's job, not each
prop's. `unregister_prop()` is mandatory: `physics-props.md` R7 frees out-of-bounds
props, so without it the registry accumulates freed references and the wake loop
iterates invalid instances. `PropBody` calls it from `_exit_tree()`, covering both
R7 freeing and scene reload.

**5 — `GravityZone`'s built-in area gravity override is cleared now.**
`gravity_zone.tscn` sets `gravity_space_override = 3` (line 12) and
`gravity = -980.0` (line 13). Both are removed as part of this Foundation work,
**not** deferred to the props epic. Left in place, they would give props
*per-region* gravity straight from the physics server, contradicting `gravity.md`
R2/R9 ("no per-body or per-region gravity") and breaking AC12. It would present as
props behaving correctly only while inside a zone's bounds — a hard bug to read.
The change is behaviourally neutral today, which is exactly why it is cheap to do
now and expensive to do later.

**6 — Levels declare a default gravity; restart restores it.** An autoload survives
`reload_current_scene()`, so without this the player would restart a level carrying
whatever gravity they died under — a regression that cannot occur in the current
design. Each level root exports `default_gravity_direction` and
`default_gravity_multiplier`; `LevelRoot._ready()` calls
`GravityAuthority.reset_to()` with them at init step 3e. One mechanism covers both
first load and restart — restart is a scene reload, which re-runs `_ready()` — and
a level's starting orientation becomes explicit and authorable rather than implied
by whichever zone the player happens to touch first.

> *Amended 2026-08-14 by ADR-0002.* This originally named
> `GameManager.reset_level_state()` as the caller. ADR-0002 deletes that function
> and moves level state ownership to `LevelRoot`; the call moves to
> `LevelRoot._ready()`, which already ran on both the first-load and restart paths.
> No behavioural change.

**7 — Jump constants stay as `@export`s on `Player`; the ordering hazard is guarded,
not designed away.** The alternative was a `GravityTuning` resource, which would
have deleted the hazard outright because resources load before any `_ready()`.
Keeping the constants on `Player` preserves designer knobs on the node they already
live on, at the cost that `gravity.md` §5's "initialisation order is load-bearing"
edge case stays live and **must remain in the GDD**. Two mitigations are mandatory:

- `GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio)` is public
  API, called from `Player._ready()`. Tests seed it directly with known values, so
  AC12 is testable with no `Player` instance.
- `GravityAuthority` **refuses to broadcast before `initialize()`** and
  `push_error()`s, rather than silently broadcasting a 1.0 ratio and losing the
  asymmetry.

Godot calls `_ready()` bottom-up, so `Player` (a child) initialises before
`LevelRoot` (the parent). The order resolves cleanly:

```
1. Autoloads         GameManager, GravityAuthority   (uninitialised, guarded)
2. Level children, bottom-up
   ├─ Player._ready()      derive baseline → GravityAuthority.initialize(…)
   ├─ Plants, Buckets, Props, Zones _ready()
   └─ HUD._ready()         bind to OxygenState / LevelState
3. LevelRoot._ready()      (parent, last)
   a. LevelValidation.validate(level)          → push_error on contract breach
   b. seed LevelState / OxygenState from exports
   c. GravityAuthority.reset_to(default_gravity_*)   → first broadcast
   d. wire zones → GravityAuthority ; register props → GravityAuthority
```

### Architecture Diagram

```
   GravityZone(s)                          Levels export
   declares dir + multiplier               default_gravity_direction
          │                                default_gravity_multiplier
          │ set_gravity(dir, mult)                    │
          ▼                                           │ reset_to()
   ┌──────────────────────────────────────────────────▼──────────┐
   │  GravityAuthority  (autoload — single source of truth)      │
   │                                                              │
   │  gravity · target_gravity · baseline_ascent_mag              │
   │  ascent_descent_ratio (invariant) · direction_ease_rate      │
   │  prop registry                                               │
   │                                                              │
   │  guard: refuses to broadcast before initialize()   (D7)      │
   │  guard: rejects zero dir / multiplier <= 0         (R7/AC7)  │
   └───────┬───────────────────────────────┬──────────────────────┘
           │ gravity_changed               │ per-frame while easing
           │ (signal)                      │
   ┌───────┴────────┬──────────────┐       ▼
   ▼                ▼              ▼   PhysicsServer2D default space
 PlayerGravity   LevelRoot       (future                   │
 Component       camera          consumers)     AREA_PARAM_GRAVITY_VECTOR
   │                                            AREA_PARAM_GRAVITY
   │ asymmetric: ascent vs descent                          │
   │ jump_velocity FIXED (R5/R10)                           │ symmetric (R4)
   ▼                                                        ▼
 CharacterBody2D                                    every RigidBody2D
 (ignores space gravity)                            + force-wake loop (R5)
```

The two arms out of the authority are what let one vector serve two contradictory
magnitude models. Nothing reads upward: props never see the player, and the player
never sees a prop.

### Key Interfaces

```gdscript
# GravityAuthority — autoload. The single source of the world gravity vector.
extends Node

signal gravity_changed(direction: Vector2, multiplier: float)

@export var direction_ease_rate: float = 32.0      # closes the hardcoded 32.0

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

**Callers must**: call `initialize()` before any `set_gravity()` / `reset_to()`;
pass `multiplier > 0` and a non-zero direction; call `unregister_prop()` from
`PropBody._exit_tree()`.

**Guarantees**:

- `ascent_descent_ratio` never changes after `initialize()` — `gravity.md` AC4
- `jump_velocity` is never recomputed, by any path including bucket carry —
  `gravity.md` R5, R10, AC11; `watering-system.md` R2, AC1
- every registered prop is woken on every frame the vector changes —
  `gravity.md` AC12, `physics-props.md` R5, AC3, AC4
- a rejected change leaves gravity untouched — `gravity.md` R7, AC7
- no broadcast occurs before `initialize()` — `gravity.md` §5

`GravityAuthority` is registered as a **scene autoload**
(`gravity_authority.tscn` with the script attached), not a bare script autoload.
A bare script autoload gives `@export var direction_ease_rate` no inspector
surface, which would make the export decorative and leave the value effectively
hardcoded — the exact defect the export exists to fix.

`PlayerGravityComponent` retains: `initialize(max_speed)`, `apply_gravity()`,
`jump_velocity`, and the derived basis. It loses: `gravity`, `target_gravity`,
`set_gravity()`, `update_gravity_lerp()`.

## Alternatives Considered

### Alternative 1: Keep gravity on `Player`; props subscribe to a re-emitted signal

- **Description**: `PlayerGravityComponent` stays the owner and re-emits
  `gravity_changed`. Props connect to the player's signal.
- **Pros**: Smallest diff. No new autoload. Gravity keeps resetting on scene
  reload for free, so decision part 6 becomes unnecessary.
- **Cons**: Makes every prop depend on the player existing and being found at
  load, which contradicts `physics-props.md` R1 (props are inert scenery with no
  gameplay coupling) and its §6 note that props receive the vector "through the
  same broadcast the player does, not by subscribing to zones individually". AC12
  could only be tested by instantiating a full `Player`, violating the headless
  requirement in the coding standards. Leaves `gravity.md` R9 ("gravity is world
  state") true only by convention.
- **Rejection Reason**: It encodes the exact ownership error this ADR exists to
  correct. Gravity would remain player state wearing a world-state label.

### Alternative 2: `GravityAuthority` broadcast, but per-prop force application

- **Description**: The authority owns the vector as decided, but each prop applies
  `apply_central_force(gravity * mass)` in its own `_physics_process` instead of
  reading space gravity.
- **Pros**: Per-prop control — individual props could scale or ignore gravity.
  Nothing depends on `PhysicsServer2D` semantics.
- **Cons**: Costs 40 script callbacks and 40 force applications per frame,
  permanently, against a 16.6 ms budget, to buy per-prop variation that
  `physics-props.md` explicitly does not want (R4: props use a single magnitude;
  §7: `prop_gravity_scale` is global and should "leave at 1.0"). Same-frame
  adoption becomes an ordering property that must be maintained by hand rather
  than a guarantee. Requires disabling each body's built-in gravity
  (`gravity_scale = 0`), one more thing to get wrong per prop.
- **Rejection Reason**: Strictly more per-frame cost and more failure modes, in
  exchange for flexibility the design forbids.

### Alternative 3: Level-root-owned `GravityState`, injected rather than autoloaded

- **Description**: A plain `RefCounted` `GravityState` created by `LevelRoot` and
  injected into the player, zones, and props — mirroring the `LevelState` /
  `OxygenState` treatment in ADR-0002.
- **Pros**: Directly satisfies the coding standard's "dependency injection over
  singletons". Dies with the scene, so gravity resets on reload automatically and
  decision part 6 is unnecessary. Trivially testable — construct one per test.
- **Cons**: Gravity has a consumer that the level-scoped state objects do not: the
  **physics space**, which is a global resource reached through
  `PhysicsServer2D`. An injected object still has to write to that global, so the
  singleton is not actually eliminated — only hidden. Injection would have to
  thread through every prop at spawn time, and props are spawned by the level
  rather than by a system that could carry the reference. The prop registry and
  wake loop want a stable lifetime that outlives individual prop scenes.
- **Rejection Reason**: Rejected on balance, not on principle — this is the
  closest alternative. The testability advantage is recovered by
  `initialize(baseline, ratio)` and `reset_to()` being public seedable API, which
  lets a headless test drive the authority to any state with no `Player` and no
  scene. Decision part 6 is the price paid for the remaining gap, and it buys back
  a genuine benefit: level starting orientation becomes explicit and authorable.

### Alternative 4: `GravityTuning` resource for the jump constants (for decision part 7)

- **Description**: Move `jump_height`, `jump_distance_to_peak`,
  `jump_distance_to_land` into a `.tres` resource.
- **Pros**: Deletes the initialisation-order hazard outright, since resources load
  before any `_ready()`. Aligns with the data-driven rule in the coding standards.
- **Cons**: Moves designer knobs off the node they already live on and away from
  the other player exports.
- **Rejection Reason**: **User decision, made against the recommendation on
  2026-08-13 and reaffirmed here.** The hazard is instead guarded by the
  `initialize()` gate in decision part 7. This is a deliberate, documented
  trade-off — not an oversight — and `gravity.md` §5's edge case must not be
  deleted as long as it stands.

## Consequences

### Positive

- `gravity.md` R9 becomes structural. There is exactly one vector, and nothing can
  hold a private copy.
- AC12 and `physics-props.md` AC4 (same-frame adoption) are satisfied by the
  physics server rather than by ordering discipline, so they cannot regress
  through a careless edit.
- `physics-props.md` R4 (symmetric prop gravity) costs zero code — it falls out of
  how space gravity works.
- Gravity becomes headless-testable. `initialize()` + `reset_to()` + `set_gravity()`
  drive the whole system with no `Player`, no scene, and no rendering.
- Prop gravity costs no per-prop per-frame work, leaving the 40-prop budget for
  rendering rather than script.
- The dormant `gravity_space_override` trap is removed before anything can trip on
  it.
- Level starting orientation becomes explicit and authorable.
- The hardcoded `32.0` ease rate becomes a real, inspector-editable tuning knob.

### Negative

- A new autoload, in a project whose coding standards prefer injection. Mitigated
  by seedable public API, but the tension is real and is recorded in Alternative 3.
- An autoload surviving scene reload creates a restart regression that must be
  closed by decision part 6 — a requirement no GDD asks for, existing purely as a
  consequence of this decision.
- **All 8 existing levels must add `default_gravity_direction` and
  `default_gravity_multiplier` exports.** Until they do, a restarted level inherits
  the previous gravity.
- The player's gravity model and the props' gravity model are now maintained in two
  places (manual application vs space params) and can drift. The single shared
  `baseline_ascent_mag` / `ascent_descent_ratio` pair is what keeps them coherent.
- `main.gd`, `player.gd`, `player_gravity_component.gd`, `gravity_zone.gd` and
  `gravity_zone.tscn` all change in one changeset. There is no incremental path.
- The `gravity.md` §5 initialisation-order hazard stays live by choice (part 7).

### Risks

| Risk | Mitigation |
|---|---|
| **Sleeping props ignore the change** — the defining bug of the props system (`physics-props.md` R5, AC3: "gravity works, but only sometimes") | The wake loop is the authority's responsibility, runs every frame the vector changes rather than only on zone entry, and `physics-props.md` says to write the AC3 test *before* the feature |
| **Stale prop registry** — R7 frees out-of-bounds props; the wake loop then iterates freed instances | `unregister_prop()` from `PropBody._exit_tree()` is mandatory API, covering both R7 and scene reload. Guard the loop with `is_instance_valid()` regardless |
| **Broadcast before `initialize()`** — ratio is 1.0, asymmetry silently lost (`gravity.md` §5) | Explicit guard that `push_error()`s and refuses to broadcast. A test must assert the refusal, not just the happy path |
| **A level ships without `default_gravity_*`** — restart inherits the wrong gravity | Add the check to `LevelValidation.validate()` under ADR-0003 so it fails loudly at load |
| **`AREA_PARAM_GRAVITY_VECTOR` enum spelling is wrong** — post-cutoff uncertainty | Flagged in Engine Compatibility as implementation-time verification. Failure mode is a compile error, not silent misbehaviour |
| **`direction_ease_rate` export is not editable** if registered as a bare script autoload | Register as a scene autoload; assert the value is reachable from the inspector during implementation |
| **Prop gravity desynchronises from the player's fall** | `prop_gravity_scale` defaults to 1.0 and `physics-props.md` §7 says leave it there. `physics-props.md` AC5 pins prop fall time to the player's `t_down` |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `gravity.md` | R2 — zones are setters, broadcast globally, no per-body or per-region gravity | Zones call `GravityAuthority.set_gravity()`; the authority is the only writer. Part 5 removes `gravity_space_override`, which was the one mechanism that could have made gravity regional |
| `gravity.md` | R3 — direction eases, strength snaps | Easing moves to the authority with `direction_ease_rate` exported. Part 4a rewrites the space vector each eased frame so props follow the rotation (`physics-props.md` R3) |
| `gravity.md` | R4 — asymmetric ascent/descent | Stays in `PlayerGravityComponent.apply_gravity()`, unchanged. `CharacterBody2D` ignores space gravity, so the symmetric prop path cannot contaminate it |
| `gravity.md` | R5 / R10 — `jump_velocity` fixed; carry never touches it | Declared an invariant of the authority contract. Carrying scales `max_speed` only, per the 2026-08-14 confirmation |
| `gravity.md` | R7 — multiplier semantics; reject bad input | Validation centralised in `set_gravity()`, so every caller is guarded by one implementation |
| `gravity.md` | R9 — gravity is world state | The entire purpose of parts 1–3 |
| `gravity.md` | AC4 — ratio invariant across any zone sequence | `ascent_descent_ratio` is set once in `initialize()` and never written again |
| `gravity.md` | AC7 — zero-length vector leaves gravity unchanged | Guarded in `set_gravity()` before any state is touched |
| `gravity.md` | AC12 — props adopt the vector on the same frame as the player | Part 4 — a single space write reaches every `RigidBody2D` in that physics frame |
| `gravity.md` | §5 — `set_gravity()` before `initialize()` | Part 7 — explicit refusal with `push_error()`. Edge case stays in the GDD by design |
| `gravity.md` | §7 — ease rate "hardcoded; should be exported" | `@export var direction_ease_rate` on the authority, scene-autoloaded so it is genuinely editable |
| `physics-props.md` | R3 — props obey the global vector, including during easing | Parts 4 and 4a |
| `physics-props.md` | R4 — prop gravity is symmetric | Space gravity is symmetric by nature; no code |
| `physics-props.md` | R5 / AC3 — props must be force-woken | Part 4b — authority-owned wake loop, every changing frame |
| `physics-props.md` | R7 — props leaving bounds are freed | `unregister_prop()` is mandatory contract, not optional cleanup |
| `physics-props.md` | §4 — `g_prop = g_descent₀ · m · prop_gravity_scale` | Exactly the `AREA_PARAM_GRAVITY` value written in part 4 |

Architecture-doc TR mapping for this ADR: `TR-gravity-001/002/003/009/011/012`,
`TR-props-001/004`. The 52-requirement baseline those IDs index has not been
persisted to disk — `/architecture-review` owns rebuilding and writing it. The GDD
rule and AC citations above are the authoritative, verifiable anchor.

## Performance Implications

- **CPU** — Net reduction versus the rejected per-prop alternative. Steady state:
  zero per-frame cost for prop gravity. During the ~100 ms ease window: two
  `PhysicsServer2D.area_set_param` calls plus one wake pass over ≤ 40 registered
  props per physics frame — roughly 6–7 frames at 60 FPS, well inside 16.6 ms. The
  player path is unchanged.
- **Memory** — One autoload node plus an `Array[RigidBody2D]` of ≤ 40 references.
  Negligible against the 512 MB ceiling.
- **Load Time** — One extra autoload instantiation. Unmeasurable.
- **Network** — Not applicable; single-player.

`physics-props.md` AC10 ("a room of props at budget holds 60 FPS during a gravity
flip") is the acceptance test for this section and belongs to ADR-0011.

## Migration Plan

No incremental path exists — parts 1, 2, 3 and 5 must land together or gravity
breaks. Parts 4, 4a and 4b can land with the props epic, since they have no
observable effect until the first `RigidBody2D` exists.

**Changeset A — ownership move (atomic):**

1. Add `src/scripts/autoloads/gravity_authority.gd` + `gravity_authority.tscn`;
   register the **scene** in `project.godot` `[autoload]`.
2. Move `gravity`, `target_gravity`, `baseline_ascent_mag`,
   `ascent_descent_ratio`, `set_gravity()`, `update_gravity_lerp()` and the basis
   derivation out of `player_gravity_component.gd` into the authority. Drop the
   dead `move_toward` magnitude easing.
3. `player_gravity_component.gd` keeps `initialize(max_speed)` and
   `apply_gravity()`; it subscribes to `gravity_changed` and calls
   `GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio)` from
   `Player._ready()`. Remove `Player.set_gravity()` (`player.gd:183`) and the
   `target_gravity` proxy (`player.gd:71`).
4. `gravity_zone.gd:25` — emit to `GravityAuthority.set_gravity()` instead of the
   zone's own signal, or keep the signal and rewire in `LevelRoot`.
5. `main.gd:25-28` — connect zones to the authority, and
   `_rotate_camera_to_gravity` to `GravityAuthority.gravity_changed` rather than to
   each zone.
6. `gravity_zone.tscn` — delete `gravity_space_override = 3` (line 12) and
   `gravity = -980.0` (line 13).
7. Add `default_gravity_direction` / `default_gravity_multiplier` exports to the
   level root and call `GravityAuthority.reset_to()` from `LevelRoot._ready()`
   (init step 3e). *(Amended 2026-08-14 by ADR-0002 — was `reset_level_state()`,
   which that ADR deletes.)*
8. **All 8 level scenes** — author the two new exports. Levels without them keep
   working on first load but inherit stale gravity on restart until authored.

**Changeset B — with the props epic (ADR-0011):** parts 4, 4a, 4b — space writes,
per-frame ease writes, prop registry and wake loop.

**Regression watch during Changeset A**: `gravity.md` AC1–AC10 must all still pass.
This is a pure relocation; any change in jump height, apex timing, or ratio means
the move was not faithful.

## Validation Criteria

Headless tests, no `Player` instance required — seed the authority with
`initialize()`:

| # | Test | Source |
|---|---|---|
| V1 | `ascent_descent_ratio` is bit-identical after 100 randomised `set_gravity()` calls | `gravity.md` AC4 |
| V2 | `jump_velocity` is unchanged after any zone sequence, and while `carrying_bucket` is true | `gravity.md` R5, R10, AC11 |
| V3 | `set_gravity(Vector2.ZERO, 1.0)` and `set_gravity(Vector2.DOWN, 0.0)` and `(…, -1.0)` each leave `gravity` untouched | `gravity.md` R7, AC7 |
| V4 | `set_gravity()` before `initialize()` broadcasts nothing and raises an error | `gravity.md` §5, part 7 |
| V5 | A 90° direction change completes within 100 ms and is monotonic | `gravity.md` AC5 |
| V6 | `reset_to()` restores the level default after an arbitrary zone sequence | Part 6 |
| V7 | `unregister_prop()` on a freed prop leaves the wake loop safe over 1 000 frames | `physics-props.md` R7 |
| V8 | Peak height is 400 px at 0.5×, 200 px at 1.0×, 100 px at 2.0× — unchanged from pre-migration | `gravity.md` AC3 (already passing; must not regress) |

Deferred to ADR-0011: a prop asleep at flip time is moving on the next physics
frame (`physics-props.md` AC3), and props adopt the vector on the same frame as the
player (AC4).

**This decision is correct if** a prop can be added to a level with no gravity code
of its own, and `physics-props.md` R3, R4 and AC4 hold with nothing written beyond
`register_prop()` / `unregister_prop()`.

## Related Decisions

- `docs/architecture/architecture.md` — binding decisions D1, D3, D4, D6, D7, which
  this ADR formalises; API Boundaries § Foundation
- **ADR-0002** Level state ownership — moves level state to `LevelRoot` and deletes
  `reset_level_state()`. Amends part 6 of this ADR: the `reset_to()` caller is
  `LevelRoot._ready()`
- **ADR-0003** Level load validation — must add the `default_gravity_*` presence
  check identified in Risks
- **ADR-0004** Collision layer allocation — the other half of prop isolation
- **ADR-0006** Tuning resource strategy — owns `PropTuning.prop_gravity_scale`, read
  by part 4; Alternative 4 is the reason `GravityTuning` is absent from it
- **ADR-0007** Player component contract — consumes the narrowed
  `PlayerGravityComponent`
- **ADR-0011** Physics props implementation — Changeset B
- `design/gdd/gravity.md` · `design/gdd/physics-props.md`
- `docs/engine-reference/godot/modules/physics-2d.md`
