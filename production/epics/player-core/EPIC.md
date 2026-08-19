# Epic: Player Core

> **Layer**: Core
> **GDD**: design/gdd/gravity.md
> **Architecture Module**: `Player` facade · `PlayerGravityComponent` · `PlayerMovementComponent` · `PlayerJumpComponent` · `PlayerWallJumpComponent`
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories player-core`

## Overview

The player is a facade over four components, and the facade owns one thing the
components do not: the order they run in. Each physics step, `Player` reads the
current gravity from `GravityAuthority`, then calls its components in a fixed
sequence — gravity basis, movement, jump, wall jump — passing `gravity`,
`ascent_mag` and `descent_mag` as parameters rather than letting any component
cache them. No component keeps a private gravity field. `PlayerGravityComponent`
applies the asymmetric ascent and descent magnitudes and derives `jump_velocity`
exactly once, so jump apex stays fixed no matter what a zone does to gravity
strength. `PlayerMovementComponent` owns `max_speed`, acceleration and friction.
`PlayerJumpComponent` owns coyote time, input buffering and variable jump height.
Input is mapped through one screen-relative function that reads the live camera
rotation, so the controls cannot invert when the room turns.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Player component contract and physics step order | `Player` calls four components in a fixed order and passes gravity as parameters; no component holds a gravity field; `jump_velocity` is derived once | LOW |
| ADR-0013: Screen-relative input basis | One `apply_screen_relative_axis` function, two callers; the mapping reads the live camera rotation, so no flag can invert the controls | LOW |

Both are LOW with **no outstanding verification**. ADR-0007 introduces no new engine
API — it composes APIs that ADR-0001 and ADR-0005 already verified. ADR-0013's one
uncertain item, `Viewport.get_camera_2d()` returning `null` when no camera is
current, was verified against the official class documentation on 2026-08-18.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gravity-004 | Asymmetric ascent/descent applied to the player | ADR-0007 ✅ |
| TR-gravity-005 | jump_velocity derived once, never recomputed | ADR-0007 ✅ |
| TR-gravity-006 | Variable jump height; release caps at min_jump_velocity | ADR-0007 ✅ |
| TR-gravity-007 | Carried mass affects speed only, never gravity or jump | ADR-0007 ✅ |
| TR-watering-014 | Carry leaves jump apex unchanged at every zone multiplier | ADR-0007 ✅ |
| TR-watering-002 | Carry scales max_speed only | ❌ No ADR — **gap, see Risks** |

`TR-gravity-013` (visual mirrors movement axis inversion at any angle) is also
governed by ADR-0013, but its module is `PlayerVisualComponent`. It belongs to the
Presentation layer, not this epic. The same function serves both callers.

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **`TR-watering-002` will be read as closed because it sits next to this ADR.** The `architecture.md` ADR table assigns it here, but the ADR-0007 Decision does **not** implement it. The carry-speed multiplier needs a `carrying_bucket` source owned by `PlayerWateringComponent` / `LevelState`. | **GAP — the one true gap in the 52-TR registry** | It is stated in three places in ADR-0007 precisely because a skimmer would miss one. The registry entry was reassigned to ADR-0009 on 2026-08-15. **Do not write a story for it in this epic.** It belongs to the Feature watering epic and still has no accepted ADR covering the mechanism. |
| **`PlayerWallJumpComponent` has no GDD, no TR IDs, and no ADR.** `architecture.md` QQ-05 rates this Medium: load-bearing traversal mechanics with no design authority. | **Unowned** | Stories may wire the component into the D7.3 call order, because that is ADR-0007's scope. Stories that change wall-jump *behaviour* are **Blocked** — they would have no design source to verify against. Resolve with `/reverse-document`, or accept the mechanic as undocumented and record that choice. |
| **A future component reintroduces a private gravity field "for convenience."** It presents as a rare, hard-to-reproduce bug rather than an architectural violation, because the cached copy only misses a gravity change that lands mid-frame. | Known, forbidden pattern | `private_gravity_copy` in `docs/registry/architecture.yaml` already names "any node". Code review must treat `PlayerGravityComponent` having no `gravity` field as **deliberate, not an oversight to fix**. |
| **The watering branch gets "simplified" back to an early `return`.** This collapses D7.3 step 8 into the gate and silently breaks `watering-system.md` AC9. It passes every manual test that does not hold a gravity flip during a pour — which is most of them. | Known | Validation Criterion 8 of ADR-0007 exercises exactly that combination. Keep the D7.3 step 2 comment naming AC9. |
| **A fifth component is appended to `_physics_process` instead of inserted.** | Known | The ordered block in D7.3 is the single source of truth for call order. Read a future addition as "insert into this list," never "append at the end." |
| **`GravityAuthority.apply_camera_relative_axis()` is mistaken for instance state.** | Low, cosmetic | GDScript static methods are callable through an instance and never touch `self`, so nothing breaks. Keep the `# static: no self access` comment at the definition site. |
| **The init-order hazard in `gravity.md` §5 stays live.** ADR-0007 D7 keeps jump constants as `@export`s on `Player` (architecture.md QQ-02, rated High). | Known, mitigated in Foundation | The guard in `GravityAuthority` is **mandatory**, and the GDD edge case must not be deleted. The guard is built in the `gravity-authority` epic; this epic depends on it. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/gravity.md` that these TRs cover are verified
- ADR-0007 Validation Criterion 8 passes (gravity change concurrent with a pour lock)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories player-core` to break this epic into implementable stories.
