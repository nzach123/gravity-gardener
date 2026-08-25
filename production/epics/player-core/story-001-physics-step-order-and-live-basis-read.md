# Story 001: Rewrite `Player._physics_process` to the D7.3 eight-step order

> **Epic**: Player Core
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (3-4 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/gravity.md` (R1, R4, R9, AC10) · `design/gdd/watering-system.md` (AC9)
**Requirement**: `TR-gravity-004` (the plumbing half — the behaviour half is story 002)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Player component contract and physics step order
**Governing ADRs**: ADR-0007 (primary, D7.1 and D7.3) · ADR-0013 (secondary, D13.3 — the
`camera_rotation` live read joins step 1)
**ADR Decision Summary**: `Player._physics_process` reads `GravityAuthority.gravity`,
`.up_dir`, `.right_dir` fresh every frame into locals and threads them into each component
as parameters. No component stores a gravity-derived value past the callback. The eight
steps run in a fixed order, and step 8 (visuals) runs **unconditionally** — including
through a watering lockout.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0007 introduces no new engine API — it composes APIs ADR-0001 and
ADR-0005 already verified. `CharacterBody2D.up_direction`, `is_on_floor()`,
`is_on_wall()`, `get_wall_normal()` and `move_and_slide()` are all pre-4.4 and unchanged
through 4.7. **GH-115763 does not apply** — `_physics_process` returns `void`.
`Viewport.get_camera_2d()` returning `null` when no camera is current was verified against
the official 4.7 class documentation on 2026-08-18 (ADR-0013 Context).

**Control Manifest Rules (Core layer)**:
- Required: `Player._physics_process` reads gravity/up_dir/right_dir fresh every frame into
  locals and threads them as parameters — source ADR-0007 (D7.1).
- Required: `up_direction = GravityAuthority.up_dir` is the **FIRST** statement, before any
  `is_on_floor()` / `is_on_wall()` / `move_and_slide()` in the same callback — source
  ADR-0007 (`Player.up_direction_sync`).
- Required: the fixed call order — 1) up_direction sync, 2) watering lockout gate,
  3) gravity, 4) wall jump, 5) jump, 6) movement, 7) `move_and_slide()`, 8) visuals
  (UNCONDITIONAL) — source ADR-0007 (D7.3).
- Required: `process_physics_priority` is assigned in code from `FramePriority` (`0` for
  `Player` and its inline components), never per-scene — source ADR-0005 (D5.1).
- Forbidden: `Player._physics_process` must never return early from the watering-lockout
  branch before `visual_component.update()` runs — source ADR-0007
  (`watering_lockout_skips_visuals`).
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`).

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` and `design/gdd/watering-system.md`, scoped to this story:*

- [ ] `src/scripts/player.gd`'s `_physics_process` matches the D7.3 ordered block: the
      eight steps appear in the literal order shown, and no step is appended after 8.
- [ ] `up_direction = up_dir` (the local copy of `GravityAuthority.up_dir`) is the first
      statement, and precedes every `is_on_floor()`, `is_on_wall()` and `move_and_slide()`
      call in the callback.
- [ ] `gravity`, `up_dir`, `right_dir` and `camera_rotation` are read into locals once per
      callback and threaded as parameters. No component reads them for itself and no field
      retains them.
- [ ] The watering branch sets `velocity = Vector2.ZERO` **without** an early `return`;
      step 8 `visual_component.update()` runs on every physics frame of a pour
      (`watering-system.md` AC9).
- [ ] `Player.set_gravity()` is absent from `player.gd` and is not reintroduced
      (ADR-0001 `zone_targets_player_directly`).
- [ ] `Player`'s proxy properties `target_gravity`, `right_dir` and `up_dir` read from
      `GravityAuthority` (`target_gravity` → `GravityAuthority.gravity`), so
      `src/scripts/debugger.gd:13,17-18` keeps working.
- [ ] The player falls, jumps and reorients as before at gravity angles 0, 90, 180 and 270
      degrees (GDD AC10) — the regression bar for the rewrite.

---

## Implementation Notes

*Derived from ADR-0007 D7.1/D7.3 and its Migration Plan steps 5, 6 and 7, plus ADR-0013 D13.3:*

- The target is `src/scripts/player.gd` (currently lines 127-167). `src/` is the production
  tree; `prototypes/` is reference only.
- **A working reference implementation already exists.** The vertical-slice prototype at
  `prototypes/gravity-gardener-vertical-slice/scripts/player.gd` (from line 69) is the D7.3
  shape, already reviewed. Read it before writing, and port rather than re-derive. **It is
  not a drop-in copy**: the prototype has no `PlayerWallJumpComponent` and so omits D7.3
  step 4 entirely. `src/` has that component and must keep step 4.
- The current `src/` body has three defects the rewrite removes, all named by ADR-0007: the
  early `return` in the watering branch (breaks `watering-system.md` AC9), the
  `update_derived_dirs()` / `update_gravity_lerp()` calls (that state moved to the
  authority), and the doubled `up_direction = -gravity_component.gravity.normalized()`
  assignments (replaced, not deleted, by the step 1 live read).
- Step 1 gains the camera read per ADR-0013 D13.3:

  ```gdscript
  var cam: Camera2D = get_viewport().get_camera_2d()
  var camera_rotation: float = cam.rotation if cam != null else 0.0
  ```

  The `null` fallback of `0.0` is deliberate: D13.2 then degrades exactly to `gravity.md`
  §4, so a headless test with no camera exercises the GDD's own formula.
- Step 4's wall-jump call is **wiring only** — copy the existing call shape and its
  `enable_wall_jump` guard unchanged. Changing what wall jump *does* is story 006 and is
  Blocked.
- Keep the step 2 comment naming `watering-system.md` AC9. The epic Risks table records
  that this branch gets "simplified" back to an early `return` by readers who do not know
  why it is shaped this way, and that the collapse passes every manual test that does not
  hold a gravity flip during a pour.
- `PlayerGravityComponent` having no `gravity` field is **deliberate**. Code review must
  not read it as an oversight to fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `apply_gravity()`'s internals and the ascent/descent behaviour it produces.
  This story only threads the parameters in.
- Story 003: jump release, coyote and buffer behaviour inside `PlayerJumpComponent`.
- Story 004: the carry apex-invariance assertion.
- Story 005: `GravityAuthority.apply_screen_relative_axis`, the `PlayerMovementComponent`
  caller, and deleting the `camera_rotation_enabled` field. **This story threads
  `camera_rotation` into steps 6 and 8; story 005 changes what the callees do with it.** If
  story 005 has not landed, pass the value and leave the callee signatures alone.
- Story 006: wall-jump behaviour. Step 4's wiring is here; its behaviour is not.
- `gravity-authority` stories 001-003: `GravityAuthority` itself, the ease loop, and
  stripping `PlayerGravityComponent`'s fields. **This story cannot start until
  `GravityAuthority` exists in `src/`** — ADR-0007's Migration Plan states the ordering
  constraint explicitly.

---

## QA Test Cases

*Story type: **Integration** — this crosses `GravityAuthority`, `Player` and four
components. The ordering and freshness assertions are grep-level or headless; the AC10
regression bar needs a scene.*

- **AC-1 — the eight steps appear in D7.3's literal order (ADR-0007 VC5)**
  - Given: `src/scripts/player.gd` as text
  - When: the body of `func _physics_process` is scanned for the eight step markers
  - Then: `up_direction` assignment, the `is_watering` branch, `apply_gravity`,
    `wall_jump_component.try`, `jump_component.update`, `movement_component.apply`,
    `move_and_slide`, `visual_component.update` occur in that order, each exactly once
  - Edge cases: assert no call appears **after** `visual_component.update()` — the epic
    Risks table names "a fifth component appended instead of inserted" as the failure mode

- **AC-2 — `up_direction` is assigned before any floor or wall query (ADR-0007 VC7)**
  - Given: `src/scripts/player.gd` as text
  - When: the character offset of the `up_direction =` assignment is compared to the first
    occurrence of `is_on_floor(`, `is_on_wall(` and `move_and_slide(`
  - Then: the assignment offset is strictly less than all three
  - Edge cases: the assignment must read `GravityAuthority.up_dir` or the local `up_dir`
    copy of it — **not** `gravity_component.gravity.normalized()`, which is the pre-ADR
    form and would pass a naive ordering check

- **AC-3 — no component retains a gravity-derived field (ADR-0007 VC6)**
  - Given: `player_gravity_component.gd`, `player_movement_component.gd`,
    `player_jump_component.gd`, `player_wall_jump_component.gd`
  - When: each file is scanned for `var gravity`, `var target_gravity`, `var up_dir`,
    `var right_dir`
  - Then: no match in any file
  - Edge cases: an `@onready` or `@export` of the same name counts as a match; a *local*
    `var gravity` inside a function body does not

- **AC-4 — visuals run through a watering lockout (ADR-0007 VC8, watering AC9)**
  - Given: a headless `Player` with `watering_component.is_watering = true` and a spy on
    `visual_component.update()`
  - When: `_physics_process(1.0 / 60.0)` is driven 30 times while `GravityAuthority` eases
    from down-gravity toward right-gravity
  - Then: `visual_component.update()` was called 30 times, and the `gravity` argument it
    received differs between the first call and the last
  - Edge cases: assert `velocity == Vector2.ZERO` on every one of those frames, and that
    `move_and_slide()` was **not** called — the lockout must still freeze motion. Also
    assert `func _physics_process` contains no `return` statement inside the `is_watering`
    branch

- **AC-5 — `set_gravity` is gone and the proxies repoint**
  - Given: `src/scripts/player.gd` as text, and a headless `Player`
  - When: the file is scanned for `func set_gravity`, and the three proxy getters are read
  - Then: no `func set_gravity` exists; `player.up_dir == GravityAuthority.up_dir`,
    `player.right_dir == GravityAuthority.right_dir`, and
    `player.target_gravity == GravityAuthority.gravity`
  - Edge cases: after a `GravityAuthority.set_gravity(Vector2.RIGHT, 2.0)` broadcast and
    one eased frame, all three proxies must reflect the new values — a proxy still bound to
    `gravity_component.*` returns a stale or default vector with **no error**, which is
    exactly the silent break ADR-0007 Migration Plan step 7 calls out for `debugger.gd`

- **AC-6 — AC10 regression bar (scene-level)**
  - Given: a level scene with the player at rest on floor
  - When: gravity is set to each of down, right, up, left in turn, and at each angle the
    player is driven to walk, jump to apex, and land
  - Then: at every angle the player leaves the floor, reaches an apex, and returns to a
    floor contact, with `is_on_floor()` true at rest
  - Edge cases: run the sequence a second time *without* resetting the level, to catch
    state that survives a gravity change

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player/player_physics_step_order_test.gd` — must
exist and pass. AC-6 may instead be a documented playtest in `production/qa/evidence/` if
the scene-level harness is not yet available.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `gravity-authority` story 001 (`GravityAuthority` must exist in `src/` —
  ADR-0007 Migration Plan ordering constraint), story 002 (the ease loop), and story 003
  (`PlayerGravityComponent` stripped to `apply_gravity()`'s pure-function signature).
- Unlocks: Stories 002, 003, 004, 005 — all of them assert against this callback's shape.
