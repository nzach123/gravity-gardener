# Architecture Review — 2026-08-15 (c)

Scope: `/architecture-review adr 08 and adr 09` — a targeted review of ADR-0008
(oxygen drain and shared death path) and ADR-0009 (watering interaction model),
both **Proposed**, checked against their declared dependencies (ADR-0002,
ADR-0004, ADR-0005, ADR-0006, ADR-0007 — all Accepted), the TR registry, the
conflict-gate registry (`docs/registry/architecture.yaml`), the owning GDDs
(`suit-oxygen.md`, `watering-system.md`, `accessibility-requirements.md`,
`physics-props.md`, `gravity.md`), and the pinned engine reference
(`docs/engine-reference/godot/`). Not a full 52-requirement review — see
`architecture-review-2026-08-15-b.md` for that.

Engine: Godot 4.7.1. Godot-specialist consultation performed (see Finding 1
and Finding 3).

## Traceability

**ADR-0008** claims TR-oxygen-001 / 002 / 003 / 004 / 006.

| TR | Status |
|---|---|
| 001, 002, 004 | ✅ Covered |
| 003 | ⚠ Partial — Finding 5 |
| 006 | ✅ Covered mechanically — Finding 3 (citation gap, not a correctness gap) |

**ADR-0009** claims TR-watering-001 / 002 / 003 / 004 / 005 / 009 / 010 / 016.

| TR | Status |
|---|---|
| 001, 004, 005, 009, 010, 016 | ✅ Covered |
| 002 | ❌ **Claimed covered, not actually covered** — Finding 2 |
| 003 | ⚠ Partial — Finding 4 |

## Findings, most severe first

### 1. BLOCKING — `Bucket.on_picked_up()` will raise a runtime error as written

ADR-0009 Decision §4:

```gdscript
func on_picked_up() -> void:
    monitoring = false
```

called synchronously from `_on_body_entered`, itself fired during
`PhysicsServer2D::flush_queries()`. Godot raises a runtime error
("Can't change this state while flushing queries...") when `Area2D`
monitoring state is mutated mid-flush; the engine's own sanctioned fix is
`set_deferred()`. Confirmed by godot-specialist consultation. As currently
written, ADR-0009's reference code — and its Migration Plan step 2, which
cites this method by name — would ship broken on first pickup.

**Fix**: `set_deferred("monitoring", false)` in `on_picked_up()`.

### 2. BLOCKING (traceability) — TR-watering-002 is claimed covered but has no implementation path

ADR-0009's GDD Requirements Addressed table and Consequences → Positive both
list TR-watering-002 (carry penalises `max_speed` only) as closed by this
ADR. Nothing in the Decision, Key Interfaces, or Migration Plan wires
`carrying_bucket` into `PlayerMovementComponent.apply()`. ADR-0007 froze that
method's signature —
`apply(delta, velocity, is_on_floor(), right_dir, up_dir, input_axis, camera_rotation_enabled)`,
no carry-state parameter — and ADR-0009 states explicitly it inherits
`Player._physics_process`'s shape (D7.3) unchanged.

`architecture.md:333`, itself amended by ADR-0007, still reads: *"no carry
multiplier yet — TR-watering-002 stays gap, owned by ADR-0009."* That line
was never updated by ADR-0009, and for good reason — nothing in ADR-0009
actually closes it. There is also no legal path for `PlayerMovementComponent`
to learn `carrying_bucket` under the current architecture:
`PlayerMovementComponent` is not a `level_state_injection` consumer
(`docs/registry/architecture.yaml`), and reaching `LevelState` any other way
hits the `global_level_state_access` forbidden pattern (ADR-0002).

**Fix**: either add a decision to ADR-0009 for how `carrying_bucket` reaches
`PlayerMovementComponent` (most likely a new parameter on `apply()`, which
means reopening ADR-0007's frozen D7.3 signature and needs its own sign-off),
or downgrade the claim and leave TR-watering-002 `gap`, explicitly flagged as
a follow-up the way ADR-0007 flagged it.

### 3. MEDIUM — ADR-0008's pause mechanism rests on an uncited engine fact

Decision §2 (TR-oxygen-006) depends entirely on `PROCESS_MODE_INHERIT`
resolving to `PROCESS_MODE_PAUSABLE` and `_physics_process` not running while
`SceneTree.paused`. Godot-specialist consultation **confirms this is correct,
stable Godot 4.x behaviour**, unaffected by any 4.4–4.7.1 change. But it
appears nowhere in `docs/engine-reference/godot/modules/core.md` (whose
"Processing order" section covers only `process_priority` /
`process_physics_priority`, not pause resolution), and ADR-0008's own Engine
Compatibility table says "Verification Required: None new" — inconsistent
with this project's otherwise meticulous citation discipline for load-bearing
Core facts (cf. ADR-0005 F1–F3, cited and gated with the same rigor).

**Fix**: add a "Processing / Pause" entry to `modules/core.md` citing the
`PROCESS_MODE_INHERIT`/`PROCESS_MODE_PAUSABLE`/`SceneTree.paused` mechanism,
and correct ADR-0008's Verification Required field to point at it.

### 4. MEDIUM — ADR-0009 silently drops the gesture-agnostic pour-abandonment requirement

`tr-registry.yaml`'s note on TR-watering-003 states: *"ADR-0009 must define
pour abandonment as GESTURE-AGNOSTIC. A toggle alternative to the hold is
committed in `design/accessibility-requirements.md` (Motor), so hold-release
and toggle-press must be the same event."* `accessibility-requirements.md`
T7 independently confirms: *"Pour toggle ... Blocked — owed to ADR-0009."*

ADR-0009 never mentions accessibility, toggle, or gesture-agnosticism
anywhere in its text, and its call site
(`watering_component.update_pour(delta, Input.is_action_pressed("interact"))`,
D7.3 step 2) reads the hold-input action directly and inline, with no
abstraction a future toggle handler could hook without editing this
"filled-in" slot again.

**Fix**: either specify the gesture-agnostic input source explicitly (e.g. a
toggle handler that drives `Input.action_press()`/`action_release()` so the
read at this call site stays uniform regardless of input scheme), or flag the
gap as an explicit follow-up the way ADR-0007 flagged TR-watering-002.

### 5. LOW / tracked — TR-oxygen-003 GDD conflict remains unresolved

`suit-oxygen.md` §5/R3 states oxygen death is "immediate"; ADR-0005 D5.2
(which ADR-0008 restates unchanged in Decision §1) defers it one physics
frame by design. Already tracked in `tr-registry.yaml` as an `open_item`,
severity `gdd_conflict`, "Unresolved." ADR-0008 — the ADR that formalizes
`OxygenDrain`'s exact frame behaviour — had the natural opportunity to close
this and does not mention it.

**Fix**: either revise `suit-oxygen.md`'s wording (a 16.6 ms deferral is what
is actually decided, "immediate" is no longer accurate), or have ADR-0008
carry an explicit narrowing note the way ADR-0005 D5.6 narrows an ADR-0002
precondition.

### 6. LOW — Migration Plan omission in ADR-0009

Reparenting `CollisionShape2D` under `Bucket`'s new `Area2D` root (the scene
restructure described in Decision §4 / Migration Plan step 2) requires
re-setting the shape's `owner` to the new root, or the edit silently fails to
persist. Standard Godot editor behaviour, not a hidden engine trap, but easy
to miss during a manual restructure and worth a line in the Migration Plan.

## Cross-ADR Conflicts

One conflict, covered above as Finding 2: ADR-0009 vs. `architecture.md`
(itself amended by ADR-0007) on whether TR-watering-002 is closed. Resolves
in `architecture.md`'s favor — it is not closed.

No data-ownership, performance-budget, or dependency-cycle conflicts found.
Both ADRs' declared dependencies (ADR-0002/0004/0005/0006/0007) are Accepted;
no unresolved or cyclic dependency.

## GDD Revision Flags

| GDD | Assumption | Reality | Action |
|---|---|---|---|
| `suit-oxygen.md` §5/R3 | Oxygen death is "immediate" | ADR-0005 D5.2 defers the kill one physics frame by design; ADR-0008 restates this unchanged | Revise `suit-oxygen.md` wording, or have ADR-0008 record the narrowing explicitly (Finding 5) |

## Engine Compatibility Issues

- ADR-0008: `PROCESS_MODE_INHERIT`/`PROCESS_MODE_PAUSABLE` claim confirmed
  correct but uncited (Finding 3).
- ADR-0009: `Area2D.monitoring` mutation during `flush_queries()` needs
  `set_deferred()` (Finding 1).
- No other engine-specific issues found in either ADR's use of
  `process_physics_priority`, detector layers, or `move_and_slide()` —
  confirmed by godot-specialist consultation.

## Verdict: CONCERNS

Neither finding breaks Foundation-layer architecture — both ADRs' dependency
chains are sound. But Finding 1 is a shipped-broken code sample and Finding 2
is a false coverage claim that will surface as a real implementation bug.
Neither ADR should move to Accepted as currently drafted.

### Blocking issues (must resolve before Accepted)

1. Fix `Bucket.on_picked_up()` to use `set_deferred()` (Finding 1).
2. Resolve the TR-watering-002 gap — implement or explicitly re-flag as `gap`
   (Finding 2).

### Recommended, non-blocking

3. Cite the PROCESS_MODE fact in `core.md`; correct ADR-0008's Verification
   Required field (Finding 3).
4. Address or explicitly flag the gesture-agnostic pour-abandonment gap
   (Finding 4).
5. Resolve or narrow the TR-oxygen-003 "immediate" vs. deferred-kill wording
   (Finding 5).
6. Note the `CollisionShape2D` owner reassignment step in the Migration Plan
   (Finding 6).
