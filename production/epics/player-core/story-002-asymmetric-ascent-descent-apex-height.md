# Story 002: `apply_gravity()` as a pure function — asymmetric ascent/descent by apex height

> **Epic**: Player Core
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/gravity.md` (R4, §4 Formulas, AC1, AC2, AC3, AC10)
**Requirement**: `TR-gravity-004` (the behaviour half — the plumbing half is story 001)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Player component contract and physics step order
**Governing ADRs**: ADR-0007 (primary, D7.2 and Validation Criterion 1)
**ADR Decision Summary**: `PlayerGravityComponent` is near-stateless. `apply_gravity()` is
a pure function taking `delta`, `velocity`, `is_on_floor`, `gravity`, `ascent_mag` and
`descent_mag` as parameters and returning a new velocity. It derives no directions of its
own and stores no gravity. The ascent/descent split is chosen per frame from the sign of
`velocity · (-ĝ)`, so it holds at any gravity angle with no angle-aware code.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No new engine API. `Vector2.dot`, `Vector2.normalized` and float
arithmetic are unchanged since well before 4.4. **GH-115763 applies if and only if**
`apply_gravity()` overrides a base method with a typed return — it does not; it is declared
fresh on `PlayerGravityComponent`. Give it an explicit `-> Vector2` anyway, per the
project's static-typing standard.

**Control Manifest Rules (Core layer)**:
- Required: `PlayerGravityComponent` is near-stateless — it retains only `initialize()`,
  `jump_velocity` (read-only after init), and `apply_gravity()` as a pure function taking
  gravity/ascent/descent as parameters. It does **not** derive its own `up_dir`/`right_dir`
  — source ADR-0007 (D7.2).
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`).
- Forbidden: accumulating or evaluating a rule-bearing quantity in `_process` — source
  ADR-0005 (`gameplay_timing_in_idle_process`).

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md`, scoped to this story:*

- [ ] AC1 — at 1.0× gravity, peak height is 200 px ±2 px.
- [ ] AC2 — descent time to ground is shorter than ascent time by the configured ratio ±5%.
- [ ] AC3 — at 0.5× gravity, peak height is 400 px ±4 px; at 2.0×, 100 px ±2 px.
- [ ] AC10 — AC1, AC2 and AC3 all hold at gravity angles 0°, 90°, 180° and 270°.
- [ ] `apply_gravity()` takes `gravity`, `ascent_mag` and `descent_mag` as parameters and
      reads no field and no autoload for any of them.
- [ ] The ascent/descent selection is `velocity.dot(-gravity.normalized()) > 0`, with no
      per-axis or per-angle branching.
- [ ] Called with `is_on_floor == true`, `apply_gravity()` returns the velocity unmodified.

---

## Implementation Notes

*Derived from ADR-0007 D7.2 and gravity.md §4:*

- Target: `src/scripts/components/player_gravity_component.gd`. The reference shape is
  `prototypes/gravity-gardener-vertical-slice/scripts/components/player_gravity_component.gd`.
- The per-frame rule is `gravity.md` §4 verbatim:

  ```
  ascending = velocity · (-ĝ) > 0
  g_applied = g_ascent if ascending else g_descent
  velocity += ĝ · g_applied · Δt
  ```

  `ĝ` is `gravity.normalized()`. `g_ascent` and `g_descent` arrive as `ascent_mag` and
  `descent_mag` — this function does not compute them and does not know the multiplier.
- **The magnitudes are the authority's, not this component's.** `GravityAuthority`
  maintains `ascent_magnitude()` and `descent_magnitude()`; `Player._physics_process`
  (story 001) reads them and threads them in. If this story finds itself recomputing
  `g_ascent₀ · m`, the parameter threading in story 001 is wrong — fix that, not this.
- **Do not re-derive `jump_velocity` here.** It is assigned exactly once, in
  `initialize()`. `gravity-authority` story 003's AC-5 already asserts that it stays
  bit-identical across gravity broadcasts; this story asserts the *observable apex* those
  constants produce. The two are complementary and both are required by ADR-0007
  Validation Criteria 1 and 2.
- **Baseline numbers** from `gravity.md` §4 for `h`=200, `d_peak`=128, `d_land`=80,
  `s`=350: `t_up`=0.3657 s, `t_down`=0.2286 s, `g_ascent`=2990.72, `g_descent`=7656.25,
  `v_jump`=1093.75, `ratio`=0.390625 (1:2.56). Reach by multiplier: 0.5× → 400 px,
  1.0× → 200 px, 2.0× → 100 px.
- These numbers are the current tuning, **not** constants to hardcode into the component.
  A test may assert them as boundary values — that is the documented exception in
  `.claude/docs/coding-standards.md` where the exact number is the point.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the callback that calls this function and threads its parameters.
- Story 003: jump *initiation* and release. This story only integrates gravity into an
  existing velocity.
- Story 004: the carry case. Apex under carry is asserted there.
- Story 005: the input basis. Nothing here reads `right_dir`.
- `gravity-authority` story 002: the direction ease. This function receives whatever
  `gravity` it is given and does not care whether it is mid-ease.
- `gravity-authority` story 003: deleting `PlayerGravityComponent`'s fields and rewriting
  `initialize()`. **That story lands first**; this one changes `apply_gravity()`'s body and
  proves the resulting trajectory.

---

## QA Test Cases

*Story type: **Logic** — every criterion is a numeric assertion against a headless
component. No scene is required.*

Fixture: a `PlayerGravityComponent` initialized with `h`=200, `d_peak`=128, `d_land`=80,
`s`=350, driven at a fixed `delta` of `1.0 / 60.0`. Simulate a jump by seeding
`velocity = -ĝ * 1093.75` and integrating until `velocity.dot(-ĝ) <= 0`, summing
displacement.

- **AC-1 — apex is 200 px at 1.0× (GDD AC1, ADR-0007 VC1)**
  - Given: the fixture, `ascent_mag = 2990.72`, `descent_mag = 7656.25`, gravity down
  - When: the jump is integrated to apex
  - Then: total displacement along `-ĝ` is 200 px ±2 px
  - Edge cases: assert the apex frame count is ~22 (`t_up` 0.3657 s / 0.01667) — a wrong
    apex reached in a wrong number of frames indicates the ascent magnitude is wrong,
    while a right apex in a wrong frame count indicates the integration order is wrong

- **AC-2 — descent is faster than ascent by the ratio (GDD AC2)**
  - Given: the fixture, jumped to apex, then integrated back to the launch displacement
  - When: ascent frame count and descent frame count are compared
  - Then: `descent_frames / ascent_frames` equals `sqrt(0.390625)` = 0.625 within ±5%
  - Edge cases: assert `descent_mag > ascent_mag` — a fixture that passes the ratio with
    the two swapped would produce a floaty fall, which is the exact feel defect R4 exists
    to prevent

- **AC-3 — apex scales inversely with the multiplier (GDD AC3)**
  - Given: the fixture
  - When: the jump is integrated at `ascent_mag = 2990.72 * m` for `m` in `[0.5, 1.0, 2.0]`,
    with `descent_mag = ascent_mag / 0.390625` each time
  - Then: apex is 400 px ±4 px, 200 px ±2 px, 100 px ±2 px respectively
  - Edge cases: include `m = 0.1` and `m = 4.0`, asserting apex is monotonically decreasing
    in `m` across all five values. Do **not** re-seed `velocity` per multiplier from a
    recomputed `v_jump` — the whole point of R5 is that it is the same 1093.75 every time

- **AC-4 — all of AC1-AC3 hold at every gravity angle (GDD AC10)**
  - Given: the fixture
  - When: AC-1, AC-2 and AC-3 are re-run with gravity set to `Vector2.DOWN`, `Vector2.RIGHT`,
    `Vector2.UP` and `Vector2.LEFT`, each scaled to the same magnitude
  - Then: every assertion holds at every angle, with displacement measured along `-ĝ`
  - Edge cases: add one off-axis angle (45°) — an angle-aware branch that passes the four
    cardinals can still fail here, and R4 claims no such branch exists

- **AC-5 — purity: no field or autoload read**
  - Given: `src/scripts/components/player_gravity_component.gd` as text
  - When: the body of `func apply_gravity` is scanned
  - Then: it contains no `GravityAuthority`, no `self.`, and no reference to any name
    declared with `var` at file scope other than `jump_velocity`
  - Edge cases: `var gravity` and `var target_gravity` must not exist at file scope at all
    (ADR-0007 VC6) — this overlaps story 001 AC-3 deliberately, because the two stories can
    land in either order

- **AC-6 — grounded is a no-op**
  - Given: the fixture and an arbitrary non-zero `velocity`
  - When: `apply_gravity(delta, velocity, true, gravity, ascent_mag, descent_mag)` is called
  - Then: the returned vector is exactly equal to the input `velocity`
  - Edge cases: also assert this at every gravity angle, and with `velocity == Vector2.ZERO`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player/player_gravity_asymmetry_test.gd` — must exist and
pass. BLOCKING gate.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the callback threads the parameters this function now requires),
  and `gravity-authority` story 003 (`initialize()` rewritten, fields removed).
- Unlocks: Story 004 — the carry apex-invariance test reuses this story's jump fixture.
