# Architecture Review — Post-ADR-0007 Full Pass

> **Date**: 2026-08-15 (session 18)
> **Mode**: `/architecture-review` (no argument — full review, Phases 1–9)
> **Engine**: Godot 4.7.1 (GL Compatibility, 2D)
> **GDDs reviewed**: 4 (`gravity.md`, `watering-system.md`, `suit-oxygen.md`, `physics-props.md`) + `systems-index.md` + `game-concept.md`
> **ADRs reviewed**: 7 (ADR-0001 … ADR-0007) — **all Accepted**
> **Also loaded**: `architecture.md`, `docs/registry/architecture.yaml`, `docs/architecture/tr-registry.yaml`, 4 engine reference files, `HANDOFF.md`
> **Verdict**: **CONCERNS**

Supersedes `architecture-review-2026-08-15.md` (session 17, written before ADR-0007 existed — 6 ADRs, all Proposed, 0/52 covered). This session was run independently of any ADR-authoring session, per the project's standing rule.

`docs/consistency-failures.md` does not exist — no reflexion log was read and none was appended.

---

## Traceability Summary

Read from `docs/architecture/tr-registry.yaml` and cross-checked by recount against every ADR's "GDD Requirements Addressed" table — the registry's own totals are correct and needed no changes.

| Status | Count | % |
|---|---|---|
| ✅ Covered by an Accepted ADR | 28 | 54% |
| ❌ Gap — assigned to an unwritten ADR | 21 | 40% |
| ❌ Gap — **unowned**, assigned to no ADR | 1 | 2% |
| ◻ Parked by GDD design | 1 | 2% |
| ◻ Implemented, no ADR required | 1 | 2% |
| **Total** | **52** | **100%** |

ADR-0007 moved 6 requirements gap → covered this session cycle (`TR-gravity-004/005/006/007/013`, `TR-watering-014`) and one was reassigned, not closed (`TR-watering-002`: ADR-0007 → ADR-0009, corrected in the registry in place per its own convention).

**Foundation and Core layers are fully covered.** All 7 Accepted ADRs (0001–0007) between them close every Foundation- and Core-tier requirement. Every remaining gap belongs to Feature or Presentation-tier work (ADR-0008 through ADR-0012), which is exactly what `architecture.md`'s own acceptance ordering predicted.

---

## Coverage Gaps (no ADR exists)

Grouped by the unwritten ADR each is assigned to (`architecture.md` § Required ADRs):

**ADR-0008 — Oxygen drain and the shared death path** (4 requirements)
- `TR-oxygen-001` drain source · `TR-oxygen-002` unconditional drain · `TR-oxygen-003` death via shared restart path · `TR-oxygen-004` nothing refills
- Domain: Core/Feature · Engine Risk: LOW (composes ADR-0002/0005 patterns already verified)

**🔴 Unowned — blocks ADR-0008** 
- `TR-oxygen-006` — "pause halts drain." **No ADR claims this.** `architecture.md` QQ-04 routes it to ADR-0010 (HUD scope); the node that must consult pause state is `OxygenDrain`, which ADR-0008 owns. Neither claims it. This is unchanged since session 16/17 — flagged again because it is the one item that actually blocks forward progress: writing ADR-0008 without resolving this leaves a load-bearing requirement to slip through the cracks a second time.

**ADR-0009 — Watering interaction model** (8 requirements)
- `TR-watering-001/002/003/004/005/009/010/016`
- Domain: Feature · Engine Risk: LOW · Inherits ADR-0007's D7.3 watering-lockout call order and D5.5's `_physics_process` clock migration without re-deriving either (both ADRs say so explicitly)

**ADR-0010 — HUD architecture** (4 requirements)
- `TR-watering-017/018`, `TR-oxygen-007/009`
- Domain: Presentation · Engine Risk: MEDIUM (`Control.offset_transform_*` is new in 4.7 — `architecture.md`'s Engine Knowledge Gap Summary already verified the two defaults that matter: `offset_transform_visual_only` defaults `true`, `offset_transform_enabled` defaults `false`)

**ADR-0011 — Physics props implementation** (4 requirements)
- `TR-props-003/005/006/008`
- Domain: Physics/Presentation · Engine Risk: LOW, contingent on the two new findings below being resolved first

**ADR-0012 — Spent jug throw and lifetime** (1 requirement)
- `TR-watering-007`
- Domain: Feature · Engine Risk: LOW

---

## Cross-ADR Conflicts

No blocking conflicts among the 7 Accepted ADRs. All conflicts found by the session-17 review (C1–C6) are already resolved and recorded via the registry's `corrected:` convention. Two new items surfaced this session — one from my own read, one from the engine-specialist consultation below — neither is a conflict *between* two ADRs so much as a gap in how ADR-0001's own parts compose with ADR-0003's step reordering.

### New finding 1 — architecture.md is stale relative to ADR-0007

Unlike ADR-0002, ADR-0003 and ADR-0005 — each of which added an inline amendment note to `architecture.md` when it deviated from or corrected the blueprint — **ADR-0007 added no such note**, and `architecture.md` was never updated:

1. `architecture.md:757` (Required ADRs table) still lists ADR-0007 as covering `TR-watering-002/014`. `TR-watering-002` was reassigned to ADR-0009 in the same session ADR-0007 was accepted (`tr-registry.yaml`'s `corrected:` field) — ADR-0007's own "GDD Requirements Addressed" table says plainly it does **not** close this requirement.
2. `architecture.md`'s Core Layer module table (`PlayerGravityComponent` row) still says it exposes `up_dir`, `right_dir` and consumes `GravityAuthority.gravity_changed`. ADR-0007 D7.2 removes both — the component's surface shrinks to `initialize()` / `jump_velocity` / `apply_gravity()`, and D7.1 establishes that `Player` reads `GravityAuthority`'s fields directly every frame, with no signal subscription needed for that purpose.
3. `architecture.md`'s API Boundaries § Foundation code block for `GravityAuthority` does not show the `apply_camera_relative_axis` static method ADR-0007 D7.4 adds.
4. `architecture.md`'s Event/signal path table still lists `gravity_changed → PlayerGravityComponent` as if that were how the player consumes gravity.

**Route through `/propagate-design-change` — do not hand-edit** (standing instruction). This is a new, ADR-0007-specific addition to the punch list `HANDOFF.md` already carries for `architecture.md` (which listed 3 pre-existing "no ADRs exist" assertions plus the `:108` carry-indicator row — none of those four items is this one).

### New finding 2 — GravityAuthority.reset_to() may never write physics-space gravity for props (engine specialist QUESTION, CONFIRMED-shape)

ADR-0001 part 4a gates the per-frame `PhysicsServer2D.area_set_param` rewrite on `gravity != target_gravity` — i.e. only while actively easing. Part 6's `reset_to()`, called from `LevelRoot._ready()` on both first load and restart, almost certainly **snaps** `gravity` and `target_gravity` to the same value immediately (a visible ease on scene appearance would itself be a bug — nothing in the ADR says level load should show a gravity animation). If so, `reset_to()` never satisfies part 4a's "while easing" condition, and the physics-server space write is **skipped entirely on every level load and restart**. Since a `Viewport`'s `World2D` (and its physics-space RID) persists across `reload_current_scene()` and `change_scene_to_packed()`, props would read whichever gravity value the physics server was last told — the *previous* level's, or the engine default — until the first real zone-triggered change in the new level. This silently violates `gravity.md` AC12 for props specifically on the frame(s) immediately after any restart or level transition, and no ADR reasons about parts 4a and 6 together.

This can't manifest in `src/` today (Changeset B — parts 4/4a/4b — is deferred to ADR-0011's implementation, and `GravityAuthority` doesn't exist in `src/` yet), but it is a real design gap that ADR-0011 will inherit unless resolved first. `gravity.md` AC12's existing headless test (V6 in ADR-0001's Validation Criteria) only asserts the `gravity` *field*, not that the physics-server space param was actually rewritten — so this gap would not be caught by the tests already specified.

### New finding 3 — camera may miss the level's first gravity broadcast (engine specialist QUESTION)

ADR-0003 D3.1's corrected init order puts `GravityAuthority.reset_to()` (**"→ first broadcast"**) at step (e), and "wire zones → GravityAuthority; register props → GravityAuthority" at step (f) — strictly after. ADR-0001's Migration Plan step 5 bundles the camera's subscription to `gravity_changed` in with "connect zones to the authority" — i.e. the same wiring pass. If the camera's `connect()` call happens at step (f), it is not yet subscribed when step (e)'s first broadcast fires, and the camera would render unrotated on every level load until the first subsequent zone-triggered change corrects it. No ADR states whether the camera independently reads `GravityAuthority.gravity` once at its own `_ready()` as a fallback, or relies solely on the signal.

**Recommendation for both new findings**: resolve before or during ADR-0011 (props) and whichever ADR implements the camera-rotation wiring (currently unassigned — see `TR-gravity-010`'s existing open item on the `camera_moving`/`camera_rotation_enabled` decouple). Neither blocks anything Accepted today; both would silently break behavior the first time this code is actually written.

---

## ADR Dependency Order

All 7 Accepted ADRs have all their declared dependencies satisfied — no unresolved dependencies, no cycles.

```
Foundation (no dependencies):
  ADR-0001  Gravity ownership and global broadcast
  ADR-0002  Level state ownership and injectable state objects
  ADR-0004  Collision layer allocation
  ADR-0006  Tuning resource strategy

Depends on Foundation:
  ADR-0003  Level load validation contract      (requires ADR-0001, ADR-0002)
  ADR-0005  Frame ordering and level_complete    (requires ADR-0002)

Depends on the above:
  ADR-0007  Player component contract            (requires ADR-0001, ADR-0005)
```

For the unwritten ADRs, every prerequisite they name is already Accepted — nothing blocks any of them on ordering grounds:

```
  ADR-0008  Oxygen drain and death path    (requires ADR-0002 ✅, ADR-0005 ✅, ADR-0006 ✅ — but see 🔴 unowned finding above)
  ADR-0009  Watering interaction model     (requires ADR-0002 ✅, ADR-0005 ✅, ADR-0006 ✅, ADR-0007 ✅)
  ADR-0011  Physics props implementation   (requires ADR-0001 ✅, ADR-0004 ✅, ADR-0006 ✅ — but see new findings 2/3 above)
  ADR-0010  HUD architecture               (requires ADR-0002 ✅; admits `hud` to V-WIRING's required set on acceptance)
  ADR-0012  Spent jug throw                (requires ADR-0006 ✅)
```

---

## GDD Revision Flags (Architecture → Design Feedback)

One flag, already tracked as an `open_item` in `tr-registry.yaml` (`TR-oxygen-003`) but never resolved or reflected in `systems-index.md`'s status column — this is exactly the case Phase 5b exists to surface formally.

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|---|---|---|---|
| `suit-oxygen.md` | R3 / §5 state oxygen death is **"immediate."** §5: *"Oxygen reaches zero mid-gravity-transition → Death is immediate."* | **ADR-0005 D5.2** deliberately defers the kill by one physics frame (the "armed death" mechanism) — this is what reconciles `suit-oxygen.md` AC8 with `watering-system.md` AC13. The deferral is load-bearing, not a bug to fix. | Revise GDD |

No other GDD assumption conflicts with a verified engine behavior or an Accepted ADR. (`TR-oxygen-009`'s internal tension — §2's "thirty seconds out" vs §4's 24s-of-48s caution threshold — is a GDD-internal inconsistency, not an engine/ADR conflict, so it's out of scope for this phase; it's already tracked in the registry.)

---

## Engine Compatibility Issues

### Base audit
- Engine: Godot 4.7.1, GL Compatibility, 2D — consistent across all 7 ADRs.
- ADRs with Engine Compatibility section: **7/7**.
- No deprecated-API references in any ADR (checked against `deprecated-apis.md`'s 5 entries).
- No stale version references.
- No contradictory Post-Cutoff API assumptions between ADRs.
- Two previously-known open verification items, unchanged, not new:
  - ADR-0001 Verification Required #2 / `TR-gravity-012` — same-frame reach of the space write during active easing, still open.
  - ADR-0006 T4 — whether `@export_range` clamps a hand-edited `.tres` value, documented but not executed against the pinned 4.7.1 binary.

### Engine Specialist Findings

Consultation scoped deliberately to cross-ADR composition (not re-litigating any single ADR's already-reviewed content):

- **CONFIRMED** — `GravityAuthority.apply_camera_relative_axis(...)` called through the autoload singleton name is standard, correct GDScript; static-method dispatch via a singleton/instance reference is unaffected by any 4.4–4.7 change.
- **CONFIRMED** — No ordering hazard between the `-100/0/+100` `process_physics_priority` contract and autoload-vs-scene instantiation timing: `GravityAuthority._ready()` runs at boot, long before any level scene's `Player._ready()`, and F3's single global sort applies regardless of tree branch.
- **New finding 2 and New finding 3 above** (physics-space write possibly skipped on `reset_to()`; camera possibly missing the first broadcast) — both QUESTIONs, not confirmed defects, surfaced only by reading ADR-0001 parts 4a/6 and ADR-0003's D3.1 step order together.

---

## Architecture Document Coverage

- Every system in `systems-index.md` appears in `architecture.md`'s layer map. ✅
- Data flow / signal table: **stale** in the same place as New finding 1 above — still shows `gravity_changed → PlayerGravityComponent` as the player's gravity-consumption path, which ADR-0007 D7.1 replaced with a live per-frame read.
- API Boundaries § Foundation: **stale** — missing ADR-0007's `apply_camera_relative_axis` addition and the narrowed `PlayerGravityComponent` surface.
- Orphaned architecture (systems with no GDD): wall jump, moving platforms, spike hazards — already correctly tracked in `systems-index.md` § Implemented but undocumented and `architecture.md` QQ-05. Not new.

---

## Verdict: **CONCERNS**

Not FAIL: no Foundation- or Core-layer requirement is uncovered — all 7 Accepted ADRs between them close every one. Not PASS: 22 requirements remain gapped (expected at this stage — all assigned to specific unwritten ADRs with no ordering blockers), one requirement (`TR-oxygen-006`) is **unowned** rather than merely unwritten, `architecture.md` has drifted from ADR-0007 in four places, and two new design gaps (physics-space write on load, camera's first-broadcast timing) need resolution before ADR-0011 and the camera-wiring work respectively.

### Blocking issues
None that block continuing to write ADRs today. The one item that blocks a *specific next ADR*: **`TR-oxygen-006` must get an owner before ADR-0008 is written** — this is unchanged from `HANDOFF.md`'s standing flag, and this review didn't find a way to resolve it by inspection alone; it needs a decision (does `OxygenDrain` consult pause state directly, or does ADR-0010's HUD/pause-menu system own composing it in?).

### Required ADRs — priority order
1. **Assign `TR-oxygen-006`'s owner** (a decision, not an ADR) — blocks ADR-0008.
2. **ADR-0008** — Oxygen drain and the shared death path (once #1 is resolved).
3. **ADR-0009** — Watering interaction model (fully unblocked; inherits ADR-0007's contracts cleanly).
4. **ADR-0011** — Physics props implementation (fully unblocked on dependencies, but should account for new findings 2/3 first).
5. **ADR-0010 / ADR-0012** — HUD and jug-throw, no ordering constraint, can happen anytime after their prerequisites.
