# Control Manifest

> **Engine**: Godot 4.7.1
> **Last Updated**: 2026-08-17
> **Manifest Version**: 2026-08-17
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

Two Core Layer rules are sourced from GDDs and a playtest finding rather than an
ADR, and cite their source accordingly. They are deliberately **not** registered in
`docs/registry/architecture.yaml` — every entry there carries an owning ADR, and
neither of these has one.

> **Scheduling note (ADR-0011):** ADR-0011's architecture is Accepted and binding,
> but `art-bible.md` §1.3 defers physics-prop *content* to Vertical-Slice tier —
> MVP's "the room moves" proof is already satisfied by camera tween + sprite
> rotation alone. This does not relax any rule below; it only says when prop
> content gets authored.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture (gravity broadcast, state
injection), save/load (level validation), engine init*

### Required Patterns

- **Gravity is owned exclusively by the `GravityAuthority` autoload.** Read via
  `GravityAuthority.gravity` / `.up_dir` / `.right_dir`, or by connecting to
  `gravity_changed(direction, multiplier)`. Written ONLY by `set_gravity()` /
  `reset_to()`. — source: ADR-0001
- **`GravityAuthority` must be a *scene* autoload** (`gravity_authority.tscn`
  with script attached), never a bare script autoload — a bare script autoload
  gives `@export var direction_ease_rate` no inspector surface. — source: ADR-0001
- **Do NOT declare `class_name` on `gravity_authority.gd`.** It is reached only
  through the autoload singleton name; a `class_name` would create two competing
  global identifiers. — source: ADR-0001
- **The gravity space write (`PhysicsServer2D.area_set_param`) must happen in
  `_physics_process`, never `_process`**, every frame while `gravity != target_gravity`. — source: ADR-0001 (part 4a)
- **Registered props must be force-woken via `prop.sleeping = false`** on every
  frame the vector changes, never via `apply_impulse()`/`apply_force()` (those
  add visible momentum). — source: ADR-0001 (part 4b)
- **`unregister_prop()` MUST be called from `PropBody._exit_tree()`** — covers
  both out-of-bounds freeing and scene reload with one call site. — source: ADR-0001
- **Every level must declare `default_gravity_direction` / `default_gravity_multiplier`
  exports on `LevelRoot`**; `GravityAuthority.reset_to()` is called from
  `LevelRoot._ready()` (not `GameManager`). — source: ADR-0001, amended by ADR-0002
- **Jump constants (`jump_height`, `jump_distance_to_peak`, `jump_distance_to_land`)
  stay `@export` on `Player`, never in a tuning resource.** User decision, reaffirmed
  twice — see `jump_constants_location`. — source: ADR-0001 part 7, ADR-0006 D6.7
- **`LevelState` and `OxygenState` are plain `RefCounted` objects constructed by
  `LevelRoot._ready()`**, never autoloads or singletons. — source: ADR-0002
- **Restart = `reload_current_scene()` alone.** No `reset()` methods anywhere;
  restart correctness is object lifetime, not a hand-maintained clear function. — source: ADR-0002
- **Every injected consumer must guard "not bound" with `push_error()` and refuse
  to operate before `bind()` is called** by `LevelRoot._ready()`. — source: ADR-0002
- **Use `push_error()`, never `assert()`, for bind/initialize guards** — `assert()`
  compiles out entirely in release exports. — source: ADR-0001, ADR-0002
- **`OxygenState._init(capacity, tuning)` validates `capacity > 0` at construction.**
  A non-positive capacity is not constructible. — source: ADR-0002
- **Every derived or externally-immutable field on `LevelState`/`OxygenState` is a
  getter-only computed property over a private backing field, never a plain `var`.**
  A plain `var` compiles a public setter that silently defeats the guarantee. — source: ADR-0002
- **`consume_bucket()` is called only on a *completed* pour**, never on pickup or
  early release. — source: ADR-0002
- **`LevelValidation.validate()` runs BEFORE `LevelState`/`OxygenState` are
  constructed**, reading only raw authored `@export` scene data. — source: ADR-0003 (D3.1)
- **Level-content discovery is by recursive `get_children()` type scan
  (`node is Plant`, etc.), never by group membership.** A forgotten group
  assignment is invisible to validation and the level reports clean. — source: ADR-0003 (D3.2)
- **Do NOT use `Node.find_children()` with its default `owned = true`** for
  discovery — it silently drops descendants without a valid `owner`. If used at
  all, pass `owned = false` explicitly. — source: ADR-0003 (D3.2, F3)
- **`validate()` returns a `PackedStringArray` of coded findings**
  (`[V-CODE] message`); codes are stable contract, message prose may be reworded
  freely. — source: ADR-0003 (D3.4)
- **`validate()` never pushes an error itself.** It is a pure function; the
  caller (`LevelRoot`) iterates the result and `push_error()`s each finding. — source: ADR-0003
- **Six validation rules** (extended to seven by ADR-0011): `V-BUCKET-SUM`,
  `V-PLANT-MIN`, `V-OXY-CAP`, `V-GRAV-EXPORT`, `V-PROP-BUDGET`, `V-WIRING`,
  `V-BOUNDS`. Any future ADR that adds a `LevelRoot` consumer export or an
  authoring invariant adds a row to this table in the same changeset. — source: ADR-0003 (D3.3), ADR-0011 (D11.7)
- **One shared `count_buckets(level)` static primitive**, used both by
  `validate()`'s `V-BUCKET-SUM` and by `LevelRoot` to seed `LevelState`. — source: ADR-0003 (D3.5)
- **No `OS.is_debug_build()` guard on validation** — it runs in every build,
  including release. — source: ADR-0003 (D3.6)
- **The suite-wide CI test (instantiate all 8 levels, assert `validate()` empty)
  lands WITH the level migration epic, not before it** — it is red until then,
  and the coding standards forbid landing a skipped/failing test. — source: ADR-0003 (D3.7)
- **`class_name` is required on `Plant`, `Bucket`, `PropBody`** — the type scan
  depends on it, making these declarations load-bearing for correctness. — source: ADR-0003
- **Three separate `Resource` subclasses — `WateringTuning`, `OxygenTuning`,
  `PropTuning` — one per GDD.** Never combine into a single `GameTuning`. — source: ADR-0006 (D6.1)
- **File layout**: scripts in `src/scripts/tuning/`, authored data in
  `src/resources/tuning/`. — source: ADR-0006 (D6.2)
- **Consumers reach tuning ONLY through `class_name Tuning`**
  (`Tuning.WATERING` / `.OXYGEN` / `.PROP`); no consumer names a `.tres` path
  itself. — source: ADR-0006 (D6.3)
- **Use `preload()`, never `load()`, for `Tuning`'s constants** — a missing/renamed
  file then fails at parse time (loud, at startup) rather than as a runtime null. — source: ADR-0006
- **`Tuning` is NOT an autoload and must never become one.** `preload` already
  gives it universal reach with no `SceneTree` dependency. — source: ADR-0006
- **Every tuning knob is `@export_range`, using the GDD-documented range
  verbatim.** — source: ADR-0006 (D6.4)
- **Tuning resources are read-only at runtime** — no writes, no `.duplicate()`
  to obtain a mutable copy (Godot caches `.tres` by path, so this is enforced
  by review/grep, not structure). — source: ADR-0006 (D6.5)
- **`resource_local_to_scene` stays `false` on all three tuning `.tres` files.** — source: ADR-0006 (D6.9)

### Forbidden Approaches

- **Never set `gravity_space_override` (or `gravity`) on any `Area2D`**,
  including `GravityZone` — gives props per-region gravity, breaking
  `gravity.md` R2/R9 and AC12. — source: ADR-0001 (`area2d_gravity_space_override`)
- **Never use `apply_central_force()` for gravity, or per-prop `gravity_scale`
  tuning** — costs 40 script callbacks/frame for variation the design forbids;
  use default-space gravity. — source: ADR-0001 (`per_prop_gravity_application`)
- **Never cache gravity/target_gravity on any node** instead of reading
  `GravityAuthority` — a cached copy can silently diverge. — source: ADR-0001 (`private_gravity_copy`)
- **Never recompute `jump_velocity` after `initialize()`**, including any
  bucket-carry weight penalty — fixed launch velocity is what makes a jump gap
  provably crossable from the zone multiplier alone. — source: ADR-0001 (`recompute_jump_velocity`)
- **Never call `set_gravity()`/`reset_to()` before `GravityAuthority.initialize()`**
  — the asymmetry ratio is silently lost (defaults to 1.0). — source: ADR-0001 (`broadcast_before_initialize`)
- **Never connect a `GravityZone` directly to the player, or call
  `Player.set_gravity()`** — that method is removed; zones report to the
  authority only. — source: ADR-0001 (`zone_targets_player_directly`)
- **Never reach level or oxygen state through an autoload, a new singleton, or
  a service locator.** State is owned by `LevelRoot` and injected. — source: ADR-0002 (`global_level_state_access`)
- **Never add `reset()` to `LevelState` or `OxygenState`, or reintroduce
  `GameManager.reset_level_state()`.** Restart is reconstruction, not a clear
  call. — source: ADR-0002 (`level_state_reset_method`)
- **Never connect `OxygenState.depleted` directly to `LevelRoot.restart_level()`**
  — breaks `suit-oxygen.md` AC8; `OxygenDrain` owns the kill policy and the
  `level_complete` suppression. — source: ADR-0002 (`depleted_wired_to_restart`)
- **Never read `LevelState`/`OxygenState` in a consumer's own `_ready()`, or
  before `bind()` has run** — `_ready()` is bottom-up; state doesn't exist yet. — source: ADR-0002 (`state_access_before_bind`)
- **`Plant` (or any single objective) must never write level-wide state or
  decide the level is complete.** It emits `pour_completed` and holds no level
  state. — source: ADR-0002 (`plant_decides_level_outcome`)
- **`LevelValidation.validate()` must never return on the first breach** —
  it must collect and return ALL contract violations in one pass. — source: ADR-0003 (`validation_first_failure_return`)
- **Never discover plants/buckets/props via `get_nodes_in_group()` inside
  `LevelValidation`** — `get_nodes_in_group()` is a `SceneTree` method and is
  unavailable on the CI path (level instantiated, never added to a tree). — source: ADR-0003 (`group_based_level_discovery`)
- **Never use `Node.find_children()` with the default `owned = true` for level
  discovery** — see Required Patterns above. — source: ADR-0003 (`find_children_owned_default`)
- **Never assign to any property of `Tuning.WATERING` / `.OXYGEN` / `.PROP`, and
  never call `.duplicate()` on a tuning resource.** — source: ADR-0006 (`tuning_resource_runtime_mutation`)
- **Never set `resource_local_to_scene = true`** on any of the three tuning
  `.tres` files — silently destroys the single-shared-instance guarantee. — source: ADR-0006 (`tuning_resource_local_to_scene`)
- **Never create a `GravityTuning` resource, or relocate the jump constants off
  `Player` into a `.tres`.** Changing this requires superseding
  `jump_constants_location`, not extending ADR-0006. — source: ADR-0006 (`gravity_tuning_resource`)
- **Never write a `res://src/resources/tuning/` path literal outside
  `src/scripts/tuning/`.** The path is written down exactly once, in `tuning.gd`. — source: ADR-0006 (`tuning_path_literal_outside_holder`)

### Performance Guardrails

- **`prop_gravity`**: 0 per-frame script cost in steady state; ≤40-prop wake
  pass only while the vector is easing (~6–7 frames per gravity change at
  60 FPS) — source: ADR-0001

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems (movement, gravity,
watering, oxygen), physics, collision*

### Required Patterns

- **Four allocated collision bits: `WORLD=1`, `PLAYER=2`, bit 3 RETIRED (never
  claim), `PROP=8`.** Bits 5–32 are unallocated; claiming one requires
  amending ADR-0004. — source: ADR-0004 (D4.1)
- **All detector `Area2D`s** (`Bucket`, `Plant`, `Goal`, `GravityZone`,
  `SpikeHazard`, `KillArea2D`) **carry `collision_layer = 0`, `collision_mask = 2`
  (PLAYER)** — detectors need no layer of their own. — source: ADR-0004
- **`class_name CollisionLayers` is the authoritative source**; `project.godot`'s
  `layer_names` are editor-facing cosmetic only — on divergence, `CollisionLayers`
  is correct and `project.godot` is the bug. — source: ADR-0004 (D4.4)
- **Verify both mask directions for every isolation guarantee.** Body-vs-body
  pairing is an OR, not an AND — a one-sided mask mistake still produces
  contact. — source: ADR-0004 (L3)
- **The collision-layer gdUnit4 test must assert derived bit invariants
  (`mask & LAYER == 0`), never raw integer equality** — raw equality breaks the
  moment an unrelated bit is legitimately added. — source: ADR-0004 (D4.5, F6)
- **`process_physics_priority` (never `process_priority`) is assigned in code
  from a `FramePriority` const-only script**: `-100 GravityAuthority`,
  `0 Player (+components inline)`, `+100 OxygenDrain`. Never per-scene in the
  inspector — 8 level scenes = 8 chances to drift. — source: ADR-0005 (D5.1, F1)
- **`FramePriority` constants live on their own const-only script, NOT on
  `LevelRoot`** — `GravityAuthority` is an autoload present before any level
  scene loads and cannot source a constant from a per-level script. — source: ADR-0005 (A5-05)
- **`OxygenDrain` arms on depletion and evaluates the kill at the TOP of its
  NEXT physics callback — never in the same callback that observed
  `remaining <= 0`.** — source: ADR-0005 (D5.2)
- **`level_complete` is a write-once latch, owned by `LevelState`, written ONLY
  via `mark_complete()` from `LevelRoot._on_player_reached_goal()`.** No path
  anywhere may set it back to `false`. — source: ADR-0005 (D5.3)
- **`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path
  must check and set `_transition_pending`.** The latch alone is insufficient —
  inter-area signal delivery order within one physics tick is undetermined. — source: ADR-0005 (D5.4, A5-02)
- **Any rule-bearing quantity whose value on a specific frame decides an
  outcome (pour progress, oxygen, death timers) must live in `_physics_process`,
  never `_process`.** Cosmetic-only work (camera follow, sprite placement,
  animation) legitimately stays in `_process`. — source: ADR-0005 (D5.5)
- **`level_complete` freezes `OxygenDrain` entirely** — no `drain()` call, not
  only no kill — so the HUD holds its final reading through the transition. — source: ADR-0005 (D5.6)
- **`Player._physics_process` reads `GravityAuthority.gravity`/`.up_dir`/`.right_dir`
  fresh every frame into locals and threads them as parameters** — no component
  stores a gravity-derived value in a field that survives past the callback. — source: ADR-0007 (D7.1)
- **`up_direction = GravityAuthority.up_dir` must be the FIRST statement in
  `Player._physics_process`**, before any `is_on_floor()`/`is_on_wall()`/
  `move_and_slide()` call in the same callback. — source: ADR-0007 (`Player.up_direction_sync`)
- **`PlayerGravityComponent` is near-stateless**: retains only `initialize()`,
  `jump_velocity` (read-only after init), and `apply_gravity()` as a pure
  function taking gravity/ascent/descent as parameters. It does NOT derive its
  own `up_dir`/`right_dir` — every consumer reads `GravityAuthority` directly. — source: ADR-0007 (D7.2)
- **Fixed call order inside `Player._physics_process`'s single
  `process_physics_priority = 0` slot**: 1) up_direction sync, 2) watering
  lockout gate, 3) gravity, 4) wall jump, 5) jump, 6) movement, 7)
  `move_and_slide()`, 8) visuals (runs UNCONDITIONALLY, watering or not). — source: ADR-0007 (D7.3)
- **Camera-relative axis inversion exists in exactly one place**:
  `GravityAuthority.apply_camera_relative_axis()` (static). Both
  `PlayerMovementComponent` and `PlayerVisualComponent` call it — never
  independent copies. — source: ADR-0007 (D7.4)
- **`OxygenDrain` is a child of `LevelRoot`, `process_physics_priority = +100`,
  running: freeze-if-complete → armed-restart → `drain()` → arm-on-depletion.** — source: ADR-0008 (§1)
- **Pause halts drain via `SceneTree.paused` + the default
  `PROCESS_MODE_INHERIT` (resolves to `PAUSABLE`) — no injected pause-state
  object.** `LevelRoot` and every ancestor between `OxygenDrain` and the tree
  root must stay `PROCESS_MODE_INHERIT` (or explicit `PAUSABLE`). — source: ADR-0008 (§2)
- **Effective drain pre-scales `delta` by `OxygenAccessibility.drain_rate_multiplier`
  before calling `OxygenState.drain(scaled_delta)`** — `OxygenState`'s signature
  and internal logic (multiplying by `tuning.drain_rate`) stay unchanged. — source: ADR-0008 (§3)
- **`OxygenAccessibility` is a scene autoload** (not bare script), so
  `@export_range(0.5, 1.0)` gets inspector surface; `drain_rate_multiplier` is
  clamped via `set_drain_rate_multiplier()`. — source: ADR-0008
- **Comment `scaled_delta` at the call site as accessibility-scaled, not raw
  wall-clock delta** — future code must not reuse it for real elapsed time. — source: ADR-0008
- **Pour-driving (`water_progress`, interact/target check, completion,
  early-release) lives on `PlayerWateringComponent`, never on `Plant`.** — source: ADR-0009 (D1)
- **`PlayerWateringComponent.update_pour()` runs ONLY via `Player._physics_process`
  step 2's inline call** — the component is never independently scheduled. — source: ADR-0009 (D2)
- **`Plant` carries NO `process_physics_priority` assignment** — it has no
  per-frame rule-bearing work once pour-driving lives on the player component. — source: ADR-0009
- **Targeting is `LevelRoot`-mediated candidate registration**: `Plant` emits
  `player_entered_range`/`player_exited_range`; `LevelRoot` wires them to
  `register_candidate()`/`unregister_candidate()` on the watering component. — source: ADR-0009 (D3)
- **Capacity (`is_capped()`) is checked ONLY at target selection, never inside
  the accumulation loop** — a capped plant is never assigned as `_target_plant`. — source: ADR-0009 (R5)
- **`Bucket` calls `pickup_bucket()` directly on the detected player** — a
  two-party spatial interaction needs no `LevelRoot` mediation. — source: ADR-0009 (D4)
- **`Bucket extends Area2D`** (not `Node2D`). — source: ADR-0009 (TR-watering-016)
- **`Bucket.on_picked_up()` must use `set_deferred("monitoring", false)`** —
  called from `_on_body_entered`, itself fired during
  `PhysicsServer2D::flush_queries()`; a synchronous mutation there raises a
  runtime error. — source: ADR-0009 (D4)
- **No watering code subscribes to `GravityAuthority.gravity_changed`** —
  interact/pickup overlap is pure layer/mask detection and does not consult
  gravity direction; a flip cannot spuriously enter/exit an area. — source: ADR-0009 (D5)
- **`PropBody extends RigidBody2D` is the only prop type**, carrying
  `collision_layer = 8` / `collision_mask = 9` via the `CollisionLayers`
  constants — never literals. — source: ADR-0011 (D11.1)
- **Fixed per `PropBody`, never authored per instance**: `custom_integrator = false`,
  `gravity_scale = 1.0`, `collision_layer`/`collision_mask`. — source: ADR-0011
- **`PropBody._ready()` calls `GravityAuthority.register_prop(self)`;
  `_exit_tree()` calls `unregister_prop(self)`** — both mandatory. — source: ADR-0011
- **The fall-speed cap clamps `linear_velocity` magnitude inside
  `_integrate_forces(state)`, never in `_physics_process`** — the engine only
  calls `_integrate_forces` on an active body, so a settled prop costs zero
  per-frame cost. — source: ADR-0011 (D11.2)
- **`prop_max_speed` is read only through `Tuning.PROP`**, never a literal path. — source: ADR-0011
- **Out-of-bounds props are freed via ONE exported `LevelBounds` `Area2D`
  (layer 0 / mask 8) per level, `body_exited → queue_free()`** — never `free()`,
  and never via the kill plane (which catches only one of four gravity
  directions). — source: ADR-0011 (D11.3)
- **No prop may be spawned, pooled, respawned, or persisted at runtime** —
  props are authored scene children only; restart correctness depends on it. — source: ADR-0011 (D11.4)
- **`GravityAuthority.reset_to()` must write the two space parameters
  SYNCHRONOUSLY** (in addition to the per-frame ease-gate write), not only
  while easing — otherwise a `reload_current_scene()` inherits the previous
  level's stale space gravity. — source: ADR-0011 (D11.5)
- **Zone-entry triggers evaluate their condition every frame, never on the signal
  edge.** Track overlap as continuous state — `body_entered` sets it,
  `body_exited` clears it — and test the trigger condition in
  `_physics_process`. A trigger gated on the raw `body_entered` edge silently
  never fires when the body is already inside the area at the moment the
  condition becomes true. **This is a silent-failure trap: the broken and working
  cases look identical to the player.** It shipped in the vertical slice's goal
  and cost a live debugging session. — source: `level-flow.md` §4, vertical-slice
  `REPORT.md` 2026-08-17
- **Movement input is screen-relative at every gravity angle.** Pass the raw axis
  through the one shared sign function before applying it to `right_dir`, so
  `move_right` always moves the player toward the right of the screen — and
  toward the top of the screen under horizontal gravity. This holds
  **unconditionally**; it is not gated on `camera_rotation_enabled`. — source:
  `gravity.md` R11. ⚠ **Conflicts with ADR-0007 D7.4**, which still returns the
  raw axis when `camera_rotation_enabled` is false. R11 is the design stance;
  D7.4 needs a ruling

### Forbidden Approaches

- **Never enforce prop isolation with a type-check guard**
  (`if body is PropBody: return`) instead of layer/mask configuration — by the
  time a handler runs, contact has already resolved in the physics step. — source: ADR-0004 (`prop_isolation_by_conditional_guard`)
- **Never assign `collision_layer`/`collision_mask` at runtime, or call
  `set_collision_layer_value()`/`set_collision_mask_value()`, on any gameplay
  node.** Layers are authored data only. — source: ADR-0004 (`runtime_collision_mask_mutation`)
- **Never use collision bit 3, or any of bits 5–32.** — source: ADR-0004 (`unallocated_collision_bit`)
- **Never use `process_priority` to order `_physics_process` callbacks** —
  that property orders `_process`; `process_physics_priority` is separate. — source: ADR-0005 (`physics_order_via_process_priority`)
- **Never restart the level in the same `_physics_process` callback that
  observed `remaining <= 0`.** — source: ADR-0005 (`same_frame_oxygen_kill`)
- **Never write `level_complete` from any node other than
  `LevelRoot._on_player_reached_goal()`, and never set it back to `false`
  anywhere.** — source: ADR-0005 (`level_complete_written_outside_level_root`)
- **Never reload the level from a death/reset path that does not consult
  `level_complete`.** All death paths route through the guarded
  `restart_level()`. — source: ADR-0005 (`unguarded_restart_path`)
- **Never accumulate or evaluate a rule-bearing quantity in `_process`.** — source: ADR-0005 (`gameplay_timing_in_idle_process`)
- **Never set `process_thread_group` away from default on `GravityAuthority`,
  `Player`, or `OxygenDrain`** — silently detaches the node from the
  `-100`/`0`/`+100` ordering contract with no compile error. — source: ADR-0005 (`process_thread_group_split_in_frame_chain`)
- **Never let `Player._physics_process` return early from the watering-lockout
  branch before `visual_component.update()` runs** — step 8 (visuals) must run
  unconditionally, or the sprite freezes mid-pour. — source: ADR-0007 (`watering_lockout_skips_visuals`)
- **`OxygenState` (or any `RefCounted` state object) must never read
  `OxygenAccessibility` or any other autoload directly** — an autoload
  dependency breaks unit-testability. — source: ADR-0008 (`oxygen_state_reads_accessibility_autoload`)
- **Never inject a `PauseState` object into `OxygenDrain`/`OxygenState`, or add
  an explicit pause check inside their logic** — `SceneTree.paused` +
  `PROCESS_MODE_INHERIT` already gets the same result at zero cost. — source: ADR-0008 (`oxygen_pause_state_object`)
- **Never assign `process_physics_priority` to `Plant`, at any value.** — source: ADR-0009 (`plant_gains_process_physics_priority`)
- **Never add a `_physics_process`/`_process` override to
  `PlayerWateringComponent`'s script** — Godot auto-schedules any override it
  detects, double-driving `update_pour()` and silently halving the effective
  pour duration. — source: ADR-0009 (`watering_component_gains_own_physics_process`)
- **`PlayerWateringComponent`, `Plant`, and `Bucket` must never connect to
  `GravityAuthority.gravity_changed`.** — source: ADR-0009 (`watering_component_subscribes_gravity_changed`)
- **Never spawn, pool, respawn, or persist any `PropBody` at runtime** — props
  are authored scene children only. — source: ADR-0011 (`runtime_prop_instantiation`)
- **Never gate a win, unlock, or trigger condition on a raw `body_entered` /
  `body_exited` signal edge** when that condition can change while the body is
  already inside the area. Track overlap as state and re-evaluate per frame. — source: `level-flow.md` §4 / vertical-slice `REPORT.md`
- **Never apply the raw input axis directly to `right_dir`.** Under inverted
  gravity this mirrors the controls against the screen, which `gravity.md` R11
  forbids. — source: `gravity.md` R11

---

## Feature Layer Rules

*Applies to: secondary mechanics layered on core systems (spent-jug throw)*

### Required Patterns

- **`Bucket.throw_spent(up_dir, right_dir)` creates its own tween, plays the
  arc, and calls `queue_free()` on `tween.finished`.** `consume()` and
  `update_pour()` stay unchanged/frozen. — source: ADR-0012 (D12.1)
- **`up_dir`/`right_dir` are captured into LOCAL variables at the call site,
  before any deferral** — a mid-flight gravity flip must NOT re-aim the arc. — source: ADR-0012 (D12.2)
- **`right_dir` is passed in, never derived** from `up_dir` inside the jug —
  `GravityAuthority` already owns that computation. — source: ADR-0012 (D12.2)
- **Detach the jug via `top_level = true` + re-assign `global_position`**,
  never by reparenting (which mutates the tree inside a physics callback). — source: ADR-0012 (D12.3)
- **`monitorable = false` is set SYNCHRONOUSLY inside `throw_spent()`** —
  different physics window than `on_picked_up()`'s deferred write (`throw_spent()`
  runs in `SceneTree::physics_process()`, strictly after `flush_queries()`). — source: ADR-0012 (D12.4)
- **The tween is created via `Bucket.create_tween()`** so it's bound to the jug
  and inherits `PROCESS_MODE_INHERIT` — pauses with the game, no exemption
  needed or granted. — source: ADR-0012 (D12.5)
- **The arc curve uses `sin(theta)`, never `tan(theta)`, for lateral reach** —
  `tan` has a singularity at 90°, the top of the GDD's legal
  `throw_angle_spread` range. — source: ADR-0012 (D12.6)
- **Randomness is confined to the throw angle only** — no test may assert on
  jug position, only on free-time and node count. — source: ADR-0012 (D12.7)
- **`Bucket.consume()` and `PlayerWateringComponent.update_pour()` signatures
  stay frozen** — this ADR adds a call, it does not reopen either. — source: ADR-0012

### Forbidden Approaches

*(No new forbidden patterns registered by ADR-0012.)*

---

## Presentation Layer Rules

*Applies to: rendering, HUD, VFX, UI, animations*

### Required Patterns

- **The HUD root is a plain `Node` with FOUR SIBLING `CanvasLayer` zones
  (Z1–Z4), never nested.** Nested `CanvasLayer` has open engine issues where
  declared `layer` order is not honoured. — source: ADR-0010 (D10.1)
- **Zone ordering is by an explicit `CanvasLayer.layer` integer**
  (Z4 debug = 1, Z2 world-tracked = 2, Z1 player-tracked = 3, Z3 transient = 4),
  never by scene-tree position — a tree reorder must not change occlusion. — source: ADR-0010 (D10.1)
- **`follow_viewport_enabled` stays `false` (engine default) on all four zone
  layers.** — source: ADR-0010
- **World-tracked elements (Z1/Z2) project position via
  `tracked.get_global_transform_with_canvas().origin`**, not the
  canvas-transform-multiply form. — source: ADR-0010 (D10.2)
- **Rotation is NEVER assigned on any HUD `Control`** — the zero-rotation
  guarantee comes structurally from the `CanvasLayer`, not from arithmetic. — source: ADR-0010 (D10.2)
- **The world-tracking offset is applied AFTER projection, in viewport pixels,
  along `GravityAuthority.up_dir`** (read every frame, never cached in a
  surviving field). — source: ADR-0010 (D10.2)
- **Collision-avoidance displacement uses `Control.offset_transform_position`**,
  never a direct write to `position` (which is recomputed from the world every
  frame and would discard the displacement). — source: ADR-0010 (D10.2)
- **`offset_transform_enabled = true` must be set in the `.tscn`**, not at
  runtime, on any `Control` the collision rule displaces. — source: ADR-0010 (D10.2)
- **The HUD's 10 layout knobs are `@export` vars on `hud.gd`/`hud.tscn`** — no
  fourth `Tuning` resource; `ADR-0006` sized the tuning set at exactly three,
  one per GDD, and HUD layout is not gameplay data. — source: ADR-0010 (D10.3)
- **`HUD` holds direct references to `LevelState`/`OxygenState` via
  `bind(level_state, oxygen_state)`** — no read-only facade wrapper (both
  types are already write-proof or name their only legal callers). — source: ADR-0010 (D10.4)
- **`is_bound: bool` (public, no private twin) gates every HUD read path**;
  the first unbound draw calls `push_error()` once. — source: ADR-0010 (D10.4)
- **E1 (oxygen gauge) polls in `_process`; most other elements are
  signal/event-driven** — see `hud.md`'s per-element Update field for the full
  table. — source: ADR-0010 (D10.5)
- **E1 displays the COMPOSED `oxygen_remaining / drain_rate`**, not the raw
  `OxygenTuning` value. — source: ADR-0010 (D10.5)
- **The HUD reads in `_process`, not `_physics_process`** — it takes no row in
  the frame-ordering table by design. — source: ADR-0010 (D10.5)
- **`PauseController` (leaf node, `process_mode = PROCESS_MODE_ALWAYS`) is the
  ONLY writer of `SceneTree.paused`.** Every other HUD node stays at the
  default `PROCESS_MODE_INHERIT` (resolves to `PAUSABLE`); only
  `PauseController` and the debug overlay E7 use `PROCESS_MODE_ALWAYS`, and
  both exemptions are set on LEAF nodes only, never the HUD root. — source: ADR-0010 (D10.6)
- **The debug overlay (E7) is instanced at runtime, NOT present in
  `hud.tscn`**, behind an `OS.has_feature("debug")` check, with an
  `InputMap.has_action()` guard before registering its input action (the
  action would otherwise re-register — and log an error — on every level
  load). — source: ADR-0010 (D10.8)
- **The `hud` `NodePath` export on `LevelRoot` is a Required consumer in
  `V-WIRING`**, effective now that ADR-0010 is Accepted — every level must
  wire a HUD before `validate()` returns empty. — source: ADR-0010 (D10.9)

### Forbidden Approaches

- **Never nest a `CanvasLayer` inside another `CanvasLayer` to order HUD
  zones, and never order zones by scene-tree position instead of
  `CanvasLayer.layer`.** — source: ADR-0010 (`hud_zone_via_nested_canvaslayer`)
- **No HUD script (or any node under `hud.tscn`) may call a mutator on
  `OxygenState`, `LevelState`, `Plant`, or `PlayerWateringComponent`.**
  Enforced by grep/test, not structure — recorded as a known-weaker guarantee. — source: ADR-0010 (`hud_writes_game_state`)

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables/functions | snake_case | `move_speed` |
| Signals | snake_case, past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 FPS |
| Frame budget | 16.6 ms |
| Draw calls | < 500 per frame |
| Memory ceiling | 512 MB |

### Approved Libraries / Addons

- **gdUnit4** (`addons/gdUnit4/`) — approved for all automated testing. Treats
  GDScript warnings as errors at test *discovery* — one warning (a shadowed
  native method name, an unused variable, a narrowing conversion) fails the
  ENTIRE suite at compile time, not just one file. Every new script must be
  warning-clean; run the headless suite locally before calling a test step
  done.

### Forbidden APIs (Godot 4.7.1)

These APIs are deprecated or changed for the pinned engine version — source:
`docs/engine-reference/godot/deprecated-apis.md`, `breaking-changes.md`:

- `RichTextLabel.add_image(..., width_in_percent, height_in_percent)` /
  `update_image()` — use `width_unit`/`height_unit` typed
  `RichTextLabel.ImageUnit`, and `float` (not `int`) sizes. (GH-112617; no
  element in the current HUD design uses `RichTextLabel`, so the hazard is
  avoided rather than managed.)
- `Control.accessibility_live` typed as `DisplayServer.AccessibilityLiveMode`
  — moved to `AccessibilityServer.AccessibilityLiveMode`. GDScript call sites
  are unaffected; only C# breaks. (GH-116839)
- `AudioEffectSpectrumAnalyzer.tap_back_pos` — removed, no replacement.
  (GH-114355)
- Bullet physics as the 3D default — replaced by native Jolt Physics (4.6+).
  Inert for this project: it is a 2D game and `3d/physics_engine` is unused.

### Cross-Cutting Constraints

- **Every cross-module link is a signal. No module calls upward.**
  (`architecture.md` — cited throughout ADR-0001 through ADR-0012.)
- **Contracts are enforced by structure, not by discipline, wherever
  structurally possible** — a rule that depends on every future author
  remembering it is not enforced. Where structural enforcement isn't possible
  (e.g. `runtime_collision_mask_mutation`, `tuning_resource_runtime_mutation`),
  the ADR says so plainly rather than overclaiming.
- **Level correctness fails loudly at load, never silently at play.**
  (`architecture.md` P4 — the principle behind `LevelValidation`.)
- **Tuning lives in data; ownership lives in code.** (`architecture.md` P5 —
  the principle behind the `Tuning` const holder.)
- **Use static typing everywhere**: `var speed: float = 200.0`,
  `func get_direction() -> Vector2:`.
- **An override of a method with a typed, non-void return must have an
  explicit `return` statement** (Godot 4.7 typed-return inheritance,
  GH-115763) — an implicit fallthrough that used to compile is now an error.
  This project enforces static typing everywhere, so this hits often; combined
  with gdUnit4's warnings-as-errors gate, one missing `return` can fail the
  whole test suite.
- **Use `@export`, not the old `export` keyword.**
- **Use `signal_name.emit()`, not `emit_signal("signal_name")`.**
- **Type-hint every signal parameter**: `signal health_changed(new_health: int)`.
- **Prefer composition over inheritance** — small, modular scenes/components
  rather than monolithic "God scripts" (see `src/scripts/components/`).
- **Prefer Godot `Resource`s (`.tres`) over raw dictionaries** for data
  independent of nodes.
- **Use `Control.offset_transform_*` for Control juice/transitions** (new in
  4.7) instead of pre-4.7 spacer-node or re-apply-after-sort workarounds.
  `offset_transform_enabled` defaults `false` (must be set explicitly, in the
  scene where possible — see `gravity_zone.gd`/`.tscn`); `offset_transform_visual_only`
  defaults `true` (mouse input hits the *un-offset* rect — a real trap for an
  animated pause menu; harmless for read-only HUD elements).
