# Story 001: `LevelState` — the injectable level-scoped state object

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/watering-system.md` §3 R6, R8 · §8 AC6, AC8
**Requirement**: `TR-watering-006`, `TR-watering-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Level State Ownership and Injectable
State Objects *(primary)* · ADR-0005: Frame ordering and the `level_complete`
guard *(secondary — it owns when `level_complete` is read and written; this story
owns only that the field exists and how it is exposed)*

**ADR Decision Summary**: `LevelState` is a plain `RefCounted` object constructed
by `LevelRoot._ready()` — not an autoload, not a singleton, not reachable
globally. Every derived or externally-immutable value is a **getter-only computed
property over a private backing field**. It has no `reset()`: restart discards the
object and constructs a fresh one, which turns `watering-system.md` AC8 from a rule
review must police into a property of object lifetime.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. `RefCounted`, `_init()` argument passing and
signals are pre-4.4 and unchanged through 4.7. Two engine facts govern the shape:

- **A plain `var` in GDScript is a public field with an implicit setter.**
  `level_state.goal_unlocked = true` would compile, run and succeed silently from
  any script. Assignment to a getter-only property raises a runtime error instead.
  This was the single blocking finding of the 2026-08-14 specialist review (A2-01)
  — the original ADR text claimed a guarantee the language does not give. Implement
  the corrected text at `adr-0002-level-state-ownership.md:247-249` and `:291`
  verbatim. **Do not re-derive the mechanism from the pre-correction wording.**
- **gdUnit4 treats a GDScript warning as an error at test discovery.** One warning
  in this file fails the whole suite at compile time, not just this file's tests.
  `var x := <Variant expression>` is the shape that has bitten this project before —
  annotate the type explicitly.

**Control Manifest Rules (this layer)**:
- Required: "`LevelState` and `OxygenState` are plain `RefCounted` objects
  constructed by `LevelRoot._ready()`, never autoloads or singletons." — ADR-0002
- Required: "Every derived or externally-immutable field on `LevelState`/
  `OxygenState` is a getter-only computed property over a private backing field,
  never a plain `var`." — ADR-0002
- Required: "`consume_bucket()` is called only on a *completed* pour, never on
  pickup or early release." — ADR-0002
- Forbidden: "Never add `reset()` to `LevelState` or `OxygenState`, or reintroduce
  `GameManager.reset_level_state()`." — ADR-0002 (`level_state_reset_method`)
- Forbidden: "Never reach level or oxygen state through an autoload, a new
  singleton, or a service locator." — ADR-0002 (`global_level_state_access`)
- Forbidden: "`Plant` (or any single objective) must never write level-wide state
  or decide the level is complete." — ADR-0002 (`plant_decides_level_outcome`)

---

## Acceptance Criteria

*From `design/gdd/watering-system.md`, scoped to this story:*

- [ ] **AC6** — `goal_unlocked` becomes true exactly when `buckets_consumed`
      reaches `buckets_total`, and never before
- [ ] **AC8, lifetime half** — the type has no `reset()` and no way to clear state
      in place. *(The restart behaviour itself is story 006; this story makes the
      alternative unrepresentable.)*
- [ ] `buckets_consumed` never decreases and never exceeds `buckets_total`
- [ ] `buckets_total` is immutable after construction
- [ ] Assignment to `buckets_total`, `buckets_consumed`, `goal_unlocked` or
      `level_complete` from outside the class raises a runtime error rather than
      succeeding silently
- [ ] `carrying_bucket` is genuinely read-write — it is the one field that is not
      getter-only
- [ ] `bucket_consumed(consumed, total)` and `goal_unlocked_changed(unlocked)` are
      emitted, and `goal_unlocked_changed` fires once, on the transition only

---

## Implementation Notes

*Derived from ADR-0002 Key Interfaces (`:214-260`) and the A2-01 correction:*

The interface is specified in the ADR and should be implemented as written:

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

- **Callers must pass `buckets_total >= 0` at construction.** Zero is legal — a
  level with no plants is not a contract breach here, and `LevelValidation`
  (ADR-0003) owns level-authoring judgement, not this type.
- **`buckets_total` is seeded from `LevelValidation.count_buckets()`**, not from a
  group count. ADR-0003 D3.2 forbids group-based discovery outright, and D3.5
  requires `LevelRoot` and `validate()` to share the one counting primitive so
  `V-BUCKET-SUM` cannot pass while `LevelRoot` seeded a subtly different number.
  The *seeding* is story 004's work; this story only accepts the value.
- **The two independent sources are the point.** `buckets_total` counts bucket
  instances; `Σ plant.buckets_required` sums plant exports. Neither derives from
  the other, so their agreement is real evidence. `LevelState` must not compute one
  from the other.
- **`mark_complete()` is NOT in this story.** The field `_level_complete` and its
  getter are declared here; the write-once latch method and its sole caller are
  story 005, under ADR-0005 D5.3.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `OxygenState`. Same patterns, separate type, separate test file.
- **Story 004**: construction and injection by `LevelRoot`, and the `bind()` guard
  on each consumer. This story builds a type that can be constructed; nothing
  constructs it yet.
- **Story 005**: `mark_complete()`, the write-once latch, and the ordered goal
  handler. Declare the backing field and the getter here and stop.
- **Story 006**: `GameManager` reduction and the restart path.
- The `carrying_bucket` **consumer** logic in `PlayerWateringComponent` — Feature
  watering epic. This story provides the field, not its users.

---

## QA Test Cases

*Story type: **Logic** — automated test specs. The developer implements against
these and does not invent new ones during implementation.*

- **AC-1 — `goal_unlocked` flips exactly at the boundary**
  - Given: `LevelState.new(3)`
  - When: `consume_bucket()` is called 2 times, then a 3rd time
  - Then: `goal_unlocked` is `false` after 2 calls and `true` after the 3rd
  - Edge cases: `buckets_total == 0` — `goal_unlocked` must be `true` from
    construction, since `0 >= 0`. `buckets_total == 1` — one call flips it.

- **AC-2 — `goal_unlocked_changed` fires on the transition only**
  - Given: `LevelState.new(2)` with the signal recorded
  - When: `consume_bucket()` is called 2 times, then a 3rd time
  - Then: the signal was emitted exactly once, with `true`
  - Edge cases: a 4th call must not re-emit.

- **AC-3 — `buckets_consumed` is bounded**
  - Given: `LevelState.new(2)`
  - When: `consume_bucket()` is called 5 times
  - Then: `buckets_consumed` is 2, not 5 — it never exceeds `buckets_total`
  - Edge cases: it never decreases on any call sequence.

- **AC-4 — the getter-only properties refuse assignment**
  - Given: a constructed `LevelState`
  - When: a script assigns to `buckets_total`, `buckets_consumed`,
    `goal_unlocked` or `level_complete`
  - Then: the assignment fails at runtime rather than succeeding silently
  - Edge cases: **this is the A2-01 test and it is the reason this story exists.**
    If GDScript 4.7.1 does not behave as the corrected ADR text states, that is a
    finding to raise, not a test to soften. Probe it before writing the assertion —
    do not assume the failure mode from the ADR prose. `carrying_bucket` must
    remain assignable, so a passing test here must also show the negative control.

- **AC-5 — `bucket_consumed` carries both numbers**
  - Given: `LevelState.new(3)`
  - When: `consume_bucket()` is called once
  - Then: the signal carried `(1, 3)`

- **AC-6 — the type has no reset path**
  - Given: the `LevelState` script
  - When: its method list is inspected
  - Then: there is no `reset()`, no `clear()` and no setter for any counter
  - Edge cases: this is a structural assertion, not a behavioural one. It is worth
    writing because the forbidden pattern `level_state_reset_method` exists
    precisely because adding one looks like a reasonable convenience.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_state/level_state_test.gd` — must exist and pass

Run the documented headless command from `tests/README.md` — both binary paths,
`_console.exe`, `-c`, and **both** `-a res://tests/unit` and
`-a res://tests/integration`. Run `--headless --path . --import` first to generate
the new test file's `.uid` sidecar.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None. This is the epic's root story.
- Unlocks: Story 004 (nothing can be injected until it exists), Story 005 (the
  latch needs the backing field)
