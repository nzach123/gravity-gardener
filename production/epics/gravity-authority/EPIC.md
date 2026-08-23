# Epic: Gravity Authority

> **Layer**: Foundation
> **GDD**: design/gdd/gravity.md
> **Architecture Module**: `GravityAuthority` (autoload)
> **Status**: Ready
> **Stories**: 7 stories — see the Stories table below

## Overview

Gravity is world state, not player state. This epic builds `GravityAuthority`, the
single autoload that holds the one global gravity vector and broadcasts it. Zones
act as setters: a zone reports a direction and a multiplier to the authority, the
authority eases the direction and snaps the strength, and it writes the result to
the `PhysicsServer2D` default space so every rigid prop adopts the same vector on
the same frame as the player. The authority also owns the prop registry and the
force-wake pass, because a sleeping `RigidBody2D` does not react to a space-gravity
change on its own. No other object may hold a gravity vector — ADR-0001 removes
`Player.set_gravity()` and stops `PlayerGravityComponent` owning `gravity` /
`target_gravity`.

**This epic takes only the Foundation share of gravity.md.** The GDD's 13
requirements split across three layers. TR-gravity-004 … TR-gravity-007 belong to
the Core player-component epic (ADR-0007). TR-gravity-013 belongs to the
Presentation visual-component epic (ADR-0013).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Gravity Ownership and Global Broadcast | One `GravityAuthority` autoload owns the vector, emits `gravity_changed`, writes default-space gravity, and force-wakes registered props | LOW |

`physics-2d.md` (verified 2026-08-13) certifies the 2D physics engine unchanged
4.4 → 4.7, so this domain is LOW despite the project's HIGH overall rating. Jolt is
out of scope — the `3d/physics_engine` setting is inert in a 2D game.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gravity-001 | Gravity is a Vector2 with derived up_dir/right_dir basis; one owner | ADR-0001 ✅ |
| TR-gravity-002 | Zones are setters; global broadcast; no per-body or per-region gravity | ADR-0001 ✅ |
| TR-gravity-003 | Direction eases, strength snaps | ADR-0001 ✅ |
| TR-gravity-008 | zone_priority overlap resolution | ❌ No ADR — **parked** |
| TR-gravity-009 | Multiplier semantics; reject zero direction and non-positive multiplier | ADR-0001 ✅ |
| TR-gravity-010 | Camera rotation follows gravity | ❌ No ADR — **implemented** |
| TR-gravity-011 | direction_ease_rate exported, not hardcoded 32.0 | ADR-0001 ✅ |
| TR-gravity-012 | Props adopt the vector on the same frame as the player | ADR-0001 ✅ |
| TR-props-001 | Props obey the global vector including during easing; symmetric | ADR-0001 ✅ |
| TR-props-004 | Sleeping props are force-woken on every change | ADR-0001 ✅ |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **ADR-0001 Verification Required item 2 is still open.** The same-frame guarantee holds only if the default-space write happens in `_physics_process` (ADR-0001 part 4a). Whether that write reaches every `RigidBody2D` in the same step is not yet confirmed against the 4.7.1 binary. | **OPEN** | TR-gravity-012 and gravity.md AC12 rest on this. The story that implements the default-space write must confirm the guarantee empirically before it closes. Do not close TR-gravity-012 on the strength of the ADR text alone. |
| **`direction_ease_rate` is not editable if `GravityAuthority` is registered as a bare script autoload.** TR-gravity-011 exists to remove the hardcoded 32.0; a non-inspectable export does not remove it. | Known, mitigated by design | Register as a **scene** autoload. A story acceptance criterion must assert the value is reachable from the inspector. |
| **TR-gravity-008 (zone_priority) has no ADR.** | **Parked, by design** | gravity.md R8 parks it and ADR-0001's single global vector keeps it parked — with one vector in play, overlap is an ordering question, not a spatial one. **No story.** Revisit only on a design change (architecture.md QQ-07). |
| **TR-gravity-010 (camera rotation) has no ADR.** Working in `main.gd` today. The input-basis leg is closed by ADR-0013 D13.2/D13.4. The camera-follow versus camera-rotation split is specified but **not applied** (ADR-0013 D13.5). | **Blocked** | Any story touching the camera split is marked Blocked. Owner is technical-director; the gate is a human playtest of `level_01` and `level_07`. `accessibility-requirements.md` T8 (reduced motion) stays blocked until that split lands. See hud.md Q10. |
| **`AREA_PARAM_GRAVITY` / `AREA_PARAM_GRAVITY_VECTOR` enum spellings.** | **RESOLVED** 2026-08-14 | Spellings confirmed (`= 1` / `= 2`). Failure mode was a compile error, not silent misbehaviour. No story work owed. |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Create the GravityAuthority scene autoload and its guards | Logic | Ready | ADR-0001 |
| 002 | Direction easing in `_physics_process` with an exported ease rate | Logic | Ready | ADR-0001 |
| 003 | Make PlayerGravityComponent a consumer; remove `Player.set_gravity` | Integration | Ready | ADR-0001, ADR-0007 |
| 004 | Zones report to the authority; clear the Area2D gravity override | Integration | Ready | ADR-0001 |
| 005 | Level default gravity exports and `reset_to` on level load | Integration | Ready | ADR-0001, ADR-0002, ADR-0003 |
| 006 | Default-space gravity write, rewritten every eased frame | Integration | Ready | ADR-0001, ADR-0006 |
| 007 | Prop registry and the force-wake pass | Logic | Ready | ADR-0001, ADR-0011 |

Stories 001-004 are ADR-0001's atomic Changeset A and land together — there is no
incremental path (ADR-0001 Migration Plan). Stories 006 and 007 have no observable
effect until the first `RigidBody2D` exists and may land with the props epic.

**No story exists for TR-gravity-008** (`zone_priority`) — parked by `gravity.md` R8.
**No story exists for the TR-gravity-010 camera-follow / camera-rotation split** —
Blocked on a human playtest of `level_01` and `level_07`, owner technical-director
(ADR-0013 D13.5). Story 004 rewires the camera signal only.

### Cross-epic prerequisites

| Story | Needs | From |
|---|---|---|
| 005 | `LevelRoot` | level-state epic (ADR-0002) |
| 006 | `Tuning.PROP` / `prop_gravity_scale` | tuning-resources epic (ADR-0006) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/gravity.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- ADR-0001 Verification Required item 2 is discharged with a recorded result

## Next Step

Run `/create-stories gravity-authority` to break this epic into implementable stories.
