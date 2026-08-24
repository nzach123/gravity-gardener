# Story 004: Collision layer invariant test suite

> **Epic**: Collision Layer Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-23

## Context

**GDD**: `design/gdd/physics-props.md`
**Requirement**: `TR-props-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Collision layer allocation
**ADR Decision Summary**: A gdUnit4 scene test
(`tests/unit/physics/collision_layers_test.gd`) instantiates every scene via
`PackedScene.instantiate()` without adding it to the tree, and asserts four
groups of invariants: the D4.3 isolation checks (as derived bit tests, never
raw integer equality), that no scene uses an unallocated bit, that every
`TileSet` physics layer equals `WORLD`, and that `project.godot`'s names agree
with the `CollisionLayers` constants.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Two specific engine facts this test depends on, both
verified against engine source at the 2026-08-14 specialist gate:
- **L5** — `collision_layer` / `collision_mask` are populated by
  `PackedScene.instantiate()` without a `SceneTree` and without `_ready()` —
  they are plain integer properties set by the `node->set(...)` loop inside
  `SceneState::instantiate()`. This is what makes the test runnable headlessly
  over every scene without adding anything to the tree.
- **L6** — `ProjectSettings.get_setting()` is a static configuration read and
  is headless-safe, which is what makes assertion 4 possible.

**Control Manifest Rules (this layer)**:
- Required: "The collision-layer gdUnit4 test must assert derived bit
  invariants (`mask & LAYER == 0`), never raw integer equality — raw equality
  breaks the moment an unrelated bit is legitimately added." — source:
  ADR-0004 (D4.5, F6)
- Guardrail: gdUnit4 treats GDScript warnings as errors at test discovery —
  one warning fails the entire suite, not just this file. This script and the
  test must both be warning-clean.

---

## Acceptance Criteria

*From ADR-0004 D4.5 and Validation Criterion 1, scoped to this story:*

- [x] `tests/unit/physics/collision_layers_test.gd` exists and instantiates
      each relevant scene via `PackedScene.instantiate()` without adding it to
      the `SceneTree` (per L5).
- [x] **Assertion group 1 — isolation invariants, expressed as derived bit
      tests, never raw integer equality**: e.g.
      `prop.collision_mask & CollisionLayers.PLAYER == 0`, and the mirror
      checks for player→prop, interactable→prop, and prop→interactable, per
      D4.3's four-pair table.
- [x] **Assertion group 2 — no scene uses an unallocated bit**:
      `(layer | mask) & ~CollisionLayers.ALLOCATED == 0`, checked across every
      scene under `src/scenes/**/*.tscn` (enumerated by directory scan, not a
      hardcoded list — a new scene must be covered on creation). Explicitly
      filter to the exact `.tscn` suffix so `.tscn*.tmp` editor autosaves are
      never picked up.
- [x] **Assertion group 3 — every `TileSet.physics_layer_0/collision_layer`
      equals `CollisionLayers.WORLD`**, across all inline sub-resources
      (levels 03–06, `test_main`) and the shared `Simple_tileset.tres`.
- [x] **Assertion group 4 — `project.godot` names agree with the
      constants**, read via `ProjectSettings.get_setting()` for
      `layer_names/2d_physics/layer_1` through `layer_4`.
- [x] The test passes on the current codebase (after stories 001–003 land).
- [x] The test **fails** when any of the following is deliberately introduced
      on a scratch branch, per Validation Criterion 1 — verify each by hand
      once, then revert:
      - A prop masking `player`.
      - A player masking `prop`.
      - Any node using bit 3 or an unallocated bit (5–32).
      - A tileset whose physics layer is not `world`.
- [x] Both `collision_layers_test.gd` and `collision_layers.gd` (story 001)
      are warning-clean under gdUnit4's warnings-as-errors discovery.

---

## Implementation Notes

*Derived from ADR-0004 D4.5, F6, and Validation Criterion 1:*

- Use bit-test assertions throughout (`&` then `== 0`), never
  `assert_int(mask).is_equal(...)`. This is the single most important rule in
  this story — raw equality fails the moment an unrelated bit is legitimately
  added later, even though the isolation guarantee still holds. F6 exists
  specifically because this mistake is easy to make.
- This test is a **unit test**, not a seventh `LevelValidation` rule.
  ADR-0003's D3.3 froze that rule set at six; do not add to it or touch
  `src/scripts/level_validation.gd` (if it exists) for this story.
- Per the ADR's own note: this test is green from the moment it lands, even
  before a `PropBody` scene exists — assertion group 1's prop-specific checks
  simply have nothing to iterate over until ADR-0011 authors the first prop.
  Do not block this story on props existing.
- Scan `src/scenes/**/*.tscn` for the scene list rather than hardcoding scene
  paths, specifically to catch drift as new scenes are added. Filter on the
  exact `.tscn` suffix — `.gitignore:39` already excludes `.tscn*.tmp` editor
  autosaves from version control, but a directory scan at test time could
  still pick one up if present locally, so filter explicitly rather than
  relying on gitignore.
- This story depends on story 001 (the `CollisionLayers` script must exist to
  reference its constants) and is most useful once stories 002 and 003 have
  landed, since two of its assertion groups (2 and 3) would otherwise need to
  tolerate defects 1–3 as known-bad. If run before 002/003 land, the test
  should still pass — none of the current defects (dead `KillArea2D` masks,
  `PlayerArea2D` on layer 1, dead platform mask) use an unallocated bit or a
  wrong tileset layer, so nothing in this story's assertions currently fails.
  Recommended order is still 001 → (002, 003) → 004 for a clean story-by-story
  narrative, but there is no hard blocking dependency on 002/003.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: creating `collision_layers.gd` itself.
- Story 002: fixing `KillArea2D` — this story tests the *result*, not the fix.
- Story 003: removing dead configuration — same relationship.
- Story 005: the CI grep for runtime mutation (D4.6) is a separate,
  non-gdUnit4 mechanism — do not fold it into this test file.

---

## QA Test Cases

*Generated by `/qa-plan sprint` on 2026-08-18. Story type: **Logic**.*

**Test file**: `tests/unit/physics/collision_layers_test.gd` — this story's
implementation *is* its test. The cases below are its required contents, and
they absorb the specs written into stories 001, 002 and 003, which own no test
file of their own.

**Standing rule for every assertion in this file**: use derived bit tests
(`mask & LAYER == 0`), never `assert_int(mask).is_equal(...)`. Raw equality
breaks the moment an unrelated bit is legitimately added, even while the
isolation guarantee still holds. ADR-0004 F6 exists because this mistake is easy
to make, and D4.5 makes it binding.

### Group 0 — registry constants (from story 001)

Cases T1.1–T1.12 in `story-001-create-collision-layers-registry.md`. ~12 assertions.

### Group 1 — isolation invariants (D4.3, four-pair table)

| # | Case | Expected |
|---|---|---|
| T4.1 | prop → player | `prop.collision_mask & CollisionLayers.PLAYER == 0` |
| T4.2 | player → prop | `player.collision_mask & CollisionLayers.PROP == 0` |
| T4.3 | interactable → prop | `detector.collision_mask & CollisionLayers.PROP == 0` |
| T4.4 | prop → interactable | `prop.collision_mask & CollisionLayers.DETECTOR_LAYER == 0` |

**Both directions of every pair must be asserted.** Body-vs-body pairing is an OR,
not an AND (L3) — a one-sided mask mistake still produces contact, so a test that
checks only one direction proves nothing.

*Per ADR-0004's own note, the prop-side cases have nothing to iterate over until
ADR-0011 authors the first `PropBody`. The test is green from the moment it lands.
Do not block this story on props existing, and do not write the loop so that zero
props causes a false pass — assert the iteration count where it is knowable.*

### Group 2 — no scene uses an unallocated bit

| # | Case | Expected |
|---|---|---|
| T4.5 | Every node in every scene under `src/scenes/**/*.tscn` | `(layer \| mask) & ~CollisionLayers.ALLOCATED == 0` |
| T4.6 | Scene list is built by directory scan | Not a hardcoded array — a new scene must be covered on creation |
| T4.7 | Scan filters on the exact `.tscn` suffix | `.tscn*.tmp` editor autosaves are never picked up |

### Group 3 — every TileSet physics layer is WORLD

| # | Case | Expected |
|---|---|---|
| T4.8 | Inline `TileSet` sub-resources in levels 03–06 and `test_main` | `physics_layer_0/collision_layer == CollisionLayers.WORLD` |
| T4.9 | Shared `Simple_tileset.tres` | Same. Already declares `collision_layer = 1` explicitly |

### Group 4 — project.godot agreement

Cases T1.9–T1.12 from story 001, via `ProjectSettings.get_setting()` (headless-safe, L6).

### Group 5 — absence cases (from story 003)

Cases T3.1–T3.3 in `story-003-remove-dead-collision-configuration.md`.

### Edge cases

- **Zero-iteration false pass.** Groups 1–3 all loop over discovered nodes. A
  scan that finds nothing passes vacuously. Assert a minimum expected count for
  scenes and tilesets, so a broken glob fails loudly instead of reporting green.
- **Scenes that fail to instantiate.** A malformed `.tscn` should fail the test
  with a clear message, not be silently skipped by a `null` guard.
- **`.tscn*.tmp` autosaves** — T4.7. `.gitignore:39` excludes them from version
  control, but a local directory scan at test time can still find one.
- **New unallocated bit added later** — the whole point of T4.5. Verified by the
  negative check below, not by a positive assertion.

### Manual verification — REQUIRED, blocking

**These four negative checks are the only proof the suite can actually fail.**
A green invariant test that cannot go red is worse than no test. ADR-0004
Validation Criterion 1 requires each one.

Verify by hand once on a scratch branch, confirm the failure, then revert:

- [ ] A prop masking `player` → group 1 fails
- [ ] A player masking `prop` → group 1 fails
- [ ] Any node using bit 3 or an unallocated bit (5–32) → group 2 fails
- [ ] A tileset whose physics layer is not `world` → group 3 fails

Record the four results in the story's completion notes. They are a one-time
manual verification, not a committed artifact.

- [ ] Both `collision_layers_test.gd` and `collision_layers.gd` are warning-clean
      under gdUnit4 warnings-as-errors discovery — one warning anywhere fails
      discovery for the entire suite, not just this file

**Estimated test count**: ~30 assertions across 5 groups, plus 4 manual negative checks.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/physics/collision_layers_test.gd` — must exist and pass

This story's implementation *is* its own test evidence — there is no separate
test-for-the-test. The scratch-branch negative checks in the acceptance
criteria are a one-time manual verification during implementation, not a
committed artifact.

**Status**: [x] Satisfied — see Completion Notes

---

## Dependencies

- Depends on: Story 001 (hard — references `CollisionLayers` constants).
  Recommended after Story 002 and Story 003 for narrative cleanliness, but not
  blocked on them.
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-08-23
**Criteria**: 8/8 passing.

**Delivered**: `tests/unit/physics/collision_layers_test.gd` — 21 test cases
across all five assertion groups. Full suite after landing: 75/75, 0 errors,
0 failures, 0 orphans, exit 0.

**Design decisions worth knowing:**

- Bodies are classified by the bits they carry, not by class name or a scene
  list, so group 1's prop-side pairs begin covering ADR-0011's `PropBody` the
  moment one is authored, without this file changing. As ADR-0004 predicted,
  those loops iterate zero times today.
- The five interactables are named explicitly (`INTERACTABLE_SCENES`) rather
  than derived. Classifying a detector by `collision_layer == 0` and then
  asserting it equals 0 would be circular and prove nothing; naming them makes
  "these carry no layer" a real assertion. Group 2's scan remains a directory
  walk, per T4.6.
- T4.4 (prop → interactable) is tautological while `DETECTOR_LAYER` is 0 —
  nothing can mask a body occupying no layer. It is implemented for pair-table
  completeness, but the load-bearing half is the `DETECTOR_LAYER` assertion in
  `test_interactables_are_detectors_that_never_mask_prop`, which is what
  actually goes red if an interactable gains a layer.
- Anti-vacuous floors: >= 15 scenes, >= 10 collision bodies, >= 9 TileMapLayers
  (actual: 18 / 9). Set below current counts so legitimate authoring does not
  trip them, far enough above zero that a broken glob fails loudly.

**Negative checks (blocking AC) — all four confirmed, then reverted:**

| Mutation | Test that caught it |
|---|---|
| Platform on PROP layer masking `player` | `test_prop_never_masks_player` |
| `player.tscn` mask → 9 (`WORLD\|PROP`) | `test_player_never_masks_prop` |
| Platform claims retired bit 3 (value 4) | `test_no_scene_uses_an_unallocated_bit` |
| Platform claims unallocated bit 5 (value 16) | `test_no_scene_uses_an_unallocated_bit` |
| `level_03` inline TileSet → layer 2 | `test_every_tileset_physics_layer_is_world` |

The first attempt at the bit-3 check was invalid and was redone. Setting
`spike_hazard.collision_layer = 4` tripped the interactable check (test #12)
before group 2 (test #14) ever ran, so it proved the wrong assertion. Re-running
the mutation on the moving platform — which no earlier group classifies —
exercised group 2 directly. Both bit 3 and bit 5 were verified separately.

**Deviations**: None from ADR-0004. One correction was made to a *sibling*
story: story 003's T3.3 expected `AnimatableBody2D.collision_mask == 0` after
the authored line is deleted. `CollisionObject2D.collision_mask` defaults to
`1`, not `0` (probed directly on 4.7.1), so T3.3 would have failed against a
correct implementation of story 003. Corrected in place there before
implementing; group 5 asserts `== 1`.

**Test Evidence**: This story's implementation is its own evidence. The
negative checks above are the one-time manual verification required by
ADR-0004 Validation Criterion 1 and are recorded here, not committed.

**Code Review**: Pending — deferred to sprint close-out with story 001.

**Open item for CLR-5.** Across all five negative-check runs, the executed-case
count equalled the index of the first failing test (10, 11, 12, 14, 15 of 21),
which indicates the suite stops at the first failing test rather than running to
completion. In CI, one failure would mask every later one. Cause not
investigated — it is a gdUnit4 runner setting, not a defect in this test.
Separately, `.godot/global_script_class_cache.cfg` was stale and the runner
would not load until `--import` was run. Both belong with CLR-5, which owns the
CI workflow.
