# ADR-0002: Level State Ownership and Injectable State Objects

## Status

**Accepted** — 2026-08-15

## Date

2026-08-14

> **Deviation notice.** `architecture.md` D2 assigns `LevelState` and `OxygenState`
> to the `GameManager` autoload. This ADR assigns them to `LevelRoot` instead, on
> a user decision taken 2026-08-14. The reasoning is in Alternative 1, and
> `architecture.md` D2 must be amended to match. This also supersedes one registry
> entry from ADR-0001 — see ADR Dependencies.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (state management, object lifetime, signals) |
| **Knowledge Risk** | **LOW** |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` · `docs/engine-reference/godot/breaking-changes.md` · `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | **None.** `RefCounted`, `_init()` argument passing, signals, `@export`, `reload_current_scene()` and bottom-up `_ready()` ordering are all pre-4.4 and unchanged through 4.7. |
| **Verification Required** | **Amended 2026-08-14.** This originally read "None," which was overstated: the in-repo engine references cover only `physics-2d` and `ui-control`, so the Core/GDScript facts this ADR rests on were asserted without independent checking. Four were verified in the engine specialist review (see `architecture-review-2026-08-14.md`): bottom-up `_ready()` and autoload-before-scene ordering ✅ · signal connections to a `RefCounted` are weak references ✅ · `assert()` compiles out in release exports while `push_error()` does not ✅ · **getter-only property enforcement — the one that did not hold as written, see A2-01.** Nothing outstanding. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. Foundation root, peer to ADR-0001. |
| **Enables** | ADR-0003 (validation reads these contracts) · ADR-0005 (`level_complete` field) · ADR-0008 (`OxygenState`) · ADR-0009 (`LevelState`) · ADR-0010 (HUD binds to both) |
| **Blocks** | The watering, oxygen and HUD epics. None may start until this is Accepted. |
| **Amends** | **ADR-0001**, registry entry `state_ownership.level_default_gravity`. That entry says level gravity is restored "via `GravityAuthority.reset_to()` from `GameManager.reset_level_state()`". `reset_level_state()` ceases to exist under this decision; the call moves to `LevelRoot._ready()`. No behaviour changes — `restart_level()` already reloads the scene, which re-runs `LevelRoot._ready()`. ADR-0001's prose (part 6) and the registry entry both need the caller name corrected. |
| **Ordering Note** | ADR-0005 depends on the `level_complete` field declared here, but this ADR deliberately does **not** define when it is read or written. |

## Context

### Problem Statement

`GameManager` is a five-field untyped autoload (`gamemanager.gd`) mutated from
**10 call sites across 5 files**: `bucket.gd:7`, `goal.gd:25,40`,
`main.gd:31,33,46,50,61`, `plant.gd:30,73`. It is the shared mutable global that
`watering-system.md` and `suit-oxygen.md` both currently name as their state owner.

Three problems follow:

**1 — Nothing is headless-testable.** `.claude/docs/coding-standards.md` requires
dependency injection over singletons and demands every public method be
unit-testable. Almost every Logic-type acceptance criterion in the two GDDs —
watering AC2, AC3, AC4, AC6, AC7; oxygen AC1, AC3, AC4, AC6, AC7 — is an assertion
about level state. Reaching an autoload means each of those tests needs a booted
`SceneTree`.

**2 — Reset is manual, and it is already wrong.** `reset_level_state()`
(`gamemanager.gd:12-15`) clears `goal_unlocked`, `plants_watered` and
`plants_total`, and **forgets `carrying_bucket`**. After a death the player retains
a bucket that no longer exists in the scene. `watering-system.md` §5 flags this as
an existing defect and AC8 is the test for it. The defect is not an oversight so
much as the predictable outcome of hand-maintaining a reset function against a
growing struct.

**3 — Individual objects decide level-wide outcomes.** `plant.gd:73-79` reaches
into `GameManager` and decides the level is over. `watering-system.md` R6 is
explicit that "no single plant should be deciding whether the room is breathable."

There is also a **latent ownership question** this ADR resolves.
`reset_level_state()` exists *only* because state lives on an autoload that
survives `reload_current_scene()`. Nothing in any GDD needs level state to outlive
a level: `suit-oxygen.md` R5 says oxygen never carries between levels and restart
resets it to full; `watering-system.md` §5 says no progress carries across a
restart. `restart_level()` (`main.gd:59-62`) is already
`reset_level_state()` **plus** `reload_current_scene()`, and the reload alone
reconstructs the level tree.

### Constraints

- Every Logic AC in both GDDs must run headless — no `SceneTree`, no `Player`, no
  rendered scene.
- Restart must reset watering state and oxygen completely (`watering-system.md`
  §5, AC8; `suit-oxygen.md` R5, AC4, AC5).
- Oxygen must never carry between levels (`suit-oxygen.md` R5, AC5).
- `Goal` keeps its existing unlock behaviour — `watering-system.md` §6 lists
  `goal.gd` as **no changes** beyond where it reads the flag from.
- Godot calls `_ready()` **bottom-up**: children are ready before their parent. Any
  object a parent creates cannot be read by a child during that child's `_ready()`.
- Nothing may call upward. `architecture.md` line 317: "Every cross-module link is
  a signal. No module calls upward."
- `player_lives` is out of scope by user decision and stays untouched.

### Requirements

- One typed object owns watering/level state; one owns oxygen state.
- Both are constructible in a test with no engine scaffolding.
- `goal_unlocked` flips exactly when `buckets_consumed >= buckets_total` and never
  before (`watering-system.md` R6, AC6).
- `remaining` never increases by any path (`suit-oxygen.md` R4, AC3).
- Restart clears carry state (`watering-system.md` AC8) and refills oxygen
  (`suit-oxygen.md` AC4).
- `Plant` reports a completed pour and nothing more.

## Decision

**`LevelRoot` owns both state objects and injects them. `GameManager` keeps only
cross-level concerns.** Six parts:

**1 — `LevelState` and `OxygenState` are plain `RefCounted` objects created by
`LevelRoot._ready()`** from the level root's own `@export`s. They are not
autoloads, not singletons, and not reachable globally.

**2 — Restart is reconstruction, not reset.** `restart_level()` becomes
`reload_current_scene()` alone. The reload destroys `LevelRoot`, which drops the
last reference to both state objects; the new `LevelRoot._ready()` constructs
fresh ones. `reset_level_state()` is **deleted**, and neither state object has a
`reset()` method.

This is the substantive win. `watering-system.md` AC8 (restart clears carry state)
and `suit-oxygen.md` AC4/AC5 (restart refills, nothing carries between levels)
stop being things a reset function must remember and become properties of object
lifetime. The `carrying_bucket` defect class is not fixed — it is made
unrepresentable.

**3 — Injection is explicit and guarded, mirroring ADR-0001.** Because `_ready()`
runs bottom-up, a consumer cannot read injected state during its own `_ready()`.
`LevelRoot._ready()` therefore calls a `bind(...)` method on each consumer, and
**every consumer refuses to operate before it is bound**, with `push_error()` —
exactly the pattern `GravityAuthority.initialize()` established in ADR-0001 part 7.

The guard shape is exactly this, and the `return` is mandatory:

```gdscript
if not _bound:
    push_error("…")
    return
```

`push_error()` logs to the debugger and terminal but **does not pause execution** —
it is a logging call, not an exception. Without the early return the consumer
continues against an unset reference, producing a null dereference or a silent read
of default field values instead of the refusal this decision promises.

`push_error()` and **not** `assert()`: `assert()` is compiled out entirely in
release exports, so every bind guard in the project would silently vanish from the
shipped build. Recorded here so the substitution is not made later as an apparent
cleanup. *(Added 2026-08-14 — engine specialist review A2-02.)*

| Consumer | Receives | Reached via |
|---|---|---|
| `Player` / `PlayerWateringComponent` | `LevelState` | existing `@export var player` |
| `Goal` | `LevelState` | existing `@export var goal` |
| `HUD` | `LevelState`, `OxygenState` | new `@export var hud` |
| `OxygenDrain` | `OxygenState` | child of `LevelRoot` |
| `Plant` (each) | nothing | `pour_completed` → `LevelState.consume_bucket()`, connected by `LevelRoot` |

`Plant` receives no state at all. It emits `pour_completed` and `LevelRoot` wires
that to the counter — the structural fix for `watering-system.md` R6.

**This corrects `architecture.md`'s init-order block** (line 391), which has
`HUD._ready()` binding to `OxygenState`/`LevelState` at step 2, before `LevelRoot`
creates them at step 3. Under bottom-up `_ready()` that cannot work. Binding is a
step-3 activity.

**4 — `OxygenDrain` is a child of `LevelRoot`, not of `Player`.** It drives
level-scoped state and its death trigger targets `LevelRoot.restart_level()`. Its
`process_priority` of `+100` is ADR-0005's concern.

**5 — `OxygenState` takes capacity and tuning at construction**, not via a later
`configure()` call. An `OxygenState` with a non-positive capacity is therefore not
constructible, which makes `suit-oxygen.md` AC7's failure mode impossible to reach
at runtime. `LevelValidation` (ADR-0003) still reports it at load time, because
authoring feedback needs *all* failures at once, not the first crash.

**6 — `GameManager` retains only `player_lives`.** It is out of scope by user
decision. It appears in no GDD and is read nowhere in `src/`; whether it is
specified or deleted is deferred.

### Architecture Diagram

```
                        LevelRoot  (@export: oxygen_capacity,
                                    default_gravity_direction/_multiplier)
                              │
              _ready() step 3 │ constructs, seeds, injects, wires
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌──────────────────┐            ┌──────────────────────┐
    │    LevelState    │            │     OxygenState      │
    │    (RefCounted)  │            │     (RefCounted)     │
    │                  │            │                      │
    │ buckets_total    │            │ capacity  (>0, ctor) │
    │ buckets_consumed │            │ remaining            │
    │ carrying_bucket  │            │ fraction             │
    │ goal_unlocked ▲  │            │ band                 │
    │ level_complete   │            │                      │
    │   (ADR-0005)     │            │ monotonically ▼ only │
    └────────┬─────────┘            └──────────┬───────────┘
             │                                  │
   bind()    │  goal_unlocked_changed           │ threshold_changed
   ┌─────────┼──────────┬─────────┐             │ depleted
   ▼         ▼          ▼         ▼             ▼
 Player    Goal       HUD    (counter)      OxygenDrain ──▶ LevelRoot
 Watering                                   (owns the         .restart_level()
 Component                                   death POLICY;
     ▲                                       ADR-0005/0008)
     │ pour_completed
   Plant  (holds no level state)

 Lifetime:  reload_current_scene() frees LevelRoot
            → both objects freed → fresh ones next _ready()
            → restart reset is STRUCTURAL, not a reset() call
```

### Key Interfaces

```gdscript
class_name LevelState extends RefCounted

signal goal_unlocked_changed(unlocked: bool)
signal bucket_consumed(consumed: int, total: int)

var _buckets_total: int
var _buckets_consumed: int
var _goal_unlocked: bool
var _level_complete: bool

var buckets_total: int:
    get: return _buckets_total     # seeded once by LevelRoot; never written again
var buckets_consumed: int:
    get: return _buckets_consumed  # written only by consume_bucket()
var goal_unlocked: bool:
    get: return _goal_unlocked     # derived
var level_complete: bool:
    get: return _level_complete    # ADR-0005 owns read/write ordering

var carrying_bucket: bool          # genuinely read-write

func _init(buckets_total: int) -> void
func consume_bucket() -> void
```

> **Read-only means getter-only.** Every derived or externally-immutable value is a
> getter-only computed property over a private backing field, not a plain `var`. A
> plain `var` in GDScript is a public field with an implicit setter —
> `level_state.goal_unlocked = true` would compile, run and succeed silently from
> any script, and V2 below could never pass. Assignment to a getter-only property
> raises a runtime error, which is what makes the guarantees below properties of the
> type rather than rules to police. *(Corrected 2026-08-14 — engine specialist
> review A2-01, the one blocking finding.)*

**Callers must**: pass `buckets_total >= 0` at construction; call
`consume_bucket()` only on a *completed* pour (`watering-system.md` R3), never on
pickup or early release.

**Guarantees**:

- `goal_unlocked` flips true exactly when `buckets_consumed >= buckets_total`, and
  never before — `watering-system.md` R6, AC6
- `buckets_consumed` never decreases and never exceeds `buckets_total`
- `buckets_total` is immutable after construction
- No `reset()`. Restart discards the object — `watering-system.md` AC8

```gdscript
class_name OxygenState extends RefCounted

enum Band { NOMINAL, CAUTION, WARNING, CRITICAL }

signal threshold_changed(band: Band)
signal depleted

var _capacity: float
var _remaining: float
var _band: Band

var capacity: float:
    get: return _capacity                  # immutable after construction
var remaining: float:
    get: return _remaining                 # monotonically decreasing; no setter
var fraction: float:
    get: return _remaining / _capacity     # derived
var band: Band:
    get: return _band

func _init(capacity: float, tuning: OxygenTuning) -> void
func drain(delta: float) -> void
```

Same rule as `LevelState`: getter-only properties over private backing fields. This
is what makes `suit-oxygen.md` AC3 ("no game action increases oxygen") a property of
the type — `remaining` has no setter to call — rather than a rule that has to be
policed in review. *(A2-01.)*

**Callers must**: pass `capacity > 0` — construction fails otherwise
(`suit-oxygen.md` AC7); call `drain()` exactly once per physics frame,
unconditionally, in every player state (`suit-oxygen.md` R2, AC1).

**Guarantees**:

- `remaining` never increases by any path — `suit-oxygen.md` R4, AC3. There is no
  setter, no refill, and no `reset()`
- `depleted` emits exactly once
- `threshold_changed` fires at the `OxygenTuning` bands (0.50 / 0.25 / 0.10) and
  never re-fires for a band already entered
- `drain()` is unconditional — it contains no state checks, so no caller can
  create a safe state (`suit-oxygen.md` R2)

`depleted` is a pure **state** signal meaning "the tank is empty". It carries no
policy. `OxygenDrain` owns the decision to kill, including the `level_complete`
suppression that `suit-oxygen.md` AC8 requires — this refines `architecture.md`'s
signal table (line 326), which wires `depleted` straight to
`LevelRoot.restart_level()` and would break AC8. The death path belongs to
ADR-0008; the ordering belongs to ADR-0005.

**Corrected initialisation order** (supersedes `architecture.md` line 386-397):

```
1. Autoloads          GameManager, GravityAuthority   (uninitialised, guarded)
2. Level children, bottom-up
   ├─ Player._ready()      derive baseline → GravityAuthority.initialize(…)
   ├─ Plants, Buckets, Props, Zones _ready()
   └─ HUD._ready()         build widgets ONLY — must not touch state yet
3. LevelRoot._ready()      (parent, last)
   a. construct LevelState(buckets_total) and OxygenState(capacity, tuning)
   b. LevelValidation.validate(level)     → push_error on contract breach
   c. bind state into Player, Goal, HUD, OxygenDrain
   d. connect each Plant.pour_completed → LevelState.consume_bucket()
   e. GravityAuthority.reset_to(default_gravity_*)   → first broadcast
   f. wire zones → GravityAuthority ; register props → GravityAuthority
```

## Alternatives Considered

### Alternative 1: `GameManager` holds both objects (`architecture.md` D2 as written)

- **Description**: The autoload keeps cross-level concerns and holds
  `level_state` / `oxygen_state`; `reset_level_state()` clears both; consumers read
  `GameManager.level_state`.
- **Pros**: Matches the signed-off architecture exactly. No injection wiring — any
  node reaches state in one line. A late-spawned node needs no special handling.
  Keeps a single well-known access point.
- **Cons**: Level-scoped state lives in a global that outlives the level, so reset
  stays a hand-maintained function — and that function is *already wrong* today
  (`carrying_bucket`, `watering-system.md` §5). The objects would be
  "injectable" in tests while production code still reaches a singleton, which
  satisfies the letter of the coding standard and not its purpose. Restart
  correctness would remain a convention that a future field addition can silently
  break.
- **Rejection Reason**: **User decision, 2026-08-14**, taken with the trade-off
  stated. The deciding argument was that watering AC8 and oxygen AC4/AC5 become
  structural under `LevelRoot` ownership rather than dependent on remembering to
  clear a field — and that the *existing* defect is evidence the convention does
  not hold. Nothing forces an autoload here: unlike ADR-0001's Alternative 3, there
  is no global engine resource (the physics space) that an injected object would
  still have to reach.

### Alternative 2: Keep flat fields on `GameManager` (status quo)

- **Description**: Add `oxygen_remaining` / `oxygen_capacity` / `buckets_*`
  alongside the existing five fields and carry on.
- **Pros**: Zero migration. All 10 existing call sites keep working.
- **Cons**: No types, no invariants, no encapsulation — any script can write
  `goal_unlocked = true` or increase `oxygen_remaining`, so `suit-oxygen.md` AC3
  ("no game action increases oxygen") could only ever be tested, never guaranteed.
  Every Logic AC needs a booted `SceneTree`. `reset_level_state()` grows two more
  fields to forget.
- **Rejection Reason**: It is the problem statement.

### Alternative 3: Hybrid — `LevelRoot` constructs, `GameManager` publishes

- **Description**: `LevelRoot` creates the objects (so reset stays structural) but
  registers them on `GameManager` for global lookup.
- **Pros**: Structural reset *and* one-line access from anywhere.
- **Cons**: Reintroduces the singleton access path the coding standard exists to
  remove, and adds a second source of truth for object lifetime — a stale
  `GameManager.level_state` pointing at a freed level is a new failure mode that
  neither pure option has.
- **Rejection Reason**: Takes the cost of both designs for the convenience of one.

### Alternative 4: One autoload per state object

- **Description**: `LevelState` and `OxygenState` each become their own autoload.
- **Pros**: Typed and encapsulated, unlike Alternative 2. Trivial access.
- **Cons**: Same survival-across-reload problem as Alternative 1, now doubled, and
  two more globals. Still untestable without a `SceneTree`.
- **Rejection Reason**: Strictly worse than Alternative 1 on every axis that
  matters.

## Consequences

### Positive

- `watering-system.md` AC8 and `suit-oxygen.md` AC4/AC5 hold **by construction**.
  The `carrying_bucket` reset defect becomes unrepresentable rather than fixed.
- Every Logic AC in both GDDs becomes headless-testable: construct a `LevelState`
  or `OxygenState` directly, with no `SceneTree`, `Player`, or rendered scene.
- `suit-oxygen.md` AC3 ("no game action increases oxygen") becomes a property of
  the type — there is no setter to call — rather than a rule to police.
- `suit-oxygen.md` AC7's runtime failure mode is unreachable: constructor
  validation means a zero-capacity `OxygenState` cannot exist.
- `watering-system.md` R6 is structurally satisfied — `Plant` holds no level state
  and cannot decide the level is over.
- `restart_level()` shrinks to a single call.
- Two real errors in `architecture.md` are corrected: the `HUD._ready()` binding
  order, and `depleted` being wired directly to `restart_level()` in a way that
  would break oxygen AC8.

### Negative

- **Deviates from `architecture.md` D2**, which must be amended or it will mislead
  every later reader. ADR-0001's part 6 prose and one registry entry need the
  caller name corrected from `GameManager.reset_level_state()` to
  `LevelRoot._ready()`.
- Explicit injection wiring is now required, and `LevelRoot` must be able to reach
  every consumer. `HUD` needs a new `@export` on the level root; a consumer added
  later and not wired will fail loudly at first use rather than silently reading a
  global.
- Consumers cannot touch level state in their own `_ready()`. This is a real
  constraint on every future node, and the reason each needs a bind guard.
- Any object needing level state must be reachable from `LevelRoot` — dynamically
  spawned objects must be injected at spawn time.
- 10 call sites across 5 files change together. `bucket.gd`, `plant.gd`, `goal.gd`,
  `main.gd` and `gamemanager.gd` are all touched in one changeset.
- `GameManager` is left holding one unused variable, which is an odd artifact until
  `player_lives` is settled.

### Risks

| Risk | Mitigation |
|---|---|
| **A consumer reads state before `bind()`** — bottom-up `_ready()` makes this the natural mistake | Every consumer guards and `push_error()`s, mirroring `GravityAuthority.initialize()` from ADR-0001. The corrected init order is documented above. A test must assert the refusal, not just the happy path |
| **A consumer is never wired** — new node added, `LevelRoot` not updated | Fails loudly at first use via the bind guard. ADR-0003 should add a "required consumers bound" check to `LevelValidation` |
| **`architecture.md` D2 left stale**, so a later ADR is written against `GameManager` ownership | Amend D2 in the same changeset as this ADR; registry entry supersession recorded below |
| **`buckets_total` seeded from the wrong source** — R6 says "buckets present at level load", R8 says it must equal `Σ buckets_required` | Seed from `LevelValidation.count_buckets()` (R6 is the definition); ADR-0003's `validate()` asserts the R8 equality. Two independent sources is the point — agreement is the check. *(Amended 2026-08-15 — was "the bucket group count". ADR-0003 D3.2 forbids group-based discovery outright: `get_nodes_in_group()` is a `SceneTree` method and is unavailable on the null-tree CI path. D3.5 requires `LevelRoot` and `validate()` to share the one `count_buckets()` primitive, so that `V-BUCKET-SUM` cannot pass while `LevelRoot` seeds from a subtly different count. **The two independent sources are unchanged** — bucket instances vs `Σ buckets_required` — only the mechanism for counting instances is now named. Resolves conflict C2 of `architecture-review-2026-08-15.md`.)* |
| **A dynamically spawned object needs level state** | Not required by any current GDD. If it becomes required, the spawner injects at construction; do not reintroduce a global |
| **A bound consumer outlives the scene reload**, holding a stale state object. `LevelRoot` is *not* the sole owner — `Player`, `Goal`, `HUD` and `OxygenDrain` each hold a strong reference | Signal connections to a `RefCounted` are **weak** and do not keep it alive, so the `Plant.pour_completed` wiring is safe. Reconstruction works because every strong holder is freed in the same synchronous teardown pass as `LevelRoot`. **Invariant: every bound consumer must be a descendant of `LevelRoot`.** A persistent or cross-scene HUD would hold a stale `LevelState` with no error and no crash — `RefCounted` leaks are invisible and there is no watchdog *(added 2026-08-14 — engine specialist review A2-03)* |
| **`depleted` reconnected directly to `restart_level()`** by someone following `architecture.md`'s signal table | Breaks `suit-oxygen.md` AC8. Registered as a forbidden pattern; ADR-0008 owns the correct death path |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `watering-system.md` | R6 — airlock gates on the level-wide consumed-bucket counter, not on any plant | `LevelState` owns `buckets_consumed` and derives `goal_unlocked`. `Plant` emits `pour_completed` and holds no level state |
| `watering-system.md` | R8 — `buckets_total == Σ buckets_required`, validated at load | `buckets_total` is immutable after construction, giving `validate()` a stable value to check (rules owned by ADR-0003) |
| `watering-system.md` | §5 defect — `reset_level_state()` leaves `carrying_bucket` set | Deleted. Restart reconstructs `LevelState`, so carry state cannot survive |
| `watering-system.md` | AC6 — `goal_unlocked` true exactly at `buckets_consumed >= buckets_total`, never before | Derived read-only property; no external writer exists |
| `watering-system.md` | AC8 — restart clears carry state | Structural: object lifetime, not a reset call |
| `suit-oxygen.md` | R1 — per-level countdown from `oxygen_capacity` | `OxygenState(capacity, tuning)` constructed per level from the `LevelRoot` export |
| `suit-oxygen.md` | R2 / AC1 — drain is unconditional in every player state | `drain(delta)` contains no state checks; no caller can create a safe state |
| `suit-oxygen.md` | R4 / AC3 — nothing refills the suit | `remaining` has no setter and no `reset()`; monotonicity is a type property |
| `suit-oxygen.md` | R5 / AC4 / AC5 — restart refills; oxygen never carries between levels | Structural: the object dies with the level, on both restart and transition |
| `suit-oxygen.md` | R6 — capacity is derived per level, not guessed | Authored as a `LevelRoot` export, matching `suit-oxygen.md` §7's stated location |
| `suit-oxygen.md` | R7 / AC9 / AC10 — always-visible readout, escalating thresholds | `threshold_changed(band)` + `fraction`; HUD binds at init step 3c (rendering owned by ADR-0010) |
| `suit-oxygen.md` | AC7 — load logs an error when `oxygen_capacity <= 0` | Constructor rejects it at runtime; `validate()` reports it at load (ADR-0003) |
| Both | Every Logic AC must run headless | `RefCounted` objects constructed directly in tests — no autoload, no `SceneTree` |

Architecture-doc TR mapping for this ADR: `TR-watering-006/011`,
`TR-oxygen-005/012`. As with ADR-0001, the 52-requirement baseline behind those IDs
is not persisted to disk; the GDD rule and AC citations above are the verifiable
anchor, and `/architecture-review` owns rebuilding the matrix.

## Performance Implications

- **CPU** — Two `RefCounted` allocations per level load. `drain()` is one
  subtraction and a band comparison per physics frame. `consume_bucket()` runs a
  handful of times per level. Effectively zero.
- **Memory** — Two small objects per level, freed with `LevelRoot`. Strictly less
  than the current design, which holds level state for the whole session.
- **Load Time** — Two allocations plus the bind and wire pass over a handful of
  nodes. Unmeasurable.
- **Network** — Not applicable.

Removing `reset_level_state()` also removes a per-restart call; the reload
dominates either way.

## Migration Plan

One atomic changeset — the 10 call sites cannot be migrated independently.

1. **New** `src/scripts/state/level_state.gd` (`class_name LevelState`) and
   `src/scripts/state/oxygen_state.gd` (`class_name OxygenState`).
2. **`gamemanager.gd`** — delete `goal_unlocked`, `plants_watered`, `plants_total`,
   `carrying_bucket` and `reset_level_state()`. Retain `player_lives` only.
3. **`main.gd`** (`LevelRoot`):
   - add `@export var oxygen_capacity: float` and `@export var hud: HUD`
   - `_ready()`: construct both state objects; bind into `player`, `goal`, `hud`,
     `OxygenDrain`; connect each `Plant.pour_completed` to
     `level_state.consume_bucket()`
   - line 33 — replace `plants_total = plants.size()` with `buckets_total` seeded
     from `LevelValidation.count_buckets()` (ADR-0003 D3.5 — **not** a group count;
     group-based discovery is forbidden by D3.2, registered as
     `group_based_level_discovery`). *(Amended 2026-08-15 — C2.)*
   - lines 46, 50 — read carry state from `level_state`
   - line 61 — delete the `reset_level_state()` call; `restart_level()` becomes
     `reload_current_scene()` alone
   - move the `GravityAuthority.reset_to(default_gravity_*)` call here (ADR-0001
     part 6 said `reset_level_state()`; that function no longer exists)
4. **`plant.gd`** — line 30, carry check via the injected path; lines 73-79, emit
   `pour_completed` and delete the `GameManager` write.
5. **`goal.gd`** — lines 25 and 40, read `goal_unlocked` from the injected
   `LevelState`; connect `goal_unlocked_changed`. Behaviour unchanged, per
   `watering-system.md` §6.
6. **`bucket.gd`** — line 7, delete the `GameManager.carrying_bucket` write. Carry
   state moves to the player component; the interaction model is ADR-0009's.
7. **All 8 level scenes** — author `oxygen_capacity` (derived per
   `suit-oxygen.md` R6, never guessed) and wire the `hud` export.
8. **`architecture.md`** — amend D2 to name `LevelRoot`; correct the init-order
   block and the `depleted` signal row.

**Regression watch**: the airlock must still unlock and the level must still
restart on spike death. `goal.gd` behaviour is explicitly unchanged — only the
source of the flag moves.

## Validation Criteria

Headless. Construct the objects directly; no `SceneTree`, no `Player`, no scene.

| # | Test | Source |
|---|---|---|
| V1 | `goal_unlocked` is false at `buckets_consumed == buckets_total - 1` and true at `== buckets_total` | `watering-system.md` R6, AC6 |
| V2 | `goal_unlocked` cannot be set externally; `buckets_consumed` never exceeds `buckets_total` | R6 |
| V3 | A fresh `LevelState` has `carrying_bucket == false` — the restart guarantee, with no `reset()` involved | `watering-system.md` AC8 |
| V4 | `OxygenState(0.0, tuning)` and a negative capacity both fail construction | `suit-oxygen.md` AC7 |
| V5 | `remaining` is strictly non-increasing across 10 000 `drain()` calls; no public path raises it | `suit-oxygen.md` R4, AC3 |
| V6 | With `drain_rate` 1.0, exactly `capacity` seconds of `drain()` reaches zero ±0.1 s | `suit-oxygen.md` AC6 |
| V7 | `depleted` emits exactly once across repeated `drain()` calls past zero | R3 |
| V8 | `threshold_changed` fires at 0.50, 0.25 and 0.10 and never re-fires a band already entered | `suit-oxygen.md` AC10 |
| V9 | A consumer that uses state before `bind()` raises an error and does not act | Init-order guard, part 3 |

Integration, requiring a scene: restart clears carry state and refills oxygen
(`watering-system.md` AC8, `suit-oxygen.md` AC4) — the end-to-end proof that
reconstruction actually happens on reload.

**This decision is correct if** every Logic AC in both GDDs can be written with no
engine scaffolding, and no test anywhere needs to call a reset function to get a
clean level.

## Related Decisions

- `docs/architecture/architecture.md` — binding decision **D2**, which this ADR
  deviates from and which must be amended; init-order block and signal table, both
  corrected here
- **ADR-0001** Gravity ownership — supplies the bind-guard pattern; its part 6 and
  one registry entry need the caller name corrected
- **ADR-0003** Level load validation — consumes `buckets_total` and
  `oxygen_capacity`; should add the "required consumers bound" check
- **ADR-0005** Frame ordering — owns when `level_complete` is read and written
- **ADR-0008** Oxygen drain and death path — owns `OxygenDrain` policy and the
  `level_complete` suppression
- **ADR-0009** Watering interaction model — owns carry state transitions and pour
  completion
- **ADR-0010** HUD — binds to both objects at init step 3c
- `design/gdd/watering-system.md` · `design/gdd/suit-oxygen.md`
