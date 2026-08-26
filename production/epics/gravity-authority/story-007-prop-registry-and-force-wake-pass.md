# Story 007: Prop registry and the force-wake pass

> **Epic**: Gravity Authority
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story)*

## Context

**GDD**: `design/gdd/physics-props.md` (R5, R7, AC3) · `design/gdd/gravity.md` (R9, AC12)
**Requirement**: `TR-props-004`, `TR-gravity-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**Governing ADRs**: ADR-0001 (primary, decision part 4b) · ADR-0011 (secondary — the
`PropBody` that calls `unregister_prop()` from `_exit_tree()`)
**ADR Decision Summary**: Space gravity does **not** wake a sleeping body. A sleeping
`RigidBody2D` wakes only via collision, `apply_impulse()` or `apply_force()`.
`GravityAuthority` therefore owns a prop registry and force-wakes every registered prop
on each frame the vector is changing — not only on the frame the zone fires, because a
prop can settle part-way through the ease. The wake call is `prop.sleeping = false`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: 2D physics unchanged 4.4 to 4.7 (`modules/physics-2d.md`, verified
2026-08-13). Engine-specialist review on 2026-08-14 (`architecture-review-2026-08-14.md`
section R1, A1-02) confirmed against 4.7 that a sleeping `RigidBody2D` requires an
explicit wake and that `prop.sleeping = false` is the call. `RigidBody2D.sleeping`,
`can_sleep` and `is_instance_valid()` are all pre-4.4 API.

**Performance**: One pass over at most 40 registered props per physics frame, and only
while the vector is easing (roughly 6-7 frames per gravity change at 60 FPS). Zero cost
in steady state. The budget is `props_per_level_budget` = 40 against a 16.6 ms frame.

**Control Manifest Rules (this layer)**:
- Required: "Registered props must be force-woken via `prop.sleeping = false` on every
  frame the vector changes, never via `apply_impulse()`/`apply_force()` (those add
  visible momentum)." — source: ADR-0001 (part 4b)
- Required: "`unregister_prop()` MUST be called from `PropBody._exit_tree()` — covers
  both out-of-bounds freeing and scene reload with one call site." — source: ADR-0001
- Required: "The gravity space write ... must happen in `_physics_process`, never
  `_process`, every frame while `gravity != target_gravity`." — source: ADR-0001
  (part 4a); the wake pass shares that branch
- Forbidden: "Never use `apply_central_force()` for gravity, or per-prop
  `gravity_scale` tuning." — source: ADR-0001 (`per_prop_gravity_application`)
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state; <= 40-prop wake
  pass only while the vector is easing." — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` R5, R7, AC3 and `design/gdd/gravity.md` AC12,
scoped to this story:*

- [ ] `register_prop(prop: RigidBody2D)` and `unregister_prop(prop: RigidBody2D)` are
      implemented on `GravityAuthority` (their signatures were declared in story 001).
- [ ] AC3 — every registered prop is woken on **every** physics frame the vector is
      changing, not only on the frame the zone fires.
- [ ] The wake call is `prop.sleeping = false`. Neither `apply_impulse()` nor
      `apply_force()` appears anywhere in the wake path.
- [ ] The wake pass is guarded with `is_instance_valid()` on every entry, regardless of
      `unregister_prop()` being correctly called.
- [ ] Registering the same prop twice does not produce two registry entries.
- [ ] `unregister_prop()` removes the prop and the wake loop no longer touches it.
- [ ] The wake pass does not run once the ease has settled — steady-state cost is zero.
- [ ] A prop with `can_sleep = false` is a harmless no-op for the wake loop, not an
      error.
- [ ] The registry holds at most `props_per_level_budget` (40) entries in a
      correctly-authored level, and the pass stays inside the 16.6 ms frame at that count.

---

## Implementation Notes

*Derived from ADR-0001 decision part 4b and the 2026-08-14 engine-specialist
clarification:*

- **This is the single most likely implementation bug in the game**, by ADR-0001's own
  assessment. Its signature presentation is "gravity works, but only sometimes" — props
  that happen to be moving when a zone fires behave correctly, and props that have
  settled do not. `physics-props.md` says to write the AC3 test *before* the feature.
  Do that here.
- `prop.sleeping = false` is the mandated call and the reason is behavioural, not
  stylistic: `apply_impulse()` and `apply_force()` both wake a body, but by adding
  momentum. That is a visible nudge on every prop at every gravity change, rather than a
  silent wake. Reviewers should treat either call in this path as a defect even though
  the prop does start moving.
- The pass runs **every frame the vector is changing**, sharing story 002's ease branch
  in `_physics_process`. Waking only on the zone-entry frame is the subtle wrong version:
  a prop can come to rest part-way through the ~100 ms rotation and then sleep through
  the remainder of it.
- Guard with `is_instance_valid(prop)` on every iteration **even though**
  `unregister_prop()` is mandatory contract. ADR-0001's Risks table asks for the guard
  regardless — `physics-props.md` R7 frees out-of-bounds props, and a registry holding
  one freed reference makes the whole wake loop throw, which takes gravity down for
  every prop rather than one.
- Sweep invalid entries out of the registry when the guard catches one, rather than
  skipping them forever. Otherwise a level that frees many props accumulates dead
  entries that are re-checked every eased frame for the rest of the session.
- `unregister_prop()` is called from `PropBody._exit_tree()` — one call site covering
  both R7 freeing and scene reload. `PropBody` itself is ADR-0011's, in the physics-props
  epic; this story provides the method it calls and must not wait on it.
- Registration happens at level init step 3d, alongside zone wiring, in
  `LevelRoot._ready()`. Make `register_prop()` idempotent so a double-registration from a
  re-run `_ready()` cannot double the pass.
- Do not add a per-prop `_physics_process`, a `gravity_scale` tweak, or
  `apply_central_force()`. All of those are the rejected Alternative 2 and are
  registered forbidden patterns.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the `PhysicsServer2D` default-space write. That delivers the gravity; this
  story only makes sure sleeping bodies notice it.
- Story 002: the ease branch this pass runs inside.
- Story 005: registration's call site in `LevelRoot._ready()` step 3d — this story
  provides the API, that story owns level init.
- **`PropBody` itself** — its `_exit_tree()` call, its collision layers, its speed cap,
  its lifetime and out-of-bounds freeing. ADR-0011 and ADR-0004, physics-props epic.
- `physics-props.md` AC10 (a room of props at budget holds 60 FPS during a flip) —
  ADR-0001 assigns that acceptance test to ADR-0011. This story only asserts the wake
  pass itself stays in budget.
- Prop restart behaviour and authored-transform reset (TR-props-003) — ADR-0011.

---

## QA Test Cases

*Story type: **Logic**. Headless. A `RigidBody2D` can be constructed and its `sleeping`
property driven directly with no rendered scene — write these before the feature, per
`physics-props.md`.*

Fixture: an initialized authority (`initialize(2990.72, 0.390625)`) settled at
`Vector2.DOWN`, and a small set of `RigidBody2D` instances.

- **AC-1 / AC-5 / AC-6 — registry mechanics**
  - Given: a fresh authority
  - When: `register_prop(a)`, `register_prop(a)` again, `register_prop(b)`, then
    `unregister_prop(a)`
  - Then: the registry holds exactly `b`; the wake loop touches `b` once per eased frame
    and `a` zero times
  - Edge cases: `unregister_prop()` on a prop that was never registered must be a no-op,
    not an error — `PropBody._exit_tree()` fires on every prop including ones that failed
    to register. Also `unregister_prop(null)`.

- **AC-2 — a sleeping prop is woken on every changing frame (`physics-props.md` AC3)**
  - Given: a registered prop with `sleeping = true` and gravity settled
  - When: `set_gravity(Vector2.RIGHT, 1.0)` and the ease is stepped frame by frame,
    forcing `sleeping = true` again after **each** frame
  - Then: the prop is observed woken on every single frame of the ease, not only the first
  - Edge cases: re-sleeping the prop after each frame is the whole point of this case.
    A test that sets `sleeping = true` once and checks it is false at the end passes on
    the wake-only-on-zone-entry defect, which is the exact bug ADR-0001 flags as most
    likely. Also assert the prop is **not** woken on frames after the ease settles.

- **AC-3 — the wake is a property write, not an impulse**
  - Given: a registered prop asleep at a known position with zero velocity
  - When: a gravity change wakes it and one physics frame elapses
  - Then: the wake itself imparted no velocity — the only velocity present is what space
    gravity produced in that frame
  - Edge cases: pair the behavioural check with a source grep asserting
    `apply_impulse` and `apply_force` appear nowhere in `gravity_authority.gd`. A small
    impulse is hard to separate from one frame of gravity numerically, so the grep is the
    reliable half and the behavioural case is the corroboration.

- **AC-4 — freed props do not break the pass**
  - Given: three registered props, one of which is `queue_free()`d and its frame allowed
    to elapse **without** `unregister_prop()` being called
  - When: a gravity change drives the wake pass
  - Then: the pass completes, the two surviving props are woken, and the freed entry is
    swept from the registry
  - Edge cases: assert the freed entry is *removed*, not merely skipped — a skip-forever
    implementation grows an unbounded dead list across a session of prop freeing.
    Construct this case with `queue_free()` plus a frame wait rather than `free()`, since
    `free()` inside a running pass is not the scenario `physics-props.md` R7 produces.

- **AC-7 — steady state costs nothing (guardrail)**
  - Given: 40 registered props and gravity settled
  - When: 100 physics frames elapse with no gravity change
  - Then: no prop's `sleeping` is written at all
  - Edge cases: assert *zero writes*, not "props stay asleep". An implementation that
    writes `sleeping = false` every frame keeps props awake, which looks fine on screen
    and silently costs 40 property writes per frame forever — a guardrail violation that
    only a write-count assertion catches.

- **AC-8 — `can_sleep = false` is a harmless no-op**
  - Given: a registered prop with `can_sleep = false`
  - When: a gravity change drives the wake pass
  - Then: no error is raised and the pass completes normally
  - Edge cases: ADR-0001 names this as a valid per-prop escape hatch, so it must not be
    treated as a misconfiguration to warn about.

- **AC-9 — the pass stays in budget at 40 props**
  - Given: 40 registered props
  - When: one full 90-degree ease runs
  - Then: the wake pass's per-frame time is a small fraction of the 16.6 ms frame budget
  - Edge cases: measure the pass in isolation, not the whole frame — this story owns only
    the wake loop. The full "room of props at budget holds 60 FPS during a flip"
    measurement is `physics-props.md` AC10 and belongs to ADR-0011.

**Estimated test count**: ~28 assertions.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Freed-object semantics, probed in GDScript 4.7.1**: `== null` is **TRUE**
  for a freed object, and `as` errors. The freed-prop case must use
  `is_instance_valid()`. Do not write the null check that looks equivalent — it
  passes for the wrong reason.
- **Assert the margin, not only the pass** *(retro action item 4)*. Run the wake
  pass **at** `props_per_level_budget` (40), not below it, and record the
  measured time against the 16.6 ms frame budget rather than only that it
  passed.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/gravity/prop_wake_registry_test.gd` — must exist and pass. Per
  `physics-props.md`, the AC3 case is written **before** the implementation.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the `register_prop` / `unregister_prop` signatures), Story 006
  (space gravity must be reaching props before waking them means anything)
- Unlocks: None within this epic. Completes the prop-side contract that ADR-0011's
  `PropBody` is written against
