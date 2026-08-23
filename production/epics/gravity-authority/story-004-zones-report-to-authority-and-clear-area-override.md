# Story 004: Zones report to the authority; clear the Area2D gravity override

> **Epic**: Gravity Authority
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story)*

## Context

**GDD**: `design/gdd/gravity.md`
**Requirement**: `TR-gravity-002`, `TR-gravity-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**ADR Decision Summary**: Zones declare a direction and a multiplier and report them to
`GravityAuthority.set_gravity()`; they never touch the player. Validation moves to the
authority so one implementation guards every caller. `gravity_zone.tscn`'s
`gravity_space_override = 3` and `gravity = -980.0` are cleared now, not deferred to
the props epic.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: 2D physics unchanged 4.4 to 4.7 (`modules/physics-2d.md`, verified
2026-08-13). `gravity_space_override = 3` is `SPACE_OVERRIDE_REPLACE`, which replaces
gravity outright including the defaults — the enum value and semantics are unchanged
through 4.7. `Area2D.body_entered` and `PackedScene` authoring are pre-4.4 API. The
`AREA_PARAM_GRAVITY` / `AREA_PARAM_GRAVITY_VECTOR` spelling question that once hung
over this area was **RESOLVED 2026-08-14** (`= 1` / `= 2`) and owes this story nothing.

**Performance**: Neutral. One signal hop per zone entry, unchanged in count.

**Control Manifest Rules (this layer)**:
- Required: "Gravity is owned exclusively by the `GravityAuthority` autoload ...
  Written ONLY by `set_gravity()` / `reset_to()`." — source: ADR-0001
- Forbidden: "Never set `gravity_space_override` (or `gravity`) on any `Area2D`,
  including `GravityZone` — gives props per-region gravity, breaking `gravity.md`
  R2/R9 and AC12." — source: ADR-0001 (`area2d_gravity_space_override`)
- Forbidden: "Never connect a `GravityZone` directly to the player, or call
  `Player.set_gravity()` — that method is removed; zones report to the authority
  only." — source: ADR-0001 (`zone_targets_player_directly`)

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` R2, R7, R9 and AC6/AC7, scoped to this story:*

- [ ] `main.gd` no longer connects any zone to `player.set_gravity`. Zones reach
      `GravityAuthority.set_gravity()` and nothing else.
- [ ] `main.gd` connects `_rotate_camera_to_gravity` to
      `GravityAuthority.gravity_changed`, not to each zone's own signal.
- [ ] `gravity_zone.tscn` no longer declares `gravity_space_override` (line 12) or
      `gravity` (line 13) on the `Area2D` root.
- [ ] No other `Area2D` in the project sets `gravity_space_override` or `gravity`.
- [ ] R7 / AC7 — a zone authored with a zero-length direction or a multiplier <= 0 is
      rejected at the authority and leaves gravity unchanged. The zone itself performs
      no validation of its own.
- [ ] R2 / AC6 — the player leaving a zone retains that zone's gravity indefinitely.
      There is no exit handler on `GravityZone`.
- [ ] R2 — entering a zone changes gravity globally, not for the entering body only.
- [ ] `GravityZone` keeps `zone_gravity_direction`, `zone_gravity_multiplier` and
      `get_zone_gravity_direction()`. `zone_priority` stays exported and unread.

---

## Implementation Notes

*Derived from ADR-0001 decision parts 2 and 5, and Migration Plan steps 4-5:*

- Two shapes are sanctioned for the zone-to-authority hop: the zone calls
  `GravityAuthority.set_gravity()` directly from `_on_body_entered`, or the zone keeps
  its `gravity_changed` signal and `LevelRoot` rewires it to the authority. **Prefer
  keeping the signal and rewiring**, because it leaves `GravityZone` free of a hard
  dependency on the autoload and keeps the zone unit-testable in isolation. Either
  satisfies the ADR.
- Validation is **removed** from `gravity_zone.gd` if any exists and is **not** added.
  `set_gravity()` on the authority is the single guard, which is the whole point of
  centralizing it — a zone-local check would silently diverge from the authority's.
- The `.tscn` override removal is the sharp edge of this story. Left in place, a prop
  inside a zone's bounds is pinned to that zone's never-updated `-980.0` while props
  outside behave correctly — props would look right *outside* zones and wrong *inside*
  them, which reads as a prop bug rather than a zone bug and is very hard to trace.
  ADR-0001 corrects an earlier inverted description of this symptom (2026-08-14 review
  A1-04); the description above is the corrected one.
- The change is **behaviourally neutral today** — `CharacterBody2D` ignores space
  gravity and no `RigidBody2D` exists yet. That is exactly why it is cheap now and
  expensive after the props epic ships.
- The camera rewire is a **wiring change only**. Connect `_rotate_camera_to_gravity` to
  the authority's signal and change nothing about what that function does. The
  camera-follow versus camera-rotation split (ADR-0013 D13.5) is **Blocked**: owner is
  technical-director, gated on a human playtest of `level_01` and `level_07`. Do not
  touch `camera_moving`, `camera_rotation_enabled`, or the tween duration.
- `zone_priority` stays exported and unread. GDD R8 parks it and ADR-0001's single
  global vector keeps it parked — with one vector in play, overlap is an ordering
  question, not a spatial one. Do not implement it, and do not delete the export.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the authority's validation implementation. This story only proves zones
  route through it.
- Story 002: the ease.
- Story 003: `PlayerGravityComponent` and `Player.set_gravity()` removal.
- Story 005: `default_gravity_direction` / `default_gravity_multiplier` and
  `reset_to()`.
- Stories 006, 007: everything prop-side.
- **TR-gravity-008 (`zone_priority` overlap resolution)** — parked by GDD R8, no story
  in this epic.
- **The camera-follow / camera-rotation split (TR-gravity-010, ADR-0013 D13.5)** —
  Blocked. This story does the signal rewire and nothing else.

---

## QA Test Cases

*Story type: **Integration** — zone, `LevelRoot` wiring and authority. Zone entry can
be driven headlessly by emitting `body_entered` with a `Player` stand-in; the scene
assertions are file reads.*

- **AC-1 / AC-2 — wiring targets the authority**
  - Given: the migrated `main.gd`
  - When: the test greps for `player.set_gravity` and for `gravity_changed.connect`
  - Then: `player.set_gravity` does not appear, and the camera handler is connected to
    `GravityAuthority.gravity_changed`
  - Edge cases: grep every `.gd` under `src/`, not `main.gd` alone. `zone_targets_player_directly`
    is a project-wide ban and a second wiring site elsewhere would satisfy a
    single-file grep.

- **AC-3 / AC-4 — no Area2D declares space gravity**
  - Given: the project's scene files
  - When: the test greps every `.tscn` under `src/` for `gravity_space_override` and for
    a root-level `gravity =` on an `Area2D` node
  - Then: neither appears in any file
  - Edge cases: the grep must cover *all* `.tscn` files, not just `gravity_zone.tscn`.
    Any `Area2D` with the override reintroduces per-region gravity, and the failure is
    invisible until a `RigidBody2D` exists — which is after this epic closes. Include
    inline sub-resources and inherited scenes. A test scoped to one file gives false
    confidence precisely where the defect is cheapest to miss.

- **AC-5 — a mis-authored zone is rejected at the authority (GDD R7, AC7)**
  - Given: an initialized authority settled at `Vector2.DOWN`, multiplier `1.0`
  - When: a zone authored with `zone_gravity_direction = Vector2.ZERO` fires
    `body_entered` with a `Player`; then a second zone with
    `zone_gravity_multiplier = -1.0` fires
  - Then: gravity is unchanged after each, and `gravity_changed` did not fire
  - Edge cases: assert the zone does **not** validate locally — a zone that returns
    early on its own leaves the authority's guard untested and the two
    implementations free to diverge. Drive one case through the zone and confirm the
    authority saw the call (spy on `set_gravity`) before rejecting it.

- **AC-6 — gravity persists after leaving a zone (GDD R2, AC6)**
  - Given: gravity set to `Vector2.UP` at `0.5` by a zone entry
  - When: the `Player` stand-in is moved out of the zone and 300 physics frames elapse
  - Then: gravity is still `Vector2.UP` at `0.5`
  - Edge cases: assert `GravityZone` declares no `body_exited` handler at all, by source
    grep. A behavioural persistence test passes on a zone that has an exit handler which
    happens to be a no-op today — and that handler is a live regression risk.

- **AC-7 — the change is global, not per-body (GDD R2, R9)**
  - Given: an initialized authority and two registered observers standing in for bodies
    at different positions in the level
  - When: one zone fires
  - Then: both observers read the same `GravityAuthority.gravity` on the same frame
  - Edge cases: place the observers far apart and outside the zone's bounds. The
    per-region defect this guards against presents as correct behaviour for a body
    *inside* the zone, so an observer inside the zone cannot detect it.

- **AC-8 — the zone's authored surface is preserved**
  - Given: a `GravityZone` instance
  - When: the test reads its exports
  - Then: `zone_gravity_direction`, `zone_gravity_multiplier` and `zone_priority` all
    exist, and `get_zone_gravity_direction()` returns the normalized direction
  - Edge cases: assert `zone_priority` is still exported *and* still unread — grep the
    source to confirm nothing consumes it. GDD R8 parks it deliberately; both silently
    implementing it and deleting the export are wrong.

### Manual verification

- [ ] Camera rewire produces no observable change.
  - Setup: run `level_01` and enter each gravity zone in turn.
  - Verify: the camera tweens to the new orientation exactly as it did before, at the
    same 0.6 s duration and the same easing.
  - Pass condition: indistinguishable from the pre-migration build. Any change means the
    rewire touched behaviour, which is out of scope and Blocked.
  - Record to `production/qa/evidence/gravity-zone-wiring-evidence.md`.

**Estimated test count**: ~26 assertions.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/gravity/gravity_zone_wiring_test.gd` — must exist and pass
- `production/qa/evidence/gravity-zone-wiring-evidence.md` — camera-rewire
  no-change check

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (validation must live on the authority), Story 003
  (`Player.set_gravity()` must be gone before its wiring is removed)
- Unlocks: Story 005
- Lands with: Stories 001, 002 and 003 form ADR-0001's atomic Changeset A
