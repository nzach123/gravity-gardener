# ADR-0011: Physics prop body, lifetime and speed cap

## Status

Accepted

## Date

2026-08-16 (Proposed) · 2026-08-16 (Accepted)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Physics (2D) |
| **Knowledge Risk** | **LOW.** The project pin carries HIGH risk overall, but `docs/engine-reference/godot/modules/physics-2d.md` states that `RigidBody2D`, `Area2D`, `CharacterBody2D` and `move_and_slide()` have no breaking change across 4.4 → 4.7, and instructs agents not to mark 2D physics decisions as unverified. Jolt is 3D only and is inert in this project. |
| **References Consulted** | `docs/engine-reference/godot/modules/physics-2d.md`, `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `docs/engine-reference/godot/modules/core.md`, ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, `design/gdd/physics-props.md`, `design/gdd/gravity.md`, `docs/registry/architecture.yaml` |
| **Post-Cutoff APIs Used** | **None.** `RigidBody2D._integrate_forces`, `PhysicsDirectBodyState2D.linear_velocity`, `RigidBody2D.sleeping`, `Area2D.body_exited`, `Node.queue_free()`, `PhysicsServer2D.area_set_param` and `area_get_param` all predate 4.0 and are unchanged through 4.7.1. `CollisionShape2D.one_way_collision_direction` is new in 4.7 and is deliberately **not** used. |
| **GH-115763 does not apply here** | The 4.7 typed-return-inheritance break affects overrides of methods with a **typed, non-void** return, which must gain an explicit `return`. `RigidBody2D._integrate_forces(state: PhysicsDirectBodyState2D) -> void` returns `void`, so the D11.2 override is unaffected. Recorded so a future reader does not re-derive it. *(Engine specialist review, 2026-08-16.)* |
| **Verification Required** | **V-E2 only.** Confirm a synchronous `PhysicsServer2D.area_set_param` write from `LevelRoot._ready()` lands before the first physics step of the new scene (D11.5). **V-E1 and V-E3 are resolved** by the engine specialist review of 2026-08-16 — see below. |
| **Resolved at review** | **V-E1** (`_integrate_forces` is never called on a sleeping body) — **confirmed against 4.7.1-stable engine source**: `godot_step_2d.cpp:140,151` shows `step()` iterating only the active body list, and `godot_body_2d.cpp:139-147` removes a body from that list on sleep. **V-E3** (`body_entered` fires for a body already overlapping at tree entry, and `body_exited` then fires normally) — confirmed; overlap pairs are computed per `flush_queries()` and a freshly-added overlapping pair is indistinguishable from one that just moved into overlap. **C3** (the clamp cannot defeat sleep detection) — confirmed at `godot_body_2d.cpp:703-715`: the clamp only ever reduces an over-threshold velocity, and once the body sleeps the clamp does not run at all. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (gravity ownership — supplies the prop registry, the space write, and the wake loop this ADR implements) · **ADR-0004** (collision layer allocation — supplies layer `8` / mask `9`) · **ADR-0006** (tuning resources — supplies `PropTuning`). All three are Accepted. |
| **Enables** | None. This is a leaf decision. |
| **Blocks** | The physics props epic, and with it `physics-props.md` AC3–AC10. |
| **Ordering Note** | Independent of ADR-0010 and ADR-0012. `physics-props.md` §6 and `watering-system.md` §5 both exclude buckets and spent jugs from prop physics, so ADR-0012's tween-driven jug shares no surface with this ADR. This ADR implements **ADR-0001 Changeset B** (parts 4, 4a, 4b), which ADR-0001 assigned here by name (`adr-0001:530`). |

## Context

### Problem Statement

No prop exists in the project, and no ADR says what one is. ADR-0001 decided how
gravity reaches a prop. ADR-0004 decided which layer a prop sits on. ADR-0006
decided where a prop's tuning lives. None of them decided what a `PropBody`
actually is, how its fall speed is capped, when it is freed, or how it returns to
its authored place after a restart.

ADR-0001 also parked its own Changeset B here. Parts 4, 4a and 4b — the space
gravity write, the per-frame ease write, and the force-wake loop — are written but
unimplemented, because they have no observable effect until the first
`RigidBody2D` exists. That first body is this ADR's business.

Four `physics-props.md` requirements have no owner until this decision lands:
restart reset (R6), out-of-bounds freeing (R7), the fall-speed cap (§4), and the
60 FPS budget under a flip (R8, AC10).

### Constraints

- **Props are cosmetic and must stay that way.** `physics-props.md` R1 says no prop
  may ever affect whether a level is solvable. R2 says isolation is enforced by
  layer and mask, never by conditional logic.
- **Gravity rotates.** Any mechanism this ADR chooses must work at every gravity
  angle, not only at the authored one. This rules out several answers that look
  correct in a fixed-gravity game.
- **The budget is 40 props per level**, at 60 FPS and under 500 draw calls.
  `docs/registry/architecture.yaml:910` sets the `prop_gravity` budget at "0
  per-frame script cost in steady state".
- **Two forbidden patterns bind this ADR.** `per_prop_gravity_application` bans
  `apply_central_force` for gravity and per-prop `gravity_scale` tuning.
  `prop_isolation_by_conditional_guard` bans `if body is PropBody: return`.
- **Three signatures are frozen.** `GravityAuthority.register_prop()`,
  `unregister_prop()`, and the `Tuning.PROP` const-holder reach.

### Requirements

- A prop must need no gravity code of its own. ADR-0001's close condition states
  this directly: a prop is correct when `physics-props.md` R3, R4 and AC4 hold with
  nothing written beyond `register_prop()` / `unregister_prop()`.
- Prop speed must never exceed `prop_max_speed`, and no prop may pass through
  terrain (AC7).
- A prop leaving level bounds must be freed and must not accumulate (R7, AC9).
- Every prop must return to its authored transform on restart (R6, AC8).
- A prop asleep at flip time must be moving on the next physics frame (R5, AC3).
  ADR-0001 deferred this criterion here by name (`adr-0001:553`).

## Decision

Seven parts. Parts 1 to 4 define the prop. Part 5 repairs an inherited defect.
Parts 6 and 7 close two questions other documents assigned here.

### D11.1 — `PropBody` is a scripted `RigidBody2D`, and it is the only prop type

`PropBody` extends `RigidBody2D`. It carries `collision_layer = 8` and
`collision_mask = 9` from ADR-0004 D4.3, written through the `CollisionLayers`
constants, never as literals.

```gdscript
class_name PropBody extends RigidBody2D

func _ready() -> void:
    GravityAuthority.register_prop(self)

func _exit_tree() -> void:
    GravityAuthority.unregister_prop(self)
```

Three properties are fixed and may not be authored per prop:

| Property | Value | Reason |
|---|---|---|
| `custom_integrator` | `false` | The engine must keep integrating space gravity. A custom integrator would make ADR-0001 part 4 inert. |
| `gravity_scale` | `1.0` | Per-prop gravity scaling is the registered forbidden pattern `per_prop_gravity_application`. One vector governs every prop. |
| `collision_layer` / `collision_mask` | `8` / `9` | ADR-0004 D4.6 bans runtime mutation of either. |

`mass`, `friction`, `bounce`, `linear_damp` and `angular_damp` stay per-scene and
authored freely, exactly as `physics-props.md` §7 and ADR-0006 D6.1 assign them.
Variation between a light chair and a heavy table is the point.

`unregister_prop()` in `_exit_tree()` is not optional. It is a registry contract
condition (`architecture.yaml:203`), and it covers both R7 freeing and scene
reload with one call site.

### D11.2 — The fall-speed cap clamps `linear_velocity` inside `_integrate_forces`

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    var max_speed: float = Tuning.PROP.prop_max_speed
    if state.linear_velocity.length() > max_speed:
        state.linear_velocity = state.linear_velocity.normalized() * max_speed
```

Three properties make this the right shape:

1. **It clamps magnitude and preserves direction.** The cap therefore works at every
   gravity angle with no angle-aware code, which is what `physics-props.md` R3
   requires of anything in this system.
2. **It costs nothing in steady state.** Godot calls `_integrate_forces` only on an
   active body. A settled prop sleeps, receives no call, and adds no per-frame
   script cost — which is how a per-body callback stays inside the
   `architecture.yaml:910` budget line that promises zero steady-state cost.
   *This is the single claim in D11.2 that is an engine fact rather than a design
   choice, so it was traced rather than assumed.* Confirmed against 4.7.1-stable
   engine source at review: `godot_step_2d.cpp:140,151` iterates only the active
   body list, and `godot_body_2d.cpp:139-147` removes a body from that list when it
   sleeps. The clamp also cannot defeat sleep detection — it only ever *reduces* an
   over-threshold velocity, never raises a settled one
   (`godot_body_2d.cpp:703-715`).
3. **It runs before integration**, so the cap holds for the step it is applied in
   rather than one step late.

**The cap does not fight AC5.** At `m` = 1.0 a prop falling 200 px reaches about
1 753 px/s (`g_prop` 7 656.25 × `t_fall` 0.229), which is under the 2 000 px/s
default. AC5 measures a 1.0× fall, so the clamp is inert there and the
prop-matches-player coherence of §4 is untouched. The clamp bites in a 2.0× zone,
where an uncapped prop would reach about 2 480 px/s over the same drop. That is
precisely the tunnelling case §4 introduced the cap for.

`prop_max_speed` is read through `Tuning.PROP` per ADR-0006 D6.3. A `.tres` path
literal outside the const holder is the registered forbidden pattern
`tuning_path_literal_outside_holder`.

### D11.3 — Out-of-bounds props are freed by one `LevelBounds` area, not by the kill plane

`LevelRoot` gains one exported `Area2D` covering the playable extent of the level:

```gdscript
@export var level_bounds: Area2D      # LevelRoot

func _on_level_bounds_body_exited(body: Node2D) -> void:
    body.queue_free()
```

The area carries `collision_layer = 0` and `collision_mask = 8` (`prop`), matching
the detector idiom ADR-0004 D4.1 establishes: a detector needs no layer of its own.
Only `PropBody` sits on layer 8, so the handler needs no type check — the mask is
the filter. A `if body is PropBody` guard here would be the registered forbidden
pattern `prop_isolation_by_conditional_guard`.

`queue_free()`, never `free()`. The handler runs from a physics callback, and
freeing a body inside one is unsafe.

**Why not the kill plane.** ADR-0004 offered `KillArea2D` mask `10` as an option
and assigned the choice here (`adr-0004:500`, `architecture.yaml:775`). This ADR
declines it, on three grounds:

1. A kill plane is a **plane**, authored for one gravity direction. Gravity rotates
   through four, so a prop can leave through any of four sides. A plane catches one.
2. Only `level_05.tscn` and `level_06.tscn` have a `KillArea2D`. Six levels would
   free nothing.
3. It would tie prop lifetime to the player death handler at `main.gd:71` — the
   handler BUG-0001 makes unreachable.

ADR-0004's deferral is therefore **closed with a no**, not left open.

**One hole, named rather than hidden.** A prop authored *outside* the bounds rect
never enters the area, so it never exits it, so it is never freed. `V-BOUNDS`
(D11.7) closes this at load rather than at runtime.

### D11.4 — Restart reset is structural. Runtime prop spawning is banned

`physics-props.md` R6 and AC8 need every prop back at its authored transform after
a restart. This ADR adds no reset pass, because ADR-0002 part 2 already made
restart *reconstruction*: `restart_level()` is `reload_current_scene()` alone,
which frees the level scene and builds a fresh one from the authored `.tscn`.
Authored transforms come back because the nodes holding them are new.

That guarantee holds on one condition, and this ADR makes the condition explicit:

> **Props are authored scene children only.** No prop may be spawned at runtime,
> pooled, respawned, or persisted across a scene reload.

A runtime-spawned prop has no authored transform to return to, so R6 would stop
being a property of object lifetime and start being a reset function somebody has
to maintain — the exact failure ADR-0002 was written to remove. This is offered as
a new forbidden pattern, `runtime_prop_instantiation`.

### D11.5 — `reset_to()` writes the space parameters synchronously

**This part repairs an inherited defect, found by the session-18 review**
(`architecture-review-2026-08-15-b.md:80-84`).

ADR-0001 part 4a writes the two space parameters on every physics frame *while
`gravity != target_gravity`*. `reset_to()` sets both to the level default at once,
so that condition is false immediately and the write never fires. A `Viewport`'s
`World2D` space RID survives `reload_current_scene()` — the root viewport is not
the node being freed — so the space keeps whatever the previous level last wrote.
Props would fall the previous level's way until the first zone-triggered change.
ADR-0001's V6 asserts the `gravity` field only, never the space parameter, so it
would pass while the bug was live.

`reset_to()` therefore performs the same two writes directly, in addition to
setting `gravity` and `target_gravity`. The ease gate in part 4a is unchanged.

**The call path was traced, not assumed.** `reset_to()` runs from
`LevelRoot._ready()` at ADR-0003 init step (e). `_ready()` runs during scene-tree
entry in idle time — `reload_current_scene()` is deferred, and
`change_scene_to_packed()` likewise. That is outside `flush_queries()` and outside
`_physics_process`, so a synchronous `PhysicsServer2D` write there raises no
reentrancy hazard, and the next physics step comes after it.

> **Read this before writing any physics-server or monitor-flag call in this
> project.** ADR-0012 D12.4 records the failure this reasoning avoids: a draft
> deferred a write by analogy with another call site, without checking that the two
> sites sat in the same physics window. They did not. Trace the path. The
> conclusion here is listed as **V-E2** and is confirmed by test, not by argument.

### D11.6 — The kill plane's correct mask is specified. It is not applied here

`KillArea2D` declares no mask, so it defaults to `1` (`world`). The player is on
layer `2`. `1 & 2 == 0`, so `body_entered` never fires and `main.gd:71` is
unreachable in the two levels that wire it. This is BUG-0001, severity S2,
priority P2, Open.

The correct value is `collision_layer = 0`, `collision_mask = 2` (`player`) — the
detector idiom of ADR-0004 D4.1, and the same shape every other detector in the
project already uses.

**This ADR specifies the value and does not apply it.** Applying it turns a dead
kill plane into a live one in `level_05.tscn` and `level_06.tscn`, which changes
player death behaviour in two shipped levels and needs a playtest first. BUG-0001
stays Open with a named fix rather than being closed by an architecture document.

Props are unaffected either way: D11.3 gives them a different mechanism, so the
kill plane never needs mask bit `8`.

### D11.7 — Validation additions

Two rules are added to ADR-0003's validation table. ADR-0003 D3.3 sanctions this
directly: *"Any future ADR that adds a `LevelRoot` consumer export adds a row to
this table in the same changeset."*

| Code | Rule | Source |
|---|---|---|
| `V-BOUNDS` | `level_bounds` is non-empty, resolves to a live `Area2D`, and every `PropBody` in the level starts inside its extent | `physics-props.md` R7; closes the D11.3 hole |
| `V-PROP-BUDGET` | *(already specified by ADR-0003, unblocked by ADR-0006)* `PropBody` count ≤ `Tuning.PROP.props_per_level_budget` | `physics-props.md` R8, §5, §7 |

`level_bounds` joins the `V-WIRING` required-consumer table as **Required**,
effective when this ADR is Accepted, per ADR-0003 D3.3's rule that a consumer
becomes required when its owning ADR is Accepted.

### Architecture Diagram

```
  GravityAuthority  (autoload, process_physics_priority = -100, ADR-0005)
  ┌──────────────────────────────────────────────────────────────┐
  │  gravity / target_gravity          ease  (ADR-0001 part 3)   │
  │                                                              │
  │  _physics_process:                                           │
  │    while easing → area_set_param(space, VECTOR | GRAVITY)    │  part 4a
  │    while easing → for p in registry: p.sleeping = false      │  part 4b
  │                                                              │
  │  reset_to():                                                 │
  │    area_set_param(space, VECTOR | GRAVITY)  ── synchronous   │  D11.5
  │                                                              │
  │  prop registry: register_prop / unregister_prop              │
  └───────────────┬──────────────────────────────────────────────┘
                  │ default-space gravity — no per-prop force
                  ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  PropBody : RigidBody2D     layer 8 / mask 9  (ADR-0004)     │
  │    _ready()      → register_prop(self)                       │
  │    _exit_tree()  → unregister_prop(self)                     │
  │    _integrate_forces(state) → clamp |linear_velocity|        │  D11.2
  │        (called only while awake → 0 cost at rest)            │
  └───────────────┬──────────────────────────────────────────────┘
                  │ body_exited
                  ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  LevelBounds : Area2D    layer 0 / mask 8    (LevelRoot)     │  D11.3
  │    body_exited → queue_free()                                │
  └──────────────────────────────────────────────────────────────┘

  Nothing reads upward. A prop never sees the player, a plant, a bucket,
  the airlock, or a hazard — by mask, not by guard.
```

### Key Interfaces

```gdscript
class_name PropBody extends RigidBody2D
# No public API. A prop is a consumer with no readers.
# Authored per scene: mass, friction, bounce, linear_damp, angular_damp.
# Fixed: custom_integrator = false, gravity_scale = 1.0,
#        collision_layer = CollisionLayers.PROP,
#        collision_mask  = CollisionLayers.PROP_MASK

# LevelRoot gains:
@export var level_bounds: Area2D

# GravityAuthority.reset_to() gains the two space writes it never performed.
# No signature changes anywhere. No frozen signature is reopened.
```

**Guarantees this ADR adds:**

- A prop's speed never exceeds `prop_max_speed`, at any gravity angle
  (`physics-props.md` §4, AC7).
- A prop outside level bounds is freed exactly once and never accumulates
  (R7, AC9).
- Every prop is at its authored transform after a restart, because the node
  holding the transform is new (R6, AC8).
- The physics space reflects the level default from the first physics step of
  every level load and restart (D11.5).

## Alternatives Considered

### Alternative 1: Script-free props, with `linear_damp` producing a terminal velocity

- **Description**: No `PropBody` script. Author a high `linear_damp` on each prop
  so drag caps the fall speed, and register props from `LevelRoot` instead of from
  the prop.
- **Pros**: Zero per-frame script cost by construction. No new class.
- **Cons**: Damping slows the *whole* fall, not only its top end. A 200 px drop at
  `m` = 1.0 would no longer take 0.229 s.
- **Rejection Reason**: It breaks AC5 and, with it, the §4 property that props and
  the player fall at the same rate — which the GDD names as the thing that makes a
  flip read as one event rather than two systems. A cap that changes the fall it is
  not supposed to touch is not a cap.

### Alternative 2: Clamp `linear_velocity` in `_physics_process`

- **Description**: Read and write `RigidBody2D.linear_velocity` from an ordinary
  `_physics_process` override rather than from `_integrate_forces`.
- **Pros**: Reads more plainly. No `PhysicsDirectBodyState2D` to understand.
- **Cons**: `_physics_process` runs whether or not the body sleeps, so 40 props cost
  40 callbacks every frame forever, including a room where nothing has moved for a
  minute. Writing `linear_velocity` from outside the integrator also sets state the
  solver is concurrently deriving.
- **Rejection Reason**: It spends the entire `prop_gravity` steady-state budget on
  a clamp that is inert in steady state.

### Alternative 3: Extend `KillArea2D` to mask `prop` (mask `10`)

- **Description**: Take the option ADR-0004 made available. One mask edit in two
  level scenes, plus a branch in `_on_kill_area_2d_body_entered`.
- **Pros**: The cheapest possible change. Reuses a node that already exists.
- **Cons**: A kill plane is authored for one gravity direction and this game rotates
  through four. Six of eight levels have no kill plane at all. It also couples prop
  lifetime to the player death path.
- **Rejection Reason**: Structurally wrong under rotating gravity. See D11.3.

### Alternative 4: Per-prop `VisibleOnScreenNotifier2D`

- **Description**: Each prop frees itself on `screen_exited`.
- **Pros**: No level authoring at all. Self-contained per prop.
- **Cons**: Off-screen is not out-of-bounds. Props legitimately leave the camera
  view in every level.
- **Rejection Reason**: It would free a room's furniture whenever the player walked
  away from it, then present as props vanishing on return. R7 is about leaving the
  *level*, not leaving the *view*.

### Alternative 5: Lift ADR-0001 part 4a's ease gate entirely

- **Description**: Fix D11.5's defect by writing both space parameters every
  physics frame unconditionally, rather than adding a write to `reset_to()`.
- **Pros**: One invariant, easy to state: the space always reflects `gravity`. No
  call site can forget it.
- **Cons**: Two `PhysicsServer2D` calls every frame forever, against a budget line
  that promises zero steady-state cost. It also amends an Accepted ADR's part 4a
  rather than adding to it.
- **Rejection Reason**: It pays a permanent cost to fix a defect that occurs at two
  moments — level load and restart. D11.5 fixes it at those two moments.

## Consequences

### Positive

- **ADR-0001's close condition is met.** A prop can be added to a level with no
  gravity code of its own. `PropBody` writes two lines, and neither mentions gravity.
- **Four requirements move from `gap` to `covered`** on acceptance: TR-props-003,
  005, 006, 008. Coverage moves from 41 to 45 of 52, assuming ADR-0012 is Accepted
  first.
- **A latent load-order defect is closed** before the first prop exists, rather than
  after eight levels have been authored against it (D11.5).
- **ADR-0004's open deferral is closed** with a reasoned no, so it stops being an
  open question carried forward in three documents.
- **No frozen signature is reopened.** `register_prop()`, `unregister_prop()`,
  `consume()`, `update_pour()` and the `Tuning` reach are all untouched. This ADR
  adds one class, one export, and two lines inside an existing method.
- **AC3, the criterion the GDD says will actually fail, is covered by construction**
  rather than by care: the wake loop is ADR-0001's, the registry is ADR-0001's, and
  `PropBody` only has to join and leave it.

### Negative

- **`level_bounds` must be authored in all 8 levels** before `validate()` returns
  empty. This is real migration work that did not exist before this ADR, and it
  lands on the level migration epic.
- **Runtime prop spawning is now banned** (D11.4). Any future feature that wants a
  breakable crate spawning debris, or a prop dropped by an event, needs a new
  decision first. This is a deliberate cost paid for a structural R6.
- **BUG-0001 stays open.** This ADR names the correct mask and declines to apply
  it. A reader could reasonably expect an ADR that touches the kill plane's mask to
  fix the kill plane. It does not, and the reason is a playtest, not an oversight.
- **AC10 has no gate level.** `physics-props.md` types it *Performance*, and
  `.claude/docs/coding-standards.md`'s evidence table has no Performance row — only
  Logic, Integration, Visual/Feel, UI and Config/Data. This ADR specifies how to
  measure it (V7) and does not re-type it. Whether it gates as BLOCKING or ADVISORY
  belongs to the GDD or to a testing-standards pass. *This is the same shape as the
  AC10 tension ADR-0012 recorded for `watering-system.md`, and it is the second
  instance — which suggests the standards table, not the two GDDs, is the thing
  that needs the edit.*
- **The camera half of the session-18 findings stays unowned.** See Risks.

### Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| ~~`_integrate_forces` is called on sleeping bodies~~ | **Closed** | Confirmed against 4.7.1-stable engine source at review. It is not. Retained as a row so the question is visibly answered rather than absent. |
| **40 bodies waking in one substep spike the frame beyond 16.6 ms** — through solver cost, not script cost | Medium | The real AC10 risk, and it is not mitigated by anything in this ADR. V7 measures it. If it fails, the levers are `props_per_level_budget` (ADR-0006 owns it, range 10–80) and per-prop `can_sleep`, not a change to D11.2. |
| **A prop authored outside `level_bounds` is never freed** | Medium | `V-BOUNDS` catches it at load. Runtime is too late; load is the right gate for an authoring error, which is how `physics-props.md` §5 already classifies over-budget prop counts. |
| **`level_bounds` is authored too tight**, freeing props that are still in play | Medium | Props are cosmetic, so the failure is visible rather than dangerous — furniture disappears where the player can see it. Caught by AC11's visual sign-off, not by a test. |
| **A future author adds a prop that spawns at runtime**, silently breaking R6 | Medium | D11.4 registers `runtime_prop_instantiation` as forbidden. Honestly assessed: this is enforced by review and grep, not by structure — the same weakness ADR-0004 D4.6 admits about its own runtime-mutation ban. |
| **The `reset_to()` write happens in a window that does not reach the first physics step** | Low | V-E2 confirms it by test. If it fails, the fallback is a dirty flag consumed by the authority's own `_physics_process`, costing one frame of stale space gravity at load. |
| **The camera renders unrotated on level load** — session-18 finding 3 | Medium | **Not mitigated here.** See the flagged gap below. |

### Flagged gap — the camera's first broadcast (session-18 finding 3)

`architecture-review-2026-08-15-b.md:86-88` found that ADR-0003 D3.1 puts
`reset_to()` (and its first broadcast) at step (e), and the wiring pass at step
(f), strictly after. If the camera's `connect()` lands at (f), it is not subscribed
when (e) fires, and the camera renders unrotated on every level load. No ADR states
whether the camera reads `GravityAuthority.gravity` once at its own `_ready()` as a
fallback.

**This ADR does not fix it.** The finding is camera wiring inside an Accepted ADR's
frozen init order, and props are unaffected — D11.5 makes the space write reach
props through the space, not through the signal, so a prop that registers at step
(f) still reads correct gravity. Recording the gap here is deliberate: it keeps the
finding attached to a live document rather than only to a review report, without
amending ADR-0003. **Owner: unassigned. Candidates are ADR-0010 or a camera ADR.**

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `physics-props.md` | **R6 / AC8** — props reset to authored transforms on restart (TR-props-003) | D11.4. Structural, via ADR-0002's reconstruction restart. The ban on runtime spawning is what keeps it structural |
| `physics-props.md` | **R7 / AC9** — props leaving level bounds are freed (TR-props-005) | D11.3. One `LevelBounds` area per level, mask `8`, `body_exited` → `queue_free()`. Gravity-agnostic on all four sides |
| `physics-props.md` | **§4 / §7 / AC7** — fall-speed cap; per-prop mass and damping (TR-props-006) | D11.2 clamps magnitude in `_integrate_forces`. D11.1 keeps `mass`, `friction`, `bounce` and both damps per-scene |
| `physics-props.md` | **R8 / AC10** — a room at budget holds 60 FPS during a flip (TR-props-008) | V7 specifies the harness. Gate level flagged, not decided — see Consequences → Negative |
| `physics-props.md` | **R5 / AC3** — sleeping props are force-woken (TR-props-004, already covered by ADR-0001) | Not re-claimed. D11.1 only joins ADR-0001's registry. V3 verifies the deferred criterion ADR-0001 assigned here (`adr-0001:553`) |
| `physics-props.md` | **R1 / R2 / AC1 / AC2** — cosmetic isolation (TR-props-002, already covered by ADR-0004) | Not re-claimed. D11.1 and D11.3 consume ADR-0004's allocation and add no guard |
| `physics-props.md` | **R3 / R4 / AC4** — eased vector, symmetric (TR-props-001, already covered by ADR-0001) | Not re-claimed. D11.5 repairs the one path where ADR-0001's mechanism did not fire |
| `gravity.md` | **AC12** — props adopt the vector on the same physics frame as the player | Preserved. D11.5 adds a write and removes none |

TR-props-004 and TR-props-007 are already `covered` by ADR-0001 and ADR-0003. This
ADR does not re-claim either.

## Performance Implications

- **CPU, steady state**: zero added script cost. Settled props sleep, so
  `_integrate_forces` is not called, and the wake loop idles once the ease
  completes. This is the `architecture.yaml:910` budget line, unchanged.
- **CPU, during a flip**: at most 40 `_integrate_forces` clamps plus ADR-0001's 40
  `sleeping = false` writes per frame, over roughly 6–7 frames per gravity change
  at 60 FPS. Each clamp is one length comparison and, rarely, one normalise.
- **CPU, during a flip — the engine-side half.** The bullet above counts *script*
  cost only, and script cost is not what threatens the budget. Waking 40 bodies in
  one substep also moves them all onto the solver's active list, which forces a
  broadphase AABB refresh, narrow-phase pair regeneration, and contact-solver
  iterations for every prop that was resting on terrain. That engine-side cost is
  the more plausible source of a frame spike than any line of GDScript in this ADR.
  **V7 exists to measure it, not to confirm a foregone conclusion.**
  *(Added 2026-08-16 — engine specialist review.)*
- **CPU, level load**: two extra `PhysicsServer2D.area_set_param` calls per load
  or restart (D11.5). Not measurable.
- **Memory**: one `Area2D` and one `CollisionShape2D` per level, plus 40 rigid
  bodies at budget. No pooling, no persistence, nothing retained across a reload.
- **Draw calls**: 40 prop sprites against a 500 budget. `physics-props.md` R8 owns
  the ceiling; ADR-0006 owns the knob.
- **Load time**: unchanged. `V-BOUNDS` adds one node-count pass over props already
  being counted by `V-PROP-BUDGET`.

## Migration Plan

Ordered. Steps 1 to 3 are self-contained. Step 4 is the level authoring pass.

1. **Land ADR-0001 Changeset B** — parts 4, 4a and 4b in `gravity_authority.gd`:
   the two space writes, the per-frame ease write, and the force-wake loop over the
   registry. These have no observable effect until step 2 adds a body.
2. **Add `reset_to()`'s synchronous space write** (D11.5), and extend ADR-0001's V6
   to assert the *space parameter*, not only the `gravity` field. V6 as written
   would pass while the defect was live.
3. **Author `src/scripts/props/prop_body.gd` and `prop_body.tscn`** (D11.1, D11.2).
   Layer and mask come from the `CollisionLayers` constants. Verify both mask
   directions against ADR-0004 D4.3's table before authoring a second prop scene.
4. **Add `LevelBounds` to all 8 level scenes** and wire `LevelRoot.level_bounds`
   (D11.3). Add the `V-BOUNDS` rule and the `level_bounds` row to `V-WIRING`'s
   required-consumer table.
5. **Author props into levels** up to `props_per_level_budget`. `V-PROP-BUDGET`
   becomes live the moment `PropTuning` and the first `PropBody` both exist.

**Not in this plan, deliberately**: fixing BUG-0001 (D11.6 — needs a playtest), and
fixing the camera's first-broadcast gap (unowned, see Flagged gap).

**Regression watch**: `gravity.md` AC1–AC12 must still pass after step 1. Changeset
B touches the authority, and the player reads the same object.

## Validation Criteria

| # | Test | Type | Source |
|---|---|---|---|
| **V1** | A `PropBody` moving at 3 000 px/s in a 2.0× zone reports `linear_velocity.length()` ≤ `prop_max_speed` on the next physics frame, at gravity angles 0°, 90°, 180° and 270° | Logic | `physics-props.md` AC7, §4 |
| **V2** | A prop falling 200 px at `m` = 1.0 takes 0.229 s ± 5%, and the clamp never engages during that fall | Logic | AC5 — guards D11.2 against Alternative 1's failure |
| **V3** | A prop that is `sleeping` at the moment gravity changes has non-zero `linear_velocity` on the **next** physics frame | Logic | AC3; the criterion ADR-0001 deferred here (`adr-0001:553`) |
| **V4** | Fall time is identical upward and downward at the same `m`, to within float tolerance | Logic | AC6, R4 |
| **V5** | A `PropBody` driven outside `level_bounds` is freed within one physics frame of `body_exited`, and `GravityAuthority`'s registry is empty afterwards | Integration | AC9, R7; also covers ADR-0001 V7 |
| **V6** | After `reload_current_scene()`, `PhysicsServer2D.area_get_param(space, AREA_PARAM_GRAVITY_VECTOR)` equals the new level's `default_gravity_direction` **before** any zone fires | Integration | D11.5. This is the test ADR-0001's V6 could not perform |
| **V7** | 40 `PropBody` instances, one scripted 90° flip, frame time sampled across the ease window stays under 16.6 ms | *Performance — see below* | AC10, R8, TR-props-008 |
| **V8** | `validate()` returns `[V-BOUNDS]` when `level_bounds` is unset, and when a `PropBody` starts outside its extent | Integration | D11.7 |
| **V9** | After a restart, every `PropBody` global transform equals its authored value, following a flip that scattered them | Integration | AC8, R6, D11.4 |

**V7's evidence type is unresolved and this ADR does not resolve it.**
`physics-props.md` types AC10 *Performance*; `.claude/docs/coding-standards.md`
defines no Performance row, so the gate level is undefined. The measurement is
specified above either way. See Consequences → Negative.

**V-E1, V-E2 and V-E3** in Engine Compatibility are engine-fact checks against the
pinned 4.7.1 binary, not acceptance tests. They confirm the three claims this ADR
makes about engine behaviour rather than about the game.

**This decision is correct if** a level author can drop a `PropBody` into a scene,
author its mass and damping, and get correct gravity, a correct speed cap, correct
freeing and a correct restart — having written no code and read no ADR.

## Related Decisions

- **ADR-0001** Gravity ownership and global broadcast — supplies parts 4, 4a and 4b
  (Changeset B), the prop registry, and the wake loop. D11.5 repairs one path in
  part 4a that never fired. `adr-0001:530`, `adr-0001:553`
- **ADR-0002** Level state ownership — supplies the reconstruction restart that
  makes D11.4 structural
- **ADR-0003** Level load validation contract — receives `V-BOUNDS` and the
  `level_bounds` row in the `V-WIRING` required-consumer table, per its own D3.3
  rule. Already owns `V-PROP-BUDGET`
- **ADR-0004** Collision layer allocation — supplies layer `8` / mask `9`. Its
  open deferral on `KillArea2D` masking `prop` is **closed with a no** by D11.3.
  `adr-0004:428`, `adr-0004:500`
- **ADR-0005** Frame ordering — places `GravityAuthority` at
  `process_physics_priority = -100`, which parts 4a and 4b presuppose
- **ADR-0006** Tuning resource strategy — supplies `PropTuning`, its three knobs,
  and the `Tuning.PROP` reach D11.2 uses
- **ADR-0012** Spent jug throw and lifetime — **no relationship.**
  `physics-props.md` §6 and `watering-system.md:261` both exclude buckets and spent
  jugs from prop physics
- `production/qa/bugs/BUG-0001.md` — D11.6 names the fix and declines to apply it
- `docs/architecture/architecture-review-2026-08-15-b.md:80-84`, `:86-88` — the two
  session-18 findings. The first is fixed by D11.5. The second is flagged, unowned
- `design/gdd/physics-props.md` · `design/gdd/gravity.md`
- `docs/engine-reference/godot/modules/physics-2d.md`
