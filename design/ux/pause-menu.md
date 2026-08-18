# UX Specification: Pause Menu

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-18
> **Version**: 1.0
> **Engine**: Godot 4.7.1
> **UI Framework**: Godot Control nodes
> **Design Resolution**: 1152 × 648 — Godot's default, **never authored**
> (`accessibility-requirements.md` **A3**). Owner: `project.godot`
> **Related Documents**:
> - **ADR-0010** — owns `SceneTree.paused` via `PauseController`, and states it
>   *"renders no menu... it owns the state that a future menu will drive."*
>   **This spec is that future menu.** Writing it does not reopen ADR-0010; it fills the
>   hole ADR-0010 deliberately left
> - **ADR-0014** — pause gating and process modes during terminal sequences. Ratifies
>   `level-flow.md` §5 and closes the open item this spec was blocked on
> - **ADR-0005** — `_transition_pending`, the guarded chokepoint
> - `design/gdd/level-flow.md` — R1, R4, R6, R8, §5
> - `design/ux/hud.md` — § *Paused state*. **The binding constraint on this screen**
> - `design/ux/interaction-patterns.md` — **P8**, **P9**; also **P6** (on-demand readout),
>   which makes a claim on the paused state
> - `design/ux/main-menu.md` — this screen's only exit destination other than resuming
> - `design/art/art-bible.md` §2.7, §7.3, **§7.4** — owns this screen's appearance
> - `design/accessibility-requirements.md` — tier Standard; reduced motion and one-hand
>   mode elevated

---

## 1. Purpose & Player Need

The pause menu does two things and deliberately no more: **stop the clock**, and **let the
player leave**.

Stopping the clock is not a convenience in this game — it is the only way to think. The
oxygen budget is the level's timer, and `suit-oxygen.md` requires pausing to halt the
drain, which ADR-0008 delivers structurally. A player mid-route with two buckets left and a
gravity flip to plan cannot get that thinking time any other way.

**Everything else this screen could plausibly offer, it does not.** No settings (deferred
and unowned — §15). No restart (§4). No level select. The screen is two items because two
is what the design actually supports today, and padding it would mean inventing
destinations.

---

## 2. Player Context on Arrival

There is one arrival, but two quite different players take it.

| Question | "Pausing to think" | "Pausing to leave" |
|---|---|---|
| What was the player just doing? | Mid-route — carrying a bucket, planning a flip, watching oxygen | Stuck, frustrated, or done for the session |
| What is their emotional state? | Focused, mildly pressured. The clock was running | Resigned or annoyed |
| What cognitive load are they carrying? | **High, and it is the whole point.** They are holding a route, a bucket count and an oxygen figure in their head | Low. They have stopped planning |
| What information do they already have? | Everything the HUD shows — and they need to keep seeing it | Nothing they need |
| What are they most likely trying to do? | **Read the frozen HUD and resume** | Get to the main menu |
| What are they likely afraid of? | That pausing cost them oxygen, or that resuming will drop their pour | Nothing |

**The first column is why this screen does not dim the background.** The player who pauses
to think is the majority case and the design's actual reason for having a pause at all,
and dimming the HUD would take away the thing they paused to read. This is not a stylistic
preference — see §5.

**Their first fear is unfounded and the second is handled.** ADR-0008 halts the drain
structurally, so `hud.md` E1 holds a value that is *correct*, not stale. An in-progress
pour freezes without the drain-back firing (`hud.md` U10.3) — see §7.3.

---

## 3. Navigation Position

An **overlay** on live gameplay, not a screen replacement. The level stays loaded,
instanced, and visible behind it.

```
    ┌──────────────────┐
    │    MAIN MENU     │ ◄──── Quit to Main Menu ────┐
    └──────────────────┘                             │
             │ Start Game                            │
             ▼                                       │
    ┌──────────────────┐   pause pressed    ┌──────────────────┐
    │    GAMEPLAY      │ ─────────────────► │   PAUSE MENU     │
    │  (level_01 …)    │ ◄───── Resume ──── │    (overlay)     │
    └──────────────────┘                    └──────────────────┘
             │
             │  pause pressed during a completion or death sequence
             └────────►  REFUSED — no menu opens (ADR-0014 D14.4)
```

---

## 4. Entry & Exit Points

### Entry

| Trigger | Source | Transition | Data In | Notes |
|---|---|---|---|---|
| Pause action pressed | Gameplay | Overlay push; `SceneTree.paused` → `true` | None | ⚠ **The action does not exist.** `project.godot` declares only `move_left`, `move_right`, `interact`, `jump`, `crouch`. See §15 PM-Q1 |
| Pause pressed during a terminal sequence | Gameplay | **Refused. Nothing opens** | — | ADR-0014 **D14.4**. `LevelRoot` sets the pause lock at the instant it sets `_transition_pending`, and `toggle_pause()` no-ops while locked |

**The refusal is structural, not a check this screen performs.** That distinction matters:
this spec does not need to know what a terminal sequence is, because the menu is never
asked to open during one. `level-flow.md` §5's "ignored for the duration" stance is
enforced one layer below this screen.

### Exit

| Exit Action | Destination | Transition | Notes |
|---|---|---|---|
| **Resume** | Gameplay | Overlay pop; `SceneTree.paused` → `false` | Also reachable via `ui_cancel` (§7.2) |
| **Quit to Main Menu** | `main-menu.md` | **Unpause, then full scene replace** | **The order is load-bearing — see below** |

> ### The unpause-before-quit rule
>
> **`SceneTree.paused` must be set to `false` before or as part of the scene change,
> never after it.**
>
> `SceneTree.paused` is a property of the tree, not of the scene, so it survives a scene
> replacement. Quitting to the main menu without clearing it loads the main menu into a
> paused tree. Every node in that menu resolves to `PAUSABLE`, and a paused `Control`
> receives no `_gui_input` and no `_unhandled_input` — so **the main menu would arrive
> visible, drawn, and completely dead.** No button would respond to mouse or keyboard, and
> there would be no error, no warning, and nothing on screen to indicate why.
>
> This is the same class of defect as ADR-0014's silent visual freeze: it looks almost
> right. AC-PM-6 exists for it.

**There is no Restart item, and that is a decision.** `level-flow.md` R1 states a level has
exactly two outcomes — completion or death — with *"no third state: no mid-level quit that
preserves progress, no partial completion, no soft-fail."* A voluntary restart would be a
third route out of a level and would need R1 and R6 amended to admit a non-death restart
that must **not** play E6 (E6 is cause-agnostic *death*; showing it would tell a player
they died when they chose to reset).

Restart is also already reachable: death *is* the restart, and `hud.md` E6 notes its hold
is short *"because the game's loop is repeated attempts."* **The honest cost**: a player
who wants a clean run must die for it, and waiting out the oxygen budget can take 30 s or
more. If that proves unacceptable in playtest, the fix is a `level-flow.md` amendment, not
a quiet addition here.

**Quit to Main Menu is not confirmed.** The reasoning differs from the main menu's, where
nothing at all is lost. Here the player does lose their current attempt — but that is the
same thing every death costs, in a game built on cheap repeated loss, and a confirmation
would require a modal-dialog pattern that `interaction-patterns.md` does not have. The
mitigation is structural instead: **Resume takes initial focus**, so reaching Quit requires
a deliberate navigation *and* an activation.

---

## 5. Layout Specification

### 5.1 The constraint that determines this layout

`hud.md` § *Paused state* is unambiguous:

> **The HUD freezes. Nothing hides, nothing dims.**

with E1 *"fully visible, holding its last value"*, E2/E4 holding as-is, E3 frozen at its
current fill, and E5's timer held. ADR-0014 D14.3 preserves exactly this by leaving every
one of those elements at `PROCESS_MODE_INHERIT`.

**So this screen may not scrim, dim, blur, or occlude the HUD.** The conventional pause
menu — a dimmed backdrop with a centred panel — is unavailable, and not for stylistic
reasons. §2's "pausing to think" player is the majority case, and the HUD is what they
paused to read.

It follows that the menu is **compact and screen-anchored**, occupying as little of the
viewport as two items allow.

### 5.2 Wireframe

```
┌────────────────────────────────────────────────────────────────┐  1152 × 648
│                                                                │
│    ░░░ level geometry, fully visible, undimmed ░░░             │
│                                                                │
│                  ┌────────────────────┐                        │
│                  │      PAUSED        │                        │
│                  ├────────────────────┤                        │
│                  │      Resume        │ ◄── initial focus      │
│                  ├────────────────────┤                        │
│                  │ Quit to Main Menu  │                        │
│                  └────────────────────┘                        │
│                                                                │
│      ┌──────┐  ◄── E1 oxygen readout: tracks the PLAYER,       │
│      │ O₂ 47│      so it roams. May collide with the panel.    │
│      └──────┘      Must not be hidden or dimmed. See PM-Q3     │
└────────────────────────────────────────────────────────────────┘
```

### 5.3 Zone Definitions

| Zone | Description | Size | Scrollable? | Overflow |
|---|---|---|---|---|
| Panel | Screen-anchored, holds the label and both buttons | Content-sized, centred | **No** | Two items; must not become scrollable (P9 authors no scroll-region focus rule, deliberately) |
| Everything else | Live gameplay and the frozen HUD | Full viewport | — | **Untouched.** Not dimmed, not blurred, not covered beyond the panel's own footprint |

> ⚠ **The panel has no zone assignment in `hud.md`'s zone system.** Z1 tracks the player,
> Z2 is the single contextual slot, Z3 is full-viewport (E6/E9), Z4 is the dev overlay.
> This panel belongs to none of them and is not a HUD element. **Zone assignment is owned
> by ADR-0010** — the same ownership that leaves P6 unplaced under `interaction-patterns.md`
> **O5**. See PM-Q3.

### 5.4 Component Inventory

| Component | Type | Purpose | Required? | Reuses? |
|---|---|---|---|---|
| Panel plate | Static frame | Groups the menu, separates it from live geometry behind it | Yes | **art-bible §7.3's flat plate family** — thin rectangle sized to content, no rounded corners, no drop shadow, no gradient fill |
| "PAUSED" label | Text | States why the game stopped | Yes | Type per §7.1 |
| Resume button | **P8** | Unpause | Yes | New |
| Quit to Main Menu button | **P8** | Leave the level | Yes | New |

**The plate is doing more work here than on the main menu.** It renders over arbitrary
level geometry rather than a controlled backdrop, which is the same worst-case-background
problem `hud.md` solved for E1–E4 with a black outline and a solid backing plate. §7.3
recommends solid Void Black at full or near-full opacity for exactly this reason and
explicitly rejects a translucent panel, because translucency *"reintroduces exactly the
worst-case-background variability the 'worst-case, not average' rule was written to
eliminate."* That recommendation applies to this panel directly.

**Note the tension, and that it is only apparent**: the panel is opaque while the screen
does not dim. Those are different things. An opaque panel occludes its own small footprint;
a scrim dims everything. §5.1 forbids the second, not the first.

---

## 6. States & Variants

| State | Trigger | Visual | Behavioural | Notes |
|---|---|---|---|---|
| **Open — Resume focused** | Pause pressed | Panel appears; Resume shows the focus indicator; HUD frozen and fully visible | Menu inputs live; gameplay inputs not processed | The only entry state |
| Quit focused | `ui_up`/`ui_down` | Focus moves | `ui_accept` leaves the level | Requires a deliberate move first (§4) |
| Either focused, other hovered | Mouse rests on the non-focused item | Both indicators visible and distinguishable | The **focused** item is what `ui_accept` fires | P8 |
| **Not open — refused** | Pause pressed during a completion or death sequence | **Nothing. No panel, no flicker, no feedback** | Gameplay unaffected; the sequence continues | ADR-0014 D14.4. See below |
| Closing | Resume or `ui_cancel` | Panel removed | `SceneTree.paused` → `false`; gameplay resumes | §7.3 covers the pour case |

**The refused state gives the player no feedback, and that is deliberate.** Feedback would
mean drawing something during E6 or E9, and `hud.md` requires those two to be
distinguishable from each other **in a single frame** — adding a third overlay into that
window risks a player misreading a win as a death, which is the one failure `hud.md` names
explicitly. The sequences are 0.35 s and a proposed 0.6 s, so the refusal window is short
enough that a press reads as a mistimed input rather than a broken control.

**No Loading, Empty or Error state.** Nothing is fetched (§8).

---

## 7. Interaction Map

### 7.1 Navigation Inputs

| Input | Action | Response | Notes |
|---|---|---|---|
| `ui_up` / `ui_down` | Move focus within the panel | Indicator moves | **Wraps at both ends** (P9) |
| Mouse hover | Hover state | Indicator on the hovered item | **Does not move focus** (P8) |
| Mouse click | Focus and activate | Press state, then the action | P8, P9 |
| Click outside the panel | **Nothing** | Nothing | **Focus must not clear** (P9), and clicking the world must not resume — an accidental click would drop the player back into a live level with the clock running |

**Initial focus is Resume, set explicitly on every open** (P9). It is both the most likely
action and the safe one.

**Focus must be trapped inside the panel.** Unlike the main menu, this screen does not own
the viewport — a live level sits behind it. Focus escaping into a `Control` belonging to
the HUD would leave the player unable to reach either menu item.

### 7.2 Action Inputs

| Input | Context | Action | Notes |
|---|---|---|---|
| `ui_accept` | Resume focused | Unpause, close | — |
| `ui_accept` | Quit focused | Unpause, **then** scene-replace to main menu | Order is load-bearing (§4) |
| **`ui_cancel`** | Any | **Resume** | Screen-level, not focus-dependent (P9). **Must invoke the same handler as the Resume button** — two paths to one exit, never two implementations |
| The pause action | Any, menu open | **Resume** | Pressing pause again closes the menu — the standard toggle. Same handler again |
| Left click | Press and release on the same item | As above | A press begun on an item and released off it is **cancelled** (P8) |
| Right click / scroll | Any | No-op | Specified so neither is left undefined |
| E8 on-demand tally key | Any, menu open | **Shows the tally** | See below |

**P6 makes a claim on this screen.** `interaction-patterns.md` P6 states the on-demand
readout *"must be available in every gameplay state where its content is meaningful,
**including while paused** — a player who pauses to think is precisely the player who needs
it."* That is §2's majority-case player exactly. So the pause menu **must not consume the
on-demand key and must not prevent E8 from displaying.**

Two things block delivering it today, neither owned by this spec: the input action does not
exist (`interaction-patterns.md` **O3**), and E8 has no zone assignment (**O5**, ADR-0010).
**Recorded as a live obligation, not as satisfied** — see PM-Q5.

### 7.3 State-Specific Behaviours

| State | Restriction / behaviour | Reason |
|---|---|---|
| Menu open | Gameplay actions are not processed | Every gameplay node is `PAUSABLE`. No suppression code is written or needed |
| Menu open, pour in progress | **E3's fill freezes. The drain-back does not fire on pausing** | `hud.md` U10.3. Pause is not an input release; draining would read as the game confiscating progress the player never released |
| Resuming, pour input still held | Pour resumes from the same fill | `hud.md` U10.3 |
| Resuming, pour input released while paused | Drain-back fires at that moment | `hud.md` U10.3. **P3 requires abandonment be gesture-agnostic**, so this must behave identically for the hold and toggle forms — a standing obligation on ADR-0009, not resolved here |
| Terminal sequence running | Menu cannot open | ADR-0014 D14.4 |
| Quitting to main menu | Unpause first | §4 |

---

## 8. Data Requirements

**This screen reads no game state.**

| Data Element | Source | Frequency | Owner | Null handling |
|---|---|---|---|---|
| — | — | — | — | — |

It displays no oxygen figure, no bucket tally and no level name. Everything a paused player
needs to read is **already on screen**, frozen and fully visible, because `hud.md` requires
the HUD not to hide. Restating any of it inside the panel would duplicate a live channel
and create two places for the same number to be wrong.

`is_paused` is state this screen *drives*, via `PauseController`, not state it reads.

---

## 9. Events Fired

| Player Action | Event | Payload | Receiver | Notes |
|---|---|---|---|---|
| Pause pressed | `PauseController.toggle_pause()` | None | `PauseController` | **Never `get_tree().paused` directly.** ADR-0014 D14.2 makes any other writer a forbidden pattern (`non_pausecontroller_writes_scenetree_paused`) |
| Resume / `ui_cancel` / pause again | `PauseController.set_paused(false)` | None | `PauseController` | One handler, three inputs (§7.2) |
| Quit to Main Menu | `set_paused(false)` **then** scene replace | None | `PauseController`, then `SceneTree` | Order is load-bearing (§4) |

**No analytics events** — no analytics system exists, and specifying events for a
non-existent receiver would create an obligation nobody agreed to.

---

## 10. Transition & Animation

| Transition | Trigger | Type | Duration | Interruptible? | Skipped by Reduced Motion? |
|---|---|---|---|---|---|
| Panel appear | Pause pressed | **None — instant** | 0 ms | N/A | N/A — no motion to skip |
| Panel dismiss | Resume | **None — instant** | 0 ms | N/A | N/A |
| Exit → main menu | Quit activated | Instant scene replace | 0 ms | **No** | N/A |
| Button focus / hover / press | Focus or pointer change | **None — state change only** | 0 ms | N/A | N/A |
| Background dim | — | **Forbidden** | — | — | — |

Every row is zero for the same reason as the main menu: reduced motion is **elevated**, so
P8 requires motion-free by default, and an animation that must be suppressed is worse than
one never added.

**Instant appearance matters more here than on the main menu.** A player pausing under
oxygen pressure is pausing *because* time is scarce; an animated panel would spend the
first frames of relief on decoration. `SceneTree.paused` takes effect immediately, so a
transition would also have to be driven by an exempted node, adding a fifth process-mode
exemption for a fade.

**Re-entrancy still applies despite zero duration.** The scene change on Quit does not take
effect until end-of-frame, so a second activation in the same frame can fire it twice.
AC-PM-9.

---

## 11. Input Method Completeness Checklist

**Keyboard**
- [x] All interactive elements reachable using arrow keys alone
- [x] Focus order follows visual order — Resume, then Quit
- [x] Every action achievable by mouse is achievable by keyboard
- [x] Focus is visible at all times (P9 never-null + P8 indicator)
- [x] **Focus does not escape the screen** — trapped inside the panel (§7.1). Load-bearing here, unlike the main menu
- [x] Esc cancels and does not quit the game — it **resumes** (§7.2)
- [ ] ⚠ **The pause action itself is unbound.** No key opens this screen. PM-Q1

**Gamepad** — **not applicable.** `technical-preferences.md` records `Gamepad Support: None`.

**Mouse**
- [x] Hover states defined (P8)
- [ ] ⚠ **Hit targets ≥ 32 × 32 px unverified** — button metrics depend on type not yet chosen. Owner: art-director
- [x] Click outside the panel defined — no-op, does not resume (§7.1)
- [x] Right-click and scroll defined — no-op

**Touch** — **not applicable.** `Touch Support: None`.

---

## 12. Screen-Level Accessibility Requirements

> **Tier note.** The template's four-tier definition does not match this project's.
> `design/accessibility-requirements.md` is authoritative: target **Standard**, with
> **reduced motion** and **one-hand mode** elevated; screen reader and high contrast
> explicitly out of scope.

**Contrast**

| Text Element | Background | Required | Current | Pass? |
|---|---|---|---|---|
| Button labels | Panel plate | ≥ 4.5:1 | ⚠ **Unmeasured** | Unknown — plate colour unset (§7.4) |
| "PAUSED" label | Panel plate | ≥ 4.5:1 | ⚠ **Unmeasured** | Unknown |
| Panel plate | **Arbitrary level geometry** | — | — | **The panel must be opaque enough that its own contrast figures do not depend on what is behind it** (§5.4, art bible §7.3) |

The third row is the one that separates this screen from the main menu. Not assumed to pass.

**Binding requirements**

| Requirement | Value | Source |
|---|---|---|
| Menu text minimum | **≥ 15 design px** | The menu floor, not the ≥ 12 px HUD floor |
| UI scaling | **1× and 2× only** | Nearest filter forbids 1.5× |
| Focus indication | **Never colour alone** | P8 |
| Motion | None (§10) | Reduced motion elevated |
| Screen reader | Not committed | `interaction-patterns.md` **O8** |

> ### One-hand mode covers five actions. Pause would be a sixth.
>
> `accessibility-requirements.md` elevates one-hand mode and commits to two presets —
> left-hand and right-hand — *"covering all 5 actions"*, enumerated as `move_left`,
> `move_right`, `jump`, `interact`, `crouch`. **Pause is not among them, because it does
> not exist yet.**
>
> A one-hand preset that cannot reach the pause key is a broken preset: the player can
> play the level but cannot stop it, in a game where stopping the clock is the only way to
> think. Adding a pause action therefore does not just add a binding — it invalidates the
> reference preset tables in `accessibility-requirements.md`, which will need a sixth row
> each.
>
> **Owner: accessibility-specialist**, jointly with PM-Q1. Flagged, not solved.

---

## 13. Localization Considerations

| String | Est. length (en) | Notes |
|---|---|---|
| "PAUSED" | 6 | ~8 expanded |
| "Resume" | 6 | ~8 expanded |
| "Quit to Main Menu" | 17 | **~24 expanded.** The longest player-facing string in the game |

**This screen is less forgiving of expansion than the main menu**, and it is worth saying
why rather than assuming symmetry. The main menu's action column is centred over a
controlled backdrop, so horizontal growth is absorbed by empty space. This panel sits over
live level geometry and is subject to PM-Q3's collision question — a wider panel is a
larger obstruction and a higher chance of overlapping the roaming E1 readout.

**"Quit to Main Menu" is the string most worth shortening** if a budget is ever set. No
character budget exists for any player-facing string in this project — the same gap
`interaction-patterns.md` **O2** records for P2's label.

**Owed**: `hud.md` and `interaction-patterns.md` P2 both still claim E2's label is *"the
only player-facing string in the game."* This screen adds three more; `main-menu.md` added
two to four. Recorded as MM-Q4 and repeated here so neither spec is the only witness.

---

## 14. Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| **AC-PM-1** | Pressing pause during normal gameplay opens the menu with focus on **Resume** | Integration |
| **AC-PM-2** | `oxygen_remaining` is unchanged across a pause of any duration, with no pause-check code in `OxygenDrain` | **Logic** |
| **AC-PM-3** | While the menu is open, **no HUD element is hidden, dimmed, blurred or scrimmed**; E1 remains fully visible holding its last value | UI — manual |
| **AC-PM-4** | Pressing pause during a completion or death sequence opens nothing, and the sequence completes normally | Integration |
| **AC-PM-5** | Resume, `ui_cancel`, and a second pause press all invoke the **same** handler and produce identical state | Integration |
| **AC-PM-6** | After **Quit to Main Menu**, `SceneTree.paused` is `false` and the main menu is fully operable by keyboard and mouse. *Guards the dead-on-entry defect in §4* | Integration |
| **AC-PM-7** | A pour in progress freezes at its fill on pause, with **no drain-back**; on resume it continues if the input is still held, and drains back if it is not | Integration |
| **AC-PM-8** | Focus cannot leave the panel while the menu is open | Integration |
| **AC-PM-9** | Activating Quit twice within one frame changes scene exactly once | Integration |
| **AC-PM-10** | Clicking level geometry outside the panel neither resumes nor clears focus | Integration |
| **AC-PM-11** | Labels render without clipping at 1× and 2×, and measure ≥ 15 design px at 1× | UI — manual |
| **AC-PM-12** | The focus indicator is distinguishable in a greyscale screenshot | UI — manual |
| **AC-PM-13** | The panel plate is opaque enough that label contrast does not vary with the geometry behind it | UI — manual |

AC-PM-11 through AC-PM-13 are blocked until art bible §7.4 sets the menu's visual
treatment. Stated now so that work has a target.

---

## 15. Open Questions

| # | Question | Affects | Owner |
|---|---|---|---|
| **PM-Q1** | **No pause input action exists.** `project.godot` declares five gameplay actions and nothing that opens this screen. Binding one raises a second question immediately: **is pause remappable?** It is not one of the five that `accessibility-requirements.md` commits to remapping, and the one-hand reference presets enumerate exactly those five — so a sixth action invalidates both preset tables (§12) | Entry, §11, §12 | ux-designer + accessibility-specialist |
| **PM-Q2** | **This panel is the fourth process-mode exemption, and ADR-0014 D14.3 said adding one is a decision** — *"No fourth exemption is granted here, and adding one later is a decision, not an implementation detail."* `PROCESS_MODE_WHEN_PAUSED` is arguably more correct than `ALWAYS` for a node that exists only while paused (ADR-0010 **V-E1** confirmed the semantics), but it carries an ordering hazard: the menu stops processing the instant it unpauses itself, so unpausing must be the last thing any handler does. **Not decided here** | Implementation | technical-director, with **O9** |
| **PM-Q3** | **The panel has no zone assignment, and E1 roams.** The oxygen readout tracks the *player* and offsets along eased gravity-up, so it can end up beneath the panel — and §5.1 forbids hiding or dimming it. `hud.md` already owns a Z1/Z2 displacement rule with release hysteresis; **the analogue is recommended over a new mechanism**, but zone assignment belongs to ADR-0010, which also leaves P6 unplaced (**O5**) | §5.3, §12 | ADR-0010 |
| **PM-Q4** | **No settings entry, by decision (2026-08-18).** Same owed item as `main-menu.md` **MM-Q1**: the settings screen is unowned, ADR-0010 records *"Owner: unassigned. Prerequisite: a settings-screen UX spec,"* and `T4`/`T5`/`T6` stay blocked. **The pause menu is the conventional home for settings**, so this omission is more visible here than on the main menu | Whole screen | Unassigned |
| **PM-Q5** | **P6's paused-state claim is recorded but not delivered.** The on-demand tally must be available while paused, and cannot be — the input action does not exist (**O3**) and E8 has no zone (**O5**) | §7.2 | ADR-0010 + `project.godot` |
| **PM-Q6** | **No ADR owns menu screen architecture** — scene structure, focus trapping, instancing and freeing, process modes. This spec stops at behaviour deliberately (**O9**) | Implementation | technical-director |
| **PM-Q7** | **Menu appearance is unset** — art bible §7.4 ⚠, owner ux-designer *"once a settings-screen UX spec exists for this section to art-direct against."* This spec and `main-menu.md` are the artifacts §7.4 was waiting on, so §7.4 is now unblocked | §5.4, §12 | art-director |
| **PM-Q8** | **No Restart item (§4).** If playtest shows waiting out oxygen is too slow a way to reset, the fix is a `level-flow.md` R1/R6 amendment admitting a non-death restart — **not** a quiet addition to this screen | §4 | game-designer |
| **PM-Q9** | **`complete_hold_duration` is still ⚠ unset** (0.6 s proposed), which sets the length of the window in which pause is refused (§6). ADR-0014 **D14.6** fixed the mechanism and deliberately not the value | §6 | game-designer, needs playtest |
