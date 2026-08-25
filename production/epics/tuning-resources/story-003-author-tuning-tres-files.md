# Story 003: Author the three tuning `.tres` files at GDD defaults

> **Epic**: Tuning Resources
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md` §7 · `design/gdd/suit-oxygen.md` §7 ·
`design/gdd/physics-props.md` §7
**Requirement**: `TR-watering-013`, `TR-oxygen-011`, `TR-props-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: D6.2 places authored tuning data in
`src/resources/tuning/`, one `.tres` per resource class. D6.9 requires
`resource_local_to_scene` to stay `false` on all three — if it is `true`, the engine
hands each instantiating scene its own copy, the "exactly one instance project-wide"
guarantee quietly becomes false, and D6.5's read-only reasoning stops describing
reality. Nothing errors and nothing logs.

**Engine**: Godot 4.7.1 | **Risk**: **HIGH** (project-level)
**Engine Notes**:
- Godot caches resources **by path** (T3, VERIFIED TRUE), so every `preload` of the
  same `.tres` yields the same object. That cache identity is the guarantee this
  whole epic is built on, and `resource_local_to_scene = true` is the one inspector
  click that destroys it silently.
- **No post-cutoff API is involved.** `resource_local_to_scene` has existed since
  Godot 3.x and is unchanged across 4.4 → 4.7.
- **`@export_range` does not validate a hand-typed `.tres` value** (T4, pending
  Story 001). Author these files through the inspector, not by hand, so the range
  actually applies.

**Control Manifest Rules (this layer)**:
- Required: "File layout: scripts in `src/scripts/tuning/`, authored data in
  `src/resources/tuning/`." — source: ADR-0006 (D6.2)
- Required: "`resource_local_to_scene` stays `false` on all three tuning `.tres`
  files." — source: ADR-0006 (D6.9)
- Forbidden: "Never set `resource_local_to_scene = true` on any of the three tuning
  `.tres` files — it silently destroys the single-shared-instance guarantee." —
  source: ADR-0006 (`tuning_resource_local_to_scene`)

---

## Acceptance Criteria

*From ADR-0006 D6.2, D6.9 and Migration Plan step 3:*

- [x] `src/resources/tuning/watering_tuning.tres` exists, has
      `script = watering_tuning.gd`, and holds all four knobs at their GDD defaults:
      `carry_speed_multiplier = 0.6`, `throw_arc_height = 120.0`,
      `throw_duration = 0.6`, `throw_angle_spread = 45.0`.
- [x] `src/resources/tuning/oxygen_tuning.tres` exists, has
      `script = oxygen_tuning.gd`, and holds all five knobs at their GDD defaults:
      `margin = 0.4`, `drain_rate = 1.0`, `threshold_caution = 0.50`,
      `threshold_warning = 0.25`, `threshold_critical = 0.10`.
- [x] `src/resources/tuning/prop_tuning.tres` exists, has
      `script = prop_tuning.gd`, and holds all three knobs at their GDD defaults:
      `prop_gravity_scale = 1.0`, `prop_max_speed = 2000.0`,
      `props_per_level_budget = 40`.
- [x] **Each file opens in the inspector** and shows its knobs. Confirmed by opening
      each one, not by inspection of the text.
      **METHOD SUBSTITUTED 2026-08-25.** No inspector was opened. The knob list was
      read from `Object.get_property_list()` on each loaded resource, which is the
      list the inspector builds its rows from. Exactly four, five and three knobs
      appeared, with no unexpected property. See the Implementation Record.
- [x] **`@export_range` constrains the inspector sliders** on each knob. Confirmed by
      dragging one slider per file to its bound.
      **METHOD SUBSTITUTED 2026-08-25.** No slider was dragged. Every one of the ten
      knobs reports `PROPERTY_HINT_RANGE` with its bounds in `hint_string` —
      `prop_gravity_scale` reads `0.8,1.2` — which is the data the inspector builds
      the slider from. See the Implementation Record.
- [x] **`resource_local_to_scene` is `false` on all three files** (D6.9). Confirmed
      both in the inspector and in the `.tres` text — the default is `false`, so the
      flag will normally be absent from the file entirely, and absence is the pass
      condition.
      **PARTIAL SUBSTITUTION 2026-08-25.** The `.tres` text half was verified in
      `production/qa/smoke-2026-08-24.md`, per file by name. The value half was read
      as `false` from each loaded resource. The inspector checkbox was not viewed.
- [x] The three `.tres` files sit in `src/resources/tuning/` and **not** alongside
      the existing unrelated resources (`Industrial.tres`, `Simple_tileset.tres`,
      `menu_theme.tres`) in `src/resources/`.
- [x] All three files are committed, together with their `.uid` sidecars if the
      editor generates them.

---

## Implementation Notes

*Derived from ADR-0006 D6.2, D6.9 and Migration Plan step 3:*

- **Create these through the editor inspector, not by hand-writing the `.tres`
  text.** Two reasons: the inspector applies the `@export_range`, and the editor
  writes the correct `script` reference and resource format header for 4.7.1. Verify
  the text afterwards; do not author it first.
- **Check `resource_local_to_scene` deliberately, on each of the three files.** The
  ADR states this rather than assuming it precisely because it is a default: defaults
  are what get changed by an author exploring the inspector, and this one has **no
  visible consequence at the moment it is changed**. Nothing errors. Nothing logs.
  The symptom appears much later as tuning silently ceasing to be global.
- The same hazard shape appears in ADR-0005's
  `process_thread_group_split_in_frame_chain` — a legitimate engine feature, inert
  today, one inspector click away, and silent until a specific case fails.
- **Defaults are the GDD defaults, unchanged.** Do not "improve" a value while
  authoring. `prop_gravity_scale` in particular must be `1.0` — `physics-props.md` §7
  says leave it there, because any other value desynchronises props from the player's
  fall and breaks the coherence described in §4.
- `drain_rate` stays at `1.0`. `suit-oxygen.md` §7 says leave it at 1.0 so capacity
  reads as real seconds. It is an accessibility hook, not a difficulty dial.
- These files are **read-only at runtime from here on** (D6.5). Once authored, the
  only legitimate way to change a value is to edit the `.tres` in the editor and
  commit it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the three `Resource` scripts. They must already exist before this story
  starts.
- Story 004: `tuning.gd` and the `preload` constants. **This story writes no path
  literal into any script** — the three paths are written down exactly once, in
  `tuning.gd`, and that is Story 004's job.
- Story 005: the gdUnit4 assertions on these values, including V9's
  `resource_local_to_scene` check. This story's checks are manual; Story 005 makes
  them permanent.
- Authoring `oxygen_capacity` anywhere. It is the per-level dial, exported on the
  level root and derived from `O_level` per `suit-oxygen.md` R6 — not a tuning value.

---

## QA Test Cases

*Story type: **Config/Data**. Gate is a smoke check. The permanent automated proof is
V4 and V9 in Story 005.*

### Manual checks — all three files

- **AC-1**: Each `.tres` opens in the inspector and shows its knobs
  - Setup: open `src/resources/tuning/watering_tuning.tres` in the Godot 4.7.1 editor
  - Verify: the inspector lists exactly the four `WateringTuning` knobs, no more
  - Pass condition: all four appear with the correct names, and no unexpected
    property is shown
  - Repeat for `oxygen_tuning.tres` (five knobs) and `prop_tuning.tres` (three knobs)

- **AC-2**: `@export_range` constrains the inspector slider
  - Setup: with the file open, drag the `prop_gravity_scale` slider
  - Verify: it stops at 0.8 and 1.2
  - Pass condition: the slider cannot be dragged past either bound. **Revert any
    change before saving** — the committed value must stay `1.0`

- **AC-3**: `resource_local_to_scene` is `false`
  - Setup: expand the Resource section in the inspector for each of the three files;
    then read the `.tres` text
  - Verify: the checkbox is unticked, and the `.tres` text contains no
    `resource_local_to_scene = true` line
  - Pass condition: false in the inspector **and** absent from the text, on all
    three files. This is V9 and it is cheap — the failure it catches is otherwise
    invisible

- **AC-4**: Values match the GDD §7 defaults exactly
  - Setup: read each `.tres` as text
  - Verify: against the twelve values in the acceptance criteria above
  - Pass condition: every value matches to the digit, and `props_per_level_budget` is
    written as an integer

### Edge cases

- **A knob missing from the `.tres` text is not a failure.** Godot omits a property
  that still equals the script default. The loaded value is what matters, and Story
  005 asserts the loaded value, not the file text. Do not "fix" a `.tres` by adding
  properties by hand.
- **Godot may rewrite the file on save** with a different property order or a bumped
  `format=` number. That is normal. Confirm the values survived, not the diff shape.
- **`.uid` sidecars.** 4.7.1 writes `.uid` files for resources. Commit them; do not
  gitignore them, or path references break on other machines.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass recorded in `production/qa/smoke-[date].md`, listing the AC-3
  `resource_local_to_scene` result for each of the three files by name
- The permanent automated proof lands with Story 005 (V4 and V9)

**Status**: [x] `production/qa/smoke-2026-08-24.md` records the AC-3
`resource_local_to_scene` result for each of the three files by name.
`production/qa/evidence/editor-facts-probe-2026-08-25.md` records the knob lists and
the range hints. The permanent automated proof is Story 005 groups 4 and 5 (V4, V9).

---

## Dependencies

- Depends on: Story 002 (hard — a `.tres` cannot reference a script that does not
  exist)
- Unlocks: Story 004 (`preload` resolves at parse time, so the files must exist
  before `tuning.gd` will parse at all)

---

## Implementation Record — 2026-08-25

**Status: all eight acceptance criteria met. Three were met by a substituted
method — read the deviation section before citing this story as closed.**

The three `.tres` files landed earlier in the sprint. This record closes the
paperwork, which had not been written.

### The twelve authored values, as loaded

Read from the loaded object, not from the file text, with `typeof()` alongside
each value.

| Resource | Knob | Type | Value | Range hint |
|---|---|---|---|---|
| `watering_tuning.tres` | `carry_speed_multiplier` | float | 0.6 | 0.4, 0.9 |
| | `throw_arc_height` | float | 120.0 | 60.0, 200.0 |
| | `throw_duration` | float | 0.6 | 0.4, 0.8 |
| | `throw_angle_spread` | float | 45.0 | 0.0, 90.0 |
| `oxygen_tuning.tres` | `margin` | float | 0.4 | 0.3, 0.6 |
| | `drain_rate` | float | 1.0 | 0.5, 1.0 |
| | `threshold_caution` | float | 0.5 | 0.0, 1.0 |
| | `threshold_warning` | float | 0.25 | 0.0, 1.0 |
| | `threshold_critical` | float | 0.1 | 0.0, 1.0 |
| `prop_tuning.tres` | `prop_gravity_scale` | float | 1.0 | 0.8, 1.2 |
| | `prop_max_speed` | float | 2000.0 | 1000.0, 4000.0 |
| | `props_per_level_budget` | **int** | 40 | 10.0, 80.0 |

Every value matches its GDD §7 default to the digit. Each resource points at its
own script. `props_per_level_budget` is `TYPE_INT`; its hint string serializes
the bounds as floats, which is the hint format and not the value type.

AC-7: all three files sit in `src/resources/tuning/`, not beside
`Industrial.tres`, `Simple_tileset.tres` or `menu_theme.tres` in
`src/resources/`.

AC-8: all three are tracked in git. Godot 4.7.1 generated no `.uid` sidecar for
these `.tres` files, so that clause of the criterion is satisfied with nothing to
commit. The four scripts in `src/scripts/tuning/` do have tracked `.uid` files.

### Deviation — AC-4, AC-5 and AC-6 name a method, not only a fact

Those three criteria do not merely state what must be true. They state how it
must be observed: open each file in the inspector, drag a slider to its bound,
and view the `resource_local_to_scene` checkbox. AC-4 goes further and rules out
inspection of the file text.

**None of those three observations was made.** No editor is usable on this
machine:

1. The windowed editor segfaults.
2. A headless editor starts and stays up, but the godot-ai MCP plugin disables
   itself in headless mode (`addons/godot_ai/plugin.gd:211`), so no session
   registers and no editor tool can be driven.
3. Only a headless probe script remains.

What was done instead is one layer below the editor's rendering, reading the same
data the editor renders from:

| Criterion | Editor method | Substituted method |
|---|---|---|
| AC-4 | Inspector shows the knob rows | `Object.get_property_list()` on the loaded resource — the source the rows are built from |
| AC-5 | Drag the slider to its bound | Read `hint` and `hint_string` — the source the slider's bounds are built from |
| AC-6 | View the unticked checkbox | Read `resource_local_to_scene` on the loaded object, plus the `.tres` text check already in the 2026-08-24 smoke doc |

This proves the data is correct. It does not prove the editor draws it. A defect
living only in the editor's rendering path is outside what this closes.

The acceptance criteria were **not reworded**. Each carries an inline note naming
its substitution, so the record does not claim an observation that never happened.

If you later open the editor on another machine, the honest way to retire these
notes is to make the three observations and say so here.

### Nothing was modified

The probe only loads and reads. `prop_gravity_scale` was never written and stays
`1.0` in `src/resources/tuning/prop_tuning.tres`. The AC-2 instruction to revert
before saving did not arise, because nothing was saved.

### Evidence

- `production/qa/evidence/editor-facts-probe-2026-08-25.md` — probe script, raw
  output, and the limitation statement
- `production/qa/smoke-2026-08-24.md` — the `.tres` text checks and the negative
  verification runs
- `tests/unit/tuning/tuning_resources_test.gd` — permanent proof, groups 4 and 5
