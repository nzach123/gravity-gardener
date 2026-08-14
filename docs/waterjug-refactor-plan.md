# WaterJug Refactor Plan — Carry Logic to Player Component

**Date:** 2026-08-13
**Status:** Ready for implementation
**Design source:** [`design/gdd/watering-system.md`](../design/gdd/watering-system.md)
**Change:** #6 of the 7-change design pass

---

## 0. Summary

Carry and watering logic is currently spread across three scripts and coordinated
through global mutable state on `GameManager`. `PlayerWateringComponent` exists but
holds only a bool and is bypassed.

This refactor moves ownership to the player component and the level root, per
`watering-system.md` §6. **It is a prerequisite for the bucket economy** — `main.gd`
holds a single `@export var bucket: Bucket`, which cannot represent N buckets.

---

## 1. Current State

### 1.1 Where carry logic lives today

| Location | Responsibility | Problem |
|---|---|---|
| `main.gd:4` | `@export var bucket: Bucket` — one hardcoded reference | **P1** Blocks N buckets entirely |
| `main.gd:46-49` | Positions the bucket to `HandMarker` every `_process` frame | **P2** The level drives player-owned presentation |
| `main.gd:50-52` | Hides the bucket when `carrying == false and goal_unlocked` | **P2** Ad-hoc lifecycle, replaced by per-bucket consumption |
| `bucket.gd:4-7` | Sets `GameManager.carrying_bucket = true` on body entry | **P6** Declares `extends Node` while being given a transform |
| `plant.gd:30` | Reads `GameManager.carrying_bucket` to gate pouring | **P3** Plant reaches into global state for player state |
| `plant.gd:73-79` | Increments counters and decides `goal_unlocked` | **P3** A single plant decides whether the room is breathable |
| `plant.gd:31, 83, 91` | Writes `player_in_range.is_watering` directly | **P4** Bypasses `PlayerWateringComponent` entirely |
| `gamemanager.gd` | `reset_level_state()` omits `carrying_bucket` | **P5** Phantom bucket survives death (`watering-system.md` §5) |
| `player_watering_component.gd` | `lock()` / `unlock()` | **P7** Exists, but nothing calls it |

### 1.2 Consequences

- **P1** is blocking. Nothing in the bucket economy can be built until it is fixed.
- **P5** is a live defect today and becomes a correctness bug under `R1` — a
  phantom bucket corrupts the level's supply count and breaks `R8`.
- **P3/P4** mean the plant is the de facto owner of player state, goal state, and
  level state. `R6` explicitly reassigns the unlock decision to the level.

---

## 2. Target Architecture

### 2.1 Ownership after the refactor

| Owner | Responsibility |
|---|---|
| `PlayerWateringComponent` | Held-bucket reference, pickup/refusal, carry transform, pour progress, target selection, input handling |
| `PlayerMovementComponent` | Applies `carry_speed_multiplier` while carrying (`R2`) |
| `Plant` | Passive target. Reports capacity, receives a completed pour, drives its own growth visuals. **Touches no global state** |
| `Bucket` | Own pickup area, consumption, throw-and-free (`R7`) |
| Level root (`main.gd`) | Owns `buckets_total` / `buckets_consumed`, the `R8` load validation, and the airlock unlock decision |
| `GameManager` | Level state container only. Resets **all** of it, carry included |

### 2.2 The key inversion

Today the **plant** drives the pour: it reads input, accumulates progress, and
writes player state. After the refactor the **player component** drives the pour and
the plant is a passive target.

This follows from `watering-system.md` R3 — the pour requires carry state and input,
both of which the player owns — and from §5, where the pour must select the *nearest
plant with remaining capacity*. Target selection is impossible from inside a single
plant.

```
PlayerWateringComponent                 Plant
  ├── holds bucket ref                    ├── can_receive() -> bool
  ├── tracks water_progress               ├── receive_pour()
  ├── selects nearest plant  ────────────→└── growth visuals only
  └── on complete: consume + notify level
```

### 2.3 Carry transform

Replace the per-frame write in `main.gd:46-49`. The bucket follows `HandMarker`
through a `RemoteTransform2D` or by reparenting on pickup — either keeps the
relationship inside the player's scene tree instead of in the level's `_process`.

---

## 3. External Contracts

### 3.1 Preserved

| Contract | Note |
|---|---|
| `Goal` / `goal.gd` | **No changes.** Continues to watch `GameManager.goal_unlocked` (`R6`) |
| `player.set_gravity()` | Untouched |
| `gravityzone` group → `gravity_changed` | Untouched |
| `interact` input action (E) | Untouched |
| `player_died` | Still read for the mid-pour safety path (`plant.gd:23`) |

### 3.2 Changed

| Contract | Before | After |
|---|---|---|
| `main.gd` bucket access | `@export var bucket: Bucket` | Group lookup (`buckets`) |
| `GameManager.carrying_bucket` | Global bool, written by `bucket.gd` and `plant.gd` | Replaced by the component's held-bucket reference |
| `GameManager.plants_watered` / `plants_total` | Counters gating the goal | Replaced by `buckets_consumed` / `buckets_total` |
| `plant.is_watered` | Bool | `buckets_received` / `buckets_required` (`R5`) |
| Goal unlock decision | `plant.gd:76-79` | Level root (`R6`) |

---

## 4. Migration Steps

Ordered so the project stays runnable between steps.

1. **Fix `bucket.gd`'s base class.** `extends Node` → the type actually matching
   the scene root. Isolated, no behaviour change. *(P6)*
2. **Fix `reset_level_state()`** to clear carry state. One line, fixes a live
   defect independent of everything else. *(P5)*
3. **Move carry state into `PlayerWateringComponent`.** Held-bucket reference plus
   pickup/refusal (`R1`). `GameManager.carrying_bucket` becomes a read-through, not
   yet removed. *(P7)*
4. **Move the carry transform** out of `main.gd:46-49` into the player scene.
   Delete the `_process` block. *(P2)*
5. **Invert pour ownership.** Move progress and input from `plant.gd` to the
   component; reduce `Plant` to `can_receive()` / `receive_pour()`. *(P3, P4)*
6. **Replace the single bucket reference** with a group lookup; convert plant
   counters to `buckets_consumed` / `buckets_total` on the level root. *(P1)*
7. **Add the `R8` load validation** and error logging.
8. **Add `carry_speed_multiplier`** to `PlayerMovementComponent` (`R2`).
9. **Add consumption, throw and free** to `Bucket` (`R7`).
10. **Remove the dead `GameManager` fields** once nothing reads them.

Steps 1–2 are independent bug fixes and can land on their own.

---

## 5. Test Plan

Tests to write alongside, from `watering-system.md` §8:

| Step | Guards | Criterion |
|---|---|---|
| 2 | P5 | AC8 — restart clears carry, all buckets present, growth reset |
| 3 | R1 | AC5 — never holds two buckets |
| 5 | R3, R4 | AC2, AC3 — pour completes / early release refunds |
| 5 | §5 | AC12 — nearest plant with capacity receives the pour |
| 6 | R6 | AC6 — unlock fires exactly at `buckets_consumed == buckets_total` |
| 7 | R8 | AC7 — mis-authored level logs an error |
| 8 | R2 | **AC1 — speed scales, jump apex unchanged** |
| 9 | R7 | AC10 — jug freed within `throw_duration + 0.1 s` |

**AC1 is the load-bearing test** — it guards `gravity.md` R5 and doubles as that
document's AC11.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| All 8 levels use the old one-bucket economy | Levels need bucket placement reworked to satisfy `R8`. Not covered by this plan |
| `plant.gd` currently drives pouring from `_process` with direct player writes | Step 5 is the largest single step; land steps 1–4 first so it is the only moving part |
| `debugger.gd` may read fields this refactor removes | Audit before step 10 |
| Reparenting vs `RemoteTransform2D` for carry | Either works; pick one and keep it consistent with how the player scene already handles `HandMarker` |
