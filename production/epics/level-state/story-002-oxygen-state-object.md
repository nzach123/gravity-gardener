# Story 002: `OxygenState` — capacity validated at construction, drain-only

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §3 R2, R4, R5, R7 · §4 · §5 · §8 AC3, AC4,
AC5, AC6, AC7, AC10
**Requirement**: `TR-oxygen-005`, `TR-oxygen-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Level State Ownership and Injectable
State Objects

**ADR Decision Summary**: `OxygenState` is a plain `RefCounted` taking capacity and
tuning **at construction**, not through a later `configure()` call. An
`OxygenState` with a non-positive capacity is therefore not constructible, which
makes `suit-oxygen.md` AC7's failure mode unreachable at runtime. `remaining` is
getter-only with no setter, no refill and no `reset()`, which is what makes AC3
("no game action increases oxygen") a property of the type rather than a rule
review must police.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Same two engine facts as story 001 apply —
a plain `var` compiles a public setter (A2-01), and gdUnit4 fails the whole suite
on one GDScript warning at discovery. One addition specific to this type:

- **`OxygenTuning` is reached as `Tuning.OXYGEN`, and the tuning resource is
  read-only at runtime.** Never assign to any property of it, and never call
  `.duplicate()` on it. CI enforces the literal shapes of both (ADR-0006 V7, the
  step added by `tuning-resources` story 006), and the ADR is honest that the grep
  is partial: an alias or a `set()` by string name passes it. The ban is real
  regardless of what the grep catches.
- **`@export_range` does not clamp and does not reject a hand-edited `.tres`.**
  Verified against the 4.7.1 binary on 2026-08-24 — see
  `production/qa/evidence/t4-export-range-clamp-spike.md`. Every `@export_range`
  is an inspector hint, not a validator. If a band threshold or a drain rate must
  hold a range at runtime, clamp it in code.

**Control Manifest Rules (this layer)**:
- Required: "`OxygenState._init(capacity, tuning)` validates `capacity > 0` at
  construction. A non-positive capacity is not constructible." — ADR-0002
- Required: "Every derived or externally-immutable field on `LevelState`/
  `OxygenState` is a getter-only computed property over a private backing field,
  never a plain `var`." — ADR-0002
- Forbidden: "Never add `reset()` to `LevelState` or `OxygenState`." — ADR-0002
  (`level_state_reset_method`)
- Forbidden: "Never connect `OxygenState.depleted` directly to
  `LevelRoot.restart_level()`" — breaks `suit-oxygen.md` AC8; `OxygenDrain` owns
  the kill policy and the `level_complete` suppression. — ADR-0002
  (`depleted_wired_to_restart`)
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`, and never call `.duplicate()` on a tuning resource." — ADR-0006
  (`tuning_resource_runtime_mutation`)

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md`, scoped to this story:*

- [ ] **AC3** — no game action increases `remaining`. There is no setter, no
      refill and no `reset()`
- [ ] **AC6, arithmetic half** — with `drain_rate` 1.0, draining a fixed timestep
      repeatedly for `capacity` seconds of accumulated delta brings `remaining` to
      exactly zero, within float tolerance. *(The wall-clock half is the
      `oxygen-drain` epic — this story owns the arithmetic, not the loop.)*
- [ ] **AC7** — an `OxygenState` cannot be constructed with `capacity <= 0`
- [ ] **AC4 / AC5, lifetime half** — the type has no way to refill or reset in
      place, so "restart refills" and "oxygen does not carry between levels"
      hold by object lifetime. *(The restart behaviour itself is story 006.)*
- [ ] **AC10, logic half** — `threshold_changed` fires at the `OxygenTuning`
      bands (0.50 / 0.25 / 0.10) and never re-fires for a band already entered.
      *(The feedback the player sees is the Presentation HUD epic.)*
- [ ] `depleted` emits exactly once
- [ ] `drain()` is unconditional — it contains no state checks, so no caller can
      construct a safe state (`suit-oxygen.md` R2, AC1)
- [ ] Assignment to `capacity`, `remaining`, `fraction` or `band` from outside the
      class raises a runtime error rather than succeeding silently

---

## Implementation Notes

*Derived from ADR-0002 Key Interfaces (`:262-320`):*

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

- **`drain()` carries no policy.** It decrements, updates the band, and emits.
  It does not decide anything about death. `depleted` is a pure **state** signal
  meaning "the tank is empty" — `OxygenDrain` owns the decision to kill, including
  the `level_complete` suppression AC8 requires. `architecture.md`'s signal table
  (line 326) wires `depleted` straight to `LevelRoot.restart_level()` and is wrong;
  that wiring is a registered forbidden pattern.
- **`drain()` is unconditional by design.** It must not check `if remaining > 0`
  and skip, or check a paused flag, or check anything else. Every such check is a
  state in which a caller could stop the clock, which is exactly what
  `suit-oxygen.md` R2 forbids. Freezing the drain on completion is `OxygenDrain`'s
  job (ADR-0005 D5.6) and it is done by not calling `drain()`, not by `drain()`
  refusing.
- **Clamp `_remaining` at zero** so `fraction` cannot go negative, but do this
  without introducing a conditional that changes whether the emit happens — the
  `depleted` signal must fire exactly once on the crossing, not once per call
  thereafter.
- **Band thresholds come from `OxygenTuning`**, read at construction. Do not
  hardcode 0.50 / 0.25 / 0.10 in this file; they are the tuning resource's values
  and `tuning_resources_test.gd` already asserts their defaults and types.
- **Construction failure needs a decided shape.** GDScript cannot fail an `_init()`
  by returning an error. Decide between `push_error()` plus a poisoned object and
  `assert()` — and note that the manifest requires `push_error()`, never
  `assert()`, for guards, because `assert()` compiles out entirely in release
  exports. `LevelValidation` (ADR-0003 `V-OXY-CAP`) reports the same breach at
  load time, because authoring feedback needs all failures at once rather than the
  first crash. **Record the chosen shape in the story's completion notes** — the
  ADR states the constraint but does not pick the mechanism.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `LevelState`.
- **Story 004**: construction and injection by `LevelRoot`.
- **`OxygenDrain` entirely** — the per-frame `drain()` caller, the arm-and-defer
  death evaluation (ADR-0005 D5.2) and the completion freeze (D5.6). That is the
  Core `oxygen-drain` epic under ADR-0008. This story builds the state it drives.
- **The accessibility drain-rate override** — ADR-0008.
- **HUD readout and threshold feedback** — `suit-oxygen.md` AC9 and the visible
  half of AC10, Presentation HUD epic under ADR-0010.

---

## QA Test Cases

*Story type: **Logic** — automated test specs.*

- **AC-1 — non-positive capacity is not constructible**
  - Given: nothing
  - When: `OxygenState.new(0.0, tuning)` and `OxygenState.new(-1.0, tuning)`
  - Then: construction fails in the shape chosen in Implementation Notes, and does
    not silently produce a usable object
  - Edge cases: a very small positive capacity (`0.0001`) must succeed — the rule
    is `> 0`, not "above some sensible floor".

- **AC-2 — draining to exactly zero**
  - Given: `OxygenState.new(10.0, tuning)` with `drain_rate` 1.0
  - When: `drain(1.0 / 60.0)` is called 600 times
  - Then: `remaining` is 0.0 within float tolerance and `fraction` is 0.0
  - Edge cases: one more call must leave `remaining` at 0.0, not negative.

- **AC-3 — `depleted` emits exactly once**
  - Given: `OxygenState.new(1.0, tuning)` with the signal recorded
  - When: `drain()` is called enough times to pass zero, then 10 more times
  - Then: the signal was emitted exactly once
  - Edge cases: a single oversized `drain(999.0)` that jumps straight past zero
    from full must still emit exactly once.

- **AC-4 — band transitions fire once per band, in order**
  - Given: `OxygenState.new(100.0, tuning)` with `threshold_changed` recorded
  - When: oxygen is drained continuously from full to zero
  - Then: the recorded bands are `CAUTION`, `WARNING`, `CRITICAL` in that order,
    one emit each
  - Edge cases: a single `drain()` large enough to cross two bands at once. Decide
    and test whether that emits both or only the final band — the GDD does not say,
    so **pick the behaviour, assert it, and record the choice in the completion
    notes as a decision rather than a discovery.**

- **AC-5 — `remaining` never increases by any path**
  - Given: a constructed `OxygenState`
  - When: a script assigns to `remaining`, `capacity`, `fraction` or `band`
  - Then: the assignment fails at runtime
  - Edge cases: as in story 001's AC-4 — probe the actual 4.7.1 behaviour before
    writing the assertion. Also assert `drain(-1.0)` cannot be used as a refill.
    **A negative delta is the obvious back door into AC3** and the GDD does not
    mention it.

- **AC-6 — `drain()` holds no state checks**
  - Given: the `OxygenState` script
  - When: `drain()` is read
  - Then: it contains no conditional that lets a caller skip the decrement
  - Edge cases: structural, like story 001's AC-6. The clamp at zero is permitted;
    a guard that returns early on some external condition is not.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Two boundary decisions that must be decided and asserted, not looked up:**
  1. A drain step landing **exactly** on a band boundary (0.50 / 0.25 / 0.10) —
     which side does the boundary belong to? Pick, document, assert.
  2. A single `drain()` large enough to **cross two bands at once** — one
     `threshold_changed` emission, or two? Either is defensible; an
     undocumented choice is not.
- **AC6's arithmetic half**: state the float tolerance explicitly. Do not use a
  bare `==` against zero.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_state/oxygen_state_test.gd` — must exist and pass

Same runner notes as story 001: `--import` first, both binary paths,
`_console.exe`, `-c`, and both `-a` roots.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None directly. `OxygenTuning` and `Tuning.OXYGEN` already exist —
  they landed with the `tuning-resources` epic in commit `b8dba3c`.
- Unlocks: Story 004 (injection), and the Core `oxygen-drain` epic, which cannot
  start without this type.
