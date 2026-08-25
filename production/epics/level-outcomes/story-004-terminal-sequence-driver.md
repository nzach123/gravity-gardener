# Story 004: The terminal-sequence driver — pause, hold, then transition

> **Epic**: Level Outcomes
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (3-4 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/level-flow.md` §3 R4 · §4 *Sequence duration* · §5
*"Pause pressed during either sequence"* · §7 · §8 AC11
**Requirement**: `TR-flow-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> ⚠ **Manifest gap.** `control-manifest.md` is version **2026-08-17** and covers
> ADR-0001–ADR-0012. **ADR-0014 is not in it.** Every D14.x rule below comes from
> `docs/architecture/adr-0014-pause-gating-during-terminal-sequences.md` directly.

> ⚠ **`complete_hold_duration` is ⚠ unset and must stay ⚠ unset.**
> `level-flow.md` §7 proposes **0.6 s** and calls it a starting value needing a
> playtest. ADR-0014 **D14.6 refuses to fix the number** and says why: inventing one
> would be exactly the kind of unsourced value this project has been declining.
> Ship the mechanism with the value exported and 0.6 s as its **default**. **Do not
> record the value as chosen**, and do not let a passing test or an agent-run
> playthrough be read as confirmation — agent-driven playtests do not settle pacing
> questions. Range: 0.2–1.5 s.

**ADR Governing Implementation**: ADR-0014: Pause gating and process modes during
terminal sequences (D14.1, D14.3, D14.4) *(primary)* · ADR-0005 (D5.4)
*(secondary — the sequence begins at the instant `_transition_pending` is set)* ·
ADR-0008 *(secondary — the drain halting is a structural consequence of the pause,
not code this story writes)*

**ADR Decision Summary**: R4's "game systems paused" **is** `SceneTree.paused` — not
a second suspension mechanism built alongside it. The alternative, having `LevelRoot`
directly stop the player, the drain and the HUD, was rejected because it reintroduces
precisely the bespoke pause-check code **ADR-0008 was accepted for not having**: the
drain would gain two ways to stop, only one structural, and the weaker one would be
the one running during the two moments that matter most. `LevelRoot` begins a
sequence by calling `PauseController.set_pause_locked(true)` then
`PauseController.set_paused(true)`, holds, then transitions. Exactly **three** nodes
take `PROCESS_MODE_ALWAYS`, set on **leaf nodes only**; the sequence driver is one of
them, and without it the hold cannot end.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Three facts bind this story, and the first is
the most consequential in ADR-0014:

- **F14.1 — `SceneTree.create_timer()`'s `process_always` parameter defaults to
  `true`, and a timer at that default keeps counting while `SceneTree.paused` is
  true.** Verified against the live class documentation on 2026-08-18. **The default
  is under active proposal to change** — `godot-proposals` **#9924** proposes
  flipping it to `false`. The proposal is open, not merged. **ADR-0014 therefore
  forbids relying on the default in either direction.** Code that relies on it is
  code whose pause behaviour silently inverts on an engine upgrade, in the one path
  where the failure is invisible.
- **F14.2 — `PROCESS_MODE_INHERIT` resolves chain-wide.** Any ancestor with a
  non-`INHERIT` mode silently changes what every `INHERIT` descendant resolves to,
  with no compile error and no symptom until the tree is actually paused. Certified
  by ADR-0010 V-E1. **Do not re-search this.**
- **A `Timer` node child of an `ALWAYS` node inherits `ALWAYS`** and is the preferred
  form, because its behaviour is visible in the scene tree rather than in an argument
  default.

**Control Manifest Rules (this layer)**:
- Required *(ADR-0014, not yet in the manifest)*: "The `LevelRoot` sequence driver,
  **E6** and **E9** take `PROCESS_MODE_ALWAYS`. **Set on leaf nodes only.** Every
  other node keeps `INHERIT`. **No fourth exemption is granted**, and adding one
  later is a decision, not an implementation detail." — ADR-0014 (D14.3)
- Required *(ADR-0014, not yet in the manifest)*: "The hold must not be timed by a
  bare `SceneTree.create_timer()` relying on the default. If `create_timer()` is
  used, `process_always` is passed **explicitly**, never omitted." — ADR-0014 (D14.3,
  F14.1)
- Required *(ADR-0014, not yet in the manifest)*: "`PauseController` is the sole
  writer of `SceneTree.paused`; `LevelRoot` calls `set_paused(true)`, never
  `get_tree().paused = true`." — ADR-0014 (D14.2)
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH paths must check and set it." — ADR-0005 (D5.4)
- Required: "Gameplay values must be data-driven (external config), never
  hardcoded." — `.claude/docs/coding-standards.md`
- Forbidden: "Never inject a `PauseState` object into `OxygenDrain`/`OxygenState`,
  or add an explicit pause check inside their logic." — ADR-0008
  (`oxygen_pause_state_object`)

---

## Acceptance Criteria

*From `design/gdd/level-flow.md` §3 R4, §4 and ADR-0014's Validation Criteria:*

- [ ] **R4** — A terminal sequence plays on the latch: the tree pauses, a hold
      elapses, then the transition fires. This is the player's only confirmation
      that the level ended
- [ ] The sequence begins by calling, in this order: `_transition_pending = true`,
      `PauseController.set_pause_locked(true)`, `PauseController.set_paused(true)`
- [ ] **V14.1** — The sequence completes *while paused*: after `t_hold` the
      transition fires. A hold that cannot advance is a hard lock and this criterion
      is what catches it
- [ ] **V14.2** — `toggle_pause()` invoked during the hold leaves `SceneTree.paused`
      true and the transition still fires on schedule
- [ ] **V14.4** — No `create_timer()` call in the sequence path omits
      `process_always`. A `Timer` node child of the `ALWAYS` driver satisfies this by
      construction and is preferred
- [ ] **V14.5** — `OxygenState.remaining` is unchanged across the hold, with **no
      pause-check code in `OxygenDrain`**
- [ ] The sequence driver is a **leaf** node at `PROCESS_MODE_ALWAYS`; no ancestor
      is given a non-`INHERIT` mode
- [ ] `death_hold_duration` is exported with default **0.35 s** (`hud.md` E6, safe
      range 0.2–0.6 s)
- [ ] `complete_hold_duration` is exported with default **0.6 s** and is documented
      in code as ⚠ **unset — proposed, not chosen** (`level-flow.md` §7, ADR-0014
      D14.6), safe range 0.2–1.5 s
- [ ] Both endings use the same driver. Only the duration and which transition fires
      at the end differ

*Explicitly NOT closed by this story — do not tick these anywhere:*

- **AC11** — "A completion is distinguishable from a hung game by a player who has
  never seen the build, within `complete_hold_duration`" — is **playtest evidence
  the GDD itself marks ADVISORY**, and it depends on the E9 element that does not
  exist yet. It cannot be closed by any automated test here, and it must not be
  closed by an agent playthrough.
- **`TR-flow-005`** (R5 — the sequence does not restate what the player already
  knows) is the sequence's **content**, a recorded `gap` in `tr-registry.yaml` owned
  by the Presentation HUD epic. ADR-0014 owns the pause gating *around* the
  sequence, not what it says. Do not read this story's coverage as covering it.

---

## Implementation Notes

*Derived from ADR-0014 D14.1, D14.3, D14.4:*

- **Prefer a `Timer` node child of the driver over `create_timer()`.** It inherits
  `ALWAYS` from its parent, so the pause behaviour is visible in the scene tree
  instead of hiding in an argument default. If `create_timer()` is used anyway,
  `process_always` is passed **explicitly and literally** — never omitted, never
  relying on the current `true`. #9924 landing must change nothing here.
- **What the pause buys, for free and correctly** — do not re-implement any of it:

  | Node | Mode | Behaviour during the hold |
  |---|---|---|
  | `OxygenDrain` | `INHERIT` → `PAUSABLE` | Drain halts. ADR-0008's guarantee preserved verbatim |
  | `Player` | `INHERIT` → `PAUSABLE` | Movement stops; the sprite holds its last pose |
  | HUD elements, zones | `INHERIT` → `PAUSABLE` | Freeze holding last values — already what `hud.md` § *Paused state* requires |
  | Spent-jug arc (ADR-0012 D12.5) | `INHERIT` → `PAUSABLE` | Freezes. D12.5 claimed no exemption and is granted none |

- **`LevelRoot` never writes `get_tree().paused`.** Every pause goes through
  `PauseController.set_paused()`. Two writers would make "who owns the pause flag" a
  question again after ADR-0008 and ADR-0010 spent two decisions settling it.
- **Set `ALWAYS` on the driver leaf, never on `LevelRoot` itself.** `LevelRoot` is an
  ancestor of `OxygenDrain`, the `Player` and the HUD; giving it `ALWAYS` would
  resolve the whole level to `ALWAYS` and the pause would suspend nothing — with no
  error and no symptom until someone paused. This is F14.2's failure mode exactly,
  and it is the identical constraint D10.6 already imposed on E7.
- **Both durations are exports on the driver for now, and where they finally live is
  not decided here.** `level-flow.md` §7 states plainly that placement faces the same
  question as `hud.md` **Q16** — a fourth tuning resource needing an ADR-0006
  amendment, or `@export` on the level root — and defers it to the Presentation-tier
  ADR that resolves Q16. Use `@export` and leave a comment naming Q16. **Do not
  create a fourth tuning resource here**; that would decide Q16 by implementation.
- **The transition at the end of the hold is whatever the ending already does** —
  `change_level()` for completion, `reload_current_scene()` for death. Story 006 owns
  what `change_level()` advances *to*. This story only moves the call to the far side
  of the hold.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 003**: `PauseController` itself, its API and the lock. This story is its
  caller.
- **Story 002**: `_transition_pending`. Set at the same instant; already landed.
- **Story 005**: making the three death causes produce an identical sequence.
- **Story 006**: which scene `change_level()` advances to.
- **E6 and E9** — the death and level-complete HUD elements. They do not exist. D14.3
  grants them `PROCESS_MODE_ALWAYS` and D14.5 corrects `hud.md`'s stale "Unreachable"
  rows for both; the **Presentation HUD epic** does that work. **Do not implement
  against the stale `hud.md` rows, and do not build a placeholder element here** —
  R5 (`TR-flow-005`) governs its content and is unowned.
- **Any transition *effect*.** `t_transition` is ⚠ unset and no effect is specified.
  The instant `change_scene_to_packed` is **the current shipped behaviour and is not
  a defect**. Treat a transition effect as new scope, not as this epic finishing an
  unfinished thing.
- **Binding a `pause` input action** — Blocked on `design/ux/pause-menu.md` (D14.6).

---

## QA Test Cases

*Story type: **Integration** — automated test specs, one per ADR-0014 Validation
Criterion, plus the playtest that is deliberately **not** automated.*

- **AC-1**: The sequence completes while paused *(V14.1 — catches the hard lock)*
  - Given: a loaded level with the driver wired
  - When: a terminal sequence begins, `SceneTree.paused` is asserted true, and the
    test advances past `t_hold`
  - Then: the transition fires
  - Edge cases: run for both durations; assert the transition does **not** fire
    before `t_hold` elapses

- **AC-2**: Pause input is refused for the duration *(V14.2 — tests `level-flow.md` §5)*
  - Given: a terminal sequence in progress
  - When: `PauseController.toggle_pause()` is invoked mid-hold
  - Then: `SceneTree.paused` is still true **and** the transition still fires on
    schedule
  - Edge cases: invoke `toggle_pause()` three times across the hold; the elapsed
    hold must be unaffected

- **AC-3**: The chain-wide hazard is detected, not assumed *(V14.3, adapted — a
  negative control)*
  - Given: the driver at `ALWAYS` and its ancestors at `INHERIT`
  - When: the test asserts the driver keeps processing while paused; **then** sets a
    non-`INHERIT` mode on an ancestor and **asserts the test fails**
  - Then: both halves hold. A test that only checks the happy path passes by luck,
    and F14.2's failure mode is invisible without the negative half
  - Edge cases: assert `LevelRoot` itself is **not** `ALWAYS` — if it were, the pause
    would suspend nothing and AC-4 would pass for the wrong reason

- **AC-4**: ADR-0008 is still structural *(V14.5)*
  - Given: a level with `OxygenDrain` at its default `INHERIT`
  - When: a terminal sequence pauses the tree and the hold elapses
  - Then: `OxygenState.remaining` is identical before and after
  - Edge cases: grep `OxygenDrain` and `OxygenState` for `paused` / `PauseState` —
    there must be no match. The drain must halt because of the engine, not because of
    a check

- **AC-5**: The timer flag is explicit *(V14.4 — guards against #9924 landing)*
  - Given: every file on the sequence path
  - When: grepped for `create_timer(`
  - Then: either there are no matches (a `Timer` node is used) or every match passes
    `process_always` explicitly
  - Edge cases: also assert the `Timer` node, if used, is a child of the `ALWAYS`
    driver and not of a `PAUSABLE` node

- **AC-6**: The durations are exported and neither is hardcoded
  - Given: the driver script
  - When: inspected
  - Then: `death_hold_duration` defaults to 0.35 and `complete_hold_duration` to 0.6,
    both `@export`, and neither literal appears anywhere else on the sequence path
  - Edge cases: assert the `complete_hold_duration` comment records it as ⚠ unset /
    proposed, not chosen

**Manual check — AC11 *(ADVISORY, and it does not close in this story)***
  - Setup: a build with the completion sequence wired, given to a player who has
    never seen it
  - Verify: whether the player reads the hold as "I won" rather than "it froze"
  - Pass condition: **a real human playtest session says so.** An agent playthrough
    does not settle this and must not be recorded as evidence. Until then
    `complete_hold_duration` stays ⚠ unset — the epic's Definition of Done names
    silent promotion to "chosen" as a failure mode by name.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/flow/terminal_sequence_test.gd` — must exist and pass
- `production/qa/evidence/complete-hold-duration-playtest.md` — human playtest,
  **ADVISORY**, for AC11 and the `complete_hold_duration` value. Not a blocker for
  this story; **is** a blocker for recording the value as chosen.

> **Runner note.** The command changed on **2026-08-24** and must include
> `-a res://tests/integration` — unit-only was documented until then and silently
> excluded 8 integration cases, including BUG-0001's regression guard. Use `-c` too.
> See `tests/README.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`_transition_pending`), Story 003 (`PauseController` and the
  lock)
- Unlocks: Story 005, Story 006
