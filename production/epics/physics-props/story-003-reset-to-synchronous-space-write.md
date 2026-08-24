# Story 003: `reset_to()` writes the space parameters synchronously

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation *(the change lands in a Foundation file — see Implementation Notes)*
> **Type**: Integration
> **Estimate**: S (1-2 hours implementation, plus the V-E2 engine verification)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (R3), `design/gdd/gravity.md` (R2, AC12)
**Requirement**: `TR-props-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, D11.5) · ADR-0001 (secondary — owns `reset_to()`
and part 4a's ease-gated write, neither of which is reopened) · ADR-0003 (secondary —
owns the init-step ordering that puts `reset_to()` at step (e))
**ADR Decision Summary**: **This story repairs an inherited defect**, found by the
session-18 review (`architecture-review-2026-08-15-b.md:80-84`). ADR-0001 part 4a writes
the two space parameters every physics frame *while `gravity != target_gravity`*.
`reset_to()` sets both to the level default at once, so that condition is false
immediately and the write never fires. A `Viewport`'s `World2D` space RID survives
`reload_current_scene()`, so the space keeps whatever the previous level last wrote, and
props fall the previous level's way until the first zone-triggered change. `reset_to()`
therefore performs the same two writes directly, in addition to setting `gravity` and
`target_gravity`. Part 4a's ease gate is unchanged.

**Engine**: Godot 4.7.1 | **Risk**: LOW, **with one open verification item this story
discharges**
**Engine Notes**: `PhysicsServer2D.area_set_param` / `area_get_param` and the
`AREA_PARAM_GRAVITY` / `AREA_PARAM_GRAVITY_VECTOR` spellings are pre-4.4 API, unchanged
through 4.7. `World2D.space` is documented as deliberately dual-registered as both space
and area, which makes this the officially sanctioned pattern rather than a workaround.
Jolt is 3D only and inert here.

> **V-E2 is the only outstanding engine check in ADR-0011, and this story closes it.**
> The claim is that a synchronous `PhysicsServer2D.area_set_param` write made from
> `LevelRoot._ready()` lands **before** the new scene's first physics step. ADR-0011
> traced the call path rather than assuming it: `reset_to()` runs from
> `LevelRoot._ready()` at ADR-0003 init step (e); `_ready()` runs during scene-tree
> entry in idle time, because `reload_current_scene()` and `change_scene_to_packed()`
> are both deferred; that is outside `flush_queries()` and outside `_physics_process`,
> so the write raises no reentrancy hazard and the next physics step comes after it.
> **Confirm this by test against the 4.7.1 binary. Do not close it on the ADR text.**
> If it fails, the sanctioned fallback is a dirty flag consumed by the authority's own
> `_physics_process`, costing one frame of stale space gravity at load.

> **Read ADR-0012 D12.4 before writing any physics-server or monitor-flag call in this
> project.** It records the failure this reasoning avoids: a draft deferred a write by
> analogy with another call site, without checking that the two sites sat in the same
> physics window. They did not. Trace the path.

**Control Manifest Rules (this layer)**:
- Required: "`GravityAuthority.reset_to()` must write the two space parameters
  SYNCHRONOUSLY (in addition to the per-frame ease-gate write), not only while easing —
  otherwise a `reload_current_scene()` inherits the previous level's stale space
  gravity." — source: ADR-0011 (D11.5)
- Required: "The gravity space write (`PhysicsServer2D.area_set_param`) must happen in
  `_physics_process`, never `_process`, every frame while `gravity != target_gravity`."
  — source: ADR-0001 (part 4a) — **unchanged by this story**
- Forbidden: "Never set `gravity_space_override` (or `gravity`) on any `Area2D`." —
  source: ADR-0001 (`area2d_gravity_space_override`)
- Forbidden: "Never call `set_gravity()`/`reset_to()` before the initialize guard has
  been satisfied." — source: ADR-0001
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state." — source:
  ADR-0001. Two extra calls **per level load or restart** is not a per-frame cost and
  does not touch this guardrail.

---

## Acceptance Criteria

*From ADR-0011 D11.5 and V6, and `gravity.md` R2, scoped to this story:*

- [ ] `GravityAuthority.reset_to()` writes both `AREA_PARAM_GRAVITY_VECTOR` and
      `AREA_PARAM_GRAVITY` to the default 2D space synchronously, in the same call that
      sets `gravity` and `target_gravity`.
- [ ] After `reload_current_scene()`, `PhysicsServer2D.area_get_param(space,
      AREA_PARAM_GRAVITY_VECTOR)` equals the new level's `default_gravity_direction`
      **before any zone fires** (V6).
- [ ] The same holds on a first load into a level, not only on a restart — there is no
      separate first-load branch.
- [ ] ADR-0001's part 4a ease gate is **unchanged**. The per-frame write still fires only
      while `gravity != target_gravity`, and steady-state per-frame cost stays at zero.
- [ ] **ADR-0001's V6 is extended to assert the space parameter**, not only the `gravity`
      field. As written it would pass while this defect was live, which is why the defect
      survived to session 18.
- [ ] `reset_to()` keeps its name and its distinction from `set_gravity()`. No signature
      changes.
- [ ] **V-E2's empirical result is recorded in ADR-0011's Engine Compatibility section** —
      confirmed, or confirmed-with-fallback. Either outcome closes it; silence does not.
- [ ] `gravity_authority.gd` and the test file are warning-clean under the headless
      gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 D11.5:*

**This story edits a Foundation file (`gravity_authority.gd`) from a Presentation epic.**
That is deliberate and sanctioned: ADR-0011 assigns D11.5 to itself by name because the
defect is only *observable* through props, and ADR-0001 could not test for it — its V6
asserts the `gravity` field, never the space parameter. Coordinate with any in-flight
`gravity-authority` work on the same file before starting.

The write is the same pair part 4a already performs; the only change is that `reset_to()`
performs it directly rather than relying on the ease gate, which by construction is false
at that moment.

**Why not simply lift the ease gate.** ADR-0011 Alternative 5 proposed writing both
parameters unconditionally every physics frame. It was rejected because it pays a
permanent per-frame cost against a budget line that promises zero steady-state cost, in
order to fix a defect that occurs at exactly two moments — level load and restart. D11.5
fixes it at those two moments.

**The ordering constraint that makes this work.** `reset_to()` sits at ADR-0003 init step
(e), after `validate()` and state seeding, before zone and prop wiring at step (f).
D11.5 makes the space write reach props **through the space, not through the signal** —
so a prop that registers at step (f) still reads correct gravity even though it was not
subscribed when the first broadcast fired. That is why this story is unaffected by the
camera's first-broadcast gap flagged in ADR-0011.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **`gravity-authority` story 006**: part 4a's per-frame eased write. This story adds a
  write and removes none.
- **`gravity-authority` story 007**: the prop registry and the force-wake pass.
- **`gravity-authority` story 005**: the `LevelRoot` gravity exports and the `reset_to()`
  call site. This story changes what `reset_to()` *does*, not where it is called from.
- **The camera's first-broadcast gap** (session-18 finding 3,
  `architecture-review-2026-08-15-b.md:86-88`). ADR-0011 flags it as **unowned** and
  declines to fix it, because it is camera wiring inside an Accepted ADR's frozen init
  order. Do not resolve it here. Candidates named by the ADR are ADR-0010 or a camera ADR.

---

## QA Test Cases

*Derived from ADR-0011 V6 and V-E2. The developer implements against these — do not
invent new test cases during implementation.*

- **AC-1** (V6): a reloaded level's space gravity is the new level's, not the old one's
  - Given: a level running with gravity rotated away from its authored default by a zone
  - When: `reload_current_scene()` completes and `LevelRoot._ready()` has run
  - Then: `PhysicsServer2D.area_get_param(space, AREA_PARAM_GRAVITY_VECTOR)` equals the
    level's `default_gravity_direction`
  - Edge cases: assert **before any zone fires** — a test that lets a zone run first
    passes whether or not the defect is present; also assert `AREA_PARAM_GRAVITY`
    (the magnitude), not only the vector, since D11.5 writes both; and reload into a
    *different* level whose default differs from the previous one's, which is the case
    the surviving `World2D` space RID actually breaks

- **AC-2** (V-E2): the write lands before the first physics step
  - Given: a fresh level load
  - When: the first `_physics_process` frame of the new scene runs
  - Then: the space parameter already holds the new level's value on that frame — not
    one frame later
  - Edge cases: this is the engine-fact check, not an acceptance test. Record the result
    in ADR-0011's Engine Compatibility section either way. If it fails, implement the
    named fallback (a dirty flag consumed by the authority's `_physics_process`) and
    record the one-frame cost rather than leaving V-E2 open

- **AC-3**: the ease gate did not regress
  - Given: a settled gravity vector where `gravity == target_gravity`
  - When: several physics frames elapse
  - Then: no `area_set_param` call is made — steady-state per-frame cost stays at zero
  - Edge cases: spy on the call count across 10 idle frames and assert exactly zero;
    then trigger a zone and assert the count rises during the ease and returns to zero
    after it settles

- **AC-4**: ADR-0001's V6 now asserts the thing that was broken
  - Given: the existing `gravity-authority` test for V6
  - When: it runs against a build with the D11.5 write deliberately removed
  - Then: it **fails**
  - Edge cases: this is a test-of-the-test and is the point of the AC — the original V6
    passed while the defect was live, and an extended V6 that still passes without the
    write has not been extended

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gravity/reset_to_space_write_test.gd` — must
exist and pass (BLOCKING per `.claude/docs/coding-standards.md`)

Additionally: **V-E2's result recorded in ADR-0011's Engine Compatibility section.** This
is a documentation obligation, not a test artefact, and the story is not done without it.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: `gravity-authority` story 001 (`reset_to()` and the initialize guard),
  story 005 (the `LevelRoot` exports and the step-(e) call site), and story 006 (part 4a's
  ease-gated write, which this story must leave intact and therefore must be able to see)
- **Unlocks**: Story 004, Story 005, Story 006 — every prop behaviour downstream assumes
  the space holds the correct vector from the first physics step of a level

> **This story is independent of `PropBody`.** V6 asserts a space parameter and needs no
> prop instance, so it can run before Story 001 if the sequencing helps.
