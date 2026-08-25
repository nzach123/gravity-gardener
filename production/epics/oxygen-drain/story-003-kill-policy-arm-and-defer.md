# Story 003: The kill policy — freeze-if-complete, arm on depletion, restart on the next frame

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3-4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §3 R3 · §5 · §8 AC2
**Requirement**: `TR-oxygen-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **`TR-oxygen-003` closes only in part here.** This story lands the kill
> *mechanism*: freeze, arm, defer one frame, route through the guarded
> chokepoint. The depletion-frame *outcomes* — `suit-oxygen.md` AC8 and
> `watering-system.md` AC13, the two opposite results of the same frame — are
> story 004. Do not tick AC8 on this story.

**ADR Governing Implementation**: ADR-0008: Oxygen Drain, Shared Death Path, and
the Accessibility Drain-Rate Override (Decision §1) *(primary)* ·
ADR-0005: Frame ordering and the `level_complete` guard (D5.2, D5.4, D5.6)
*(secondary — it owns the deferral and the chokepoint; ADR-0008 restates them
unchanged)* · ADR-0002 *(secondary — `depleted` is a pure state signal carrying no
policy)*

**ADR Decision Summary**: `OxygenState.depleted` reports an empty tank and decides
nothing. `OxygenDrain` owns the kill *policy*, which is why it — and not
`LevelRoot` — is the node that respects the `level_complete` suppression. The
callback is four steps in a fixed order and has no other branches:
freeze-if-complete → armed-restart → `drain()` → arm-on-depletion. The kill is
evaluated at the **top of the next** callback, never in the one that observed
`remaining <= 0`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0008 declares no new post-cutoff API and no new
verification. Project-local facts that bind this story:

- **A freed `Object` held in a `Variant` compares `== null` as TRUE on 4.7.1, and
  `value as Node` on one RAISES** "Trying to cast a freed object". A plain null
  check already catches a freed object; `as` is not a safe probe. Relevant here
  because the restart path tears down the level while this node still holds
  references to `LevelRoot` and both state objects.
- **`reload_current_scene` logs `Parameter "current_scene" is null` in a headless
  test with no current scene, and that is not a failure** —
  `kill_area_death_test.gd` passes while logging it. Do not chase the line.
- gdUnit4 treats one GDScript warning as a discovery-time error for the whole
  suite.

**Control Manifest Rules (this layer)**:
- Required: "`OxygenDrain` arms on depletion and evaluates the kill at the TOP of
  its NEXT physics callback — never in the same callback that observed
  `remaining <= 0`." — ADR-0005 (D5.2)
- Required: "`level_complete` freezes `OxygenDrain` entirely — no `drain()` call,
  not only no kill — so the HUD holds its final reading through the transition." —
  ADR-0005 (D5.6)
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path must
  check and set `_transition_pending`. The latch alone is insufficient —
  inter-area signal delivery order within one physics tick is undetermined." —
  ADR-0005 (D5.4, A5-02)
- Forbidden: "Never restart the level in the same `_physics_process` callback that
  observed `remaining <= 0`." — ADR-0005 (`same_frame_oxygen_kill`)
- Forbidden: "Never reload the level from a death/reset path that does not consult
  `level_complete`. All death paths route through the guarded `restart_level()`."
  — ADR-0005 (`unguarded_restart_path`)
- Forbidden: "Never connect `OxygenState.depleted` directly to
  `LevelRoot.restart_level()`" — breaks `suit-oxygen.md` AC8; `OxygenDrain` owns
  the kill policy and the `level_complete` suppression. — ADR-0002
  (`depleted_wired_to_restart`)
- Forbidden: "Never write `level_complete` from any node other than
  `LevelRoot._on_player_reached_goal()`, and never set it back to `false`." —
  ADR-0005 (`level_complete_written_outside_level_root`)

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md`, scoped to this story:*

- [ ] **AC2** — reaching zero triggers the **identical** restart path as spike
      death. Not a parallel path that looks the same: the same guarded
      `LevelRoot.restart_level()` call that `Hazard` and the kill area route
      through
- [ ] The four callback steps run in the ADR's fixed order, and the callback
      contains no other branches
- [ ] `level_complete` freezes the node **entirely** — `drain()` is not called,
      not merely the kill suppressed
- [ ] The kill fires at the **top of the callback after** the one that observed
      `remaining <= 0`. Never the same callback
- [ ] `OxygenDrain` reads `level_complete` and never writes it
- [ ] `OxygenState.depleted` is not connected to anything that restarts the level
- [ ] The one-physics-frame deferral is **documented at the code** as
      intentional, citing ADR-0005 D5.2 — so a future reader does not "fix" it

---

## Implementation Notes

*Derived from ADR-0008 Decision §1 and the ADR-0005 D5.2 frame walkthrough:*

- **The callback, exactly as ADR-0008 records it:**
  ```gdscript
  _physics_process(delta):
      if level_complete:      return          # frozen: no drain, no kill
      if _death_armed:        restart_level(); return
      drain(delta)
      if remaining <= 0.0:    _death_armed = true
  ```
  Insert steps 1, 2 and 4 into the seams story 002 left. Do not restructure.
- **Two port deltas from the prototype, and the ADR wins both.**
  `prototypes/.../scripts/oxygen_drain.gd` is the reviewed reference, but:
  1. It **emits an `oxygen_depleted` signal** where ADR-0005 (`:373`) calls
     `_level_root.restart_level()` **directly** on an injected reference.
     Implement the direct call. A signal reintroduces the delivery-order
     uncertainty D5.4's `_transition_pending` guard exists to close, and it puts
     the kill decision back where the wiring — not this node — decides it.
  2. Its flag is named `_armed`; ADR-0005 and ADR-0008 both name it
     `_death_armed`. Use the ADR name.
- **The deferral is load-bearing and `suit-oxygen.md` disagrees with it in
  writing.** The GDD's R3 and §5 say oxygen death is "immediate"; ADR-0005 D5.2
  defers it one physics frame (~16.6 ms), and ADR-0008 Decision §1 states that
  narrowing explicitly on the architecture side. **`tr-registry.yaml` carries this
  as an unresolved GDD-level conflict under `TR-oxygen-003`'s `note`.** Implement
  the ADR. Do not edit the GDD from this story, and do not "correct" the code
  toward the GDD's wording.
- **`restart_level()`'s `_transition_pending` guard is not this story's to add.**
  It lives on `LevelRoot` and is owed by the `level-validation` / level-migration
  work that ADR-0005's migration plan step 3 names (`main.gd:59`). `level-state`
  stories 005 and 006 both explicitly decline it too. **If it is still absent when
  this story runs, that is a real gap — raise it rather than adding the field
  here**, because a second author adding `_transition_pending` in a second place
  is precisely the failure the single-chokepoint decision prevents.
- **Hold the injected `LevelRoot` reference from `bind()`.** Do not reach for it
  with `get_parent()` or a group lookup — ADR-0002 forbids discovery, and
  `get_parent()` silently binds the contract to scene-tree shape.
- **Why `OxygenDrain` and not `LevelRoot` owns this**: the freeze check has to
  happen *before* the armed-restart check, in the same node, on the same frame.
  Splitting them across two nodes reintroduces the ordering question. ADR-0002
  corrected `architecture.md` on exactly this point.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **Story 002**: the drain call itself, the priority, `bind()`, and the
  accessibility composition.
- **Story 004**: `suit-oxygen.md` AC8 and `watering-system.md` AC13 — what the
  two opposite depletion-frame outcomes actually resolve to. This story provides
  the mechanism they are asserted against.
- **Story 006**: pause. Add no pause check — `SceneTree.paused` stops the
  callback from running at all, and `oxygen_pause_state_object` forbids the flag.
- **`LevelState.mark_complete()` and the write-once latch** — `level-state`
  story 005. This story only *reads* `level_complete`.
- **`restart_level()`'s own `_transition_pending` early return** — ADR-0005
  migration step 3, owned by the level-migration work. See Implementation Notes.
- **Spike and kill-area death paths.** They already exist in `src/`. This story
  joins them; it does not modify them.

---

## QA Test Cases

*Story type: **Logic** — automated test specs.*

- **AC-1 — the kill is deferred exactly one frame**
  - Given: a bound drain with `remaining` one step away from zero
  - When: the step that brings `remaining` to `0.0` runs
  - Then: **no restart happened during that callback**, and `_death_armed` is true
  - And when: the next callback runs
  - Then: the restart fires at the top, before any `drain()` call
  - Edge cases: this is `same_frame_oxygen_kill`, the forbidden pattern with the
    highest chance of being "simplified" away by a later author. Assert the
    negative (nothing happened on the arming frame) as explicitly as the positive.

- **AC-2 — `level_complete` freezes the node entirely**
  - Given: a bound drain and a `LevelState` with the latch set
  - When: several callbacks are stepped
  - Then: `remaining` is **unchanged** — `drain()` was not called at all
  - Edge cases: D5.6 is specifically stronger than "no kill". An implementation
    that suppresses only the restart still drains, and the HUD's final reading
    drifts during the transition. Assert on `remaining`, not on restart count.

- **AC-3 — a level completed while already armed never kills**
  - Given: a drain with `_death_armed` true from the previous frame
  - When: `level_complete` becomes true before the next callback
  - Then: the freeze check wins, and no restart fires — on that frame or any
    later one
  - Edge cases: **step order is the whole assertion here.** If the armed-restart
    check were placed above the freeze check, this test fails and AC8 becomes
    unreachable. Test it directly rather than trusting the source order.

- **AC-4 — the restart path is the same one spike death uses**
  - Given: `src/**/*.gd` after this story
  - When: every path that reloads or restarts a level is enumerated
  - Then: all of them — spike, kill area, oxygen — call the single guarded
    `LevelRoot.restart_level()`, and none calls `reload_current_scene` (or
    equivalent) directly
  - Edge cases: `unguarded_restart_path` is the forbidden pattern. Capture the
    match and branch on emptiness — a bare `grep` exits `1` on no match and passes
    forever.

- **AC-5 — `depleted` is not wired to restart**
  - Given: the whole `src/` tree
  - When: searched for a connection from `OxygenState`'s `depleted` to any
    restart or reload target
  - Then: none exists
  - Edge cases: `depleted_wired_to_restart` is forbidden precisely because it is
    the *obvious* wiring and it looks correct until a player enters the airlock on
    the depletion frame. Check both `connect()` calls and `.tscn` signal
    connections — the editor writes the latter and a grep over `.gd` alone misses
    it.

- **AC-6 — `OxygenDrain` never writes `level_complete`**
  - Given: `oxygen_drain.gd`
  - When: read
  - Then: it holds no call to `mark_complete()` and makes no assignment to
    `level_complete`
  - Edge cases: scope the assertion to **writes**. This node legitimately reads
    the latch every frame — an assertion that bans the reference outright
    contradicts AC-2 and will be "fixed" by deleting the freeze check.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/oxygen/oxygen_kill_policy_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (the callback and the seams) · `level-state` story
  005 (the `level_complete` latch this story reads) · `level-state` story 004
  (`LevelRoot` and injection).
- **Unlocks**: Story 004 (the depletion-frame outcomes, asserted against this
  mechanism) · Story 006.
