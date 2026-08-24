# Story 005: Headless gdUnit4 validation suite — V1-V4 and V9

> **Epic**: Tuning Resources
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/physics-props.md` §7 · `design/gdd/suit-oxygen.md` §7 ·
`design/gdd/watering-system.md` §7
**Requirement**: `TR-props-009`, `TR-oxygen-011`, `TR-watering-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: Migration Plan step 5 requires V1-V4 and V9 to run as a
headless gdUnit4 test **before any consumer depends on this**. Two are load-bearing:
**V2** (assert resolution inside a test that instantiates a level scene and never
adds it to the tree) and **V1** (assert `is PropTuning`, not merely non-null,
because of GH#73615).

**Engine**: Godot 4.7.1 | **Risk**: **HIGH** (project-level)
**Engine Notes**:
- **T2 — VERIFIED TRUE**: `preload()` resolves with no `SceneTree` involvement at
  all. V2 is the test that proves this holds in practice on the ADR-0003 path.
- **T3 — VERIFIED TRUE**: Godot caches resources by path, so two reads yield the same
  object. V3 asserts it.
- **GH#73615**: a `preload()`ed resource can resolve **non-null yet be the wrong
  type**. The bug class presents as a *type* failure on a non-null object, which a
  null check would pass. This is why V1 asserts type identity.
- V2's mechanism is **different from ADR-0003's E1/E2**, which concern `@export`
  values surviving `PackedScene.instantiate()` without `_ready()`. D6.3 does not
  depend on E1/E2; the two facts are independent and both hold. Do not conflate them
  when writing the test.
- **No post-cutoff API is involved.**

**Control Manifest Rules (this layer)**:
- Required: "`resource_local_to_scene` stays `false` on all three tuning `.tres`
  files." — source: ADR-0006 (D6.9)
- Required: the ADR-0004 precedent — assert derived invariants, not incidental
  values, so a test does not break the moment something unrelated is legitimately
  added.
- Guardrail: gdUnit4 treats GDScript warnings as errors at test discovery — one
  warning fails the **entire** suite. This test file and all four scripts from
  Stories 002 and 004 must be warning-clean.

---

## Acceptance Criteria

*From ADR-0006 Validation Criteria V1-V4 and V9, and Migration Plan step 5:*

- [ ] `tests/unit/tuning/tuning_resources_test.gd` exists and runs headless via
      `godot --headless --script tests/gdunit4_runner.gd`.
- [ ] **V1 — type identity.** `Tuning.PROP is PropTuning`, `Tuning.OXYGEN is
      OxygenTuning`, `Tuning.WATERING is WateringTuning`. Asserted as `is`, **not**
      as a non-null check. This is the GH#73615 guard and it is load-bearing.
- [ ] **V2 — null-tree resolution.** `Tuning.PROP` resolves inside a static call on a
      scene that was instantiated via `PackedScene.instantiate()` and **never added
      to the tree**. The test asserts `get_tree() == null` on that instance, then
      reads `Tuning.PROP` successfully. This is the ADR-0003 `LevelValidation` path
      and it is the second load-bearing case.
- [ ] **V3 — cache identity.** Two independent reads of `Tuning.PROP` return the same
      instance, asserted by object identity (`==` on the object reference or
      `get_instance_id()`), not by field-by-field comparison.
- [ ] **V4 — every default matches its GDD §7 default exactly.** All ten global knobs
      asserted: four on `WateringTuning`, five on `OxygenTuning`, three on
      `PropTuning` (twelve values in total across the three classes).
- [ ] **V9 — `resource_local_to_scene` is `false`** on all three resources.
- [ ] The absence cases from Story 002 are asserted: no `buckets_required`,
      `water_duration` or `interact_radius` on `WateringTuning`; no
      `oxygen_capacity` on `OxygenTuning`; no `mass` / `friction` / `bounce` /
      `linear_damp` / `angular_damp` on `PropTuning`; no `GravityTuning` class
      registered anywhere.
- [ ] `props_per_level_budget` is asserted to be an **`int`**, not a float.
- [ ] The threshold ordering `threshold_critical < threshold_warning <
      threshold_caution` is asserted on the authored values.
- [ ] The suite is green on the current codebase once Stories 002-004 have landed.
- [ ] The suite **fails** when each of these is deliberately introduced on a scratch
      branch, verified by hand once and then reverted:
      - `resource_local_to_scene = true` on any one `.tres` (V9)
      - Any one knob edited off its GDD default (V4)
      - A `.tres` re-pointed at the wrong script, so the type is wrong but the object
        is non-null (V1)
- [ ] The test file and all four tuning scripts are warning-clean under gdUnit4's
      warnings-as-errors discovery.

---

## Implementation Notes

*Derived from ADR-0006 Validation Criteria and Migration Plan step 5:*

- **V1 is the most important assertion in this file, and the easiest to write
  wrongly.** `assert_that(Tuning.PROP).is_not_null()` passes on exactly the bug
  GH#73615 produces. Assert the type. If the test framework makes `is` awkward,
  assert `Tuning.PROP.get_script()` resolves to `prop_tuning.gd` as well — but never
  instead.
- **V2 must genuinely have a null tree.** Instantiate a level scene with
  `PackedScene.instantiate()`, assert `instance.get_tree() == null` first, and only
  then read `Tuning.PROP`. A test that reads `Tuning.PROP` from an ordinary test
  method proves nothing about the `LevelValidation` path. Free the instance
  afterwards — an orphaned node leaks and gdUnit4 will report it.
- **V3 asserts object identity, not equality.** Comparing ten field values would pass
  even if the cache had handed out two separate copies, which is exactly the failure
  D6.9 exists to prevent.
- **V9 is cheap and catches an otherwise invisible failure.** Assert
  `resource_local_to_scene == false` on all three. If it is ever `true`, T3's cache
  identity stops holding, "exactly one instance project-wide" quietly becomes false,
  and D6.5's read-only reasoning stops describing reality — with no error and no log.
- Follow the ADR-0004 precedent: assert **derived invariants** where possible. The
  threshold ordering is a derived invariant; the twelve raw defaults are not, and
  must be asserted literally — the exact number **is** the point, which is the
  documented exception to the no-hardcoded-data rule in the coding standards.
- Read the GDD defaults from the ADR's D6.4 block, not from memory.
- **Do not test the consumers.** No `GravityAuthority`, no `LevelValidation`, no
  `OxygenState`. None of them exists yet, and none is owed by this epic.
- Put the file in `tests/unit/tuning/`. `tests/unit/` currently holds `gamemanager/`
  and `gravity/`; follow that per-system convention.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the T4 spike. Its evidence is a document, not a committed test. **Do not
  add a test asserting that `@export_range` does or does not clamp** — that is an
  engine behaviour, not this project's contract.
- Story 004: the accessor's own shape checks (three constants, no behaviour, not an
  autoload). If those would overlap this file, fold them in here rather than
  duplicating them — but the accessor story owns writing them.
- Story 006: V6, V7 and V8. Those are **CI greps, not gdUnit4 tests**. Do not fold
  them into this file.
- **V5** — `V-PROP-BUDGET` returning a finding when a level exceeds the budget. That
  belongs to ADR-0003's validation suite in the `level-validation` epic, not here.
  ADR-0003's six-rule set is unchanged by ADR-0006, and D3.3 stays frozen.

---

## QA Test Cases

*Story type: **Logic**. Test file: `tests/unit/tuning/tuning_resources_test.gd`. This
story's implementation **is** its test evidence.*

### Group 1 — V1, type identity (GH#73615 guard)

| # | Case | Expected |
|---|---|---|
| T5.1 | `Tuning.PROP` | `is PropTuning` |
| T5.2 | `Tuning.OXYGEN` | `is OxygenTuning` |
| T5.3 | `Tuning.WATERING` | `is WateringTuning` |

**Assert the type, never merely non-null.** The bug this guards against presents as a
type failure on a non-null object, so a null check reports green on the exact defect.

### Group 2 — V2, null-tree resolution (the ADR-0003 path)

| # | Case | Expected |
|---|---|---|
| T5.4 | A level scene instantiated with `PackedScene.instantiate()` | `instance.get_tree() == null` — asserted first, as the precondition |
| T5.5 | `Tuning.PROP` read from a static call in that context | Resolves, and `is PropTuning` |
| T5.6 | The instance is freed at teardown | No orphan node reported by gdUnit4 |

*T5.4 is not optional scaffolding. Without it the test proves nothing — it would pass
just as well from an ordinary test method with a live tree.*

### Group 3 — V3, cache identity

| # | Case | Expected |
|---|---|---|
| T5.7 | Two independent reads of `Tuning.PROP` | Same object — identity, not field equality |
| T5.8 | Same for `OXYGEN` and `WATERING` | Same object |

### Group 4 — V4, every default matches GDD §7

| # | Knob | Expected | Type |
|---|---|---|---|
| T5.9 | `WATERING.carry_speed_multiplier` | `0.6` | float |
| T5.10 | `WATERING.throw_arc_height` | `120.0` | float |
| T5.11 | `WATERING.throw_duration` | `0.6` | float |
| T5.12 | `WATERING.throw_angle_spread` | `45.0` | float |
| T5.13 | `OXYGEN.margin` | `0.4` | float |
| T5.14 | `OXYGEN.drain_rate` | `1.0` | float |
| T5.15 | `OXYGEN.threshold_caution` | `0.50` | float |
| T5.16 | `OXYGEN.threshold_warning` | `0.25` | float |
| T5.17 | `OXYGEN.threshold_critical` | `0.10` | float |
| T5.18 | `PROP.prop_gravity_scale` | `1.0` | float |
| T5.19 | `PROP.prop_max_speed` | `2000.0` | float |
| T5.20 | `PROP.props_per_level_budget` | `40` | **int** — assert the type too |

### Group 5 — V9, `resource_local_to_scene`

| # | Case | Expected |
|---|---|---|
| T5.21 | `Tuning.WATERING.resource_local_to_scene` | `false` |
| T5.22 | `Tuning.OXYGEN.resource_local_to_scene` | `false` |
| T5.23 | `Tuning.PROP.resource_local_to_scene` | `false` |

### Group 6 — absence cases (from Story 002)

| # | Case | Expected |
|---|---|---|
| T5.24 | `WateringTuning` property list | No `buckets_required`, `water_duration`, `interact_radius` |
| T5.25 | `OxygenTuning` property list | No `oxygen_capacity` |
| T5.26 | `PropTuning` property list | No `mass`, `friction`, `bounce`, `linear_damp`, `angular_damp` |
| T5.27 | Global class list | No `GravityTuning` registered (D6.7) |

### Group 7 — derived invariants

| # | Case | Expected |
|---|---|---|
| T5.28 | Threshold ordering | `threshold_critical < threshold_warning < threshold_caution` |

### Edge cases

- **Float comparison.** Use the framework's approximate float assertion for the
  twelve defaults. An exact `==` on `0.10` is a source of intermittent failure, and
  the coding standards forbid non-deterministic tests.
- **Zero-iteration false pass.** Any assertion written as a loop over a property list
  must also assert the expected count, so an empty or broken list fails loudly
  instead of reporting green.
- **Test-order independence.** These resources are process-wide singletons by design
  (T3). If any test ever writes to one, every later test is polluted. **No test in
  this file may assign to a tuning property** — that would violate D6.5 from inside
  the suite meant to protect it.
- **Orphan nodes from V2.** Free the instantiated scene in teardown.

### Manual verification — REQUIRED, blocking

**These three negative checks are the only proof the suite can actually fail.** A
green invariant test that cannot go red is worse than no test. Verify each by hand on
a scratch branch, confirm the failure, then revert:

- [ ] `resource_local_to_scene = true` on one `.tres` → group 5 fails
- [ ] One knob edited off its GDD default → group 4 fails
- [ ] A `.tres` re-pointed at the wrong script → group 1 fails, **and a null check
      would have passed** — confirm this explicitly, because it is the whole reason
      V1 is written as a type assertion

Record all three results in the story's completion notes.

**Estimated test count**: ~28 assertions across 7 groups, plus 3 manual negative
checks.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tuning/tuning_resources_test.gd` — must exist and pass headless

This story's implementation **is** its own test evidence. The scratch-branch negative
checks are a one-time manual verification during implementation, not a committed
artifact.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002, Story 003 and Story 004 (all hard — the suite asserts
  against all four scripts and all three `.tres` files)
- Unlocks: consumer adoption of `Tuning.*` under ADR-0008 / ADR-0009 / ADR-0011 /
  ADR-0012, and the `level-validation` epic's `V-PROP-BUDGET` work (sprint task
  LV-2). **ADR-0006 requires this suite to be green before any consumer depends on
  the tuning resources.**
