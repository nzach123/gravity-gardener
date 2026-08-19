# Epic: Collision Layer Registry

> **Layer**: Foundation
> **GDD**: design/gdd/physics-props.md
> **Architecture Module**: `CollisionLayerRegistry` (`collision_layers.gd`)
> **Status**: Ready
> **Stories**: 5 stories

## Overview

Physics props must never change whether a level can be finished. This epic makes
that hold by construction rather than by careful coding. One file,
`collision_layers.gd`, owns every layer and mask constant. Bit 4 (`prop`) is added
alongside the existing `world`, `player` and `item` bits. Props sit on layer 4 and
mask `world | prop` only. The player never masks 4, and props never mask 2 or 3.
The result is that "a prop never collides with the player" and "a prop never
triggers a plant, bucket or airlock detector" become structurally impossible to
violate, instead of rules that review has to police. No file outside
`collision_layers.gd` may assign `collision_layer` or `collision_mask`, or call
`set_collision_layer_value` / `set_collision_mask_value`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Collision layer allocation | Four named bits owned by one registry file; prop isolation enforced by mask allocation; direct layer/mask assignment banned elsewhere (D4.6) | LOW |

LOW, and this is a **verified downgrade rather than an assumption**. The project
rates HIGH overall on post-4.3 churn, and every item in that churn is 3D or
rendering. `modules/physics-2d.md` states that 2D physics is unchanged 4.4 → 4.7,
and that claim was independently re-checked at the 2026-08-14 specialist gate
(L1–L6). Jolt is irrelevant here — the `3d/physics_engine` setting is inert in a 2D
game.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-props-002 | Prop isolation enforced by layer and mask | ADR-0004 ✅ |

One TR, and it is the load-bearing one for the whole props system. This epic is
small in code and large in consequence.

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **F8 — this decision guarantees authored state only.** The registry fixes what scene files declare. It cannot stop code from mutating a layer or mask at runtime. | **OPEN — the most important open item** | `runtime_collision_mask_mutation` is a forbidden pattern in `docs/registry/architecture.yaml`. Enforcement is by review unless the D4.6 grep is automated — see the next row. |
| **The D4.6 ban needs a CI grep step to be structural rather than advisory.** ADR-0004 recommends it and deliberately leaves the call to this epic. | **Decision owed by this epic** | Recommendation: add the CI grep. Validation criterion 5 is already written as a greppable rule ("no file outside `collision_layers.gd` contains `set_collision_layer_value`, `set_collision_mask_value`, or an assignment to `collision_layer` / `collision_mask`"). A story must either add the step or record why not. |
| **Whether `KillArea2D` should also mask `prop` is not decided here.** | **Deferred to ADR-0011** (R7) | Do not resolve it in this epic. A story that needs the answer is Blocked on the Presentation props epic. |
| **`Simple_tileset.tres` inherits its physics layer rather than stating it.** | Recommended fix, folded into migration step 6 | State the physics layer explicitly so the tileset is covered by the same registry discipline as everything else. |
| **BUG-0001 — inert kill-area masks.** `hazards.md` R9 records this as a live defect: levels 05 and 06 do not restart when the player falls out of bounds. | Fixed by this epic | Validation criterion 4 of ADR-0004 requires levels 05 and 06 to restart on an out-of-bounds fall. Close BUG-0001 against that criterion. |
| **gdUnit4 treats GDScript warnings as errors at test discovery** — one warning fails the entire suite. | Known | `collision_layers.gd` must be warning-clean, including the unused-`class_name` and shadowing checks. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- `collision_layers_test.gd` passes, and fails on each deliberately introduced violation listed in ADR-0004 validation criterion 1
- Levels 05 and 06 restart on an out-of-bounds fall (BUG-0001 closed)
- The CI-grep decision is recorded either way
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Create the CollisionLayers registry and correct project.godot naming | Logic | Ready | ADR-0004 |
| 002 | Fix BUG-0001 — dead kill-plane masks on levels 05 and 06 | Integration | Ready | ADR-0004 |
| 003 | Remove vestigial PlayerArea2D and dead moving-platform mask | Logic | Ready | ADR-0004 |
| 004 | Collision layer invariant test suite | Logic | Ready | ADR-0004 |
| 005 | CI grep enforcing the D4.6 runtime-mutation ban | Logic | Ready | ADR-0004 |

## Next Step

Run `/story-readiness production/epics/collision-layer-registry/story-001-create-collision-layers-registry.md` to begin implementation.
