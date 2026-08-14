---
status: draft
source: /brainstorm session 2026-08-13
depends-on: gravity.md
date: 2026-08-13
amended: 2026-08-14 — §5/§6 synced to ADR-0002 (LevelState owned by the level root; reset defect resolved structurally). No rule changed
---

# Watering System — Design

> **Status**: Complete draft — all 8 required sections authored and approved.
> Not yet validated with `/design-review`. Depends on `suit-oxygen.md` and
> `physics-props.md`, neither of which is written yet.

## 1. Overview

Water is delivered by single-use buckets scattered through the level. A bucket is
picked up on contact, carried at reduced movement speed, and spent by holding the
interact input at a plant for `water_duration` seconds. Completing a pour empties
the bucket — flung aside and freed — and advances that plant one growth stage.
Once a plant reaches full growth it begins producing oxygen for the room, and it
is that oxygenation, not the watering itself, that cycles the airlock to the next
level open. Plants declare `buckets_required`; larger cosmic plants need more.
Bucket count is the system's primary difficulty lever: every additional bucket is
another round trip through rooms whose gravity the player keeps rewriting, paid
for out of a suit oxygen supply that never refills.

> **Two oxygens — do not conflate.**
>
> | Concept | What it is | Behaviour |
> |---|---|---|
> | **Suit oxygen** | The player's personal supply; the level countdown | Drains continuously, never refills, death at zero. See `suit-oxygen.md` |
> | **Room oxygen** | Produced by a fully grown plant | The win condition; cycles the airlock open |
>
> The two never interact. A plant oxygenates the room only at full growth — the
> moment the level ends — so there is no window in which room oxygen could top up
> the suit.

## 2. Player Fantasy

The last gardener aboard a derelict station, growing the thing that makes the air.
The player is not watering a plant to complete a chore — they are terraforming a
dead room one bucket at a time so it becomes survivable enough to leave.

Each bucket is a commitment: awkward to carry, slowing the player down, and gone
the instant it is spent. The core tension is between the deliberate, stationary
act of pouring and a suit supply that drains whether or not the player is making
progress. Standing still to water costs oxygen that cannot be recovered, so the
real puzzle is the *order* buckets are fetched in, not the reaching of any single
one.

A room that demands more buckets should read as visibly more dangerous before the
player commits to it. The payoff is the last pour: the plant opens out, the room
fills with air that is suddenly yours, and the airlock cycles.

## 3. Detailed Rules

**R1 — Buckets are single-use consumables.** A bucket is a discrete world object
picked up on body contact, with no input required (matches current `bucket.gd`).
The player carries at most one at a time; while carrying, further pickups are
refused and the untouched bucket remains in the world. A bucket holds exactly one
pour — there is no partial fill and no capacity meter. Completing a pour destroys
it. There is no voluntary drop: R8 guarantees a valid destination always exists
for every bucket the player can pick up.

**R2 — Carrying penalises movement speed only.** While carrying, `max_speed` is
multiplied by `carry_speed_multiplier` (< 1.0). Jump velocity, gravity strength,
coyote time, jump buffer and wall jump are all untouched. *This explicitly
preserves R5 of `gravity.md`.* Rationale: a jump penalty would hand level design a
second independent lever on reachability, so a gap could no longer be proven
crossable by reading the zone multiplier alone. Speed is a soft cost paid in
oxygen; jump height is a hard geometric contract.

**R3 — Pour is time-based, held-input, and locks the player.** While the player is
inside a plant's interact area, carrying a bucket, and holding `interact`,
`water_progress` accumulates by `delta`. Player movement is locked for the
duration. On `water_progress >= water_duration` the pour completes: the bucket is
consumed (R1), flung (R7), the plant advances one growth stage, and the level
counter increments (R6).

**R4 — Early release keeps the bucket and resets progress.** Releasing `interact`,
or leaving the interact area, before completion sets `water_progress` to zero and
unlocks the player. The bucket is retained. Progress never persists between
attempts. Rationale: suit oxygen already taxes wasted time; destroying a scarce
bucket on top of that would risk unwinnable states, since R8 supplies exactly
enough.

**R5 — Plants cap intake at `buckets_required`.** Each plant exports
`buckets_required: int` (≥ 1) and tracks `buckets_received: int`. A pour is refused
outright — the interaction never engages — once
`buckets_received >= buckets_required`. A capped plant is *fully grown* and begins
producing room oxygen. A refused pour costs the player nothing; the bucket is kept.

**R6 — The airlock gates on the level-wide consumed-bucket counter.** The airlock
is the existing `Goal` scene (`src/scenes/goal.tscn`, `src/scripts/goal.gd`) —
"airlock" is its fictional name, not a new object. Its unlock behaviour is
unchanged: `goal.gd` watches `goal_unlocked`, plays `goal_open`, and emits
`player_reached_goal` on entry. Only the *source* of the flag moves — from
`GameManager` to the injected `LevelState` (ADR-0002).

What changes is the condition that raises the flag. `buckets_consumed` increments
on each completed pour, and the flag is set when
`buckets_consumed >= buckets_total`, where `buckets_total` is the number of buckets
present at level load. This replaces the current test at `plant.gd:76-79`
(`plants_watered >= plants_total`), and moves ownership of the unlock decision off
the individual plant — no single plant should be deciding whether the room is
breathable.

Fictionally this is the moment the grown plants have oxygenated the room, and the
airlock can safely cycle.

**R7 — The spent jug is flung and freed.** On completion the bucket detaches from
the hand, plays a scripted arc away from the player in the current gravity basis,
and is freed when the tween ends. It has no physics body and no collision. The
throw *direction* is randomised for visual variety; because the jug cannot collide
with anything and its lifetime is fixed, this randomness is purely cosmetic and
touches no testable state — satisfying the determinism rule in the testing
standards.

**R8 — Level invariant: `buckets_total == Σ(buckets_required)`.** This is an
authoring contract on every level, and it must be validated at load. Both
directions of mismatch break the level:

| Condition | Failure |
|---|---|
| `buckets_total > Σ(required)` | Plants all cap out, counter can never reach total, **airlock never opens** — unwinnable |
| `buckets_total < Σ(required)` | Counter reaches total early, **airlock opens with plants unfinished** — fiction broken |

The first failure mode is the more dangerous: a silently unwinnable level with no
feedback. The load-time check must log an error rather than fail quietly.

> R5, R6 and R8 must be read as a set. R6 alone is exploitable — a level-wide
> counter lets the player dump every bucket into one small plant. R5 makes
> dumping impossible; R8 makes the counter provably equivalent to "all plants
> fully grown".

## 4. Formulas

### Variables

| Symbol | Name | Meaning |
|---|---|---|
| `s` | `max_speed` | Base movement speed, 350 px/s (from `gravity.md`) |
| `k` | `carry_speed_multiplier` | Carry penalty, 0 < k < 1 |
| `w` | `water_duration` | Seconds of held input to complete one pour |
| `d_f` | fetch distance | Path length from plant to the next bucket |
| `d_r` | return distance | Path length from that bucket back to the plant |
| `N` | `buckets_total` | Buckets in the level (== Σ `buckets_required`, R8) |

**Pour progress** — accumulates only while the interact input is held (R3), resets
to zero on release (R4):

```
water_progress += delta
complete when water_progress >= w
```

**Carry speed** (R2) — jump velocity is deliberately absent from this formula:

```
effective_speed = s · k          while carrying
effective_speed = s              otherwise
```

**Cost of one bucket delivery** — the fetch leg runs at full speed, the return leg
is penalised:

```
t_bucket = d_f/s  +  d_r/(s·k)  +  w
```

**Level time floor** — the minimum survivable oxygen budget, before margin:

```
t_level = Σ (d_f,i/s + d_r,i/(s·k) + w)     for i = 1..N
O_level = t_level · (1 + margin)             margin ≈ 0.4
```

**Growth fraction** — drives the plant's visual stage (R5):

```
growth_fraction = buckets_received / buckets_required
```

### Worked example

One plant, `buckets_required = 3`, each bucket 800 px away, `s = 350`, `k = 0.6`,
`w = 5.0`:

```
fetch leg   = 800 / 350        = 2.29 s
return leg  = 800 / (350·0.6)  = 3.81 s     ← 1.67× the fetch leg
pour        =                    5.00 s
t_bucket    =                   11.10 s
t_level     = 11.10 × 3       = 33.29 s
O_level     = 33.29 × 1.4     = 46.6 s  →  author as 45–50 s
```

### Sensitivity of `k`

The carry multiplier is the strongest lever on level duration, because it only
ever taxes the return leg:

| `k` | return leg | `t_bucket` | `t_level` (N=3) |
|---|---|---|---|
| 0.8 | 2.86 s | 10.14 s | 30.4 s |
| 0.6 | 3.81 s | 11.10 s | 33.3 s |
| 0.5 | 4.57 s | 11.86 s | 35.6 s |
| 0.4 | 5.71 s | 13.00 s | 39.0 s |

### Ranges

| Knob | Range | Notes |
|---|---|---|
| `w` | 2.0 – 8.0 s | Default 5.0. Under 2.0 the lock stops reading as a commitment; over 8.0 it is dead air |
| `k` | 0.4 – 0.9 | Default 0.6. Below 0.4 reads as broken controls; above 0.9 is imperceptible |
| `buckets_required` | 1 – 4 | Above 4 becomes repetition rather than escalation |
| `margin` | 0.3 – 0.6 | Below 0.3 punishes any routing mistake; above 0.6 the timer stops mattering |

> **`d_f` and `d_r` are path lengths, not straight lines.** Under rotating gravity
> the traversable route can be far longer than the euclidean distance between two
> points. These must be measured by walking the route, never measured off the level
> in a straight line.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Player dies mid-pour | Level restarts. All watering state resets: buckets respawn, `buckets_received` returns to 0 on every plant, `buckets_consumed` returns to 0, suit oxygen refills. No progress carries across a restart |
| Player releases `interact` mid-pour | R4 — bucket retained, `water_progress` set to 0, player unlocked |
| Player leaves the interact area mid-pour | Identical to early release. No partial credit |
| Gravity flips mid-pour | The pour is unaffected and the lock holds through the transition. The player's sprite rotates with the easing direction and unlocks into the new orientation on completion |
| Player carrying a bucket walks over another | R1 — pickup refused, the second bucket remains untouched in the world |
| Player approaches a fully grown plant | R5 — the interaction never engages, no progress accumulates, no bucket is consumed. The interact prompt is suppressed so the refusal is legible rather than silent |
| Two plants' interact areas overlap | The pour targets the **nearest plant with remaining capacity**. If every plant in range is capped, no interaction engages |
| Unpicked buckets during a gravity flip | Buckets are **static** world objects and do not respond to gravity changes. Rationale: a bucket that relocates on a flip would break R8's guarantee that the level's supply stays reachable |
| Spent jug in flight during a gravity flip | The jug completes its arc in the gravity basis captured at throw time (R7). The cosmetic mismatch is accepted — it has no collision and a fixed lifetime |
| Pour completes on the same frame oxygen reaches zero | The pour resolves first, then the death check runs. The player still dies. R6 unlocks the airlock; it does not teleport the player to it — the door must be physically reached |
| Player reaches the airlock while carrying a bucket | Cannot occur under R8, since the counter only reaches `buckets_total` when every bucket has been consumed. If it does occur, the level is mis-authored — log an error |
| Level restart while carrying | `carrying_bucket` is cleared. Restart reloads the scene, which destroys the level root and with it the `LevelState` — a fresh one is constructed on load, so carry state cannot survive (ADR-0002) |

> ⚠ **Existing defect — resolved by ADR-0002.** `GameManager.reset_level_state()`
> clears `goal_unlocked`, `plants_watered` and `plants_total`, but leaves
> `carrying_bucket` set. After a death the player retains a bucket that no longer
> exists in the scene. Under R1 this corrupts the level's bucket supply.
>
> ADR-0002 removes the defect *by construction* rather than by fixing the reset
> function: `LevelState` is owned by the level root and dies with it, and
> `reset_level_state()` is deleted outright. AC8 remains the test for this — it now
> verifies object lifetime rather than that someone remembered to clear a field.

## 6. Dependencies

### Design documents

| Document | Relationship |
|---|---|
| `gravity.md` | R2 is bounded by gravity.md's R5 (fixed jump velocity) — carrying must never touch jump. Carry speed scales `max_speed`, which feeds *every* gravity derivation, so `k` changes nothing about jump height by design |
| `suit-oxygen.md` | Pouring costs oxygen with no offset. §4's `O_level` formula derives the level timer from watering geometry, so oxygen budgets are downstream of bucket placement |
| `physics-props.md` | Explicitly **excludes** buckets and spent jugs. Buckets are static (§5); jugs are tween-driven with no body (R7) |

### Code

| Component | Responsibility under this design |
|---|---|
| `PlayerWateringComponent` | Owns carry state, the held-bucket reference, and pour driving. Currently holds only an `is_watering` bool — absorbs the logic now spread across `main.gd` and `plant.gd` (change #6) |
| `PlayerMovementComponent` | Owns `max_speed`; applies `carry_speed_multiplier` when carrying (R2) |
| `Plant` (`plant.gd`) | `buckets_required` / `buckets_received`, intake cap (R5), growth visuals. **Stops touching `GameManager`** — reports a completed pour and nothing more |
| `Bucket` (`bucket.gd`) | Pickup, consumption, throw-and-free (R7). Must stop declaring `extends Node` while being given a transform |
| `Goal` (`goal.gd`) | **Behaviour unchanged.** Watches `goal_unlocked` on the injected `LevelState` instead of on `GameManager` (ADR-0002). Listed so it does not get opened for anything more than that |
| `LevelState` *(RefCounted, new)* | Owns `buckets_total`, `buckets_consumed`, `carrying_bucket`, and the derived `goal_unlocked`. Constructed per level by the level root and injected into consumers (ADR-0002). **Not** an autoload |
| `GameManager` | **No longer holds watering state.** Retains cross-level concerns only (ADR-0002) |
| `main.gd` / level root | Replaces `@export var bucket: Bucket` with a group lookup; constructs and injects `LevelState`; owns the tally and the R8 load-time validation |
| HUD *(new scene)* | Carry indicator. The oxygen readout belongs to `suit-oxygen.md`, not here |

### Level design

Bound by R8 (`buckets_total == Σ buckets_required`) and by §4's requirement that
`d_f` / `d_r` be measured as walked paths, not straight lines.

### Reciprocal entries

Per the bidirectional-dependency rule in `.claude/rules/design-docs.md`:

1. ✅ `gravity.md` §6 → **Watering System**: consumes `max_speed` via
   `carry_speed_multiplier`; must not affect jump velocity (R5/R10)
2. ✅ `suit-oxygen.md` §6 → **Watering System**: pour duration and bucket routing
   set the level's oxygen budget
3. ✅ `physics-props.md` §6 → **Watering System**: buckets and spent jugs are
   excluded from prop physics

## 7. Tuning Knobs

| Knob | Lives in | Default | Safe range | Affects |
|---|---|---|---|---|
| `buckets_required` | `Plant`, exported per instance | 1 | 1 – 4 | The primary **risk dial**. Sets plant size and how many round trips a level demands. Drives Σ for R8 |
| `water_duration` | `Plant`, exported per instance | 5.0 s | 2.0 – 8.0 s | Length of the movement lock, and therefore the direct oxygen cost of each pour |
| `carry_speed_multiplier` | `WateringTuning` resource | 0.6 | 0.4 – 0.9 | Return-leg speed. Per §4 the **strongest single lever on level duration** — it taxes every carried leg and nothing else |
| `interact_radius` | `Plant`'s `InteractArea2D` | — | — | How precisely the player must position to pour. Enlarging it makes overlapping-plant targeting ambiguous (§5) |
| `throw_arc_height` | `WateringTuning` resource | 120 px | 60 – 200 px | Cosmetic only (R7) |
| `throw_duration` | `WateringTuning` resource | 0.6 s | 0.4 – 0.8 s | Cosmetic. Must stay below the time to reach the next bucket, or spent jugs visibly pile up |
| `throw_angle_spread` | `WateringTuning` resource | ±45° | 0 – 90° | Cosmetic variety only. Touches no testable state (R7) |

### Placement

Per-plant knobs (`buckets_required`, `water_duration`) are exported on the `Plant`
node because they are *meant* to vary per instance — that variation is the level
design vocabulary. Player-global knobs live in a `WateringTuning` resource
(`.tres`) so they are tunable without touching code, per the data-driven rule in
`.claude/docs/coding-standards.md`.

### Escalation rule

`buckets_required` and `carry_speed_multiplier` both scale level duration, and they
**multiply**. A level at `buckets_required = 4` with `k = 0.4` costs 4 × 13.0 s =
52 s of pure delivery before any gravity puzzling happens. Pushing both dials at
once escalates difficulty far faster than it reads on paper.

> **Therefore:** `buckets_required` is the per-level difficulty dial. `k` is a
> global feel constant — set once, then left alone. Do not tune `k` to make an
> individual level harder.

### Not owned here

`margin` and `O_level` from §4 are consumed by this system but belong to
`suit-oxygen.md`. Level oxygen budgets are authored there.

## 8. Acceptance Criteria

| # | Criterion | Rule | Type |
|---|---|---|---|
| AC1 | While carrying, horizontal speed equals `s · k` ±2%; **jump apex height is identical to the non-carrying case** at the same zone multiplier | R2 | Logic |
| AC2 | Holding `interact` for `water_duration` completes exactly one pour and consumes exactly one bucket | R1, R3 | Logic |
| AC3 | Releasing `interact` at any point before `water_duration` leaves `buckets_received` unchanged and the bucket still carried | R4 | Logic |
| AC4 | A plant at `buckets_received == buckets_required` refuses further pours; `water_progress` never accumulates | R5 | Logic |
| AC5 | Walking over a second bucket while carrying leaves that bucket in the scene; the player never holds two | R1 | Integration |
| AC6 | `goal_unlocked` becomes true exactly when `buckets_consumed` reaches `buckets_total`, and never before | R6 | Logic |
| AC7 | Level load logs an error when `buckets_total != Σ buckets_required` | R8 | Logic |
| AC8 | After a level restart: carry state cleared, all buckets present, every plant reads `buckets_received == 0` | §5 defect | Integration |
| AC9 | A gravity flip during a pour does not interrupt it; the pour completes and the player unlocks in the new orientation | §5 | Integration |
| AC10 | The spent jug is freed within `throw_duration + 0.1 s` of pour completion; no jug persists into the next pour | R7 | Logic |
| AC11 | Unpicked buckets do not change position when gravity changes | §5 | Logic |
| AC12 | With two overlapping interact areas, the nearest plant *with remaining capacity* receives the pour | §5 | Integration |
| AC13 | Completing the final pour on the frame oxygen reaches zero results in death, not level completion | §5 | Integration |
| AC14 | The player reads as visibly slower and visibly burdened while carrying | R2 | Visual — advisory |

> **AC1 is load-bearing.** It is the automated guard on gravity.md's R5: if a
> future change ever lets carry weight touch jump velocity, AC1 fails and the
> geometric contract that makes levels provably solvable breaks. Write it first.
