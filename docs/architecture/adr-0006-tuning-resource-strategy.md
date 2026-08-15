# ADR-0006: Tuning resource strategy

## Status

Proposed

## Date

2026-08-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned 2026-08-13) |
| **Domain** | Core / Scripting — the `Resource` system, `preload`, `@export_range` |
| **Knowledge Risk** | **HIGH** at the project level. No `modules/core.md` reference exists — only `physics-2d.md` and `ui-control.md` — so this domain has no curated snapshot to check against |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` · `breaking-changes.md` · `deprecated-apis.md` · `current-best-practices.md` |
| **Post-Cutoff APIs Used** | **None.** `Resource`, `preload()`, `class_name`, `@export_range` and typed constants all predate the ~4.3 training coverage. `breaking-changes.md` and `deprecated-apis.md` list nothing touching the Resource system across 4.4 → 4.7 |
| **Verification Required** | **T1–T3 discharged** by the engine specialist gate on 2026-08-14; **T4 partially discharged** — see below |

### Engine facts, verified 2026-08-14

Established by the `godot-specialist` gate. **These are ADR-0006's T1–T4; they are
not ADR-0003's E1–E3 nor ADR-0004's L1–L6.**

| ID | Fact | Verdict | Basis |
|---|---|---|---|
| **T1** | A typed constant holding a `preload()`ed custom `Resource` — `const PROP: PropTuning = preload(...)` — is legal GDScript and resolves at script-load time | **VERIFIED TRUE** | `docs/…/static_typing.html` §Custom types — `class_name` types are usable as annotations anywhere. See the F1 caveat below |
| **T2** | `preload()` resolves with **no `SceneTree` involvement whatsoever** | **VERIFIED TRUE — and stronger than the draft claimed** | `best_practices/logic_preferences.html` §"Loading vs. preloading": a preloaded const *"spawns when the Script object loads"*. Resolution is at script-load time and is **categorically independent** of tree or node state, not merely compatible with a null tree |
| **T3** | Two `preload()`s of the same path yield the **same instance**, and that identity survives `reload_current_scene()` | **VERIFIED TRUE** | `Resource` class docs: *"The engine keeps a global cache of all loaded resources, referenced by paths… subsequent loads using its path will return the cached reference."* The cache is engine-global, not scene-scoped |
| **T4** | `@export_range` constrains the inspector but does **not** clamp or reject a value loaded from a hand-edited `.tres` | **VERIFIED TRUE — documentation only, not executed** | The `"or_greater"` / `"or_less"` hints exist precisely because otherwise *"the editor widget will not cap the value"*, and `PropertyHint` is inspector metadata rather than a `set()` validator. **No test was run against the pinned `4.7.1-stable` binary** |

> **T3 caveat:** cache entries are released once all references drop. Immaterial
> here — `Tuning`'s constants hold a reference for the whole process lifetime, so
> the instance can never be evicted and re-created.

> **T4 remains open in practice.** The specialist began building an isolated
> project against the actual `4.7.1-stable` binary to confirm T1–T4 empirically and
> did not finish. Migration Plan step 5 must actually execute before T4 is treated
> as closed. Nothing in the decision *depends* on T4 — it only justifies why D6.4
> is authoring-time-only — but the claim should not be repeated as settled until
> the test runs.

`current-best-practices.md` independently endorses the direction taken here:
*"Resources for data: use Godot Resources to store data independently of nodes.
Prefer `.tres` for serialized game data over raw dictionaries."*

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **None.** ADR-0001, ADR-0002 and ADR-0003 each *name* a tuning resource, but none must be Accepted before this one can be. This ADR supplies a definition those three already assume; it does not consume anything they decide |
| **Enables** | ADR-0003 (`V-PROP-BUDGET`, specified but inert until `PropTuning` exists) · ADR-0008 (oxygen drain — consumes `OxygenTuning`, and inherits the `drain_rate` accessibility question per D6.6) · ADR-0009 (watering interaction — consumes `WateringTuning`) · ADR-0011 (physics props — consumes `PropTuning`) · ADR-0012 (spent jug throw — consumes the three `throw_*` knobs) |
| **Blocks** | The level migration epic's `V-PROP-BUDGET` closure step (ADR-0003 Migration Plan step 8). No epic is blocked in full |
| **Ordering Note** | Deliberately independent. This ADR defines *where tuning values live and how they are reached*; it decides no gameplay behaviour and reads no other ADR's state. It can be accepted before or after ADR-0001–0005 in any order. The one hard coupling runs outward, not inward: `OxygenState._init(capacity, tuning)` was frozen by ADR-0002 before `OxygenTuning` had a definition, so this ADR must satisfy that signature rather than negotiate it |

## Context

### Problem Statement

Three tuning resources — `WateringTuning`, `OxygenTuning`, `PropTuning` — are named
as settled fact across **four documents**: `watering-system.md` §7,
`suit-oxygen.md` §7, `physics-props.md` §7, and `architecture.md`'s Foundation
layer table, which lists "Tuning resources" as a module with status **New**.
`architecture.md` P5 states the principle they serve:

> *Values that vary per instance are `@export`s on the node; values that are
> global feel constants live in `.tres` resources. Neither is hardcoded.*

**Nothing anywhere defines how a consumer obtains one.** Not the class shape, not
the file path, not the reach mechanism, not whether the instance is shared or
per-level, not whether it may be written to at runtime. Three ADRs have already
been written against these resources as though the question were answered:

- **ADR-0001** has `GravityAuthority` — an **autoload** — read
  `prop_tuning.prop_gravity_scale` on **every physics frame while the gravity
  vector is easing**, inside the `PhysicsServer2D.area_set_param` call.
- **ADR-0002** froze `OxygenState._init(capacity: float, tuning: OxygenTuning)`,
  so `LevelRoot` must hold an `OxygenTuning` at construction time.
- **ADR-0003** specifies `V-PROP-BUDGET` reading
  `PropTuning.props_per_level_budget` from `LevelValidation` — a **static, pure
  function** that ADR-0003 requires be *"callable on a scene instantiated but never
  added to the SceneTree"* (E1/E2).

Those three consumers have **incompatible reach**, and that incompatibility — not
taste — is what decides this ADR. An autoload exists before any level does, so it
cannot be handed a resource by a level. A static function with `get_tree() == null`
cannot look up an autoload at all. A level root can do either. Any strategy that
satisfies one of the three by a mechanism the others cannot use leaves the
remaining consumers to invent their own, which is the no-owner condition ADR-0004
was written to end, arriving one layer up.

### The constraint that closes the field

**`LevelValidation` runs with a null tree.** ADR-0003's CI gate instantiates all
eight level scenes and never adds them to the `SceneTree`, because that is what
lets `validate()` be a pure predicate over a `Node`. On that code path
`get_node("/root/Tuning")` is not merely inelegant — it is **unavailable**. This
is the same disqualification that killed `get_nodes_in_group()` for level
discovery (ADR-0003 `group_based_level_discovery`, reason 1), reached by the same
route, and it removes the autoload option before any argument about global state
is needed.

### Constraints

- **No `GravityTuning` may exist.** ADR-0001 decision part 7 keeps `jump_height`,
  `jump_distance_to_peak` and `jump_distance_to_land` as `@export`s on `Player`.
  That was a **user decision made against the standing recommendation on
  2026-08-13 and reaffirmed 2026-08-14**, and it is recorded in the registry as
  `jump_constants_location`. This ADR must not quietly re-open it by creating the
  resource under a general "all tuning lives in `.tres`" rule.
- `OxygenState._init(capacity: float, tuning: OxygenTuning)` is frozen (ADR-0002).
- `GravityAuthority` reads `PropTuning` per physics frame during easing (ADR-0001
  part 4a) — roughly 6–7 consecutive frames per gravity change at 60 FPS.
- `LevelValidation` must reach `PropTuning` with no tree and no side effects
  (ADR-0003).
- `.claude/docs/coding-standards.md`: *"Gameplay values must be data-driven
  (external config), never hardcoded"* and *"dependency injection over singletons"*.
- ADR-0002 `global_level_state_access` bans reaching **state** through an autoload.
  Tuning is not state, so the ban does not apply literally — but the ADR owes an
  explicit answer rather than silence, because the shapes look alike.

### Requirements

- Exactly **one** canonical instance per tuning class, with no path to a second.
- Reachable from a **static context with `get_tree() == null`**.
- Reachable from an **autoload that exists before any level**.
- Reachable from `LevelRoot._ready()` for constructor injection.
- **Zero allocation and no file I/O per frame** — `GravityAuthority` reads during
  easing, inside the 16.6 ms budget.
- The `.tres` path is written down in exactly **one** place in the codebase.
- No `GravityTuning`.

### What this ADR is not about

`architecture.md` P5 draws the line and the GDDs have already applied it. The
**per-instance** knobs are settled and stay on their nodes — they are named here
only so no reader mistakes them for omissions:

| Knob | Stays on | Authority |
|---|---|---|
| `buckets_required`, `water_duration` | `Plant`, per instance | `watering-system.md` §7 |
| `interact_radius` | `Plant`'s `InteractArea2D` | `watering-system.md` §7 |
| `oxygen_capacity` | Level root, per level | `suit-oxygen.md` §7 — the per-level difficulty dial |
| `mass`, `friction`, `bounce`, `linear_damp`, `angular_damp` | Per prop scene | `physics-props.md` §7 — *"variation between a light chair and a heavy table is the point"* |
| `jump_height`, `jump_distance_to_peak`, `jump_distance_to_land` | `Player` | **ADR-0001 part 7 — user decision, do not relocate** |

Every knob this ADR governs is a **global feel constant** by the GDDs' own
classification. That is why no per-level override mechanism is designed: nothing
in the design asks for one.

## Decision

### D6.1 — Three resources, one per system. No combined `GameTuning`

`WateringTuning`, `OxygenTuning` and `PropTuning` are separate `Resource`
subclasses, exactly as the three GDDs name them.

A single combined resource was considered and rejected: it would hand ADR-0008,
ADR-0009 and ADR-0011 one shared surface, making *"which module owns this value"*
un-answerable by inspection — the precise inference `architecture.md` P5 forbids
(*"never inferred from where the value happens to be read"*). Three classes make
ownership structural. It also keeps the ADR-0002 signature honest: `OxygenState`
receives an `OxygenTuning` and is statically incapable of reading a watering knob.

### D6.2 — File layout

| Artefact | Path |
|---|---|
| `class_name WateringTuning` | `src/scripts/tuning/watering_tuning.gd` |
| `class_name OxygenTuning` | `src/scripts/tuning/oxygen_tuning.gd` |
| `class_name PropTuning` | `src/scripts/tuning/prop_tuning.gd` |
| `class_name Tuning` (const holder) | `src/scripts/tuning/tuning.gd` |
| Authored data | `src/resources/tuning/watering_tuning.tres` |
| | `src/resources/tuning/oxygen_tuning.tres` |
| | `src/resources/tuning/prop_tuning.tres` |

> **Deliberate deviation from ADR-0004**, which placed `collision_layers.gd` flat
> in `src/scripts/`. One file is reasonable flat; four related files are a group,
> and `src/scripts/` already holds gameplay node scripts (`plant.gd`, `bucket.gd`,
> `goal.gd`). `src/resources/` likewise already holds unrelated art and theme
> resources (`Industrial.tres`, `Simple_tileset.tres`, `menu_theme.tres`), so
> tuning data gets its own subdirectory rather than joining that pile.

### D6.3 — `class_name Tuning` is the single reach. Consumers never load a path

```gdscript
class_name Tuning

## Canonical tuning instances. The ONLY place a tuning .tres path is written.
## Reached as Tuning.PROP / Tuning.OXYGEN / Tuning.WATERING.
##
## preload() resolves when this SCRIPT loads, which is independent of the
## SceneTree entirely — not merely tolerant of a null one. That is what lets
## LevelValidation (ADR-0003, null tree) and GravityAuthority (autoload,
## pre-level) share one mechanism. See ADR-0006 D6.3 and T2.

const WATERING: WateringTuning = preload("res://src/resources/tuning/watering_tuning.tres")
const OXYGEN:   OxygenTuning   = preload("res://src/resources/tuning/oxygen_tuning.tres")
const PROP:     PropTuning     = preload("res://src/resources/tuning/prop_tuning.tres")
```

Consumers read through `Tuning` and never name a `.tres` path themselves:

```gdscript
# GravityAuthority (autoload, ADR-0001 part 4) — during easing, every frame
PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY,
        descent_magnitude() * Tuning.PROP.prop_gravity_scale)

# LevelValidation (static, null tree, ADR-0003 V-PROP-BUDGET)
if _count_props(level) > Tuning.PROP.props_per_level_budget:
    findings.append("V-PROP-BUDGET ...")

# LevelRoot._ready() (ADR-0002 init step)
_oxygen_state = OxygenState.new(oxygen_capacity, Tuning.OXYGEN)
```

**This is the same pattern as ADR-0004's `CollisionLayers`**, and for the same
reason: a constant table that names an invariant once so no author has to
remember it. `Tuning` registers nothing and has no behaviour — it holds three
constants and nothing else. It is **not** an autoload and must never become one;
`preload` already gives it universal reach, and registering it would hand it
exactly the tree dependency D6.3 exists to avoid.

**Why `preload` and not `load`:** `preload` resolves at parse time, so a missing
or renamed `.tres` is a **script parse error at startup**, not a null dereference
on the first gravity flip. The failure is loud, immediate, and impossible to ship
past — consistent with `architecture.md` P4.

**Why this reaches `LevelValidation` at all.** The verified basis is T2:
`preload` resolves *when the script object loads*, which does not consult the
`SceneTree` in any way. It is worth stating precisely, because the weaker
framing — "it happens to work with a null tree" — invites a future author to
assume some tree-dependent alternative would also be fine. It would not be. This
is also a **different mechanism from ADR-0003's E1/E2**, which concern `@export`
values surviving `PackedScene.instantiate()` without `_ready()`. D6.3 does not
depend on E1/E2; the two facts are independent and both hold.

**No autoload parse-order hazard.** `GravityAuthority` is an autoload with no
`class_name`, and it reads `Tuning`, a `class_name` script that is not an
autoload. Verified safe: `class_name` global registration happens at project load
**before** any autoload is instantiated, and `tuning.gd` itself only loads on
first reference — the first easing frame, long after every autoload exists.

### D6.4 — Every knob is `@export_range`, using the GDD-documented range verbatim

```gdscript
class_name WateringTuning extends Resource
## Global watering feel constants (watering-system.md §7).
## Per-plant knobs (buckets_required, water_duration) are NOT here — they are
## exported on Plant, because per-instance variation is the level design
## vocabulary. See ADR-0006 D6.1.

@export_range(0.4, 0.9)   var carry_speed_multiplier: float = 0.6
@export_range(60.0, 200.0) var throw_arc_height: float = 120.0
@export_range(0.4, 0.8)   var throw_duration: float = 0.6
@export_range(0.0, 90.0)  var throw_angle_spread: float = 45.0
```

```gdscript
class_name OxygenTuning extends Resource
## Global oxygen constants (suit-oxygen.md §7).
## oxygen_capacity is NOT here — it is the per-level difficulty dial, exported
## on the level root and derived from O_level (suit-oxygen.md R6).

@export_range(0.3, 0.6) var margin: float = 0.4
@export_range(0.5, 1.0) var drain_rate: float = 1.0
@export_range(0.0, 1.0) var threshold_caution: float = 0.50
@export_range(0.0, 1.0) var threshold_warning: float = 0.25
@export_range(0.0, 1.0) var threshold_critical: float = 0.10
```

```gdscript
class_name PropTuning extends Resource
## Global prop constants (physics-props.md §7).
## mass, friction, bounce and damping are NOT here — they are per-prop scene
## exports, because variation between a light chair and a heavy table is the point.

@export_range(0.8, 1.2)       var prop_gravity_scale: float = 1.0
@export_range(1000.0, 4000.0) var prop_max_speed: float = 2000.0
@export_range(10, 80)         var props_per_level_budget: int = 40
```

Defaults are the GDD defaults, unchanged. Ranges are the GDD "safe range" columns,
unchanged. `threshold_*` have no GDD range and take `0.0–1.0`, the only range a
fraction can have.

**`@export_range` is an authoring-time constraint only** (T4). It shapes the
inspector; it does not validate a value typed into the `.tres` by hand. This is
accepted deliberately rather than escalated to a runtime check: adding a seventh
rule to `LevelValidation` would break ADR-0003 D3.3's frozen six-rule set, and
the failure mode here is mild and self-announcing — `prop_gravity_scale` off 1.0
desynchronises props from the player's fall, which is visible in the first
second of play, not silent like the failures ADR-0003 and ADR-0005 defend against.

### D6.5 — Tuning resources are read-only at runtime

**No code may write to a tuning resource property, and no code may call
`.duplicate()` on one to obtain a mutable copy.** Recorded as a forbidden pattern.

The reason is engine mechanics, not style. Godot caches resources **by path**, so
every `preload` of `prop_tuning.tres` yields the *same object* (T3). A single
runtime assignment therefore:

1. changes the value for **every consumer at once**, including consumers in other
   systems that never asked;
2. **survives level transitions**, because the cache outlives
   `reload_current_scene()` — the same autoload-shaped hazard ADR-0001 part 6 had
   to close for gravity, arriving through a different door;
3. can be **written back to disk** if it happens in the editor or a tool script,
   silently editing the authored source of truth.

This is the same class of guarantee as ADR-0004's
`runtime_collision_mask_mutation` — and the same honest weakness applies: it is
enforced by review and grep, **not by structure**. GDScript has no `readonly`
resource. A CI grep asserting no file assigns to a `Tuning.*` property would make
it structural; recommended in *Validation Criteria*, left to the epic.

### D6.6 — The `drain_rate` accessibility override is ADR-0008's, and is named here

`suit-oxygen.md` §7 documents `drain_rate` as an **"Accessibility hook only"**,
which implies a settings menu that changes it while the game runs. D6.5 forbids
exactly that write.

The conflict is resolved by separating the two concepts rather than weakening
either: **`OxygenTuning.drain_rate` is the authored design default; a player-facing
accessibility setting is user data, not design data, and belongs to a settings
system that does not exist yet.** `OxygenDrain` will read an effective rate
composed from both. Specifying that composition — where user settings persist,
whether the multiplier stacks or replaces, and whether it may change mid-level —
is assigned to **ADR-0008 (oxygen drain and the shared death path)**, which owns
`OxygenDrain`.

This is stated so the question has a named owner rather than floating. It is
**not** a licence for ADR-0008 to write to `OxygenTuning`; D6.5 stands.

### D6.7 — `GravityTuning` does not exist and must not be created

Restated as a standing ban, because ADR-0006 is the document a future author will
read when asking *"where do tuning values live?"* — and the answer here would
otherwise imply that the jump constants belong in a resource too. They do not.
ADR-0001 part 7 keeps them on `Player` by explicit user decision, and
`gravity.md` §5's initialisation-order edge case **stays live in the GDD** as the
documented price. Creating `GravityTuning` under this ADR's general rule would
silently overturn a decision made twice and reverse a documented trade-off.

Changing it requires superseding ADR-0001's `jump_constants_location`, not
extending ADR-0006.

### D6.8 — This ADR unblocks `V-PROP-BUDGET`; it does not add a rule

ADR-0003's `V-PROP-BUDGET` is specified and inert, gated solely on
`PropTuning.props_per_level_budget` existing. D6.3 supplies it in a form callable
from a static context with a null tree, which is what ADR-0003's Ordering Note
requires. **ADR-0003's six-rule set is unchanged** — no seventh rule is added
here, and D3.3 stays frozen.

### D6.9 — `resource_local_to_scene` must remain `false` on all three resources

*Source: engine specialist review 2026-08-14 (F4). Not anticipated by the draft.*

Godot's `Resource.resource_local_to_scene` flag, when set `true`, makes the engine
hand **each instantiating scene its own copy** of the resource. It is a legitimate
and useful feature — it is how you give two instances of the same scene
independent materials — and it is a single checkbox in the inspector.

On a tuning resource it would **silently destroy the guarantee this entire ADR is
built on**. T3's cache identity would no longer hold: `Tuning.PROP` read from one
level and `Tuning.PROP` read from another would be different objects, the
"exactly one instance project-wide" guarantee would quietly become false, and
D6.5's read-only reasoning — which rests on there being a single shared object —
would no longer describe reality. Nothing would error. Nothing would log.

**All three `.tres` files keep `resource_local_to_scene = false`** (the default).
This is stated rather than assumed precisely because it is a default: defaults are
what get changed by an author exploring the inspector, and this one has no visible
consequence at the moment it is changed.

> This is the same hazard shape as ADR-0005's
> `process_thread_group_split_in_frame_chain` — a legitimate engine feature that
> is inert today, costs one inspector click, and silently detaches a node or
> resource from a contract with no compile error and no symptom until a specific
> case fails.

### Architecture Diagram

```
              src/resources/tuning/*.tres        ← authored data (inspector)
                          │
                          │  preload()  — parse time, no tree, no _ready()
                          ▼
                  ┌───────────────┐
                  │    Tuning     │   const WATERING / OXYGEN / PROP
                  │  (const only) │   the ONLY place a .tres path is written
                  └───────┬───────┘
        ┌─────────────────┼──────────────────┬───────────────────┐
        ▼                 ▼                  ▼                   ▼
 GravityAuthority   LevelValidation      LevelRoot            PropBody
   (autoload)       (static, NULL tree)  (Node2D)           (RigidBody2D)
        │                 │                  │                   │
 Tuning.PROP        Tuning.PROP      OxygenState.new(       Tuning.PROP
 .prop_gravity_     .props_per_        capacity,            .prop_max_speed
  scale              level_budget      Tuning.OXYGEN)         (ADR-0011)
   ADR-0001 §4       ADR-0003          ADR-0002
   per easing frame  V-PROP-BUDGET     init step

 ── all four reach the SAME cached instance (path cache). Read-only: D6.5.
```

### Key Interfaces

```gdscript
class_name Tuning
const WATERING: WateringTuning = preload("res://src/resources/tuning/watering_tuning.tres")
const OXYGEN:   OxygenTuning   = preload("res://src/resources/tuning/oxygen_tuning.tres")
const PROP:     PropTuning     = preload("res://src/resources/tuning/prop_tuning.tres")
```

**Callers must:** reach tuning only through `Tuning`. **Callers must never:**
call `load()`/`preload()` on a tuning `.tres`, assign to a tuning property,
`duplicate()` a tuning resource, set `resource_local_to_scene = true` on one,
register `Tuning` as an autoload, or add a `GravityTuning`.

**Guarantees:** exactly one instance per tuning class, project-wide (T3, and D6.9
is what keeps it true) · resolves with **no `SceneTree` involvement at all** (T2) ·
zero per-frame allocation and zero file I/O after parse · a missing or renamed
`.tres` fails at **parse time**, not at first use.

## Alternatives Considered

### Alternative 1: `@export var tuning: PropTuning` on each consumer, authored per scene

- **Description**: Each consumer node exports a tuning slot; the level author
  drags the `.tres` in. Matches ADR-0002's injection style.
- **Pros**: Consistent with the coding standard's "dependency injection over
  singletons". Allows per-level tuning variants. Visible in the inspector.
- **Cons**: **Does not work for two of the three consumers.** `LevelValidation`
  is static with no node to export from, and `GravityAuthority` is an autoload
  that exists before any level author can wire it.
- **Rejection Reason**: It cannot satisfy the consumer set, so it would have to
  be *combined* with another mechanism — leaving two ways to reach tuning and no
  rule for which. Worse, it makes one invariant an authoring chore repeated
  across 8 levels × N consumers: **exactly the drift shape ADR-0004 catalogued as
  defect 5**, where terrain's collision layer is configured in five independent
  places. Nothing in the GDDs asks for per-level tuning variants, so the
  flexibility buys nothing and costs an authoring surface that can silently go
  wrong.

### Alternative 2: A `Tuning` autoload holding the three resources

- **Description**: Register `Tuning` in `project.godot` autoloads; consumers use
  `Tuning.PROP` via the global.
- **Pros**: Familiar. Single instance. No `preload` in consumer scripts.
- **Cons**: **Unavailable to `LevelValidation`.** Autoload access is
  `get_node("/root/Tuning")`, and ADR-0003's CI gate never adds the scene to a
  tree, so `get_tree()` is null and the lookup fails on the exact path
  `V-PROP-BUDGET` must run on. It also adds a second autoload to a project whose
  coding standards prefer injection, and invites the shape ADR-0002 banned as
  `global_level_state_access`.
- **Rejection Reason**: Disqualified on the same technical ground as
  `group_based_level_discovery` (ADR-0003) — not inadvisable, **unavailable** on a
  required code path. The `preload` const gives every benefit of an autoload with
  none of the tree dependency, so there is nothing left to trade.

### Alternative 3: `ProjectSettings` entries

- **Description**: Store the ten knobs as custom `ProjectSettings` keys, read via
  `ProjectSettings.get_setting()`.
- **Pros**: Genuinely tree-free and headless-safe — independently verified as
  ADR-0004 L6. Single source. No new files.
- **Cons**: Untyped `Variant` returns, so static typing is lost at every call
  site. No grouping, no ranges, no inspector affordance beyond a flat settings
  list. A string key typo is a runtime `null`, not a parse error. Contradicts
  `.claude/docs/coding-standards.md` ("gameplay values must be data-driven
  (external config)") in spirit and `current-best-practices.md` ("prefer `.tres`
  for serialized game data over raw dictionaries") by name.
- **Rejection Reason**: It solves the reach problem and loses everything else.
  Tuning knobs are read by designers, and `.tres` in the inspector with named
  ranges is the affordance the GDDs' §7 tables assume.

### Alternative 4: `preload()` const declared on each consumer individually

- **Description**: No `Tuning` class; each consumer declares its own
  `const PROP_TUNING := preload("res://.../prop_tuning.tres")`.
- **Pros**: Fewest files. Same parse-time, tree-free properties as the chosen
  option.
- **Cons**: The `.tres` path is repeated in every consumer — `GravityAuthority`,
  `LevelValidation`, `PropBody`, and every future reader. Moving or renaming a
  resource becomes a multi-file edit with no compiler help until each file is
  parsed.
- **Rejection Reason**: **Same defect as Alternative 1, reached from the other
  direction** — one invariant written down in N places. ADR-0004 rejected exactly
  this for collision layers and created `CollisionLayers` instead; `Tuning` is
  that decision applied consistently. The cost of the chosen option over this one
  is a single 6-line file.

### Alternative 5: A single combined `GameTuning` resource

- **Description**: One resource, one `.tres`, all ten knobs.
- **Pros**: One file. One reach. Simplest possible statement.
- **Cons**: Destroys ownership boundaries. `OxygenState` would receive an object
  carrying watering and prop knobs, contradicting ADR-0002's frozen
  `_init(capacity, tuning: OxygenTuning)` signature and making
  `architecture.md` P5's *"which module owns a value is an architectural
  decision... never inferred"* impossible to honour by inspection.
- **Rejection Reason**: The three GDDs each name their own resource, and the type
  system is the cheapest possible enforcement of the boundary. Rejected on
  ownership, not on file count.

### Alternative 6: Static factory — `PropTuning.get_default()`

- **Description**: Each resource class exposes
  `static func get_default() -> PropTuning` wrapping its own `load()`.
- **Pros**: Path lives with the class that owns it. No separate holder class.
- **Cons**: `load()` at call time rather than `preload()` at parse time, so a
  missing file is a runtime null on first use rather than a startup parse error —
  losing the loud-failure property. Adds a function call on a per-frame path
  (`GravityAuthority` during easing). Relies on static-member behaviour that is
  newer GDScript surface area and would itself need verification.
- **Rejection Reason**: Strictly more machinery than a constant, for a weaker
  failure mode. Considered seriously and set aside on the parse-time-failure
  property alone.

## Consequences

### Positive

- **The three incompatible consumers share one mechanism.** An autoload, a
  static function with a null tree, and a level root all reach tuning the same
  way, so no consumer has to invent a private route.
- **`V-PROP-BUDGET` is unblocked**, closing the last gap in ADR-0003's rule set
  and the last item on ADR-0003's Migration Plan.
- **One `.tres` path per resource, project-wide.** Renaming or moving a tuning
  file is a one-line edit in `tuning.gd`.
- **A missing tuning file fails at parse time**, before the main scene loads —
  consistent with `architecture.md` P4's fail-loud-at-load principle.
- **Zero runtime cost.** `preload` resolves once at parse; the per-frame read in
  `GravityAuthority` is a property access on an already-resident object, with no
  allocation and no I/O.
- **Static typing survives**, unlike the `ProjectSettings` alternative — every
  knob is a typed property with a declared range.
- **The `drain_rate` accessibility question gains a named owner** (ADR-0008)
  instead of floating, continuing the practice established in ADR-0003 and
  ADR-0004.

### Negative

- **`Tuning` is a globally reachable object in a project whose coding standards
  prefer injection.** The tension is real and is recorded rather than argued
  away. The mitigation is that it is *immutable data*, not state and not
  behaviour: nothing can be written to it (D6.5), it holds no runtime value, and
  the object it hands back is the same one on every call. ADR-0002's
  `global_level_state_access` ban targets **mutable level state whose lifetime
  must track a level**; tuning has neither property.
- **No per-level tuning variation is possible** without amending this ADR. That
  is intended — the GDDs classify every knob here as global — but it is a door
  this ADR closes.
- **D6.5 is enforced by review and grep, not by structure.** Identical honest
  weakness to ADR-0004's `runtime_collision_mask_mutation`. GDScript offers no
  immutable resource; a single assignment would void the guarantee invisibly.
- **`preload` creates a hard parse-time dependency on three file paths.** Moving
  a `.tres` without updating `tuning.gd` breaks project startup, not just the
  feature. Loud, but total.
- **Four new files and a new directory** for ten values that do not exist yet.
  Justified by three ADRs already depending on them, but it is real weight added
  ahead of the code that uses it.

### Risks

- **A future author adds `GravityTuning`** under this ADR's general rule,
  silently overturning ADR-0001 part 7 and a decision the user made twice.
  *Mitigation*: D6.7 states the ban inside this document, where that author will
  be reading; registry entry `jump_constants_location` remains the authority.
- **A settings menu writes `Tuning.OXYGEN.drain_rate` directly** — the most
  likely D6.5 violation, because `suit-oxygen.md` §7 invites it in prose.
  *Mitigation*: D6.6 assigns the composition to ADR-0008 by name and states that
  the ban still holds; the forbidden-pattern entry names this case explicitly.
- **A latent GDScript type-resolution bug of exactly this shape has existed
  before.** `godotengine/godot#73615` — *"Type casting of certain resources fails
  unexpectedly"* — describes a preloaded `.tres` whose script carries a
  `class_name`, referenced through a multi-file type-annotation chain, failing
  `is` / `as` checks. It presented as a cyclic-dependency problem and was not one.
  `Tuning` is structurally close: three cross-referenced `class_name` Resource
  types reached through typed constants. A maintainer confirmed on **2026-07-25**
  that it reproduces on `4.0.stable` and **does not reproduce on `4.7.1.stable`** —
  the project's exact pinned build. *Mitigation*: not a live defect, but V1 is
  strengthened to assert **type identity** (`Tuning.PROP is PropTuning`) rather
  than mere non-nullity, so a regression in this bug class is caught by the suite
  rather than by a confusing failure at a call site. If it ever does bite, the
  fallback is an untyped `const PROP = preload(...)`, which costs only the
  annotation on the constant; the resource's own properties stay typed and no part
  of the decision depends on it.
- **`resource_local_to_scene` is set to `true` by an author exploring the
  inspector**, silently dissolving the single-instance guarantee with no error and
  no symptom. *Mitigation*: D6.9 states the requirement explicitly and V9 asserts
  it. Specialist finding F4 — the draft had not anticipated this.
- **T4 has not been executed.** The claim that `@export_range` does not clamp a
  hand-edited `.tres` value rests on documentation wording alone. *Mitigation*:
  Migration Plan step 5 runs it against the pinned binary. Low stakes — T4 only
  justifies why D6.4 is authoring-time-only; if it turns out values *are* clamped
  at load, the ADR gets stronger, not weaker.
- **An editor tool script mutates and saves a tuning `.tres`**, silently editing
  authored values in version control. *Mitigation*: covered by D6.5; the
  recommended CI grep would catch it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `physics-props.md` | §7 — `prop_gravity_scale`, `prop_max_speed`, `props_per_level_budget` live in a `PropTuning` resource "per the data-driven rule" | D6.1/D6.4 define `PropTuning` with all three knobs at their GDD defaults and ranges; D6.3 makes it reachable from `GravityAuthority` (autoload) and `LevelValidation` (null tree) |
| `physics-props.md` | R8 / §5 — prop count is budgeted and exceeding it is "flagged at load" | D6.8 unblocks ADR-0003's `V-PROP-BUDGET`, which is the flag. No seventh validation rule is added |
| `physics-props.md` | §7 — per-prop `mass`/`damping`/`friction` stay on the prop because variation is the point | Explicitly excluded from `PropTuning` (D6.1 and the *What this ADR is not about* table) |
| `suit-oxygen.md` | §7 — `margin`, `drain_rate`, `threshold_*` live in an `OxygenTuning` resource | D6.4 defines all five knobs at GDD defaults; D6.3 supplies the instance `LevelRoot` passes to the `OxygenState._init(capacity, tuning)` signature ADR-0002 froze |
| `suit-oxygen.md` | §7 — `drain_rate` is an "accessibility hook only"; §7 — `oxygen_capacity` is the per-level dial, derived not guessed | D6.6 assigns the accessibility composition to ADR-0008 and keeps the ban on writes; `oxygen_capacity` is deliberately kept out of the resource as a level-root export |
| `watering-system.md` | §7 — `carry_speed_multiplier`, `throw_arc_height`, `throw_duration`, `throw_angle_spread` in a `WateringTuning` `.tres`, "tunable without touching code" | D6.4 defines all four at GDD defaults and ranges; `.tres` authoring in the inspector satisfies "without touching code" |
| `watering-system.md` | §7 Placement — per-plant `buckets_required` / `water_duration` stay on `Plant` because "that variation is the level design vocabulary" | Explicitly excluded from `WateringTuning` (D6.1) |
| `watering-system.md` | §7 Escalation rule — `k` is "a global feel constant — set once, then left alone" | D6.5's read-only stance makes "set once, then left alone" structural rather than advisory |
| `gravity.md` | §7 — jump constants are tuning knobs, but ADR-0001 part 7 keeps them on `Player` | D6.7 restates the ban on `GravityTuning` so this ADR does not silently relocate them |

## Performance Implications

- **CPU**: Effectively zero. `preload` resolves at parse time. The only per-frame
  read is `Tuning.PROP.prop_gravity_scale` in `GravityAuthority` during easing
  (~6–7 frames per gravity change at 60 FPS) — a single property access on a
  resident object, no allocation, no I/O, no lookup. `LevelValidation`'s read
  happens once per level load.
- **Memory**: Three small `Resource` instances, ten scalar properties in total,
  resident for the process lifetime. Immaterial against the 512 MB ceiling.
- **Load Time**: Three `.tres` files parsed at startup instead of on first use.
  Sub-millisecond; the trade is deliberate — it is what converts a missing file
  into a startup parse error.
- **Network**: N/A.

## Migration Plan

**Greenfield.** A grep across `src/` for `carry_speed_multiplier`,
`throw_arc_height`, `throw_duration`, `throw_angle_spread`, `drain_rate`,
`margin`, `threshold_`, `prop_gravity_scale`, `prop_max_speed` and
`props_per_level_budget` returns **zero matches**. None of these values is
hardcoded anywhere today, because none of the three systems is built. There is no
migration — only creation. `src/resources/` holds `Industrial.tres`,
`Simple_tileset.tres` and `menu_theme.tres`, none of them tuning.

1. Create `src/scripts/tuning/` and `src/resources/tuning/`.
2. Create the three `Resource` scripts with the D6.4 contracts verbatim,
   including the doc comments that state which knobs are deliberately absent.
3. Create the three `.tres` files with the GDD defaults. Verify each opens in the
   inspector, that `@export_range` constrains the sliders, and that
   **`resource_local_to_scene` is `false`** on all three (D6.9).
4. Create `src/scripts/tuning/tuning.gd` with the D6.3 contract verbatim.
5. **Run V1–V4 and V9** as a headless GdUnit4 test before any consumer depends on
   this. Two are load-bearing: **V2** (assert resolution inside a test that
   instantiates a level scene and never adds it to the tree) and **V1** (assert
   `is PropTuning`, not just non-null — see the GH#73615 risk).
   **Execute T4 here as well** — it is the one engine claim the specialist gate
   could not discharge empirically, and this is where it gets closed.
6. **Close `V-PROP-BUDGET`** in `LevelValidation` (ADR-0003 Migration Plan
   step 8) and remove the "BLOCKED on ADR-0006" note from ADR-0003's registry
   entry and Ordering Note.
7. Consumers adopt `Tuning.*` as ADR-0008 / ADR-0009 / ADR-0011 / ADR-0012 land.
   No consumer work is owed by this ADR.

> **`gdUnit4` treats GDScript warnings as errors at test discovery** — one warning
> fails the *entire* suite. The four new scripts must be warning-clean, including
> the unused-`class_name` and shadowing checks. Same caveat that applied to
> `collision_layers.gd` (ADR-0004).

## Validation Criteria

| # | Criterion | Evidence |
|---|---|---|
| V1 | **`Tuning.PROP is PropTuning`** — and the same for `OXYGEN`/`WATERING`. Assert **type identity**, not merely non-null | Unit test. Strengthened per specialist F1 / GH#73615 — the bug class this guards against presents as a *type* failure on a non-null object |
| V2 | **`Tuning.PROP` resolves inside a static call on a scene instantiated but never added to the tree** — the ADR-0003 path | Headless test, `get_tree() == null` (T2) |
| V3 | Two independent reads of `Tuning.PROP` return the same instance | Unit test (T3) |
| V4 | Every knob's default matches its GDD §7 default exactly | Unit test asserting all ten values |
| V5 | `V-PROP-BUDGET` returns a finding when a level exceeds `props_per_level_budget`, and none when it does not | ADR-0003's validation suite |
| V9 | `resource_local_to_scene` is `false` on all three resources | Unit test (D6.9). Cheap to assert, and the failure it catches is otherwise invisible |
| V6 | No file outside `src/scripts/tuning/` contains a `res://src/resources/tuning/` path literal | **Recommended CI grep** — makes D6.3 structural |
| V7 | No file assigns to a property of `Tuning.WATERING` / `.OXYGEN` / `.PROP`, and none calls `.duplicate()` on one | **Recommended CI grep** — makes D6.5 structural. This is the weak link; see D6.5 |
| V8 | No `GravityTuning` class or `gravity_tuning.tres` exists anywhere | **Recommended CI grep** — guards ADR-0001 part 7 |

> V1–V5 and V9 are asserted tests. V6, V7 and V8 are **recommended, not asserted** —
> like ADR-0004's grep recommendation they are left to the migration epic rather
> than blocking this ADR, and are recorded here so the debt stays visible rather
> than forgotten.

## Related Decisions

- **ADR-0001** — Gravity ownership and global broadcast. Part 4 consumes
  `Tuning.PROP.prop_gravity_scale` per easing frame; part 7 and Alternative 4 are
  the reason `GravityTuning` is absent (D6.7).
- **ADR-0002** — Level state ownership. Froze
  `OxygenState._init(capacity: float, tuning: OxygenTuning)` before `OxygenTuning`
  had a definition; D6.3 supplies the instance. `global_level_state_access` is
  discussed and distinguished under *Consequences → Negative*.
- **ADR-0003** — Level load validation contract. `V-PROP-BUDGET` is unblocked by
  D6.8; its null-tree requirement (E1/E2) is the constraint that decided D6.3.
- **ADR-0004** — Collision layer allocation. `Tuning` is the same const-table
  pattern as `CollisionLayers`, and D6.5 is the same honest weakness as
  `runtime_collision_mask_mutation`.
- **ADR-0008** — Oxygen drain and the shared death path. Owns the `drain_rate`
  accessibility composition assigned by D6.6.
- **ADR-0011** — Physics props implementation. Consumes `prop_max_speed` and the
  budget; owns per-prop `mass`/`damping`.
- **ADR-0012** — Spent jug throw and lifetime. Consumes the three `throw_*` knobs.
- `architecture.md` **P5** — "Tuning lives in data; ownership lives in code." This
  ADR is P5's implementation.
- `.claude/docs/coding-standards.md` — "Gameplay values must be data-driven
  (external config), never hardcoded."
