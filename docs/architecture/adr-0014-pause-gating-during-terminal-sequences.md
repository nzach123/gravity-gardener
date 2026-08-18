# ADR-0014: Pause gating and process modes during terminal sequences

## Status

**Accepted** — 2026-08-18

Resolves the conflict recorded as **open item 3** in `production/session-state/active.md`:
`design/gdd/level-flow.md` §5 takes a stance on pause during the completion and death
sequences, and ADR-0010 owns pause routing, and the two had never been reconciled.
`level-flow.md` §6 names the reconciliation as owed: *"ADR-0010 — Owns pause routing.
The §5 pause-during-sequence stance needs its agreement."*

Raised during `/ux-design pause-menu` (step 2b of the pre-production gate), because the
pause-menu spec cannot state what pause does without this ruling.

## Date

2026-08-18

## Last Verified

2026-08-18

## Decision Makers

user (binding), technical-director, ux-designer

## Summary

`level-flow.md` R4 requires the completion and death sequences to play as "a brief hold
with game systems paused," but never says what that pause *is*; ADR-0010 D10.6 gives
`SceneTree.paused` to `PauseController` with an unconditional toggle and assigns every
player-facing HUD element `PROCESS_MODE_INHERIT`, which includes the two elements those
sequences exist to display. This ADR rules that the sequence hold **is** `SceneTree.paused`,
written only through `PauseController`, with exactly three leaf nodes exempted to
`PROCESS_MODE_ALWAYS` and a set-once pause lock that makes `level-flow.md` §5's "ignored
for the duration" stance structural rather than advisory.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (`SceneTree` pause, `Node.process_mode`), UI adjacent |
| **Knowledge Risk** | **LOW.** `Node.process_mode` and its five `PROCESS_MODE_*` values are 4.0 APIs whose semantics ADR-0010 already certified stable 4.0 → 4.7.1 (its V-E1, marked CONFIRMED). `SceneTree.paused` is older still. The one fact this ADR adds — `SceneTree.create_timer()`'s `process_always` default — was verified 2026-08-18 against the live docs and the open proposal that would change it. |
| **References Consulted** | `docs/engine-reference/godot/modules/core.md` § *Pause and process modes* · `docs/engine-reference/godot/modules/ui-control.md` · ADR-0010 § *Engine facts* (V-E1) · `godotengine/godot-proposals` #9924 |
| **Post-Cutoff APIs Used** | None. Every API named here predates the training cutoff and is already relied on by ADR-0010. |
| **Verification Required** | None outstanding. F14.1 was verified 2026-08-18. F14.2 is inherited from ADR-0010's V-E1 and is **not** to be re-verified. |

### Engine facts this decision rests on

**F14.1 — `SceneTree.create_timer()`'s `process_always` parameter defaults to `true`,
and a timer created at that default keeps counting while `SceneTree.paused` is `true`.**
Verified against the live class documentation on 2026-08-18. This is not a training-data
recollection, and it is the single most consequential fact in this ADR — see D14.3's
hazard note.

**The default is under active proposal to change.** `godot-proposals` #9924 proposes
flipping it to `false`, on the stated grounds that scene-tree timers continuing through a
pause "has been a source of headaches and bugs, seems unintuitive and is inconsistent with
`Tween`." The proposal is open, not merged, as of 2026-08-18. **This ADR therefore forbids
relying on the default in either direction** — D14.3 requires the value be passed
explicitly, so that a future engine change alters nothing here.

- <https://docs.godotengine.org/en/stable/classes/class_scenetree.html>
- <https://github.com/godotengine/godot-proposals/issues/9924>

**F14.2 — `PROCESS_MODE_INHERIT` resolves chain-wide, and a paused node stops processing
but keeps rendering.** Established and certified by ADR-0010, which also records the
hazard that any ancestor with a non-`INHERIT` mode silently changes what every `INHERIT`
descendant resolves to, with no compile error and no symptom until the tree is actually
paused. **Do not re-search this.** D14.3 is built directly on it.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (frame ordering, `_transition_pending`), ADR-0008 (oxygen drain halts structurally on pause), ADR-0010 (owns `SceneTree.paused` and the HUD process-mode table) — all Accepted |
| **Enables** | `design/ux/pause-menu.md`; the `V6`-class pause tests ADR-0010 specified but could not complete |
| **Blocks** | None |
| **Ordering Note** | This ADR **amends no Accepted ADR's text.** It uses `PauseController.set_paused()`, an API ADR-0010 D10.6 already declares, and adds leaf exemptions in the same manner and to the same table D10.6 established for E7. ADR-0010 stays Accepted and unedited — the same non-reopening approach used for ADR-0007 in ADR-0013. |

## Context

### Problem Statement

Three documents each assume another one handles pause during the two sequences that end a
level, and none of them does.

- **`level-flow.md` R4** — "A level-complete sequence plays on the latch: a brief hold with
  game systems paused, then the transition." R6 gives death the same shape.
  **The mechanism is never named.**
- **`level-flow.md` §5** — "Pause pressed during either sequence: **Ignored** for the
  duration of the sequence. ⚠ **New stance** — both sequences already pause game systems,
  so a second pause layer has nothing to halt, but pause routing is owned by ADR-0010 and
  this needs its agreement."
- **ADR-0010 D10.6** — `PauseController` owns `SceneTree.paused` and toggles it
  unconditionally: `get_tree().paused = not get_tree().paused`. It runs at
  `PROCESS_MODE_ALWAYS` so that it can always unpause. Its table assigns
  *"the `HUD` root, the Z1/Z2/Z3 layers, and every player-facing element"* the default
  `INHERIT`, resolving to `PAUSABLE`.
- **`hud.md`** places E6 (death sequence) and E9 (level-complete sequence) in **Z3**, and
  gives both a duration measured in a hold — 0.35 s and a proposed 0.6 s — during which
  they must actually play.

§5's reasoning is inverted. It argues a second pause layer has nothing to *halt*. The
exposure is the opposite: `PauseController` is one of the very few things still processing
while the tree is paused, so a pause press during a sequence **un**-halts a game that a
terminal sequence has already stopped, while a scene transition is pending.

### The circular row in `hud.md`

`hud.md`'s *Paused state* table resolves E6 and E9 as:

> | E6 | Unreachable — the death sequence already pauses game systems itself |
> | E9 | Unreachable — the completion sequence already pauses game systems itself |

This is circular. It excludes E6/E9 from the paused state by citing the sequences' own
pause — but if that pause is `SceneTree.paused`, it is the *same* pause, and E6/E9 are
`PAUSABLE` player-facing elements caught by it. The rows do not describe a resolved case;
they describe the unexamined one.

### Two failure modes, and the quieter one is worse

Taken together with F14.1, the unspecified mechanism produces two distinct defects
depending on an implementation detail nobody has chosen yet:

| If the hold is timed by | What happens | Severity |
|---|---|---|
| A **`Timer` node** (respects `process_mode`) | The timer freezes with everything else. `t_hold` never elapses, the transition never fires, `_transition_pending` stays `true` forever | **Hard lock.** Loud, and would be caught the first time anyone completed a level |
| **`SceneTree.create_timer()`** at its default `process_always = true` (F14.1) | The timer keeps counting. E6/E9 freeze at their first frame, the hold elapses invisibly, and the transition fires exactly on schedule | **Silent visual freeze.** The player sees a still frame and then a cut. It looks nearly correct, and it would ship |

The second is the one this ADR is most concerned with. It produces no error, no warning,
and no stall — only the loss of the two elements that `level-flow.md` R4 says are *"the
player's only confirmation that the level ended."* That is the exact failure the vertical
slice already suffered once, in a different form, and E9 exists because of it.

### Current State

`src/` contains no HUD scene, no `PauseController`, no `LevelRoot` sequence driver, and no
pause handling of any kind. No terminal sequence is implemented. This ADR therefore
specifies new code rather than changing behaviour, and **applies nothing** — the same
posture as ADR-0011 D11.6 and ADR-0013's migration plan.

`project.godot` declares five input actions — `move_left`, `move_right`, `interact`,
`jump`, `crouch` — and **no pause action**. Binding one is owed by `design/ux/pause-menu.md`,
not by this ADR.

## Decision

### D14.1 — R4's "game systems paused" **is** `SceneTree.paused`

The terminal-sequence hold uses the engine's own pause, not a second suspension mechanism
built alongside it.

The alternative — having `LevelRoot` directly stop the player, the drain, and anything
else that must hold — was rejected because it reintroduces precisely the bespoke
pause-check code that **ADR-0008 was accepted for not having.** ADR-0008's structural
guarantee is that `OxygenDrain` keeps its default `INHERIT`, so `SceneTree.paused` halts
the drain with no pause-check code anywhere. A parallel suspension path would mean the
drain has two ways to stop, only one of which is structural, and the weaker one would be
the one running during the two moments that matter most.

Using the engine pause buys the whole suspension for free and correctly:

| Node | Mode | Behaviour during the hold |
|---|---|---|
| `OxygenDrain` | `INHERIT` → `PAUSABLE` | Drain halts. ADR-0008's guarantee preserved verbatim |
| `Player` | `INHERIT` → `PAUSABLE` | Movement stops; the sprite holds its last pose (see *Consequences*) |
| E1–E5, E8, HUD root, Z1/Z2/Z3 | `INHERIT` → `PAUSABLE` | Freeze holding last values — already what `hud.md` § *Paused state* requires |
| Spent-jug arc (ADR-0012 D12.5) | `INHERIT` → `PAUSABLE` | Freezes. D12.5 claimed no exemption and is granted none |

### D14.2 — `PauseController` remains the sole writer of `SceneTree.paused`

`LevelRoot` begins a terminal sequence by calling **`PauseController.set_paused(true)`** —
a method **ADR-0010 D10.6 already declares** in its public API. It never writes
`get_tree().paused` itself.

This is what keeps the ADR from reopening ADR-0010. D10.6's ownership claim is not
weakened, contradicted, or shared: it gains a second caller of an existing method. Two
writers to `SceneTree.paused` would have made "who owns the pause flag" a question again,
after ADR-0008 and ADR-0010 spent two decisions settling it.

**Forbidden pattern**: any node other than `PauseController` assigning `get_tree().paused`.
Owed to `docs/registry/architecture.yaml` at acceptance.

### D14.3 — Exactly three leaf exemptions, and the timer flag is always explicit

Three nodes take `PROCESS_MODE_ALWAYS`:

| Node | Why |
|---|---|
| The `LevelRoot` sequence driver | It must advance `t_hold` and fire the transition while the tree it paused is paused. Without this the hold cannot end |
| **E6** — death sequence | It is the thing being displayed. `PAUSABLE` freezes it at frame one |
| **E9** — level-complete sequence | Same |

**Set on leaf nodes only.** Per F14.2, `PROCESS_MODE_INHERIT` resolves chain-wide, so
setting `ALWAYS` on the `HUD` root or on the Z3 layer would keep the entire player-facing
HUD live through every pause and break `hud.md` H14 — with no error and no symptom until
someone paused. This is the identical constraint D10.6 already imposed on E7's exemption,
applied identically. E7 keeps its own `ALWAYS` and therefore keeps updating through a
terminal sequence, which is correct for a developer tool.

**Every other node keeps `INHERIT`. No fourth exemption is granted here**, and adding one
later is a decision, not an implementation detail.

**The hold must not be timed by a bare `SceneTree.create_timer()` call relying on the
default.** Whatever timing mechanism the sequence driver uses, the pause behaviour is
stated explicitly at the call site:

- A `Timer` **node** child of the `ALWAYS` sequence driver inherits `ALWAYS` and is the
  preferred form, because its behaviour is visible in the scene tree rather than in an
  argument default.
- If `SceneTree.create_timer()` is used instead, `process_always` is passed **explicitly**,
  never omitted.

The reason is F14.1: the default is `true` today and `godot-proposals` #9924 proposes
changing it to `false`. Code that relies on the default is code whose pause behaviour
silently inverts on an engine upgrade, in the one code path where the failure is invisible.

### D14.4 — A pause lock, set once and never cleared

`PauseController` gains a lock:

```gdscript
class_name PauseController extends Node

var _pause_locked: bool = false

func set_pause_locked(value: bool) -> void
func toggle_pause() -> void      # no-ops while _pause_locked
func set_paused(value: bool) -> void
var is_paused: bool
```

`LevelRoot` calls `set_pause_locked(true)` at the instant a terminal sequence begins — the
same instant it sets ADR-0005 D5.4's `_transition_pending` — and **never clears it.**

This makes `level-flow.md` §5's "ignored for the duration of the sequence" structural
rather than advisory, and it is what closes open item 3. Three properties are worth stating
because each was a choice:

**It is never cleared, and that is correct.** Both endings terminate the level instance —
completion transitions to another scene, death calls `reload_current_scene()`. The lock
dies with the scene it was set in. A `PauseController` that cleared the lock would need to
know *when* the sequence ended, which is a second piece of shared state for no benefit.
This mirrors R2's write-once latch and R8's total reset: nothing carries across the
boundary, so nothing needs unwinding.

**It is a local flag, not a read of `_transition_pending`.** Guarding on ADR-0005's flag
directly would have been equivalent in behaviour but would give `PauseController` a
dependency on `LevelRoot`'s internals, which ADR-0002's injection contract would then have
to carry. A one-way setter costs nothing and creates no coupling in the reverse direction.

**`toggle_pause()` is guarded, `set_paused()` is not.** The lock exists to refuse *player
input*, not to refuse `LevelRoot` itself — which must be able to call `set_paused(true)`
after locking. Guarding both would deadlock the sequence at the moment it started.

### D14.5 — `hud.md`'s E6/E9 "Unreachable" rows are wrong and are corrected

They are not unreachable. Under D14.3 they are the only two player-facing elements that
keep running while the tree is paused. The corrected rows state that E6/E9 run at
`PROCESS_MODE_ALWAYS` and play through the hold their own Duration fields describe.

Recorded here so the next reader of that table does not implement the stale version — the
same treatment D10.6 gave the `tr-registry.yaml` `WHEN_PAUSED` note. **Owed to `hud.md` at
acceptance.**

### D14.6 — What this ADR deliberately leaves open

- **`complete_hold_duration` stays ⚠ unset.** `level-flow.md` §7 proposes 0.6 s and calls
  it a starting value needing a playtest. This ADR fixes the mechanism, not the value, and
  inventing one here would be exactly the kind of unsourced number the project has been
  refusing.
- **The pause input action.** No `pause` action exists in `project.godot`. Binding it, and
  deciding whether it is remappable alongside the five gameplay actions, is owed by
  `design/ux/pause-menu.md`.
- **What the pause menu contains, and how it is instanced.** D10.6 states it "renders no
  menu," and this ADR renders none either. The node-level contract for menu screens is
  unowned — `interaction-patterns.md` **O9**, owner technical-director.
- **`level-flow.md` R10** — what happens after the final level — is untouched. It remains
  ⚠ TBD.

## Alternatives Considered

**A — A bespoke suspension mechanism, separate from `SceneTree.paused`.** `LevelRoot`
stops the player, the drain and the HUD directly for the duration.
*Rejected by D14.1.* It gives `OxygenDrain` a second, non-structural way to stop, which is
the precise property ADR-0008 was accepted for eliminating. It also requires every system
added later to remember to participate, with nothing enforcing it.

**B — Guard `toggle_pause()` by reading ADR-0005's `_transition_pending`.** Behaviourally
identical to D14.4.
*Rejected.* It couples `PauseController` to `LevelRoot`'s internal state across a boundary
ADR-0002's injection contract would then have to carry. The set-once lock achieves the same
refusal with a one-way call and no reverse dependency.

**C — Remove `PROCESS_MODE_ALWAYS` from `PauseController` so it cannot fire during a
paused sequence.** *Rejected.* D10.6 gives it `ALWAYS` because it must be able to unpause;
a `PAUSABLE` `PauseController` can pause the game and then never release it. The problem is
the toggle's unconditionality, not its process mode.

**D — Let the pause menu open during a terminal sequence, and simply not let it resume.**
*Rejected.* It offers the player a control that visibly does nothing, during the 0.35–0.6 s
window in which they are being told the level ended. `level-flow.md` §5 already took the
opposite stance and this ADR ratifies it rather than overturning it.

**E — Amend ADR-0010 D10.6 in place.** *Rejected on process grounds.* ADR-0010 is Accepted.
The project's established mechanism for extending an Accepted ADR without reopening it —
used for ADR-0002 over ADR-0001, and for ADR-0013 over ADR-0007 — is a new ADR plus a
registry entry. Nothing in D10.6 is contradicted here, so nothing in it needs editing.

## Consequences

### Positive

- **Open item 3 closes.** `level-flow.md` §5's stance is ratified and made structural, and
  its ⚠ can be removed.
- **ADR-0008's structural drain-halt survives untouched.** No second suspension path.
- **ADR-0010 is extended without being edited.** `PauseController` stays the single owner
  of `SceneTree.paused`; the exemption list grows by the same mechanism D10.6 established.
- **A silent, shippable defect is closed before any code exists.** The `process_always`
  interaction (F14.1) would not have surfaced in review, in a headless run, or in most
  playtests — a frozen 0.35 s effect followed by an on-schedule transition looks like a
  design choice.
- **`art-bible.md` §5.4's death-pose item closes at no cost.** The `Player` stays
  `PAUSABLE`, so the sprite freezes holding its last pose for the whole of E6 —
  structurally, with no death animation authored and no clip added to the sheet. §5.4
  recommended exactly this ("the sprite holds its last pose and the full-viewport E6 effect
  carries the beat") and marked it *"a recommendation, not a decision"* pending
  ux-designer and UI-programmer agreement, because E6 belongs to `hud.md`/ADR-0010. The
  process-mode assignment supplies that agreement. **Owed to `art-bible.md` §5.4 at
  acceptance.**

### Negative

- **Three more nodes carry a non-default process mode**, and F14.2's chain-wide hazard
  applies to every one of them. The mitigation is the leaf-only rule and V14.3 below, not
  vigilance.
- **The `ALWAYS` sequence driver is a node that keeps running through *every* pause**,
  including an ordinary player-initiated one. It is inert in that state because it only
  acts while a sequence is in progress, but it is a live node in a paused tree and should
  be written accordingly.
- **The lock is unrecoverable within a level instance.** Correct, per D14.4, but it means a
  bug that sets it early makes the level unpausable with no in-game recovery. V14.2 exists
  for this.

### Neutral

- Nothing in `src/` changes. This ADR is specified, not applied.

## GDD Requirements Addressed

| Document | Requirement | How |
|---|---|---|
| `design/gdd/level-flow.md` | **R4** — completion is announced with a hold with game systems paused | D14.1 names the mechanism; D14.3 keeps E9 running through it |
| `design/gdd/level-flow.md` | **R6** — death is cause-agnostic, same sequence | Same treatment for E6; no path distinguishes the three causes |
| `design/gdd/level-flow.md` | **§5** — pause ignored during either sequence | **D14.4**, and structurally rather than by convention |
| `design/gdd/level-flow.md` | **R9** — both endings route through one guarded chokepoint | Unchanged. The lock is set at the same instant as `_transition_pending`, not in place of it |
| `design/ux/hud.md` | **E6, E9** — durations, and the § *Paused state* table | **D14.3**, **D14.5** |
| `design/ux/hud.md` | § *Paused state* — "the HUD freezes, nothing hides, nothing dims" | Preserved for E1–E5 and E8 by leaving them `INHERIT` |
| `design/accessibility-requirements.md` | **T9** — pause halts drain | Unaffected and preserved; ADR-0008's `INHERIT` is untouched |
| `design/art/art-bible.md` | **§5.4** — death pose | Closed as a consequence, see above |

## Performance Implications

None measurable. Three additional nodes evaluate a process mode per frame, and one boolean
is checked per pause input. `SceneTree.paused` is engine-side and already in use by
ADR-0008 and ADR-0010.

## Migration Plan

**Nothing is applied by this ADR.** `src/` has no `PauseController`, no `LevelRoot`
sequence driver, no HUD scene, and no terminal sequence, so there is no existing behaviour
to migrate. The steps below are for whoever implements ADR-0010 and `level-flow.md`, and
belong in the story that does so.

1. Add `_pause_locked`, `set_pause_locked()`, and the `toggle_pause()` guard to
   `PauseController` (D14.4).
2. Have `LevelRoot` call `set_pause_locked(true)` and `PauseController.set_paused(true)` at
   the same point it sets `_transition_pending` (D14.2, D14.4).
3. Set `PROCESS_MODE_ALWAYS` on the sequence driver, E6, and E9 — **on those leaf nodes
   only** (D14.3).
4. Time the hold with a `Timer` node child of the sequence driver, or pass `process_always`
   explicitly to `SceneTree.create_timer()` (D14.3).
5. Leave every other node at `INHERIT`.

## Validation Criteria

- **V14.1 — The sequence completes while paused.** Begin a terminal sequence, assert the
  tree is paused, advance past `t_hold`, and assert the transition fires. Catches the
  `Timer`-node hard lock.
- **V14.2 — Pause input is refused for the duration.** Begin a terminal sequence, invoke
  `toggle_pause()`, and assert `SceneTree.paused` is still `true` and the transition still
  fires on schedule. Directly tests `level-flow.md` §5.
- **V14.3 — The chain-wide hazard is detected, not assumed.** Assert E6 and E9 keep
  processing while paused; then set a non-`INHERIT` mode on an ancestor and **assert the
  test fails.** A test that only checks the happy path passes by luck, and F14.2's failure
  mode is invisible without this. Same discipline as ADR-0010's V6.
- **V14.4 — The timer flag is explicit.** A check that no `create_timer()` call in the
  sequence path omits `process_always`. Guards against #9924 landing.
- **V14.5 — ADR-0008 is still structural.** Pause during a terminal sequence and assert
  `OxygenState.remaining` is unchanged across it, with no pause-check code in
  `OxygenDrain`.

## Related Decisions

- **ADR-0005** — Frame ordering and the `level_complete` guard. Supplies
  `_transition_pending` and the single guarded chokepoint. D14.4's lock is set alongside
  it, never instead of it.
- **ADR-0008** — Oxygen drain and shared death path. Its structural pause-halt is the
  reason D14.1 rejects a bespoke suspension mechanism.
- **ADR-0010** — HUD composition, viewport tracking, and pause ownership. Owns
  `SceneTree.paused` and the process-mode table. **Not edited.** This ADR calls the API it
  declared and extends the exemption list it established.
- **ADR-0012** — Spent jug throw. D12.5 claimed no pause exemption; none is granted here on
  its behalf.
- **ADR-0013** — Screen-relative input basis. Precedent for the non-reopening approach used
  here: resolve a cross-document conflict in a new ADR, record the extension in
  `docs/registry/architecture.yaml`, and leave the Accepted ADR's text alone.
