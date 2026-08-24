# Story 004: `LevelBounds` frees out-of-bounds props

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (R7, AC9, §5)
**Requirement**: `TR-props-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, D11.3 and D11.6) · ADR-0004 (secondary — supplies
the detector idiom and mask `8`) · ADR-0001 (secondary — the registry that must be empty
afterwards)
**ADR Decision Summary**: `LevelRoot` gains one exported `Area2D` covering the playable
extent of the level. Its `body_exited` handler calls `queue_free()` on the exiting body,
with no type check — the mask is the filter, because only `PropBody` sits on layer 8.
The kill plane is **not** used: a kill plane is a plane authored for one gravity
direction, and gravity here rotates through four.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `Area2D`, `body_exited` and `queue_free()` are all pre-4.4 API,
unchanged through 4.7 per `docs/engine-reference/godot/modules/physics-2d.md`.
`CollisionShape2D.one_way_collision_direction` is new in 4.7 and is deliberately not
used anywhere in this system.

**Control Manifest Rules (this layer)**:
- Required: "Out-of-bounds props are freed via ONE exported `LevelBounds` `Area2D`
  (layer 0 / mask 8) per level, `body_exited` → `queue_free()` — never `free()`, and
  never via the kill plane (which catches only one of four gravity directions)." —
  source: ADR-0011 (D11.3)
- Required: "All detector `Area2D`s carry `collision_layer = 0`" — a detector needs no
  layer of its own. — source: ADR-0004 (D4.1)
- Required: "`unregister_prop()` MUST be called from `PropBody._exit_tree()`" — covers
  this freeing path and scene reload with one call site. — source: ADR-0011
- Forbidden: "Never enforce prop isolation with a type-check guard
  (`if body is PropBody: return`) instead of layer/mask configuration." — source:
  ADR-0004 (`prop_isolation_by_conditional_guard`)
- Forbidden: runtime mutation of `collision_layer` or `collision_mask`. — source:
  ADR-0004 (D4.6)

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` R7 and AC9, and ADR-0011 D11.3 / V5, scoped to
this story:*

- [ ] `LevelRoot` declares `@export var level_bounds: Area2D`.
- [ ] The handler is `_on_level_bounds_body_exited(body: Node2D) -> void` and its body is
      `body.queue_free()` — no type check, no branch, no filtering.
- [ ] The `LevelBounds` `Area2D` carries `collision_layer = 0` and `collision_mask = 8`
      (`CollisionLayers.PROP`), written through the constants.
- [ ] `queue_free()` is used, never `free()` — the handler runs from a physics callback,
      and freeing a body inside one is unsafe.
- [ ] A `PropBody` driven outside `level_bounds` is freed within one physics frame of
      `body_exited`, and `GravityAuthority`'s prop registry is empty afterwards (V5).
- [ ] Freeing works on **all four sides** — a prop leaving left, right, up or down is
      freed identically, at every gravity angle.
- [ ] The player, plants, buckets and the airlock are never freed by this handler,
      because the mask excludes them — verified by assertion, not by a guard.
- [ ] A test fixture level scene wires a `LevelBounds` and its `level_bounds` export.
- [ ] `level_root.gd` and the test file are warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 D11.3:*

```gdscript
@export var level_bounds: Area2D      # LevelRoot

func _on_level_bounds_body_exited(body: Node2D) -> void:
    body.queue_free()
```

**The absent type check is the design, not an omission.** Only `PropBody` sits on layer
8, so mask `8` is the filter. Adding `if body is PropBody` here is the registered
forbidden pattern `prop_isolation_by_conditional_guard` — and by the time a handler runs,
contact has already resolved in the physics step, so a guard would be both redundant and
misleading about where isolation comes from.

`queue_free()`, never `free()`. This is a physics callback.

Registry cleanup is automatic: `PropBody._exit_tree()` (story 001) calls
`unregister_prop()`. Do not add a second unregister call here — one call site covers both
this path and scene reload, and that is a registry contract condition
(`architecture.yaml:203`).

**Why not the kill plane**, so a reviewer does not re-propose it. ADR-0004 offered
`KillArea2D` mask `10` and assigned the choice to ADR-0011, which **declined it and
closed the deferral with a no**, on three grounds: a kill plane is authored for one
gravity direction while gravity rotates through four; only `level_05.tscn` and
`level_06.tscn` have a `KillArea2D` at all, so six levels would free nothing; and it
would tie prop lifetime to the player death handler at `main.gd:71`, which BUG-0001
makes unreachable.

**Also rejected**: per-prop `VisibleOnScreenNotifier2D` (ADR-0011 Alternative 4).
Off-screen is not out-of-bounds — props legitimately leave the camera view in every
level, and self-freeing on `screen_exited` would present as a room's furniture vanishing
whenever the player walked away and returned. R7 is about leaving the *level*, not
leaving the *view*.

**One hole, named rather than hidden.** A prop authored *outside* the bounds rect never
enters the area, so it never exits it, so it is never freed. That is closed at **load**
by `V-BOUNDS`, which belongs to `level-validation` story 006 — not at runtime, and not
here. Runtime is too late for what is an authoring error.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **`level-validation` story 006**: `V-BOUNDS` and `V-PROP-BUDGET`, including the
  per-prop extent check and the `V-BOUNDS` / `V-WIRING` double-report decision. ADR-0011
  V8 is that story's, not this one's.
- **Authoring `LevelBounds` into all 8 level scenes** and adding the `level_bounds` row
  to `V-WIRING`'s required-consumer table. ADR-0011 migration step 4; the epic's Risks
  table assigns it to `level-validation` and the level migration epic. This story
  delivers the export, the handler and **one test fixture**.
- **BUG-0001 / the `KillArea2D` mask fix.** D11.6 specifies the correct value
  (`collision_layer = 0`, `collision_mask = 2`) and **deliberately does not apply it** —
  applying it turns a dead kill plane into a live one in two shipped levels and needs a
  playtest first. The application belongs to `collision-layer-registry`. BUG-0001 stays
  Open with a named fix.
- **Story 005**: restart reset. Freeing and restart are different lifetimes.

---

## QA Test Cases

*Derived from ADR-0011 V5 and D11.3. The developer implements against these — do not
invent new test cases during implementation.*

- **AC-1** (V5): an out-of-bounds prop is freed, and the registry follows
  - Given: a test fixture level with a wired `level_bounds` and one registered `PropBody`
  - When: the prop is driven outside the bounds extent
  - Then: it is freed within one physics frame of `body_exited`, and
    `GravityAuthority`'s prop registry is empty afterwards
  - Edge cases: assert the registry, not only the node — a prop freed without
    unregistering leaves a dangling entry, and per the project's probed Godot 4.7.1
    semantics a freed `Object` compares `== null` as **true**, so a naive registry check
    can pass while holding a freed reference. Assert the registry's *count*

- **AC-2**: all four sides, at all four gravity angles
  - Given: the same fixture
  - When: a prop exits left, then right, then up, then down
  - Then: each is freed identically
  - Edge cases: repeat with gravity at 0°, 90°, 180° and 270°. This is the assertion that
    proves the kill-plane rejection was correct — a plane-shaped implementation passes one
    of these four and fails three

- **AC-3**: the mask is the filter, and it excludes everything else
  - Given: a fixture containing a player, a plant, a bucket and a `PropBody`
  - When: all four are driven outside the bounds extent
  - Then: only the `PropBody` is freed; the other three survive
  - Edge cases: assert `level_bounds.collision_mask == CollisionLayers.PROP` and
    `collision_layer == 0`; and grep-assert that the handler body contains no `is`
    keyword, since a passing behavioural test does not prove the guard is absent

- **AC-4**: props do not accumulate
  - Given: the fixture
  - When: ten props are driven out of bounds in sequence
  - Then: the registry is empty and no freed prop is re-processed
  - Edge cases: assert `body_exited` firing twice for the same body raises no error —
    `queue_free()` on an already-queued node must not produce a second free

- **AC-5**: `queue_free()`, not `free()`
  - Given: `level_root.gd`
  - When: the handler is scanned
  - Then: it calls `queue_free()` and contains no bare `free()` call
  - Edge cases: a synchronous `free()` inside a physics callback may pass a happy-path
    test and crash under contact load, so this is asserted statically rather than
    behaviourally

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/physics/level_bounds_free_test.gd` — must exist
and pass (BLOCKING per `.claude/docs/coding-standards.md`)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`PropBody` and its `_exit_tree()` unregister);
  `gravity-authority` story 007 (the registry this story asserts empty); `level-state`
  epic for `LevelRoot` itself
- **Unlocks**: `level-validation` story 006's `V-BOUNDS` half — the export must exist
  before validation can check it resolves
