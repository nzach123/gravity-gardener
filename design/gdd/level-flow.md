---
status: authored — all 8 sections complete, pending /design-review
source: docs/architecture/adr-0005-frame-ordering-and-level-complete-guard.md, design/ux/hud.md, design/gdd/suit-oxygen.md, design/gdd/watering-system.md, src/scripts/main.gd, src/scripts/goal.gd
date: 2026-08-17
reason: closes the "new requirement with no GDD home" in systems-index.md (level_complete), hud.md Q6 (death sequence has no GDD home), and hud.md line 186
---

# Level Flow — Design

> **Scope.** This document owns how a level *ends* — completion, death, restart,
> and the move to the next level. It does not own what makes a level completable
> (`watering-system.md` R6), what kills the player (`suit-oxygen.md`,
> `spike_hazard.gd`), or the frame ordering that sequences the two
> (ADR-0005). It states *what* happens; ADR-0005 states *how* it is sequenced.

## 1. Overview

A level ends in exactly one of two ways: the player enters the unlocked airlock,
or the player dies. Completion latches a write-once `level_complete` flag, plays a
short sequence, and moves to the next level. Death plays a short sequence that never
names its cause — oxygen, spike, and kill area are indistinguishable — and restarts
the level with every piece of state reset. The two outcomes are mutually exclusive by
construction: once `level_complete` latches, no death can be presented, which is what
lets a frame-perfect airlock entry at zero oxygen count as a win rather than a corpse
in a doorway.

## 2. Player Fantasy

Leaving is the reward, and it costs the air you spent. The airlock is not a checkpoint
or a score screen — it is the door out of a room the player just made survivable for
whoever comes next (`game-concept.md` Core Fantasy). The completion beat should read as
release: the clock that has been draining since the first frame stops, and it stops
*because you got out*, not because the game ran out of things to do. Death is the same
journey ending one step short, and it deliberately withholds the diagnosis — the player
is told they died, not why, so a mistimed flip and a mismanaged tank feel like the same
failure to budget (`suit-oxygen.md` R3).

## 3. Detailed Rules

**R1 — A level has exactly two outcomes.** Completion or death. There is no third
state: no mid-level quit that preserves progress, no partial completion, no soft-fail.

**R2 — `level_complete` is a write-once latch.** It becomes `true` when the player
enters the airlock while `goal_unlocked` is `true`, and never returns to `false` for
the lifetime of the level instance. Only `LevelRoot` may write it; every other system
reads it through a getter. Structural detail is ADR-0005 D5.3.

**R3 — Completion outranks death on the same frame.** *Reciprocal reference, not a
rule this document owns:* `suit-oxygen.md` §5 gives airlock entry priority over zero
oxygen. It is named here because that priority is the reason R2's latch must be
readable before any death resolves.

**R4 — Completion is announced to the player.** A level-complete sequence plays on the
latch: a brief hold with game systems paused, then the transition. This sequence is the
player's only confirmation that the level ended. *Source:* with no such signal, the
vertical slice's only observable win state was the oxygen counter silently ceasing to
fall, which made a working completion and a broken one identical to the player and
masked a real bug (`prototypes/gravity-gardener-vertical-slice/REPORT.md`,
§Observations).

**R5 — The completion sequence does not restate what the player already knows.** It
reports that the level ended. It does not announce the airlock unlocking —
`goal_unlocked` is Hidden-diegetic by decision, and the airlock's own state change is
that message (`hud.md` Information Architecture #11). It does not show a bucket tally;
E5 already confirmed each pour as it happened.

**R6 — Death is cause-agnostic.** Oxygen depletion, spike contact, and kill-area entry
produce one identical sequence. Nothing in it names, hints at, or varies with the
cause. Inherited from `suit-oxygen.md` R3.

**R7 — Death is unreachable once `level_complete` latches.** A death armed before the
latch resolves must not present. Presenting one would show the player a death they did
not suffer.

**R8 — Restart is a total reset.** Oxygen returns to `oxygen_capacity`, every bucket
returns unspent, every plant returns to zero intake, `goal_unlocked` returns to
`false`, and `level_complete` dies with the level instance. Nothing carries across a
restart, and there are no checkpoints.

**R9 — Both endings route through one guarded chokepoint.** Completion-transition and
death-restart pass through a single guard so that neither can fire twice, and so a
queued restart cannot outrun a latching completion. Structural detail is ADR-0005 D5.4
(`_transition_pending`).

**R10 — Completion advances to the next level in the authored sequence.** ⚠ **TBD** —
what happens after the final level is undecided, and depends on `game-concept.md`'s
open question of whether a session is one level or several. Not decided here.

## 4. Formulas

This system is a state machine rather than a set of equations. The three expressions
it does own:

**Completion predicate** — evaluated every physics frame, never on a signal edge:

```
level_complete ← level_complete ∨ (goal_unlocked ∧ player_overlaps_airlock)
```

`player_overlaps_airlock` is tracked as continuous state, set by `body_entered` and
cleared by `body_exited`. It is **not** read from the entry signal itself. The
disjunction with the current value is what makes the latch write-once (R2).

**Sequence duration**, for both endings:

```
t_sequence = t_hold + t_transition
```

| Variable | Value | Range | Source |
|---|---|---|---|
| `death_hold_duration` | 0.35 s | 0.2–0.6 s | `hud.md` E6 |
| `complete_hold_duration` | ⚠ **unset** | 0.2–1.5 s | Needs a playtest. Proposed starting value 0.6 s, matching the gravity-flip camera tween the player is already calibrated to |
| `t_transition` | ⚠ **unset** | — | No transition effect is specified; currently an instant `change_scene_to_packed` |

Example, at the proposed values: a completion occupies `0.6 + 0 = 0.6 s` between the
latch and the next level's first frame; a death occupies `0.35 s` before restart.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Player is already standing in the airlock when the final pour completes | The latch fires on that frame. The predicate is evaluated every frame, so it does not depend on the player producing a fresh entry. **This is the exact failure the vertical slice shipped** — its goal checked the unlock only on the `body_entered` edge, and a player already inside never won |
| Oxygen reaches zero on the frame of airlock entry | Completion wins. Owned by `suit-oxygen.md` §5 |
| A death arms on the frame `level_complete` latches | The death is discarded, not queued (R7) |
| Two death causes on the same frame — spike and oxygen | One sequence plays. The chokepoint guard admits the first and refuses the second (R9) |
| Player enters the airlock while `goal_unlocked` is `false` | Nothing happens, and nothing is displayed. The airlock's own locked appearance is the message (`hud.md` #11, Hidden-diegetic). No refusal prompt — E4 exists for capped plants, not for the airlock |
| Player leaves the airlock before the final pour, then returns | Normal. `player_overlaps_airlock` clears and re-sets; the predicate re-evaluates on every frame either way |
| Restart requested while the completion sequence is playing | Refused by the guard (R9) |
| Pause pressed during either sequence | Ignored for the duration of the sequence. ⚠ **New stance** — both sequences already pause game systems, so a second pause layer has nothing to halt, but pause routing is owned by ADR-0010 and this needs its agreement |
| The next level's scene fails to load | Out of scope here — level load validity is owned by ADR-0003's `LevelValidation.validate()` at load |
| Final level completed | ⚠ **TBD** (R10). Not decided |
| `level_complete` latches while the player is mid-pour | The pour is abandoned unresolved. The level is over; the bucket's fate does not matter. No conflict with `watering-system.md` §5, which orders pour-then-death, because that ordering only governs the death path |
| Gravity vector after a restart | Reset to the level's authored default. `GravityAuthority` is an autoload and outlives `reload_current_scene()`, so gravity does **not** reset on its own — `LevelRoot` re-asserts the level's `default_gravity_direction` / `default_gravity_multiplier` on load. Already decided by ADR-0001 D6; recorded here because it is what makes R8 true for gravity |

## 6. Dependencies

| Depends on | Relationship |
|---|---|
| `watering-system.md` | **Reciprocal.** R6's `goal_unlocked` is the precondition in this document's completion predicate (§4). Watering owns when the airlock unlocks; this document owns what happens when the player then enters it |
| `suit-oxygen.md` | **Reciprocal.** §5 owns airlock-entry-beats-zero-oxygen (R3 here); its R3 owns cause-agnostic death (R6 here). This document owns the sequence that presents both |
| `hud.md` | **Reciprocal.** E6 presents the death sequence; a new element presents the completion sequence. `hud.md` line 172–187 states the death sequence "is **not** specified in any GDD" — this document is now that GDD |
| `gravity.md` | **One coupling.** Gravity is otherwise unrelated to level flow, but `GravityAuthority` is an autoload and survives restart, so R8's "total reset" holds for gravity only because `LevelRoot` re-asserts the level's authored default on load (ADR-0001 D6) |
| `LevelState` *(RefCounted)* | Holds the `level_complete` field. ADR-0002 declared it; this document defines its meaning |
| `LevelRoot` / `main.gd` | Sole writer of the latch, owner of the chokepoint guard, and the node that runs both sequences |
| `hazards.md` | **Reciprocal.** Owns two of the three death causes — spikes and kill areas. It owns what kills; this document owns what a death then does. R6 requires hazard death be indistinguishable from oxygen death |
| ADR-0005 | Owns frame ordering, priority values, and `_transition_pending`. This document states *what*, that ADR states *how* |
| ADR-0003 | Owns load-time level validity, including the next level's scene |
| ADR-0010 | Owns pause routing. The §5 pause-during-sequence stance needs its agreement |

## 7. Tuning Knobs

| Knob | Current | Safe range | Affects |
|---|---|---|---|
| `death_hold_duration` | 0.35 s | 0.2–0.6 s | How long failure registers before restart. Below 0.2 s the restart reads as a stutter rather than a death; above 0.6 s it becomes a punishment in a game whose recovery is meant to cost only time |
| `complete_hold_duration` | ⚠ unset — 0.6 s proposed | 0.2–1.5 s | How long the win registers. Needs a playtest before the proposed value is treated as chosen |

> **Placement is not decided here.** These two knobs face the same question as
> `hud.md` Q16 — a fourth tuning resource (needing an ADR-0006 amendment) or
> `@export` on the level root. Deferred to the same Presentation-tier ADR that
> resolves Q16.

## 8. Acceptance Criteria

- [ ] AC1 — Entering the airlock with `goal_unlocked` true sets `level_complete`
      true on that physics frame
- [ ] AC2 — A player already overlapping the airlock when the final pour completes
      wins on the frame `goal_unlocked` becomes true, with no exit and re-entry
- [ ] AC3 — `level_complete`, once true, is still true on every subsequent frame of
      that level instance
- [ ] AC4 — No code path outside `LevelRoot` can write `level_complete`
- [ ] AC5 — Oxygen reaching zero on the frame of a valid airlock entry produces a
      completion and no death sequence
- [ ] AC6 — Oxygen death, spike death, and kill-area death produce byte-identical
      presentation
- [ ] AC7 — A death armed on the frame `level_complete` latches never presents
- [ ] AC8 — Entering the airlock with `goal_unlocked` false produces no state change
      and no on-screen element
- [ ] AC9 — After a restart, `oxygen_remaining` equals `oxygen_capacity`, every
      bucket is unspent, every plant reads zero intake, and `goal_unlocked` is false
- [ ] AC10 — Firing completion and death handlers on the same frame, in either
      order, produces exactly one transition
- [ ] AC11 — A completion is distinguishable from a hung game by a player who has
      never seen the build, within `complete_hold_duration` *(playtest, ADVISORY)*
