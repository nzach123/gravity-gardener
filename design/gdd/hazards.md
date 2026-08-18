---
status: authored — all 8 sections complete, pending /design-review
source: src/scripts/spike_hazard.gd, src/scripts/main.gd, src/scenes/levels/level_05.tscn, src/scenes/levels/level_06.tscn, design/art/art-bible.md, design/gdd/game-concept.md
date: 2026-08-17
reason: closes the "Spike hazards — implemented but undocumented" entry in systems-index.md, and answers the vertical-slice tester's "needs more danger" finding (REPORT.md §Observations)
---

# Hazards — Design

> **Scope.** This document owns what a hazard is, how it kills, how it is placed,
> and how it behaves when gravity rotates. It does not own what happens after a
> death — that is `level-flow.md` R6–R8 — and it does not own the oxygen failure
> mode, which is `suit-oxygen.md`.

## 1. Overview

A hazard is level geometry that kills on contact. There is no health, no damage
accumulation, and no invulnerability window — touching a hazard ends the level
exactly as running out of oxygen does, through the same cause-agnostic path. Hazards
come in two kinds with two different jobs: **spikes**, which are visible, authored
threats the player must read and route around, and **kill areas**, which are invisible
volumes outside the playable space that catch a player who has left it. Neither moves
when gravity flips; a hazard is part of the room, and rotating which way is down
changes how the player approaches it, not where it is.

## 2. Player Fantasy

Danger is a property of the room, read the same way gravity is. The player looks at a
chamber and asks two questions at once — "which way will I fall here?" and "what will
I fall *into*?" — and the answers interact. A spike bed that is harmless while it is
on the ceiling becomes the floor after a flip. This is the "agency and danger" the
vertical slice was missing (`prototypes/gravity-gardener-vertical-slice/REPORT.md`
§Observations): not a threat that chases the player, but one more fixed fact about a
room that the player's own gravity choices make relevant or irrelevant. Death costs
only time (`game-concept.md` Flow State Design), so a hazard is a reason to plan a
route, not a reason to fear committing to one.

## 3. Detailed Rules

**R1 — Contact is instant death, never damage.** No health pool, no partial damage,
no invulnerability frames, no knockback. *Naming defect:* `spike_hazard.gd` declares
`signal inc_hazard_dmg`, which implies incremental damage. `main.gd:23` connects it
directly to `restart_level`, so the behaviour already matches this rule. **The name is
wrong and must be changed at implementation** — it is the only thing in the codebase
suggesting this game has a health system, and `game-concept.md`'s Anti-Pillars say it
does not.

**R2 — Two kinds, two jobs.** *Spikes* are visible authored geometry, placed
deliberately, and are a designed challenge. *Kill areas* are invisible volumes that
catch a player who has left the playable space. A kill area is a safety net and **must
never be used as a designed challenge** — an invisible instant-kill volume inside
playable space is unreadable by construction and violates R4.

**R3 — Hazard death is indistinguishable from any other death.** Same sequence, same
timing, nothing names the cause. Inherited from `suit-oxygen.md` R3 and
`level-flow.md` R6.

**R4 — A hazard is readable before it is lethal.** It must be identifiable by contour
alone, in greyscale, before its colour is read. `art-bible.md` reserves a shape family
for hazards that appears nowhere in safe geometry — sharp, irregular, high
edge-frequency triangulation — and reserves **Hazard Crimson `#B21030`** exclusively
for hazard geometry, so any crimson on screen means "this will kill you." Colour is
the confirmation; shape is the message.

**R5 — A hazard mounts at any orientation. ⚠** It must be placeable on floor, ceiling,
or either wall, and read correctly at every gravity angle. *Current code does not
satisfy this:* `spike_hazard.gd` hard-codes `tiled_body.is_horizontal = true` with the
comment "Hazard only supports horizontal orientation." In a game whose core mechanic
rotates the world, a horizontal-only hazard cannot be placed on a surface the player
will later stand on. **This is a required change, not an observation.**

**R6 — Hazards do not move with gravity.** They are level geometry, not props. A
gravity flip never relocates, reorients, or drops a hazard. This is what separates
them from `physics-props.md`, whose whole purpose is to visibly obey the shared
gravity vector.

**R7 — Hazards must not break the oxygen derivation.** `oxygen_capacity` derives from
walked path lengths (`watering-system.md` §4). If a hazard forces a detour, that
detour **is** the walked route and must be measured as such. A hazard may never make
the derived budget unreachable — placing one is a level-geometry change and re-derives
the level's timer, exactly as moving a bucket does.

**R8 — Kill areas bound the playable space and nothing else.** A kill area may only
occupy volume outside where the player is intended to be able to reach and survive.

**R9 — Every hazard's collision mask must include the player's layer.** Governed by
ADR-0004. ⚠ **BUG-0001:** the kill areas in `level_05` and `level_06` mask `world`(1)
while the player is on layer 2, so `1 & 2 == 0` and they never fire. Both are
currently inert, and any test of the death sequence against them will show nothing.

**R10 — No hazard is unavoidable on the intended route.** A level whose derived route
requires passing through a hazard is mis-authored, in the same class of failure as
`buckets_total ≠ Σ buckets_required` (`watering-system.md` R8).

## 4. Formulas

**Spike extent**, from the two exports already on `spike_hazard.gd`:

```
hazard_width = hazard_length_blocks × block_size        (px)
```

| Variable | Default | Range | Meaning |
|---|---|---|---|
| `hazard_length_blocks` | 3 | 1–12 | Tiled segments along the hazard's mounting surface |
| `block_size` | 17 | 17 | Segment size in px. Fixed by the tile art; not a design dial |

At defaults, one spike run is `3 × 17 = 51 px` — roughly a seventh of a second of
travel at `max_speed` 350.

**Lethality predicate**, evaluated on overlap:

```
kills = (hazard_collision_mask & player_collision_layer) ≠ 0
```

A hazard whose mask fails this test is **inert, not lenient**. This must be a
load-time validation failure, not a silent no-op — it is exactly how `level_05` and
`level_06` came to ship with dead kill areas (R9, BUG-0001).

**Route cost.** A hazard that forces a detour changes the level's oxygen budget,
because the detour is the walked route:

```
d_route(with hazard) ≥ d_route(without hazard)
O_level re-derived per watering-system.md §4
```

Placing a hazard is a level-geometry change. It re-derives the timer exactly as moving
a bucket does (R7).

**Clearance.** The minimum passable gap a hazard may leave on the intended route is
⚠ **unset** — it needs a playtest to establish, and inventing a number here would give
level authors a false constraint. Recorded as a tuning knob in §7 with no value.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Gravity flips while the player is airborne above spikes | The player falls into them and dies. Intended — the flip is a commitment (`gravity.md` §5, "caught by the new floor") |
| The player deliberately flips gravity so a spike surface becomes the floor | Legitimate death. R10 only forbids hazards being unavoidable on the *intended* route; it does not protect a player from a route they chose |
| Player spawns inside or touching a hazard | Mis-authored level. Must fail at load, not at first contact — proposed as a new `LevelValidation` check under ADR-0003 (see §6) |
| A hazard's mask excludes the player's layer | **Load-time validation failure.** Not a silent no-op. This is BUG-0001's failure mode, and it is the same class of silent trap as the `body_entered`-edge win trigger |
| Hazard contact on the frame `level_complete` latches | No death. `level-flow.md` R7 discards it |
| Hazard contact and oxygen depletion on the same frame | One death, one sequence. `level-flow.md` R9's chokepoint admits the first and refuses the second |
| Player dies while carrying a bucket | Bucket is lost with everything else; full reset (`level-flow.md` R8) |
| Hazard overlaps a gravity zone | Both fire. The gravity change is irrelevant — the level is restarting |
| Hazard mounted on a moving platform | ⚠ **Out of scope.** `moving_platform.gd` exists in `src/` with no GDD (`systems-index.md`, *Implemented but undocumented*). Flagged, not decided |
| Hazard extends outside the level bounds | Mis-authored. Same validation class as spawning inside one |
| A kill area placed inside playable space | Forbidden by R2. Not detectable automatically — this is an authoring-discipline rule, enforced at level review |

## 6. Dependencies

| Depends on | Relationship |
|---|---|
| `level-flow.md` | **Reciprocal.** Supplies two of the three death causes; `level-flow.md` R6–R8 owns the sequence, the guard, and the reset. This document owns only what kills |
| `suit-oxygen.md` | **One-way.** Its R3 requires all deaths be indistinguishable, which R3 here inherits. Oxygen death and hazard death share one presentation |
| `watering-system.md` | **Reciprocal.** A hazard that forces a detour lengthens the walked route, and `d_f`/`d_r`/`d_exit` must be measured around it. Placing a hazard re-derives the level's oxygen budget |
| `gravity.md` | **Reciprocal.** Hazards never move with gravity (R6), but a flip changes which surface the player falls toward, so it changes which hazards are reachable. The interaction is the design, not a side effect |
| `physics-props.md` | **One-way, by contrast.** Props exist to visibly obey the shared gravity vector; hazards exist to visibly ignore it. Props are a pure consumer and are owed no reciprocal entry (`systems-index.md`) |
| `art-bible.md` | Owns the reserved hazard shape grammar and Hazard Crimson `#B21030`. R4 is that contract stated as a rule |
| ADR-0004 | Owns the collision layer allocation R9's mask predicate is checked against |
| ADR-0003 | **Proposed extension.** Two new `LevelValidation` checks are needed: `V-HAZARD-MASK` (every hazard's mask includes the player layer) and `V-HAZARD-SPAWN` (no hazard overlaps the spawn point). Neither exists; proposed here, owned there |
| `spike_hazard.gd`, `main.gd`, `KillArea2D` | The existing implementation. R1 renames `inc_hazard_dmg`; R5 removes the horizontal-only constraint; R9 fixes BUG-0001 |

## 7. Tuning Knobs

| Knob | Current | Safe range | Affects |
|---|---|---|---|
| `hazard_length_blocks` | 3 | 1–12 | Width of one spike run. Below 1 is not a hazard; above 12 the run stops reading as an obstacle and starts reading as terrain |
| `block_size` | 17 | fixed at 17 | Tile segment size. Fixed by the art, listed for completeness — **not a design dial** |
| `min_clearance` | ⚠ **unset** | — | Minimum passable gap a hazard may leave on the intended route. Needs a playtest; deliberately not invented here |

> **There is no damage, health, or invulnerability knob, and there must never be
> one.** R1 makes contact instantly lethal, and `game-concept.md`'s Anti-Pillars rule
> out a health system. A knob here would be the first step toward one.

## 8. Acceptance Criteria

- [ ] AC1 — Player contact with a spike or kill area restarts the level with no
      intermediate state
- [ ] AC2 — Spike death, kill-area death, and oxygen death produce byte-identical
      presentation
- [ ] AC3 — No code path reduces a health value, applies partial damage, or grants
      invulnerability frames
- [ ] AC4 — A spike reads as a hazard in a greyscale screenshot, from contour alone,
      with no colour information
- [ ] AC5 — Hazard Crimson `#B21030` appears on no non-hazard geometry in any level
- [ ] AC6 — A spike mounts and renders correctly on floor, ceiling, and both walls, at
      gravity angles 0°, 90°, 180° and 270°
- [ ] AC7 — A gravity flip leaves every hazard's world position and rotation unchanged
- [ ] AC8 — A level containing a hazard whose mask excludes the player layer fails
      `LevelValidation` at load
- [ ] AC9 — A level whose spawn point overlaps a hazard fails `LevelValidation` at load
- [ ] AC10 — Hazard contact on the frame `level_complete` latches produces no death
- [ ] AC11 — Hazard contact and oxygen depletion on the same frame produce exactly one
      restart
- [ ] AC12 — Every level's `oxygen_capacity` is derivable from a walked route that
      touches no hazard *(level-authoring check, ADVISORY)*
