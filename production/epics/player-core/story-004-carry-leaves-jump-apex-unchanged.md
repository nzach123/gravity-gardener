# Story 004: Carry leaves jump apex unchanged at every zone multiplier

> **Epic**: Player Core
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/gravity.md` (R10, AC11) · `design/gdd/watering-system.md` (R2, AC1)
**Requirement**: `TR-gravity-007`, `TR-watering-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Player component contract and physics step order
**Governing ADRs**: ADR-0007 (primary, Validation Criterion 3)
**ADR Decision Summary**: Carried mass penalises movement speed only. Gravity strength,
`jump_velocity`, coyote time and jump buffer are untouched, so R5 holds unconditionally.
ADR-0007 Validation Criterion 3 names this as one shared test: `gravity.md` AC11 and
`watering-system.md` AC1 are reciprocals, and it says plainly that it "should be written
once."

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No engine API is involved. This story adds a test and, at most, a
guard-rail comment; it introduces no new call.

**Control Manifest Rules (Core layer)**:
- Required: `PlayerGravityComponent` is near-stateless and `apply_gravity()` is a pure
  function of its parameters — source ADR-0007 (D7.2). A carry multiplier reaching it would
  be a parameter it does not have.
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`).

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` and `design/gdd/watering-system.md`, scoped to this story:*

- [ ] AC11 (gravity) / AC1 (watering) — carrying a bucket leaves jump apex height identical
      to the non-carrying case, at every zone multiplier.
- [ ] `jump_velocity`, `coyote_time` and `jump_buffer_time` read identically with a carry
      active and without one.
- [ ] No carry-derived value reaches `PlayerGravityComponent.apply_gravity()` or
      `PlayerJumpComponent.update()` — neither has a parameter for one, and neither reads
      the watering component.
- [ ] The test is written once and cited from both GDDs' criteria, not duplicated per GDD.

---

## Implementation Notes

*Derived from ADR-0007 Validation Criterion 3 and gravity.md R10:*

- **This story asserts an invariance. It does not build the carry-speed multiplier.**
  `TR-watering-002` ("carry scales `max_speed` only") is `adr: null` / `adr_status: unowned`
  / `status: gap` in `tr-registry.yaml` — the one deliberately unowned requirement in the
  registry. The epic Risks table says in as many words: **do not write a story for it in
  this epic.** It belongs to the Feature watering epic and still has no accepted ADR.
- Because the multiplier does not exist yet, the invariance holds trivially today. **That
  is the point.** This is a regression guard placed *before* the mechanism arrives, so that
  the story which eventually adds the multiplier fails loudly if it reaches past `max_speed`
  into gravity or jump. Write it as a standing guard, not as a proof of new behaviour.
- The carry state source is `PlayerWateringComponent` / `LevelState`. For this test, drive
  it through whatever `carrying_bucket`-equivalent flag exists on the fixture; if none
  exists yet, assert the negative form — that `player_gravity_component.gd` and
  `player_jump_component.gd` contain no reference to the watering component, to `Bucket`, or
  to any carry or mass identifier.
- The epic Risks table records the specific way this requirement gets misread:
  `TR-watering-002` sits next to ADR-0007 in the `architecture.md` table and gets **read as
  closed by proximity**. ADR-0007 states three separate times that it does not implement it,
  precisely because a skimmer would miss one. Do not treat this story as closing it.
- Reuse story 002's jump fixture and its apex-integration helper rather than writing a
  second one.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **The carry-speed multiplier itself (`TR-watering-002`)** — unowned, no accepted ADR,
  explicitly forbidden to this epic by the epic Risks table. Feature watering epic.
- Story 002: the apex measurement machinery and the multiplier sweep. This story reuses
  them.
- Story 003: coyote and buffer behaviour. This story only asserts a carry does not perturb
  them.
- `gravity-authority` story 003: its AC-5 already asserts `jump_velocity` is bit-identical
  across ten gravity broadcasts, including one issued while a carry multiplier is active.
  **That covers the derivation.** This story covers the observable apex in pixels, which
  that test does not measure. Both are required — ADR-0007 Validation Criteria 2 and 3 are
  separate criteria.

---

## QA Test Cases

*Story type: **Logic** — headless, numeric, no scene required.*

Fixture: story 002's jump fixture (`h`=200, `d_peak`=128, `d_land`=80, `s`=350;
`v_jump`=1093.75, `ratio`=0.390625), extended with a carry flag.

- **AC-1 — apex is identical with and without a carry, at every multiplier (gravity AC11 /
  watering AC1, ADR-0007 VC3)**
  - Given: the fixture
  - When: the jump is integrated to apex for `m` in `[0.1, 0.5, 1.0, 2.0, 4.0]`, once with
    the carry flag false and once with it true
  - Then: for each `m`, the two apex values are equal to within floating-point tolerance
    (not merely within the ±2 px AC1 band — these should be **bit-identical**, because
    nothing in the path differs)
  - Edge cases: repeat at gravity angles 0°, 90°, 180° and 270°. Also run one case where
    the carry is picked up *mid-ascent* — apex must match the no-carry apex for that same
    launch

- **AC-2 — the jump constants are unperturbed by a carry (GDD R10)**
  - Given: the fixture
  - When: the carry flag is toggled on, then off, then on again
  - Then: `jump_velocity`, `coyote_time` and `jump_buffer_time` are bit-identical at every
    reading
  - Edge cases: interleave a `GravityAuthority.set_gravity(Vector2.LEFT, 0.5)` broadcast
    between the toggles — the combination of a carry and a gravity change is the case R10's
    rationale is protecting, because it is where a second traversal lever would hide

- **AC-3 — no carry value can reach gravity or jump (structural)**
  - Given: `player_gravity_component.gd` and `player_jump_component.gd` as text
  - When: each is scanned for `watering`, `bucket`, `carry`, `carrying` and `mass`
  - Then: no match in either file, in any case
  - Edge cases: also assert `apply_gravity`'s parameter list is exactly
    `(delta, velocity, is_on_floor, gravity, ascent_mag, descent_mag)` — an added seventh
    parameter is how a carry factor would first appear, and it would be a silent R10 breach
    rather than a test failure anywhere else

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player/player_carry_apex_invariance_test.gd` — must exist
and pass. BLOCKING gate. Cite it from both `gravity.md` AC11 and `watering-system.md` AC1;
do not write a second copy under `tests/unit/watering/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (supplies the apex-integration fixture this story reuses), Story 003
  (supplies the coyote/buffer fixture for AC-2).
- Unlocks: None directly. It is the standing guard the Feature watering epic's
  carry-speed story must not break.
