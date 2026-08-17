---
status: reverse-documented
source: design/gdd/gravity.md, design/gdd/watering-system.md, design/gdd/suit-oxygen.md, design/gdd/physics-props.md, src/scripts/
date: 2026-08-15
verified-by: nzach123
---

# Game Concept: Gravity Gardener

*Created: 2026-08-15*
*Status: Draft*

> **Note**: This document was reverse-engineered from four existing system GDDs
> and the current `src/` implementation, then completed with the user's answers
> on pillars, hook, audience, and scope (session 17). No `/brainstorm` session
> produced this document — the game was designed and mostly implemented before
> a top-level concept existed. Sections marked ⚠ **TBD** are the author's
> inference, not sourced from prior decisions, and need explicit confirmation
> or revision before this document gates the art bible.

---

## Elevator Pitch

> It's a 2D gravity-flip puzzle-platformer where you rewrite which way is down
> to route single-use water buckets to dying plants on a derelict space
> station, racing a suit oxygen supply that never refills.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Puzzle-platformer (environmental/physics puzzle, traversal-focused) |
| **Platform** | PC (keyboard/mouse only — no gamepad or touch input configured, `.claude/docs/technical-preferences.md`) |
| **Target Audience** | Broader casual audience, accessibility-forward (see Target Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 10–20 minutes |
| **Monetization** | None yet |
| **Estimated Scope** | Small (1–3 months, solo) — see MVP Definition |
| **Comparable Titles** | ⚠ **TBD — not user-validated.** Structural comparison only: *VVVVVV* (gravity-flip traversal). No competitive/market positioning has been confirmed by the user; do not treat this as a marketing claim |

---

## Core Fantasy

The last gardener aboard a derelict station, growing the thing that makes the
air. The player is not watering a plant to complete a chore — they are
terraforming a dead room one bucket at a time so it becomes survivable enough
to leave.

*(Sourced verbatim from `watering-system.md` §2, cross-referenced against
`suit-oxygen.md` §2's "the tank only ever goes one direction" and `gravity.md`
§2's astronaut-aboard-a-derelict-ship framing. All three system GDDs converge
on the same setting and player identity independently — this is the strongest
piece of evidence in the reverse-documentation.)*

---

## Unique Hook

The countdown isn't an arbitrary difficulty dial. `oxygen_capacity` is
mechanically derived from the level's own bucket-to-plant geometry
(`suit-oxygen.md` R6, the `O_level` formula in `watering-system.md` §4) —
walked path lengths, not straight lines. Route planning and the timer are the
same problem, not two separate systems layered on top of each other: moving a
bucket six tiles farther in the editor changes how long the player has to
live, automatically.

*And-also test*: "It's a gravity-flip puzzle-platformer, and also the timer
you're racing is a direct readout of the route you chose, not a number the
designer picked."

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

⚠ **TBD — inferred, not sourced.** Ranked from what the four GDDs emphasize
repeatedly (traversal puzzles, budgeted urgency, room-reading); not confirmed
against a stated design intent. Revise before treating as binding.

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | 3 | Gravity-flip legibility via physics props tumbling to the new down (`physics-props.md`); NES-curve jump feel (`gravity.md` §2) |
| **Fantasy** | 4 | Astronaut-gardener framing on a derelict station |
| **Narrative** | N/A | No narrative system designed or implemented |
| **Challenge** | 1 | Reading a room's gravity and bucket layout to prove a route is survivable before committing to it |
| **Fellowship** | N/A | Single-player, no social systems |
| **Discovery** | 2 | Each room is a fresh spatial puzzle — "which way will I fall here, and can I reach that ledge once I do?" (`gravity.md` §2) |
| **Expression** | N/A | No build/customization/cosmetic systems |
| **Submission** | N/A | Explicitly the opposite — `suit-oxygen.md` §2 targets "budgeted urgency," not relaxation |

### Key Dynamics (Emergent player behaviors)

- Players will mentally map a room's gravity states before moving, rather than
  reacting to flips as they happen — the puzzle is legible ahead of the
  commitment (`gravity.md` §2: "which way will I fall here").
- Players will sequence bucket pickups to minimize penalized return-leg
  distance under carry speed, since `k` (`carry_speed_multiplier`) is the
  strongest lever on level duration (`watering-system.md` §4 sensitivity
  table).
- Players will treat standing still to pour as the most dangerous action in
  the game, not the safest one — oxygen drains identically whether moving or
  stationary (`suit-oxygen.md` R2).

### Core Mechanics (Systems we build)

1. **World-state gravity** — a per-room vector the player rewrites by entering
   a Gravity Zone; persists until overwritten; affects the player and all
   rigid props identically (`gravity.md`).
2. **Single-use bucket delivery** — pick up, carry at reduced speed, spend via
   a held-input pour that locks movement; plants cap intake and gate the level
   exit on a level-wide consumed-bucket counter (`watering-system.md`).
3. **Non-refilling oxygen budget** — a per-level countdown, capacity derived
   from the level's own bucket geometry, drains unconditionally in every
   player state (`suit-oxygen.md`).
4. **Cosmetic physics props** — loose objects that share the global gravity
   vector and never affect solvability, existing purely to make a flip read as
   the room moving rather than a camera trick (`physics-props.md`). At MVP
   tier this is already satisfied without props — camera tween and continuous
   player-sprite rotation alone carry the "room moving" proof (`art-bible.md`
   §1.3); physics props add a second corroborating layer once built at
   Vertical-Slice tier.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Player chooses bucket-fetch order and route within a room; no forced sequence | Supporting |
| **Competence** | Success is proving a route survivable ahead of time, then executing it under a real clock | Core |
| **Relatedness** | ⚠ **TBD** — no system serves this; single-player, no social hooks designed | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — completing every plant's growth and reaching the airlock within budget
- [x] **Explorers** — reading each room's gravity and prop behavior to find a survivable route
- [ ] **Socializers** — not served; no multiplayer or social system exists
- [ ] **Killers/Competitors** — not served; no PvP, leaderboard, or competitive system exists

### Flow State Design

- **Onboarding curve**: ⚠ **TBD.** No tutorial system exists in `src/` (`main.gd`,
  `start_menu.gd`) — the first level currently teaches by placement alone, not
  by a designed onboarding sequence.
- **Difficulty scaling**: `buckets_required` is the intended per-level
  difficulty dial (`watering-system.md` §7); `k` and `margin` are meant to stay
  fixed as global feel constants, not tuned per level.
- **Feedback clarity**: escalating oxygen-readout thresholds at 50/25/10%
  remaining (`suit-oxygen.md` §4); "the player must never be surprised by the
  tank running out" (R7).
- **Recovery from failure**: instant full-scene restart on death (oxygen,
  spike, or kill-area) — `main.gd restart_level()`. All watering and oxygen
  state resets to full; no partial-progress carry.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Read the current room's gravity, move toward the next bucket or plant, flip
gravity at a Gravity Zone when the route requires it, and watch loose props
confirm the flip actually happened.

### Short-Term (5–15 minutes)

One level: fetch buckets in a chosen order, carry each back at reduced speed,
hold the interact input to pour at a plant, repeat until every plant is fully
grown, then reach the airlock before the suit oxygen countdown reaches zero.

### Session-Level (10–20 minutes)

⚠ **TBD** — no multi-level session structure is documented. Currently 8
levels exist in `src/scenes/levels/`, chained via `change_scene_to_packed`
(`main.gd`); whether a session means one level or several in sequence has not
been decided by the user.

### Long-Term Progression

⚠ **TBD.** No progression, unlock, or meta-system is designed or implemented
beyond the fixed 8-level sequence.

### Retention Hooks

⚠ **TBD** — none of the four retention categories below have a designed
system behind them yet:
- **Curiosity**: not designed
- **Investment**: not designed — deaths cost only time (full state reset)
- **Social**: not applicable (single-player)
- **Mastery**: partially present — faster/cleaner routing is possible but not
  scored, timed, or otherwise recognized by any system

---

## Game Pillars

### Pillar 1: Gravity is world state, not a player power

The room decides which way is down; the player reads it and reacts. Gravity is
never something the player character possesses independently — it is global,
broadcast state that every gravity-affected body in the level shares at once.
A flip must be legible from the room itself, not from a UI readout — the
world moving is the proof, not a number changing on the HUD.

*Design test*: if a proposed mechanic would let the player hold a personal
gravity distinct from the room's, or would let a prop disagree with the
player's gravity, this pillar rejects it (`gravity.md` R9). If a proposed
presentation would communicate a flip only through UI rather than through
the room's own physics and camera behavior, this pillar rejects that too.

### Pillar 2: Oxygen never refills

Every action — pouring, waiting, walking, a mistimed flip — spends the same
non-renewable clock. There are no pickups, checkpoints, or safe states that
restore it. The clock itself is not a difficulty dial the designer sets by
hand — `oxygen_capacity` is derived from the level's own bucket-to-plant
walked geometry, so the timer is always a direct readout of the route
chosen, never an arbitrary number.

The gardener spends their own finite air terraforming a room for whoever
comes next — the plants never give air back, and that is the point, not an
oversight to be patched with a pickup.

*Design test*: if a proposed feature would let the player regain oxygen mid-level
by any means other than restarting, this pillar rejects it (`suit-oxygen.md`
R2/R4). If a proposed feature would let a designer set `oxygen_capacity` by
hand rather than deriving it from the level's own route geometry, this
pillar rejects that too.

### Pillar 3: Every bucket is a commitment

A bucket is carried at reduced speed, holds exactly one pour, and is destroyed
on use. The routing order buckets are fetched in — not the reaching of any
single one — is the actual puzzle.

*Design test*: if a proposed feature would let the player carry more than one
bucket at a time, or would remove the carry speed penalty, this pillar rejects
it (`watering-system.md` R1/R2).

### Anti-Pillars (What This Game Is NOT)

- **NOT a combat game**: no health, weapons, or enemies exist anywhere in
  `src/` or the four GDDs. The only failure states are oxygen depletion and
  environmental hazards (spikes, kill areas).
- **NOT a physics sandbox**: physics props are explicitly cosmetic and forbidden
  from affecting solvability by construction (`physics-props.md` R1/R2) — this
  protects Pillar 1 and 3 from a mechanic that would let props become a fourth
  routing variable.
- **NOT a multiplayer or social game**: no networking, no co-op, no shared
  state across players exists or is planned in any current document.

---

## Inspiration and References

⚠ **TBD — not user-validated.** The row below is a structural comparison
only (shared mechanic), offered because no comparable-titles list has been
confirmed by the user. Do not use for marketing or positioning without review.

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| *VVVVVV* | Gravity flip as the core traversal verb | Gravity is diegetic world state shared with props and tied to a resource-management layer (buckets, oxygen), not a pure precision-platforming device | Validates that a single flip mechanic can carry a full game, if paired with a second system that gives it stakes |

**Non-game inspirations**: ⚠ **TBD** — none recorded in any existing document.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | ⚠ **TBD** — not specified |
| **Gaming experience** | Casual |
| **Time availability** | Short sessions, 10–20 minutes |
| **Platform preference** | PC, keyboard/mouse |
| **Current games they play** | ⚠ **TBD** — not specified |
| **What they're looking for** | A short, legible puzzle loop without a high skill floor — supported by the Standard accessibility tier already committed in `design/accessibility-requirements.md` (full remapping, one-hand presets, text scaling, elevated reduced motion) |
| **What would turn them away** | Motion sensitivity to the 0.6s viewport rotation on flip is the known dealbreaker case — this is why reduced motion was elevated above the Standard tier baseline (`accessibility-requirements.md` U16.1) rather than left at the default |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7.1 / GDScript — already the pinned engine (`docs/engine-reference/godot/VERSION.md`); no alternative was ever evaluated |
| **Key Technical Challenges** | Force-waking sleeping `RigidBody2D` props on every gravity change (`physics-props.md` R5, flagged as "the single most likely implementation bug in the system"); deriving `oxygen_capacity` from walked (not straight-line) path lengths (`watering-system.md` §4) |
| **Art Style** | 2D pixel (NES-influenced jump curve target, `gravity.md` §2; NES palette referenced in accessibility work, U8.15) |
| **Art Pipeline Complexity** | Low–Medium (custom 2D pixel art, no 3D pipeline) |
| **Audio Needs** | ⚠ **TBD** — zero audio files or `AudioStream` references exist anywhere in `src/` as of this writing |
| **Networking** | None |
| **Content Volume** | 8 levels currently exist in `src/scenes/levels/`; no level count target beyond that has been stated |
| **Procedural Systems** | None — all levels are hand-authored, and level oxygen budgets/bucket counts are hand-authored per the invariants in `systems-index.md` |

---

## Risks and Open Questions

### Design Risks

- No onboarding sequence exists — the first level currently has to teach
  gravity, carrying, and pouring simultaneously with no designed tutorial
  layer.
- No progression or retention system exists beyond the fixed 8-level sequence;
  unclear what brings a player back after level 8.

### Technical Risks

- `physics-props.md` R5 (force-waking sleeping props) is explicitly flagged in
  its own document as the bug most likely to ship broken.
- `TR-oxygen-006` (pause halts oxygen drain) currently has no owning ADR —
  neither ADR-0008 (owns `OxygenDrain`) nor ADR-0010 (owns HUD/pause routing)
  claims it, per `production/session-state/HANDOFF.md`.
- No settings/menu system exists at any level, but the accessibility tier
  already commits to four features that require one (remapping, one-hand
  presets, text scaling, reduced motion) — flagged as the largest gap in
  session 16.

### Market Risks

⚠ **TBD** — not assessable without a validated comparable-titles list (see
Inspiration and References above).

### Scope Risks

- `src/` has never been touched across the 16 sessions that produced the four
  system GDDs — all of gravity, watering, oxygen, and props as *designed*
  remain unimplemented against the current `player.gd`/`main.gd`/`gamemanager.gd`
  code, which still uses the pre-refactor `GameManager`-owned state the GDDs
  describe replacing (ADR-0002).
- Two documented but undesigned mechanics already ship in code with no GDD:
  wall jump (`player_wall_jump_component.gd`) and moving platforms
  (`moving_platform.gd`).

### Open Questions

- Whether a "session" means one level or several in sequence (Core Loop,
  Session-Level, above) — needs a decision before session-length claims in
  Core Identity can be treated as validated rather than estimated.
- Whether any retention or long-term progression system is wanted at all, or
  whether the 8-level arc is the intended full scope.

---

## MVP Definition

**Core hypothesis**: Flipping gravity to solve a bucket-routing puzzle under a
derelict-station oxygen budget is fun for a short session.

**Required for MVP** (per the four system GDDs, all drafted but not yet wired
into `src/`):
1. World-state gravity with zone-driven flips (`gravity.md`)
2. Single-use bucket delivery with carry penalty and held-input pour
   (`watering-system.md`)
3. Non-refilling, geometry-derived oxygen countdown (`suit-oxygen.md`)
4. At least one level authored to the bucket/oxygen invariants in
   `systems-index.md`

**Explicitly NOT in MVP**:
- Physics props (`physics-props.md` is Presentation-tier by its own
  classification — it "adds no mechanics, no failure states")
- Any onboarding, progression, or retention system (none currently designed)
- Audio (none exists)

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 level | Gravity + watering + oxygen + minimal oxygen readout, no props | 30–45 focused days |
| **Vertical Slice** | 1 level, polished | Core + props + full HUD build-out | +18–28 days on top of MVP |
| **Alpha** | 8 levels (existing scene count), placeholder art | All four systems wired | ⚠ TBD |
| **Full Vision** | 8 levels, polished | All features, accessibility tier fully implemented | ⚠ **1–3 months, solo — likely stale, see below** |

**MVP and Vertical Slice re-estimated 2026-08-17 (session 28)**, complexity-derived
— `production/` has no sprint or milestone history to calibrate against, so
treat the range width as real, not a formatting choice. At a ~7h focused-day,
30–45 days is 6–9 weeks full-time solo, or 4–6 months at an evenings/weekends
pace (~12h/week). The driver is not "wire the four GDDs into `src/`" — it is
landing 9 of the 12 Accepted ADRs first, several atomic (e.g. ADR-0001's
Changeset A and ADR-0007 have, in ADR-0001's own words, "no incremental
path"), plus a minimal HUD (an oxygen readout is required by `suit-oxygen.md`
R7's own edge-case table, not optional at MVP) and one fully re-authored
level. Vertical Slice adds the full HUD build-out (`hud.md` alone is 1,061
lines — longer than all four core system GDDs combined) plus ADR-0011 props
and a polish pass.

**Full Vision's "1–3 months, solo" figure predates all 12 ADRs** and is
flagged, not corrected, here: MVP alone is now projected to consume roughly
that entire budget, which suggests Full Vision needs its own re-estimate
before being treated as committed — out of scope for this pass, which was
asked for MVP and Vertical Slice only. Alpha remains TBD; it was not
re-estimated this session either.

---

## Next Steps

> **Creative Director Review (CD-PILLARS)**: CONCERNS (revised) 2026-08-16 —
> presentation clause added to Pillar 1, ludonarrative reading named and
> route-geometry protection added to Pillar 2, per `/gate-check pre-production`.

- [x] Get concept approval from creative-director
- [ ] Resolve all ⚠ TBD sections above — particularly session structure,
      retention systems, and comparable titles — before this document is
      cited as authoritative outside of gating the art bible
- [ ] Run `/art-bible` — this document exists specifically to unblock it
      (`production/session-state/HANDOFF.md` gate blocker 1)
- [ ] Create a game pillars document (`/design-review` to validate) — the
      three pillars above are currently only recorded here
- [ ] Assign an owner for `TR-oxygen-006` before writing ADR-0008 or ADR-0010
      (see Technical Risks above)
