# Story 003: `PauseController` — sole writer of `SceneTree.paused`, and the set-once pause lock

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (2 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R4 · §5 *"Pause pressed during either
sequence"* · `design/ux/hud.md` § *Paused state*
**Requirement**: `TR-flow-004` *(the mechanism half — the pause writer and the lock.
The sequence that uses them is story 004, and the sequence's **content** is
`TR-flow-005`, a recorded gap owned by the Presentation HUD epic)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> ⚠ **Manifest gap — read the ADR, not only the manifest.**
> `control-manifest.md` is version **2026-08-17** and its header covers ADR-0001
> through ADR-0012. **ADR-0013 and ADR-0014 are not in it.** Every D14.x rule quoted
> below is taken from `docs/architecture/adr-0014-pause-gating-during-terminal-sequences.md`
> directly. When `/create-control-manifest update` next runs, these become manifest
> lines and this note can go. Until then `/story-readiness`'s manifest-version
> comparison will not catch a drift in them.

**ADR Governing Implementation**: ADR-0014: Pause gating and process modes during
terminal sequences (D14.2, D14.4) *(primary)* · ADR-0010: HUD composition, viewport
tracking and pause ownership (D10.6) *(secondary — it declares `PauseController` and
`set_paused()`; this story does not reopen it)*

**ADR Decision Summary**: `PauseController` **remains the sole writer of
`SceneTree.paused`**. `LevelRoot` begins a terminal sequence by calling
`PauseController.set_paused(true)` — a method D10.6 already declares — and never
writes `get_tree().paused` itself. D10.6's ownership claim is not weakened or
shared: it gains a second caller of an existing method. `PauseController` also gains
a **set-once lock**: `LevelRoot` calls `set_pause_locked(true)` at the instant a
terminal sequence begins, and **never clears it**. `toggle_pause()` no-ops while
locked; `set_paused()` does **not**, because the lock exists to refuse *player
input*, not to refuse `LevelRoot` itself — guarding both would deadlock the sequence
at the moment it started.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0014 declares no post-cutoff API and no outstanding
verification. Two facts bind this story:

- **F14.2 — `PROCESS_MODE_INHERIT` resolves chain-wide, and a paused node stops
  processing but keeps rendering.** Certified by ADR-0010 (V-E1). **Do not
  re-search this.** `PauseController` is a **leaf** node at
  `PROCESS_MODE_ALWAYS`; setting `ALWAYS` on an ancestor instead would keep the
  whole subtree live through every pause, with no error and no symptom until
  someone paused.
- **`PROCESS_MODE_WHEN_PAUSED` is the inverse of `PAUSABLE`, not a stronger version
  of it.** It runs *only* while the tree is paused. This has already been applied
  wrongly once on this project and was caught at a gate. Do not reach for it.
- **A gdUnit4 scene test can set `SceneTree.paused` directly.** No pause menu and no
  input action are needed to exercise anything in this story.

**Control Manifest Rules (this layer)**:
- Required: "**`PauseController` (leaf node, `process_mode = PROCESS_MODE_ALWAYS`)
  is the ONLY writer of `SceneTree.paused`.** Every other HUD node stays at the
  default `PROCESS_MODE_INHERIT` (resolves to `PAUSABLE`); only `PauseController`
  and the debug overlay E7 use `PROCESS_MODE_ALWAYS`, and both exemptions are set on
  LEAF nodes only, never the HUD root." — ADR-0010 (D10.6)
- Required *(ADR-0014, not yet in the manifest)*: "`LevelRoot` calls
  `set_pause_locked(true)` at the instant a terminal sequence begins — the same
  instant it sets `_transition_pending` — and never clears it." — ADR-0014 (D14.4)
- Forbidden *(ADR-0014, not yet in the manifest)*: "**Any node other than
  `PauseController` assigning `get_tree().paused`.**" — ADR-0014 (D14.2). Owed to
  `docs/registry/architecture.yaml` at acceptance
- Forbidden: "Never inject a `PauseState` object into `OxygenDrain`/`OxygenState`,
  or add an explicit pause check inside their logic." — ADR-0008
  (`oxygen_pause_state_object`)

---

## Acceptance Criteria

*From ADR-0014 D14.2/D14.4 and `level-flow.md` §5:*

- [ ] `PauseController` exists as a leaf node with
      `process_mode = PROCESS_MODE_ALWAYS`, set on the node itself and on no
      ancestor
- [ ] Its public API is exactly: `set_paused(value: bool)`,
      `toggle_pause()`, `set_pause_locked(value: bool)`, and a read-only
      `is_paused` property
- [ ] `set_paused(true)` sets `SceneTree.paused` true; `set_paused(false)` sets it
      false — and it does so **while locked**, unchanged
- [ ] `toggle_pause()` is a no-op while `_pause_locked` is true: `SceneTree.paused`
      is unchanged and no signal is emitted
- [ ] `toggle_pause()` behaves normally while unlocked
- [ ] `PauseController` holds no reference to `LevelRoot` and does not read
      `_transition_pending`. The lock is a **local flag**, set through a one-way
      setter
- [ ] No path clears the lock. There is no `set_pause_locked(false)` caller in `src/`
- [ ] No node other than `PauseController` assigns `get_tree().paused` anywhere in
      `src/`

*Explicitly NOT closed by this story — do not tick these anywhere:*

- **`level-flow.md` AC11** and R4's player-facing announcement need the sequence
  itself. Story 004.
- **No `pause` input action is bound here.** ADR-0014 D14.6 leaves the binding — and
  whether it is remappable alongside the five gameplay actions — owed by
  `design/ux/pause-menu.md`. **Binding it is Blocked on UX, not deferred by
  laziness.** The mechanism is exercised by calling the methods directly.
- **No pause menu is rendered.** D10.6 renders none and D14.6 renders none. The
  node-level contract for menu screens is unowned — `interaction-patterns.md` **O9**,
  owner technical-director, inherited by the Presentation HUD / pause-menu epic.

---

## Implementation Notes

*Derived from ADR-0014 D14.2 and D14.4:*

- **The shape is given in the ADR:**

  ```gdscript
  class_name PauseController extends Node

  var _pause_locked: bool = false

  func set_pause_locked(value: bool) -> void
  func toggle_pause() -> void      # no-ops while _pause_locked
  func set_paused(value: bool) -> void
  var is_paused: bool
  ```

- **`toggle_pause()` is guarded, `set_paused()` is not — and that asymmetry is the
  decision, not an oversight.** Record it in a comment at the guard so a later reader
  does not "fix" the inconsistency and deadlock the sequence.
- **The lock is never cleared, and that is correct.** Both endings terminate the
  level instance — completion transitions to another scene, death calls
  `reload_current_scene()`. The lock dies with the scene it was set in. A controller
  that cleared the lock would have to know *when* the sequence ended, which is a
  second piece of shared state for no benefit. This mirrors R2's write-once latch and
  R8's total reset: nothing carries across the boundary, so nothing needs unwinding.
- **A local flag, not a read of `_transition_pending`.** Guarding on ADR-0005's flag
  would be equivalent in behaviour but would give `PauseController` a dependency on
  `LevelRoot`'s internals, which ADR-0002's injection contract would then have to
  carry. A one-way setter costs nothing and creates no coupling in the reverse
  direction.
- **Where the node lives.** `PauseController` is a HUD-tier leaf under ADR-0010, and
  no HUD scene exists yet. Instance it wherever the sequence driver can reach it in
  story 004 and leave a comment naming ADR-0010 D10.6 as the owner of its eventual
  home. **Do not** make it an autoload — that would put a second global beside
  `GravityAuthority` for a per-level concern, and ADR-0002 bans reaching level-scoped
  state through an autoload.
- **`OxygenDrain` gets nothing here.** Its pause behaviour is structural: default
  `INHERIT` resolving to `PAUSABLE` (ADR-0008 §2, `oxygen-drain` story 006). This
  story writes `SceneTree.paused`; the drain halting is the engine's consequence, not
  code anyone adds.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 002**: `_transition_pending`. Set at the same instant, deliberately a
  separate flag.
- **Story 004**: the caller. `LevelRoot` calling `set_pause_locked(true)` then
  `set_paused(true)`, the `PROCESS_MODE_ALWAYS` sequence driver, and the hold.
- **The `pause` input action** — Blocked on `design/ux/pause-menu.md` (D14.6).
- **The pause menu's contents and node contract** — unowned, `interaction-patterns.md`
  O9, Presentation HUD / pause-menu epic.
- **E6 / E9 exemptions** — those two HUD elements do not exist. D14.3 grants them
  `PROCESS_MODE_ALWAYS` when the Presentation epic builds them, and D14.5 corrects
  `hud.md`'s stale "Unreachable" rows at the same time. **Do not implement against
  the stale `hud.md` rows.**
- **`oxygen-drain` story 006**: proving pause halts the drain, and the
  `LevelRoot`-ancestor `process_mode` invariant that makes it true.

---

## QA Test Cases

*Story type: **Logic** — automated test specs. These are ADR-0014's V14.2 and part
of V14.5, scoped to the controller alone.*

- **AC-1**: `set_paused` writes the tree flag in both directions
  - Given: an unpaused tree and a `PauseController`
  - When: `set_paused(true)` then `set_paused(false)`
  - Then: `SceneTree.paused` reads true then false, and `is_paused` agrees at each
    step
  - Edge cases: `set_paused(true)` twice is idempotent and raises nothing

- **AC-2**: The lock refuses `toggle_pause()` and only `toggle_pause()` *(V14.2)*
  - Given: a `PauseController` with `set_pause_locked(true)` called and the tree
    paused
  - When: `toggle_pause()` is invoked
  - Then: `SceneTree.paused` is **still true** and nothing was emitted
  - Edge cases: with the tree **unpaused** and locked, `toggle_pause()` must also do
    nothing — the lock refuses input in both directions, not just un-pausing

- **AC-3**: `set_paused()` still works while locked *(the deadlock guard)*
  - Given: a locked `PauseController`
  - When: `set_paused(true)` is called
  - Then: `SceneTree.paused` becomes true
  - Edge cases: `set_paused(false)` while locked also works — the lock never blocks
    `LevelRoot`

- **AC-4**: `toggle_pause()` is normal while unlocked
  - Given: an unlocked `PauseController`, tree unpaused
  - When: `toggle_pause()` twice
  - Then: paused, then unpaused

- **AC-5**: The lock is one-way and never cleared
  - Given: the whole of `src/`
  - When: grepped for `set_pause_locked`
  - Then: every call site passes `true`; no call passes `false`, and no internal path
    assigns `_pause_locked = false`
  - Edge cases: assert `PauseController` contains no reference to `LevelRoot`,
    `_transition_pending`, or `level_state`

- **AC-6**: Structural — sole writer *(V14.2's forbidden pattern)*
  - Given: the whole of `src/`
  - When: grepped for assignments to `get_tree().paused` / `SceneTree.paused` /
    `.paused =`
  - Then: the only match is inside `PauseController.set_paused()`
  - Edge cases: also assert `process_mode` is set on the `PauseController` node
    itself and that its parent chain is left at `INHERIT`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/flow/pause_controller_test.gd` — must exist and
pass.

> **Runner note.** Include `-a res://tests/integration` and `-c`; the unit-only
> command was the documented one until **2026-08-24** and silently excluded 8
> integration cases. See `tests/README.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None. This story is self-contained and can start before stories 001
  and 002.
- Unlocks: Story 004, Story 005
