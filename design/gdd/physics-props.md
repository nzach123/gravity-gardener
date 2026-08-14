---
status: draft
source: /brainstorm session 2026-08-13
depends-on: gravity.md
date: 2026-08-13
tier: Presentation
---

# Physics Props — Design

> **Status**: Complete draft — all 8 required sections authored and approved.
> Not yet validated with `/design-review`. No props exist in the project yet.

## 1. Overview

Physics props are loose objects — tables, chairs, crates, debris — that share the
level's single global gravity vector with the player (`gravity.md` R9). When a
Gravity Zone rewrites down, unsecured props fall the new way.

Props are **purely cosmetic**. They never collide with the player, the objectives,
or the hazards. They cannot block a path, be stood on, crush anything, or be
pushed. Their entire job is to make a gravity flip legible: a room turning over and
everything loose going with it. This is a Presentation-tier system — it adds no
mechanics, no failure states, and no constraints on level solvability.

## 2. Player Fantasy

The flip should feel like the *ship* moving, not the camera. A player who flips
gravity in an empty corridor has to take the game's word for it; a player who flips
gravity in a mess hall watches every chair leave the floor at once and simply
believes it.

Props are the game's evidence. They confirm that "down" is a property of the room,
that the change is total rather than a trick played on the player character alone,
and that the station is a physical place with loose objects in it that nobody
secured before things went wrong.

They are also deliberately powerless. The player should learn quickly that props
are scenery — beautiful, reactive, and irrelevant to the problem being solved — so
that attention stays on routing buckets and reading gravity.

## 3. Detailed Rules

**R1 — Props are cosmetic.** They never collide with the player, objectives
(plants, buckets, the airlock), or hazards. They cannot block, carry, crush, or be
pushed. No prop may ever affect whether a level is solvable.

**R2 — Props collide with terrain and each other only.** This is enforced by
collision layer and mask, not by conditional logic, so R1 holds by construction
rather than by careful coding. A prop that could be made to collide with the player
by a code path is a bug in the layer setup, not a behaviour to special-case.

**R3 — Props obey the global gravity vector.** They consume the same vector the
player does (`gravity.md` R9), including *during* the easing window — props tip and
slide through the rotation rather than snapping to the new down (`gravity.md` R3).

**R4 — Prop gravity is symmetric.** `gravity.md` R4's ascent/descent asymmetry is a
player jump-feel device; a table has no jump to tune. Applying the asymmetry would
make a prop accelerate differently upward than downward, which reads as broken.
Props use a single magnitude in both directions.

**R5 — Props must be force-woken on every gravity change. ⚠** A settled
`RigidBody2D` sleeps, and a sleeping body does not respond to a change in gravity.
Every gravity change must explicitly wake all props. *This is the single most
likely implementation bug in the system*: flip gravity and half the props sit
motionless on what is now a ceiling.

**R6 — Props reset to authored positions on level restart**, alongside all other
level state. Prop layout is authored, never emergent across attempts.

**R7 — Props leaving level bounds are freed.** A prop that falls out of the level
through a gap is destroyed rather than simulated forever. Nothing is lost — they
are cosmetic.

**R8 — Prop count is budgeted** against the 60 FPS / < 500 draw call targets in
`.claude/docs/technical-preferences.md`. See §7.

## 4. Formulas

Props reuse the derivation in `gravity.md` §4 rather than introducing a second
gravity model.

| Symbol | Meaning |
|---|---|
| `g_descent₀` | Baseline descent gravity from `gravity.md`, 7 656.25 px/s² |
| `m` | Zone gravity multiplier (`zone_gravity_multiplier`) |
| `prop_gravity_scale` | Global prop tuning factor, default 1.0 |
| `h` | Fall distance in px |

```
g_prop = g_descent₀ · m · prop_gravity_scale        (symmetric, per R4)
t_fall = √(2h / g_prop)
```

### Worked example

A prop falling 200 px at `prop_gravity_scale` = 1.0:

| Zone `m` | `g_prop` | `t_fall` |
|---|---|---|
| 0.5× | 3 828.1 | 0.323 s |
| 1.0× | 7 656.3 | 0.229 s |
| 2.0× | 15 312.5 | 0.162 s |

The 1.0× figure is exactly `gravity.md`'s `t_down` of 0.2286 s. **Props and the
player fall at the same rate by construction**, which is what makes a flip read as
one coherent event rather than two systems running alongside each other. Changing
`prop_gravity_scale` away from 1.0 deliberately breaks that coherence and should be
done only for a specific visual reason.

### Fall speed cap

```
prop_speed = min(prop_speed, prop_max_speed)
```

Uncapped, a prop in a 2.0× zone over a long drop can tunnel through thin terrain
between physics frames. Capping is preferred over enabling continuous collision
detection, which costs more than a cosmetic system deserves.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Prop is asleep when gravity changes | Force-woken (R5). Never left settled against a surface that is no longer the floor |
| Gravity changes while a prop is mid-air | The prop follows the eased vector continuously, arcing rather than snapping (R3) |
| Prop comes to rest on a plant, bucket, or the airlock | Cannot occur — props do not collide with objectives (R2). The prop passes through and continues to the terrain below |
| Prop lands on the player | Cannot occur — no player collision (R2). The prop passes through |
| Player walks into a prop | Nothing. No push, no block, no collision response in either direction (R1) |
| Prop falls out of the level | Freed once outside level bounds (R7) |
| Prop stack collapses during a flip | Permitted and desirable. Props collide with each other (R2), so stacks tumble — this is the most legible possible signal that gravity changed |
| Level restart with props scattered | All props return to authored transforms (R6) |
| Prop count exceeds budget | An authoring error. Flagged at load; see §7 |
| Prop overlapping terrain at author time | Standard physics resolution pushes it out. Cosmetic only, no gameplay consequence |

## 6. Dependencies

| Depends on | Relationship |
|---|---|
| `gravity.md` | Consumes the global gravity vector (R9). Reuses `g_descent₀` and `zone_gravity_multiplier` from §4, but **not** the ascent/descent asymmetry (R4) |
| `watering-system.md` | **Buckets and spent jugs are excluded from this system.** Unpicked buckets are static and do not respond to gravity (`watering-system.md` §5); spent jugs are tween-driven with no physics body (R7 there) |
| `suit-oxygen.md` | No interaction. Props cannot kill, so they can never consume oxygen or cause death |
| `GravityZone` | Indirect — props receive the vector through the same broadcast the player does, not by subscribing to zones individually |
| Level design | Prop placement and count budget (§7). No solvability constraints, by R1 |

> **No reciprocal entries are owed to this document.** Props are a pure consumer:
> they read the gravity vector and affect nothing. Any future change that gives a
> prop influence over the player or an objective breaks R1 and requires this
> section to be revisited first.

## 7. Tuning Knobs

| Knob | Lives in | Default | Range | Affects |
|---|---|---|---|---|
| `prop_gravity_scale` | `PropTuning` resource | 1.0 | 0.8 – 1.2 | Global prop fall rate. **Leave at 1.0** — any other value desynchronises props from the player's fall and breaks the coherence described in §4 |
| `prop_max_speed` | `PropTuning` resource | 2 000 px/s | 1 000 – 4 000 | Tunnelling guard. Too low and props visibly float in heavy zones |
| `props_per_level_budget` | `PropTuning` resource | 40 | 10 – 80 | Performance ceiling. Exceeding it risks the 60 FPS / 500 draw call targets |
| `linear_damp` / `angular_damp` | Per prop | engine default | — | How quickly a prop settles after a flip. Higher values calm a busy room; lower values keep debris tumbling |
| `mass`, `friction`, `bounce` | Per prop | — | — | Individual prop character. Purely aesthetic — no gameplay reads from any of these |

Per-prop knobs are exported on the prop scene because variation between a light
chair and a heavy table is the point. Global knobs live in a `PropTuning` resource
per the data-driven rule in `.claude/docs/coding-standards.md`.

## 8. Acceptance Criteria

| # | Criterion | Rule | Type |
|---|---|---|---|
| AC1 | A prop never collides with the player from either direction, at any gravity angle | R1, R2 | Logic |
| AC2 | A prop never collides with a plant, bucket, or the airlock | R1, R2 | Logic |
| AC3 | Every prop in the level responds to a gravity change, **including props that were asleep** | R5 | Logic |
| AC4 | Props adopt a new gravity vector on the same frame the player does | R3 | Logic |
| AC5 | A prop falls 200 px in 0.229 s ±5% at `m` = 1.0, matching the player's `t_down` | §4 | Logic |
| AC6 | Prop fall time is identical upward and downward at the same `m` | R4 | Logic |
| AC7 | Prop speed never exceeds `prop_max_speed`; no prop passes through terrain | §4 | Logic |
| AC8 | Level restart returns every prop to its authored transform | R6 | Integration |
| AC9 | A prop crossing level bounds is freed and does not accumulate | R7 | Logic |
| AC10 | A room of props at budget holds 60 FPS during a gravity flip | R8 | Performance |
| AC11 | A gravity flip in a prop-furnished room reads as the room turning over | R1 | Visual — advisory |

> **AC3 is the one that will actually fail.** Sleeping bodies not responding to
> gravity changes is the defining bug of this system, and it will present as
> "gravity works, but only sometimes." Write this test before the feature.
