# Epic: Level State Ownership

> **Layer**: Foundation
> **GDD**: design/gdd/watering-system.md · design/gdd/suit-oxygen.md
> **Architecture Module**: `LevelState` · `OxygenState` · `GameManager` · `LevelRoot` (construction and injection only)
> **Status**: Ready
> **Stories**: 6 — created 2026-08-24 (sprint task LS-0)

## Overview

Level-scoped state moves off the `GameManager` autoload and into two injectable
`RefCounted` objects. `LevelState` owns `buckets_consumed`, `buckets_total`,
`goal_unlocked`, `carrying_bucket` and `level_complete`. `OxygenState` owns
`remaining`, `capacity` and the threshold band. `LevelRoot` (`main.gd`) constructs
both and injects them into their consumers. `GameManager` keeps only what genuinely
crosses levels — `player_lives`. Because restart discards the objects rather than
resetting them, "oxygen never carries between levels" and "restart clears carry
state" become properties of object lifetime instead of rules that review must
police. This epic also lands the `level_complete` flag and its frame-ordering
guard, which is what lets "pour at zero oxygen is death" and "airlock at zero
oxygen is completion" coexist without contradiction.

**Scope boundary:** the `LevelRoot` restart path, level transition and camera work
are **not** in this epic. Those belong to the Core `level-flow` epic. This epic
takes only state construction, ownership and injection.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Level State Ownership and Injectable State Objects | `LevelState` / `OxygenState` are `RefCounted`, constructed and injected by `LevelRoot`; `GameManager` keeps cross-level concerns only | LOW |
| ADR-0005: Frame ordering and the `level_complete` guard | `process_physics_priority` sets tick order; the `level_complete` guard decides the depletion-frame outcome | LOW |

Both rate LOW. The four load-bearing Core claims of ADR-0002 and F1–F3 of ADR-0005
were verified against engine source on 2026-08-14, not recalled from training data.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-watering-006 | Goal gates on the level-wide consumed counter, not on a plant | ADR-0002 ✅ |
| TR-watering-011 | Restart clears carry state and all watering state | ADR-0002 ✅ |
| TR-oxygen-005 | Restart refills; oxygen never carries between levels | ADR-0002 ✅ |
| TR-oxygen-012 | capacity derived from O_level, authored on the level root | ADR-0002 ✅ |
| TR-watering-012 | Pour on the depletion frame yields death, not completion | ADR-0005 ✅ |
| TR-oxygen-010 | Airlock entry on the depletion frame completes the level | ADR-0005 ✅ |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **Getter-only property enforcement did not hold as written.** The original ADR-0002 text claimed a guarantee the language does not give. This was the one blocking finding of the 2026-08-14 specialist review. | **RESOLVED** — corrected in ADR-0002 (A2-01) | Implement the corrected text at `adr-0002-level-state-ownership.md:247-249` and `:291` verbatim. The point stands: `remaining` has no setter and no `reset()`, so `suit-oxygen.md` AC3 is a property of the type. Do not re-derive the mechanism from the pre-correction wording. |
| **This epic blocks three others.** ADR-0002 states outright that the watering, oxygen and HUD epics may not start until it lands. | Sequencing constraint | Schedule this epic before the Core watering and oxygen epics and before the Presentation HUD epic. `/create-stories` for those epics may run early; implementation may not. |
| **ADR-0002 amends ADR-0001.** `GameManager.reset_level_state()` ceases to exist; the `GravityAuthority.reset_to()` call moves to `LevelRoot._ready()`. Part 6 of ADR-0001 and the registry entry `state_ownership.level_default_gravity` still name the old caller. | Known documentation drift | Behaviour does not change — `restart_level()` already reloads the scene, which re-runs `LevelRoot._ready()`. Correct the caller name in ADR-0001 part 6 and in the registry entry as part of this epic. |
| **ADR-0005 depends on a field that ADR-0002 declares but does not govern.** ADR-0002 declares `level_complete` and deliberately does not define when it is read or written. | By design | ADR-0005 owns the read and write timing. Stories must cite ADR-0005 for guard behaviour, and ADR-0002 only for the existence and lifetime of the field. |
| **Inter-area `body_entered` delivery order is genuinely undetermined** in the engine. | Closed by design, not by verification | D5.4 removes the dependency on delivery order rather than assuming one. Stories must not reintroduce an ordering assumption between the airlock area and the plant area. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria in `design/gdd/watering-system.md` and `design/gdd/suit-oxygen.md` that these TRs cover are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The ADR-0001 caller-name correction is applied

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | `LevelState` — the injectable level-scoped state object | Logic | Ready | ADR-0002 |
| 002 | `OxygenState` — capacity validated at construction, drain-only | Logic | Ready | ADR-0002 |
| 003 | `FramePriority` — the const-only physics ordering contract | Logic | Ready | ADR-0005 |
| 004 | `LevelRoot` constructs both state objects and injects them | Integration | Ready | ADR-0002 |
| 005 | The `level_complete` write-once latch and the ordered goal handler | Logic | Ready | ADR-0005 |
| 006 | Restart is reconstruction — `GameManager` keeps only `player_lives` | Integration | Ready | ADR-0002 |

Implementation order is the numbering. Each story's `Depends on:` field states what
must be DONE first: 001 and 002 have no dependency, 003 has none, 004 needs both
types, 005 needs 001 and 004, and 006 needs 004.

### Two scoping decisions taken at decomposition, 2026-08-24

**Story 003 is not named in this epic's Architecture Module line.** It was added
deliberately. `FramePriority` blocks `gravity-authority`, `player-core` and
`oxygen-drain` and belongs to none of them, and ADR-0005 A5-05 forbids the
placement that would have made it a member of one — the constants cannot live on
`LevelRoot`, because `GravityAuthority` is an autoload present before any level
scene loads. This epic is the earliest of the four in the build order, so placing
it here blocks nobody. Story 003 carries the same note in its own Context.

**Two acceptance criteria cannot close inside this epic, and the stories say so.**
`watering-system.md` AC13 and `suit-oxygen.md` AC8 — the depletion-frame outcomes
that `TR-watering-012` and `TR-oxygen-010` name — need `OxygenDrain`'s arm-and-defer
behaviour (ADR-0005 D5.2), which is ADR-0008 and the Core `oxygen-drain` epic.
Story 005 lands the latch half only and states this in its acceptance criteria, so
`/story-done` cannot close it against criteria it does not satisfy.

### One seam left open on purpose

Story 004 implements initialisation-order steps (a), (c) and (d), and leaves step
(b) — `LevelValidation.validate()` — as a named, commented insertion point.
That is **LV-005**, which is blocked on this epic: `LevelState` and `OxygenState`
did not exist, and LV-005's real subject is the ORDERING between `validate()` and
their construction. Leaving the seam makes LV-005 an insertion rather than a merge
conflict.

## Next Step

Run `/story-readiness production/epics/level-state/story-001-level-state-object.md`,
then `/dev-story` on the same file.
