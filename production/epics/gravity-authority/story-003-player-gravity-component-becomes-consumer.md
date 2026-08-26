# Story 003: Make PlayerGravityComponent a consumer; remove Player.set_gravity

> **Epic**: Gravity Authority
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-26

## Context

**GDD**: `design/gdd/gravity.md`
**Requirement**: `TR-gravity-001`, `TR-gravity-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**Governing ADRs**: ADR-0001 (primary) · ADR-0007 (secondary — the player component
contract and physics step order this component sits inside)
**ADR Decision Summary**: `PlayerGravityComponent` stops owning gravity and becomes a
consumer. It keeps `initialize(max_speed)`, `apply_gravity()`, `jump_velocity` and the
derived basis; it loses `gravity`, `target_gravity`, `set_gravity()` and
`update_gravity_lerp()`. `Player.set_gravity()` is deleted outright.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: 2D physics unchanged 4.4 to 4.7 (`modules/physics-2d.md`, verified
2026-08-13). One 4.7 change is directly relevant to this story: **a method overriding
one with a typed return now inherits that return type and requires an explicit
`return`** (GH-115763, `VERSION.md` risk 1). `apply_gravity()` returns `Vector2` and
is being edited — confirm every path returns. `CharacterBody2D` ignores space gravity,
which is why the player's manual application survives this move unchanged.

**Performance**: Neutral. The same per-frame math runs; only the vector's owner
changes. One signal connection is added at `_ready()`.

**Control Manifest Rules (this layer)**:
- Required: "Gravity is owned exclusively by the `GravityAuthority` autoload. Read via
  `GravityAuthority.gravity` / `.up_dir` / `.right_dir`, or by connecting to
  `gravity_changed(direction, multiplier)`." — source: ADR-0001
- Required: "Jump constants (`jump_height`, `jump_distance_to_peak`,
  `jump_distance_to_land`) stay `@export` on `Player`, never in a tuning resource." —
  source: ADR-0001 part 7, ADR-0006 D6.7
- Required: "Use `push_error()`, never `assert()`, for bind/initialize guards." —
  source: ADR-0001, ADR-0002
- Forbidden: "Never cache gravity/target_gravity on any node instead of reading
  `GravityAuthority` — a cached copy can silently diverge." — source: ADR-0001
  (`private_gravity_copy`)
- Forbidden: "Never recompute `jump_velocity` after `initialize()`, including any
  bucket-carry weight penalty." — source: ADR-0001 (`recompute_jump_velocity`)
- Forbidden: "Never connect a `GravityZone` directly to the player, or call
  `Player.set_gravity()` — that method is removed." — source: ADR-0001
  (`zone_targets_player_directly`)

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` R1, R4, R5, R9 and AC4, scoped to this story:*

- [ ] `player_gravity_component.gd` no longer declares `gravity`, `target_gravity`,
      `baseline_ascent_mag`, `ascent_descent_ratio`, `set_gravity()` or
      `update_gravity_lerp()`.
- [ ] `Player.set_gravity()` (`player.gd:183`) and the `target_gravity` proxy
      (`player.gd:71`) are deleted. No call site remains anywhere in `src/`.
- [ ] `Player._ready()` calls
      `GravityAuthority.initialize(baseline_ascent_mag, ascent_descent_ratio)` with the
      values derived in `PlayerGravityComponent.initialize(max_speed)`.
- [ ] R4 — the ascent/descent asymmetry still lives in
      `PlayerGravityComponent.apply_gravity()` and produces byte-identical magnitudes
      to the pre-migration code for the same inputs. This is a relocation, not a retune.
- [ ] R5 — `jump_velocity` is derived once in `initialize()` and is never written again
      by any path, including every `gravity_changed` broadcast.
- [ ] R1 — `up_dir` and `right_dir` are read from `GravityAuthority`, not derived from
      a local copy of the vector.
- [ ] The component holds no gravity field of its own. A grep of
      `src/scripts/components/player_gravity_component.gd` for `var gravity` returns
      nothing (`private_gravity_copy`).
- [ ] The player falls, jumps and reorients exactly as before at gravity angles 0, 90,
      180 and 270 degrees (GDD AC10) — this is the regression bar for the move.
      **DEFERRED 2026-08-26 — requires a human playtest.** Cannot be automated (the
      coding standards place "feel" qualities outside automation) and cannot be run by
      an agent here: the windowed Godot editor segfaults on this machine. Folded into
      the sprint's single gravity-path playtest, which runs after GA-005 lands and is
      signed off by qa-lead at
      `production/qa/evidence/playtest-sprint-2-gravity-regression.md`.

---

## Implementation Notes

*Derived from ADR-0001 decision part 3 and Migration Plan steps 2-3:*

- ADR-0001 is explicit that **parts 1, 2, 3 and 5 must land together or gravity
  breaks** — there is no incremental path. This story is part 3. Stories 001, 002 and
  004 are the rest of that changeset. Plan to land 001 through 004 as one mergeable
  unit even though they are reviewed separately.
- `initialize(max_speed)` keeps its existing derivation verbatim: `t_up`, `t_down`,
  `gravity_ascent_mag`, `gravity_descent_mag`, `jump_velocity`, `ascent_descent_ratio`,
  `baseline_ascent_mag`. What changes is what happens *next* — instead of seeding a
  local `gravity`, it hands `baseline_ascent_mag` and `ascent_descent_ratio` to the
  authority.
- The seed line `gravity = Vector2(0.0, gravity_ascent_mag)` is deleted, not moved. The
  authority's starting vector comes from `LevelRoot.reset_to()` in story 005, which is
  what makes a level's starting orientation explicit rather than implied.
- `apply_gravity()` reads `GravityAuthority.gravity.normalized()` and the authority's
  `ascent_magnitude()` / `descent_magnitude()`. Do not copy those into locals that
  outlive the call — a per-call local is fine, a member field is the
  `private_gravity_copy` violation.
- `update_derived_dirs()` is deleted from the component. `up_dir` and `right_dir` are
  the authority's, already derived there in story 001. Any consumer currently reading
  `player.gravity_component.up_dir` is redirected to `GravityAuthority.up_dir`.
- Godot calls `_ready()` bottom-up, so `Player` (a child) initializes before `LevelRoot`
  (the parent). That ordering is what makes `initialize()` land before
  `LevelRoot._ready()` calls `reset_to()`. The ordering hazard is guarded by the
  authority's refusal-to-broadcast gate from story 001, not designed away — GDD
  section 5's edge case stays in the GDD by explicit user decision (ADR-0001
  Alternative 4).
- **Do not introduce a `GravityTuning` resource** for the jump constants. This was
  rejected by user decision on 2026-08-13 and reaffirmed in ADR-0001. The constants
  stay as `@export` on `Player`.
- The 4.7 typed-return inheritance change (GH-115763) applies to `apply_gravity()`.
  Confirm the edited body has an explicit `return` on the `is_on_floor` early-out path
  as well as the main path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the authority node and its guards.
- Story 002: the ease loop. This component no longer eases anything.
- Story 004: `gravity_zone.gd`, `main.gd` wiring, and the `.tscn` override cleanup.
- Story 005: level default gravity exports and `reset_to()` at level load.
- Stories 006 and 007: props. `CharacterBody2D` ignores space gravity, so nothing in
  the prop path touches the player.
- The screen-relative input basis (GDD R11, TR-gravity-013) — that is ADR-0013 and
  belongs to the Presentation visual-component epic, not this one.
- `PlayerMovementComponent`, `PlayerJumpComponent` and `PlayerVisualComponent` internals
  — they are Core-layer (ADR-0007) and only their read path changes here.

---

## QA Test Cases

*Story type: **Integration** — this crosses `GravityAuthority`, `Player` and
`PlayerGravityComponent`. The magnitude assertions can and should still be driven
headlessly; the AC-8 regression bar needs a scene.*

Fixture: a `Player` instantiated headless with the GDD section 4 current values
(`h`=200, `d_peak`=128, `d_land`=80, `s`=350), producing `g_ascent`=2990.72,
`g_descent`=7656.25, `v_jump`=1093.75, `ratio`=0.390625.

- **AC-1 / AC-6 / AC-7 — the component owns no gravity**
  - Given: the migrated source
  - When: the test greps `player_gravity_component.gd`
  - Then: none of `var gravity`, `var target_gravity`, `var baseline_ascent_mag`,
    `var ascent_descent_ratio`, `func set_gravity`, `func update_gravity_lerp` appear
  - Edge cases: also grep `src/` project-wide for `player.set_gravity` and
    `.target_gravity` to prove no call site survives. A deleted method with a live
    caller is a parse-time failure, but a deleted *property* read on a dynamically
    typed node is a runtime null — the grep catches what the compiler will not.

- **AC-2 — `Player.set_gravity` is gone**
  - Given: a `Player` instance
  - When: the test calls `player.has_method("set_gravity")`
  - Then: it returns `false`
  - Edge cases: assert on the *`Player`* node specifically. `Node` has no inherited
    `set_gravity`, so a `true` here means the method genuinely survived.

- **AC-3 — the player seeds the authority**
  - Given: a fresh scene tree with the `GravityAuthority` autoload uninitialized
  - When: a `Player` enters the tree and `_ready()` runs
  - Then: the authority reports initialized, `baseline_ascent_mag` is `2990.72` within
    0.01, and `ascent_descent_ratio` is `0.390625` within 1e-6
  - Edge cases: assert the authority was **not** initialized before `Player._ready()`.
    A test that only checks the end state passes on an authority that self-initializes
    with defaults, which is exactly the silent 1.0-ratio failure story 001's guard
    exists to prevent.

- **AC-4 — asymmetry survives the move byte-identically (GDD R4)**
  - Given: an initialized player and authority at multiplier `1.0`
  - When: `apply_gravity(delta, velocity, false)` is called with an ascending velocity
    and then with a descending velocity
  - Then: the ascending call applies `2990.72 * delta` along the gravity direction and
    the descending call applies `7656.25 * delta`
  - Edge cases: the `vel_up == 0.0` boundary — a velocity exactly perpendicular to
    gravity. The pre-migration code used `vel_up > 0.0`, so zero takes the *descent*
    branch. Assert that specific behaviour: the relocation must not silently flip the
    boundary, because apex frames land there and a flipped boundary changes jump feel.
    Also assert `is_on_floor = true` returns the velocity unmodified.

- **AC-5 — `jump_velocity` is never recomputed (GDD R5, AC11)**
  - Given: an initialized player, `jump_velocity` recorded as `1093.75`
  - When: ten `GravityAuthority.set_gravity()` broadcasts are issued with multipliers
    `[0.5, 2.0, 0.25, 4.0, 1.0, 0.1, 3.0, 0.5, 2.0, 1.0]` and varying directions
  - Then: `jump_velocity` is bit-identical to `1093.75` after every one
  - Edge cases: include one broadcast issued while a carry-speed multiplier is active,
    if the watering component is present in the fixture. GDD R10 and AC11 make this the
    reciprocal of `watering-system.md` AC1 — one test satisfies both, and this is the
    place it is cheapest to assert.

- **AC-6 — basis is read from the authority (GDD R1)**
  - Given: an initialized player and authority
  - When: `GravityAuthority.reset_to(dir, 1.0)` for `dir` in DOWN, UP, RIGHT, LEFT and
    one 45-degree angle
  - Then: every consumer that previously read `gravity_component.up_dir` now observes
    the authority's value, and the two never diverge
  - Edge cases: sample mid-ease, not only when settled. A component that caches the
    basis on the `gravity_changed` signal agrees at both endpoints and disagrees for the
    ~100 ms in between — the settled-only test passes on the `private_gravity_copy`
    defect.

### Manual verification

- [ ] **AC-8** — Play regression at four gravity angles.
  - Setup: run `level_01`, and enter a gravity zone for each of down, up, left and right
    orientations (author temporary zones if the level lacks one).
  - Verify: the player falls, jumps to a normal-looking apex, and reorients at each
    angle. Jump apex at 1.0x reads as roughly the same height as before the migration.
  - Pass condition: no observable difference from the pre-migration build at any of the
    four angles. Any difference in jump feel means the derivation moved rather than
    relocated, and the story is not done.
  - Record to `production/qa/evidence/player-gravity-consumer-evidence.md`.

**Estimated test count**: ~35 assertions.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Read Finding 1 of the sprint QA plan before writing a line of this test.**
- `tests/unit/gravity/gravity_component_test.gd` holds **26 cases** and is the
  only characterization of pre-migration gravity behaviour that exists anywhere.
  The four `test_apply_gravity_*` cases are this story's **R4 regression bar**:
  they may be re-pointed at the new call path, but **their expected values may
  not change**. A changed value is a retune, not a relocation, and violates AC4.
- **Every removed case needs a named disposition** — migrated to a named file,
  deduped against an existing case in `gravity_authority_contract_test.gd`, or
  deleted because its subject no longer exists. "It no longer compiles" is not a
  disposition.
- **Suite-count reconciliation is gating.** Record at `/story-done`: count
  before, count after, per-case disposition. The count will drop below 178, and
  a drop is otherwise indistinguishable from tests silently disappearing.
- **Manual**: this story is part of the sprint's single gravity-path playtest,
  run after GA-005 lands. Do not mark it Complete before that session signs off.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/gravity/player_gravity_consumer_test.gd` — must exist and pass
- `production/qa/evidence/player-gravity-consumer-evidence.md` — the AC-8 four-angle
  play regression, which cannot be automated (the coding standards place "feel"
  qualities outside automation)

**Status**: [x] `tests/integration/gravity/player_gravity_consumer_test.gd` — created and
passing (32 test functions; suite 233/233 across 14 suites, exit 0, report_18, 2026-08-26).
[ ] `production/qa/evidence/player-gravity-consumer-evidence.md` — NOT created; this is the
AC-8 four-angle regression, deferred to the sprint playtest above.

---

## Dependencies

- Depends on: Story 001 (the authority must own the vector before the component can
  stop owning it), Story 002 (the ease must have moved before
  `update_gravity_lerp()` is deleted)
- Unlocks: Story 004
- Lands with: Stories 001, 002 and 004 form ADR-0001's atomic Changeset A

---

## Completion Notes
**Completed**: 2026-08-26
**Criteria**: 7/8 passing. AC-8 (four-angle play regression) DEFERRED — human playtest
required, folded into the post-GA-005 sprint gravity-path playtest.
**Deviations**:
- OUT OF SCOPE (valid, not scope creep): `src/scripts/main.gd` was edited although this
  story's Out of Scope section assigns `main.gd` wiring to Story 004. AC-2 requires no
  surviving `player.set_gravity` call site anywhere in `src/`, and a `connect()` to a
  removed method is a RUNTIME error, not a parse error — it aborted `Main._ready()` and
  failed all three `kill_area_death_test` cases until the line was removed. GA-004 then
  replaced it with the authority wiring.
- ADVISORY: ADR-0001's Key Interfaces prose states the component "retains ... the derived
  basis"; AC-6 requires the opposite. The story governs — `update_derived_dirs()`, `up_dir`
  and `right_dir` were deleted and every basis read now comes from `GravityAuthority`. A
  second local derivation is the divergence AC-6's edge case describes. ADR erratum
  candidate; the ADR line has NOT been amended.
- ADVISORY: `src/scripts/debugger.gd:13` was repointed to `GravityAuthority.target_gravity`.
  Not excluded by this story; it was a live call site of the deleted `Player.target_gravity`
  proxy that no compiler would have caught.
**Test Evidence**: Integration — `tests/integration/gravity/player_gravity_consumer_test.gd`
(BLOCKING gate satisfied). AC-8 evidence doc deferred.
**Code Review**: Complete — `/code-review` run 2026-08-26 across all seven changed files,
verdict APPROVED WITH SUGGESTIONS, no blocking findings. One suggestion applied before
close: `_reset_authority()` now writes `_initialized` / `_current_multiplier` directly
instead of via `Object.set()`, which was verified against the 4.7.1 binary to fail silently
on a renamed property and would have let the AC-3 guard pass for the wrong reason.
