# Story 001: Create the CollisionLayers registry and correct project.godot naming

> **Epic**: Collision Layer Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-23

## Context

**GDD**: `design/gdd/physics-props.md`
**Requirement**: `TR-props-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Collision layer allocation
**ADR Decision Summary**: Four collision bits are allocated project-wide —
`WORLD=1`, `PLAYER=2`, bit 3 retired (never claimed), `PROP=8` — and a single
`class_name CollisionLayers` const script is the authoritative source. When
`project.godot`'s editor-facing `layer_names` disagree with the constants, the
constants win.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Verified downgrade, not an assumption — 2D physics is
unchanged 4.4 → 4.7 (`docs/engine-reference/godot/modules/physics-2d.md`),
independently re-checked at the 2026-08-14 specialist gate. No post-cutoff API
is used: `collision_layer`, `collision_mask`, `PackedScene.instantiate()`, and
`ProjectSettings.get_setting()` all predate 4.0 and are untouched by the 4.4–4.7
changelogs. Jolt (`3d/physics_engine`) is inert in this 2D project.

**Performance**: No performance impact expected — this story only adds
compile-time constants (`class_name CollisionLayers`) and static
`project.godot` `[layer_names]` metadata. No runtime collision checks,
physics queries, or per-frame logic are added or altered.

**Control Manifest Rules (this layer)**:
- Required: "Four allocated collision bits: `WORLD=1`, `PLAYER=2`, bit 3 RETIRED
  (never claim), `PROP=8`. Bits 5–32 are unallocated; claiming one requires
  amending ADR-0004." — source: ADR-0004 (D4.1)
- Required: "`class_name CollisionLayers` is the authoritative source;
  `project.godot`'s `layer_names` are editor-facing cosmetic only — on
  divergence, `CollisionLayers` is correct and `project.godot` is the bug." —
  source: ADR-0004 (D4.4)
- Forbidden: "Never use collision bit 3, or any of bits 5–32." — source:
  ADR-0004 (`unallocated_collision_bit`)

---

## Acceptance Criteria

*Scoped to ADR-0004 Migration Plan steps 1–2. Full isolation verification is
story 004's job — this story only creates the registry itself.*

- [x] `src/scripts/collision_layers.gd` exists, `extends RefCounted`, carries
      `class_name CollisionLayers`, and matches the *Key Interfaces* block in
      ADR-0004 verbatim: `WORLD`, `PLAYER`, `PROP`, `ALLOCATED`,
      `PLAYER_MASK`, `PROP_MASK`, `DETECTOR_MASK`, `DETECTOR_LAYER`. Bit 3 is
      *not* declared as a constant — only a comment marks it retired.
- [x] The script and its class-level doc comment are **warning-clean** under
      gdUnit4's warnings-as-errors discovery (no unused `class_name`, no
      shadowing).
- [x] `project.godot`'s `[layer_names]` section gains
      `2d_physics/layer_4="prop"`.
- [x] `project.godot`'s `[layer_names]` section no longer declares
      `2d_physics/layer_3="item"` (D4.2 — bit 3 is retired, not populated).
- [x] `2d_physics/layer_1="world"` and `2d_physics/layer_2="player"` are left
      unchanged.

---

## Implementation Notes

*Derived from ADR-0004 D4.1, D4.2, D4.4 and Migration Plan steps 1–2:*

- The class doc comment must state the precedence rule in-file, not just in
  the ADR — the header comment in ADR-0004's *Key Interfaces* block is the
  exact text to use: `project.godot`'s `layer_names` are editor-facing only;
  on disagreement this file is correct.
- Also state in-file that `collision_layer` / `collision_mask` are authored
  data and must never be assigned at runtime (D4.6) — this script is the
  natural place for that warning even though enforcement is story 005's job.
- Do **not** declare a constant for bit 3. The GDD-derived rule is that naming
  an unoccupied bit invites the next author to claim it "since it's already
  named." A code comment noting `# bit 3 (value 4) is RETIRED — see ADR-0004
  D4.2. Do not claim it.` is sufficient and is what ADR-0004 itself does.
- `ALLOCATED = WORLD | PLAYER | PROP` (value `11`) is the constant story 004's
  test uses to assert no scene claims bit 3 or bits 5–32. Get this one right —
  it is load-bearing for that story.
- This story does **not** touch any `.tscn` file and does not fix any of the
  five defects ADR-0004 catalogs — those are stories 002 and 003.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: fixing the dead `KillArea2D` masks on levels 05/06 (BUG-0001).
- Story 003: removing the vestigial `PlayerArea2D` and the dead
  `moving_platform.tscn` mask.
- Story 004: the gdUnit4 test that verifies the registry against every scene.
- Story 005: the CI grep enforcing the D4.6 runtime-mutation ban.
- Consolidating the five inline `TileSet` sub-resources into
  `Simple_tileset.tres` — ADR-0004 marks this optional cleanup (migration step
  6) and out of scope for this epic. Note: `Simple_tileset.tres` already
  declares `physics_layer_0/collision_layer = 1` explicitly, so the one
  concrete ask in that optional step is already satisfied.

---

## QA Test Cases

*Generated by `/qa-plan sprint` on 2026-08-18. Story type: **Logic**.*

**This story owns no test file.** Its assertions live in
`tests/unit/physics/collision_layers_test.gd`, created by story 004. The cases
below are written here so story 004 implements them, and so `/story-done` on
this story knows what to check rather than reporting a missing test path.

### Constant-value cases (assertion group 0 — new, this story)

| # | Case | Expected |
|---|---|---|
| T1.1 | `CollisionLayers.WORLD` | `== 1` |
| T1.2 | `CollisionLayers.PLAYER` | `== 2` |
| T1.3 | `CollisionLayers.PROP` | `== 8` |
| T1.4 | `CollisionLayers.ALLOCATED` | `== 11` (`WORLD \| PLAYER \| PROP`) — load-bearing for story 004 assertion group 2 |
| T1.5 | `DETECTOR_LAYER` | `== 0` |
| T1.6 | `DETECTOR_MASK` | `== CollisionLayers.PLAYER` |
| T1.7 | `PLAYER_MASK` and `PROP_MASK` | Both declared; each asserted by derived bit test, never raw equality (D4.5/F6) |
| T1.8 | Bit 3 is not declared | No constant anywhere in the script evaluates to `4`. Assert `ALLOCATED & 4 == 0` — a value test, since a missing constant cannot be asserted directly |

### `project.godot` agreement cases (story 004 assertion group 4)

| # | Case | Expected |
|---|---|---|
| T1.9 | `layer_names/2d_physics/layer_1` | `== "world"` |
| T1.10 | `layer_names/2d_physics/layer_2` | `== "player"` |
| T1.11 | `layer_names/2d_physics/layer_3` | Undeclared — `ProjectSettings.get_setting("layer_names/2d_physics/layer_3", "")` returns `""` (D4.2, bit 3 retired not renamed). **Do not use `has_setting()`** — it returns `true` for every 2D layer slot whether or not `project.godot` declares it |
| T1.12 | `layer_names/2d_physics/layer_4` | `== "prop"` |

Read via `ProjectSettings.get_setting()`, which is headless-safe (L6).

### Edge cases

- **Retired bit is asserted undeclared, not renamed.** T1.11 must assert the
  value is empty. A test that only asserts `layer_3 != "item"` would pass on a
  rename, which is exactly the outcome D4.2 forbids.
- **Presence is not a usable signal for T1.11.**
  `ProjectSettings.has_setting("layer_names/2d_physics/layer_N")` returns `true`
  for every `N`, declared or not — the slots are pre-registered engine settings
  defaulting to `""`. Verified against 4.7.1 on 2026-08-18: `layer_3` (removed by
  this story) and `layer_31` (never mentioned anywhere in the project) both
  report `true`. An absence check would fail on correct code.
- **No boundary or invalid-input cases apply** — this story adds compile-time
  constants only. There is no input to be zero, maximum, or null.

### Manual verification

- [x] `collision_layers.gd` is warning-clean under gdUnit4 warnings-as-errors
      discovery. Run the full suite, not just this file — one warning anywhere
      fails discovery for every test.
- [x] The class doc comment states the D4.4 precedence rule and the D4.6
      runtime-mutation ban in-file, per Implementation Notes.

**Estimated test count**: ~12 assertions, all inside story 004's file.

*No formula exists in `physics-props.md` for this story — TR-props-002 is a
structural rule, not a computation. Cases are derived from ADR-0004 D4.1/D4.2/D4.4
and the story's acceptance criteria.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/[system]/[story-slug]_test.[ext]` — must exist and pass

This story has no dedicated test file of its own — `collision_layers.gd` is
constants only, and story 004's `collision_layers_test.gd` is what exercises
it. Evidence for *this* story is that story 004's test passes once both land.

**Status**: [x] Satisfied — see Completion Notes

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 003, Story 004, Story 005

---

## Completion Notes
**Completed**: 2026-08-23
**Criteria**: 5/5 passing.

- AC-1 auto-verified by `diff` against `adr-0004-collision-layer-allocation.md:302-331`
  — `src/scripts/collision_layers.gd` is byte-identical to the ADR's *Key
  Interfaces* block apart from the code fence. Bit 3 is undeclared; only the
  comment marks it retired.
- AC-2 verified by running the full gdUnit4 suite: 5/5 suites discovered,
  75/75 cases, 0 errors, 0 orphans. Warnings-as-errors discovery is clean.
- AC-3/4/5 verified by reading `project.godot` `[layer_names]` directly:
  `layer_1="world"`, `layer_2="player"`, `layer_4="prop"`, no `layer_3`.

**Deviations**: None. Manifest version matched (story `2026-08-17` = current
`2026-08-17`). No forbidden pattern present — no runtime layer/mask assignment.

**Test Evidence**: Satisfied via story 004's
`tests/unit/physics/collision_layers_test.gd`, landed the same day. Its group 0
(9 cases) and group 4 (2 cases) implement T1.1–T1.12, so every criterion above
now has a regression guard rather than only a one-time inspection.

**Code Review**: Pending — `/code-review` deferred to sprint close-out by
developer decision. Low risk: the file is 26 lines of constants already verified
verbatim against the governing ADR.

**Note for whoever runs CI next**: `.godot/global_script_class_cache.cfg` was
stale and `GdUnitCmdTool.gd` would not load at all until
`godot --headless --path . --import` was run. Nothing to do with this story, but
a clean checkout will hit it. Relevant to CLR-5.
