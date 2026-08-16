# Godot — Core Module Reference

Collated 2026-08-15. The engine facts below were verified **2026-08-14** by the
ADRs that rest on them (ADR-0001, ADR-0003, ADR-0005, ADR-0006), against the live
Godot 4.7 class reference and engine source. They are not training-data
recollections, and this file does not re-verify them — it exists so that four
Accepted ADRs do not each have to carry the same Core semantics privately.

**Do not re-search these.** If one is ever found to be wrong, correct it here and
in the owning ADR together; a silent fix in one place leaves the other binding.

## Stability

No breaking changes to `Node`, `SceneTree`, `Resource`, or `PackedScene`
across 4.4 → 4.7.1. Training-data knowledge of the Core node lifecycle is broadly
reliable. The traps below are not version drift — they are longstanding semantics
that are easy to state backwards.

## Processing order

| Property | Orders | Introduced |
|---|---|---|
| `process_priority` | `_process` (idle/render callback) | pre-4.0 |
| `process_physics_priority` | `_physics_process` | **4.1** |

Lower values run earlier. With no explicit value, nodes run in scene-tree order.

### Rules

- **Never use `process_priority` to order `_physics_process`.** They are separate
  properties on `Node` and the wrong one is inert. `architecture.md` once named
  `process_priority` for a table of `_physics_process` callbacks; that ordering
  would never have taken effect, and tick order would have silently stayed an
  accident of tree layout (ADR-0005 F1).
- **Ordering is a single global sort, not per-parent** (ADR-0005 F3). Physics-processing
  nodes live in one flat vector per process group, sorted by a global priority
  comparator with a scene-tree-position tiebreak. Autoloads — direct children of the
  SceneTree root — and ordinary scene descendants share the single
  `default_process_group`. There is no per-parent partitioning and no separately
  scheduled autoload branch. This is what lets an autoload be ordered ahead of scene
  nodes in a different branch.
- **The global-sort guarantee is conditional** on no node in the chain setting
  `process_thread_group` away from default.
- `process_physics_priority` being a 4.1 API is what makes the ADRs' "Post-Cutoff
  APIs Used: None" claims correct rather than merely plausible.

> **Hazard — `process_thread_group_split_in_frame_chain`.** A legitimate engine
> feature, inert today, one inspector click away, that silently detaches a node from
> the ordering contract with no compile error and no symptom until a specific case
> fails. Same shape as `resource_local_to_scene` below. Neither is a bug; both are
> defaults that must be *stated* precisely because nothing complains when they change.

## Pause and process modes

| Property | Values | Effect |
|---|---|---|
| `Node.process_mode` | `PROCESS_MODE_INHERIT` (default), `PROCESS_MODE_PAUSABLE`, `PROCESS_MODE_WHEN_PAUSED`, `PROCESS_MODE_ALWAYS`, `PROCESS_MODE_DISABLED` | Governs whether `_process`/`_physics_process` run while `SceneTree.paused` is true |
| `SceneTree.paused` | `bool` | Setting `true` stops `_process`/`_physics_process` from being called on every node whose *resolved* process mode is `PAUSABLE` (the default, via `INHERIT`) |

**`PROCESS_MODE_INHERIT` resolves up the tree to the nearest ancestor with an
explicit mode**, defaulting to `PROCESS_MODE_PAUSABLE` at the root if nothing
in the chain overrides it. A node left at the default `INHERIT` therefore
stops calling `_physics_process` the instant `SceneTree.paused` becomes
`true` — no per-node check needed, no flag to read. This has been stable
since pause modes were introduced and is unaffected by any 4.4–4.7.1 change.

**The resolution is chain-wide, not per-node.** Any ancestor between a node
and the tree root that sets a non-`INHERIT` mode changes what every
`INHERIT` descendant resolves to, silently, with no compile error and no
symptom until the tree is actually paused. Same hazard shape as
`process_thread_group_split_in_frame_chain` above.

## The physics frame

`Main::iteration()` runs, per physics substep:

```
PhysicsServer2D::sync()
PhysicsServer2D::flush_queries()   ← body_entered fires here
SceneTree::physics_process()       ← all _physics_process, priority-ordered
PhysicsServer2D::end_sync()
PhysicsServer2D::step()            ← overlaps computed here
```

`flush_queries()` fires signals from pairs computed by the *previous* substep's
`step()`. Two consequences, both load-bearing:

- **Overlap is resolved once per step, not when a body moves** (ADR-0005 F2). The
  `Area2D` reference states that the overlap list "is modified once during the
  physics step, not immediately after objects are moved." So when
  `move_and_slide()` carries a body into an area during frame N's batch, *nothing
  later in that same batch can observe it* — not `body_entered`, not
  `get_overlapping_bodies()`, not `has_overlapping_bodies()`.
- **The resulting `body_entered` arrives at the very start of frame N+1**, before
  *any* node's `_physics_process` that frame — not merely before a specific
  late-priority listener.

Inter-area `body_entered` delivery order is **genuinely undetermined**. ADR-0005
closes that gap by design (D5.4) rather than by relying on an engine guarantee.
Do not write code that depends on which of two areas reports first.

## Node lifecycle and instantiation

- **`_ready()` is bottom-up.** A parent's `_ready()` runs after every child's.
  Children are therefore constructed and their `@export`s populated by the time a
  parent's `_ready()` runs.
- **`PackedScene.instantiate()` populates `@export` values without running
  `_ready()`** (ADR-0003 E1). In `SceneState::instantiate()`, exported properties
  are set via a `node->set(...)` loop that completes before the function returns.
  `_ready()` is dispatched by `NOTIFICATION_READY`, which fires only on tree entry —
  and `instantiate()` never enters a tree.
- **`@export`ed *node references* also resolve at instantiation**, not tree entry
  (ADR-0003 E2). The `node_paths=PackedStringArray(...)` mechanism is collected into
  a `deferred_node_paths` list and applied during instantiation.
- **`@onready` is the exception**: on a scene merely instantiated and never added to
  the tree, `@onready` fields are *not* populated. `@onready` on a node whose
  `_ready()` has run is available.

Together these are what make headless validation possible: a level can be
instantiated, inspected, and freed with **no `SceneTree` and without firing a single
gameplay `_ready()`**.

> **Provenance note:** ADR-0003 E1 cites `scene/resources/packed_scene.cpp` at the
> **4.3-stable** tag, not 4.7.1. The behaviour is longstanding and no 4.4–4.7
> breaking change touches it, but the citation is to an older tag than the project
> runs. Re-pin the link if E1 is ever revisited.

## Resources

- **`Resource.resource_local_to_scene` defaults to `false`.** Set `true`, the engine
  hands **each instantiating scene its own copy**. That is a legitimate feature — it
  is how two instances of one scene get independent materials — and it is a single
  inspector checkbox.
- On a shared data resource it **silently destroys single-instance identity**: the
  same `preload()`ed resource read from two scenes becomes two objects, and any
  "exactly one instance project-wide" guarantee quietly becomes false. Nothing
  errors. Nothing logs. See ADR-0006 D6.9.
- **`preload()` of a `.tres` into a `const` on a `class_name` script** resolves with
  no `SceneTree` involvement at all, allocates nothing per frame, and fails at
  **parse time** if the file is missing or renamed — not at first use.

> **Known trap** (ADR-0006): a `.tres` whose script declares `class_name`, referenced
> through a multi-file type-annotation chain, can fail `is` / `as` checks. It
> presents as a cyclic-dependency problem and is not one.

## Who depends on this

Every consumer below is **specified and Accepted but not yet implemented** —
verified against `src/` on 2026-08-15. None of these semantics is currently
exercised by running code, so none is protected by the test suite. They are
load-bearing for work that has not been written yet, which is exactly why they are
recorded rather than rediscovered.

| Depends on | For | Status in `src/` |
|---|---|---|
| **ADR-0005** | `_physics_process` priority allocations (the ADR owns the numbers; this file owns the semantics under them) | no priorities set yet |
| **ADR-0003** | headless level validation with no `SceneTree` (D3.1, D3.7) | `LevelValidation` absent |
| **ADR-0006** | single-instance tuning resources (D6.9) | `src/resources/tuning/` absent |
| **ADR-0001** | an autoload ordered ahead of scene nodes in another branch | `GravityAuthority` absent |
| **ADR-0008** | pause halting `OxygenDrain` via `PROCESS_MODE_INHERIT` + `SceneTree.paused`, no injected pause-state object | `OxygenDrain` absent |

The one Core behaviour already live in `src/` is the bottom-up `_ready()` order that
existing components rely on implicitly.

## Sources

- https://docs.godotengine.org/en/stable/classes/class_node.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
- https://docs.godotengine.org/en/stable/classes/class_area2d.html
- https://docs.godotengine.org/en/stable/classes/class_resource.html
- https://docs.godotengine.org/en/stable/classes/class_scenetree.html
- `main/main.cpp` — `Main::iteration()` loop body
- `scene/main/scene_tree.cpp` — `_process_group()`, `default_process_group`
- `scene/main/node.h`
- https://github.com/godotengine/godot/blob/4.3-stable/scene/resources/packed_scene.cpp
