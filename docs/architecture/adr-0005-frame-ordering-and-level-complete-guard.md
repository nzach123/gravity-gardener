# ADR-0005: Frame ordering and the `level_complete` guard

## Status

**Accepted** — 2026-08-15

## Date

2026-08-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (SceneTree / frame lifecycle), Physics-2D adjacent |
| **Knowledge Risk** | **LOW for this ADR.** `VERSION.md` rates the project HIGH overall, but `modules/physics-2d.md` certifies 2D physics and its callback model unchanged 4.4 → 4.7, and node process ordering is 4.x-stable. The two APIs this ADR depends on were verified against the live 4.7 class reference on 2026-08-14 (see below). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/physics-2d.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None. `Node.process_physics_priority` was introduced in **4.1** (verified against engine source 2026-08-14 — absent in 4.0-stable, present in 4.1-stable); `Area2D.body_entered` is far older. Both predate the training cutoff. |
| **Verification Required** | None outstanding. F1 and F2 were verified 2026-08-14 and **independently re-verified** in the engine specialist review the same day, which additionally resolved F2's open corollary and established F3 (global process-group ordering). See *Engine facts this decision rests on* and `architecture-review-2026-08-14.md`. Note the review found the inter-area `body_entered` delivery order to be genuinely undetermined — that gap is closed by design in D5.4 rather than by verification. |

### Engine facts this decision rests on

Both were verified against the live Godot 4.7 class reference on 2026-08-14. Neither
is a training-data recollection. **Do not re-search these.**

**F1 — `_physics_process` order is set by `process_physics_priority`, not
`process_priority`.** `Node` carries both properties. `process_priority` orders
`_process` (the idle/render callback); `process_physics_priority` orders
`_physics_process`. Lower runs earlier; without an explicit value nodes run in
scene-tree order. `architecture.md` §Frame update path named `process_priority`
for a table of `_physics_process` callbacks — that ordering would never have taken
effect, and tick order would have silently remained an accident of tree layout,
which is the exact failure D5 exists to prevent.

- <https://docs.godotengine.org/en/stable/classes/class_node.html>
- <https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html>

**F2 — Area overlap is resolved once per physics step, not at the moment a body
moves.** The `Area2D` class reference states, of `get_overlapping_bodies()` and
`has_overlapping_bodies()`:

> "For performance reasons (collisions are all processed at the same time) this
> list is modified once during the physics step, not immediately after objects are
> moved. Consider using signals instead."

The consequence for this ADR: when `Player.move_and_slide()` carries the player
into the airlock during frame N's `_physics_process` batch, **nothing later in that
same batch can observe the entry** — not `body_entered`, not
`get_overlapping_bodies()`, not `has_overlapping_bodies()`. The overlap is resolved
by the physics step that runs after the batch.

- <https://docs.godotengine.org/en/stable/classes/class_area2d.html>

**F2 corollary — RESOLVED 2026-08-14.** This originally hedged between two readings
of when `body_entered` is emitted — tail of step N, or head of frame N+1 — and
argued the choice did not matter. The engine specialist review settled it, and the
answer is a third and stronger reading than either. `Main::iteration()` runs, per
physics substep:

```
PhysicsServer2D::sync()
PhysicsServer2D::flush_queries()   ← body_entered fires here
SceneTree::physics_process()       ← all _physics_process, priority-ordered
PhysicsServer2D::end_sync()
PhysicsServer2D::step()            ← overlaps computed here
```

`flush_queries()` fires signals from pairs computed by the *previous* substep's
`step()`. So an overlap caused by frame N's `move_and_slide()` is computed by frame
N's `step()` — which runs after every node's `_physics_process`, including
`OxygenDrain` at `+100` — and the resulting `body_entered` is delivered at the very
**start** of frame N+1, before *any* node's `_physics_process` that frame, not
merely before `OxygenDrain`'s. D5.2's diagram is correct, and the armed-death design
rests on firmer ground than the two-readings hedge could show.

- `main/main.cpp` — `Main::iteration()` loop body

**F3 — `process_physics_priority` ordering is a single global sort, not per-parent.**
Verified 2026-08-14. Physics-processing nodes are held in one flat vector per
process group, sorted by a global priority comparator with a scene-tree-position
tiebreak. Autoloads — direct children of the SceneTree root — and ordinary scene
descendants share the single `default_process_group`. There is no per-parent
partitioning and no separately-scheduled autoload branch.

This is what licenses the `-100` row: `GravityAuthority` is an autoload living in a
different branch of the tree from the scene nodes it must precede, and had ordering
been scoped per-parent the priority table would have ordered nothing — reproducing
the exact class of defect F1 exists to correct. The guarantee is conditional on no
node in the chain setting `process_thread_group` away from default; see Risks.

`Node.process_physics_priority` was introduced in **4.1** (absent in 4.0-stable,
present in 4.1-stable), which is what makes this ADR's "Post-Cutoff APIs Used: None"
claim correct rather than merely plausible.

- `scene/main/scene_tree.cpp` — `_process_group()`, `default_process_group`
- `scene/main/node.h`

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (defines `LevelState.level_complete`, `OxygenState`, `OxygenDrain`, and the injection lifecycle this ADR sequences). Must be Accepted first. |
| **Enables** | ADR-0008 (oxygen drain and death path) and ADR-0009 (watering interaction model). Both were explicitly ordered behind this ADR because both consume the ordering contract defined here. |
| **Blocks** | Any epic touching the oxygen death path, the watering pour, or level completion. `suit-oxygen.md` AC8 and `watering-system.md` AC13 are untestable until this is Accepted. |
| **Ordering Note** | Taken out of numeric sequence (before ADR-0003, ADR-0004 and ADR-0006) precisely because ADR-0008 and ADR-0009 cannot start without it. ADR-0002 declared the `level_complete` field but deliberately deferred *when it is read and written* to this ADR. |

## Context

### Problem Statement

Two acceptance criteria in two different GDDs describe the same instant — the
frame oxygen reaches zero — and demand opposite outcomes:

- **`watering-system.md` AC13** — completing the final pour on the frame oxygen
  reaches zero must result in **death, not level completion**.
- **`suit-oxygen.md` AC8** — entering the airlock on the frame oxygen reaches zero
  must **complete the level**.

Read as unordered rules these contradict each other. They are reconcilable only if
frame ordering is a contract: the pour and the airlock entry are different events,
resolved at different points in the frame, and exactly one piece of state —
`level_complete` — separates them.

`architecture.md` D5 sketched that contract. Three defects make it
unimplementable as written, and this ADR exists to resolve all three:

1. **Wrong property.** D5 orders `_physics_process` callbacks with
   `process_priority`, which orders `_process` (F1). The table would have had no
   effect.
2. **An impossible row.** D5 places `Goal._physics_process` at `+50` resolving
   airlock entry between the player's movement at `0` and the death check at
   `+100`. `goal.gd:15` resolves entry through `Area2D.body_entered`, and by F2 no
   overlap-based mechanism can observe an entry caused by movement earlier in the
   same batch. On the exact frame AC8 describes, `OxygenDrain` at `+100` would run
   with `level_complete` still false and kill the player. **D5 as written fails
   AC8** — the criterion it was drafted to satisfy.
3. **Two clocks.** `plant.gd:34` accumulates `water_progress` in `_process`, the
   render frame, while oxygen drains in `_physics_process`. "The same frame" in
   AC13 is not a defined concept across two clocks running at unrelated rates.

### Constraints

- `watering-system.md` §6 records `Goal` as **behaviour unchanged** — it watches
  the unlock flag and emits `player_reached_goal`, nothing more. A fix that
  rebuilds Goal's detection model spends that constraint.
- ADR-0002 registered `depleted_wired_to_restart` as forbidden: `OxygenState.depleted`
  is a pure state signal and `OxygenDrain` owns the kill policy. The guard belongs
  in the policy layer, not the state layer.
- ADR-0002 registered `level_state_reset_method` as forbidden. `level_complete`
  therefore gets no setter that can clear it; restart is reconstruction.
- `suit-oxygen.md` R3 and AC2 require oxygen death to be **indistinguishable** from
  spike and kill-area death. Any guard that protects only the oxygen path leaves
  the other two paths behaving differently on the completion frame.
- `main.gd:62` already routes restart through `call_deferred("reload_current_scene")`,
  and `change_level()` through `change_scene_to_packed()`. Both take effect at the
  end of the current frame, not instantly — so there is a live window between
  "the level was won" and "the scene actually changed".

### Requirements

- AC13 and AC8 must both pass **by construction**, not by convention or by tuning.
- Tick order must be explicit and reviewable in one place, and must not drift as
  eight level scenes are authored.
- The reconciling state must be write-once — a `level_complete` that can be cleared
  reintroduces the hand-maintained-reset defect ADR-0002 eliminated.
- No death path may restart a level the player has already completed.

## Decision

### D5.1 — Ordering is `process_physics_priority`, assigned in code

The frame contract is expressed with `process_physics_priority` (F1), assigned in
each node's `_ready()` from a named constant. It is **not** set through the
inspector on a per-scene basis: eight level scenes each carrying an editable copy
of the ordering is eight opportunities for silent drift, and the resulting bug —
a death check that runs before movement in one level only — is close to
undiagnosable.

| `process_physics_priority` | Node | Responsibility |
|---|---|---|
| `-100` | `GravityAuthority` | Ease direction, push space gravity, force-wake props |
| `0` | `Player` (+ its components, called inline) | Pour progress, movement, `move_and_slide()` |
| `+100` | `OxygenDrain` | Armed-kill evaluation, **then** drain |

`Goal` has no row. It does not participate in the batch ordering at all — it
resolves at the physics-query phase, which is a different point in the frame, not a
different priority. This is the correction to `architecture.md`'s `+50` row.

### D5.2 — Airlock entry is resolved by armed death, deferred one physics frame

`OxygenDrain` does not kill on the frame oxygen empties. It **arms**, and evaluates
the kill at the top of its next callback — by which point any `body_entered` from
the intervening physics step has already been delivered (F2 corollary).

```
frame N     Player       (0)     move_and_slide() → player is inside the airlock
            OxygenDrain  (+100)  drain(Δ) → remaining <= 0 → _death_armed = true
            ── physics step: overlap resolved (F2) ──

frame N+1   ── body_entered delivered → Goal.player_reached_goal ──
            LevelRoot._on_player_reached_goal():
                level_state.mark_complete()      ← guard is now set
                change_level()
            OxygenDrain  (+100)  level_complete → freeze; no drain, no kill  ✅ AC8
```

And the case AC13 describes, which must reach the opposite outcome:

```
frame N     Player       (0)     final pour completes → LevelState.consume_bucket()
                                 → goal_unlocked = true   (the DOOR opens)
            OxygenDrain  (+100)  drain(Δ) → remaining <= 0 → _death_armed = true

frame N+1   ── no body_entered: unlocking a door is not walking through it ──
            OxygenDrain  (+100)  _death_armed and not level_complete → restart  ✅ AC13
```

The asymmetry that makes both pass is that **unlocking the airlock and entering it
are different events**. `watering-system.md` §5 already states this in prose —
"R6 unlocks the airlock; it does not teleport the player to it — the door must be
physically reached". This ADR is that sentence expressed as frame ordering.

Cost of the deferral: death lands one physics frame late — 16.6 ms at 60 FPS,
below the threshold of perception and far below the input latency the player is
already absorbing.

### D5.3 — `level_complete` is a write-once latch owned by `LevelRoot`

`Goal` continues to emit `player_reached_goal` and writes no level state, holding
`watering-system.md` §6's "behaviour unchanged" and staying clear of ADR-0002's
`plant_decides_level_outcome` ban. `LevelRoot` — which already connects that signal
at `main.gd:16-18` — is the sole writer.

The two existing connections are replaced by **one ordered handler**. Relying on
signal connection order to get the latch set before the scene change is exactly the
kind of implicit ordering this ADR exists to remove.

### D5.4 — `restart_level()` is the guarded chokepoint

The guard lives at the single point every death path already passes through, rather
than being repeated at each caller. This covers `OxygenDrain`, `spike_hazard`'s
`inc_hazard_dmg`, and `_on_kill_area_2d_body_entered` uniformly — satisfying
`suit-oxygen.md` R3/AC2's demand that the three be indistinguishable, on the
completion frame as much as on any other.

`OxygenDrain` retains its own check. That is deliberate redundancy, not an
oversight: ADR-0002 assigns the oxygen kill *decision* to `OxygenDrain`, and the
chokepoint is a backstop for every path, including ones added later by an author
who never reads this ADR.

**The latch alone is not sufficient — a `_transition_pending` guard is also
required.** *(Added 2026-08-14 — engine specialist review A5-02.)* `body_entered`
for *different* `Area2D` nodes delivered in the same `flush_queries()` batch is not
ordered by `process_physics_priority` — that property governs `_physics_process`
dispatch, not signal-callback dispatch during query flush — and no deterministic
inter-area delivery order could be established from documentation or source. If
level geometry ever lets the player enter a goal trigger and a hazard trigger within
one physics tick, and the hazard handler happens to run first, `restart_level()`
queues a reload while `level_complete` is still `false`; the goal handler then
latches completion and queues a scene change, leaving both pending for the same
frame. Guarding on `level_complete` alone cannot close this, because the order in
which the two handlers run is the very thing in question. An idempotent
transition latch checked and set by *both* paths closes it regardless of order —
see Key Interfaces.

### D5.5 — Load-bearing gameplay timing moves to `_physics_process`

`plant.gd`'s `water_progress` accumulation migrates from `_process` to
`_physics_process`. Any quantity whose value on a specific frame decides life,
death or completion belongs on the physics clock; without this, AC13 cannot be
written as a deterministic test, because the pour and the drain would advance on
clocks with no fixed relationship.

Cosmetic work — camera follow, sprite placement, animation — legitimately stays in
`_process`. The line is whether a rule reads the value.

**What moves, exactly.** *(Enumerated 2026-08-14 — engine specialist review A5-04.)*
In the current `plant.gd` the accumulation is entangled in one conditional structure
with the interact polling, the completion check, and the animation calls. Moving
only the `+=` line would leave completion detection on the idle clock, reading a
value physics wrote with no defined phase relationship — reproducing the two-clocks
defect named in Context problem #3 while appearing to have fixed it. All four of the
following move to `_physics_process` together:

- `Input.is_action_pressed("interact")` / `is_action_just_released` polling
- `water_progress += delta`
- the `water_progress >= water_duration` completion check
- the `_complete_watering()` and `_reset_watering()` calls

Only `animated_sprite_2d.speed_scale` and `.play(…)` stay in `_process`, reading
state that `_physics_process` has already written.

### Architecture Diagram

```
                     ┌──────────────────────────────────────────┐
   physics frame ──▶ │  _physics_process batch                  │
                     │  ordered by process_physics_priority     │
                     ├──────────────────────────────────────────┤
        -100         │  GravityAuthority   ease → space → wake  │
           0         │  Player             pour, move_and_slide │
                     │  Plant              water_progress (D5.5)│
        +100         │  OxygenDrain        ┌ level_complete? ──────▶ freeze
                     │                     ├ _death_armed?   ──────▶ restart_level()
                     │                     ├ drain(Δ)                      │
                     │                     └ remaining<=0 → arm            │
                     └──────────────────────────────────────────┘          │
                                        │                                  │
                     ── physics step: overlap resolved (F2) ──             │
                                        │                                  ▼
                     ── body_entered ───┘                       ┌──────────────────┐
                                        │                       │ restart_level()  │
                                        ▼                       │ if level_complete│
                     Goal.player_reached_goal                   │     return  ◀────┼── spike
                                        │                       └──────────────────┘   kill area
                                        ▼
                     LevelRoot._on_player_reached_goal()
                        1. level_state.mark_complete()   ← write-once latch
                        2. change_level()
```

### Key Interfaces

```gdscript
# LevelState — extends the ADR-0002 contract
var _level_complete: bool = false
var level_complete: bool:
    get: return _level_complete         # getter-only: no external writer exists
                                        # (ADR-0002 A2-01 — a plain var would not
                                        #  enforce this)

func mark_complete() -> void:
    # Write-once. No un-set, no reset — restart is reconstruction (ADR-0002).
    # Idempotent: a second call is a no-op, not an error.
    _level_complete = true


# FramePriority — const-only script. The single source of the ordering contract.
# NOT on LevelRoot: GravityAuthority is an autoload present before any level scene
# loads, and must not source a constant from a per-level scene script. (A5-05.)
class_name FramePriority
const GRAVITY : int = -100
const PLAYER  : int = 0
const OXYGEN  : int = +100


# LevelRoot — sole writer of the latch, sole owner of the death chokepoint
var _transition_pending: bool = false   # D5.4 — order-independent guard

func _on_player_reached_goal() -> void:
    # Ordered explicitly. Signal connection order is NOT a contract (D5.3).
    if _transition_pending:
        return
    _transition_pending = true
    level_state.mark_complete()
    change_level()

func restart_level() -> void:
    if level_state.level_complete or _transition_pending:
        return                          # D5.4 — completion already won this frame
    _transition_pending = true
    get_tree().call_deferred("reload_current_scene")


# OxygenDrain — owns the kill policy (ADR-0002); this ADR fixes its frame shape
var _death_armed: bool = false

func _physics_process(delta: float) -> void:
    if _level_state.level_complete:
        return                          # D5.6 — frozen: no drain, no kill
    if _death_armed:
        _level_root.restart_level()     # evaluated a frame after arming (D5.2)
        return
    _oxygen_state.drain(delta)
    if _oxygen_state.remaining <= 0.0:
        _death_armed = true
```

### D5.6 — Completion freezes the drain, and why that is not a contradiction

Once `level_complete` is set, `OxygenDrain` stops calling `drain()` as well as
suppressing the kill, so the HUD holds its final reading through the scene
transition instead of visibly bottoming out behind a fade.

This **narrows a precondition ADR-0002 registered** on `OxygenState.contract`:

> "drain() called exactly once per physics frame, unconditionally, in every player
> state [suit-oxygen R2/AC1]"

The narrowing is recorded here explicitly rather than left as a silent
contradiction between two Proposed ADRs. The precondition's purpose, stated in the
same registry entry, is that "drain() contains no state checks, so no caller can
create a safe state" — it exists to stop *player states* (watering, crouching,
wall-clinging) from becoming oxygen sanctuaries. `level_complete` is not a player
state; it is the level having ended. The invariant that matters —
`suit-oxygen.md` R4, `remaining` never increases — is untouched: freezing is not
refilling, and `OxygenState` still has no setter.

Scope of the exception, stated tightly so it cannot be stretched: **`level_complete`
is the only condition permitted to suppress a `drain()` call. It is checked in
`OxygenDrain`, never inside `OxygenState.drain()`, which remains free of state
checks exactly as ADR-0002 requires.**

## Alternatives Considered

### Alternative 1: Same-frame geometric poll in `Goal`

- **Description**: `Goal` polls `rect.has_point(player.global_position)` at `+50`
  each physics frame and sets `level_complete` immediately; the death check stays
  same-frame at `+100`.
- **Pros**: Exact same-frame resolution, no deferral, no reasoning about physics
  phases at all.
- **Cons**: Gives `Goal` a hand-rolled overlap test that can disagree with its own
  `Area2D` shape, and that must then be kept in sync with it by hand forever. Must
  also be reconciled with `body_entered`, which still fires, or entry double-fires.
  Spends `watering-system.md` §6's "behaviour unchanged" for `Goal`.
- **Rejection Reason**: It buys an imperceptible 16.6 ms of latency with a
  permanent second source of truth for "is the player in the airlock". Two
  geometry implementations that must agree is a worse long-term liability than one
  frame of delay.

### Alternative 2: Same-frame physics shape query in `Goal`

- **Description**: `Goal` at `+50` runs `intersect_shape()` against the direct
  space state, which reads current transforms rather than last-step results, and
  so can observe an entry caused earlier in the same batch.
- **Pros**: Physically correct and same-frame, without duplicating collision
  geometry — the query uses the real shape.
- **Cons**: A space query every physics frame, forever, per goal. Still replaces
  `Goal`'s detection model and still must be reconciled with the `body_entered`
  path.
- **Rejection Reason**: Same trade as Alternative 1 with a higher running cost.
  A recurring per-frame query is a poor price for removing a delay no player can
  perceive.

### Alternative 3: `architecture.md` D5 as originally written

- **Description**: `Goal._physics_process` at `+50` resolving airlock entry
  between movement at `0` and the death check at `+100`.
- **Pros**: None beyond already being written down.
- **Cons**: Not implementable. By F2 the entry cannot be observed in the batch that
  caused it, and by F1 the property named would not have ordered the batch anyway.
- **Rejection Reason**: **Fails `suit-oxygen.md` AC8** — the criterion it was
  drafted to satisfy. Retained here so a future reader who finds the old table in
  git history understands why it changed.

### Alternative 4: Guard only `OxygenDrain`, not `restart_level()`

- **Description**: The literal reading of `architecture.md` and ADR-0002 — only the
  oxygen path consults `level_complete`.
- **Pros**: Smallest possible change; keeps the guard adjacent to the policy owner.
- **Cons**: A spike or kill-area touched on the completion frame still restarts a
  level the player has already won.
- **Rejection Reason**: Violates `suit-oxygen.md` R3/AC2 — the three death paths
  must be indistinguishable, and this makes oxygen the only one that respects
  completion. The chokepoint costs two lines and closes the class.

## Consequences

### Positive

- AC13 and AC8 pass **by construction**. Neither depends on tuning, on tree layout,
  or on a comment asking a future author not to reorder anything.
- One guard covers every death path, present and future, including paths added by
  someone who never reads this ADR.
- `level_complete` cannot be cleared, so ADR-0002's "restart is reconstruction"
  stance survives contact with the completion path.
- `Goal` and `Plant` keep their existing detection and interaction models; the
  changes are to *when* code runs, not to what it does.
- Two latent defects are removed as a side effect: an ordering table that ordered
  nothing (F1), and pour progress on a clock unrelated to the rules that read it.

### Negative

- Oxygen death is one physics frame later than the depletion that caused it. There
  is a single frame in which `remaining <= 0` and the player is still alive and
  controllable.
- `OxygenDrain` carries `_death_armed`, a small state machine where a direct
  conditional would have appeared to suffice. The comment explaining why is
  mandatory — without it, "simplifying" the deferral away is an obvious-looking
  cleanup that silently breaks AC8.
- The freeze in D5.6 is a documented exception to an ADR-0002 precondition. Every
  exception is a thing a future reader must hold in mind.
- Ordering constants live in code rather than the inspector, so changing tick order
  is a code edit. This is intended — it is a contract, not a tuning knob.

### Risks

- **Someone "simplifies" the armed deferral back to a direct kill.** Presents as
  AC8 failing only on a frame-perfect entry — rare in play, easy to dismiss as a
  fluke. *Mitigation*: registered forbidden pattern `same_frame_oxygen_kill`, plus
  the mandatory comment at the call site and an AC8 regression test.
- **A new node needs deterministic ordering and its author sets `process_priority`,
  as `architecture.md` said.** It compiles, it runs, it orders nothing. *Mitigation*:
  registered forbidden pattern `physics_order_via_process_priority`, and F1 is
  recorded as verified so no one re-derives it.
- **New gameplay timing is written in `_process` by habit.** Presents as
  frame-rate-dependent behaviour that survives testing at 60 FPS and fails
  elsewhere. *Mitigation*: registered forbidden pattern
  `gameplay_timing_in_idle_process`.
- **A future author sets `level_complete` from `Goal` directly**, it being the node
  that knows the player arrived. *Mitigation*: registered forbidden pattern
  `level_complete_written_outside_level_root`; `mark_complete()` on `LevelRoot`'s
  handler is the only sanctioned path.
- **A node in the ordering chain sets `process_thread_group` away from default.**
  The global sort guaranteed by F3 is scoped to the default process group;
  `process_thread_group` (`SUB_THREAD` / `MAIN_THREAD`) moves a node and its subtree
  into a separately-scheduled group with an independent priority sort. Nothing sets
  it today, so there is no live bug — but a future author enabling multithreaded
  processing on `Player`, `OxygenDrain` or `GravityAuthority`, plausibly while
  chasing a performance win, would silently detach that node from the `-100`/`0`/
  `+100` contract. No compile error, no symptom until a frame-perfect AC8 or AC13
  case fails. *Mitigation*: registered forbidden pattern
  `process_thread_group_split_in_frame_chain`. *(Added 2026-08-14 — engine
  specialist review A5-01.)*
- **The single-frame window in which the player is alive at zero oxygen.** No
  current mechanic can exploit 16.6 ms. *Mitigation*: noted, not defended against;
  revisit only if a mechanic ever grants meaningful action inside one frame.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `watering-system.md` | **AC13** (`TR-watering-012`) — final pour on the frame oxygen reaches zero yields death, not completion | The pour resolves at priority `0` and sets `goal_unlocked`; it never sets `level_complete`, because unlocking the door is not entering it. The armed kill fires the following frame unopposed (D5.2). |
| `watering-system.md` | **§5 edge case** — "R6 unlocks the airlock; it does not teleport the player to it — the door must be physically reached" | Made structural: `goal_unlocked` and `level_complete` are distinct fields written by distinct events, `LevelState.consume_bucket()` and `LevelRoot._on_player_reached_goal()` respectively. |
| `watering-system.md` | **§6** — `Goal` behaviour unchanged | Honoured. `Goal` keeps `body_entered` and `player_reached_goal` and writes no level state (D5.3). Rejecting Alternatives 1 and 2 was in large part to preserve this. |
| `suit-oxygen.md` | **AC8** (`TR-oxygen-010`) — airlock entry on the frame oxygen reaches zero completes the level | The kill is deferred one physics frame, by which point `body_entered` has been delivered and the latch is set, so the kill is suppressed (D5.2). |
| `suit-oxygen.md` | **§5** — "Airlock entry wins... punishing a frame-perfect success would be gratuitous" | The deferral is precisely this rule: on a tie between entry and depletion, entry wins. |
| `suit-oxygen.md` | **R3 / AC2** — oxygen death uses the identical restart path as spike death, indistinguishable | All three route through the guarded `restart_level()` (D5.4), so all three are suppressed identically after completion. |
| `suit-oxygen.md` | **R2 / AC1** — drain is unconditional in every player state | Preserved. `OxygenState.drain()` keeps no state checks; the only suppressing condition is `level_complete`, checked in `OxygenDrain`, and it is not a player state (D5.6). |
| `suit-oxygen.md` | **R4** — nothing refills the suit | Untouched. Freezing is not refilling; `remaining` still has no setter. |
| `gravity.md` | **AC12** — every body responds to a gravity change in the same physics frame | `GravityAuthority` at `-100` runs before any consumer reads gravity, so no consumer can observe a stale vector. |

## Performance Implications

- **CPU**: Effectively zero. Three integer assignments at `_ready()`, one boolean
  test per physics frame in `OxygenDrain`, one in `restart_level()`. Moving pour
  accumulation from `_process` to `_physics_process` typically *reduces* calls,
  since physics ticks at 60 Hz while idle frames are uncapped.
- **Memory**: One bool per `LevelState`, one per `OxygenDrain`.
- **Load Time**: None.
- **Network**: N/A — single-player.

## Migration Plan

0. **New** `FramePriority` — a const-only script holding `GRAVITY` / `PLAYER` /
   `OXYGEN`. Not on `LevelRoot` (A5-05).
1. `LevelState` — add `_level_complete` with a getter-only `level_complete`
   property and `mark_complete()`. No setter, no clear, no `reset()` (ADR-0002).
2. `LevelRoot` (`main.gd`) — replace the two `player_reached_goal` connections at
   `main.gd:16-18` with the single ordered handler `_on_player_reached_goal()`.
   Keep `player.win_level()` wired; order it after `mark_complete()`. Add the
   `_transition_pending` field (D5.4).
3. `LevelRoot.restart_level()` (`main.gd:59`) — add the
   `level_complete or _transition_pending` early return. Leave the existing
   `call_deferred("reload_current_scene")` (`main.gd:62`) as is; delete the
   `GameManager.reset_level_state()` call per ADR-0002.
4. `OxygenDrain` (new node, ADR-0002) — implement `_physics_process` in the exact
   order given in *Key Interfaces*: freeze check, armed check, drain, arm. Comment
   the deferral with a pointer to this ADR and to AC8.
5. `GravityAuthority`, `Player`, `OxygenDrain` — assign `process_physics_priority`
   in `_ready()` from the `FramePriority` constants. **Not** `process_priority` (F1),
   and do not set `process_thread_group` on any of the three (F3, Risks).
6. `plant.gd` — move interact polling, the `water_progress` accumulation
   (`plant.gd:34`), the `water_duration` completion check, and the
   `_complete_watering()` / `_reset_watering()` calls from `_process` to
   `_physics_process` (D5.5). Only `speed_scale` and `play()` stay in `_process`.
   Note that `plant.gd:76-79`'s `GameManager` write is removed separately by
   ADR-0002; these two migrations touch the same function and should land together.
7. `goal.gd` — no change to entry detection (`body_entered` connected at
   `goal.gd:15`, handler at `goal.gd:38-42`). Its `GameManager.goal_unlocked`
   polling in `_process` becomes a `LevelState` read under ADR-0002; that is
   ADR-0002's migration, not this one.

> *Line citations corrected 2026-08-14 — engine specialist review A5-07.* Several
> were 1–4 lines off against live source; `main.gd:16-18` was accurate as cited.

Steps 1–5 are inert until `OxygenDrain` exists, so this ADR's migration lands with
ADR-0002's or after it — never before.

## Validation Criteria

This decision is correct if the following hold. The first two are the ACs that
motivated the ADR and are **blocking**; both are Integration-type evidence per the
project testing standards.

1. **AC8** — drive `remaining` to exactly `0` on the frame the player's
   `move_and_slide()` carries them into the airlock. Expected: level completes, no
   restart, `restart_level()` never runs its reload.
2. **AC13** — complete the final pour on the frame `remaining` reaches `0`, with
   the player not in the airlock. Expected: `goal_unlocked == true`, level restarts,
   `level_complete == false` throughout.
3. **Chokepoint** — trigger `inc_hazard_dmg` on the frame after `mark_complete()`.
   Expected: no reload; the completed level still changes scene.
4. **Ordering** — a **static/grep-level** check that each of the three `_ready()`
   methods contains a literal `process_physics_priority = FramePriority.*`
   assignment, plus a runtime assertion that
   `GravityAuthority.process_physics_priority < Player.process_physics_priority
   < OxygenDrain.process_physics_priority`.
   *(Amended 2026-08-14 — engine specialist review A5-03.)* This originally asked
   for a runtime assertion that all three were "explicitly assigned, not defaulted."
   That is not implementable: `Player`'s assigned priority is `0`, which is also the
   engine default for every node that never touches the property, so a runtime read
   cannot distinguish the two. The criterion could not detect its own failure mode
   for the one node whose correct value coincides with the default. The grep check
   can, and matches the pattern criterion 5 already uses.
5. **Clock** — assert `Plant` has `_physics_process` and no `_process` accumulation
   of `water_progress`. A grep-level check is sufficient and cheap to keep in CI.
6. **Latch** — call `mark_complete()` twice; assert idempotent and that no code path
   anywhere sets `level_complete = false`.

The decision is **wrong**, and should be revisited, if the one-frame death deferral
ever becomes observable — for example if a future mechanic grants the player a
meaningful action within a single physics frame, or if a death VFX is authored to
begin on the exact frame of depletion rather than on the restart.

## Related Decisions

- **ADR-0001** — gravity ownership; supplies the `-100` row and `gravity.md` AC12's
  same-frame guarantee.
- **ADR-0002** — level state ownership; declared `level_complete` (registry line 81)
  and deferred its read/write ordering to this ADR. This ADR narrows one
  `OxygenState.contract` precondition, scoped in D5.6.
- **ADR-0008** (unwritten) — oxygen drain and death path. Consumes this contract;
  cannot start until this is Accepted.
- **ADR-0009** (unwritten) — watering interaction model. Inherits the D5.5 clock
  migration.
- `docs/architecture/architecture.md` §Frame update path — **amended 2026-08-14** by
  this ADR in three places (property name, the `Goal +50` row, the frame diagram).
- `design/gdd/watering-system.md` AC13, §5, §6 · `design/gdd/suit-oxygen.md` AC8,
  §5, R2/R3/R4.
