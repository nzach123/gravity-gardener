# Epic: Oxygen Drain

> **Layer**: Core
> **GDD**: design/gdd/suit-oxygen.md
> **Architecture Module**: `OxygenDrain` · `OxygenAccessibility` (autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories oxygen-drain`

## Overview

Oxygen is the clock the whole level runs on. `OxygenDrain` is a Core node that
drives `OxygenState` one step per physics frame, unconditionally, in every player
state — walking, jumping, watering, standing still. Nothing in the game refills it,
so the countdown is monotonic and the level has a hard time budget. When the tank
empties, `OxygenState` emits `depleted`, and `OxygenDrain` — not `LevelRoot` — owns
what happens next, because the kill decision has to respect the `level_complete`
suppression. The drain node also emits threshold changes at the 50 / 25 / 10 percent
bands for the HUD to react to. Pause halts the drain structurally rather than by a
flag: `OxygenDrain` inherits its process mode from `LevelRoot`, so a paused tree
stops the clock with no code path to forget. An `OxygenAccessibility` autoload holds
exactly one field, a drain-rate multiplier, composed onto the tuning value rather
than written into it.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: Oxygen Drain, Shared Death Path, and the Accessibility Drain-Rate Override | `OxygenDrain` runs at priority `+100`, owns the kill decision, halts on pause via process mode, and composes the accessibility multiplier onto `Tuning.OXYGEN.drain_rate` | LOW |

**Constrained by, but not governed by:**

| ADR | What it constrains here |
|-----|------------------------|
| ADR-0005: Frame ordering and the `level_complete` guard | Sets the `+100` slot and the depletion-frame outcome. `OxygenDrain` formalizes it; it decides nothing new. |
| ADR-0002: Level State Ownership | Owns `OxygenState` itself. `depleted` is a pure state signal carrying no policy. |
| ADR-0014: Pause gating during terminal sequences | The sequence hold **is** `SceneTree.paused`, so the drain stops during it by the same mechanism. |

ADR-0008 is LOW with no new verification. The `PROCESS_MODE_INHERIT` /
`PROCESS_MODE_PAUSABLE` / `SceneTree.paused` mechanism is now cited in
`modules/core.md`, closed by the 2026-08-15 architecture review.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-oxygen-001 | Countdown from oxygen_capacity | ADR-0008 ✅ |
| TR-oxygen-002 | Drain is unconditional in every player state | ADR-0008 ✅ |
| TR-oxygen-003 | Depletion is death via the shared restart path, indistinguishable from other deaths | ADR-0008 ✅ |
| TR-oxygen-004 | Nothing refills the suit | ADR-0008 ✅ |
| TR-oxygen-006 | Pause halts drain | ADR-0008 ✅ |

`TR-oxygen-005`, `-010` and `-012` are owned by the Foundation `level-state` epic.
`TR-oxygen-007`, `-009` (HUD readout and threshold feedback) are owned by the
Presentation HUD epic under ADR-0010. `TR-oxygen-008` (load-time capacity check) is
owned by the Foundation `level-validation` epic.

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **Wiring `depleted` straight to `LevelRoot.restart_level()` breaks `suit-oxygen.md` AC8.** `depleted` means "the tank is empty" and carries no policy. `OxygenDrain` owns the kill decision, including the `level_complete` suppression that lets a frame-perfect airlock entry at zero oxygen count as a win. | **Live trap** — the obvious wiring is the wrong one | ADR-0002 corrected `architecture.md` on exactly this point. A story must assert the AC8 case: airlock entry on the depletion frame completes the level. |
| **The `LevelRoot`-ancestor `process_mode` invariant is enforced by nothing but the ADR text.** A future node inserted between `OxygenDrain` and the tree root with a non-`INHERIT` process mode silently breaks TR-oxygen-006. No compile error, no symptom until a playtester notices oxygen draining during pause. | **OPEN — no automated check exists** | ADR-0008 recommends a scene test once a pause menu exists to pause against. That menu arrives with ADR-0010 / ADR-0014 in the Presentation layer. **Write the test then, and record the dependency now** so it is not forgotten. |
| **A future author writes to `Tuning.OXYGEN.drain_rate` directly** instead of composing through `OxygenAccessibility`, reintroducing the D6.5 violation that D6.6 exists to prevent. | Known, forbidden pattern | `tuning_resource_runtime_mutation` in the registry already names ADR-0008 as the correct location. Point at it in code review; no new registry entry is needed. |
| **`OxygenAccessibility` grows into an implicit general settings singleton** nothing decided to build. | Known | Its scope is **exactly one field**. Extending it needs its own ADR — the same discipline `Tuning` follows. Note that the settings system is still unowned: no GDD or ADR covers how any of it is built. |
| **`clampf()` in `set_drain_rate_multiplier()` silently absorbs an out-of-range value** rather than reporting it. | Accepted for now | Acceptable because nothing calls the setter yet. The future settings-screen ADR must decide whether silent clamping stays correct once a UI can produce out-of-range input. |
| **`scaled_delta` reads like a raw frame delta at the call site.** A later edit to `OxygenState.drain()` that reuses `delta` for a play-time counter or a VFX timer would silently inherit the accessibility scaling. | Known, no automated check | The call-site comment required by ADR-0008 Decision §3 is mandatory, not optional. |
| **This epic cannot start until the Foundation `level-state` epic lands.** ADR-0002 blocks the oxygen epic by name. | Sequencing constraint | Build `level-state` first. `OxygenState` must exist before anything can drive it. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/suit-oxygen.md` that these TRs cover are verified, including AC8
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The pause-invariant scene test is either written, or recorded as owed to the Presentation HUD epic

## Next Step

Run `/create-stories oxygen-drain` to break this epic into implementable stories.
