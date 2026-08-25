# Epic: Level Outcomes

> **Layer**: Core
> **GDD**: design/gdd/level-flow.md
> **Architecture Module**: No dedicated module. Behaviour spans `LevelRoot` (Foundation), `OxygenDrain` (Core) and `Goal` (Feature) — see Scope note
> **Status**: Ready
> **Stories**: 7 — see the Stories table below (6 Ready, 1 Blocked)

## Overview

A level ends in exactly one of two ways, and this epic builds the layer that decides
which. Completion latches a write-once `level_complete` flag, plays a short hold,
and advances to the next level. Death plays a short sequence that never names its
cause — oxygen depletion, spike contact and kill-area entry are indistinguishable —
and restarts the level with every piece of state reset. The two outcomes are
mutually exclusive by construction rather than by careful ordering: once
`level_complete` latches, no death can be presented, which is what lets a
frame-perfect airlock entry at zero oxygen read as a win instead of a corpse in a
doorway. Both endings route through one guarded chokepoint. The sequence hold is
`SceneTree.paused`, written only through `PauseController`, with exactly three leaf
nodes exempted so the player can still see what the sequence exists to show, and a
set-once pause lock that makes "pause input is ignored for the duration" structural
instead of advisory.

## Scope note — why this epic has no module

`level-flow.md` was authored 2026-08-17, after `architecture.md` v1.0 and after the
52-requirement TR baseline was frozen. It therefore has **no architecture module of
its own**. `systems-index.md` places it in the Core tier; the code it governs lives
in `LevelRoot`, `OxygenDrain` and `Goal`.

> **The TR half of this gap is CLOSED as of 2026-08-24.** This section previously
> read "no architecture module of its own **and no TR IDs**", and the GDD
> Requirements table below still traces by rule anchor. The **ARCH-1 sweep**
> (2026-08-24) allocated **`TR-flow-001`–`010`**, one per rule R1–R10, taking the TR
> baseline from 52 to 74. Eight of the ten entered the registry already covered by
> ADR-0005, ADR-0014 and ADR-0002. The two that did not are `TR-flow-005` (R5 — the
> sequence's content, a HUD element that does not exist; Presentation epic) and
> `TR-flow-010` (R10 — the blocked design decision already on the Risks table).
> **The stories written against this epic trace to TR IDs.** The rule anchors are
> kept alongside them because the GDD prose is still the readable source.

The remaining half of the gap — that this epic has no architecture module — is real
and is not closed. It is why the requirements table below is anchored to GDD rules
rather than to a module's requirement list.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Frame ordering and the `level_complete` guard | `process_physics_priority` sets tick order; the guard decides the depletion-frame outcome; D5.4 removes any dependence on inter-area `body_entered` delivery order | LOW |
| ADR-0014: Pause gating and process modes during terminal sequences | The R4 hold **is** `SceneTree.paused`, written only through `PauseController`; three leaf exemptions to `PROCESS_MODE_ALWAYS`; a set-once pause lock | LOW |

Both LOW with no outstanding verification. ADR-0014's one added fact — the
`process_always` default of `SceneTree.create_timer()` — was verified 2026-08-18
against the live docs and against the open proposal that would change it.

## GDD Requirements

Traced by rule anchor, because no TR IDs exist for this system.

| Anchor | Requirement | ADR Coverage |
|--------|-------------|--------------|
| R1 | A level has exactly two outcomes — completion or death | ADR-0005 ✅ |
| R2 | `level_complete` is a write-once latch | ADR-0002 (field) + ADR-0005 (timing) ✅ |
| R3 | Completion outranks death on the same frame | ADR-0005 ✅ |
| R4 | Completion is announced to the player; a sequence plays with game systems paused | ADR-0014 ✅ (mechanism) |
| R5 | The completion sequence does not restate what the player already knows | ADR-0014 ✅ (mechanism) |
| R6 | Death is cause-agnostic — oxygen, spike and kill area are indistinguishable | ADR-0008 ✅ |
| R7 | Death is unreachable once `level_complete` latches | ADR-0005 ✅ |
| R8 | Restart is a total reset | ADR-0002 ✅ (restart discards the state objects) |
| R9 | Both endings route through one guarded chokepoint | ADR-0005 ✅ |
| R10 | Completion advances to the next level in the authored sequence | ❌ ⚠ **TBD — see Risks** |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **R10 is ⚠ TBD.** What follows the final level is not decided. ADR-0014 explicitly leaves it untouched. | **BLOCKED — design decision owed** | Stories for the multi-level arc and the end-of-game state are **Blocked**. Single-level completion and the advance-to-next-level path are not blocked and can proceed. Resolve R10 with the game-designer before the final level ships. |
| **`complete_hold_duration` is ⚠ unset.** `level-flow.md` §7 proposes 0.6 s and calls it a starting value that needs a playtest. ADR-0014 D14.6 refuses to fix the number, and says so plainly: inventing one would be the kind of unsourced value this project has been declining. | **OPEN — needs a human playtest** | Implement the mechanism with the value exported and the 0.6 s proposal as its default. **Do not record the value as chosen** until a real human playtest confirms it. Agent-driven playtests do not settle pacing questions. Range: 0.2–1.5 s. |
| **`t_transition` is ⚠ unset and no transition effect is specified.** Today it is an instant `change_scene_to_packed`. | **OPEN** | The instant change is the current shipped behaviour and is not a defect. Treat any transition effect as new scope, not as this epic finishing an unfinished thing. |
| **No `pause` action exists in `project.godot`.** ADR-0014 D14.6 leaves the binding — and whether it is remappable alongside the five gameplay actions — owed by `design/ux/pause-menu.md`. | **Blocked on UX** | The pause *mechanism* can be built and tested by calling `PauseController` directly. Binding an input action is Blocked. |
| **The node-level contract for menu screens is unowned.** D10.6 renders no menu and ADR-0014 renders none either. `interaction-patterns.md` **O9**, owner technical-director. | **Unowned** | This epic builds the pause and sequence mechanism, not the menu. The Presentation HUD / pause-menu epic inherits O9. |
| **`hud.md` E6/E9 "Unreachable" rows are wrong.** D14.5 corrects them. | Known, corrected in ADR-0014 | Apply D14.5's correction when the HUD epic lands. Do not implement against the stale `hud.md` rows. |
| **Inter-area `body_entered` delivery order is genuinely undetermined** in the engine — the 2026-08-14 review confirmed this is a real gap, not an unknown. | Closed by design, not by verification | D5.4 removes the dependency rather than assuming an order. Stories must not reintroduce an ordering assumption between the airlock area and a hazard or plant area. |
| **A bespoke suspension mechanism gets built instead of `SceneTree.paused`.** | Rejected alternative A | It would give `OxygenDrain` a second, non-structural way to stop — the exact property ADR-0008 was accepted for eliminating. `PauseController` stays the sole writer of `SceneTree.paused` (D14.2). |

## Stories

| # | Story | Type | Status | TR | ADR |
|---|-------|------|--------|----|-----|
| [001](story-001-continuous-completion-predicate.md) | The continuous completion predicate — `Goal` stops gating on the signal edge | Logic | Ready | `TR-flow-001` | ADR-0005 |
| [002](story-002-transition-pending-chokepoint.md) | `_transition_pending` — the guarded chokepoint both endings route through | Logic | Ready | `TR-flow-009`, `TR-flow-007` | ADR-0005 (D5.4) |
| [003](story-003-pause-controller-and-pause-lock.md) | `PauseController` — sole writer of `SceneTree.paused`, and the set-once pause lock | Logic | Ready | `TR-flow-004` *(mechanism)* | ADR-0014 (D14.2, D14.4) |
| [004](story-004-terminal-sequence-driver.md) | The terminal-sequence driver — pause, hold, then transition | Integration | Ready | `TR-flow-004` | ADR-0014 (D14.1, D14.3) |
| [005](story-005-cause-agnostic-death.md) | Cause-agnostic death — three causes, one indistinguishable sequence | Integration | Ready | `TR-flow-006` | ADR-0005 (D5.4) / ADR-0008 |
| [006](story-006-advance-to-next-authored-level.md) | Completion advances to the next authored level | Integration | Ready | `TR-flow-010` *(not-blocked half)* | ADR-0005 |
| [007](story-007-end-of-game-after-final-level.md) | What follows the final level — the end-of-game state | Logic | **Blocked** | `TR-flow-010` *(remainder)* | **N/A — unowned** |

**Order**: 001 → 002 → 003 → 004 → 005 → 006. Story 003 is self-contained and can
start at any time. Story 007 is Blocked on a design decision and is not schedulable.

### What this epic does **not** own

Named here because four adjacent pieces sit in sibling epics and `level-state`
story 005 wrote the handover out by name.

| Not here | Owner |
|---|---|
| The `level_complete` latch and the ordered goal handler (D5.3) | `level-state` story 005 |
| Restart-is-reconstruction — R8 / `TR-flow-008` | `level-state` story 006 |
| Arm-and-defer, the completion freeze, the depletion-frame outcomes | `oxygen-drain` stories 003–004 |
| `FramePriority` constants (D5.1) | `level-state` story 003 |
| `plant.gd` `_process` → `_physics_process` (D5.5) | Feature watering epic |
| The sequence's **content** — E6/E9, R5 / `TR-flow-005` | Presentation HUD epic |
| The `pause` input action binding | Blocked on `design/ux/pause-menu.md` (D14.6) |
| The menu-screen node contract | Unowned — `interaction-patterns.md` O9 |

### ⚠ Manifest gap the stories carry

`docs/architecture/control-manifest.md` is version **2026-08-17** and its header
covers ADR-0001 through ADR-0012. **ADR-0013 and ADR-0014 are not in it.** Every
D14.x rule in stories 003 and 004 is therefore quoted from the ADR directly and
marked as a manifest gap, because `/story-readiness`'s manifest-version comparison
cannot detect drift in a rule the manifest does not contain. Run
`/create-control-manifest update` before these stories are implemented, or accept
that the ADR is the only check on them.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria in `design/gdd/level-flow.md` are verified, except those depending on R10
- A frame-perfect airlock entry at zero oxygen completes the level; a pour on the same frame does not
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- `complete_hold_duration` is either confirmed by a human playtest or still flagged ⚠ unset — **not** silently promoted to chosen

## Next Step

Run `/create-stories level-outcomes` to break this epic into implementable stories.
