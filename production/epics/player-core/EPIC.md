# Epic: Player Core

> **Layer**: Core
> **GDD**: design/gdd/gravity.md
> **Architecture Module**: `Player` facade · `PlayerGravityComponent` · `PlayerMovementComponent` · `PlayerJumpComponent` · `PlayerWallJumpComponent`
> **Status**: Ready
> **Stories**: 6 — created 2026-08-24

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
| **`GravityAuthority.apply_screen_relative_axis()` is mistaken for instance state.** | Low, cosmetic | GDScript static methods are callable through an instance and never touch `self`, so nothing breaks. Keep the `# static: no self access` comment at the definition site. |
| **The init-order hazard in `gravity.md` §5 stays live.** ADR-0007 D7 keeps jump constants as `@export`s on `Player` (architecture.md QQ-02, rated High). | Known, mitigated in Foundation | The guard in `GravityAuthority` is **mandatory**, and the GDD edge case must not be deleted. The guard is built in the `gravity-authority` epic; this epic depends on it. |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Rewrite `Player._physics_process` to the D7.3 eight-step order | Integration | Ready | ADR-0007 · ADR-0013 |
| 002 | `apply_gravity()` as a pure function — asymmetric ascent/descent by apex height | Logic | Ready | ADR-0007 |
| 003 | Variable jump height — release caps upward velocity at `min_jump_velocity` | Logic | Ready | ADR-0007 |
| 004 | Carry leaves jump apex unchanged at every zone multiplier | Logic | Ready | ADR-0007 |
| 005 | `apply_screen_relative_axis` and the `PlayerMovementComponent` caller | Logic | Ready | ADR-0013 · ADR-0007 |
| 006 | Wall-jump behaviour and tuning | Integration | **Blocked** | N/A — no ADR exists |

Build order is 001 first (every other story asserts against the callback it rewrites),
then 002, 003 and 005 in any order, then 004 (it reuses 002's and 003's fixtures).
Story 006 is Blocked and blocks nothing.

### Scope decisions taken at decomposition, 2026-08-24

**Story 005 absorbs an unowned ADR-0013 implementation step.** ADR-0013's step 1 puts
`static func apply_screen_relative_axis(...)` on `GravityAuthority`, a **Foundation**
module — but no `gravity-authority` story adds it. That epic's story 003 (`:131`) routes
ADR-0013 to "the Presentation visual-component epic", and **no such epic exists**:
`production/epics/index.md` lists `physics-props` as the only Presentation epic, with
HUD / Pause Menu still un-epic'd. The function's two callers are `PlayerMovementComponent`
(this epic) and `PlayerVisualComponent` (the absent epic). Rather than reopen a decomposed
epic, story 005 takes the function, because its Core caller cannot exist without it.
**`TR-gravity-013` is therefore half-owned on purpose** and does not close until the
Presentation caller lands. Recorded as an open risk in `index.md`.

**A related seam is flagged, not amended.** ADR-0013 scopes its supersession to "the
method contract of ADR-0007 D7.4 only", but D7.3's code block also passes
`camera_rotation_enabled` at its step 6 and step 8 call sites. Those must become
`camera_rotation` for D13.2 to receive a usable value, and no ADR text says so. Story 005
makes the change; neither ADR is edited.

**Two requirements this epic's table claims are substantively owned elsewhere.**
`gravity-authority` story 003's AC-5 already asserts `TR-gravity-005` (`jump_velocity`
bit-identical across ten gravity broadcasts) and cites `watering-system.md` AC1. That is
the *derivation* half. ADR-0007 Validation Criteria 1 and 3 also require the *outcome*
half — apex height in pixels — which that test does not measure. Stories 002 and 004 take
the outcome half only. The two are complementary, not duplicated.

**`TR-watering-002` has no story here, deliberately.** It is `adr: null` /
`adr_status: unowned` / `status: gap` in `tr-registry.yaml` — the registry's one
deliberately unowned requirement. The Risks table above forbids a story for it in this
epic. Story 004 asserts the *invariance* R10 demands and does not build the multiplier.

**The reference implementation is the vertical-slice prototype, not green-field.**
`prototypes/gravity-gardener-vertical-slice/scripts/player.gd` (from line 69) is already
the D7.3 shape and was reviewed. `src/scripts/player.gd:127-167` is the pre-ADR form. The
port target is `src/`. **The prototype is not a drop-in copy** — it has no
`PlayerWallJumpComponent` and omits D7.3 step 4 entirely, which `src/` must keep.

## Next Step

Stories are written. Run `/story-readiness production/epics/player-core/story-001-physics-step-order-and-live-basis-read.md`,
then `/dev-story` — but note that story 001 depends on `gravity-authority` stories 001-003
landing first, because `GravityAuthority` does not yet exist in `src/`.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/gravity.md` that these TRs cover are verified
- ADR-0007 Validation Criterion 8 passes (gravity change concurrent with a pour lock)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

