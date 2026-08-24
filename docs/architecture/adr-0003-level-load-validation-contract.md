# ADR-0003: Level load validation contract

## Status

**Accepted** — 2026-08-15

## Date

2026-08-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (project runs 4.7.1-stable) |
| **Domain** | Core (SceneTree traversal, node instantiation lifecycle, error reporting), with a GdUnit4 test-harness dependency |
| **Knowledge Risk** | **LOW for this ADR.** `VERSION.md` rates the project HIGH overall on the strength of post-4.3 physics and rendering churn, none of which this decision touches. The standing gap is real — **this repo has no Core engine reference**, `modules/` holding only `physics-2d.md` and `ui-control.md` — but the three Core claims this decision actually rests on were verified against engine source and live docs on 2026-08-14. See *Engine facts this decision rests on*. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `docs/architecture/architecture-review-2026-08-14.md`, and the engine specialist review of 2026-08-14 (F1–F11) |
| **Post-Cutoff APIs Used** | **None.** `PackedScene.instantiate()`, `Node.get_children()`, `Node.get_node_or_null()`, `Node.find_children()`, `push_error()` and `OS.is_debug_build()` all predate 4.0, are absent from `deprecated-apis.md`, and are unchanged in `breaking-changes.md` (which records no Core-domain entry across 4.4 → 4.7). |
| **Verification Required** | **None outstanding.** The three load-bearing Core claims (E1–E3 below) were each verified on 2026-08-14 rather than asserted from training data. One honest caveat on the verification method is recorded with them. |

### Engine facts this decision rests on

All three were verified on 2026-08-14 during the engine specialist review, against
the live Godot class reference and against `scene/resources/packed_scene.cpp`.
Neither is a training-data recollection. **Do not re-search these.**

**E1 — `PackedScene.instantiate()` populates `@export` values without running
`_ready()`.** In `SceneState::instantiate()`, ordinary exported properties are set
via a `node->set(...)` loop that completes before the function returns. `_ready()`
is dispatched by `NOTIFICATION_READY`, which fires only on tree entry, and
`instantiate()` never enters a tree. **This is what makes D3.7's CI test possible**
— each level can be instantiated, validated and freed without a `SceneTree` and
without firing a single gameplay `_ready()`.

- <https://github.com/godotengine/godot/blob/4.3-stable/scene/resources/packed_scene.cpp>

**E2 — `@export`ed node references resolve at instantiation, not at tree entry.**
The `node_paths=PackedStringArray("player", "goal", "bucket")` mechanism seen at
`level_01.tscn:21` is collected into a `deferred_node_paths` list during the same
loop, then resolved with `base->get_node_or_null(path)` and written back — after
the subtree is built, but still *inside* `instantiate()`. `get_node_or_null()` is
local parent/child traversal and does not require `SceneTree` membership. So
`V-WIRING` is CI-testable alongside the other five rules.

- *Boundary condition:* resolution is skipped in favour of storing the raw
  `NodePath` when `get_scene_instance_load_placeholder()` is set outside the
  editor. No scene in this project uses instance load placeholders. If one ever
  does, `V-WIRING` silently degrades on that scene.

**E3 — `push_error()` reaches disk in an exported release build.** It is never
compiled out (unlike `assert()`), always writing to stderr. Beyond that,
`debug/file_logging/enable_file_logging` defaults to `false` but the desktop
override `…enable_file_logging.pc` defaults to **`true`**, routing error output to
`user://logs/godot.log`. This project's `project.godot` overrides neither, and
`technical-preferences.md` pins the target to PC — so the default is live in the
shipped build. This is what D3.6 stands on.

- <https://docs.godotengine.org/en/stable/classes/class_@globalscope.html>
- <https://docs.godotengine.org/en/stable/classes/class_projectsettings.html>

> **Caveat on method, recorded plainly.** No literal `4.7` git tag is fetchable
> from the public repository, so E1 and E2 rest on 4.3-stable engine source plus
> the documented-unchanged 4.4 → 4.7 changelogs, not on literal 4.7 source. E3
> rests on the live (4.7-current) class reference. This is stated rather than
> presented as stronger than it is — the same discipline the 2026-08-14 review
> imposed after finding three ADRs had written "Verification Required: None" over
> unchecked Core claims, one of which was wrong.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** — `V-GRAV-EXPORT` validates the `default_gravity_direction` / `default_gravity_multiplier` exports that ADR-0001 places on `LevelRoot`, and ADR-0001 explicitly delegates that check here. **ADR-0002** — this ADR sits inside the `LevelRoot._ready()` sequence ADR-0002 owns, and `V-WIRING` is the check ADR-0002 asked for by name. |
| **Enables** | None. No other ADR waits on this one. |
| **Blocks** | The **level migration epic** (`architecture.md` QQ-03 — all 8 levels need `default_gravity_*`, bucket-economy conversion and a derived `oxygen_capacity`). Also blocks test evidence for `watering-system.md` AC7 and `suit-oxygen.md` AC7, which are typed **Logic** and therefore BLOCKING under `.claude/docs/coding-standards.md`. |
| **Ordering Note** | **`V-PROP-BUDGET` cannot be implemented until ADR-0006 exists.** It reads `props_per_level_budget`, which `physics-props.md` §7 places in a `PropTuning` resource that ADR-0006 owns. The rule is specified here and implemented when `PropTuning` lands; the other five rules have no such gate. This ADR is otherwise independent of ADR-0004 and ADR-0006 and can be accepted before either. |

## Context

### Problem Statement

Every level in this game carries authoring contracts that no amount of careful
coding can enforce, because they are properties of the *level data*, not of the
code that reads it. `watering-system.md` R8 requires
`buckets_total == Σ buckets_required` and states outright that the dangerous
failure mode is the silent one: a level where the airlock can never open, with no
feedback to the player and none to the author. `suit-oxygen.md` §5 requires a
non-positive `oxygen_capacity` to be reported at load. ADR-0001 requires each level
to carry `default_gravity_*` exports or a restart inherits the gravity the player
died under. `physics-props.md` §5 requires an over-budget prop count to be flagged
at load.

`architecture.md` P4 states the principle — *level correctness fails loudly at
load, never silently at play* — and names `LevelValidation` as the mechanism, but
leaves the contract unspecified: which rules, discovered how, run when, reported
how, and testable by what means.

Three things make this urgent rather than tidy.

First, **the check does not exist and all 8 levels currently violate it.** They use
the pre-GDD one-bucket model (`level_01.tscn:21` exports a single `bucket`), none
carry `default_gravity_*`, and no `O_level` has been computed for any of them.

Second, **the migration that fixes that is 8 levels × 3 hand-edits**, and it is the
single most likely source of exactly the authoring breakage this rule set exists to
catch.

Third, **two BLOCKING acceptance criteria have no testable surface without this
decision.** `watering-system.md` AC7 and `suit-oxygen.md` AC7 both read *"Level
load logs an error when …"* and are typed **Logic**, which
`.claude/docs/coding-standards.md` makes a blocking automated-test gate. A
`push_error` side-effect is not cleanly assertable. Something must return a value.

### Constraints

- **Runs before state exists.** ADR-0002 made `OxygenState` un-constructible at
  `capacity <= 0`. Validation therefore cannot read constructed state objects — see
  the ordering defect in D3.1.
- **Runs before `bind()`.** ADR-0002's `state_access_before_bind` forbids touching
  injected state early, and the bind step has not happened yet at validation time.
- **No global access.** ADR-0002's `global_level_state_access` forbids reaching
  level state through an autoload or service locator. `validate()` takes the level
  as a parameter.
- **`_ready()` is bottom-up.** `LevelRoot._ready()` runs after every child's, so
  child nodes are constructed and their `@export`s populated by the time validation
  runs. `@onready` fields of `LevelRoot` itself are available; `@onready` fields of
  a scene merely *instantiated* and never added to the tree are not (E1).
- **Must be unit-testable without a running game.** Per the coding standards,
  public methods are testable and gameplay values are data-driven.

### Requirements

- Report **every** breach in one pass, not the first — a level can violate the
  bucket contract and the oxygen contract simultaneously, and one-at-a-time
  reporting costs a full run per defect.
- Return a value with **stable identity** that a test can assert on without
  depending on human-readable wording.
- Discovery must not itself be silently incomplete. A validation pass that can miss
  a node because an author forgot a bookkeeping step is worse than no validation,
  because it reports "clean" over a broken level.
- Cost must be negligible at load and zero per frame.
- Must not contradict any stance registered in `docs/registry/architecture.yaml`.

## Decision

### D3.1 — Validation runs *before* state construction, on raw scene data

`architecture.md` §Frame update path ordered `LevelRoot._ready()` as:

```
   a. construct LevelState(buckets_total) and OxygenState(capacity, tuning)
   b. LevelValidation.validate(level)   → push_error on contract breach
```

**This ordering is defective and is corrected here.** ADR-0002 established that
`OxygenState._init` rejects `capacity <= 0` — the object is not constructible. So
on a level with a mis-authored capacity, step (a) fails *before* step (b) ever
runs. The one input `validate()` was written to describe is the one input on which
it never executes, and the "return all failures at once" guarantee is dead exactly
where it was needed.

The corrected sequence:

```
3. LevelRoot._ready()   (parent, last)
   a. LevelValidation.validate(self)  → push_error each finding      [MOVED]
   b. construct LevelState(buckets_total) and OxygenState(capacity, tuning)
   c. bind state into Player, Goal, HUD, OxygenDrain
   d. connect each Plant.pour_completed → LevelState.consume_bucket()
   e. GravityAuthority.reset_to(default_gravity_*)   → first broadcast
   f. wire zones → GravityAuthority ; register props → GravityAuthority
```

`validate()` therefore reads **authored scene data only**: `@export` values on
`LevelRoot` and on the nodes beneath it, and the shape of the subtree. It never
reads `LevelState`, `OxygenState`, or anything produced by `bind()`. This is not a
concession to the ordering fix — it is what makes the function a pure,
side-effect-free predicate over a `Node`, testable by handing it a synthetic tree.

`architecture.md` must be amended to match. See Migration Plan.

### D3.2 — Discovery is by recursive type scan, not by group membership

`validate()` walks the level subtree depth-first and matches nodes by class
(`node is Plant`, `node is Bucket`, `node is PropBody`).

ADR-0002's body text presumed group membership ("seed from the bucket group
count"). That is **narrowed, not superseded**: the *quantity* ADR-0002 defines is
unchanged — `buckets_total` is still the count of buckets present at level load,
per `watering-system.md` R6 — only the mechanism for counting them changes.

Groups are rejected for two reasons, and the second is decisive.

**The authoring reason.** Group membership is a per-scene authoring step with no
compile-time or load-time consequence of its own. A plant an author forgot to add
to the `"plants"` group is **invisible to validation**, so the level reports clean
and ships unwinnable. That is the precise failure P4 exists to close, reintroduced
inside the mechanism meant to close it. Type identity cannot be forgotten: a node
that is a `Plant` is a `Plant`.

**The technical reason.** `get_nodes_in_group()` is a method on `SceneTree`, not on
`Node`. D3.7's CI test instantiates each level and never adds it to a tree, so
`get_tree()` returns `null` and group lookup is **not merely risky there — it is
unavailable**. Groups could not service the CI half of this decision at all. The
discovery mechanism and the test strategy are therefore not independent choices:
picking the CI gate picks the type scan with it. *(Engine specialist review
2026-08-14, F2.)*

**Do not replace the hand-rolled recursion with `Node.find_children()`.** The
built-in does the same type matching, but its `owned` parameter **defaults to
`true`** — "only descendants with a valid `owner` node are checked" — which can
silently drop nodes and reintroduce exactly the silent-miss failure this decision
rejects groups for, by a different route. Plain `get_children()` recursion applies
no `owner` filtering and descends into instantiated sub-scenes correctly regardless
of `editable path`. If `find_children()` is ever used here it must pass
`owned = false` explicitly. *(F3 — registered as a forbidden pattern.)*

This requires `class_name Plant`, `class_name Bucket` and `class_name PropBody`.
**This does not conflict with the `class_name` prohibition from the 2026-08-14
review (A1-03)** — that finding is scoped to the collision between an *autoload*
name and a global class identifier, which is why `gamemanager.gd` correctly has
none. `Plant`, `Bucket` and `PropBody` are not autoloads, and 13 of the 14 scripts
in `src/scripts/` already declare a `class_name`. Recorded here so a future reader
does not misapply A1-03 as a blanket ban.

### D3.3 — The v1 rule set: seven rules

| Code | Rule | Source |
|---|---|---|
| `V-BUCKET-SUM` | `count_buckets(level) == Σ plant.buckets_required` | `watering-system.md` R8, AC7 |
| `V-PLANT-MIN` | every `Plant` has `buckets_required >= 1` | `watering-system.md` R5 |
| `V-OXY-CAP` | `LevelRoot.oxygen_capacity > 0` | `suit-oxygen.md` §5, AC7 |
| `V-GRAV-EXPORT` | `default_gravity_direction` is non-zero **and** `default_gravity_multiplier > 0` | ADR-0001 (delegated), `gravity.md` R7 |
| `V-PROP-BUDGET` | `PropBody` count `<= PropTuning.props_per_level_budget` | `physics-props.md` R8, §5, §7 |
| `V-WIRING` | every **required** consumer `NodePath` export on `LevelRoot` is non-empty and resolves — required set enumerated below | ADR-0002 (delegated) |
| `V-BOUNDS` | `level_bounds` is non-empty, resolves to a live `Area2D`, and every `PropBody` in the level starts inside its extent | `physics-props.md` R7; ADR-0011 D11.7 |

*(`V-BOUNDS` added 2026-08-24 by ADR-0011 D11.7, under this ADR's own rule that an
ADR adding a `LevelRoot` consumer amends this table in the same changeset. Its
constant is declared in `level_validation.gd`; the rule logic lands with story 006.)*

Three notes on the set.

**`V-BUCKET-SUM` compares two genuinely independent quantities.** ADR-0002 is
explicit that this is the point — "agreement is the check". `buckets_total` comes
from counting bucket instances; `Σ buckets_required` comes from summing plant
exports. Neither is derived from the other, so their agreement is real evidence
rather than a tautology. Both directions of mismatch are reported, since
`watering-system.md` R8 tabulates both as level-breaking.

**`V-WIRING` checks *wiring*, not *binding*.** ADR-0002 asked ADR-0003 for a
"required consumers bound" check. Under D3.1 validation runs at step (a) and
`bind()` at step (c), so binding has not happened yet and cannot be observed. What
`validate()` *can* observe is that the exported `NodePath`s are non-empty and
resolve to live nodes — which is the condition under which step (c) will succeed.
An unwired consumer is caught here at load; a consumer that is wired but whose
`bind()` call was never written is caught by ADR-0002's per-consumer guard at first
use. The two checks are complementary and neither subsumes the other. This
resolution is a narrowing of ADR-0002's request, not a refusal of it.

**The required-consumer set, and how it grows.** *(Added 2026-08-15 — resolves
conflict C1 of `architecture-review-2026-08-15.md`. Table amended 2026-08-24 —
ADR-0010 and ADR-0011 are now Accepted, so the admission rule below admits `hud`
and `level_bounds`. This records what the rule already required; it is not a new
decision.)* A consumer is **required** when the ADR that introduces it is
**Accepted**. The set as of 2026-08-24:

| Export | Consumer | Owning ADR | Required |
|---|---|---|---|
| `player` | `Player` / `PlayerWateringComponent` | ADR-0002 (Accepted) | **Yes** |
| `goal` | `Goal` | ADR-0002 (Accepted) | **Yes** |
| `hud` | `HUD` | ADR-0010 (Accepted) | **Yes** — admitted 2026-08-24 |
| `level_bounds` | `LevelBounds` `Area2D` | ADR-0011 (Accepted, D11.7) | **Yes** — admitted 2026-08-24 |

`OxygenDrain` is out of scope for this rule entirely: ADR-0002 part 4 makes it a
*child* of `LevelRoot`, not a `NodePath` export, so there is no path for `V-WIRING`
to resolve. Its binding failure mode is covered by ADR-0002's per-consumer guard.

**Why the scoping is necessary rather than a convenience.** ADR-0002 part 3 adds
`@export var hud: HUD` and lists `HUD` as a bound consumer. No HUD scene exists —
`systems-index.md` files it under *Designed but not built*, it belongs to ADR-0010,
which is Presentation tier, and no level wires one. An unqualified reading of "every
required consumer" therefore makes this ADR's own close condition unreachable:
Migration Plan step 6 and Validation Criterion 5 both require every level to return
empty from `validate()` before the level migration epic closes, and no step in that
plan authors a HUD. The epic would close with the gate red, or `V-WIRING` would be
quietly weakened during implementation — which is how a validation rule becomes
decoration, the exact failure `architecture.md` P4 exists to close.

*(2026-08-24 — the scoping argument above is now historical. ADR-0010 is Accepted
and ADR-0011 adds `level_bounds`, so both rows are Required. The close condition it
protected now falls to the level migration epic, which must author both.)*

**This is an obligation on ADR-0010, recorded here so its author inherits it rather
than discovers it.** *(Discharged 2026-08-24 — ADR-0010 was Accepted and `hud`
moved to Required.)* When ADR-0010 is Accepted, `hud` moves to Required and every
level must wire one. Any future ADR that adds a `LevelRoot` consumer export adds a
row to this table in the same changeset.

### D3.4 — Findings are coded strings

`validate()` returns a `PackedStringArray` — the type `architecture.md` already
declares — where every message opens with a stable bracketed code:

```
[V-BUCKET-SUM] buckets_total 3 != sum(buckets_required) 4
[V-OXY-CAP] oxygen_capacity is 0.0; must be > 0 (suit-oxygen.md §5)
[V-PLANT-MIN] Plant "Plant2" has buckets_required 0; must be >= 1
```

Tests assert on the code; humans read the remainder. This buys stable test identity
without introducing a new type or changing the declared return signature. Message
prose may be improved freely; codes are contract and may not change without an ADR
amendment.

An empty return means the level is valid. **`validate()` never pushes an error
itself** — it is a pure function. `LevelRoot` iterates the result and calls
`push_error` on each. This separation is what makes the CI test in D3.7 possible:
a test asserting on a `push_error` side-effect would have to intercept the engine's
error stream; a test asserting on a returned array does not.

### D3.5 — A shared counting primitive

```gdscript
static func count_buckets(level: Node) -> int
```

`LevelRoot` uses this to seed `LevelState(buckets_total)` at step (b), and
`validate()` uses it for `V-BUCKET-SUM` at step (a). One definition of "a bucket",
used by both. Without it, `V-BUCKET-SUM` could pass while `LevelRoot` seeded
`buckets_total` from a subtly different count — a validation pass that certifies a
value the game does not actually use.

### D3.6 — Validation runs in every build

No `OS.is_debug_build()` guard. `architecture.md` P4 carves out no exception for
release, and `watering-system.md` R8 names the silent unwinnable level as the more
dangerous failure mode — a property that does not become less dangerous once
shipped. The cost is one subtree walk at level load (see Performance
Implications), which does not justify a build-conditional branch.

**Be precise about what "reports itself" buys.** Per E3, a finding in a release
build is written to `user://logs/godot.log` and is **retrievable after the fact** —
by the author, by QA, or from a file a player attaches to a bug report. It is
**not** surfaced to the player in-game, and this decision does not make it so. The
value is diagnostic, not corrective: a mis-authored level that escapes CI is
identifiable from a log rather than only from a reproduction. Read as anything
stronger, D3.6 would be overclaiming. *(F6.)*

### D3.7 — A headless CI test over all 8 levels

```gdscript
# tests/unit/level/level_validation_test.gd
func test_every_shipped_level_validates_clean() -> void:
    for path in LEVEL_SCENE_PATHS:                 # all 8
        var level := load(path).instantiate()      # not added to the tree (E1)
        assert_array(LevelValidation.validate(level)).is_empty()
        level.free()
```

Runtime validation alone fires only on levels someone actually plays. With a
migration epic touching all 8, a botched level 07 would sit undetected until
someone played through to level 07. This test converts the whole set into a
blocking CI gate — and, more importantly, it is the surface on which
`watering-system.md` AC7 and `suit-oxygen.md` AC7 become automatable at all.

Per-rule unit tests build synthetic trees and assert the specific code fires; this
suite-wide test asserts the shipped content is clean.

**This test will be RED until the migration epic completes** — all 8 levels
currently fail `V-GRAV-EXPORT` and `V-OXY-CAP`. `.claude/docs/coding-standards.md`
forbids disabling or skipping a failing test to make CI pass, so **the test lands
with the migration epic, not before it.** The per-rule unit tests land immediately
with the implementation. This is stated so the sequencing is a decision on record
rather than a surprise during the epic.

### Architecture Diagram

```
                    LevelRoot._ready()      (bottom-up: children already ready)
                            │
                 (a) ┌──────▼───────────────────────────────┐
                     │ LevelValidation.validate(self)       │   pure, static
                     │   depth-first scan of the subtree    │   no side effects
                     │   reads @export values only          │   no state objects
                     └──────┬───────────────────────────────┘
                            │ PackedStringArray
              ┌─────────────┴─────────────┐
        empty │                           │ non-empty
              │                           ▼
              │                   push_error each finding
              │                   (level still starts — D3.6)
              ▼                           │
   (b) construct LevelState(count_buckets(self)), OxygenState(...)
   (c) bind → Player, Goal, HUD, OxygenDrain
   (d) connect Plant.pour_completed → LevelState.consume_bucket()
   (e) GravityAuthority.reset_to(default_gravity_*)
   (f) wire zones ; register props

        ── separately, off the runtime path ──
   CI: for each of 8 level scenes → instantiate → validate() → assert empty
```

### Key Interfaces

```gdscript
class_name LevelValidation
extends RefCounted
## Pure, static load-time contract checks over a level subtree.
## Reads authored scene data only — never LevelState, OxygenState, or bind() output.
## Discovery is hand-rolled get_children() recursion by design.
## Do NOT substitute Node.find_children() — its `owned` defaults to true (D3.2, F3).

const V_BUCKET_SUM  := "V-BUCKET-SUM"
const V_PLANT_MIN   := "V-PLANT-MIN"
const V_OXY_CAP     := "V-OXY-CAP"
const V_GRAV_EXPORT := "V-GRAV-EXPORT"
const V_PROP_BUDGET := "V-PROP-BUDGET"
const V_WIRING      := "V-WIRING"
const V_BOUNDS      := "V-BOUNDS"

## Returns every contract breach found, each prefixed with its stable code.
## An empty result means the level satisfies every implemented rule.
static func validate(level: Node) -> PackedStringArray

## The single definition of "a bucket in this level". Used by validate() for
## V-BUCKET-SUM and by LevelRoot to seed LevelState(buckets_total).
static func count_buckets(level: Node) -> int
```

**Callers must:** call `validate()` from `LevelRoot._ready()` *before* constructing
`LevelState` or `OxygenState` (D3.1); `push_error` each returned finding; seed
`buckets_total` from `count_buckets()` rather than an independent count (D3.5).

**Guarantees:** returns **all** breaches, never only the first · pushes no errors
and mutates nothing — calling it twice is identical to calling it once · reads no
injected state, so it is callable on a scene that was instantiated but never added
to the tree · codes are stable across message rewording.

## Alternatives Considered

### Alternative 1: Construct state first, then validate (`architecture.md` as written)

- **Description**: Keep the published `LevelRoot._ready()` order — build
  `LevelState` and `OxygenState`, then run `validate()` against the constructed
  objects.
- **Pros**: No amendment to `architecture.md`. `validate()` could read typed state
  rather than raw exports.
- **Cons**: Broken by ADR-0002. `OxygenState._init` rejects `capacity <= 0`, so a
  level violating `V-OXY-CAP` fails during construction and validation never runs.
- **Rejection Reason**: It defeats the requirement it exists to serve. The
  report-all-failures guarantee would hold on every input except the one that
  motivated it.

### Alternative 2: Discovery by scene group membership

- **Description**: `get_nodes_in_group("plants" / "buckets" / "props")`, as
  ADR-0002's body text presumed.
- **Pros**: Cheapest lookup. No `class_name` requirement. Lets a level opt a node
  out of validation deliberately.
- **Cons**: Group membership is invisible bookkeeping with no other consequence. A
  forgotten group assignment makes the node invisible to validation, and the level
  reports clean.
- **Rejection Reason**: A validation mechanism whose own discovery can silently
  under-report is worse than none, because it converts "unknown" into a false
  "clean". The opt-out flexibility is not a requirement any GDD asks for.

### Alternative 3: `@tool` edit-time validation in the editor

- **Description**: Mark the level root `@tool` and surface findings as editor
  warnings via `_get_configuration_warnings()`, catching breaches while authoring.
- **Pros**: Earliest possible feedback, at the moment of the mistake. Zero runtime
  cost.
- **Cons**: Requires `@tool` on the gameplay level-root script, after which *every*
  line in it must be editor-safe — a substantial and permanent hazard for a script
  that also owns state construction, injection and gravity reset. Helps only
  whoever has that scene open; it is not a gate, so nothing stops a broken level
  being committed.
- **Rejection Reason**: A large, permanent correctness liability in `main.gd` bought
  for feedback that D3.7's CI gate provides without touching gameplay code. Worth
  revisiting as a *supplement* once the runtime and CI halves exist — never as a
  replacement.

### Alternative 4: Per-system self-validation

- **Description**: Each subsystem checks its own contract in its own `_ready()` —
  `Plant` validates `buckets_required`, the oxygen system validates capacity, and
  so on.
- **Pros**: Ownership sits with the system that defines the rule. No central class.
- **Cons**: Defeats report-all-failures by construction: each system errors at its
  own moment, so an author discovers breaches one run at a time. Re-scatters
  ownership that ADR-0002 just consolidated into `LevelRoot`. `V-BUCKET-SUM` is
  level-wide and has no owning system — it would land back on `Plant`, colliding
  directly with ADR-0002's `plant_decides_level_outcome` ban. `V-PROP-BUDGET` has
  no natural owner among the props themselves.
- **Rejection Reason**: It reproduces the distributed-ownership defect ADR-0002 was
  written to remove, and cannot satisfy the report-all-failures requirement at all.

## Consequences

### Positive

- `watering-system.md` AC7 and `suit-oxygen.md` AC7 gain a clean automated evidence
  path. Both are Logic-typed and therefore BLOCKING; neither was satisfiable before.
- The level migration epic (QQ-03) gets a per-level gate. 8 levels × 3 hand-edits
  becomes a change with an objective completion test rather than a checklist.
- `architecture.md`'s init-order defect is caught before any code depends on it.
- `validate()` is a pure static function over a `Node`, so per-rule tests need a
  synthetic tree and nothing else — no running game, no autoloads, no scene load.
- Adding a seventh rule later touches one file and adds one code.

### Negative

- Three `class_name` declarations are now load-bearing for correctness rather than
  convenience. Removing `class_name Plant` would silently reduce validation
  coverage rather than break the build. This must be spelled out in the control
  manifest.
- `V-PROP-BUDGET` is specified here but cannot be implemented until ADR-0006 lands
  `PropTuning`. The rule set ships incomplete and is completed later.
- The CI test is knowingly deferred to the migration epic to avoid landing a red
  test, so between implementation and migration the runtime check is the only one
  running.
- Validation runs on every level load in every build, including release (D3.6).
  Small, but non-zero and permanent.

### Risks

| Risk | Mitigation |
|---|---|
| **`find_children()` substituted for the hand-rolled recursion** | Its `owned` parameter defaults to `true`, silently skipping descendants without a valid `owner` — the same silent-miss class this ADR rejects groups for, arriving as a plausible-looking cleanup. Registered as a forbidden pattern; the recursion carries a comment citing D3.2. *(F3)* |
| **GdUnit4 fails the whole suite on a GDScript warning** | gdUnit4 treats warnings as errors at test *discovery*, so a shadowed native method name, an unused variable or a narrowing conversion in `level_validation.gd` fails **every** test rather than one. This project has hit it before. Run the documented headless command locally as part of Migration Plan step 4, before calling it done. *(F10)* |
| **An author adds a new level-wide contract and does not add a rule** | `validate()` reporting clean is only as strong as the rule set. Every future GDD introducing a level-authoring invariant must add a rule here — record in the control manifest, not in this ADR alone |
| **A scene starts using instance load placeholders** | Per E2's boundary condition, node-path exports on such a scene store the raw `NodePath` rather than resolving, so `V-WIRING` degrades silently on it. No scene uses them today. If one ever does, `V-WIRING` needs an explicit unresolved-path branch |
| **A new objective type is introduced that `validate()` does not know about** | The type scan covers `Plant`, `Bucket` and `PropBody` by name. A new class is invisible until a rule names it — the same class of gap as Alternative 2's forgotten group, merely narrower and code-visible rather than data-invisible |
| **Someone "simplifies" `validate()` to return on first failure** | It reads like an efficiency win and destroys the requirement. The implementation must carry a comment citing `watering-system.md` R8 and this ADR, in the same spirit as ADR-0005's deferral comment |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `watering-system.md` | R8 — `buckets_total == Σ buckets_required`, validated at load; both mismatch directions break the level; the check must log an error rather than fail quietly | `V-BUCKET-SUM` compares two independently sourced quantities and reports either direction. `LevelRoot` pushes an error per finding; the level still starts (D3.6) |
| `watering-system.md` | AC7 — "Level load logs an error when `buckets_total != Σ buckets_required`", type **Logic** (BLOCKING) | The returned `PackedStringArray` is the assertable surface (D3.4). Per-rule unit test asserts `V-BUCKET-SUM` fires on a synthetic mismatched tree |
| `watering-system.md` | R5 — each plant exports `buckets_required: int` (≥ 1) | `V-PLANT-MIN`. A zero would make the plant permanently capped and silently shrink Σ below `buckets_total` |
| `suit-oxygen.md` | §5 — "`oxygen_capacity` authored ≤ 0 → mis-authored level, log an error at load, same class of failure as R8 in `watering-system.md`" | `V-OXY-CAP`, running at step (a) before `OxygenState` construction would abort on the same input (D3.1) |
| `suit-oxygen.md` | AC7 — "Level load logs an error when `oxygen_capacity <= 0`", type **Logic** (BLOCKING) | Same mechanism as watering AC7. Discharges the ADR-0002 registry note that `LevelValidation` "still reports it at load time, because authoring feedback needs all failures at once" |
| `physics-props.md` | R8 / §5 — prop count is budgeted; exceeding it is an authoring error "flagged at load" | `V-PROP-BUDGET`, gated on ADR-0006 delivering `PropTuning.props_per_level_budget` (Ordering Note) |
| `gravity.md` | R7 — an invalid gravity change is rejected; ADR-0001 requires every level to carry `default_gravity_*` or a restart inherits the death gravity | `V-GRAV-EXPORT`, the check ADR-0001 delegated here by name |

## Performance Implications

- **CPU**: One depth-first walk of the level subtree per level load. Current levels
  hold well under 100 nodes; `props_per_level_budget` defaults to 40, so a fully
  furnished level stays in the low hundreds. Sub-millisecond, one-off, off the
  frame path entirely. **Zero per-frame cost** — `validate()` is never called from
  `_process` or `_physics_process`.
- **Memory**: One `PackedStringArray`, empty in the passing case, discarded
  immediately after the `push_error` loop. No retained references to level nodes.
- **Load Time**: Negligible against scene instantiation, which walks the same tree
  and does substantially more per node.
- **Network**: Not applicable.

## Migration Plan

1. **Amend `architecture.md`** — swap steps (a) and (b) in the §Frame update path
   init block and add a note that validation reads raw scene data. The published
   order is defective as written (D3.1).
2. **Add `class_name`** to `plant.gd` and `bucket.gd`; `PropBody` gets one when it
   is created under ADR-0011.
3. **Implement `LevelValidation`** with five of the seven rules. `V-PROP-BUDGET`
   and `V-BOUNDS` are specified with their constants in place and land with
   story 006.
4. **Per-rule unit tests** — synthetic trees, one test per code, asserting the right
   code fires and that a clean tree returns empty. **Run the headless suite locally
   before calling this step done**: gdUnit4 treats GDScript warnings as errors
   during test discovery, so a shadowed native method name in `level_validation.gd`
   fails the entire suite at compile time rather than failing one test. This
   project has already been bitten by exactly that. *(F10)*

   ```bash
   "…/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
     --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
     --ignoreHeadlessMode -a res://tests/unit
   ```
5. **Wire into `LevelRoot._ready()`** at step (a), with `count_buckets()` seeding
   `LevelState` at step (b).
6. **Level migration epic (QQ-03)** — all 8 levels gain `default_gravity_*`, the
   multi-bucket economy, and a derived `oxygen_capacity`. Every level must return
   empty from `validate()` before the epic closes.
7. **Land the suite-wide CI test with step 6**, not before — it is red until the
   migration completes, and the coding standards forbid shipping a skipped test.
8. **Close `V-PROP-BUDGET`** when ADR-0006 lands `PropTuning`.

## Validation Criteria

1. `validate()` on a synthetic level breaching **all seven** rules returns one
   finding per breached code, and one `V-WIRING` finding per unwired consumer
   row — not one finding, and not a partial set. This is the report-all-failures
   guarantee under direct test. *(Amended 2026-08-24: the original wording said
   "six findings, one per code". `V-WIRING` fires per row, so the count is not
   equal to the number of codes — the shipped gate test returns nine findings
   across the five implemented codes.)*
2. `validate()` on a level with `oxygen_capacity = 0` returns `V-OXY-CAP` **and the
   level still reaches step (b)**, proving the D3.1 reordering actually fixed the
   abort rather than merely relocating it.
3. A `grep` for `is_debug_build` in `level_validation.gd` and in the `LevelRoot`
   call site returns nothing — D3.6 has no build-conditional guard. *(Same
   grep-as-test shape as ADR-0005's Validation Criterion 4.)*
4. Removing a plant from any level makes `V-BUCKET-SUM` fire — confirming discovery
   is live rather than reading a cached or authored count.
5. All 8 shipped levels return empty at the close of the migration epic.
6. `validate()` called twice on the same tree returns equal results and leaves the
   tree unchanged — the purity guarantee D3.7 depends on.

## Related Decisions

- **ADR-0001** Gravity ownership and global broadcast — delegates the
  `default_gravity_*` presence check here (`V-GRAV-EXPORT`); its Risks table names
  this ADR as the mitigation.
- **ADR-0002** Level state ownership — owns the `LevelRoot._ready()` sequence this
  decision inserts into; requested `V-WIRING` by name; its
  `oxygen_state_constructor_injection` entry is what forced the D3.1 reordering.
- **ADR-0005** Frame ordering and the `level_complete` guard — adjacent in the
  lifecycle but disjoint: ADR-0005 governs per-frame ordering, this governs
  one-time load ordering. No overlap.
- **ADR-0006** Tuning resource strategy — must land `PropTuning.props_per_level_budget`
  before `V-PROP-BUDGET` is implementable.
- `architecture.md` P4 (fail loudly at load), §Frame update path (amended by D3.1),
  §API Boundaries `LevelValidation` block (expanded here).
- `architecture-review-2026-08-14.md` — the source of the non-empty Verification
  Required discipline this ADR follows.
- **Engine specialist review, 2026-08-14** (gate step 5.5) — verdict *APPROVE WITH
  NOTES*. Verified E1–E3 against engine source and the live class reference,
  confirmed A1-03's `class_name` prohibition is autoload-scoped only (F8), upheld
  Alternative 3's rejection of `@tool` / `_get_configuration_warnings()` as
  editor-only and therefore unusable as a load-time or CI gate (F9), and
  contributed the `find_children(owned)` hazard (F3), the D3.6 wording correction
  (F6) and the gdUnit4 warnings-as-errors risk (F10).
