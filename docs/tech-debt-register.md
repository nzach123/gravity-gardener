# Tech Debt Register

Advisory items accepted at story close. Each entry names the story it came from
so the debt can be traced back to the decision that accepted it.

## Open

- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): AC-9 evidence document not created. The inspector screenshot of
  `Direction Ease Rate` needs the windowed editor, which is unavailable in this
  environment. Expected at
  `production/qa/evidence/gravity-authority-autoload-evidence.md`. The export is
  already verified structurally by
  `tests/unit/gravity/gravity_authority_contract_test.gd::test_direction_ease_rate_is_an_exported_property_defaulting_to_32`,
  so this is confirmation rather than detection — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`
- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): `reset_to()` has no test for a non-positive multiplier and no test
  for a near-zero direction. Both cases reach the same `_accepts()` branch that
  `set_gravity()` already covers, so the guard is exercised but the second entry
  point is not. Add `test_reset_to_rejects_zero_and_negative_multipliers` and
  `test_reset_to_with_a_near_zero_direction_is_also_rejected` — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`
- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): the comment above `_accepts()` in
  `src/scripts/autoloads/gravity_authority.gd` (line 131) says the guard uses
  `push_error()`, but the direction and multiplier branches use
  `push_warning()`. The behaviour is correct and inside the control-manifest
  rule, which scopes `push_error()` to bind/initialize guards. The comment is
  what needs correcting, not the code — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`

- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `MIN_TILEMAP_LAYERS = 9` in `tests/unit/physics/collision_layers_test.gd:47`
  sits AT the real count of 9 `TileMapLayer` nodes (one each in `level_01`-`level_08`
  plus `test_main`), not below it. The comment at lines 41-44 claims all three
  floors "sit below the current counts", which is true for `MIN_SCENES` (15 < 18)
  and `MIN_COLLISION_BODIES` but false here. Deleting or merging any level fails
  `test_every_tileset_physics_layer_is_world` with "expected at least 9" — a
  message that blames a broken scan when authoring legitimately changed. Lower to
  8, or amend the comment to state the exactness is deliberate — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `_classify_all()` (line 173) returns an untyped `Dictionary`, and all three call
  sites (lines 188, 198, 240) narrow `Variant` into a bare `Array`, discarding the
  `Array[CollisionObject2D]` typing the helper built. This breaks the
  "static typing everywhere" standard in `.claude/docs/technical-preferences.md`.
  It does NOT fail the suite: `project.godot` declares no
  `debug/gdscript/warnings/*` section, so Godot's `unsafe_*` and
  `untyped_declaration` warnings are off by default and discovery stays green
  (verified 2026-08-25, 178/178, exit 0). Fix all four sites together — two typed
  helpers returning `Array[CollisionObject2D]` — or none — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `test_every_tileset_physics_layer_is_world` reads only physics layer index 0
  (line 298) after asserting `get_physics_layers_count() >= 1`. A TileSet that
  declares a SECOND physics layer on an unallocated bit passes group 3 untouched,
  and group 2 cannot catch it either — that walk collects `CollisionObject2D` and
  `TileMapLayer` is not one. The test faithfully implements ADR-0004 D4.5
  assertion 3, which itself says `physics_layer_0`, so THE GAP IS IN THE ADR, not
  the test. Closing it needs `range(get_physics_layers_count())` in the test and,
  strictly, an ADR-0004 amendment — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `test_prop_never_masks_player` (T4.1) and `test_prop_never_masks_interactable_layer`
  (T4.4) iterate zero times today because no `PropBody` exists, and unlike T4.2/T4.3
  they carry no per-test anti-vacuous floor. Two of the four ADR-0004 D4.3 pair
  checks are therefore inert. The story permits this and the file documents it at
  lines 168-171, but it contradicts the story's own edge-case rule ("do not write
  the loop so that zero props causes a false pass"). Resolves itself when ADR-0011's
  `PropBody` is authored; until then the pair table is half-covered — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `_classify_all()` re-walks `res://src/scenes` and re-instantiates all 18 scenes
  on each call, and is called from three separate tests — roughly 54
  instantiations where 18 would do. Memoize in a `before()` fixture. Deferred
  because the whole suite runs in 33s and caching introduces cross-test state the
  file currently avoids on purpose — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  `_layer_name()` (line 338) takes a layer NUMBER while `RETIRED_BIT_3 = 4` (line 49)
  is a bit VALUE, and the two schemes meet with no comment saying so. `_layer_name(4)`
  means `layer_4 = "prop"`, whose bit value is 8. Both call sites are correct —
  verified against `project.godot:63-65` (`layer_1="world"`, `layer_2="player"`,
  `layer_4="prop"`, no `layer_3`) — but a future editor could "fix" `_layer_name(4)`
  to `_layer_name(8)` and silently break group 4. Needs one clarifying comment —
  tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`
- **2026-08-25** (Story 004: Collision layer invariant test suite — `/code-review`):
  Two cosmetic items. Three group-0 assertions are tautological because the masks
  are defined as ORs of the very bits they test — `DETECTOR_MASK` IS `PLAYER`, so
  `DETECTOR_MASK & PLAYER != 0` can only fail if `PLAYER` becomes 0 (the
  `is_equal(0)` halves ARE load-bearing and catch a bit-value collision); worth a
  comment so they are not mistaken for coverage. And `var areas` at line 354 is
  passed to `_collect_bodies`, which collects all bodies, not only areas — rename
  to `bodies` — tracked from
  `production/epics/collision-layer-registry/story-004-collision-layer-invariant-test-suite.md`

- **2026-08-25** (CI-1: live-fire verification of the ADR guards — `/dev-story`):
  The CI test step has no equivalent of the local runner's `-c` flag, so a red CI
  suite may stop at the first failing test and under-report. The local command
  passes `-c` to `GdUnitCmdTool.gd` for exactly this reason;
  `MikeSchulze/gdUnit4-action@v1` is configured in `.github/workflows/tests.yml`
  with `godot-version`, `paths`, `timeout` and `report-name` only, and no
  continue-past-first-failure option was identified. Not yet reproduced — every
  CI run to date has had a GREEN suite, so the under-reporting is inferred from
  the missing flag rather than observed. Confirm the action exposes such an
  option before scheduling the fix. Affects the quality of CI evidence, not
  correctness — tracked from
  `production/qa/evidence/ci-1-live-fire-2026-08-25.md`
- **2026-08-25** (CI-1: live-fire verification of the ADR guards — `/dev-story`):
  `actions/checkout@v4` and `actions/upload-artifact@v4` in
  `.github/workflows/tests.yml` target Node.js 20 and are being forced onto Node
  24 by the runner, which logs a deprecation warning on every run. A warning, not
  a failure; all four runs on 2026-08-25 completed normally. Resolves by bumping
  both actions to a Node-24 release. Deferred because a version bump is an
  unforced change to a workflow that has only just been observed working, and it
  should be made deliberately rather than folded into CI-1 — tracked from
  `production/qa/evidence/ci-1-live-fire-2026-08-25.md`

## Closed

*(none yet)*
