# Story 001: `PropBody` — the scripted rigid body and its registry membership

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (R1, R2, R5, §7)
**Requirement**: `TR-props-006` (the per-prop mass and damping half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Consumed, not claimed**: `TR-props-002` (cosmetic isolation) is covered by ADR-0004,
and `TR-props-004` (force-wake) by ADR-0001. This story joins their mechanisms and
adds no guard of its own. ADR-0011 is explicit that it does not re-claim either.

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, D11.1) · ADR-0004 (secondary — supplies layer `8`
/ mask `9` and the `CollisionLayers` constants) · ADR-0001 (secondary — supplies
`register_prop()` / `unregister_prop()` and the registry contract)
**ADR Decision Summary**: `PropBody extends RigidBody2D` is the only prop type in the
project. It registers with `GravityAuthority` on `_ready()` and unregisters on
`_exit_tree()`. Three properties are fixed and may never be authored per instance;
`mass`, `friction`, `bounce`, `linear_damp` and `angular_damp` stay per-scene and are
authored freely, because variation between a light chair and a heavy table is the point.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `docs/engine-reference/godot/modules/physics-2d.md` states that
`RigidBody2D` carries no breaking change across 4.4 → 4.7 and instructs agents not to
mark 2D physics decisions unverified. Jolt is 3D only and inert here. ADR-0011 uses no
post-cutoff API. `CollisionShape2D.one_way_collision_direction` is new in 4.7 and is
deliberately **not** used. GH-115763 (typed-return inheritance) does not apply to this
story — no override here inherits a typed return.

**Control Manifest Rules (this layer)**:
- Required: "`PropBody extends RigidBody2D` is the only prop type, carrying
  `collision_layer = 8` / `collision_mask = 9` via the `CollisionLayers` constants —
  never literals." — source: ADR-0011 (D11.1)
- Required: "Fixed per `PropBody`, never authored per instance: `custom_integrator =
  false`, `gravity_scale = 1.0`, `collision_layer`/`collision_mask`." — source: ADR-0011
- Required: "`PropBody._ready()` calls `GravityAuthority.register_prop(self)`;
  `_exit_tree()` calls `unregister_prop(self)` — both mandatory." — source: ADR-0011
- Required: "`class_name` is required on `Plant`, `Bucket`, `PropBody`" — the type scan
  depends on it. — source: ADR-0003
- Forbidden: "Never use `apply_central_force()` for gravity, or per-prop `gravity_scale`
  tuning." — source: ADR-0001 (`per_prop_gravity_application`)
- Forbidden: "Never enforce prop isolation with a type-check guard
  (`if body is PropBody: return`) instead of layer/mask configuration." — source:
  ADR-0004 (`prop_isolation_by_conditional_guard`)
- Forbidden: runtime mutation of `collision_layer` or `collision_mask`. — source:
  ADR-0004 (D4.6, `runtime_collision_mask_mutation`)
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state." — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` R1, R2, §7 and ADR-0011 D11.1, scoped to this story:*

- [ ] `src/scripts/props/prop_body.gd` declares `class_name PropBody extends RigidBody2D`.
- [ ] `_ready()` calls `GravityAuthority.register_prop(self)`; `_exit_tree()` calls
      `GravityAuthority.unregister_prop(self)`. Both are present; neither is conditional.
- [ ] `collision_layer` is `CollisionLayers.PROP` and `collision_mask` is
      `CollisionLayers.PROP_MASK`, written through the constants. No integer literal
      `8` or `9` appears in the script or the scene.
- [ ] `custom_integrator` is `false` and `gravity_scale` is `1.0`, and neither is
      exported or settable per instance.
- [ ] `mass`, `friction`, `bounce`, `linear_damp` and `angular_damp` remain authorable
      per scene instance — the script neither overrides nor pins any of them.
- [ ] `src/scripts/props/prop_body.tscn` exists with a `PropBody` root and a
      `CollisionShape2D` child carrying a valid shape.
- [ ] The script contains no reference to the player, a plant, a bucket, the airlock or
      any hazard, and no `body_entered`/`body_exited` guard of its own.
- [ ] `prop_body.gd` and the test file are warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 D11.1:*

The whole class is four lines of behaviour:

```gdscript
class_name PropBody extends RigidBody2D

func _ready() -> void:
    GravityAuthority.register_prop(self)

func _exit_tree() -> void:
    GravityAuthority.unregister_prop(self)
```

`unregister_prop()` in `_exit_tree()` is **not optional**. It is a registry contract
condition (`architecture.yaml:203`), and one call site covers both R7 freeing (story 004)
and scene reload (story 005). Do not add a second teardown path.

The three fixed properties are set in `prop_body.tscn`, not assigned at runtime — a
runtime write to `collision_layer` or `collision_mask` is the registered forbidden
pattern `runtime_collision_mask_mutation`.

Verify **both mask directions** against ADR-0004 D4.3's table before authoring a second
prop scene. `CollisionLayers.PROP_MASK` is `WORLD | PROP` = 9: props see terrain and each
other, and nothing else. R1 and R2 hold by that allocation, not by any line of code here.

ADR-0011's own success test for this story: *a level author drops a `PropBody` into a
scene, authors its mass and damping, and gets correct gravity — having written no code
and read no ADR.*

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: the fall-speed cap and `_integrate_forces`. This story adds no
  `_integrate_forces` override at all.
- **Story 004**: `LevelBounds` and out-of-bounds freeing.
- **Story 005**: the restart-reset verification and the runtime-spawn CI grep.
- **`level-validation` story 006**: `V-PROP-BUDGET` and `V-BOUNDS`. This story is what
  unblocks that one; it does not implement it.
- **Prop content authoring.** No prop is placed into any level here — `art-bible.md`
  §1.3 defers prop content to Vertical-Slice tier. Tests use authored fixtures.

---

## QA Test Cases

*Derived from ADR-0011 D11.1 and the control manifest. The developer implements against
these — do not invent new test cases during implementation.*

- **AC-1**: `PropBody` registers on entry and unregisters on exit
  - Given: a `GravityAuthority` with an empty prop registry
  - When: a `PropBody` is added to the tree, then freed
  - Then: the registry holds exactly one entry after entry, and is empty after the free
  - Edge cases: add and free two props and assert the registry returns to empty, not to
    one; free a prop that was never added and assert no error is raised; assert the
    registry is empty after `queue_free()` has actually completed, not merely after the
    call is issued

- **AC-2**: layer and mask come from the constants and hold the ADR-0004 values
  - Given: an instantiated `prop_body.tscn`
  - When: `collision_layer` and `collision_mask` are read
  - Then: they equal `CollisionLayers.PROP` (8) and `CollisionLayers.PROP_MASK` (9)
  - Edge cases: assert the *bits*, not the decimal — `mask & CollisionLayers.PLAYER == 0`
    is the assertion that proves R1, and it must be written that way so a future bit
    reallocation cannot pass a decimal-only check

- **AC-3**: the fixed properties are fixed
  - Given: an instantiated `prop_body.tscn`
  - When: `custom_integrator` and `gravity_scale` are read
  - Then: `false` and `1.0` respectively
  - Edge cases: a grep assertion that `gravity_scale` is not `@export`ed anywhere in
    `src/scripts/props/`

- **AC-4**: per-prop authoring survives
  - Given: two `PropBody` instances with `mass` 1.0 and 5.0 and different `linear_damp`
  - When: both enter the tree
  - Then: each retains its authored value — the script overwrites neither
  - Edge cases: assert after `_ready()` has run, not before, since that is where an
    accidental pin would land

- **AC-5**: no isolation guard exists
  - Given: `src/scripts/props/prop_body.gd`
  - When: the file is scanned
  - Then: it contains no `is PropBody`, no `body_entered`, and no reference to `Player`,
    `Plant`, `Bucket` or `Goal`
  - Edge cases: this is the `prop_isolation_by_conditional_guard` ban — a grep-shaped
    assertion is the correct form, because the defect is the *presence* of code

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Scope guard**: only story 001 of `physics-props` is in Sprint 2.
  `art-bible.md` §1.3 defers the epic's content to Vertical-Slice tier. **Do not
  write test cases for stories 002-006.**
- **Sequencing**: `PropBody._ready()` calls `GravityAuthority.register_prop()`,
  so **GA-007 must land first**. A test written before GA-007 fails for a reason
  that is not this story's defect, which is the most expensive kind of red.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/physics/prop_body_test.gd` — must exist and pass
(BLOCKING per `.claude/docs/coding-standards.md`)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - `gravity-authority` story 001 (the `GravityAuthority` autoload must exist — it does
    not today; `project.godot` registers only `GameManager`)
  - `gravity-authority` story 007 (`register_prop()` / `unregister_prop()`)
  - `collision-layer-registry` — **already satisfied**, `CollisionLayers.PROP` and
    `PROP_MASK` are in `src/scripts/collision_layers.gd`
- **Unlocks**: Story 002, Story 004, Story 005, Story 006, and
  `level-validation` story 006 (which is *unschedulable* without `class_name PropBody`)

> **On pulling this story forward.** `production/epics/index.md` recommends pulling this
> one story ahead of the epic to clear `level-validation` story 006. That is sound, but
> it is not free: this story cannot run without the `GravityAuthority` autoload and its
> prop registry, so pulling it forward pulls `gravity-authority` stories 001 and 007 with it.
