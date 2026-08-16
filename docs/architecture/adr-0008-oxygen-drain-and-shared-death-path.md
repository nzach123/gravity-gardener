# ADR-0008: Oxygen Drain, Shared Death Path, and the Accessibility Drain-Rate Override

## Status
Accepted

## Date
2026-08-15 (Accepted 2026-08-16)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — no breaking changes to `Node`, `SceneTree`, `Resource`, or `PackedScene` between 4.4 and 4.7.1 (`modules/core.md`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/core.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`. Note: the `oxygen_accessibility.tscn` autoload's `@export_range`-on-`Node` pattern is verified by precedent (ADR-0001's `GravityAuthority`, Accepted), not by `modules/core.md`, which does not cover autoload/inspector-surface patterns (godot-specialist validation, 2026-08-16) |
| **Post-Cutoff APIs Used** | None. `process_physics_priority` (4.1) is already established by ADR-0005; this ADR adds no new post-cutoff API |
| **Verification Required** | None new. The `PROCESS_MODE_INHERIT`/`PROCESS_MODE_PAUSABLE`/`SceneTree.paused` mechanism Decision §2 depends on is now cited in `modules/core.md` § Pause and process modes (previously correct but uncited — closed by 2026-08-15 architecture review). ADR-0006 T4 (`@export_range` clamping on a hand-edited `.tres`) stays open and is unaffected by this ADR |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted — `OxygenState` construction and injection), ADR-0005 (Accepted — frame ordering, `OxygenDrain.frame_contract`, `restart_level_chokepoint_guard`), ADR-0006 (Accepted — `Tuning.OXYGEN` and D6.6's assignment of the drain-rate composition to this ADR) |
| **Enables** | A future settings-screen ADR (not yet numbered). That ADR designs the UI and disk persistence that write to `OxygenAccessibility`; this ADR defines only the read side and an in-memory default |
| **Blocks** | None. The HUD readout (TR-oxygen-007, TR-oxygen-009 — ADR-0010) reads `OxygenState`, already available via ADR-0002 |
| **Ordering Note** | None beyond Depends On |

## Context

### Problem Statement

`suit-oxygen.md` R1–R4 need `OxygenState` and `OxygenDrain` to implement the drain and death rules. TR-oxygen-006 needs a pause mechanism. ADR-0006 D6.6 assigns one more question to this ADR: `OxygenTuning.drain_rate` is a read-only authored constant (D6.5), but `suit-oxygen.md` §7 calls `drain_rate` a player-facing accessibility hook. Something must compose the two without writing to the tuning resource.

### Constraints

- `OxygenTuning.drain_rate` cannot be written at runtime (D6.5, ADR-0006).
- `OxygenState._init(capacity: float, tuning: OxygenTuning)` is frozen by ADR-0002. This ADR must not change that signature.
- `OxygenState.drain(delta: float)` must keep its existing guarantee: no state checks (ADR-0002 registry entry).
- No settings screen or save system exists yet.
- `OxygenDrain`'s frame position is already fixed at `process_physics_priority` +100 (ADR-0005).

### Requirements

- Drain must be unconditional across every player state (R2).
- Zero oxygen must route through the same restart path as spike and kill-area death (R3), respecting the one-frame arming deferral and the `level_complete` / `_transition_pending` chokepoint (ADR-0005).
- Pausing must halt drain, with no change to `OxygenState` or `OxygenDrain`'s own logic (TR-oxygen-006, decided session 18 — see Decision §2).
- A player-facing drain-rate accessibility setting must exist, in memory, readable every physics frame, without touching `Tuning.OXYGEN`.

## Decision

### 1 — OxygenDrain's frame behavior (formalizes ADR-0005; no new decision here)

`OxygenDrain` is a `Node` child of `LevelRoot`, injected with the level's `OxygenState` (ADR-0002, `level_state_injection`). Its `process_physics_priority` is +100 (ADR-0005, `frame_ordering_contract`). Its `_physics_process` body is the contract ADR-0005 already recorded:

```gdscript
_physics_process(delta):
    if level_complete:      return          # frozen: no drain, no kill
    if _death_armed:        restart_level(); return
    drain(delta)
    if remaining <= 0.0:    _death_armed = true
```

This ADR changes nothing here. It exists to give `suit-oxygen.md` R1–R4 a written owner: TR-oxygen-001 through TR-oxygen-004 currently show `adr_status: not_written` in the registry, even though the mechanics are already Accepted under ADR-0005's frame contract.

**Narrowing note on `suit-oxygen.md` §5/R3's "immediate."** The GDD's wording predates ADR-0005 D5.2's decision to arm on the frame `remaining` reaches zero and restart on the *next* frame (`_death_armed` above) — a one-physics-frame (~16.6 ms) deferral, not a same-frame kill. This ADR restates D5.2 unchanged and does not reopen it; the deferral is load-bearing (it lets the arming frame finish its own frame batch cleanly, the same discipline `restart_level_chokepoint_guard` already relies on). `suit-oxygen.md` R3/§5's wording remains uncorrected in the GDD itself — this note narrows the architecture-side reading only, the way ADR-0005 D5.6 narrows an ADR-0002 precondition without editing ADR-0002's text.

### 2 — Pause halts drain (TR-oxygen-006, decided 2026-08-15, session 18)

`OxygenDrain` keeps its default `process_mode` (`PROCESS_MODE_INHERIT`). When `SceneTree.paused = true`, an inherited `PROCESS_MODE_INHERIT` chain resolves to `PROCESS_MODE_PAUSABLE`, and `_physics_process` does not run — `drain()` is never called. No pause-state object is injected into `OxygenDrain` or `OxygenState`.

**This correctness is chain-wide, not local to `OxygenDrain`.** If `LevelRoot` or any ancestor between `OxygenDrain` and the tree root is ever set to `PROCESS_MODE_ALWAYS` or `PROCESS_MODE_WHEN_PAUSED` for an unrelated reason — for example, a future pause-menu overlay parented under `LevelRoot` that needs to keep animating while paused — `OxygenDrain` silently inherits that change and TR-oxygen-006 breaks with no local symptom. **`LevelRoot` and every ancestor between it and the tree root must stay `PROCESS_MODE_INHERIT` (or explicit `PAUSABLE`).** This is not enforced by any code in this ADR; it is recorded here because nothing will complain when it changes (same hazard shape as `process_thread_group_split_in_frame_chain`, ADR-0005).

This ADR does not own the pause toggle. ADR-0010 owns opening and closing the pause state; no pause menu exists yet.

**Rejected**: an injected pause-state object that `OxygenDrain` checks each frame, mirroring `level_complete`. `SceneTree.paused` already stops `_physics_process` from being called at all, so a second flag would duplicate an engine guarantee for no benefit, and would put a state check inside a callback ADR-0005 defined as check-then-drain-then-arm with no other branches.

### 3 — The drain-rate composition (ADR-0006 D6.6)

**Effective drain, per physics frame:**

```gdscript
var scaled_delta := delta * OxygenAccessibility.drain_rate_multiplier
oxygen_state.drain(scaled_delta)
```

`OxygenState.drain(delta)` keeps its ADR-0002 signature unchanged and keeps multiplying by `tuning.drain_rate` internally, exactly as today. `OxygenDrain` is the only caller, and it is the one place the accessibility multiplier and the authored `Tuning.OXYGEN.drain_rate` combine:

```
remaining -= tuning.drain_rate * (delta * OxygenAccessibility.drain_rate_multiplier)
           = tuning.drain_rate * OxygenAccessibility.drain_rate_multiplier * delta
```

Since `Tuning.OXYGEN.drain_rate` is the authored constant (currently 1.0 — see D6.6 and `suit-oxygen.md` §7's "must not be used as a difficulty dial"), this reduces to the multiplier alone today. Pre-scaling the delta, rather than changing `OxygenState.drain()`'s signature or logic, means:

- `OxygenState` stays exactly as ADR-0002 froze it. No new constructor parameter, no new dependency.
- `OxygenState` never reaches for an autoload. It stays a plain `RefCounted`, constructible and testable with only `(capacity, tuning)` — the coding standard's "public methods must be unit-testable... dependency injection over singletons" holds with no mock needed for `OxygenAccessibility`.
- The composition is **stacked**, not **replaced**, without any branch. `drain_rate_multiplier` defaults to `1.0`, so an untouched setting is a no-op, not a special case.

**`scaled_delta` is not a raw frame delta once it leaves this line.** Add a one-line comment at the call site (and in `OxygenState`'s doc comment) noting that `drain()` receives an accessibility-scaled delta, not wall-clock delta — future code must not reuse this value for anything that needs real elapsed time (a play-time counter, a VFX timer).

**`OxygenAccessibility`** is a new scene autoload (`oxygen_accessibility.tscn`, script attached), chosen over a bare script autoload specifically so `@export_range` gets inspector surface — this is the pattern ADR-0001 *decided* for `GravityAuthority`, though `GravityAuthority` is itself Accepted but not yet implemented in `src/`. The one autoload that currently exists, `GameManager` (`project.godot:20`), is a bare script autoload — the opposite pattern, kept for `GameManager`'s own reasons and not a counter-precedent here.

```gdscript
class_name OxygenAccessibility
extends Node

@export_range(0.5, 1.0, 0.01) var drain_rate_multiplier: float = 1.0

func set_drain_rate_multiplier(value: float) -> void:
    drain_rate_multiplier = clampf(value, 0.5, 1.0)
```

**Persistence: none, yet.** `drain_rate_multiplier` lives only in memory and resets to `1.0` on every launch. Nothing in this ADR reads or writes `user://`. A future settings-screen ADR owns disk persistence (`ConfigFile` or otherwise) and calls `set_drain_rate_multiplier()` on load — this ADR defines only the read contract that ADR will consume.

**Mid-level changes take effect immediately.** `OxygenDrain` reads `OxygenAccessibility.drain_rate_multiplier` fresh every physics frame — no snapshot, no caching, no re-read-on-level-load step to bypass. A player who opens a future settings screen mid-level sees the drain rate change on the next physics frame, with no restart required.

### Architecture Diagram

```
LevelRoot._ready()
  ├─ constructs OxygenState(capacity, Tuning.OXYGEN)      [ADR-0002]
  └─ OxygenDrain (child, priority +100)
       ├─ bind(oxygen_state)                               [ADR-0002 injection pattern]
       └─ _physics_process(delta):
            scaled_delta = delta * OxygenAccessibility.drain_rate_multiplier
            oxygen_state.drain(scaled_delta)   # multiplies by tuning.drain_rate internally
            ...arm / restart on depletion       [ADR-0005]

OxygenAccessibility (autoload, always present)
  drain_rate_multiplier: float = 1.0   [0.5, 1.0]
  set_drain_rate_multiplier(value)     ← future settings screen calls this
```

### Key Interfaces

```gdscript
class_name OxygenAccessibility
extends Node
@export_range(0.5, 1.0, 0.01) var drain_rate_multiplier: float = 1.0
func set_drain_rate_multiplier(value: float) -> void
```

No change to `OxygenState` or `OxygenDrain`'s existing frozen contracts (ADR-0002, ADR-0005). `OxygenDrain`'s only new line reads `OxygenAccessibility.drain_rate_multiplier` before calling `drain()`.

## Alternatives Considered

### Alternative 1: Replace instead of stack

- **Description**: When a non-default accessibility value is set, `OxygenDrain` uses it directly as the drain rate and does not read `Tuning.OXYGEN.drain_rate` at all.
- **Pros**: One active number at a time; no multiplication to reason about.
- **Rejection Reason**: User decision. Needs a branch ("is an override active?") inside a path ADR-0002 and ADR-0005 both keep branch-free. Stacking with a default-1.0 multiplier reaches the same numbers with no branch.

### Alternative 2: Full disk persistence now

- **Description**: This ADR also designs a `ConfigFile` format under `user://` and a load-on-launch path for the multiplier.
- **Pros**: Settings survive a relaunch immediately, not just after a future ADR.
- **Rejection Reason**: User decision. Nothing can write the file today — no settings screen exists. Specifying a save format with no writer is unfalsifiable speculation, and the coding standard rejects designing for a requirement that cannot yet be exercised.

### Alternative 3: OxygenState reads OxygenAccessibility directly

- **Description**: `OxygenState.drain()` reaches into the `OxygenAccessibility` autoload itself instead of receiving a pre-scaled delta.
- **Pros**: One fewer line in `OxygenDrain`.
- **Rejection Reason**: Gives a plain `RefCounted` a hidden autoload dependency. Breaks the "public methods must be unit-testable... dependency injection over singletons" coding standard, and `OxygenState` would need a live singleton to test, the same hazard class the `LevelValidation` null-tree precedent (ADR-0003 E1/E2) already treats as a risk.

### Alternative 4: Injected pause-state object (TR-oxygen-006)

- **Description**: A `PauseState` object is injected into `OxygenDrain`, mirroring `level_complete`, and checked each frame.
- **Pros**: Symmetric with the `level_complete` check already in the frame contract.
- **Rejection Reason**: Already decided against, session 18. `SceneTree.paused` plus `PROCESS_MODE_INHERIT` gets the same result at zero cost — the engine already refuses to call `_physics_process` at all. An injected object would duplicate that guarantee and add a state check the frame contract does not otherwise need.

## Consequences

### Positive

- TR-oxygen-001 through TR-oxygen-004 and TR-oxygen-006 gain a written ADR. `docs/architecture/tr-registry.yaml` moves from `adr_status: not_written` to `accepted` for all five once this ADR is Accepted.
- The D6.6 conflict (drain_rate is both "read-only" and "an accessibility hook") is resolved without weakening D6.5. `Tuning.OXYGEN.drain_rate` is never written.
- `OxygenState` and `OxygenDrain`'s existing frozen contracts (ADR-0002, ADR-0005) are untouched. This ADR adds one autoload and one line in `OxygenDrain`.
- The accessibility multiplier takes effect immediately, mid-level, satisfying `accessibility-requirements.md`'s T3 test today, without a settings screen.

### Negative

- `OxygenAccessibility.drain_rate_multiplier` resets to `1.0` on every launch until a settings-screen ADR adds persistence. A player must re-set it every session.
- A second autoload exists project-wide for one float, once `GravityAuthority` is also implemented. This is a small, single-purpose object, not a general accessibility-settings hub — later accessibility features (text scale, remapping, reduced motion) each need their own architecture decision and may or may not extend this autoload.

### Risks

- **A future author adds unrelated fields to `OxygenAccessibility`**, turning a single-purpose autoload into an implicit general settings singleton nothing decided to build. *Mitigation*: this ADR names the autoload's scope as exactly one field; extending it needs its own ADR, the same discipline as `Tuning` (ADR-0006) and `GravityTuning`'s ban (D6.7).
- **A future author writes to `Tuning.OXYGEN.drain_rate` directly** instead of going through `OxygenAccessibility`, reintroducing the exact D6.5 violation D6.6 exists to prevent. *Mitigation*: the forbidden-pattern registry entry `tuning_resource_runtime_mutation` already names this ADR as the correct location; no new registry entry needed, only the composition contract to point to.
- **The `LevelRoot`-ancestor `process_mode` invariant (Decision §2) is enforced by nothing but this document.** A future node added between `OxygenDrain` and the tree root with a non-`INHERIT` process mode silently breaks TR-oxygen-006 with no compile error and no symptom until a playtester notices oxygen draining during pause. *Mitigation*: stated explicitly in Decision §2. No automated check exists; recommend a scene test once a pause menu (ADR-0010) exists to pause against.
- **`clampf()` in `set_drain_rate_multiplier()` silently absorbs an out-of-range settings value** rather than reporting it. *Mitigation*: acceptable today because nothing calls the setter yet. The future settings-screen ADR should decide whether silent clamping is still correct once a UI can produce out-of-range input.
- **`scaled_delta` looks like a raw frame delta at the call site**, and a future edit to `OxygenState.drain()` that reuses `delta` for anything needing real elapsed time (a play-time counter, a VFX timer) would silently inherit the accessibility scaling too. *Mitigation*: comment required at the call site per Decision §3; no automated check.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `suit-oxygen.md` | R1 — per-level countdown from `oxygen_capacity` | `OxygenState`, constructed per ADR-0002, already holds capacity/remaining; this ADR adds no change |
| `suit-oxygen.md` | R2 / AC1 — drain is unconditional in every player state | `OxygenDrain`'s frame contract (ADR-0005) calls `drain()` unconditionally every physics frame with no player-state branch |
| `suit-oxygen.md` | R3 / AC2 — zero oxygen is death via the shared restart path | `OxygenDrain` arms on depletion and restarts on the next frame through the ADR-0005 chokepoint guard, identical to spike and kill-area death. **Note**: this is a one-physics-frame deferral, not same-frame — see Decision §1 narrowing note on the GDD's "immediate" wording |
| `suit-oxygen.md` | R4 / AC3 — nothing refills the suit | `OxygenState.drain()` has no setter and never increases `remaining` (ADR-0002); this ADR adds no path that could |
| `suit-oxygen.md` | §5 — pausing halts drain (TR-oxygen-006) | `SceneTree.paused` plus `OxygenDrain`'s default `PROCESS_MODE_INHERIT` stops `_physics_process` from running while paused, subject to the ancestor-chain invariant in Decision §2 |
| `suit-oxygen.md` | §7 — `drain_rate` is an accessibility hook, range 0.5–1.0 | `OxygenAccessibility.drain_rate_multiplier`, range-clamped 0.5–1.0, composes with `Tuning.OXYGEN.drain_rate` by multiplication in `OxygenDrain` |
| `accessibility-requirements.md` | T3 — set drain_rate = 0.5, verify E1 reads real seconds | `OxygenAccessibility.set_drain_rate_multiplier(0.5)` is callable today (via debug/test code), ahead of any settings UI |
| `accessibility-requirements.md` | "Timing extension" row — drain_rate extends oxygen deadlines up to 2× | The 0.5–1.0 clamp on `drain_rate_multiplier` is the same range `accessibility-requirements.md` already documents as the ceiling |

## Performance Implications

- **CPU**: One float multiplication and one autoload property read added to an existing per-physics-frame call. Immeasurable against the 16.6 ms budget.
- **Memory**: One new autoload node, one float field. Negligible.
- **Load Time**: None. `OxygenAccessibility` is a scene autoload, resolved at project start; it holds no resource to preload.
- **Network**: Not applicable — no networking in this project.

## Migration Plan

`src/` does not yet implement `OxygenState`, `OxygenDrain`, or any oxygen mechanics (verified 2026-08-15). There is nothing to migrate. The migration epic implements this ADR alongside ADR-0002, ADR-0005, and ADR-0006 as new code, not as a change to existing behavior.

Add `oxygen_accessibility.tscn` as a new autoload in `project.godot`, ordered anywhere relative to `GravityAuthority` once that autoload also exists — the two have no dependency on each other.

## Validation Criteria

- A unit test constructs `OxygenState(capacity, tuning)` directly (no autoload, no `SceneTree`) and asserts `drain()` behaves per ADR-0002 — proves `OxygenState` still needs no `OxygenAccessibility` dependency.
- A unit test asserts `OxygenAccessibility.set_drain_rate_multiplier()` clamps values outside `[0.5, 1.0]`.
- `accessibility-requirements.md` T3 becomes runnable and should pass: setting `drain_rate_multiplier = 0.5` makes E1 (once built) read real seconds against a stopwatch at half the default drain speed.
- `accessibility-requirements.md` T9 (pause halts drain) becomes runnable once a pause menu exists (ADR-0010): pausing mid-level must leave `oxygen_remaining` unchanged.
- Integration: a level with `oxygen_capacity` authored and `drain_rate_multiplier` left at default 1.0 must survive exactly `oxygen_capacity` wall-clock seconds ±0.1 s (AC6, already specified in `suit-oxygen.md`).

## Related Decisions

- **ADR-0002** — Level state ownership. Freezes `OxygenState._init(capacity, tuning)` and `drain(delta)`; this ADR does not modify either.
- **ADR-0005** — Frame ordering. Defines `OxygenDrain`'s `_physics_process` shape and the `_transition_pending` chokepoint this ADR's death path reuses unchanged.
- **ADR-0006** — Tuning resource strategy. D6.5 bans writing to `Tuning.OXYGEN`; D6.6 assigns the drain-rate composition question to this ADR by name.
- **ADR-0010** (not yet written) — HUD and pause. Owns the pause toggle and the future settings screen that will call `OxygenAccessibility.set_drain_rate_multiplier()`.
