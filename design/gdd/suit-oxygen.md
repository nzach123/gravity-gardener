---
status: draft
source: /brainstorm session 2026-08-13
depends-on: watering-system.md
date: 2026-08-13
amended: 2026-08-14 — §6 synced to ADR-0002 (OxygenState owned by the level root). No rule changed
---

# Suit Oxygen — Design

> **Status**: Complete draft — all 8 required sections authored and approved.
> Not yet validated with `/design-review`. Requires a HUD scene, which does not
> exist yet (R7, §5).

## 1. Overview

Suit oxygen is a per-level countdown that begins full on load and drains in real
time until the player reaches the airlock or dies. It is the pressure that gives
every other system its cost: a slow carried leg, a five-second pour lock, a
mistimed gravity flip and a wrong-order route all spend the same non-renewable
resource. Nothing in the level restores it.

The budget is not an independent difficulty dial. It is derived from the level's
own bucket layout via the `O_level` formula in `watering-system.md` §4, so a
level's timer is a consequence of how far its buckets sit from its plants.

> **Two oxygens — do not conflate.** *Suit oxygen* (this document) is the player's
> personal supply: it drains, it kills, and it never refills. *Room oxygen* is what
> a fully grown plant produces to open the airlock (`watering-system.md` R6). They
> never interact — a plant oxygenates the room only at full growth, the moment the
> level ends, so there is no window in which it could top up the suit.

## 2. Player Fantasy

The suit gauge is the one number the player cannot argue with. Gravity can be
re-read, a bad jump can be retried, a spilled pour costs only time — but the tank
only ever goes one direction.

The intended feeling is *budgeted urgency* rather than panic. The player should
spend the early part of a level thinking about route order and the late part
committed to it, aware that deliberation itself is being charged for. Standing
still to pour is the sharpest expression of this: the correct action and the
expensive action are the same action.

Death by oxygen should feel earned rather than ambushed — the player ought to know
roughly thirty seconds out that they are not going to make it, and to spend those
seconds trying anyway.

## 3. Detailed Rules

**R1 — Suit oxygen is a per-level countdown.** `oxygen_remaining` starts at
`oxygen_capacity` seconds on level load and decreases in real time. It is the
player's own supply, carried in the suit — distinct from the room oxygen a grown
plant produces.

**R2 — Drain is unconditional.** Pouring, wall-sliding, standing idle, airborne,
mid-gravity-transition — every state drains identically. There are no safe states
and no way to stall the clock. This is what makes the pour lock in
`watering-system.md` R3 cost something real.

**R3 — Zero oxygen is death.** On `oxygen_remaining <= 0` the player dies through
the existing death path (`main.gd` `restart_level`), making oxygen death
indistinguishable from spike or kill-area death in both handling and presentation.

**R4 — Nothing refills the suit.** There are no pickups, tanks, or recovery
mechanics. A fully grown plant oxygenates the *room* and opens the airlock; it does
not touch the suit. The only way to regain oxygen is to restart the level.

**R5 — Restart resets oxygen to full**, alongside all watering state. Oxygen never
carries between levels — each level is a fresh tank.

**R6 — The budget is derived, not guessed.** `oxygen_capacity` is authored from
`watering-system.md` §4's `O_level`, using walked path lengths rather than straight
lines. A level's timer is a consequence of its bucket layout, not an independent
dial. Changing where a bucket sits changes the level's oxygen budget — and so does
moving the exit, since `O_level` budgets the run from the final plant to the airlock
as well as the bucket deliveries (`d_exit`, added 2026-08-17).

**R7 — The readout is always visible**, with escalating feedback at fixed
thresholds (§4). The player must never be surprised by the tank running out.

## 4. Formulas

| Symbol | Meaning |
|---|---|
| `oxygen_capacity` | Starting tank, in seconds, authored per level |
| `drain_rate` | Global multiplier, default 1.0 |
| `t_level`, `margin` | From `watering-system.md` §4 |

```
oxygen_remaining -= drain_rate · delta
oxygen_capacity   = t_level · (1 + margin)
oxygen_fraction   = oxygen_remaining / oxygen_capacity
```

**Feedback thresholds** on `oxygen_fraction`:
nominal > 0.50 · caution ≤ 0.50 · warning ≤ 0.25 · critical ≤ 0.10

### Worked example

Continuing watering §4's level (3 buckets, 800 px each, `k` = 0.6, `w` = 5.0, so
`t_level` = 33.29 s):

```
oxygen_capacity = 33.29 × 1.4 = 46.6 s  →  authored as 48 s
caution   at 0.50 → 24.0 s remaining
warning   at 0.25 → 12.0 s remaining
critical  at 0.10 →  4.8 s remaining
```

### Why `drain_rate` stays at 1.0

At exactly 1.0, `oxygen_capacity` reads directly as wall-clock seconds — an
authored budget of 48 means 48 real seconds. Any other value silently decouples the
two and makes every level's authored number a lie. It exists as an **accessibility
hook** (lowering it grants more real time without touching level design) and must
not be used as a difficulty dial.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Oxygen reaches zero mid-pour | The pour resolves first, then the death check runs. The player still dies (mirrors `watering-system.md` §5) |
| Oxygen reaches zero on the frame the player enters the airlock | **Airlock entry wins** — the level completes. The player physically reached the door; punishing a frame-perfect success would be gratuitous |
| Oxygen reaches zero mid-gravity-transition | Death is immediate. The easing does not have to finish first |
| Player dies to a spike with oxygen remaining | Normal restart; oxygen resets to full like all other level state |
| Level restart | `oxygen_remaining` returns to `oxygen_capacity` |
| Level transition | Fresh tank. Nothing carries over (R5) |
| `oxygen_capacity` authored ≤ 0 | Mis-authored level — log an error at load, same class of failure as R8 in `watering-system.md` |
| Game paused | Drain halts. **No pause menu exists today** (only `start_menu.tscn`); when one is added, halting the drain is a requirement, not a nicety |
| HUD missing or not yet built | Oxygen still functions and still kills. This violates R7 and must not ship |

## 6. Dependencies

| Depends on | Relationship |
|---|---|
| `watering-system.md` | **Reciprocal.** Pour duration and bucket routing produce `t_level`, which sets this system's `oxygen_capacity` (R6). Watering §6 already declares the other direction |
| `gravity.md` | **No interaction by design.** Gravity transitions neither pause nor accelerate drain. Stated explicitly so it is not assumed otherwise |
| `OxygenState` *(RefCounted, new)* | Owns `capacity` and `remaining`. Constructed per level by the level root from its `oxygen_capacity` export and injected into consumers (ADR-0002). **Not** an autoload — it dies with the level, which is what gives R5 for free |
| `GameManager` | **No longer holds oxygen state.** Retains cross-level concerns only (ADR-0002) |
| `OxygenDrain` *(new)* | Drives `OxygenState.drain()` and owns the death *policy*, including the airlock-entry suppression in §5. `OxygenState.depleted` reports an empty tank and decides nothing |
| `main.gd` / level root | Constructs and injects `OxygenState`; wires oxygen death into the existing `restart_level` path |
| `spike_hazard`, kill area | Share that restart path — oxygen death must be indistinguishable |
| HUD *(new scene)* | Renders the readout and threshold feedback (R7) |
| `level-flow.md` | **Reciprocal.** Owns the death sequence that R3 requires be cause-agnostic, and the `level_complete` latch that §5's airlock-beats-zero-oxygen priority depends on. This document owns *what kills*; `level-flow.md` owns what a death and a completion then do |

## 7. Tuning Knobs

| Knob | Lives in | Default | Range | Affects |
|---|---|---|---|---|
| `oxygen_capacity` | Level root, per level | derived | — | The per-level difficulty dial. **Derived from `O_level`, never guessed** (R6) |
| `margin` | `OxygenTuning` resource | 0.4 | 0.3 – 0.6 | Slack over the theoretical minimum route. Below 0.3 any routing mistake is fatal; above 0.6 the timer stops mattering |
| `drain_rate` | `OxygenTuning` resource | 1.0 | 0.5 – 1.0 | **Accessibility hook only.** Leave at 1.0 so capacity reads as real seconds |
| `threshold_caution` / `_warning` / `_critical` | `OxygenTuning` resource | 0.50 / 0.25 / 0.10 | — | When escalating feedback fires |

## 8. Acceptance Criteria

| # | Criterion | Rule | Type |
|---|---|---|---|
| AC1 | `oxygen_remaining` decreases by `drain_rate · delta` every frame regardless of player state, **including mid-pour** | R2 | Logic |
| AC2 | Reaching zero triggers the identical restart path as spike death | R3 | Logic |
| AC3 | No game action increases `oxygen_remaining` | R4 | Logic |
| AC4 | Restart resets `oxygen_remaining` to `oxygen_capacity` | R5 | Logic |
| AC5 | Oxygen does not carry between levels | R5 | Integration |
| AC6 | With `drain_rate` = 1.0, an idle level survives exactly `oxygen_capacity` wall-clock seconds ±0.1 s | §4 | Logic |
| AC7 | Level load logs an error when `oxygen_capacity <= 0` | §5 | Logic |
| AC8 | Entering the airlock on the frame oxygen reaches zero completes the level | §5 | Integration |
| AC9 | HUD readout matches `oxygen_remaining` within 0.1 s | R7 | UI — advisory |
| AC10 | Threshold feedback fires at 50%, 25% and 10% | R7 | Visual — advisory |
