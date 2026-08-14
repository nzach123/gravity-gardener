---
status: reverse-documented, amended
source: src/scripts/components/player_gravity_component.gd, src/scripts/gravity_zone.gd
date: 2026-08-13
amended: 2026-08-13 — R9 (gravity as world state) and R10 (carry affects speed only) added
amended: 2026-08-14 — §5/§6/§7 synced to ADR-0001 (GravityAuthority ownership). No rule changed; §5 init-order hazard deliberately retained per ADR-0001 part 7
verified-by: nzach123
---

# Gravity System — Design

> **Note**: Reverse-engineered from the existing implementation. Captures current
> behavior plus clarified intent. Sections marked ⚠ describe intended design that
> the code does not yet match.

## 1. Overview

Gravity is a per-room 2D vector the player rewrites by entering a Gravity Zone.
It has both a direction (any angle; vertical and horizontal flips are the
designed cases) and a strength. Direction determines which surface is "the
floor" and rotates the player's whole frame of reference. Strength determines
how high the player can jump and how fast they fall. Zones act as *setters*:
gravity persists unchanged after the player leaves, until the next zone
overwrites it. Gravity is **world state, not player state**: when a zone fires,
the new vector applies to every gravity-affected body in the level — the player
and all rigid props alike.

## 2. Player Fantasy

An astronaut aboard a derelict ship where "down" is a property of the room, not
the universe. Rooms are read as spatial puzzles — the player looks at a chamber
and asks "which way will I fall here, and can I reach that ledge once I do?"
Reorientation should feel like the ship asserting itself, not like a camera
trick: the swap is smooth enough to track but fast enough to be decisive.

Jump feel targets the Super Mario Bros. (NES) curve — a floaty rise and a
notably harder fall, with height controlled by how long the button is held.

## 3. Detailed Rules

**R1 — Gravity is a vector.** Stored as `Vector2`. `up_dir` is its negation
normalized; `right_dir` is `up_dir` rotated 90° (`Vector2(-up_dir.y, up_dir.x)`).
All movement, jump, and animation math is expressed in this basis, so the system
works at any gravity angle.

**R2 — Zones are setters, not fields.** Entering a Gravity Zone emits its vector
once via `body_entered`. There is no exit handler. Gravity persists after the
player leaves and changes only when another zone is entered. Rooms own gravity;
the player carries the last room's gravity into untagged space. The change is
broadcast **globally**: every gravity-affected body adopts the new vector at once,
regardless of where it sits in the level. There is no per-body or per-region
gravity.

**R3 — Direction eases, strength snaps.** On a change, gravity direction rotates
toward the target via `lerp_angle` at 32 rad/s-scaled rate. Strength applies
immediately.

**R4 — Gravity is asymmetric.** Ascent uses a weaker magnitude than descent. The
ratio between them is fixed at startup and preserved across every zone change,
so the rise/fall character stays constant even as absolute strength varies.

**R5 — Jump velocity is fixed.** Launch velocity is derived once at startup and
never changes. Because height is `v² / 2g`, jump height therefore varies
inversely with zone gravity strength — low-gravity rooms are reachable, heavy
rooms are not. This is the primary traversal puzzle lever.

**R6 — Variable jump height.** Releasing jump while still ascending cuts upward
velocity to `min_jump_velocity`, allowing short hops.

**R7 — Zone strength is a multiplier.** Zones declare
`zone_gravity_multiplier` — a multiple of the derived baseline — rather than an
absolute px/s². `1.0` is baseline, `0.5` halves gravity and doubles jump reach,
`2.0` does the inverse. Zones therefore stay correct when jump tuning changes.
A non-positive multiplier or zero-length direction is rejected outright.
*Superseded:* `zone_gravity_strength` was an absolute defaulting to `980.0`, a
placeholder meant to represent 9.80 m/s² that did not match the baseline the
jump is tuned against.

**R8 — Overlapping zones are unresolved. ⚠** `zone_priority` is exported but
never read. Behavior is last-entered-wins. Level design must not rely on
overlap until this is implemented.

The global-broadcast decision in R9 keeps this parked. Because there is only ever
one gravity value in play, overlapping zones stay a last-entered-wins *ordering*
question rather than a spatial-resolution one. Had props been regional,
`zone_priority` would have become blocking.

**R9 — Gravity is world state. ⚠** Rigid props (tables, chairs, boxes) share the
single gravity vector with the player. When gravity flips up, unsecured props fall
upward. Props do not have their own gravity and cannot disagree with the player's.
See `physics-props.md` for prop behaviour; this rule only establishes that one
vector governs everything.

**R10 — Carried mass does not affect gravity or jump. ⚠** Carrying a bucket
penalises movement speed only. Gravity strength, `jump_velocity`, coyote time and
jump buffer are untouched, so R5 holds unconditionally. See R2 of
`watering-system.md`. *Rationale:* R5 is what lets level design prove a gap is
crossable from the zone multiplier alone. A carry-based jump penalty would add a
second independent lever and destroy that guarantee.

## 4. Formulas

Derived once at startup, where `h` = `jump_height`, `d_peak` =
`jump_distance_to_peak`, `d_land` = `jump_distance_to_land`, `s` = `max_speed`:

```
t_up    = d_peak / s
t_down  = d_land / s
g_ascent  = 2h / t_up²
g_descent = 2h / t_down²
v_jump    = 2h / t_up
ratio     = g_ascent / g_descent = (d_land / d_peak)²
```

On zone change, given zone multiplier `m` and baseline `g_ascent₀`:

```
g_ascent  = g_ascent₀ · m
g_descent = g_ascent / ratio
v_jump    = unchanged                    (R5)
height    = v_jump² / (2 · g_ascent)
```

Per frame, while airborne:

```
ascending = velocity · (-ĝ) > 0
g_applied = g_ascent if ascending else g_descent
velocity += ĝ · g_applied · Δt
```

Direction easing:

```
angle = lerp_angle(angle(g), angle(g_target), clamp(32 · Δt, 0, 1))
```

**Current values** (`h`=200, `d_peak`=128, `d_land`=80, `s`=350):
`t_up`=0.3657 s, `t_down`=0.2286 s, `g_ascent`=2990.72, `g_descent`=7656.25,
`v_jump`=1093.75, `ratio`=0.390625 (1:2.56).

**Reach by multiplier:** `0.5×` → 400 px · `1.0×` → 200 px · `2.0×` → 100 px.

**Mario-curve target:** ratio 0.286 (1:3.5), reached by setting
`d_land = 128 · √0.286 ≈ 68`.

## 5. Edge Cases

| Case | Behavior |
|---|---|
| Zone emits zero-length direction | `set_gravity()` returns early; gravity unchanged |
| Zone multiplier ≤ 0 | Rejected; gravity unchanged. Prevents a mis-authored zone from cancelling or inverting gravity |
| `set_gravity()` before `initialize()` | `ratio` is still 1.0, so descent equals ascent and asymmetry is lost. Initialization order is load-bearing |
| Overlapping zones | Last entered wins (see R8) |
| Player leaves all zones | Gravity persists (see R2) |
| Gravity flips mid-jump | Velocity is preserved in world space, so upward motion becomes downward relative to the new frame. Intended: the swap should feel like being *caught* by the new floor |
| Mid-transition input | `up_dir`/`right_dir` follow the easing direction, so controls rotate continuously rather than snapping |
| Gravity magnitude easing | Only direction eases; magnitude snaps. Every consumer reads `gravity.normalized()`. The dead `move_toward` magnitude easing is removed by ADR-0001 when the ease moves to `GravityAuthority` |
| Prop and player in different zones | No conflict — R9 means one global vector. The most recently entered zone governs everything |
| Player carrying a bucket | Speed reduced; gravity, jump velocity and jump height all unchanged (R10) |

## 6. Dependencies

- **PlayerMovementComponent** — consumes `right_dir`; owns `max_speed`, an input to every gravity formula
- **PlayerJumpComponent** — receives `jump_velocity`; owns coyote/buffer/min-velocity
- **PlayerVisualComponent** — rotates sprite to gravity; must mirror movement's axis inversion exactly
- **GravityAuthority** *(autoload)* — owns the gravity vector, the ease, and the
  ascent/descent ratio; sole writer. Emits `gravity_changed` to every consumer
  (ADR-0001)
- **GravityZone** — *declares* a direction and multiplier and reports them to
  `GravityAuthority.set_gravity()`. It does not own or change gravity itself
- **main.gd** (`LevelRoot`) — wires zones to `GravityAuthority`, and camera
  rotation to `GravityAuthority.gravity_changed`. `Player.set_gravity()` no longer
  exists (ADR-0001)
- **Watering System** (`watering-system.md`) — consumes `max_speed` via
  `carry_speed_multiplier`; must not affect jump velocity (R5/R10)
- **Physics Props** (`physics-props.md`) — consumes the global gravity vector; all
  rigid props adopt zone changes (R9)
- **Level design** — reachability depends on per-room strength once R5 lands

## 7. Tuning Knobs

| Knob | Current | Notes |
|---|---|---|
| `jump_height` | 200.0 | Height at 1.0× gravity |
| `jump_distance_to_peak` | 128.0 | Sets ascent time |
| `jump_distance_to_land` | 80.0 | Sets fall snappiness; → 68 for Mario curve |
| `max_speed` | 350.0 | Feeds all gravity derivation |
| `min_jump_velocity` | 100.0 | Short-hop floor |
| `coyote_time` | 0.12 | |
| `jump_buffer_time` | 0.15 | |
| `zone_gravity_multiplier` | 1.0 | Per-zone; 0.5 = double reach, 2.0 = half |
| `direction_ease_rate` | 32.0 | Exported on `GravityAuthority` (ADR-0001) |
| `zone_priority` | 0 | ⚠ not implemented (R8) |

> `carry_speed_multiplier` is consumed by this system through `max_speed`, but is
> **owned by `watering-system.md`** and is not tunable here.

## 8. Acceptance Criteria

- [ ] AC1 — At 1.0× gravity, peak height is 200 px ±2 px
- [ ] AC2 — Descent time to ground is shorter than ascent time by the configured ratio ±5%
- [x] AC3 — At 0.5× gravity, peak height is 400 px ±4 px; at 2.0×, 100 px ±2 px *(unit-tested; not yet verified in-game)*
- [ ] AC4 — `ascent_descent_ratio` is unchanged after any sequence of zone changes
- [ ] AC5 — Gravity direction completes a 90° rotation within 100 ms and is monotonic
- [ ] AC6 — Player leaving a zone retains that zone's gravity indefinitely
- [ ] AC7 — A zero-length zone vector leaves gravity unchanged
- [ ] AC8 — Under horizontal gravity, sprite facing matches travel direction
- [ ] AC9 — Releasing jump during ascent caps upward velocity at `min_jump_velocity`
- [ ] AC10 — All of AC1–AC9 hold at gravity angles of 0°, 90°, 180°, 270°
- [ ] AC11 — Carrying a bucket leaves jump apex height unchanged at every zone
      multiplier *(reciprocal of `watering-system.md` AC1; one test satisfies both)*
- [ ] AC12 — All rigid props adopt a new gravity vector on the same frame the
      player does
