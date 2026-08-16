# ADR-0007: Player component contract and physics step order

## Status

**Accepted** — 2026-08-15

Engine specialist review: no blocking issues (2026-08-15). TD-ADR review: CONCERNS
(5 findings, 2 blocking) → all 5 revised → re-review: CONCERNS (1 new gap in the
Architecture Diagram, 3 minor notes) → all revised → final confirmation pass:
**APPROVE** (2026-08-15).

## Date

2026-08-15

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (autoload access, static typing), Physics-2D adjacent (`CharacterBody2D`, `move_and_slide()`) |
| **Knowledge Risk** | **LOW.** `modules/physics-2d.md` certifies `CharacterBody2D`/`move_and_slide()` unchanged 4.4 → 4.7. `modules/core.md` already established (ADR-0005 F3) that `process_physics_priority` ordering is a single global sort across the default process group, which is the fact this ADR's freshness guarantee rests on. No new engine API is introduced by this decision — it composes APIs ADR-0001 and ADR-0005 already verified. |
| **References Consulted** | `docs/engine-reference/godot/modules/core.md`, `docs/engine-reference/godot/modules/physics-2d.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/breaking-changes.md`, plus `docs/architecture/adr-0001-gravity-ownership-and-global-broadcast.md` and `docs/architecture/adr-0005-frame-ordering-and-level-complete-guard.md` |
| **Post-Cutoff APIs Used** | None beyond what ADR-0001/ADR-0005 already verified (`process_physics_priority`, 4.1+). This ADR is pure GDScript composition — member access on an existing autoload, static method calls, typed parameter passing. |
| **Verification Required** | None outstanding — validated by `godot-specialist` against `docs/engine-reference/godot/modules/core.md`, `physics-2d.md`, `deprecated-apis.md`, `breaking-changes.md`, and the live component scripts on 2026-08-15. See Risks. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted — narrows `PlayerGravityComponent` and establishes `GravityAuthority` as sole owner of `gravity`/`target_gravity`/`up_dir`/`right_dir`/`baseline_ascent_mag`/`ascent_descent_ratio`). ADR-0005 (Accepted — fixes `Player` to a single `process_physics_priority = 0` slot with components "called inline," a phrase this ADR now defines precisely). Both must remain Accepted; this ADR resolves one internal inconsistency in ADR-0001's Decision prose (D7.2) in favor of ADR-0001's own registry entry, but does not reopen or renegotiate either ADR's actual decision. |
| **Enables** | ADR-0009 (watering interaction model, unwritten) — inherits this ADR's call-order contract and the claimed watering-lockout row (see D7.3). Any future story implementing `Player` or its five components. |
| **Blocks** | The Core epic covering `PlayerGravityComponent`, `PlayerMovementComponent`, `PlayerJumpComponent`, `PlayerWallJumpComponent`, `PlayerVisualComponent`. None of `TR-gravity-004/005/006/007/013` or `TR-watering-014` can move from `gap` to `covered` until this is Accepted. `TR-watering-002` is not closed by this ADR (see Decision D7.3, GDD Requirements Addressed) — it remains blocked on ADR-0009. |
| **Ordering Note** | Numbered next in sequence per `watering-system.md`'s own note that this should be written before ADR-0008 and ADR-0009 — both consume `Player`'s finished component contract (ADR-0008 needs a settled physics-step shape to slot `OxygenDrain`'s `+100` work against; ADR-0009 inherits this ADR's D7.3 watering-lockout row rather than re-deriving it). |

## Context

### Problem Statement

Two Accepted ADRs left a gap between them. ADR-0001 narrowed `PlayerGravityComponent` — it retains `initialize(max_speed)`, `apply_gravity()`, `jump_velocity`, and "derived basis," and loses `gravity`, `target_gravity`, `set_gravity()`, `update_gravity_lerp()` — but never specified how `apply_gravity()` obtains a gravity vector it no longer owns. ADR-0005 fixed `Player` (plus its components, "called inline") to a single `process_physics_priority = 0` slot, but never defined what "called inline" means: which component runs first, what data passes between them, or how the now-authority-owned gravity vector reaches components that need it every frame.

The current `src/scripts/player.gd` still calls `gravity_component.update_derived_dirs()` and `gravity_component.update_gravity_lerp(delta)` inline, and `PlayerGravityComponent` still holds `gravity`/`target_gravity`/`up_dir`/`right_dir`/`gravity_ascent_mag`/`gravity_descent_mag` as local fields — exactly the ownership ADR-0001 revoked. Left unresolved, the registry's `private_gravity_copy` forbidden pattern is already being violated by code that predates `GravityAuthority`'s existence, and nothing states what should replace it.

A second, smaller gap: `PlayerMovementComponent.apply()` and `PlayerVisualComponent.update()` both carry an identical camera-relative axis-inversion formula. `gravity.md`'s dependency table requires the visual component to "mirror movement's axis inversion exactly" (TR-gravity-013) — a requirement two independently-maintained copies of one formula cannot guarantee.

### Constraints

- `PlayerGravityComponent` must not become the `private_gravity_copy` the registry forbids. Any field that could grow stale relative to `GravityAuthority` is a defect, not a convenience.
- `Player`'s jump constants (`jump_height`, `jump_distance_to_peak`, `jump_distance_to_land`) stay `@export` on `Player` — a standing user decision (ADR-0001 `jump_constants_location`) this ADR must not revisit.
- `jump_velocity` must never be recomputed after `initialize()`, including under bucket carry (`recompute_jump_velocity` forbidden pattern, `gravity.md` R5/R10).
- The frame ordering contract (`-100` / `0` / `+100`) is closed; this ADR works inside the `0` slot, it does not reopen `frame_ordering_contract`.
- `watering-system.md` R2 requires carry speed to scale `max_speed` only — the movement component's contract must keep jump velocity and gravity strength untouched by anything watering-related.

### Requirements

- `PlayerGravityComponent.apply_gravity()` must read a gravity vector guaranteed fresh for the current frame, without storing a copy across frames.
- The order in which `Player`'s five components run inside the single physics slot must be explicit, reviewable in one place, and must not depend on scene-tree child order or signal connection order.
- The camera-relative axis-inversion formula must exist in exactly one place.
- `TR-gravity-004/005/006/007/013` and `TR-watering-014` must all move from `gap` to `covered` in the traceability registry once this ADR lands. `TR-watering-002` is out of reach for this ADR (see D7.3) and stays `gap`.

## Decision

### D7.1 — Live pass-through: `Player` reads `GravityAuthority` fresh every frame, nothing is cached

At the top of `Player._physics_process(delta)`, the facade reads `GravityAuthority.gravity`, `.up_dir`, `.right_dir`, `.ascent_magnitude()`, and `.descent_magnitude()` once, into local variables, and threads them as explicit parameters through every component call that needs them. No component — not `PlayerGravityComponent`, not any other — stores a gravity-derived value in a field that survives past the current callback.

This is safe by construction, not by convention: `GravityAuthority` runs at `process_physics_priority = -100`, strictly before `Player` at `0`, in the same physics frame (`frame_ordering_contract`, ADR-0005). A value read at the top of `Player`'s callback is therefore guaranteed to be this frame's value, never last frame's. No signal subscription is needed for this purpose — `gravity_changed` still exists and still serves `LevelRoot` (camera) and `PhysicsProps`, whose triggering condition really is "a change happened," unlike `Player`, which needs "the current value" unconditionally every frame regardless of whether it changed.

### D7.2 — `PlayerGravityComponent` becomes a near-stateless math component

**Retains:**
- `initialize(max_speed: float) -> void` — computes `baseline_ascent_mag`, `ascent_descent_ratio`, and `jump_velocity` from `Player`'s forwarded `jump_height`/`jump_distance_to_peak`/`jump_distance_to_land` exports (unchanged math from today's `initialize()`), then calls `GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio)` once to seed the authority. `baseline_ascent_mag` and `ascent_descent_ratio` are local variables inside this function — they are not kept as fields afterward. Only `jump_velocity` survives as a field, and it is read-only from this point on (`recompute_jump_velocity` stays forbidden).
- `jump_velocity: float` — set once by `initialize()`, read by `PlayerJumpComponent`, never touched by anything else.
- `apply_gravity(delta: float, velocity: Vector2, is_on_floor: bool, gravity: Vector2, ascent_mag: float, descent_mag: float) -> Vector2` — a pure function. `gravity`, `ascent_mag`, and `descent_mag` are parameters supplied fresh every call (D7.1), not fields. The asymmetric ascent/descent math itself (`gravity.md` R4) is unchanged from today's implementation, satisfying `TR-gravity-004`.

**Loses** (confirms and completes ADR-0001's narrowing): `gravity`, `target_gravity`, `set_gravity()`, `update_gravity_lerp()`, `update_derived_dirs()`, and the local `up_dir`/`right_dir`/`gravity_ascent_mag`/`gravity_descent_mag` fields. Every one of these either moved to `GravityAuthority` (ADR-0001) or is now a call-site parameter (D7.1) rather than component state.

This closes `TR-gravity-005` (`jump_velocity` derived once, never recomputed) and `TR-gravity-007` (carried mass affects speed only, never gravity or jump) by construction: `apply_gravity()` has no field a carry penalty could reach even by accident, because it has almost no fields left.

**This is a deliberate override of ADR-0001's prose, stated plainly rather than left implicit.** ADR-0001's Decision text says `PlayerGravityComponent` "derives its basis (`up_dir`, `right_dir`)... from the broadcast vector," which reads as the component still computing its own copy. But ADR-0001's own registry entry (`world_gravity_vector`, `docs/registry/architecture.yaml`) lists `up_dir` and `right_dir` as fields owned by `GravityAuthority`, with the note "no consumer may cache it." The two cannot both be true — a component that "derives its basis" from the vector is doing the same computation `GravityAuthority` already did, which is either a redundant duplicate or, if the results could ever disagree, a `private_gravity_copy` violation by a different name. This ADR resolves the inconsistency in favor of the registry entry: `PlayerGravityComponent` does not derive `up_dir`/`right_dir` at all, and every consumer reads them from `GravityAuthority` directly (D7.1). This is not "completing" ADR-0001's intent — it is choosing one of two things ADR-0001 said, over the other, and recording that choice here. (TD-ADR finding 4, 2026-08-15.)

### D7.3 — Fixed call order inside the single `process_physics_priority = 0` slot

```gdscript
func _physics_process(delta: float) -> void:
    # 1. Live read — nothing here is stored past this callback (D7.1).
    #    up_direction is CharacterBody2D's own property, consulted by
    #    is_on_floor()/is_on_wall()/move_and_slide(); GravityAuthority cannot
    #    set it on this node, so Player must, every frame, before any floor
    #    or wall query below. (TD-ADR finding 1, 2026-08-15.)
    var gravity: Vector2 = GravityAuthority.gravity
    var up_dir: Vector2 = GravityAuthority.up_dir
    var right_dir: Vector2 = GravityAuthority.right_dir
    up_direction = up_dir

    # 2. Watering lockout — claimed by this ADR; PlayerWateringComponent's full
    #    pour interaction model belongs to ADR-0009 (unwritten). The ordering
    #    fact that gravity/wall-jump/jump/movement/move_and_slide freeze during
    #    a pour is physics-step order, not pour mechanics, and is settled here.
    #    Visuals are NOT skipped: watering-system.md AC9 requires the sprite to
    #    keep rotating with the gravity easing through the lock, so step 8 runs
    #    unconditionally regardless of this branch. (TD-ADR finding 2, corrected
    #    2026-08-15 — the original draft's early `return` broke AC9.)
    var input_axis: float = 0.0
    if watering_component.is_watering:
        velocity = Vector2.ZERO
    else:
        # 3. Gravity (D7.2) — pure function, no component-owned gravity state.
        velocity = gravity_component.apply_gravity(
            delta, velocity, is_on_floor(),
            gravity, GravityAuthority.ascent_magnitude(), GravityAuthority.descent_magnitude()
        )

        # 4. Wall jump (conditional on enable_wall_jump, unchanged from today)
        if wall_jump_component.enable_wall_jump:
            velocity = wall_jump_component.try(
                delta, velocity, is_on_floor(), is_on_wall(),
                up_dir, func(): return get_wall_normal()
            )

        # 5. Jump — coyote, buffer, variable height, landing (TR-gravity-006)
        velocity = jump_component.update(delta, velocity, is_on_floor(), up_dir, right_dir)

        # 6. Lateral movement. NOTE: does not yet apply a carry-speed multiplier —
        #    TR-watering-002 is NOT closed by this ADR; see GDD Requirements
        #    Addressed and Consequences below.
        input_axis = Input.get_axis("move_left", "move_right")
        velocity = movement_component.apply(
            delta, velocity, is_on_floor(), right_dir, up_dir, input_axis, camera_rotation_enabled
        )

        # 7. Collision resolution
        move_and_slide()

    # 8. Visuals — ALWAYS runs, watering or not (see step 2). Reads post-slide
    #    velocity when not watering, and the zeroed velocity while watering;
    #    either way it keeps rotating the sprite toward `gravity` every frame.
    visual_component.update(
        delta, velocity, is_on_floor(), right_dir, up_dir, input_axis, gravity, camera_rotation_enabled
    )
```

This is the order already live in `src/scripts/player.gd` today, with three changes: the gravity-ease/derive-dirs calls are removed (that responsibility now belongs to `GravityAuthority`, per ADR-0001); every gravity-fed call receives its inputs as parameters rather than reading a component field; and `up_direction` is set explicitly every frame, which the current code does today via `gravity_component`-owned state but which this ADR's narrowing would otherwise silently drop.

The watering-lockout row is claimed explicitly rather than left implicit, because it is a fact about *when* steps 3–7 run, not about how pouring works — but step 8 (visuals) is deliberately outside that gate, because `watering-system.md` AC9 depends on it running throughout the lock. ADR-0009 inherits this shape unchanged; it does not redesign it.

### D7.4 — One axis-inversion formula, not two

`GravityAuthority` gains a stateless static method:

```gdscript
# static: no self access — pure function of its parameters, not autoload state.
# Colocated here because right_dir is the only external input and GravityAuthority
# already owns it.
static func apply_camera_relative_axis(input_axis: float, right_dir: Vector2, camera_rotation_enabled: bool) -> float:
    if camera_rotation_enabled:
        return input_axis
    if not is_zero_approx(right_dir.dot(Vector2.RIGHT)):
        return input_axis * sign(right_dir.dot(Vector2.RIGHT))
    return input_axis * -sign(right_dir.y)
```

`PlayerMovementComponent.apply()` and `PlayerVisualComponent.update()` both call `GravityAuthority.apply_camera_relative_axis(...)` instead of carrying their own copy of the branch. This makes `TR-gravity-013` ("visual component mirrors movement's axis inversion exactly") hold by construction — there is exactly one implementation to diverge from, and it cannot.

### Architecture Diagram

```
GravityAuthority  (process_physics_priority = -100)
  ease → gravity, up_dir, right_dir, ascent/descent mags finalized for this frame
         │
         ▼  (same frame, guaranteed prior — frame_ordering_contract)
Player  (process_physics_priority = 0)
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. read GravityAuthority.gravity / up_dir / right_dir     (D7.1)│
  │    up_direction = up_dir                                        │
  │                                                                  │
  │ 2. watering_component.is_watering ?                       (D7.3)│
  │      YES → velocity = Vector2.ZERO, jump to step 8              │
  │      NO  → continue to step 3                                   │
  │                                                                  │
  │ 3. gravity_component.apply_gravity(gravity, ascent, descent)    │
  │                                                             (D7.2)│
  │ 4. wall_jump_component.try()  (conditional)                     │
  │                                                                  │
  │ 5. jump_component.update()                                      │
  │                                                                  │
  │ 6. movement_component.apply()  ── GravityAuthority.             │
  │      apply_camera_relative_axis()                         (D7.4)│
  │                                                                  │
  │ 7. move_and_slide()                                             │
  │                                                                  │
  │ 8. visual_component.update()  ── SAME static fn as step 6 (D7.4)│
  │      runs UNCONDITIONALLY — watering or not, per AC9            │
  └─────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# PlayerGravityComponent — narrowed to near-stateless (D7.2)
func initialize(max_speed: float) -> void
    # computes baseline_ascent_mag, ascent_descent_ratio, jump_velocity locally;
    # seeds GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio);
    # keeps only jump_velocity as a field.

var jump_velocity: float   # read-only after initialize(); never recomputed

func apply_gravity(
    delta: float, velocity: Vector2, is_on_floor: bool,
    gravity: Vector2, ascent_mag: float, descent_mag: float
) -> Vector2
    # pure function — no field reads except jump_height/jump_distance_to_peak/
    # jump_distance_to_land, which are only used inside initialize().


# GravityAuthority — additive to the ADR-0001 contract (D7.4)
static func apply_camera_relative_axis(
    input_axis: float, right_dir: Vector2, camera_rotation_enabled: bool
) -> float


# Player facade — the sole caller that reads GravityAuthority per frame (D7.1)
func _physics_process(delta: float) -> void
    # exact body per D7.3
```

## Alternatives Considered

### Alternative 1: Per-component signal subscription with local caching

- **Description**: Each component (`PlayerGravityComponent`, `PlayerMovementComponent`, etc.) connects individually to `GravityAuthority.gravity_changed` and stores the received `direction`/`multiplier` in its own fields, updated whenever the signal fires.
- **Pros**: No parameter threading through `Player._physics_process`; each component is self-contained.
- **Cons**: This is exactly what the registry's `private_gravity_copy` forbidden pattern names and bans — "any node caching its own gravity/target_gravity instead of reading GravityAuthority... a cached copy can silently diverge." Five independent copies (one per component) is five chances for one to miss an update or read stale state on the frame a change occurs.
- **Rejection Reason**: Directly violates an already-Accepted forbidden pattern (ADR-0001). Also multiplies the exact defect ADR-0001 was written to eliminate — gravity was *player* state by construction before ADR-0001; this alternative would make it five different kinds of player-adjacent state instead of one.

### Alternative 2: Thin per-frame cache object

- **Description**: A small `GravityFrame` value object is constructed once at the top of `Player._physics_process` (`GravityFrame.new(GravityAuthority.gravity, ...)`) and passed around instead of individual parameters, discarded at the end of the frame.
- **Pros**: Functionally identical to D7.1; slightly shorter call signatures.
- **Cons**: Adds an allocation every physics frame (60 Hz) for no behavioral benefit over passing three or four primitive parameters directly. Introduces a class whose only job is to not be `GravityAuthority` and not be a component field — a distinction with no operational difference from direct parameter passing.
- **Rejection Reason**: Adds a moving part and a per-frame allocation with nothing to show for it. Direct parameter passing achieves the identical guarantee (nothing survives past the callback) with less code and less to review.

### Alternative 3: Leave the axis-inversion formula duplicated

- **Description**: Accept the existing duplication between `PlayerMovementComponent` and `PlayerVisualComponent` as a known risk, documented but not fixed.
- **Pros**: Zero-diff on this specific concern; smaller ADR.
- **Cons**: `TR-gravity-013` explicitly requires the two to match "exactly." Two independently-maintained copies of a five-line branch is precisely the shape of defect this project's other ADRs have consistently rejected (ADR-0005's rejection of a second airlock-detection implementation for the same reason — "two geometry implementations that must agree is a worse long-term liability").
- **Rejection Reason**: The fix costs one static function and two call-site edits. The user confirmed centralizing it during this ADR's design questions (session 17).

## Consequences

### Positive

- `TR-gravity-004/005/006/007/013` and `TR-watering-014` move from `gap` to `covered` — this ADR is the sole owner of all six. `TR-watering-002` does **not** close here (see Negative, below, and the GDD Requirements Addressed table) — it stays `gap`, owned by ADR-0009.
- `private_gravity_copy` stops being violated by `PlayerGravityComponent`'s current implementation; the fix is structural (no field exists to go stale), not a promise to keep two things in sync.
- `TR-gravity-013` holds by construction: one axis-inversion function, two callers, cannot diverge.
- `Player._physics_process` becomes a single, linearly-readable sequence — the "called inline" phrase from ADR-0005 is no longer ambiguous.
- No new autoload, no new signal, no new node. This ADR is entirely a refactor of existing component boundaries plus one new static function.

### Negative

- `PlayerGravityComponent`'s public surface shrinks from six meaningful members to three (`initialize`, `jump_velocity`, `apply_gravity`). A future reader expecting to find gravity state on the component that is named for gravity will need to know to look at `GravityAuthority` instead — this is the intended consequence of ADR-0001, restated here because this ADR is where the component's shape actually changes in code.
- `Player._physics_process` now carries three local variables (`gravity`, `up_dir`, `right_dir`) read at the top of every frame purely to thread through six subsequent calls. This is more verbose than a component reading its own field, and is an intentional trade of brevity for the freshness guarantee.
- `GravityAuthority`'s script gains one `static` method alongside otherwise-all-instance methods (`initialize`, `set_gravity`, `register_prop`, etc. — all instance methods per ADR-0001's Key Interfaces). Confirmed idiomatic and legal by engine specialist review (2026-08-15), but it is the one asymmetric member in that file and needs the inline comment shown in D7.4 so a future reader does not wonder why it's callable before `initialize()` has run.

### Risks

- **A future component reintroduces a gravity field "for convenience."** Presents as working correctly until a gravity change lands mid-frame in a way the cached copy misses — likely to read as a rare, hard-to-reproduce bug rather than an architectural violation. *Mitigation*: register `private_gravity_copy`'s existing forbidden-pattern entry as covering this ADR's components explicitly (it already names "any node"), and note in code review that `PlayerGravityComponent` having no `gravity` field is deliberate, not an oversight to "fix."
- **`GravityAuthority.apply_camera_relative_axis()` is mistaken for instance state and called before `initialize()`.** Low actual risk — GDScript static methods are callable through an instance reference and do not touch `self`, so nothing breaks, but a reader unfamiliar with the file might assume otherwise. *Mitigation*: the `# static: no self access` comment at the definition site (confirmed by engine specialist review as the correct fix for this — cosmetic, not a defect).
- **A future author adds a sixth component to `Player` and appends it to `_physics_process` without checking where in D7.3's order it belongs.** *Mitigation*: the ordered code block in D7.3 is the single source of truth for call order, the same pattern `FramePriority` established for cross-node ordering (ADR-0005) — a future addition should read as "insert into this list," not "append at the end."
- **A future author "simplifies" the watering branch back to an early `return`, collapsing step 8 into the gate.** Presents as working correctly in every manual test that doesn't hold a gravity flip during a pour — an easy state to not notice, since most pours happen in a stable room. It silently breaks `watering-system.md` AC9. *Mitigation*: the comment at D7.3 step 2 names AC9 explicitly, and Validation Criterion 8 exercises exactly this combination (gravity change concurrent with a pour lock).
- **`TR-watering-002` is read as closed because it appears in this ADR's title-adjacent requirement list** (`architecture.md`'s ADR table assigns it here) even though the Decision does not implement it. *Mitigation*: stated plainly in three places (D7.3 step 6 comment, GDD Requirements Addressed, Consequences → Positive) rather than once, specifically because a reader skimming any single section could otherwise miss the carve-out. `docs/architecture/tr-registry.yaml`'s `TR-watering-002` entry should be reassigned from `ADR-0007` to `ADR-0009` — flagged here as a follow-up requiring its own approval, not performed by this ADR.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `gravity.md` | R4 (`TR-gravity-004`) — asymmetric ascent/descent applied to the player | `apply_gravity()` keeps the unchanged asymmetric math, now fed `ascent_mag`/`descent_mag` as parameters from `GravityAuthority` (D7.2) |
| `gravity.md` | R5 (`TR-gravity-005`) — `jump_velocity` derived once, never recomputed | `jump_velocity` is the one field `PlayerGravityComponent` retains, set once in `initialize()`, with no remaining code path that could touch it afterward (D7.2) |
| `gravity.md` | R6 (`TR-gravity-006`) — variable jump height; release caps at `min_jump_velocity` | Unchanged; `PlayerJumpComponent.update()` keeps its existing implementation, now called at a fixed, documented point in D7.3's order |
| `gravity.md` | R10 (`TR-gravity-007`) — carried mass affects speed only, never gravity or jump | `apply_gravity()`'s parameter-only signature has no field a carry penalty could reach; `movement_component.apply()` is the sole consumer of `max_speed`, unaffected by this ADR |
| `gravity.md` | §6, AC8, AC10 (`TR-gravity-013`) — visual component mirrors movement's axis inversion at any angle | One static function (D7.4) replaces two independent copies; "exactly" holds by construction |
| `watering-system.md` | R2 (`TR-watering-002`) — carry scales `max_speed` only | **NOT closed by this ADR.** `movement_component.apply()`'s signature is unchanged and applies no carry multiplier; the registry currently assigns this requirement to ADR-0007, but implementing it needs a `carrying_bucket` source this ADR does not define (that state belongs to `PlayerWateringComponent`/`LevelState`, ADR-0002/ADR-0009's territory). Stays `gap`, owned by ADR-0009. (TD-ADR finding 3, 2026-08-15 — see Consequences) |
| `watering-system.md` | AC1 (`TR-watering-014`) — carrying leaves jump apex unchanged at every zone multiplier | Follows directly from `TR-gravity-005`/`TR-gravity-007` above: `apply_gravity()` and `jump_component.update()` have no path by which a carry-scaled `max_speed` could reach `jump_velocity` or the gravity magnitudes. This is a negative guarantee (carry *cannot* reach jump) and holds regardless of where the multiplier itself is applied, so it closes independently of `TR-watering-002` |
| `watering-system.md` | §5 edge case, AC9 — sprite rotates with the gravity easing through a pour lock and unlocks into the new orientation | `visual_component.update()` runs unconditionally every physics frame (D7.3 step 8), including while `watering_component.is_watering` is true — the watering-lockout gate covers only steps 3–7 |

## Performance Implications

- **CPU**: Effectively zero net change. The gravity-ease/derive-dirs work that moves out of `Player`'s callback was already running every frame under the old code; it now runs once in `GravityAuthority` instead of being duplicated in intent. Three local variable reads (`gravity`, `up_dir`, `right_dir`) and two method calls (`ascent_magnitude()`, `descent_magnitude()`) per physics frame are negligible against a 16.6 ms budget.
- **Memory**: Net reduction — `PlayerGravityComponent` sheds five fields (`gravity`, `target_gravity`, `up_dir`, `right_dir`, `gravity_ascent_mag`, `gravity_descent_mag` minus the one it keeps).
- **Load Time**: None.
- **Network**: N/A — single-player.

## Migration Plan

1. `PlayerGravityComponent` — delete `gravity`, `target_gravity`, `up_dir`, `right_dir`, `gravity_ascent_mag`, `gravity_descent_mag` fields, `set_gravity()`, `update_derived_dirs()`, `update_gravity_lerp()`. Rewrite `initialize()` to seed `GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio)` (requires `GravityAuthority` to exist — blocked on ADR-0001's own migration landing first, specifically `GravityAuthority.lifecycle`). Rewrite `apply_gravity()` to the pure-function signature in Key Interfaces.
2. `GravityAuthority` — add `static func apply_camera_relative_axis(...)` per D7.4, with the `# static: no self access` comment.
3. `PlayerMovementComponent.apply()` — replace the inline axis-inversion branch (current `player_movement_component.gd:27-31`) with a call to `GravityAuthority.apply_camera_relative_axis(input_axis, right_dir, camera_rotation_enabled)`.
4. `PlayerVisualComponent.update()` — replace the inline axis-inversion branch (current `player_visual_component.gd:46-50`) with the same call.
5. `Player._physics_process()` (`player.gd:128-175`) — rewrite to D7.3's exact body: remove the `update_derived_dirs()`/`update_gravity_lerp()` calls; **replace**, not delete, the `up_direction` assignments — `up_direction = up_dir` moves to step 1, reading the live `GravityAuthority.up_dir` instead of `gravity_component.gravity.normalized()` (TD-ADR finding 1); add the three-variable live read; thread `gravity`/`ascent_mag`/`descent_mag` into `apply_gravity()`; restructure the watering branch so step 8 runs unconditionally (D7.3, TD-ADR finding 2).
6. `Player.set_gravity()` (`player.gd:183-187`) — this facade method is removed entirely per ADR-0001's `zone_targets_player_directly` forbidden pattern; not reintroduced by this ADR.
7. `Player`'s proxy properties (`player.gd:71-78`: `target_gravity`, `right_dir`, `up_dir`) — repoint their getters from `gravity_component.*` to `GravityAuthority.*`. This is required, not optional: `src/scripts/debugger.gd` reads `player.target_gravity`, `player.right_dir`, and `player.up_dir` (lines 13, 17-18) and would break silently — reading stale or default values with no error — if these proxies were left pointing at the now-empty `gravity_component` fields instead of being repointed. **`right_dir` and `up_dir` repoint to `GravityAuthority.right_dir`/`.up_dir`, both confirmed public by the registry's `world_gravity_vector` interface ("Read via GravityAuthority.gravity / up_dir / right_dir"). `target_gravity` repoints to `GravityAuthority.gravity` instead of `.target_gravity`** — the registry's interface line names `gravity`/`up_dir`/`right_dir` as the public read surface and conspicuously omits `target_gravity`, which `GravityAuthority` does not yet exist in `src/` to confirm one way or the other. Reading the live `gravity` value rather than the eased destination is a strictly more accurate debug readout in any case, and the proxy's external name (`Player.target_gravity`) is unchanged, so `debugger.gd` needs no edits either way. (TD-ADR finding 5, 2026-08-15; public-surface note added on re-review, 2026-08-15.)

Step 1 cannot land before `GravityAuthority` exists in `src/` (ADR-0001's own migration). This ADR's migration lands with or after ADR-0001's, never before — same ordering constraint ADR-0005 stated for its own migration relative to ADR-0002.

## Validation Criteria

This decision is correct if the following hold:

1. **`TR-gravity-004`/`AC1`** — at 1.0× gravity, peak height is 200 px ±2 px, and descent is faster than ascent by the configured ratio ±5%, driven entirely by `apply_gravity()`'s parameters.
2. **`TR-gravity-005`** — a static/grep-level check that `jump_velocity` is assigned exactly once in `PlayerGravityComponent` (inside `initialize()`) and nowhere else in the file.
3. **`TR-gravity-007`/`TR-watering-014`/`AC11`(gravity)/`AC1`(watering) — one shared test** — carrying a bucket at any zone multiplier leaves jump apex height identical to the non-carrying case. This is the reciprocal test both GDDs already call for; it should be written once.
4. **`TR-gravity-013`/`AC8`/`AC10`** — under horizontal gravity, sprite facing matches travel direction, verified by asserting `PlayerMovementComponent` and `PlayerVisualComponent` both call `GravityAuthority.apply_camera_relative_axis` (grep-level) rather than by comparing two independent implementations' output.
5. **Ordering** — a grep-level check that `Player._physics_process` contains the eight steps of D7.3 in the literal order shown, matching the pattern ADR-0005's validation criteria already established for `FramePriority`.
6. **No private copy** — a grep-level check that `PlayerGravityComponent` declares no field named `gravity` or `target_gravity`.
7. **`up_direction` ownership** — a grep-level check that `Player._physics_process` assigns `up_direction` from `GravityAuthority.up_dir` (or the local `up_dir` copy of it) before any call to `is_on_floor()`, `is_on_wall()`, or `move_and_slide()` in the same callback.
8. **`watering-system.md` AC9** — drive a gravity change while `watering_component.is_watering` is true; assert `visual_component.update()` still runs (sprite rotation continues toward the new `gravity` target) every physics frame of the lock, not just before or after it.

The decision is **wrong**, and should be revisited, if a future gravity-dependent mechanic needs sub-frame gravity precision the live-read-once-per-frame model cannot provide (no such mechanic exists today), or if `GravityAuthority.ascent_magnitude()`/`descent_magnitude()` prove to need per-consumer variation (e.g. a future mechanic where the player and a prop experience different asymmetry) — which would contradict `gravity.md` R9's single-vector premise and require revisiting ADR-0001, not this ADR.

## Related Decisions

- **ADR-0001** — established `GravityAuthority` and narrowed `PlayerGravityComponent`; this ADR resolves an internal inconsistency in ADR-0001's own text (D7.2's override note) and supplies the `apply_camera_relative_axis` addition to `GravityAuthority`'s contract.
- **ADR-0005** — fixed the `-100`/`0`/`+100` frame ordering and left "components called inline" undefined at the `0` slot; this ADR is that definition.
- **ADR-0008** (unwritten) — oxygen drain and death path. Does not depend on this ADR's internals, but benefits from `Player`'s physics-step shape being settled before authoring `OxygenDrain`'s relationship to it.
- **ADR-0009** (unwritten) — watering interaction model. Inherits D7.3's watering-lockout row and D5.5's `_physics_process` clock migration (ADR-0005) without re-deriving either, and owns closing `TR-watering-002` (see Risks — this ADR flags but does not perform the `tr-registry.yaml` reassignment). **One forward note from re-review (2026-08-15)**: because step 8 now runs unconditionally, `visual_component.update()` reaches its animation block (`Idle`/`Jump`/`Run`/`Falling`) every frame of a pour, not just before or after one. Any pour-specific animation ADR-0009 wants must be driven from inside `update()`'s existing state machine, not from the currently-empty `_on_watering_started()`/`_on_watering_stopped()` signal handlers — those fire once at the transition edges, not per-frame during the lock.
- `design/gdd/gravity.md` R4, R5, R6, R7, R10, §6, AC8, AC10, AC11.
- `design/gdd/watering-system.md` R2, AC1, AC9, AC14.
- `docs/architecture/tr-registry.yaml` — `TR-gravity-004/005/006/007/013`, `TR-watering-014` (closed); `TR-watering-002` (not closed, flagged for reassignment to ADR-0009).
