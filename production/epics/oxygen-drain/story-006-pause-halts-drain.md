# Story 006: Pause halts drain, and the `LevelRoot`-ancestor `process_mode` invariant

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §5 ·
`design/accessibility-requirements.md` T9
**Requirement**: `TR-oxygen-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **`TR-oxygen-006`'s ownership was corrected twice and the registry records
> both.** It once read `adr: null, adr_status: unowned — NO ADR CLAIMS THIS`;
> ADR-0008 owns it now because it owns `OxygenDrain`. ADR-0010 owns *toggling*
> `get_tree().paused` — a dependency, not a split ownership claim. A second
> correction (2026-08-16) removed a wrong claim that HUD Controls take a
> `PROCESS_MODE_WHEN_PAUSED` exemption; `WHEN_PAUSED` runs **only** while paused,
> the exact inverse of `PAUSABLE`, and applying it would blank every HUD Control
> during normal play. Read the registry note before touching process modes.

**ADR Governing Implementation**: ADR-0008: Oxygen Drain, Shared Death Path, and
the Accessibility Drain-Rate Override (Decision §2) *(primary)* ·
ADR-0014: Pause gating and process modes during terminal sequences *(secondary —
see the manifest-gap note below)* · ADR-0010 *(dependency only — it owns the
pause toggle and the menu; neither exists yet)*

**ADR Decision Summary**: Pause halts drain **structurally, not by a flag**.
`OxygenDrain` keeps the engine default `PROCESS_MODE_INHERIT`; when
`SceneTree.paused` is true an inherited chain resolves to `PROCESS_MODE_PAUSABLE`
and `_physics_process` is never called, so `drain()` cannot run. No pause-state
object is injected, and no pause check goes inside the logic — ADR-0008 rejected
that explicitly, because `SceneTree.paused` already delivers the guarantee and a
second flag would duplicate an engine promise inside a callback ADR-0005 defined
as having no other branches.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0008 declares no new verification — the
`PROCESS_MODE_INHERIT` / `PROCESS_MODE_PAUSABLE` / `SceneTree.paused` mechanism is
cited in `docs/engine-reference/godot/modules/core.md` § Pause and process modes,
closed by the 2026-08-15 architecture review. Two things to know before starting:

- **`PROCESS_MODE_WHEN_PAUSED` is the inverse of `PAUSABLE`, not a stronger
  version of it.** It runs *only* while the tree is paused. This has already been
  applied wrongly once on this project and caught at a gate. Do not reach for it.
- **A gdUnit4 scene test can set `SceneTree.paused` directly.** No pause menu is
  needed to *pause* — see the scope note below.

**Control Manifest Rules (this layer)**:
- Required: "Pause halts drain via `SceneTree.paused` + the default
  `PROCESS_MODE_INHERIT` (resolves to `PAUSABLE`) — no injected pause-state
  object. `LevelRoot` and every ancestor between `OxygenDrain` and the tree root
  must stay `PROCESS_MODE_INHERIT` (or explicit `PAUSABLE`)." — ADR-0008 (§2)
- Forbidden: "Never inject a `PauseState` object into `OxygenDrain`/`OxygenState`,
  or add an explicit pause check inside their logic." — ADR-0008
  (`oxygen_pause_state_object`)
- Forbidden: "Never set `process_thread_group` away from default on
  `GravityAuthority`, `Player`, or `OxygenDrain`." — ADR-0005
  (`process_thread_group_split_in_frame_chain`)
- **Manifest gap, ADR-0014**: `control-manifest.md` extracts **no rule from
  ADR-0014**. Verified 2026-08-24 — the manifest body cites ADR-0013 (added by
  commit `584e1d8` without regenerating the header) and cites ADR-0014 nowhere at
  all. This epic names ADR-0014 as a constrainer, so this story has an Accepted
  ADR governing it with no manifest rule to quote. **Read ADR-0014 directly.**
  `/create-control-manifest update` is owed; it is a real regeneration, not the
  header edit it was first assumed to be.

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md` §5, scoped to this story:*

- [ ] With `SceneTree.paused = true`, `remaining` is **unchanged** across any
      number of frames, and `_physics_process` is not called at all
- [ ] Unpausing resumes the drain at the same rate, with no catch-up burst and no
      lost frame
- [ ] `OxygenDrain` and `OxygenState` contain **no pause check of any kind** — no
      injected `PauseState`, no `get_tree().paused` read, no flag
- [ ] `OxygenDrain`'s own `process_mode` is the engine default
      (`PROCESS_MODE_INHERIT`)
- [ ] Every ancestor between `OxygenDrain` and the tree root is `INHERIT` or
      explicit `PAUSABLE` — asserted at runtime by walking the chain, not by
      reading the ADR
- [ ] The arm-and-defer state survives a pause: a drain armed on the frame before
      a pause is still armed on unpause, and kills on the first unpaused frame

---

## Implementation Notes

*Derived from ADR-0008 Decision §2:*

- **This story is Ready, and the epic's OPEN risk row is narrower than it
  reads.** ADR-0008 says "recommend a scene test once a pause menu (ADR-0010)
  exists to pause against", and `production/epics/index.md` carries that as an
  open risk. **A test does not need a menu in order to pause** — it sets
  `SceneTree.paused = true` itself. So the automated half of `TR-oxygen-006`
  closes here and now. **Neither ADR-0008 nor the index risk row is amended by
  this story** — this is flagged, per the standing preference for flagging over
  reopening. What genuinely stays owed to the Presentation HUD epic is named in
  Out of Scope below, and the risk row should be narrowed to that, not closed.
- **Write almost no production code.** If stories 002 and 003 were implemented
  correctly, the pause behaviour already holds for free — that is the entire point
  of choosing a structural mechanism over a flag. The deliverable is the test that
  proves it, plus the ancestor-chain assertion that nothing else provides.
- **The ancestor-chain assertion is the real value here.** ADR-0008 states
  plainly that this invariant "is enforced by nothing but this document": a future
  node inserted between `OxygenDrain` and the tree root with a non-`INHERIT`
  process mode silently breaks `TR-oxygen-006` with **no compile error and no
  symptom** until a playtester notices oxygen draining during pause. Walk from
  `OxygenDrain` to the root at runtime and assert each node's `process_mode` is
  `PROCESS_MODE_INHERIT` or `PROCESS_MODE_PAUSABLE`. This is the same hazard shape
  as `process_thread_group_split_in_frame_chain`; assert both in the same test
  while walking the chain.
- **The likely future breaker is a pause menu parented under `LevelRoot`.**
  ADR-0008 names it: an overlay that needs to keep animating while paused gets
  `PROCESS_MODE_ALWAYS`, and if it is placed such that `LevelRoot` inherits that
  change, the drain never stops. The chain assertion is what will catch it — write
  it so the failure message says *which* ancestor and *what* mode, or the next
  author will spend the debugging session ADR-0008 is trying to save them.
- **Read ADR-0014 directly for the terminal-sequence interaction.** The epic
  records that the sequence hold **is** `SceneTree.paused`, so the drain stops
  during it by this same mechanism. There is no manifest rule to quote for it —
  see the gap above.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **A pause menu, a pause toggle, or any UI.** ADR-0010 owns opening and closing
  the pause state. None of it exists yet, and this story does not build a
  placeholder.
- **`accessibility-requirements.md` T9's manual run** — "pause mid-level, wait,
  unpause", currently marked *"Blocked — no pause exists"*, with a pass condition
  that includes "HUD freezes per U10.3". Both halves need ADR-0010. **This story
  closes the automated half only; T9 stays Blocked.**
- **The ancestor-chain regression against a real pause overlay.** The assertion
  written here runs against the level's actual tree; it cannot exercise a pause
  menu that does not exist. When ADR-0010's overlay lands, the Presentation HUD
  epic must run this test with the overlay present. **That is what the epic's
  OPEN risk row should be narrowed to.**
- **Stories 002 and 003**: the callback, the composition, and the kill policy.
- **`level_complete`'s freeze.** That is a different mechanism for a different
  reason — story 003 (D5.6). Pause and completion both stop the drain; do not
  merge the two paths.

---

## QA Test Cases

*Story type: **Integration** — automated test specs.*

- **AC-1 — a paused tree does not drain**
  - Given: a bound `OxygenDrain` in a live scene tree, mid-level
  - When: `SceneTree.paused` is set true and many physics frames are stepped
  - Then: `remaining` is **exactly** unchanged, and `_physics_process` recorded
    zero calls
  - Edge cases: assert the call count, not only `remaining`. An implementation
    that runs the callback and drains by zero passes a `remaining` check and
    fails the structural guarantee — and it is what a pause *flag* would look
    like.

- **AC-2 — unpausing resumes cleanly**
  - Given: a level paused for many frames
  - When: `SceneTree.paused` is set false and stepping continues
  - Then: the drain resumes at the same per-frame amount, with no accumulated
    catch-up on the first unpaused frame
  - Edge cases: the first frame after unpause is the one to check. Godot supplies
    a normal fixed `delta` there, but a hand-rolled elapsed-time calculation would
    not — and this AC is what would catch someone reintroducing one.

- **AC-3 — no pause check exists in the logic**
  - Given: `oxygen_drain.gd` and `oxygen_state.gd`
  - When: searched for `paused`, `PauseState`, `get_tree().paused`
  - Then: no match in either
  - Edge cases: capture the match and branch on emptiness — a bare `grep` exits
    `1` on no match and passes forever. This is `oxygen_pause_state_object`, and
    the tempting shape is a "harmless" defensive check added alongside an
    unrelated fix.

- **AC-4 — the ancestor chain is `INHERIT` or `PAUSABLE` all the way up**
  - Given: a loaded level with `OxygenDrain` in place
  - When: the chain from `OxygenDrain` to the tree root is walked
  - Then: every node's `process_mode` is `PROCESS_MODE_INHERIT` or
    `PROCESS_MODE_PAUSABLE`
  - Edge cases: assert `OxygenDrain`'s own mode is the default `INHERIT`
    specifically, not merely "one of the two" — an explicit `PAUSABLE` on the node
    itself would work today but silently detaches it from the chain the invariant
    is about. Include `process_thread_group` in the same walk. Make the failure
    message name the offending node and its mode.

- **AC-5 — an armed kill survives a pause**
  - Given: a drain armed on the frame before the pause (`remaining` at `0.0`,
    `_death_armed` true)
  - When: the tree is paused for many frames, then unpaused
  - Then: no restart fired while paused, and the restart fires on the first
    unpaused callback
  - Edge cases: this is the interaction between two mechanisms that were designed
    separately — the D5.2 deferral and the structural pause. Nothing else tests
    them together, and pausing on exactly the arming frame is the case a
    playtester would find first.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/oxygen/pause_halts_drain_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (the callback) · Story 003 (the arm-and-defer state
  AC-5 exercises) · `level-state` story 004 (`LevelRoot` and the tree shape AC-4
  walks).
- **Unlocks**: None in this epic. It closes `TR-oxygen-006`'s automated half and
  narrows the epic's one OPEN risk to the overlay regression named in Out of Scope.
