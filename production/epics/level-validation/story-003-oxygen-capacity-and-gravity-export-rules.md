# Story 003: V-OXY-CAP and V-GRAV-EXPORT

> **Epic**: Level Load Validation
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` · `design/gdd/gravity.md`
**Requirement**: `TR-oxygen-008`, `TR-gravity-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0003 (primary) · ADR-0001 (secondary — delegates the
`default_gravity_*` presence check here by name) · ADR-0002 (secondary — its
`OxygenState._init` capacity guard is what forced the D3.1 reordering)

**ADR Decision Summary**: Both rules read `@export` values on `LevelRoot` before any
state object is constructed. `V-OXY-CAP` requires `oxygen_capacity > 0`; a
non-positive capacity means instant death on spawn. `V-GRAV-EXPORT` requires
`default_gravity_direction` to be non-zero **and** `default_gravity_multiplier > 0`;
without them a restart inherits the gravity the player died under.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Per **E1**, `@export` values are set by `PackedScene.instantiate()`
before `_ready()` and without a `SceneTree`, so both rules are testable on a level
that was instantiated and never added to the tree. Per **F10**, a single GDScript
warning fails the whole gdUnit4 suite at discovery.

**Control Manifest Rules (this layer)**:

- Required: "`LevelValidation.validate()` runs BEFORE `LevelState`/`OxygenState` are
  constructed, reading only raw authored `@export` scene data." — source: ADR-0003 (D3.1)
- Required: "`OxygenState._init(capacity, tuning)` validates `capacity > 0` at
  construction. A non-positive capacity is not constructible." — source: ADR-0002
- Required: "Every level must declare `default_gravity_direction` /
  `default_gravity_multiplier` exports on `LevelRoot`." — source: ADR-0001, amended
  by ADR-0002
- Required: "`validate()` returns a `PackedStringArray` of coded findings."
  — source: ADR-0003 (D3.4)
- Forbidden: "`LevelValidation.validate()` must never return on the first breach."
  — source: ADR-0003 (`validation_first_failure_return`)
- Forbidden: "Never reach level or oxygen state through an autoload, a new
  singleton, or a service locator." — source: ADR-0002 (`global_level_state_access`).
  Relevant here: `validate()` takes the level as a parameter and reads exports, never
  a constructed `OxygenState`.
- Required: "No `OS.is_debug_build()` guard on validation — it runs in every build,
  including release." — source: ADR-0003 (D3.6)

---

## Acceptance Criteria

*From `suit-oxygen.md` §5 and AC7, `gravity.md` R7, ADR-0001 and ADR-0003 D3.1/D3.3,
scoped to this story:*

- [ ] `V-OXY-CAP` fires when `LevelRoot.oxygen_capacity <= 0`, in the ADR-0003 D3.4
      shape: `[V-OXY-CAP] oxygen_capacity is 0.0; must be > 0 (suit-oxygen.md §5)`.
- [ ] `V-GRAV-EXPORT` fires when `default_gravity_direction` is the zero vector.
- [ ] `V-GRAV-EXPORT` fires when `default_gravity_multiplier <= 0`.
- [ ] A level breaching both gravity conditions returns a finding naming both, or two
      findings — pick one and assert it; do not return only the first condition
      found.
- [ ] Both rules read the exports via `Node.get()` and treat an **absent** export as
      a breach of the same rule, with a finding that says the export is missing
      rather than reporting a misleading value. See Implementation Notes — this is a
      decision this story makes, not one ADR-0003 states.
- [ ] A level breaching `V-OXY-CAP` and `V-GRAV-EXPORT` together returns findings for
      both in one call.
- [ ] A clean level returns empty from `validate()`.
- [ ] `grep -n "is_debug_build" src/scripts/level_validation.gd` still returns nothing
      (ADR-0003 Validation Criterion 3).
- [ ] `level_validation.gd` and the test file are warning-clean under the headless
      gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0003 D3.1, D3.3 and ADR-0001:*

**Why these rules read raw exports rather than state objects.** `architecture.md`
originally ordered `LevelRoot._ready()` as construct-state-then-validate. ADR-0003
D3.1 corrects that ordering, and `V-OXY-CAP` is the reason: ADR-0002 makes
`OxygenState._init` reject `capacity <= 0`, so on a level with a mis-authored
capacity the construction fails *before* validation ever runs. The one input the
rule exists to describe is the one input on which it would never execute. Do not
reintroduce a read of `OxygenState` here for any reason.

**On absent exports.** `main.gd` today declares neither `oxygen_capacity` nor
`default_gravity_*` — those exports arrive with the `level-state` and
`gravity-authority` epics. `validate()` takes `level: Node`, so reading a missing
property is a runtime error, not a parse error. Use `level.get("oxygen_capacity")`
and check for `null` before comparing. An absent export is a genuine authoring
breach of the same rule — a level with no `oxygen_capacity` is exactly as broken as
one with a zero — so report it under the same code, with message text that
distinguishes the two cases for the human reading the log. ADR-0003 does not state
this; it is recorded here so a reviewer sees a decision rather than an accident.

**Both gravity conditions are one rule with two clauses.** ADR-0003 D3.3 defines
`V-GRAV-EXPORT` as "direction is non-zero **and** multiplier > 0". Whether a level
breaching both gets one finding or two is unstated. Either satisfies the contract;
pick one, make the test assert it, and keep it consistent so the log is predictable.

**Float comparison.** `oxygen_capacity` and `default_gravity_multiplier` are floats.
Compare against `0.0` directly rather than with an epsilon — the rule is a sign
check, not an equality check, and a capacity of `0.0001` is a design problem for the
oxygen GDD to bound, not a validation problem.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the scaffold, the recursive scan, the code constants.
- **Story 002**: `V-BUCKET-SUM` and `V-PLANT-MIN`.
- **Story 004**: `V-WIRING`, and the combined all-rules-fire-at-once test.
- **Story 005**: the `LevelRoot._ready()` call site and the `push_error` loop.
- **The `level-state` epic (ADR-0002)**: adding `@export var oxygen_capacity` to
  `LevelRoot`, and constructing `OxygenState`. This story reads the export
  defensively and does not author it.
- **The `gravity-authority` epic (ADR-0001)**: adding the `default_gravity_*` exports
  and calling `GravityAuthority.reset_to()`. Same reasoning.
- **The level migration epic**: giving all 8 shipped levels these exports. Every
  level currently fails both rules and that is expected until then.

---

## QA Test Cases

*Derived from `suit-oxygen.md` AC7, `gravity.md` R7 and ADR-0003 Validation Criteria
1, 2 and 3. The developer implements against these — do not invent new test cases
during implementation.*

**Test file**: `tests/unit/level/level_validation_root_export_rules_test.gd`

Build the synthetic level root from a small test-only script that declares the
exports, so the tests do not wait on `level-state` or `gravity-authority`.

- **AC-1**: `V-OXY-CAP` fires on a non-positive capacity
  - Given: a synthetic level root with `oxygen_capacity = 0.0`
  - When: `validate(level)` is called
  - Then: exactly one finding starts with `[V-OXY-CAP]`
  - Edge cases: a negative capacity (`-5.0`) must also fire; a small positive value
    (`0.1`) must **not** fire

- **AC-2**: `V-OXY-CAP` fires when the export is absent entirely
  - Given: a synthetic level root that declares no `oxygen_capacity` property
  - When: `validate(level)` is called
  - Then: one `[V-OXY-CAP]` finding is returned, and its message identifies the
    export as missing rather than reporting a value
  - Edge cases: this must not raise a runtime error — the `get()` guard is the point

- **AC-3**: `V-GRAV-EXPORT` fires on a zero direction
  - Given: a synthetic level root with `default_gravity_direction = Vector2.ZERO`
    and `default_gravity_multiplier = 1.0`
  - When: `validate(level)` is called
  - Then: a `[V-GRAV-EXPORT]` finding is returned
  - Edge cases: a non-axis-aligned non-zero direction such as `Vector2(0.3, -0.7)`
    must **not** fire — the rule checks non-zero, not normalised

- **AC-4**: `V-GRAV-EXPORT` fires on a non-positive multiplier
  - Given: a synthetic level root with a valid direction and
    `default_gravity_multiplier = 0.0`
  - When: `validate(level)` is called
  - Then: a `[V-GRAV-EXPORT]` finding is returned
  - Edge cases: a negative multiplier must fire; `0.5` must not

- **AC-5**: both rules report in one pass
  - Given: a synthetic level root breaching `V-OXY-CAP` **and** `V-GRAV-EXPORT`
  - When: `validate(level)` is called
  - Then: the result contains at least one of each code
  - Edge cases: this is the no-early-return guard

- **AC-6**: a clean root returns empty
  - Given: a synthetic level root with `oxygen_capacity = 90.0`,
    `default_gravity_direction = Vector2.DOWN`, `default_gravity_multiplier = 1.0`,
    and no plants or buckets
  - When: `validate(level)` is called
  - Then: the result is empty
  - Edge cases: none

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level/level_validation_root_export_rules_test.gd`
— must exist and pass. This test file is the automated evidence for
`suit-oxygen.md` AC7, which is typed **Logic** and is therefore a BLOCKING gate
under `.claude/docs/coding-standards.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: **Story 001** must be DONE. Story 002 is independent of this one and
  the two may be taken in either order.
- Unlocks: Story 005. Also supplies `gravity-authority` and `level-state` with a
  load-time gate for the exports they add.
