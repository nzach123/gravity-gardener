# Bug Fix: GravityZone Reduces Player Jump Height

**Date:** 2026-08-10
**Status:** Diagnosed, fix prescribed

---

## Problem

When the player enters a `GravityZone`, their peak jump height is reduced (or increased) instead of staying consistent with the designer-configured `jump_height`.

## Root Cause

`set_gravity()` in `player.gd` (lines 261–270) scales both `gravity_ascent_mag` and `jump_velocity` by the same multiplicative `scale_factor`:

```gdscript
var scale_factor: float = new_vector.length() / gravity_ascent_mag
gravity_ascent_mag  *= scale_factor
jump_velocity       *= scale_factor
```

However, jump height follows the kinematic equation:

$$h = \frac{v^2}{2g}$$

When both $v$ and $g$ are scaled by the same factor $s$, height scales by $s$ — it is **not** preserved:

$$h' = \frac{(s \cdot v)^2}{2 \cdot (s \cdot g)} = s \cdot \frac{v^2}{2g} = s \cdot h$$

### Concrete Example

| Variable | Default (no zone) | Zone (strength=980) |
|---|---|---|
| `gravity_ascent_mag` | ~2991 | 980 |
| `scale_factor` | — | 980/2991 ≈ 0.33 |
| `jump_velocity` | ~1469 | ~486 |
| **Effective jump height** | **200 px** | **~66 px** |

### Secondary Issue: Compounding Across Zones

Because `gravity_ascent_mag` is used as the divisor in `scale_factor` **and** is itself mutated by the multiplication, traversing multiple zones (A → B → C) compounds multiplicatively rather than rebasing to each zone's absolute strength.

---

## Fix

### Step 1: Store the ascent/descent ratio in `_ready()`

Add a variable to the runtime state section (near line 80):

```gdscript
var ascent_descent_ratio: float = 1.0
```

In `_ready()`, after the gravity computation block, add:

```gdscript
ascent_descent_ratio = gravity_ascent_mag / gravity_descent_mag
```

### Step 2: Rewrite `set_gravity()`

Replace the entire function body (lines 261–270) with:

```gdscript
func set_gravity(new_vector: Vector2) -> void:
    # GravityZone calls this to redirect gravity.
    # Set ascent magnitude to the zone's absolute strength,
    # then recompute descent magnitude and jump velocity to
    # preserve jump_height and the ascent/descent ratio.
    var new_mag := new_vector.length()
    if new_mag <= 0.0:
        return  # guard against zero-length gravity vectors
    gravity_ascent_mag  = new_mag
    gravity_descent_mag = gravity_ascent_mag / ascent_descent_ratio
    jump_velocity       = sqrt(2.0 * jump_height * gravity_ascent_mag)
    target_gravity      = new_vector
```

### Why This Works

- $h = \frac{v^2}{2g} \implies v = \sqrt{2gh}$ — for any given gravity magnitude, we compute the exact jump velocity needed to reach `jump_height`.
- The ascent/descent ratio is preserved, keeping the arcade-style "floaty up, snappy down" feel intact.
- The zone's `zone_gravity_strength` is treated as **absolute** — no more multiplicative compounding across multiple zones.
- `jump_height` remains the single designer-facing control for jump feel, regardless of gravity zone strength.

---

## Files Modified

- `_res/scripts/player.gd`
  - **Runtime state** (~line 80): Add `var ascent_descent_ratio: float = 1.0`
  - **`_ready()`** (~line 102): Add `ascent_descent_ratio = gravity_ascent_mag / gravity_descent_mag`
  - **`set_gravity()`** (lines 261–270): Complete rewrite as shown above

## Verification

1. **Math invariant**: After `set_gravity()`, `jump_velocity * jump_velocity / (2.0 * gravity_ascent_mag)` should always equal `jump_height`. Add a temporary `print()` to confirm.
2. **Visual test**: Place gravity zones with different strengths in a test level. The player's peak height above the ground should look identical in every zone.
3. **Multi-zone test**: Pass through zones A → B → C. Jump height should be consistent in each (no compounding).
4. **Edge case**: Ensure a zone with `zone_gravity_strength = 0` is safely ignored by the guard clause.

---

## Designer Note

A side effect of this fix: the `gravity_ascent_mag` now **becomes** the zone's `zone_gravity_strength`. The player no longer uses the internally-derived default (~2991); it inherits the zone's value. This means the zone's strength directly controls how "heavy" the player feels — lower values mean floatier physics across the board. The `jump_height` export remains the single-source-of-truth for peak height.
