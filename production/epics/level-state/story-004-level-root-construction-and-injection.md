# Story 004: `LevelRoot` constructs both state objects and injects them

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/watering-system.md` §3 R6 · `design/gdd/suit-oxygen.md` §5
**Requirement**: `TR-watering-006`, `TR-oxygen-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Level State Ownership and Injectable
State Objects (part 3, part 4, part 5, and the Corrected initialisation order at
`:311-327`)

**ADR Decision Summary**: `LevelRoot._ready()` constructs `LevelState` and
`OxygenState` from its own `@export`s, then calls a `bind(...)` method on each
consumer. Because `_ready()` runs **bottom-up**, a consumer cannot read injected
state during its own `_ready()` — so every consumer refuses to operate before it is
bound, with `push_error()` and a mandatory early `return`. This corrects
`architecture.md`'s init-order block (line 391), which has `HUD._ready()` binding at
step 2, before `LevelRoot` creates the objects at step 3. Under bottom-up `_ready()`
that cannot work.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Four load-bearing facts, all verified in the 2026-08-14 engine
specialist review rather than recalled from training data:

- **`_ready()` is bottom-up, and autoloads run before the scene.** This is the
  whole reason `bind()` exists instead of consumers pulling state themselves.
- **Signal connections to a `RefCounted` are weak references** and do not keep it
  alive. This is what makes the `Plant.pour_completed` → `LevelState.consume_bucket()`
  wiring safe: the connection does not extend the state object's lifetime past the
  scene reload.
- **`push_error()` logs but does not pause execution.** It is a logging call, not
  an exception. Without the early `return` the consumer continues against an unset
  reference, producing a null dereference or a silent read of default field values
  instead of the refusal this decision promises.
- **`assert()` compiles out entirely in release exports**, so every bind guard in
  the project would silently vanish from the shipped build. Use `push_error()`.
  *(A2-02 — recorded so the substitution is not made later as an apparent cleanup.)*

**Control Manifest Rules (this layer)**:
- Required: "`LevelState` and `OxygenState` are plain `RefCounted` objects
  constructed by `LevelRoot._ready()`, never autoloads or singletons." — ADR-0002
- Required: "Every injected consumer must guard 'not bound' with `push_error()` and
  refuse to operate before `bind()` is called by `LevelRoot._ready()`." — ADR-0002
- Required: "Use `push_error()`, never `assert()`, for bind/initialize guards." —
  ADR-0001, ADR-0002
- Required: "Level-content discovery is by recursive `get_children()` type scan
  (`node is Plant`, etc.), **never** by group membership." A forgotten group
  assignment is invisible to validation and the level reports clean. — ADR-0003 (D3.2)
- Forbidden: "Never read `LevelState`/`OxygenState` in a consumer's own `_ready()`,
  or before `bind()` has run." — ADR-0002 (`state_access_before_bind`)
- Forbidden: "`Plant` (or any single objective) must never write level-wide state
  or decide the level is complete." — ADR-0002 (`plant_decides_level_outcome`)
- Forbidden: "Never discover plants/buckets/props via `get_nodes_in_group()`." —
  ADR-0003

---

## Acceptance Criteria

*From ADR-0002 part 3 and the corrected init order, and the GDD requirements they carry:*

- [ ] `LevelRoot._ready()` constructs `LevelState(buckets_total)` and
      `OxygenState(capacity, tuning)` from its own `@export`s, at step (a) — before
      any binding
- [ ] `buckets_total` is seeded from `LevelValidation.count_buckets()`, the same
      primitive `validate()` uses, and **not** from a group count
- [ ] `Player` / `PlayerWateringComponent`, `Goal`, `HUD` and `OxygenDrain` each
      receive their state through a `bind(...)` call from `LevelRoot._ready()`
- [ ] Every bound consumer refuses to operate before `bind()` has run, with
      `push_error()` **and** an early `return`
- [ ] Each `Plant.pour_completed` is connected by `LevelRoot` to
      `LevelState.consume_bucket()`; `Plant` receives no state object at all
- [ ] `OxygenDrain` is a child of `LevelRoot`, not of `Player`
- [ ] Every bound consumer is a descendant of `LevelRoot` *(the A2-03 invariant —
      see Implementation Notes)*
- [ ] The existing group-based discovery in `main.gd` for plants is replaced by a
      recursive type scan

---

## Implementation Notes

*Derived from ADR-0002 parts 3-5 and the corrected initialisation order:*

The corrected order, which supersedes `architecture.md` lines 386-397:

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

- **Step (b) is deliberately left unwired by this story, and the seam must be
  explicit.** Wiring `LevelValidation.validate()` into `LevelRoot._ready()` is
  **LV-005**, which is blocked on this epic — `LevelState` and `OxygenState` did
  not exist, and LV-005's actual subject is the *ordering* between `validate()` and
  their construction. Leave a named, commented insertion point at step (b) citing
  LV-005 and ADR-0003 D3.1, so that story is an insertion rather than a merge
  conflict. Note the ordering constraint it will assert: **`validate()` runs
  BEFORE the state objects are constructed**, reading only raw authored `@export`
  scene data (ADR-0003 D3.1). Do not pre-empt it by calling `validate()` here.
- **Steps (e) and (f) belong to the `gravity-authority` epic.** `main.gd` already
  does a version of both today, through groups and through the removed
  `Player.set_gravity()` path. Do not rewrite them here; this story's changes to
  `main.gd` are steps (a), (c) and (d), plus replacing the plants group scan.
- **The consumer table, from the ADR:**

  | Consumer | Receives | Reached via |
  |---|---|---|
  | `Player` / `PlayerWateringComponent` | `LevelState` | existing `@export var player` |
  | `Goal` | `LevelState` | existing `@export var goal` |
  | `HUD` | `LevelState`, `OxygenState` | new `@export var hud` |
  | `OxygenDrain` | `OxygenState` | child of `LevelRoot` |
  | `Plant` (each) | nothing | `pour_completed` → `LevelState.consume_bucket()`, connected by `LevelRoot` |

- **`HUD` and `OxygenDrain` do not exist yet.** `HUD` is the Presentation epic
  under ADR-0010; `OxygenDrain` is the Core `oxygen-drain` epic under ADR-0008.
  Bind the consumers that exist, and leave the two absent rows as commented,
  named seams the way step (b) is left. Do not invent stub nodes for them —
  a stub that binds successfully would make a later real consumer's missing
  `bind()` invisible.
- **The guard shape is exactly this, and the `return` is mandatory:**

  ```gdscript
  if not _bound:
      push_error("…")
      return
  ```

- **A2-03 invariant: every bound consumer must be a descendant of `LevelRoot`.**
  Reconstruction on restart works only because every strong holder is freed in the
  same synchronous teardown pass as `LevelRoot`. A persistent or cross-scene HUD
  would hold a stale `LevelState` with no error and no crash — `RefCounted` leaks
  are invisible and there is no watchdog. State this in a comment where `HUD` is
  bound, because the Presentation epic is the one most likely to break it.
- **`@export var next_level: PackedScene` and the camera exports on `main.gd` are
  not this story's concern.** Leave them alone.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Stories 001 and 002**: the two types themselves. This story constructs them.
- **Story 005**: `mark_complete()`, the latch, and the ordered goal handler.
  `main.gd`'s two existing `player_reached_goal` connections at lines 16-18 are
  story 005's to replace — do not touch them here.
- **Story 006**: `GameManager.reset_level_state()` deletion and the restart path.
  `main.gd:31` still calls it after this story; that is expected.
- **LV-005**: wiring `validate()` into step (b). Leave the seam, not the call.
- **`gravity-authority`**: steps (e) and (f), and the removal of the
  `zone.gravity_changed` → `player.set_gravity` wiring.
- **`OxygenDrain` and `HUD` themselves** — this story binds what exists and marks
  the seams for what does not.

---

## QA Test Cases

*Story type: **Integration** — automated test specs. These need a synthetic tree,
not a running game.*

- **AC-1 — construction happens at step (a), before any bind**
  - Given: a synthetic level tree with a `LevelRoot`, a `Player` and two `Plant`s
  - When: `LevelRoot._ready()` runs
  - Then: both state objects exist and each consumer's `bind()` received a
    non-null object
  - Edge cases: a consumer whose `_ready()` tried to read state must have failed
    loudly at that point, not silently read a default.

- **AC-2 — an unbound consumer refuses to operate**
  - Given: a consumer instantiated but never bound
  - When: an operation that needs state is called on it
  - Then: it emits `push_error()` and returns without touching the null reference
  - Edge cases: **assert the refusal, not just the happy path.** ADR-0002's Risks
    table calls this out by name: bottom-up `_ready()` makes reading-before-bind
    the natural mistake, so the test that matters is the negative one.

- **AC-3 — `buckets_total` is seeded from the shared counting primitive**
  - Given: a synthetic level with 3 `Bucket` nodes at varying tree depths, one of
    them **not** in any group
  - When: `LevelRoot._ready()` runs
  - Then: `level_state.buckets_total` is 3
  - Edge cases: this is the D3.5 requirement — `LevelRoot` and `validate()` must
    share one primitive, so `V-BUCKET-SUM` cannot pass while `LevelRoot` seeded a
    different number. The ungrouped bucket is the case a group scan gets wrong and
    a type scan gets right.

- **AC-4 — `Plant` writes no level state**
  - Given: a synthetic level with two `Plant`s
  - When: a plant emits `pour_completed`
  - Then: `LevelState.buckets_consumed` increments, and the `Plant` itself holds no
    reference to any state object
  - Edge cases: assert the connection was made by `LevelRoot`, not by the plant
    connecting itself — the forbidden pattern is `plant_decides_level_outcome`.

- **AC-5 — the state objects do not outlive the level**
  - Given: a bound consumer holding a strong reference
  - When: `LevelRoot` is freed
  - Then: the state objects are released
  - Edge cases: **`== null` is TRUE for a freed `Object` in a Variant on 4.7.1, and
    `value as Node` on a freed object RAISES.** A plain null check already catches a
    freed object; `as` is not a safe probe. Write the assertion accordingly — this
    was established on 2026-08-24 and is not worth rediscovering.

- **AC-6 — no group-based discovery remains for plants or buckets**
  - Given: `main.gd` after this story
  - When: it is read
  - Then: plant and bucket discovery is a recursive type scan
  - Edge cases: the `hazards` and `gravityzone` group scans in `main.gd` stay for
    now — they belong to other epics. Scope the assertion, or it fails on code this
    story is not allowed to change.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/level_state/level_root_injection_test.gd` — must exist and pass

The integration root is easy to leave out of a run. The documented command takes
**both** `-a res://tests/unit` and `-a res://tests/integration`; unit-only was the
documented command until 2026-08-24 and silently excluded 8 integration cases.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 and Story 002, both DONE. Nothing can be injected until
  both types exist.
- Unlocks: **LV-005** (its blocker was this epic), Story 005, and the Core
  `oxygen-drain` and Presentation HUD epics, which ADR-0002 blocks by name.
