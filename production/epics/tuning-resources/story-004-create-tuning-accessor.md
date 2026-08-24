# Story 004: Create the `Tuning` const accessor

> **Epic**: Tuning Resources
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md` §7 · `design/gdd/suit-oxygen.md` §7 ·
`design/gdd/physics-props.md` §7
**Requirement**: `TR-watering-013`, `TR-oxygen-011`, `TR-props-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: D6.3 makes `class_name Tuning` the single reach for all
tuning data. It holds three typed `preload()`ed constants and nothing else — no
behaviour, no registration. It is **the only place in the project where a tuning
`.tres` path is written**. `preload` resolves at script-load time with no `SceneTree`
involvement at all, which is what lets `LevelValidation` (static, null tree) and
`GravityAuthority` (autoload, pre-level) share one mechanism.

**Engine**: Godot 4.7.1 | **Risk**: **HIGH** (project-level)
**Engine Notes**: Four engine facts carry this story. T1-T3 were verified at the
2026-08-14 specialist gate.
- **T1 — VERIFIED TRUE**: a typed constant holding a `preload()`ed custom `Resource`
  — `const PROP: PropTuning = preload(...)` — is legal GDScript and resolves at
  script-load time. Basis: `static_typing.html` §Custom types.
- **T2 — VERIFIED TRUE, and stronger than the draft claimed**: `preload()` resolves
  with **no `SceneTree` involvement whatsoever**. Basis:
  `best_practices/logic_preferences.html` §"Loading vs. preloading" — a preloaded
  const *"spawns when the Script object loads"*. Resolution is **categorically
  independent** of tree or node state, not merely compatible with a null tree. The
  weaker framing invites a future author to assume a tree-dependent alternative would
  also work. It would not.
- **T3 — VERIFIED TRUE**: Godot caches resources by path, so every `preload` of the
  same `.tres` yields the same object.
- **GH#73615 — a known engine bug**: a `preload()`ed resource can resolve **non-null
  yet be the wrong type**. This is why Story 005's V1 asserts `is PropTuning` rather
  than merely non-null.
- **No autoload parse-order hazard.** `GravityAuthority` is an autoload with no
  `class_name`, and it reads `Tuning`, a `class_name` script that is not an autoload.
  Verified safe: `class_name` global registration happens at project load **before**
  any autoload is instantiated, and `tuning.gd` itself only loads on first reference.
- **No post-cutoff API is used.**

**Control Manifest Rules (this layer)**:
- Required: "Consumers reach tuning ONLY through `class_name Tuning`
  (`Tuning.WATERING` / `.OXYGEN` / `.PROP`); no consumer names a `.tres` path
  itself." — source: ADR-0006 (D6.3)
- Required: "Use `preload()`, never `load()`, for `Tuning`'s constants — a
  missing/renamed file then fails at parse time (loud, at startup) rather than as a
  runtime null." — source: ADR-0006
- Required: "`Tuning` is NOT an autoload and must never become one. `preload` already
  gives it universal reach with no `SceneTree` dependency." — source: ADR-0006
- Forbidden: "Never write a `res://src/resources/tuning/` path literal outside
  `src/scripts/tuning/`. The path is written down exactly once, in `tuning.gd`." —
  source: ADR-0006 (`tuning_path_literal_outside_holder`)
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`, and never call `.duplicate()` on a tuning resource." — source: ADR-0006
  (`tuning_resource_runtime_mutation`)
- Guardrail: `Tuning.PROP.prop_gravity_scale` is read **per easing frame** by
  `GravityAuthority` (~6-7 frames per gravity change at 60 FPS). That must stay a
  single property access on a resident object — no allocation, no I/O, no lookup.

---

## Acceptance Criteria

*From ADR-0006 D6.3, the Key Interfaces block, and Migration Plan step 4:*

- [ ] `src/scripts/tuning/tuning.gd` exists and declares `class_name Tuning`.
- [ ] It holds exactly these three constants, typed, using `preload`, verbatim from
      D6.3:
      `const WATERING: WateringTuning = preload("res://src/resources/tuning/watering_tuning.tres")`,
      `const OXYGEN: OxygenTuning = preload("res://src/resources/tuning/oxygen_tuning.tres")`,
      `const PROP: PropTuning = preload("res://src/resources/tuning/prop_tuning.tres")`.
- [ ] **The script holds nothing else** — no methods, no variables, no signals, no
      `_ready`. `Tuning` registers nothing and has no behaviour.
- [ ] It carries the D6.3 doc comment, which states that this is the only place a
      tuning `.tres` path is written, and that `preload` resolution is independent of
      the `SceneTree`.
- [ ] **`Tuning` is not registered as an autoload** in `project.godot`, and no line
      is added to `[autoload]`.
- [ ] `load()` is not used anywhere in the file.
- [ ] The three `.tres` paths appear in this file and **nowhere else in the
      project** — verified by grep at implementation time and made permanent by Story
      006's V6 CI grep.
- [ ] The script is warning-clean under gdUnit4's warnings-as-errors test discovery.
- [ ] Renaming any one of the three `.tres` files produces a **parse error at
      startup**, not a runtime null. Verified once by hand, then reverted.

---

## Implementation Notes

*Derived from ADR-0006 D6.3 and the Key Interfaces block:*

- **Copy the D6.3 block verbatim from the ADR**, including the doc comment. The
  wording of that comment is load-bearing: it is what stops a future author from
  "improving" this into an autoload or a lazy `load()`.
- **`preload`, never `load`.** `preload` resolves at parse time, so a missing or
  renamed `.tres` is a script parse error at startup — loud, immediate, impossible to
  ship past — instead of a null dereference on the first gravity flip. This matches
  `architecture.md` P4.
- **Never make `Tuning` an autoload.** `preload` already gives it universal reach.
  Registering it would hand it exactly the tree dependency D6.3 exists to avoid, and
  would break the `LevelValidation` null-tree path.
- This is **the same const-table pattern as ADR-0004's `CollisionLayers`**, and for
  the same reason: name an invariant once so no author has to remember it. If in
  doubt about style, match `src/scripts/collision_layers.gd`.
- **Do not add a `get_tuning()` helper, a lookup by string, or a fourth constant.**
  Three constants, nothing else. `architecture.md` §429 records that a fourth
  `Tuning` resource was already declined — ADR-0006 sized the tuning set at exactly
  three.
- The typed-constant form (`const PROP: PropTuning = ...`) is what makes T1 apply and
  what makes a wrong-type resolution (GH#73615) catchable. Do not drop the type
  annotation to silence a warning; fix the warning another way.
- **Do not write any consumer code.** `GravityAuthority`, `LevelValidation`,
  `LevelRoot` and `PropBody` adopt `Tuning.*` under their own ADRs as they land.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 and Story 003: the resource scripts and the `.tres` files. Both must
  already exist, or this file will not parse.
- Story 005: the gdUnit4 suite that asserts V1-V4 and V9 against this accessor.
- Story 006: the CI greps that make D6.3 and D6.5 structural.
- **All consumer adoption.** ADR-0008 / ADR-0009 / ADR-0011 / ADR-0012 adopt
  `Tuning.*` as they land. No consumer work is owed by this epic.
- Closing `V-PROP-BUDGET`. That work is owned by the `level-validation` epic
  (sprint task LV-2) and must be done once, not twice.

---

## QA Test Cases

*Story type: **Logic**. Test file: `tests/unit/tuning/tuning_accessor_test.gd`.*

*Note: V1, V2 and V3 belong to Story 005's suite, which is the epic's validation
gate. The cases here are this story's own shape checks — that the accessor holds
three constants and nothing else, and that it is not an autoload. If the two test
files would overlap, fold these into Story 005's file rather than duplicating an
assertion.*

- **AC-1**: `Tuning` exposes exactly three constants
  - Given: `tuning.gd` is parsed
  - When: the script's constant map is read
  - Then: it contains `WATERING`, `OXYGEN` and `PROP`, and nothing else
  - Edge cases: a fourth constant added later must fail this test — that is the
    point. `architecture.md` already records one declined fourth resource.

- **AC-2**: `Tuning` has no behaviour
  - Given: `tuning.gd` is parsed
  - When: its method list is read
  - Then: it declares no script-level methods and no signals
  - Edge cases: inherited `Object` / `RefCounted` methods do not count. Filter to
    methods declared by this script.

- **AC-3**: `Tuning` is not an autoload
  - Given: the project settings
  - When: the `autoload/` section is read via `ProjectSettings.get_setting()`
    (a static configuration read, headless-safe)
  - Then: no entry names `Tuning` or `tuning.gd`
  - Edge cases: an entry disabled with a leading `*` still counts as present.
    Match on the value, not only on the key.

- **AC-4**: No `load()` call and no path literal outside this file
  - Given: the project source tree
  - When: `src/` is searched for `res://src/resources/tuning/`
  - Then: `src/scripts/tuning/tuning.gd` is the only match
  - Edge cases: `tests/` may legitimately name a path — scope the search to `src/`.
    Story 006 makes this a CI step; here it is a one-time check.

### Manual verification — required once

- [ ] Rename `prop_tuning.tres`, reopen the project, and confirm the failure is a
      **parse error at startup**, not a runtime null on first use. Then revert.
      This is the entire justification for `preload` over `load`, and it has never
      been observed on this project.

### Edge cases

- **GH#73615 — non-null but wrong type.** Not asserted here; it is Story 005's V1,
  which asserts `is PropTuning` rather than merely non-null. Do not weaken V1 to a
  null check because this story already "checked the constants exist" — those are
  different checks.
- **Warnings-as-errors.** A `class_name` with no consumer can trip the unused
  warning. `Tuning` has no consumer until ADR-0008 / ADR-0009 / ADR-0011 land, so
  expect this and resolve it at write time.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/tuning/tuning_accessor_test.gd` — must exist and pass
- The one-time rename check recorded in the story's completion notes (a manual
  verification, not a committed artifact)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 and Story 003 (both hard — `preload` resolves at parse time,
  so both the scripts and the `.tres` files must exist or this file will not parse)
- Unlocks: Story 005, Story 006, and the `level-validation` epic's `V-PROP-BUDGET`
  work (sprint task LV-2)
