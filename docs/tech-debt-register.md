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

- **2026-08-26** (GA-002: Direction easing and the exported rate): `direction_ease_rate`
  is exported with no `@export_range` floor and no runtime guard. Set to 0 or negative,
  `clampf(rate * delta, 0.0, 1.0)` yields 0, `lerp_angle` returns the current angle every
  frame, the residual never shrinks so `DIRECTION_SETTLE_EPSILON` never trips, and the
  turn freezes silently with no diagnostic — unlike `initialize()` and `_accepts()`, which
  both refuse and `push_error` on non-positive input. Deferred because the export
  *declaration* belongs to Story 001, not GA-002 — tracked from
  `production/epics/gravity-authority/story-002-direction-easing-and-exported-rate.md`
- **2026-08-26** (GA-002: Direction easing and the exported rate): `_settle_steps()` in
  `tests/unit/gravity/gravity_authority_easing_test.gd` caps its loop at
  `SETTLE_STEP_CEILING` (240) and returns that count without asserting the loop exited via
  settlement. A defect that stopped the ease terminating at a lower rate would return 240,
  still greater than the fast path's 5, so `test_a_lower_ease_rate_takes_strictly_more_steps`
  would pass on a broken ease. The sibling helper `_run_transition()` does assert the
  ceiling; apply the same assertion — tracked from
  `production/epics/gravity-authority/story-002-direction-easing-and-exported-rate.md`
- **2026-08-26** (GA-002: Direction easing and the exported rate): `control-manifest.md:170`
  still budgets the prop wake pass at "~6-7 frames per gravity change" at 60 FPS. The
  2.5-degree settle epsilon added 2026-08-25 makes it 5 frames. Documentation drift with no
  code impact, but the manifest is the sheet programmers read for the Foundation layer, and
  Story 007's wake pass will be sized against this number — tracked from
  `production/epics/gravity-authority/story-002-direction-easing-and-exported-rate.md`

- **2026-08-26** (GA-003: Make PlayerGravityComponent a consumer): ADR-0001's Key
  Interfaces section still reads "`PlayerGravityComponent` retains: ... and the derived
  basis", which GA-003 AC-6 contradicts and overrides. The basis now lives only on
  `GravityAuthority`; `update_derived_dirs()`, `up_dir` and `right_dir` were deleted from
  the component. The ADR line is loose prose, not a rejected pattern, and has NOT been
  amended. Raise as an ADR erratum — do not re-add a local basis, which is exactly the
  divergence AC-6's edge case describes (it agrees at both endpoints of an ease and
  disagrees for the ~83 ms between) — tracked from
  `production/epics/gravity-authority/story-003-player-gravity-component-becomes-consumer.md`
- **2026-08-26** (GA-003: Make PlayerGravityComponent a consumer): AC-8, the four-angle
  play regression at gravity 0/90/180/270 degrees, is unverified. It cannot be automated
  (coding standards place "feel" outside automation) and cannot be run by an agent on this
  machine, where the windowed Godot editor segfaults. Folded into the sprint's single
  gravity-path playtest, which runs after GA-005 and is signed off by qa-lead at
  `production/qa/evidence/playtest-sprint-2-gravity-regression.md`. Close this when that
  playtest is recorded — tracked from
  `production/epics/gravity-authority/story-003-player-gravity-component-becomes-consumer.md`
- **2026-08-26** (GA-003 / GA-004: ADR-0001 Changeset A): `GravityAuthority.gravity`
  initializes to `Vector2.ZERO` and NOTHING seeds it at level load. `reset_to()` has zero
  production call sites — verified by grep across `src/`. GA-003 deleted the old seed at
  `player_gravity_component.gd:42` by design; ADR-0001 part 6 puts the replacement in
  `LevelRoot._ready()`, which does not exist yet (LS-004 creates it; GA-005 AC-2 is the
  fix). This has TWO distinct halves and both must be closed together:
  (a) *First load* leaves the player INERT, not merely weightless — `apply_gravity()` adds
  a zero vector, `up_dir`/`right_dir` are `Vector2.ZERO` so movement, jump and wall-jump
  all get a zero basis, and `player.gd` assigns `up_direction = Vector2.ZERO`, which breaks
  floor detection too. Observable evidence: level scenes under `scene_runner` log
  `up_direction can't be equal to Vector2.ZERO`. It is a log line, not a test failure — the
  suite is green — and gravity starts working the moment any zone fires.
  (b) *Every subsequent load* inherits the PREVIOUS level's gravity, because
  `GravityAuthority` is an autoload that survives scene changes and all three transition
  paths (`start_menu.gd:5`, `main.gd:61` `change_level()`, `main.gd:67`
  `reload_current_scene`) leave it untouched. Levels 2-8 and every death-restart therefore
  begin under whatever gravity the player last triggered — precisely the regression
  ADR-0001 part 6 exists to prevent ("a restart never inherits the gravity the player died
  in"). Half (b) is NOT visible as a log line and will not be noticed until levels are
  played in sequence. No interim workaround was added, by explicit developer decision on
  2026-08-26 — tracked from
  `production/epics/gravity-authority/story-003-player-gravity-component-becomes-consumer.md`
- **2026-08-26** (LS-001: `LevelState` — the injectable level-scoped state object):
  ADR-0002's A2-01 correction at `adr-0002-level-state-ownership.md:246-248` states
  "Assignment to a getter-only property raises a runtime error, which is what makes the
  guarantees below properties of the type rather than rules to police." **This is false
  for Godot 4.7.1.** Probed against the binary in four shapes — `Object.set()`, a
  `Variant`-typed reference, a statically-typed reference, and an in-script typed direct
  assignment. All four PARSE, all four leave the backing field unchanged, and NONE raises
  a parse error or a runtime error. An out-of-bounds array read placed in the same script
  body raised loudly, so the silence is real and not a capture artefact. Evidence:
  `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`. Split the claim in
  two: the **safety** half HOLDS (external code cannot corrupt the object, so building
  `LevelState` and `OxygenState` as specified is still correct), while the **detection**
  half DOES NOT (the write is discarded silently, which is exactly the failure mode A2-01
  claimed getter-only properties remove — a caller writing
  `level_state.goal_unlocked = true` gets a no-op with no diagnostic). Two consequences
  already absorbed: LS-001's assignment criterion (QA case AC-4) is ANNOTATED in the story
  rather than reworded, and the
  2026-08-25 QA-plan addendum bullet requiring the test to assert "raises a runtime error,
  not merely that the value is unchanged" is unsatisfiable against a correct
  implementation and is annotated in place. **This applies equally to LS-002
  (`OxygenState`), which uses the same pattern and the same ADR paragraph at `:291` —
  read this row before writing that story's assignment test.** Raise as an ADR-0002
  erratum; the ADR is Accepted and has NOT been amended. Do NOT "fix" this by adding
  error-raising setters without a decision, which would deviate from ADR-0002's Key
  Interfaces — that option was considered and declined on 2026-08-26 in favour of
  annotating — tracked from
  `production/epics/level-state/story-001-level-state-object.md`
- **2026-08-26** (LS-001, incidental): `Object.set()` returns `void` in Godot 4.7.1;
  capturing its return value is itself a script error ("Trying to get a return value of a
  method that returns \"void\""). This corrects an earlier session note describing `set()`
  as returning `null`. Low impact, recorded so the wrong version is not re-derived —
  tracked from `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`
- **2026-08-26** (LS-002: `OxygenState`): `OxygenState._init()` reads `tuning.drain_rate`
  with no null guard, so a null `tuning` crashes rather than reporting through
  `push_error()`. The Foundation manifest's "guard not-bound with `push_error()`" rule is
  written for `bind()`, not for constructors, so this is NOT a manifest violation and was
  deliberately left unfixed to keep LS-002 inside its stated scope (decision 2026-08-26).
  Low impact today: LS-004 is the only planned caller and passes `Tuning.OXYGEN`, which is
  a `preload` constant that fails at parse time if the file is missing. Revisit if any
  second construction site appears — tracked from
  `production/epics/level-state/story-002-oxygen-state-object.md`
- **2026-08-26** (LS-002, incidental — docs conflict, not code): two live and CONFLICTING
  test-function naming rules exist in the repo. `.claude/rules/test-standards.md:8` says
  `test_[system]_[scenario]_[expected_result]`, and its frontmatter is `paths: tests/**`,
  which `.claude/docs/rules-reference.md:3` describes as automatically enforced for
  matching files. `.claude/docs/coding-standards.md:44` says `test_[scenario]_[expected]`
  and is the file CLAUDE.md actually imports. **Every existing suite in the repo follows
  `coding-standards.md`**, so the code is consistent and no test needs renaming; the rules
  file is the outlier. Left unresolved because picking the survivor is a standards
  decision, not an implementation one. Resolve by deleting the duplicated line from one of
  the two files rather than by editing tests — tracked from
  `production/epics/level-state/story-002-oxygen-state-object.md`

## Closed

- **2026-08-26** — CLOSED by GA-003. (GA-002: Direction easing and the exported rate): the
  QA-plan addendum's instruction to delete `test_gravity_lerp_moves_toward_target` and
  `test_gravity_lerp_noop_when_already_at_target` from `gravity_component_test.gd` was
  deferred to Story 003. GA-003 removed `update_gravity_lerp()` and both tests; verified
  absent from `tests/unit/gravity/gravity_component_test.gd` on 2026-08-26.
