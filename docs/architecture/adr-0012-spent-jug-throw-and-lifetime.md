# ADR-0012: Spent Jug Throw and Lifetime

## Status

Accepted

## Date

2026-08-16 (Proposed) · 2026-08-16 (Accepted)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Animation (tween-driven cosmetic motion) · Core (node lifetime, pause resolution) |
| **Knowledge Risk** | **HIGH** — 4.7.1 is beyond the LLM training data (~4.3), and the reference library holds **no `modules/animation.md`**. Every tween claim below rests on the godot-specialist validation pass, not on a pinned local source. This is a weaker evidence base than ADR-0008 or ADR-0009 had. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` · `modules/core.md` § Pause and process modes (`:53-71`), § The physics frame (`:73-100`), § Node lifecycle (`:102-126`) · `breaking-changes.md` (no tween or animation entry) · `deprecated-apis.md` (no tween or animation entry) |
| **Post-Cutoff APIs Used** | **None.** `Node.create_tween()`, `Tween.tween_method()`, `Node2D.top_level`, `randf_range()`, and `deg_to_rad()` all pre-date 4.4 and carry no deprecation marker. The removed pre-4.0 `Tween` *node* is not used. Confirmed by godot-specialist, 2026-08-16. |
| **Engine Validation** | godot-specialist gate pass, 2026-08-16. **CONFIRMED against official docs**: `Tween.set_pause_mode()` defaults to `TWEEN_PAUSE_BOUND`, so a bound tween follows its node's `process_mode` (D12.5); `Tween.finished` takes zero parameters, matching `queue_free()` (D12.1); `Area2D.monitoring` and `monitorable` have the directions this ADR states (D12.4); `tween_method()` accepts a `Callable` (D12.6); a bound tween is auto-killed when its node is freed. **One blocking finding, fixed before this revision** — see D12.4. |
| **Verification Required** | (1) **`top_level` global-transform behaviour is confirmed by mechanism, not by a verbatim doc sentence.** The `CanvasItem.top_level` doc states the node stops inheriting the parent transform; that `global_position` therefore shifts unless re-assigned is a necessary implication of that, not a documented line. Confirm in a playtest that the jug does not visually jump at the throw. (2) `queue_free()` is documented to delete "at the end of the current frame"; confirm the observed free time fits AC10's `throw_duration + 0.1 s` budget on the pinned 4.7.1 binary. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0006** (Accepted) — supplies `throw_arc_height`, `throw_duration`, and `throw_angle_spread` through `Tuning.WATERING`. **ADR-0009** (Accepted) — supplies the `Bucket.consume()` hand-off, the `Area2D` root type, and the `_complete_pour()` call site. |
| **Enables** | None. |
| **Blocks** | None. |
| **Ordering Note** | This ADR has **no ordering relationship with ADR-0010 or ADR-0011**. `watering-system.md` §6 excludes buckets and spent jugs from prop physics, so the props ADR and this one do not touch. The HUD ADR reads `carrying_bucket`, which ADR-0002 already supplies. |

## Context

### Problem Statement

ADR-0009 stops at `Bucket.consume()`. That method's only guarantee is that "the bucket stops being pickable" (`adr-0009:210-213`); its own comment hands the rest here. `watering-system.md` R7 asks for more: the spent jug detaches from the hand, plays a scripted arc away from the player in the current gravity basis, and is freed when the arc ends.

Three things are unowned. Nobody animates the arc. Nobody supplies the gravity basis. Nobody calls `queue_free()`. Until they have an owner, `TR-watering-007` stays a gap and AC10 — "the spent jug is freed within `throw_duration + 0.1 s` of pour completion; no jug persists into the next pour" — has nothing to test.

### Constraints

- `Bucket` is an `Area2D` with a `CollisionShape2D` child (ADR-0009 D§4, `TR-watering-016`). `on_picked_up()` clears `monitoring` only.
- `func consume() -> void` is a **frozen** Key Interface of the Accepted ADR-0009.
- `func update_pour(delta: float, interact_held: bool) -> void` is likewise frozen, and ADR-0007's step order (`adr-0007:96-106`) passes the watering component **no gravity parameters at all**.
- No watering code may subscribe to `GravityAuthority.gravity_changed` (`adr-0009:222-224`).
- Tuning is reached only through `Tuning.WATERING`. The resource is immutable at runtime (ADR-0006 D6.3, D6.5).
- The jug has no physics body and no collision (`watering-system.md` R7, §6).
- The testing standards forbid non-determinism. The GDD pre-resolves this by scoping the randomness to direction only, "which touches no testable state."

### Requirements

- **R7** — detach, arc away from the player in the current gravity basis, free at the end of the arc.
- **AC10** (Logic) — freed within `throw_duration + 0.1 s`; no jug persists into the next pour.
- **§5 edge case** — a jug in flight during a gravity flip completes its arc in the basis captured at throw time. The cosmetic mismatch is accepted.
- **§7** — `throw_arc_height` 120 px (60–200), `throw_duration` 0.6 s (0.4–0.8), `throw_angle_spread` ±45° (0–90).

## Decision

### D12.1 — The jug animates itself and frees itself

`Bucket` gains one method, `throw_spent()`. It creates its own tween, plays the arc, and calls `queue_free()` when the tween finishes. `consume()` is untouched.

The jug is the node that must die, and ADR-0009 already hands off at the jug. Putting the arc anywhere else means a second object holding a reference to a node whose whole purpose is to stop existing.

### D12.2 — The basis is injected, and captured once

`throw_spent(up_dir: Vector2, right_dir: Vector2)`. `PlayerWateringComponent._complete_pour()` reads both fields from `GravityAuthority` into locals and passes them straight through.

Both values are captured into local variables **at the call, before any deferral**. This is what makes `watering-system.md` §5 hold structurally: a gravity flip during the flight cannot re-aim an arc whose basis was already copied out. It is also why no `gravity_changed` subscription is needed, which keeps ADR-0009's bar (`adr-0009:222-224`) intact by construction rather than by discipline.

**`right_dir` is passed, not derived.** Deriving a perpendicular from `up_dir` inside the jug would recompute a value `GravityAuthority` already owns — the exact shape ADR-0007 D7.2 rejected when it removed `PlayerGravityComponent`'s own basis derivation.

**Recorded deviation.** `_complete_pour()` reads the autoload directly instead of receiving the basis as a parameter. ADR-0007 D7.1's style is to read once at the top of `Player._physics_process` and thread the values down. That style is not available here without adding a third parameter to ADR-0009's frozen `update_pour()` signature. D7.1's *binding* rule is narrower than its style — "no component stores a gravity-derived value in a field that survives past the current callback" (`adr-0007:65`) — and a local that is read, passed, and discarded satisfies it. The registry's `private_gravity_copy` ban is likewise on **caching**, not on reading. The deviation is from a pattern, not from a guarantee, and it is recorded here rather than left for a reader to notice.

### D12.3 — The jug detaches with `top_level`, not by reparenting

`throw_spent()` sets `top_level = true` and then re-assigns `global_position` to the captured origin.

R7 requires the jug to detach from the hand. `top_level` makes a `Node2D` ignore its parent's transform without mutating the scene tree, so the arc is correct **whatever carry representation ADR-0009's implementation ends up choosing** (see Risks — that representation is not specified anywhere). Reparenting would work too, but it mutates the tree inside a physics callback and needs a deferral plus knowledge of a level-root node the jug does not have.

### D12.4 — `monitorable` is cleared, synchronously

`on_picked_up()` cleared `monitoring`, which stops this area from detecting others. It does **not** stop others from detecting this one — the two properties point in opposite directions, which the engine docs state plainly. A flying jug on the bucket's collision layer would still register against any area that masks it, which contradicts R7's "no collision." So `monitorable = false` is set here.

**It is set synchronously, and this is deliberate.** ADR-0009's `on_picked_up()` must use `set_deferred()` because it is called straight from `Bucket._on_body_entered`, which fires **during** `PhysicsServer2D::flush_queries()` — inside the window where mutating an `Area2D` monitor flag raises a runtime error (ADR-0009 Finding 1). `throw_spent()` is not in that window. Its only call path is `_complete_pour()` → `update_pour()` → `Player._physics_process` step 2 (`adr-0009:237`), and `core.md:75-83` puts `SceneTree::physics_process()` strictly **after** `flush_queries()` has returned:

```
PhysicsServer2D::flush_queries()   ← body_entered fires here — locked
SceneTree::physics_process()       ← update_pour() runs here — not locked
```

> **Recorded correction.** This ADR's first draft deferred the write "for the same reason `on_picked_up()` defers." That was reasoning by analogy to ADR-0009 instead of tracing the actual call path, and it was wrong. The godot-specialist gate pass caught it (2026-08-16). The analogy is recorded here so a future reader does not re-derive it and re-introduce the deferral.

Setting it synchronously buys two things beyond correctness. It closes the one-frame window in which a jug already in flight is still detectable. And it keeps V1 and V2 genuine **Logic** tests: a deferred write needs a live `SceneTree` iteration to flush, so a headless unit test that never processes a frame would silently never apply it, and the criterion would be untestable in isolation.

### D12.5 — The arc freezes with the game

The tween is created by `Bucket.create_tween()`, so it is bound to the jug and inherits the jug's pause resolution. The jug is left at the default `PROCESS_MODE_INHERIT`, which resolves to `PAUSABLE` (`core.md:60-65`). The arc therefore suspends when `SceneTree.paused` becomes true and resumes on unpause, with **no pause-check code and no explicit exemption**.

This is the same structural approach ADR-0008 took for the oxygen drain, and it matches `hud.md`'s Paused-state rule, where nothing hides and E3 suspends rather than draining. **ADR-0010 inherits no obligation from this ADR** — the jug needs no `PROCESS_MODE_WHEN_PAUSED` exemption.

**The arc advances on idle frames, not physics ticks.** `Tween.set_process_mode()` defaults to `TWEEN_PROCESS_IDLE`, so although the tween is created from inside `_physics_process`, it steps on the render frame. This is harmless — the jug has no collider and no physics interaction, so nothing depends on it landing on a physics boundary. It is stated because it decides how V5 must be written: that test has to advance **idle** frames to observe the arc, and advancing only physics frames would show no motion whether the game is paused or not, passing for the wrong reason.

### D12.6 — The curve is scripted, and derives its reach from existing knobs

In the gravity basis, over normalised time `t` from 0 to 1:

```
u(t) = 4 · h · t · (1 − t)          along up_dir     — apex h at t = 0.5, back to 0 at t = 1
r(t) = 4 · h · sin(θ) · t           along right_dir  — linear drift away from the player
```

where `h` is `throw_arc_height` and `θ` is drawn once from `±throw_angle_spread`.

**`watering-system.md` §7 specifies no throw distance and no launch speed.** A scripted arc needs one, so the lateral reach is *derived* from `h` and `θ` rather than adding a fourth knob — adding one would mean editing the GDD's §7 table, the `.tres`, and ADR-0006's frozen `WateringTuning` definition. The gap is recorded in Consequences → Negative.

`sin(θ)` is used rather than `tan(θ)` deliberately. `tan` has a singularity at 90°, which is the **top of the GDD's own safe range** for `throw_angle_spread`, so a designer could set a legal value that produces infinite lateral reach. `sin` is bounded across the whole 0–90 range. The curve is not a ballistic simulation and does not claim to be — R7 says "scripted arc," and the jug has no body.

### Key Interfaces

```gdscript
# Bucket — ONE added method. consume() is unchanged and stays frozen.
class_name Bucket
extends Area2D                                    # ADR-0009, TR-watering-016

func throw_spent(up_dir: Vector2, right_dir: Vector2) -> void
```

```gdscript
func throw_spent(up_dir: Vector2, right_dir: Vector2) -> void:
    ## Plays R7's cosmetic arc, then frees this node. Call once, after consume().
    ## up_dir/right_dir are CAPTURED HERE. watering-system.md §5 requires the arc
    ## to finish in the basis held at throw time, so a mid-flight gravity flip
    ## must NOT re-aim it. Capturing is what makes that structural (D12.2).
    var origin := global_position

    # on_picked_up() cleared `monitoring` — that stops THIS area detecting others,
    # NOT others detecting it. Set synchronously, unlike on_picked_up()'s deferred
    # write: that one is called from _on_body_entered, inside flush_queries();
    # this one is called from _physics_process, which core.md:75-83 places strictly
    # after flush_queries() has returned. Not the same window (D12.4).
    monitorable = false

    # Detach from the hand without mutating the tree (D12.3). top_level does not
    # preserve the global transform on its own, so re-assign it.
    top_level = true
    global_position = origin

    var h: float = Tuning.WATERING.throw_arc_height
    var spread := deg_to_rad(Tuning.WATERING.throw_angle_spread)
    var theta := randf_range(-spread, spread)     # cosmetic only — see D12.7
    var reach := 4.0 * h * sin(theta)

    var tween := create_tween()                   # bound to self: dies with this
                                                  # node, and pauses with it (D12.5)
    # NOTE: a GDScript lambda captures outer locals BY VALUE at creation time.
    # origin/up_dir/right_dir/h/reach are all frozen here and never reassigned,
    # which is exactly what D12.2's "captured once" guarantee needs. Do not edit
    # this lambda to read a live value — the capture would not see the update.
    tween.tween_method(
        func(t: float) -> void:
            global_position = origin \
                + up_dir * (4.0 * h * t * (1.0 - t)) \
                + right_dir * (reach * t),
        0.0, 1.0, Tuning.WATERING.throw_duration
    )
    tween.finished.connect(queue_free)
```

```gdscript
# PlayerWateringComponent._complete_pour() — ONE line added to ADR-0009's version.
func _complete_pour() -> void:
    _target_plant.receive_pour()
    _held_bucket.consume()
    _held_bucket.throw_spent(GravityAuthority.up_dir, GravityAuthority.right_dir)  # ← this ADR
    _held_bucket = null
    carrying_bucket = false
    level_state.carrying_bucket = false
    is_watering = false
    _target_plant = null
    water_progress = 0.0
```

### D12.7 — Randomness is confined to the angle, and no test reads it

`θ` is the only random quantity. It sets direction only. AC10's automated test asserts the free **time** and the node count, never a position — so the test stays deterministic and the testing standards' "no random seeds" rule holds without seeding anything.

### Architecture Diagram

```
Player._physics_process(delta)                                    [ADR-0007]
  step 2: watering_component.update_pour(delta, interact_held)    [ADR-0009]
            └─ water_progress >= water_duration
                 └─ _complete_pour()                              [ADR-0009]
                      ├─ _target_plant.receive_pour()             [ADR-0009]
                      │    └─ pour_completed → level_state.consume_bucket()  [ADR-0002]
                      ├─ _held_bucket.consume()                   [ADR-0009]
                      │    └─ (already un-pickable)
                      └─ _held_bucket.throw_spent(up_dir, right_dir)   ← THIS ADR
                           ├─ capture origin + basis          (D12.2)
                           ├─ monitorable = false, synchronous (D12.4)
                           ├─ top_level = true                (D12.3)
                           └─ create_tween() ── throw_duration ──▶ queue_free()
                                └─ advances on IDLE frames     (D12.5)
                                └─ pauses with SceneTree.paused (D12.5)

   Note the two windows are different. Bucket._on_body_entered → on_picked_up()
   runs inside flush_queries() and MUST defer its write. The chain above runs in
   SceneTree::physics_process(), strictly after. See D12.4.
```

## Alternatives Considered

### Alternative 1: Spawn a separate `SpentJug` scene

- **Description**: `Bucket` frees itself the moment the pour completes, and instances a cosmetic-only `SpentJug` scene that carries the arc.
- **Pros**: The closest literal match to R7's "no physics body and no collision" — the jug would carry no `CollisionShape2D` at all, so D12.4's `monitorable` clean-up would be unnecessary.
- **Cons**: A second scene file, a second script, and a spawn path for a purely cosmetic object that lives at most 0.8 s. It also needs a parent to spawn under, which reintroduces exactly the level-root knowledge D12.3 avoids.
- **Rejection Reason**: The cost is a permanent addition to the scene inventory; the benefit is one deferred property write. D12.4 closes the same gap in one line.

### Alternative 2: `PlayerWateringComponent` owns the tween

- **Description**: The player component creates the tween, animates the jug, and frees it.
- **Pros**: The basis is already in hand at that call site, so no injection is needed.
- **Cons**: Contradicts the registry's stance that the component's interaction fields are "written ONLY inside `update_pour()`", and couples the player to a cosmetic effect it does not own. The component would also have to keep a reference to a node it has just released.
- **Rejection Reason**: It makes the player responsible for the lifetime of an object that is, by design, finished with the player.

### Alternative 3: `Bucket` reads `GravityAuthority` itself

- **Description**: `throw_spent()` takes no parameters and reads `GravityAuthority.up_dir` and `.right_dir` directly.
- **Pros**: No change at all to ADR-0009's `_complete_pour()`.
- **Cons**: Works against the coding standard "dependency injection over singletons", and makes AC10's Logic test need a live autoload to run.
- **Rejection Reason**: AC10 is a **Logic** criterion. It must be unit-testable in isolation, and injection is what makes that possible.

### Alternative 4: Change `consume()` to `consume(up_dir, right_dir)`

- **Description**: Fold the throw into the existing hand-off, one method instead of two.
- **Pros**: The simplest call site.
- **Cons**: Reopens the frozen Key Interface of an Accepted ADR.
- **Rejection Reason**: Same standing choice this project made three times during ADR-0008/0009 — a non-reopening fix over reopening a frozen signature.

## Consequences

### Positive

- `TR-watering-007` closes. It is the last `watering-system.md` requirement assigned to an unwritten ADR.
- The §5 gravity-flip edge case holds **by construction**, not by discipline: the basis is copied out before any deferral, so nothing can re-aim a jug in flight.
- No new tuning knob, no new scene, no new autoload, no new signal. One method and one call-site line.
- ADR-0010 inherits nothing from this ADR. The jug needs no pause exemption (D12.5).
- The Feature tier closes. ADR-0008, ADR-0009, and ADR-0012 are then all written.

### Negative

- **`watering-system.md` §7 has no throw distance or launch-speed knob**, so lateral reach is derived (D12.6) rather than authored. A designer who wants a longer throw must change `throw_arc_height`, which also raises the apex. The two cannot be tuned apart. Recorded as a GDD gap, **not** fixed here — closing it means editing the §7 table, the `.tres`, and ADR-0006's frozen `WateringTuning` definition.
- **`_complete_pour()` reads the autoload directly**, a documented deviation from ADR-0007 D7.1's threading style (D12.2). It breaks no guarantee, but it is one more place where the basis is fetched rather than passed.
- **`TR-watering-002` stays a gap and stays unowned.** This ADR does **not** close it. The carry penalty scales `max_speed` *while carrying*; the throw fires at `consume()`, which ends the carry. The two states are disjoint, so no throw behaviour depends on the penalty and no penalty behaviour depends on the throw. Closing `TR-watering-002` still needs a carry-state parameter on `PlayerMovementComponent.apply()`, which would reopen ADR-0007's frozen D7.3 signature. Recorded so a future reader does not have to re-derive that the two are unrelated.

### Risks

- **The carried jug's parent and visibility are specified by no Accepted ADR.** ADR-0009 mentions a hand marker only parenthetically (`adr-0009:205-206`) and calls the jug "now-hidden" only inside a test description (`adr-0009:355`). Neither is a decision. *Mitigation*: D12.3 makes the throw independent of that choice — `top_level` detaches from any parent, and the arc starts from the jug's actual global position whatever it is. The gap is real but it no longer blocks this ADR. It should be closed by the migration epic, or by the first ADR that needs the carry representation for another reason.
- **The tween evidence base is weaker than ADR-0008's or ADR-0009's.** There is no `modules/animation.md` to cite, so the four Verification Required items rest on the specialist pass alone. *Mitigation*: all four are listed explicitly rather than assumed, and none of them is load-bearing for anything outside this ADR.
- **`throw_duration` must stay below the time to reach the next bucket**, or spent jugs visibly overlap. `watering-system.md` §7 states this as an authoring note. *Mitigation*: it holds by a wide margin today — `throw_duration` caps at 0.8 s and `water_duration` alone is at least 2.0 s, so at most one jug is ever in flight. This is an authoring constraint, not a code guard, and no code enforces it.
- **A level restart during a flight** frees the jug with the scene, and the tween dies with it. The `Tween` docs state this directly — a bound tween "will be automatically killed when the bound object is freed" (confirmed by the godot-specialist pass, 2026-08-16). No leak, no dangling callback. Stated because it is the case a reader will ask about, not because it needs code.
- **`top_level = true` also changes draw order.** The `CanvasItem.top_level` doc notes such a node draws on top of `CanvasItem`s that do not set the flag, so the jug will render in front of the rest of the scene for the length of its flight. This is a side effect of D12.3's detach mechanism, not an intended visual. *Mitigation*: none needed for a 0.6 s cosmetic that is meant to be seen, but it is recorded so a technical-artist is not surprised by a jug popping to the front layer, and so the art pass knows the jug's layering is not authorable from the scene tree.
- **The lambda captures by value.** GDScript freezes a lambda's captured locals at creation time. This is what makes D12.2's "captured once" guarantee hold, so it is load-bearing rather than incidental — but it is also a silent footgun for a future edit that tries to make the lambda read a live value. *Mitigation*: stated in a code comment at the capture site, not only here.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `watering-system.md` | **R7** — the spent jug detaches, arcs away in the current gravity basis, and is freed when the tween ends | D12.1 (jug animates and frees itself), D12.3 (`top_level` detach), D12.6 (the curve) |
| `watering-system.md` | **§5 edge case** — a jug in flight through a gravity flip finishes in the basis captured at throw time | D12.2 — the basis is copied into locals before any deferral, so nothing can re-aim it |
| `watering-system.md` | **§7** — `throw_arc_height`, `throw_duration`, `throw_angle_spread` live in `WateringTuning` | Read through `Tuning.WATERING` per ADR-0006 D6.3. No knob is added; §7's missing distance knob is recorded in Consequences → Negative |
| `watering-system.md` | **AC10** (Logic) — freed within `throw_duration + 0.1 s`; no jug persists into the next pour | D12.1 frees on `finished`; D12.7 keeps the test deterministic; the "next pour" clause holds by the `water_duration` margin, recorded as an authoring constraint |
| `watering-system.md` | **R2 / TR-watering-002** — carry scales `max_speed` only | **NOT addressed, deliberately.** See Consequences → Negative. The TR stays `gap` / `unowned` |
| `physics-props.md` | **§6** — buckets and spent jugs are excluded from prop physics | Held by construction: the jug is tween-driven, has no `RigidBody2D`, and never registers with `GravityAuthority.register_prop()`. This is why ADR-0011 and this ADR do not touch |

## Performance Implications

- **CPU**: One tween, active for at most `throw_duration` (0.8 s ceiling). **At most one jug is ever in flight** — R1 allows one carried bucket, and the next pour costs at least `water_duration` (2.0 s floor), which exceeds the longest flight. No per-frame cost when idle.
- **Memory**: One `Tween` object and one lambda per pour, both released when the jug frees. No pooling needed at this volume.
- **Load Time**: No change. No new scene, no new resource.
- **Network**: Not applicable.

## Migration Plan

1. **`src/scripts/bucket.gd`** — add `throw_spent(up_dir, right_dir)` exactly as written in Key Interfaces. This lands in the same changeset as ADR-0009's `Bucket` restructure, not before it: the method assumes the `Area2D` root type and the `on_picked_up()` / `consume()` pair that restructure creates.
2. **`PlayerWateringComponent._complete_pour()`** — add the single `throw_spent(...)` call between `consume()` and `_held_bucket = null`. Order matters: the reference is still held at that point.
3. **No `.tscn` change.** `top_level` is set in code (D12.3), so `bucket.tscn` is untouched by this ADR. ADR-0009's restructure of that file is unaffected.
4. **No `.tres` change.** All three knobs already exist in `watering_tuning.tres` with the GDD's defaults (ADR-0006 D6.4).

## Validation Criteria

| # | Criterion | Type | Closes |
|---|---|---|---|
| V1 | `throw_spent()` on a bucket in a headless scene leaves `is_instance_valid(bucket) == false` within `throw_duration + 0.1 s`. Asserts time and validity only — never position | Logic — **BLOCKING** | AC10 |
| V2 | **Immediately** after `throw_spent()` returns — same frame, no `await` — `monitorable` is `false` and `monitoring` is `false` | Logic | R7 "no collision", D12.4 |
| V3 | Calling `throw_spent(Vector2.UP, Vector2.RIGHT)` and then changing `GravityAuthority`'s vector mid-flight leaves the sampled path unchanged from a control run with no flip | Logic | §5 edge case, D12.2 |
| V4 | With `throw_angle_spread` at its 90 upper bound, sampled positions stay finite and bounded by `4 · throw_arc_height` | Logic | D12.6's `sin` over `tan` choice |
| V5 | With `SceneTree.paused = true` mid-flight, the jug's `global_position` is unchanged after several **idle** frames, and the arc resumes on unpause | Integration | D12.5 |
| V6 | Completing a pour leaves exactly zero jugs in the scene before the next pour begins | Integration | AC10 second clause |

**Test-harness note, and one flagged tension.**

- **V2 needs no `SceneTree` at all.** Its "immediately" is literal — same frame, no `await` — and it is testable only because D12.4 sets the property synchronously. Had the write stayed deferred, V2 would have needed a running tree to flush it, and the criterion would have been untestable in isolation.
- **V1, V3, and V4 do need a processing tree**, because a tween only advances on a processed idle frame (D12.5). They can be written against the jug in a minimal tree; they do not need a level.
- **Flagged, not resolved: `watering-system.md` types AC10 as `Logic`, but verifying it needs a live tree advancing idle frames** — which is closer to this project's `Integration` definition in `.claude/docs/coding-standards.md`. The criterion is real and testable either way; only its classification is in tension, which decides whether it is a BLOCKING or ADVISORY gate. This ADR does not re-type it. It belongs to the GDD or to a testing-standards pass.

## Related Decisions

- **ADR-0009** — Watering interaction model. Supplies `consume()`, the `Area2D` root type, and the `_complete_pour()` call site. This ADR adds one line to that method and one method to that class, and changes no frozen signature.
- **ADR-0006** — Tuning resource strategy. Supplies the three `throw_*` knobs through `Tuning.WATERING`.
- **ADR-0007** — Player component contract. Source of the D7.1 threading style this ADR deviates from, openly, in D12.2.
- **ADR-0002** — Level state ownership. `consume_bucket()` is driven by `Plant.pour_completed`, not by the throw. The throw is downstream of the count and cannot affect it.
- **ADR-0005** — Frame ordering. The pour resolves before the drain in every frame, so AC13 (a final pour on the depletion frame still kills) is unaffected by anything here.
- **ADR-0011** (not yet written) — Physics props. **No relationship.** `physics-props.md` §6 excludes spent jugs.
- `design/gdd/watering-system.md` — R7, §5, §6, §7, AC10.
