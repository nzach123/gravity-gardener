# Story 002: `OxygenDrain` — bind, `+100` priority, and the accessibility-scaled drain call

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3-4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §3 R1, R2, R4 · §4 · §7 · §8 AC1, AC3
**Requirement**: `TR-oxygen-001` *(drain half)*, `TR-oxygen-002`, `TR-oxygen-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Oxygen Drain, Shared Death Path, and
the Accessibility Drain-Rate Override (Decision §1, §3) *(primary)* ·
ADR-0005: Frame ordering (D5.1, D5.5) *(secondary — it fixed the `+100` slot;
ADR-0008 formalizes it and decides nothing new there)* ·
ADR-0002 *(secondary — it froze `OxygenState.drain(delta)`'s signature, which
this story must not change)*

**ADR Decision Summary**: `OxygenDrain` is a `Node` child of `LevelRoot`, injected
with the level's `OxygenState` (never reaching for it through an autoload), sitting
at `process_physics_priority` `+100`. It calls `drain()` **unconditionally every
physics frame with no player-state branch** — that is the whole of R2. It is the
single place the accessibility multiplier and the authored
`Tuning.OXYGEN.drain_rate` combine, and it combines them by pre-scaling `delta`,
so `OxygenState` keeps the signature and internal logic ADR-0002 froze.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0008 declares **no new post-cutoff API and no new
verification**. `process_physics_priority` dates to 4.1 and is already established
by ADR-0005. Three project-local facts bind this story:

- **`process_physics_priority`, never `process_priority`.** The latter orders
  `_process` and is a separate property — assigning it here compiles cleanly and
  silently does nothing to physics ordering.
- **`OxygenTuning` is reached as `Tuning.OXYGEN`, and the tuning resource is
  read-only at runtime.** Never assign to any property of it, never call
  `.duplicate()`. CI enforces the literal shapes of both (ADR-0006 V7); the ADR is
  honest that the grep is partial — an alias or a `set()` by string name passes it.
  The ban is real regardless of what the grep catches.
- gdUnit4 fails the whole suite on one GDScript warning at discovery.
  `var x := <Variant expr>` is the shape that has bitten this project; annotate
  the type explicitly.

**Control Manifest Rules (this layer)**:
- Required: "`OxygenDrain` is a child of `LevelRoot`, `process_physics_priority =
  +100`, running: freeze-if-complete → armed-restart → `drain()` →
  arm-on-depletion." — ADR-0008 (§1)
- Required: "Effective drain pre-scales `delta` by
  `OxygenAccessibility.drain_rate_multiplier` before calling
  `OxygenState.drain(scaled_delta)`** — `OxygenState`'s signature and internal
  logic (multiplying by `tuning.drain_rate`) stay unchanged." — ADR-0008 (§3)
- Required: "Comment `scaled_delta` at the call site as accessibility-scaled, not
  raw wall-clock delta — future code must not reuse it for real elapsed time." —
  ADR-0008
- Required: "`process_physics_priority` (never `process_priority`) is assigned in
  code from a `FramePriority` const-only script: `-100 GravityAuthority`,
  `0 Player (+components inline)`, `+100 OxygenDrain`. Never per-scene in the
  inspector — 8 level scenes = 8 chances to drift." — ADR-0005 (D5.1, F1)
- Required: "Any rule-bearing quantity whose value on a specific frame decides an
  outcome (pour progress, oxygen, death timers) must live in `_physics_process`,
  never `_process`." — ADR-0005 (D5.5)
- Forbidden: "Never set `process_thread_group` away from default on
  `GravityAuthority`, `Player`, or `OxygenDrain`" — silently detaches the node
  from the `-100`/`0`/`+100` ordering contract with no compile error. — ADR-0005
  (`process_thread_group_split_in_frame_chain`)
- Forbidden: "Never reach level or oxygen state through an autoload, a new
  singleton, or [group discovery]." — ADR-0002
- Forbidden: "Never accumulate or evaluate a rule-bearing quantity in
  `_process`." — ADR-0005 (`gameplay_timing_in_idle_process`)
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`." — ADR-0006 (`tuning_resource_runtime_mutation`)

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md`, scoped to this story:*

- [ ] **AC1** — `oxygen_remaining` decreases by `drain_rate · delta` **every
      frame regardless of player state, including mid-pour**. No branch on player
      state exists anywhere in the callback
- [ ] **R1, drain half** — the countdown runs against the level's authored
      `oxygen_capacity`, received through injection at construction, never read
      from a global. *(The wall-clock fidelity of that countdown is story 005.)*
- [ ] **AC3, system half** — no call site anywhere increases `remaining`.
      `OxygenDrain` is the only caller of `drain()`, and it never passes a
      negative delta. *(The type-level guarantee — no setter, no refill, no
      `reset()` — is `level-state` story 002. This story asserts the complement:
      that the one caller cannot violate it either.)*
- [ ] `bind()` injects `OxygenState` and `LevelState`; an unbound
      `_physics_process` reports the error and returns rather than
      null-dereferencing
- [ ] `process_physics_priority` is assigned **in code** from
      `FramePriority.OXYGEN_DRAIN`, not as a literal and not in the inspector
- [ ] The effective drain is
      `tuning.drain_rate · multiplier · delta`, reached by pre-scaling `delta` —
      `OxygenState.drain()`'s signature and body are unchanged
- [ ] `drain_rate_multiplier` is read **fresh every physics frame**. No snapshot,
      no caching, no read-on-level-load step to bypass
- [ ] The `scaled_delta` call site carries the ADR-mandated comment

---

## Implementation Notes

*Derived from ADR-0008 Decision §1 and §3:*

- **This is a port, not green-field.**
  `prototypes/gravity-gardener-vertical-slice/scripts/oxygen_drain.gd` is the
  reviewed reference and is close to correct. `src/` has no `OxygenDrain`,
  no `OxygenState`, no `LevelRoot` and no `FramePriority` — verified 2026-08-24
  against the `src/` tree and `project.godot`. Port it; do not re-derive it.
- **One port delta to apply.** The prototype's `_physics_process` runs the full
  four-step body including the kill. **This story lands the drain half only** —
  the freeze check, the arm flag and the restart call are story 003. Implement the
  callback in the ADR's stated order from the start so story 003 is an insertion
  rather than a restructure, and leave a named comment at the two seams. This is
  the same discipline `level-state` story 004 used to keep LV-005 an insertion.
- **The composition is stacked, not replaced, and needs no branch:**
  ```gdscript
  # scaled_delta is accessibility-scaled, NOT raw wall-clock delta (ADR-0008 §3).
  # Never reuse it for anything needing real elapsed time — a play-time counter,
  # a VFX timer — or that thing silently inherits the accessibility scaling.
  var scaled_delta: float = delta * OxygenAccessibility.drain_rate_multiplier
  oxygen_state.drain(scaled_delta)
  ```
  which resolves to
  `remaining -= tuning.drain_rate * multiplier * delta`. Because the multiplier
  defaults to `1.0`, an untouched setting is a no-op and not a special case.
  **ADR-0008 rejected the alternative** where a non-default value replaces the
  authored rate: it needs an "is an override active?" branch inside a path
  ADR-0002 and ADR-0005 both keep branch-free.
- **Do not move the scaling into `OxygenState`.** ADR-0008 rejected that too
  (Alternative 3): it gives a plain `RefCounted` a hidden autoload dependency and
  breaks the coding standard's "dependency injection over singletons". The
  forbidden pattern `oxygen_state_reads_accessibility_autoload` exists for it.
- **`FramePriority.OXYGEN_DRAIN` comes from `level-state` story 003**, a
  const-only script reachable without a `SceneTree`. Do not define a local
  constant, and do not put the constant on `LevelRoot` — `GravityAuthority` is an
  autoload present before any level scene loads and cannot source a constant from
  a per-level script (ADR-0005 A5-05).
- **The unbound guard is a `push_error()` and an early return**, matching the
  prototype and the pattern `level-state` story 004's AC-2 established for every
  injected consumer. It is not a crash and not a silent no-op.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **Story 001**: the `OxygenAccessibility` autoload itself. This story reads it.
- **Story 003**: the kill policy — `level_complete` freeze, `_death_armed`, and
  the call into the guarded `restart_level()`. Leave the seams; do not fill them.
- **Story 005**: proving the countdown is wall-clock accurate to ±0.1 s.
- **Story 006**: pause. Add **no** pause check here — `oxygen_pause_state_object`
  forbids exactly that, and `SceneTree.paused` already stops the callback running.
- **`OxygenState` itself** — construction, capacity validation, getter-only
  `remaining`, and the `threshold_changed` band logic all belong to `level-state`
  story 002. **`threshold_changed` is emitted by `OxygenState`, not by
  `OxygenDrain`.** The epic overview's line about the drain node emitting band
  changes overstates ADR-0008, which assigns it no band behaviour at all. Do not
  add one here. *(EPIC.md carries a scope-correction note.)*
- **The HUD reading any of this** — Presentation HUD epic, ADR-0010.

---

## QA Test Cases

*Story type: **Logic** — automated test specs.*

- **AC-1 — drain is unconditional across player state**
  - Given: a bound `OxygenDrain` and an `OxygenState` at full capacity
  - When: `_physics_process` is stepped repeatedly while the player is
    successively idle, moving, jumping, and mid-pour
  - Then: `remaining` decreases by the same amount per step in all four cases
  - Edge cases: **mid-pour is the case AC1 names explicitly and the one a future
    author is most likely to break**, because the watering lockout gate
    (ADR-0007 D7.3 step 2) is the natural place to "helpfully" pause the clock.
    Assert it, and assert structurally that the callback contains no branch on
    player state.

- **AC-2 — the composition arithmetic**
  - Given: `Tuning.OXYGEN.drain_rate` at its authored value and a known `delta`
  - When: the multiplier is `1.0`, then `0.5`
  - Then: `remaining` falls by `drain_rate · delta` and `drain_rate · 0.5 · delta`
    respectively
  - Edge cases: assert `OxygenState.drain()`'s own signature and body are
    unchanged from `level-state` story 002 — the ADR requires the scaling live at
    the call site, and an implementation that "simplifies" by adding a multiplier
    parameter to `drain()` passes the arithmetic while breaking the frozen
    contract.

- **AC-3 — the multiplier is read fresh every frame**
  - Given: a bound drain stepping normally at multiplier `1.0`
  - When: the multiplier is changed to `0.5` **between two steps**, with no
    restart and no re-bind
  - Then: the very next step drains at the halved rate
  - Edge cases: this is ADR-0008's "mid-level changes take effect immediately"
    guarantee. A cached read in `_ready()` or in `bind()` passes every other test
    in this story and fails only this one.

- **AC-4 — no call site increases `remaining`**
  - Given: `src/**/*.gd` after this story
  - When: searched for callers of `drain(`
  - Then: exactly one, in `OxygenDrain._physics_process`, and it passes a
    non-negative scaled delta
  - Edge cases: a negative `delta` cannot occur from the engine, but a negative
    *multiplier* could if story 001's clamp were removed. Assert that a
    hypothetical negative multiplier still cannot raise `remaining` — `drain()`'s
    `maxf(0.0, ...)` floor is not a ceiling, so this is a real gap to check rather
    than assume.

- **AC-5 — the priority is assigned in code from the shared constant**
  - Given: `oxygen_drain.gd` and every `.tscn` that instances it
  - When: read
  - Then: `process_physics_priority = FramePriority.OXYGEN_DRAIN` appears in
    `_ready()`, the value resolves to `+100`, and **no scene file sets
    `process_physics_priority` in the inspector**
  - Edge cases: also assert `process_priority` is never assigned, and
    `process_thread_group` is left at default. Both compile silently and both
    detach the node from the frame contract.

- **AC-6 — an unbound drain reports and returns**
  - Given: an `OxygenDrain` added to a tree with `bind()` never called
  - When: `_physics_process` runs
  - Then: `push_error` fires and the callback returns without dereferencing null
  - Edge cases: assert it does not fire repeatedly enough to flood — or, if it
    does, that this is accepted and recorded. A per-frame `push_error` in a
    headless CI run is noise that hides real errors.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/oxygen/oxygen_drain_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (the autoload it reads) · `level-state` story 002
  (`OxygenState`) · `level-state` story 003 (`FramePriority`) · `level-state`
  story 004 (`LevelRoot` construction and injection). **ADR-0002 blocks this epic
  on `level-state` by name — build that epic first.**
- **Unlocks**: Story 003 (the kill policy, inserted at the seams this story
  leaves) · Story 005 · Story 006.
