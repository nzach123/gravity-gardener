# Story 002: Create the three tuning `Resource` scripts

> **Epic**: Tuning Resources
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/watering-system.md` §7 · `design/gdd/suit-oxygen.md` §7 ·
`design/gdd/physics-props.md` §7
**Requirement**: `TR-watering-013`, `TR-oxygen-011`, `TR-props-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: D6.1 requires three separate `Resource` subclasses —
`WateringTuning`, `OxygenTuning`, `PropTuning` — one per GDD, never combined into a
single `GameTuning`, because three classes make ownership structural rather than
inferred. D6.2 fixes their paths. D6.4 requires every knob to be `@export_range`
with the GDD-documented default and range **verbatim**.

**Engine**: Godot 4.7.1 | **Risk**: **HIGH** (project-level)
**Engine Notes**:
- **No post-cutoff API is used.** `Resource`, `class_name` and `@export_range` all
  predate the ~4.3 training coverage, and nothing in `breaking-changes.md` or
  `deprecated-apis.md` touches the Resource system across 4.4 → 4.7.
- The HIGH rating is because **no `modules/core.md` engine reference exists** — this
  domain has no curated in-repo snapshot. Verify any uncertain Resource-system API
  against the official 4.7 docs before writing code. Do not answer from training
  data; training coverage stops at roughly 4.3.
- **`@export_range` is an authoring-time constraint only** (T4, pending Story 001).
  Until Story 001 closes, treat every range as an inspector hint, not a validator.

**Control Manifest Rules (this layer)**:
- Required: "Three separate `Resource` subclasses — `WateringTuning`, `OxygenTuning`,
  `PropTuning` — one per GDD. Never combine into a single `GameTuning`." — source:
  ADR-0006 (D6.1)
- Required: "File layout: scripts in `src/scripts/tuning/`, authored data in
  `src/resources/tuning/`." — source: ADR-0006 (D6.2)
- Required: "Every tuning knob is `@export_range`, using the GDD-documented range
  verbatim." — source: ADR-0006 (D6.4)
- Forbidden: "Never create a `GravityTuning` resource, or relocate the jump constants
  off `Player`." — source: ADR-0006 (`gravity_tuning_resource`)
- Guardrail: gdUnit4 treats GDScript warnings as errors at test discovery — one
  warning fails the **entire** suite, not just these files. All three scripts must be
  warning-clean, including the unused-`class_name` and shadowing checks. Same caveat
  that applied to `collision_layers.gd` under ADR-0004.

---

## Acceptance Criteria

*From ADR-0006 D6.1, D6.2, D6.4 and Migration Plan steps 1-2:*

- [ ] `src/scripts/tuning/` and `src/resources/tuning/` exist.
- [ ] `src/scripts/tuning/watering_tuning.gd` declares `class_name WateringTuning
      extends Resource` with exactly these four knobs, defaults and ranges:
      `carry_speed_multiplier: float = 0.6` `@export_range(0.4, 0.9)`;
      `throw_arc_height: float = 120.0` `@export_range(60.0, 200.0)`;
      `throw_duration: float = 0.6` `@export_range(0.4, 0.8)`;
      `throw_angle_spread: float = 45.0` `@export_range(0.0, 90.0)`.
- [ ] `src/scripts/tuning/oxygen_tuning.gd` declares `class_name OxygenTuning
      extends Resource` with exactly these five knobs:
      `margin: float = 0.4` `@export_range(0.3, 0.6)`;
      `drain_rate: float = 1.0` `@export_range(0.5, 1.0)`;
      `threshold_caution: float = 0.50` `@export_range(0.0, 1.0)`;
      `threshold_warning: float = 0.25` `@export_range(0.0, 1.0)`;
      `threshold_critical: float = 0.10` `@export_range(0.0, 1.0)`.
- [ ] `src/scripts/tuning/prop_tuning.gd` declares `class_name PropTuning
      extends Resource` with exactly these three knobs:
      `prop_gravity_scale: float = 1.0` `@export_range(0.8, 1.2)`;
      `prop_max_speed: float = 2000.0` `@export_range(1000.0, 4000.0)`;
      `props_per_level_budget: int = 40` `@export_range(10, 80)`.
- [ ] **No knob outside those ten exists on any of the three classes.** In
      particular: `buckets_required` and `water_duration` are **not** on
      `WateringTuning`; `interact_radius` is **not** on it either; `oxygen_capacity`
      is **not** on `OxygenTuning`; `mass`, `friction`, `bounce`, `linear_damp` and
      `angular_damp` are **not** on `PropTuning`.
- [ ] Each script carries the D6.4 doc comment stating which knobs are deliberately
      absent and why, so a future author does not "complete" the set.
- [ ] No `GravityTuning` class is created (D6.7).
- [ ] All three scripts are warning-clean under gdUnit4's warnings-as-errors test
      discovery — confirmed by running the suite, not by inspection.
- [ ] All three files carry static types on every property (project standard).

---

## Implementation Notes

*Derived from ADR-0006 D6.1, D6.2, D6.4 and D6.7:*

- **Copy the D6.4 contracts verbatim from the ADR**, including the doc comments. The
  ADR has the exact text. Do not re-derive the numbers from the GDDs by hand — the
  ADR already reconciled them, and re-deriving is where a transcription error enters.
- The GDD ranges are the "Safe range" columns, unchanged. The three `threshold_*`
  knobs have **no GDD range**; they take `0.0-1.0`, which is the only range a
  fraction can have.
- **Do not add a combined `GameTuning`**, and do not add a shared base class for the
  three. D6.1 rejected a single surface on purpose: it would make "which module owns
  this value" un-answerable by inspection, the exact inference `architecture.md` P5
  forbids.
- **Do not add `GravityTuning`.** D6.7 makes this a standing ban. The jump constants
  stay `@export` on `Player` by explicit user decision, reaffirmed twice. Changing it
  requires superseding ADR-0001's `jump_constants_location`, not extending ADR-0006.
- `drain_rate` is documented in the GDD as an "accessibility hook only". It is still
  just the authored design default here. The player-facing accessibility setting is
  **user data, not design data**, and D6.6 assigned its composition to ADR-0008. Do
  not build anything for it in this story, and do not make the property writable.
- The unused-`class_name` warning is the likely trip hazard: these three classes have
  no consumer until Story 004 lands. Run the gdUnit4 suite after writing them and fix
  any warning before moving on. One warning fails discovery for every test in the
  project.
- These are the **scripts only**. The `.tres` files are Story 003.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the T4 spike. Do not add a code-side clamp on the strength of a guess
  about T4's outcome — wait for the observed result.
- Story 003: authoring the three `.tres` files and checking
  `resource_local_to_scene`.
- Story 004: `src/scripts/tuning/tuning.gd` and the `preload` constants. **No
  `preload` of a tuning `.tres` belongs in this story**, and no `.tres` path literal
  belongs in these three scripts.
- Story 005: the gdUnit4 validation suite that asserts these defaults.
- Any consumer work. ADR-0008 / ADR-0009 / ADR-0011 / ADR-0012 adopt `Tuning.*` as
  they land. **No consumer work is owed by this epic.**

---

## QA Test Cases

*Story type: **Config/Data**. These three scripts declare data, not logic, so their
gate is a smoke check here. The ten defaults are asserted for real by **V4 in Story
005** — that is where the automated proof lives. The cases below are what Story 005
must cover, recorded here so the two stories cannot drift apart.*

### Smoke check for this story

- [ ] The project opens in the Godot 4.7.1 editor with no script parse error.
- [ ] `WateringTuning`, `OxygenTuning` and `PropTuning` all appear in the editor's
      "Create New Resource" dialog — proof the `class_name` registration took.
- [ ] The gdUnit4 suite still discovers and runs. A discovery failure means one of
      the three scripts carries a warning.

### Cases owed to Story 005 (V4 — every default matches its GDD §7 default)

| # | Knob | Class | Expected default | Expected range |
|---|---|---|---|---|
| T2.1 | `carry_speed_multiplier` | `WateringTuning` | `0.6` | 0.4 - 0.9 |
| T2.2 | `throw_arc_height` | `WateringTuning` | `120.0` | 60 - 200 |
| T2.3 | `throw_duration` | `WateringTuning` | `0.6` | 0.4 - 0.8 |
| T2.4 | `throw_angle_spread` | `WateringTuning` | `45.0` | 0 - 90 |
| T2.5 | `margin` | `OxygenTuning` | `0.4` | 0.3 - 0.6 |
| T2.6 | `drain_rate` | `OxygenTuning` | `1.0` | 0.5 - 1.0 |
| T2.7 | `threshold_caution` | `OxygenTuning` | `0.50` | 0.0 - 1.0 |
| T2.8 | `threshold_warning` | `OxygenTuning` | `0.25` | 0.0 - 1.0 |
| T2.9 | `threshold_critical` | `OxygenTuning` | `0.10` | 0.0 - 1.0 |
| T2.10 | `prop_gravity_scale` | `PropTuning` | `1.0` | 0.8 - 1.2 |
| T2.11 | `prop_max_speed` | `PropTuning` | `2000.0` | 1000 - 4000 |
| T2.12 | `props_per_level_budget` | `PropTuning` | `40` (int) | 10 - 80 |

### Absence cases owed to Story 005

| # | Case | Expected |
|---|---|---|
| T2.13 | `WateringTuning` property list | Contains no `buckets_required`, `water_duration` or `interact_radius` |
| T2.14 | `OxygenTuning` property list | Contains no `oxygen_capacity` |
| T2.15 | `PropTuning` property list | Contains no `mass`, `friction`, `bounce`, `linear_damp` or `angular_damp` |
| T2.16 | No `GravityTuning` class is registered anywhere | D6.7 |

**These absence cases matter as much as the presence cases.** The failure they catch
is a well-meaning author "completing" a resource with a knob the ADR deliberately
placed on a node instead, which silently moves the tuning surface and breaks D6.1's
ownership guarantee with no error.

### Edge cases

- **`threshold_critical < threshold_warning < threshold_caution` ordering.** The
  three defaults satisfy it (0.10 < 0.25 < 0.50) and nothing enforces it. Story 005
  should assert the ordering on the authored values, so a later edit that inverts two
  thresholds fails loudly rather than producing silently wrong feedback escalation.
- **`props_per_level_budget` is an `int`, not a `float`.** Assert the type, not just
  the value. `V-PROP-BUDGET` compares a node count against it.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass recorded in `production/qa/smoke-[date].md`
- The automated proof of the ten defaults lands with Story 005
  (`tests/unit/tuning/tuning_resources_test.gd`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (soft). Story 001 tells you whether any knob needs a
  code-side clamp. Nothing here is blocked if Story 001 slips, but the ADR sequences
  it first and it is cheap.
- Unlocks: Story 003 (a `.tres` cannot be authored before its script exists)
