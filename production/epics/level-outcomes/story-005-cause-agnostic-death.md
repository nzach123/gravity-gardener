# Story 005: Cause-agnostic death — three causes, one indistinguishable sequence

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R6 · §5 · §8 AC6 ·
`design/gdd/suit-oxygen.md` §3 R3 · `design/gdd/hazards.md`
**Requirement**: `TR-flow-006` *(reciprocal with `TR-hazards-003`, which states the
same guarantee from the hazards side)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Frame ordering and the `level_complete`
guard (D5.4) *(primary — the chokepoint is what makes the three uniform)* ·
ADR-0008: Oxygen Drain, Shared Death Path, and the Accessibility Drain-Rate Override
*(secondary — it reuses the ADR-0005 chokepoint unchanged for oxygen death)* ·
ADR-0014 D14.3 *(secondary — E6 running through the pause is what lets the sequence
actually play, and E6 is Presentation)*

**ADR Decision Summary**: The guard lives at the single point every death path
already passes through, rather than being repeated at each caller. That covers
`OxygenDrain`, `spike_hazard`'s `inc_hazard_dmg` and `_on_kill_area_2d_body_entered`
**uniformly** — which is what satisfies `suit-oxygen.md` R3/AC2's demand that the
three be indistinguishable, on the completion frame as much as on any other. Story
002 made the paths converge; this story makes what they converge on carry **no trace
of which one arrived**.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Facts that bind this story:

- **`reload_current_scene` logs `Parameter "current_scene" is null` in a headless
  test with no current scene, and that is not a failure** —
  `kill_area_death_test.gd` passes while logging it. Do not chase the line.
- **A freed `Object` compares `== null` as TRUE on 4.7.1 and `as` on one RAISES**
  "Trying to cast a freed object". A plain null check catches a freed object; `as` is
  not a safe probe. Every path here tears the level down while references are live.
- **Inter-area `body_entered` delivery order within one physics tick is
  undetermined.** Two causes can arrive in either order in the same batch; the
  chokepoint guard, not an ordering assumption, is what makes that produce one
  sequence.
- gdUnit4 treats one GDScript warning as a discovery-time error for the whole suite.

**Control Manifest Rules (this layer)**:
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH the completion path and the restart path must
  check and set `_transition_pending`." — ADR-0005 (D5.4, A5-02)
- Forbidden: "**Never reload the level from a death/reset path that does not consult
  `level_complete`.** All death paths route through the guarded `restart_level()`." —
  ADR-0005 (`unguarded_restart_path`)
- Forbidden: "Never restart the level in the same `_physics_process` callback that
  observed `remaining <= 0`." — ADR-0005 (`same_frame_oxygen_kill`)

---

## Acceptance Criteria

*From `design/gdd/level-flow.md` §8, scoped to this story:*

- [ ] **AC6** — Oxygen death, spike death and kill-area death produce **byte-identical
      presentation**. Nothing in the sequence names, hints at, or varies with the
      cause
- [ ] All three causes reach `LevelRoot.restart_level()` and nothing else. No cause
      has a path of its own
- [ ] No cause writes a cause-specific flag, field or signal payload that any later
      code could read. `_on_kill_area_2d_body_entered`'s current
      `body.player_died = true` write is removed or reduced to something the other
      two causes set identically
- [ ] Every death runs the **same** driver with the **same** `death_hold_duration`.
      No cause takes a different duration or a different code path through the hold
- [ ] A cause-specific write that happens **before** the guard is not left in place:
      a refused death must leave no residue that a completion could then display
- [ ] `print()` and debug output do not distinguish the causes in a shipping build.
      `main.gd`'s current `print("level restart called")` is either removed or
      carries no cause

*Explicitly NOT closed by this story — do not tick these anywhere:*

- **`TR-hazards-003`** states the same guarantee from the hazards side and closes in
  the hazards epic. Ticking it here would claim work this story does not do — the
  hazard bodies, masks and damage triggers are not touched.
- **`suit-oxygen.md` AC2** needs `OxygenDrain`'s kill policy, which is
  `oxygen-drain` story 003. This story asserts the *presentation* is uniform once the
  three arrive.
- **The visual content of the death sequence (E6)** is Presentation. This story
  guarantees the three causes are indistinguishable *by construction*; it does not
  build what is shown.

---

## Implementation Notes

*Derived from ADR-0005 D5.4 and `level-flow.md` R6:*

- **The property is structural, not a matter of care.** The three causes are
  indistinguishable because there is exactly one function that can end a level in
  death and it takes no arguments. Any signature change that lets a caller pass a
  reason — `restart_level(cause)`, a `death_reason` field, an enum — reintroduces the
  thing R6 forbids, even if nothing reads it yet. **Keep `restart_level()`
  parameterless.**
- **`_on_kill_area_2d_body_entered` currently sets `body.player_died = true` before
  calling `restart_level()`** (`main.gd`). That write is a cause-specific side
  channel and it happens *outside* the guard, so it still runs on a death that is
  then refused. Two problems in one line. Remove it, or if `player_died` is genuinely
  needed by something, set it identically from all three causes and move it inside
  the guard. Check what reads `player_died` before deciding — do not delete a field
  another system depends on without looking.
- **`spike_hazard`'s `inc_hazard_dmg` connects straight to `restart_level`**
  (`main.gd`'s hazard loop). That is already the correct shape. Do not "improve" it
  into a signal that carries a payload.
- **`OxygenDrain` retains its own `level_complete` check.** Deliberate redundancy,
  not an oversight: ADR-0002 assigns the oxygen kill *decision* to `OxygenDrain`, and
  the chokepoint is a backstop for every path — including ones added later by an
  author who never reads the ADR. Nothing to do here; recorded so it is not
  simplified away.
- **Oxygen death lands one physics frame later than the other two, and that is
  correct.** D5.2's deferral costs 16.6 ms at 60 FPS — below the threshold of
  perception. R6 asks that the causes be indistinguishable, not that they be
  simultaneous. Do not try to defer the hazard paths to match.
- **`suit-oxygen.md` still says oxygen death is "immediate"** while D5.2 defers it one
  frame by design. That conflict is recorded as an open item in `tr-registry.yaml`
  (`TR-oxygen-003`, severity `gdd_conflict`) and is **not** this story's to resolve.
  Implement the ADR; do not edit the GDD.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 002**: the guard itself. This story assumes it exists and tests what flows
  through it.
- **Story 004**: the hold and the pause. This story asserts all three causes use the
  same one; it does not build it.
- **`oxygen-drain` story 003**: `OxygenDrain`'s arm-and-defer kill policy.
- **The hazards epic**: hazard bodies, collision masks, damage triggers, and
  `TR-hazards-003`.
- **The Presentation HUD epic**: E6, the death sequence's visual content, and
  D14.5's correction to `hud.md`'s stale "Unreachable" row for it.
- **`level-state` story 006**: restart being pure reconstruction. This story does not
  touch what a restart resets.

---

## QA Test Cases

*Story type: **Integration** — automated test specs. The load-bearing shape is a
**parameterised** test: run the identical assertion three times, once per cause, and
compare the results to each other rather than to a hardcoded expectation.*

- **AC-1**: All three causes reach the same chokepoint
  - Given: a loaded level with a spike, a kill area and an `OxygenDrain`
  - When: each cause is triggered in a separate run
  - Then: in all three runs `LevelRoot.restart_level()` was entered exactly once and
    a deferred `reload_current_scene` was queued
  - Edge cases: assert no run reaches `reload_current_scene` by any other route

- **AC-2**: The three runs are indistinguishable *(AC6)*
  - Given: the three runs from AC-1
  - When: the observable state at the moment the sequence begins is captured for each
    — `_transition_pending`, the pause lock, `SceneTree.paused`, the hold duration in
    effect, and any field on `Player` or `LevelRoot` that differs from its
    pre-death value
  - Then: the three captures are **equal to each other**
  - Edge cases: this is the assertion that catches `player_died`. Compare the full
    captured state, not a chosen subset — a subset chosen after the fact would pass
    over exactly the field that differs

- **AC-3**: A refused death leaves no residue
  - Given: a level where `level_complete` has already latched
  - When: each of the three causes fires
  - Then: `restart_level()` returns early in all three, and the state captured in
    AC-2 is **unchanged from before the cause fired** in all three
  - Edge cases: this is where a pre-guard write such as `body.player_died = true`
    fails. It must fail here if it is still present

- **AC-4**: Two causes in one frame yield one sequence
  - Given: a level with no transition pending
  - When: a spike and a kill area both fire within one physics tick, in each of the
    two possible orders
  - Then: exactly one sequence begins in both orders, and the two orders produce
    equal captures
  - Edge cases: add oxygen as a third simultaneous cause; still one

- **AC-5**: Structural — the death path carries no cause
  - Given: `src/scripts/main.gd`, `spike_hazard.gd` and the `OxygenDrain` script
  - When: grepped for `restart_level(` and for `death_reason` / `cause` / `killed_by`
  - Then: every `restart_level` call passes no arguments, the function takes none,
    and no cause-naming identifier exists on the path
  - Edge cases: assert no `print()` on the death path names a cause

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/flow/cause_agnostic_death_test.gd` — must
exist and pass.

> **Runner note.** Include `-a res://tests/integration` and `-c`. `reload_current_scene`
> logging `Parameter "current_scene" is null` headlessly is **not** a failure — an
> existing kill-area test passes while logging it. See `tests/README.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (the guard), Story 004 (the shared driver and duration).
  `oxygen-drain` story 003 must be done before the oxygen leg of AC-1/AC-2 can run;
  the spike and kill-area legs do not need it.
- Unlocks: None
