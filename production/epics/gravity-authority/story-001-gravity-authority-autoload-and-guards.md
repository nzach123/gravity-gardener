# Story 001: Create the GravityAuthority scene autoload and its guards

> **Epic**: Gravity Authority
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story)*

## Context

**GDD**: `design/gdd/gravity.md`
**Requirement**: `TR-gravity-001`, `TR-gravity-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**ADR Decision Summary**: Gravity moves out of the player into a `GravityAuthority`
autoload that is the single source of the world gravity vector. Zones declare, the
authority owns, the player and props consume. This story builds parts 1 and 7 — the
node, its state, its public API, and the two guards.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `modules/physics-2d.md` (verified 2026-08-13) states 2D physics is
unchanged 4.4 to 4.7. No post-cutoff API is used here: `lerp_angle`, autoload
registration, and `push_error()` all predate 4.4. Jolt (`3d/physics_engine`) is inert
in this 2D project and must not inform any review of this story.

**Performance**: One extra autoload instantiation at load. No per-frame cost — the
ease loop and the space write arrive in stories 002 and 006.

**Control Manifest Rules (this layer)**:
- Required: "Gravity is owned exclusively by the `GravityAuthority` autoload. Read via
  `GravityAuthority.gravity` / `.up_dir` / `.right_dir`, or by connecting to
  `gravity_changed(direction, multiplier)`. Written ONLY by `set_gravity()` /
  `reset_to()`." — source: ADR-0001
- Required: "`GravityAuthority` must be a *scene* autoload (`gravity_authority.tscn`
  with script attached), never a bare script autoload." — source: ADR-0001
- Required: "Do NOT declare `class_name` on `gravity_authority.gd`." — source: ADR-0001
- Required: "Use `push_error()`, never `assert()`, for bind/initialize guards —
  `assert()` compiles out entirely in release exports." — source: ADR-0001, ADR-0002
- Forbidden: "Never call `set_gravity()`/`reset_to()` before
  `GravityAuthority.initialize()`." — source: ADR-0001 (`broadcast_before_initialize`)
- Forbidden: "Never recompute `jump_velocity` after `initialize()`." — source:
  ADR-0001 (`recompute_jump_velocity`)

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` R1, R7 and AC4/AC7, scoped to this story:*

- [ ] `src/scripts/autoloads/gravity_authority.gd` exists, `extends Node`, and carries
      **no** `class_name` declaration.
- [ ] `src/scripts/autoloads/gravity_authority.tscn` exists with that script attached,
      and `project.godot` `[autoload]` registers the **scene** path
      (`*res://src/scripts/autoloads/gravity_authority.tscn`), not the `.gd`.
- [ ] The public API matches ADR-0001 *Key Interfaces* exactly: `gravity_changed`
      signal, `@export var direction_ease_rate: float = 32.0`, `gravity`, `up_dir`,
      `right_dir`, and the methods `initialize`, `reset_to`, `set_gravity`,
      `register_prop`, `unregister_prop`, `ascent_magnitude`, `descent_magnitude`.
- [ ] `up_dir` is `-gravity.normalized()` and `right_dir` is
      `Vector2(-up_dir.y, up_dir.x)` at every gravity angle (GDD R1).
- [ ] AC7 — `set_gravity()` with a zero-length direction leaves `gravity`,
      `target_gravity` and the magnitudes untouched and emits no signal.
- [ ] A `multiplier <= 0.0` is rejected identically: state untouched, no signal (GDD R7).
- [ ] AC4 — `ascent_descent_ratio` is written once by `initialize()` and is unchanged
      after any sequence of `set_gravity()` / `reset_to()` calls.
- [ ] `set_gravity()` or `reset_to()` called before `initialize()` `push_error()`s,
      refuses to broadcast, and leaves state untouched (GDD section 5).
- [ ] `direction_ease_rate` is reachable and editable from the Godot inspector when
      the autoload scene is opened — the export is real, not decorative
      (TR-gravity-011 mitigation; the epic Risks table calls this out by name).

---

## Implementation Notes

*Derived from ADR-0001 decision parts 1 and 7:*

- The authority holds `gravity`, `target_gravity`, `baseline_ascent_mag`,
  `ascent_descent_ratio` and `direction_ease_rate`. These move out of
  `player_gravity_component.gd` in story 003 — this story creates them fresh on the
  authority, so the two files temporarily both declare them. That overlap is expected
  and closes in story 003.
- `initialize(baseline_ascent_mag: float, ascent_descent_ratio: float)` is public
  seedable API on purpose. It is what makes every acceptance criterion here testable
  headless with no `Player` and no rendered scene (ADR-0001 Alternative 3 rejection
  reason). Do not make it private or `_ready()`-driven.
- The initialize guard is a single boolean set inside `initialize()`. Both
  `set_gravity()` and `reset_to()` check it first and return early after
  `push_error()`. Do **not** use `assert()` — it compiles out of release exports, so
  the guard would silently vanish in the build that matters.
- Validation order inside `set_gravity()` matters: check the initialize gate, then the
  direction, then the multiplier, and touch no state until all three pass. AC7 requires
  gravity to be *unchanged*, which a partially-applied write would violate.
- `ascent_magnitude()` returns `baseline_ascent_mag * current_multiplier`;
  `descent_magnitude()` returns `ascent_magnitude() / ascent_descent_ratio`. Deriving
  descent rather than storing it is what makes AC4 structural — there is no second
  field that can drift.
- `jump_velocity` is **not** a field on the authority. It stays derived once on
  `PlayerGravityComponent` and is never recomputed by any path here.
- `register_prop` / `unregister_prop` are declared with their signatures in this story
  so the contract is complete, but their body is story 007's. An empty body with a
  `# Story 007` marker is acceptable; a missing method is not, because ADR-0011's
  `PropBody` is written against this interface.
- Scene autoload, not script autoload. A bare script autoload gives
  `@export var direction_ease_rate` no inspector surface, which leaves the value
  effectively hardcoded — the exact defect TR-gravity-011 exists to fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the `_physics_process` direction ease and its use of `direction_ease_rate`.
- Story 003: removing `gravity` / `target_gravity` / `set_gravity()` from
  `PlayerGravityComponent`, and removing `Player.set_gravity()`.
- Story 004: rewiring zones and the camera; clearing `gravity_space_override`.
- Story 005: `default_gravity_direction` / `default_gravity_multiplier` on levels.
- Story 006: the `PhysicsServer2D` default-space write.
- Story 007: the prop registry body and the force-wake pass.

---

## QA Test Cases

*Story type: **Logic**. Every case runs headless with no `Player` and no scene —
seed the authority with `initialize()` directly.*

Fixture for all cases below unless stated otherwise:
`initialize(2990.72, 0.390625)` — the GDD section 4 *Current values* baseline.

- **AC-1 / AC-2 / AC-3 — structural contract**
  - Given: the project is loaded
  - When: the test reads `ProjectSettings.get_setting("autoload/GravityAuthority")`
  - Then: the value ends in `.tscn`, not `.gd`
  - Edge cases: assert the string contains `gravity_authority.tscn` — a `.gd` path here
    is the bare-script-autoload defect and must fail loudly, not be tolerated.

- **AC-4 — basis derivation at every angle**
  - Given: an initialized authority
  - When: `reset_to(dir, 1.0)` for `dir` in DOWN, UP, RIGHT, LEFT
  - Then: `up_dir == -dir.normalized()` and `right_dir == Vector2(-up_dir.y, up_dir.x)`
    for each, within `is_equal_approx` tolerance
  - Edge cases: include one non-axis angle (45 degrees) to prove the derivation is
    angular and not a four-case lookup. GDD AC10 requires the system to hold at any angle.

- **AC-5 — zero-length direction is rejected (GDD AC7)**
  - Given: an initialized authority at `reset_to(Vector2.DOWN, 1.0)`
  - When: `set_gravity(Vector2.ZERO, 1.0)` is called
  - Then: `gravity`, `target_gravity`, `up_dir`, `right_dir`, `ascent_magnitude()` and
    `descent_magnitude()` all equal their pre-call values, and `gravity_changed` did
    not fire
  - Edge cases: also test a direction that is non-zero but degenerate under
    `is_zero_approx` — e.g. `Vector2(1e-9, 0)`. Use `is_zero_approx()`, not
    `== Vector2.ZERO`; an exact comparison lets a near-zero vector through and produces
    a NaN angle.

- **AC-6 — non-positive multiplier is rejected**
  - Given: an initialized authority at `reset_to(Vector2.DOWN, 1.0)`
  - When: `set_gravity(Vector2.UP, m)` for `m` in `0.0`, `-1.0`, `-0.0001`
  - Then: state unchanged and no signal, for each
  - Edge cases: `m = 0.0001` (smallest positive tested) must be **accepted** — the rule
    is `<= 0`, not "implausibly small". A test that only checks `0.0` and `-1.0` would
    pass on an over-strict guard.

- **AC-7 — ratio invariance (GDD AC4)**
  - Given: `initialize(2990.72, 0.390625)`
  - When: a sequence of ten `set_gravity()` calls with multipliers
    `[0.5, 2.0, 1.0, 0.25, 4.0, 1.0, 0.5, 3.0, 0.1, 1.0]` and varying directions,
    interleaved with two rejected calls (zero direction, negative multiplier)
  - Then: `ascent_magnitude() / descent_magnitude()` equals `0.390625` after every
    single call, within 1e-6
  - Edge cases: assert after *each* call, not only at the end — a ratio that drifts and
    returns would pass an end-only assertion. Also assert `descent_magnitude()` is
    never zero, which would make the ratio undefined rather than wrong.

- **AC-8 — broadcast before initialize is refused (GDD section 5)**
  - Given: a fresh `GravityAuthority` on which `initialize()` has **not** been called
  - When: `set_gravity(Vector2.DOWN, 1.0)` and then `reset_to(Vector2.UP, 2.0)`
  - Then: both `push_error()`, neither emits `gravity_changed`, and `gravity` is still
    its uninitialized value
  - Edge cases: assert the *refusal*, not just the absence of a crash. The failure this
    guards is silent — a 1.0 default ratio broadcasting successfully and losing the R4
    asymmetry. A test asserting "no exception" would pass on exactly that bug.
    Verify the error is raised via `push_error`, not `assert` — grep the source for
    `assert(` in the guard path as a companion check, since `assert()` compiles out of
    release and the test would then pass on a build that has no guard at all.

### Manual verification

- [ ] **AC-9** — Open `gravity_authority.tscn` in the Godot editor.
  - Setup: open the scene from the FileSystem dock and select the root node.
  - Verify: `Direction Ease Rate` appears in the inspector, shows `32.0`, and accepts an
    edited value that persists on save.
  - Pass condition: the field is present and editable. A missing field means the autoload
    was registered as a bare script and TR-gravity-011 is not closed.
  - Screenshot to `production/qa/evidence/gravity-authority-autoload-evidence.md`.

**Estimated test count**: ~30 assertions.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/gravity/gravity_authority_contract_test.gd` — must exist and pass
- Supplementary inspector screenshot in
  `production/qa/evidence/gravity-authority-autoload-evidence.md` for AC-9 only

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the root Foundation story of the epic
- Unlocks: Story 002, Story 003, Story 004, Story 007
