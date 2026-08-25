# Story 005: `apply_screen_relative_axis` and the `PlayerMovementComponent` caller

> **Epic**: Player Core
> **Status**: Ready
> **Layer**: Core *(with one Foundation-tier addition — see Scope Note)*
> **Type**: Logic
> **Estimate**: L (3-4 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/gravity.md` (R11, §4 Input basis, AC13, AC14, AC15)
**Requirement**: `TR-gravity-013` (the `PlayerMovementComponent` caller half only — see
Scope Note)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Screen-relative input basis
**Governing ADRs**: ADR-0013 (primary, D13.2 / D13.3 / D13.4) · ADR-0007 (secondary, D7.4 —
**its method contract is superseded by ADR-0013**; D7.4's one-function stance is preserved)
**ADR Decision Summary**: Screen-relative axis inversion exists in exactly one place:
`GravityAuthority.apply_screen_relative_axis(input_axis, right_dir, camera_rotation)`, a
stateless static function. It is parameterised by the camera's *actual* rotation rather than
by a boolean flag, so it is exact at every camera angle rather than only at the two
endpoints. The `camera_rotation_enabled` flag is deleted, because no combination of it and
`camera_moving` can satisfy `accessibility-requirements.md` T8.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `Vector2.rotated`, `signf`, `is_zero_approx` and static-method dispatch
through an autoload name are all pre-4.4 and unchanged through 4.7. A static method called
through the autoload singleton name was **CONFIRMED** correct for 4.4-4.7 at the 2026-08-15
architecture review (`architecture-review-2026-08-15-b.md:153`). `Viewport.get_camera_2d()`
returning `null` when no camera is current was verified against the official 4.7 class
documentation on 2026-08-18. **GH-115763 does not apply** — the function overrides nothing.

**Control Manifest Rules (Core layer)**:
- Required: screen-relative axis inversion exists in exactly one place,
  `GravityAuthority.apply_screen_relative_axis()` (static). Both `PlayerMovementComponent`
  and `PlayerVisualComponent` call it — never independent copies — source ADR-0013 (D13.2),
  stance originating in ADR-0007 (D7.4).
- Forbidden: never apply the raw input axis directly to `right_dir` — source, Core layer
  forbidden list.
- Forbidden: `input_basis_gated_on_boolean_camera_flag` — source ADR-0013 (D13.4),
  registered in `docs/registry/architecture.yaml`.
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`). `camera_rotation` is subject to the same freshness rule and must
  stay a per-frame local (D13.3).

---

## Scope Note — this story absorbs an unowned ADR-0013 step

ADR-0013's Implementation step 1 puts `static func apply_screen_relative_axis(...)` on
`GravityAuthority`, which is a **Foundation** module. No `gravity-authority` story adds it —
that epic's story 003 (`:131`) routes ADR-0013 to "the Presentation visual-component epic",
and **no such epic exists**: `production/epics/index.md` lists `physics-props` as the only
Presentation epic, with HUD / Pause Menu still un-epic'd.

The function has exactly two callers. One (`PlayerMovementComponent`) is this epic's module;
the other (`PlayerVisualComponent`) belongs to the absent Presentation epic. Rather than
reopen a decomposed epic, **this story takes the Foundation function**, because its Core
caller cannot be implemented without it and this epic is the first to need it.

`TR-gravity-013` is therefore **half-owned on purpose**. The `PlayerVisualComponent` caller
stays out of scope here and is recorded as an open risk in `production/epics/index.md`. The
requirement does not close until that caller lands.

**A second, smaller seam, recorded and not acted on.** ADR-0013 scopes its supersession to
"the **method contract** of ADR-0007 D7.4 only", but D7.3's code block also passes
`camera_rotation_enabled` at its step 6 and step 8 call sites. Those call sites must change
to `camera_rotation` for D13.2 to receive anything usable, and no ADR text says so. This
story makes the change; neither ADR is amended.

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md`, scoped to this story:*

- [ ] AC13 — `move_right` moves the player toward the right of the screen at gravity angles
      0° and 180°, and toward the top of the screen at 90° and 270°.
- [ ] AC14 — during any gravity ease, the dot product of the on-screen walk direction with
      screen-right never becomes negative.
- [ ] AC15 — AC13 holds at `camera_rotation` = 0, at the fully-turned camera angle, and at
      ten evenly spaced points between.
- [ ] `GravityAuthority` declares `static func apply_screen_relative_axis(input_axis: float,
      right_dir: Vector2, camera_rotation: float) -> float` with the
      `# static: no self access` comment at the definition site.
- [ ] `PlayerMovementComponent.apply()` calls it and contains no inline `sign(` axis branch.
- [ ] `camera_rotation_enabled` is deleted from `player.gd`, from `main.gd`'s export, and
      from `main.gd`'s forward. No reference to the identifier remains anywhere in `src/`.
- [ ] `camera_rotation` is a per-frame local in `Player._physics_process`, stored in no
      field.

---

## Implementation Notes

*Derived from ADR-0013 D13.2, D13.3, D13.4 and its Implementation steps 1-3:*

- The function body is given verbatim by D13.2 and must not be re-derived:

  ```gdscript
  # static: no self access — pure function of its parameters, not autoload state.
  # Colocated here because right_dir is the only gravity-derived input and
  # GravityAuthority already owns it.
  static func apply_screen_relative_axis(
      input_axis: float, right_dir: Vector2, camera_rotation: float
  ) -> float:
      var rd_screen: Vector2 = right_dir.rotated(-camera_rotation)
      if not is_zero_approx(rd_screen.x):
          return input_axis * signf(rd_screen.x)
      return input_axis * -signf(rd_screen.y)
  ```

- **The two endpoints are the proof it is the general law**, and both are checked in
  ADR-0013 D13.2. At `camera_rotation == 0.0`, `rd_screen == right_dir` and the body becomes
  `gravity.md` §4's `screen_sign` formula character for character. At the fully-turned angle,
  `rd_screen == (1, 0)` and the result is the raw `input_axis` — the old
  `camera_rotation_enabled == true` branch. It is exact at every value between, and that is
  what removes the 500 ms inverted-controls window.
- The `null`-camera fallback of `0.0` (story 001, D13.3) means a headless test with no camera
  exercises the GDD's own §4 formula. **Assert against §4's table in that configuration** —
  that is what ADR-0013 says `TR-gravity-013`'s tests should do.
- **`camera_rotation` is a `float` where the old parameter was a `bool`.** ADR-0013 records
  that the rename away from `apply_camera_relative_axis` is deliberate for exactly this
  reason: the old name must not survive and silently accept a truthy value.
- Deleting `camera_rotation_enabled` is **not tidying**. D13.4's four-row table proves T8
  ("disable the 0.6 s viewport rotation without disabling camera-follow and without leaving
  the input basis inverted") is unreachable in data while three flags gate two behaviours.
  Removing this leg is a required code change.
- `Camera2D.ignore_rotation` is a precondition, not a guard. `main.gd:13` sets it `false`.
  ADR-0013 records this as a risk and deliberately does not add a runtime check. Do not add
  one.
- A side effect worth keeping: under this formula the effective screen walk vector's
  x-component is `|rd_screen.x| >= 0` by construction, so `gravity.md` §5's "Mid-transition
  input" claim becomes true rather than needing to be weakened. AC14 is testing that.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **`PlayerVisualComponent.update()`'s caller (ADR-0013 Implementation step 4)** — belongs
  to the un-created Presentation visual epic. Its inline axis branch at
  `player_visual_component.gd:46-50` stays as-is until that epic exists. See the Scope Note.
- **The camera follow/rotate split (ADR-0013 D13.5, `TR-gravity-010`)** — **Blocked**. Owner
  is `technical-director`, gated on a human playtest of `level_01` and `level_07`. ADR-0013
  specifies the split and deliberately does not apply it. `gravity-authority` story 004 holds
  it. Do not add `camera_follow_enabled` or `camera_rotates_with_gravity` here.
- Story 001: the `camera_rotation` live read at step 1 and threading it into steps 6 and 8.
  This story changes what the callees do with the value.
- Stories 002-004: gravity, jump and carry. None of them inverts an axis.
- `gravity-authority` story 004: `main.gd` camera-signal rewiring. This story touches
  `main.gd` **only** to delete the `camera_rotation_enabled` export and forward
  (`main.gd:9`, `main.gd:15`), per D13.4.

---

## QA Test Cases

*Story type: **Logic** — `apply_screen_relative_axis` is a pure function of three
parameters, which ADR-0013 notes makes a table-driven test the natural form. No scene is
required.*

- **AC-1 — the §4 table holds at `camera_rotation = 0` (GDD AC13, ADR-0013 V1)**
  - Given: `camera_rotation = 0.0` and `input_axis = 1.0`
  - When: `apply_screen_relative_axis` is evaluated for each row of `gravity.md` §4's table —
    gravity down (`right_dir` = `(1,0)`), up (`(-1,0)`), right (`(0,-1)`), left (`(0,1)`)
  - Then: the returned `screen_sign` is `+1, -1, +1, -1` respectively, and applying it to
    `right_dir` yields a world vector whose screen projection points screen-right (angles 0°
    and 180°) or screen-up (angles 90° and 270°)
  - Edge cases: assert `input_axis = -1.0` mirrors every row exactly, and `input_axis = 0.0`
    returns `0.0` (signed-zero must not leak — assert `result == 0.0`, not `is_zero_approx`)

- **AC-2 — the two endpoints reduce to the ADR's stated cases (ADR-0013 D13.2)**
  - Given: `input_axis = 1.0`, gravity right (`right_dir` = `(0,-1)`)
  - When: evaluated at `camera_rotation = 0.0`, then at
    `camera_rotation = Vector2.DOWN.angle_to(gravity_dir)` (camera fully turned)
  - Then: the first equals `gravity.md` §4's `screen_sign` for that row; the second returns
    the raw `1.0`
  - Edge cases: at the fully-turned angle, assert `right_dir.rotated(-camera_rotation)` is
    `(1, 0)` to within `is_equal_approx` — if it is not, the fixture's camera angle is wrong
    and every other assertion in this test is measuring nothing

- **AC-3 — exact at ten points between the endpoints (GDD AC15, ADR-0013 V4)**
  - Given: `input_axis = 1.0`, each of the four cardinal gravity directions
  - When: evaluated at twelve `camera_rotation` values — 0, the fully-turned angle, and ten
    evenly spaced points between
  - Then: at every one of the 48 combinations, the resulting screen walk vector has a
    non-negative x-component
  - Edge cases: include the `rd_screen.x == 0` crossing explicitly (a camera rotation that
    puts the walk axis exactly vertical on screen) — that is the branch the
    `is_zero_approx` guard exists for, and the fallback must return
    `input_axis * -signf(rd_screen.y)`, not `0.0`

- **AC-4 — no sign inversion during an ease (GDD AC14)**
  - Given: `GravityAuthority` easing from down-gravity to right-gravity, with the camera
    rotating over the same interval
  - When: `_physics_process(1.0 / 60.0)` is driven for the full ease, sampling the screen
    walk vector every frame with `input_axis = 1.0`
  - Then: the dot product of the screen walk direction with screen-right is never negative
    on any frame
  - Edge cases: run the ease in both directions, and run one where the camera is *not*
    rotating at all (`camera_rotation` held at 0) — that is the reduced-motion configuration
    T8 wants, and AC14 must hold there too

- **AC-5 — one implementation, no copies (ADR-0013 V5)**
  - Given: `player_movement_component.gd` and `player_visual_component.gd` as text
  - When: each is scanned for `GravityAuthority.apply_screen_relative_axis` and for an
    inline `sign(` or `signf(` axis branch
  - Then: `PlayerMovementComponent` calls the shared function and contains no inline branch
  - Edge cases: `PlayerVisualComponent` is **expected to still contain its inline branch**
    at this story's close — that caller is out of scope (see Scope Note). Assert its state
    explicitly so the eventual Presentation story has a failing check to flip, rather than
    leaving it unasserted

- **AC-6 — `camera_rotation_enabled` is gone (ADR-0013 D13.4)**
  - Given: the whole `src/` tree
  - When: it is grepped for `camera_rotation_enabled`
  - Then: zero matches
  - Edge cases: also assert `camera_rotation` appears in `player.gd` only as a local `var`
    inside `_physics_process` and never as an `@export` or file-scope `var` — a stored copy
    would be the same defect `private_gravity_copy` bans, in a new field

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player/screen_relative_axis_test.gd` — must exist and
pass. BLOCKING gate.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (reads `camera_rotation` at step 1 and threads it into step 6), and
  `gravity-authority` story 001 (`GravityAuthority` must exist in `src/` to host the static
  function) and story 002 (the ease loop AC-4 samples).
- Unlocks: the Presentation visual epic's `PlayerVisualComponent` caller, which closes
  `TR-gravity-013`. That epic does not yet exist.
