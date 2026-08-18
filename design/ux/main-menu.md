# UX Specification: Main Menu

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-18
> **Version**: 1.0
> **Engine**: Godot 4.7.1
> **UI Framework**: Godot Control nodes
> **Design Resolution**: 1152 × 648 — Godot's default. **Never authored.**
> `accessibility-requirements.md` **A3** flags this: every pixel figure in that document,
> and every one below, rests on a resolution nobody chose. Owner: `project.godot`
> **Related Documents**:
> - `design/ux/interaction-patterns.md` — **P8** (Button) and **P9** (Focus & Navigation
>   Order) are the two patterns this screen consumes. Both were authored 2026-08-18
>   specifically so this spec would not have to invent them
> - `design/ux/pause-menu.md` — the only other screen spec; sends the player here
> - `design/art/art-bible.md` §2.7, §7.1, §7.3, **§7.4** — owns this screen's *appearance*.
>   §7.4's ⚠ names ux-designer as owner *"once a settings-screen UX spec exists for this
>   section to art-direct against"*. This spec and `pause-menu.md` are what §7 was waiting on
> - `design/accessibility-requirements.md` — tier **Standard**, reduced motion and one-hand
>   mode elevated
> - `design/gdd/game-concept.md` — Scope Tiers; the open "one level or several" question
> - `src/scenes/start_menu.tscn`, `src/scripts/start_menu.gd` — **this screen already
>   exists in placeholder form and is `run/main_scene`.** See §5.4

---

## 1. Purpose & Player Need

The main menu exists to put the player into the game with the fewest decisions the
project can justify, and to be the only thing standing between launching the executable
and `level_01`.

It is deliberately not a hub. There is no save system, no progression store, no
statistics, and no level select, so there is nothing for a hub to present. `game-concept.md`
lists no menu content in any Scope Tier — not MVP, not Vertical Slice, not Alpha — which
means this screen has never been scoped as a feature. It is specified here because the
pre-production gate requires it and because `start_menu.tscn` already ships an unspecified
version of it.

**The player need is small and worth stating plainly**: confirm the game launched, and
start. Everything else on this screen is in service of not getting in the way of that.

---

## 2. Player Context on Arrival

There are exactly two arrivals, and they are not the same player.

| Question | Cold launch | Returned from `pause-menu.md` |
|---|---|---|
| What was the player just doing? | Launching the executable | Abandoning a level in progress from the pause menu |
| What is their emotional state? | Neutral. Possibly first-ever exposure to the game | Mild frustration or fatigue — they chose to leave a level rather than finish or die in it |
| What cognitive load are they carrying? | None | Some. They were mid-route with a bucket plan and an oxygen budget |
| What information do they already have? | The window title and whatever the title element says | Everything about the level they just left, none of which persists (`level-flow.md` R8) |
| What are they most likely trying to do? | Start | Either start again immediately, or quit |
| What are they likely afraid of? | Nothing yet | That leaving cost them something. **It did not, and it could not** — there are no checkpoints and no save, so there was never progress to lose |

**The second arrival is the reason Quit sits directly below Start** rather than being
tucked away: the returning player is the one most likely to want it, and they have just
demonstrated a willingness to leave.

**No onboarding happens here.** `game-concept.md` records under Design Risks that no
onboarding sequence exists and that `level_01` currently has to teach gravity, carrying and
pouring simultaneously. This screen does not fix that and must not pretend to — a tutorial
surface on the main menu would be a new feature, not a UX layout decision.

---

## 3. Navigation Position

The main menu is the **root** of the screen graph, and the graph is two nodes deep.

```
                    ┌──────────────────┐
    launch  ──────► │    MAIN MENU     │ ──── Quit ────►  process exits
                    └──────────────────┘
                       │            ▲
                 Start Game         │  Quit to main menu
                       │            │
                       ▼            │
                    ┌──────────────────┐
                    │  level_01 …      │ ◄──── Resume ──── PAUSE MENU
                    │  (gameplay)      │ ─────  pause  ───►
                    └──────────────────┘
```

**Nothing else exists.** There is no settings screen, no credits, no level select, and no
options sub-menu. Each of those is recorded as owed in §15 rather than drawn here.

---

## 4. Entry & Exit Points

### Entry

| Trigger | Source | Transition Type | Data Passed In | Notes |
|---|---|---|---|---|
| Application launch | OS | Initial scene load | None | `project.godot` `run/main_scene` resolves to `start_menu.tscn` (`uid://c7wcjgf8lvf3i`). **Verified, not assumed** |
| Quit to main menu | `pause-menu.md` | Full scene replace | None | The level instance is destroyed. `level-flow.md` R8's total reset applies by construction — there is no state to carry, so none is passed |

### Exit

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|---|---|---|---|---|
| **Start Game** | `level_01.tscn` | Full scene replace | None | Matches shipped behaviour: `start_menu.gd` `_on_button_pressed()` calls `change_scene_to_packed(start_level)`, with `start_level` exported and wired to `level_01` in the scene file |
| **Quit** | Process exit | Terminal | None | `get_tree().quit()`. **No confirmation dialog** — see below |

**Quit is not confirmed, and that is a decision.** Three reasons, in order of weight:
there is no save system and no session state, so quitting from the main menu destroys
nothing; a confirmation would require a modal-dialog pattern that does not exist in
`interaction-patterns.md` and would make this screen the reason a sixth pattern had to be
written; and the player reaching Quit from the main menu has, in both arrival cases, taken
at least one deliberate action to get here.

**The level `Start Game` targets is hard-wired and stays that way.** `game-concept.md`
leaves "whether a session is one level or several" explicitly open, and `level-flow.md` R10
leaves what happens after the final level ⚠ TBD. A level-select or continue affordance
cannot be specified before either is decided, and inventing one here would quietly answer a
question the design has deliberately held open.

---

## 5. Layout Specification

### 5.1 Wireframe

```
┌────────────────────────────────────────────────────────────────┐  1152 × 648
│                                                                │
│                                                                │
│                                                                │
│                      ╔══════════════════╗                      │
│                      ║   TITLE ELEMENT  ║   ⚠ form unset       │
│                      ╚══════════════════╝                      │
│                                                                │
│                      ┌──────────────────┐                      │
│                      │   Start Game     │  ◄── initial focus   │
│                      └──────────────────┘                      │
│                      ┌──────────────────┐                      │
│                      │      Quit        │                      │
│                      └──────────────────┘                      │
│                                                                │
│                                                                │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

Centred, single-column, two items. **The layout is the least interesting thing about this
screen and should stay that way** — §7.4 of the art bible commits menus to "the station's
own status screen," and a status screen is not composed.

### 5.2 Zone Definitions

| Zone | Description | Approximate Size | Scrollable? | Overflow Behaviour |
|---|---|---|---|---|
| Backdrop | Full-viewport ground. Currently a `ColorRect` plus a `TextureRect` | Full viewport | No | None — never scrolls |
| Title | Identifies the game | Centred, above the action column | No | ⚠ Unset. Depends on whether the title is an image or set type — see §5.3 |
| Action column | The `VBoxContainer` holding every interactive element | Centred, content-sized | **No** | **Must not become scrollable.** Two items now; if this screen ever holds enough items to overflow, that is a signal to reconsider the screen, not to add a scrollbar — P9 authors no scroll-region focus rule and deliberately says so |

### 5.3 Component Inventory

| Component | Type | Zone | Purpose | Required? | Reuses Existing? |
|---|---|---|---|---|---|
| Backdrop | `ColorRect` | Backdrop | Ground colour | Yes | Exists — **and is wrong, see §5.4** |
| Title element | ⚠ **Unset** — image or set type | Title | Names the game | Yes | Partially. `Menu_temp.png` exists in a `TextureRect` but is named as temporary. **Owner: art-director**, under §7.4 |
| Start Game button | **P8** | Action column | Enters `level_01` | Yes | Exists as `StartButton` |
| Quit button | **P8** | Action column | Exits the process | Yes | Exists as `QuitButton` |

**No component on this screen uses any pattern other than P8.** That is the intended
outcome of authoring P8 and P9 before this spec rather than during it.

### 5.4 The screen that already exists, and what is wrong with it

`start_menu.tscn` ships today with a `Control` root, a `ColorRect`, a `TextureRect`
(`Menu_temp.png`), and a `CenterContainer` → `VBoxContainer` holding `StartButton`
("Start Game") and `QuitButton` ("Quit"), both themed from `src/resources/menu_theme.tres`.
Its structure already matches §5.1. **Three defects, all sourced:**

| # | Defect | Source of the rule | Severity |
|---|---|---|---|
| **MM-1** | **`start_menu.gd` never calls `grab_focus()`.** The menu opens with nothing focused, so it is operable by mouse only. A keyboard-only player cannot start the game | **P9** — "Focus is never null while a menu is open." This is the single most load-bearing rule in P9, and the shipped screen violates it | **Blocking.** The game is keyboard/mouse with no gamepad; this is not a polish item |
| **MM-2** | **The backdrop is `Color(0.35968348, 0.5160989, 0.36534452)` ≈ `#5C845D` — a green**, and not an entry in the fixed 56-entry NES palette | `art-bible.md` §4.2 quarantines green to plants: *"Neither hue appears anywhere else in the primary palette."* §4.1 binds the palette project-wide. §2.7 requires the station's cold register, *"not a separate warm menu aesthetic"* | **High.** It contradicts the one colour rule the art bible states most absolutely |
| **MM-3** | `Menu_temp.png` is named and treated as temporary, and no title treatment is specified anywhere | `art-bible.md` §7.4 ⚠ — full menu visual layout unset | Medium. Owner: art-director |

**This spec does not restyle the screen.** MM-2 and MM-3 are appearance, which §7.4 owns;
they are recorded here so §7 inherits them rather than rediscovers them. **MM-1 is
behaviour, and this spec does fix it** — see §7.1 and AC-MM-2.

---

## 6. States & Variants

| State | Trigger | What Changes Visually | What Changes Behaviourally | Notes |
|---|---|---|---|---|
| **Default** | Screen open | Start Game holds focus | All inputs live | The only steady state this screen has |
| Start Game focused | Default, or `ui_up`/`ui_down` from Quit | Start Game shows the P8 focus indicator | `ui_accept` starts the game | Initial state on every entry, including return from the pause menu |
| Quit focused | `ui_up`/`ui_down` from Start Game | Quit shows the focus indicator | `ui_accept` exits | — |
| Either focused **and** the other hovered | Mouse rests over the non-focused button | **Both indicators show at once, and are distinguishable** | Unchanged — the *focused* button is what `ui_accept` fires | P8 requires this explicitly. It is the most reachable "surprising" state on the screen |
| Transitioning out | Start Game or Quit activated | Nothing — the transition is instant (§10) | Input is not accepted after activation | See §10 on why re-entrancy matters even with no animation |

**States this screen deliberately does not have**: no Loading state (there is nothing to
load before the buttons can be drawn); no Empty state; no Error state (there is no data
fetch that can fail — see §8); no Disabled variant of either button, because neither can
ever be unavailable.

---

## 7. Interaction Map

### 7.1 Navigation Inputs

| Input | Action | Visual Response | Notes |
|---|---|---|---|
| `ui_up` / `ui_down` | Move focus within the action column | Focus indicator moves | **Wraps at both ends** (P9). With two items, up and down are equivalent |
| Mouse hover | Show the hover state | Hover indicator appears on the hovered button | **Does not move focus** (P8). The focused button is unchanged and is still what `ui_accept` fires |
| Mouse click | Focus **and** activate | Press state, then the exit transition | Click both moves focus and activates, per P8 and P9 |
| Click into dead space | Nothing | Nothing | **Focus must not clear** (P9). This is the most likely accidental route into the null-focus state P9 forbids |

**Initial focus is `Start Game`, set explicitly on screen open, on every entry.** Never
left to scene-tree order (P9). This is the fix for **MM-1**.

Focus does not need trapping: the screen occupies the whole viewport and there is nothing
behind it to reach.

### 7.2 Action Inputs

| Input | Context | Action | Response | Notes |
|---|---|---|---|---|
| `ui_accept` | Start Game focused | Enter `level_01` | Immediate scene replace | Godot's built-in; no new binding (P9's Engine notes) |
| `ui_accept` | Quit focused | Exit the process | Window closes | No confirmation (§4) |
| Left click | On a button, pressed and released on the same button | As above | As above | A press that begins on the button and releases off it is **cancelled** (P8) |
| **`ui_cancel`** | Any | **No-op** | **Nothing** | See below |
| Right click | Any | No-op | Nothing | Specified so it is not left undefined |
| Scroll wheel | Any | No-op | Nothing | Nothing on this screen scrolls (§5.2) |

**`ui_cancel` does nothing here, and must not quit.** P9 makes cancel a screen-level
action, but the main menu is the root of the graph — there is nowhere to cancel *to*.
Wiring Escape to Quit would put process termination on the one key players press
reflexively to back out of things, which is the opposite of what pressing it means. The
player who wants to leave uses the Quit button, which is one keystroke away and says what
it does.

### 7.3 State-Specific Behaviours

| State | Input Restriction | Reason |
|---|---|---|
| Transitioning out | All input ignored | A second activation during the scene swap would fire `change_scene_to_packed` or `quit()` twice. See §10 |

---

## 8. Data Requirements

**This screen reads no game state at all.**

| Data Element | Source System | Update Frequency | Owner | Null / Missing Handling |
|---|---|---|---|---|
| — | — | — | — | — |

The table is empty on purpose, and the emptiness is worth recording: there is no save
system, no settings store, no profile, and no progression data, so there is nothing for
this screen to display and nothing it can fail to load. **This is why §6 has no Loading
and no Error state.**

**It will stop being empty the moment settings exists**, because settings must persist and
be readable before the first level starts. That is one more reason the deferred settings
screen is a structural change to this screen and not an addition beside it.

---

## 9. Events Fired

| Player Action | Event | Payload | Receiver | Notes |
|---|---|---|---|---|
| Activates Start Game | `StartGameRequested` | None | Scene routing | Today `start_menu.gd` calls `change_scene_to_packed()` inline. **Whether this stays inline or routes through a named event is unowned** — `interaction-patterns.md` **O9** records that no ADR owns menu screen architecture |
| Activates Quit | `QuitRequested` | None | `SceneTree` | `get_tree().quit()` |

**No analytics events.** No analytics system exists in this project, and specifying events
for a receiver that does not exist would create an obligation nobody agreed to.

---

## 10. Transition & Animation

| Transition | Trigger | Type | Duration | Interruptible? | Skipped by Reduced Motion? |
|---|---|---|---|---|---|
| Screen enter | Launch, or return from pause | **None — instant** | 0 ms | N/A | N/A — there is no motion to skip |
| Screen exit → `level_01` | Start Game activated | **None — instant scene replace** | 0 ms | **No** | N/A |
| Screen exit → process | Quit activated | Terminal | 0 ms | No | N/A |
| Button focus / hover / press | Focus or pointer change | **None — state change only** | 0 ms | N/A | N/A |

**Every row is zero, and that is a decision rather than an omission.** Reduced motion is
**elevated** for this project rather than optional, so P8 requires buttons to be motion-free
by default: an animation that has to be suppressed is a worse answer than one never added.
A fade on the screen transition would buy nothing here — the destination is a level whose
own first frame is the thing the player is waiting for — while adding a reduced-motion
branch and an interruptibility question to a screen that currently has neither.

**The one thing zero duration does not remove is re-entrancy.** `change_scene_to_packed()`
does not take effect until the end of the frame, so a fast second activation in the same
frame can still fire it twice. §7.3's input lock is required even though nothing is
animating.

---

## 11. Input Method Completeness Checklist

**Keyboard**
- [x] All interactive elements reachable using arrow keys alone
- [x] Focus order follows visual order — top to bottom, Start Game then Quit
- [x] Every action achievable by mouse is also achievable by keyboard
- [x] Focus is visible at all times — guaranteed by P9's never-null rule plus P8's indicator
- [x] Focus does not escape the screen — the screen is full-viewport with nothing behind it
- [x] Esc does not quit the game from within a screen — **explicitly a no-op here (§7.2)**

**Gamepad** — **not applicable.** `.claude/docs/technical-preferences.md` records
`Gamepad Support: None` and a keyboard-only input map. These boxes are marked N/A rather
than left unchecked, so that an unchecked box always means unfinished work.

**Mouse**
- [x] Hover states defined for all interactive elements (P8)
- [ ] ⚠ **Hit targets ≥ 32 × 32 px unverified.** Button size is content-driven and the type
      is not chosen yet (§5.3, art bible §7.1). **Owner: art-director**, at the point the
      type and plate metrics are set
- [x] Right-click behaviour defined — no-op (§7.2)
- [x] Scroll behaviour defined — nothing scrolls (§5.2)

**Touch** — **not applicable.** `Touch Support: None`.

---

## 12. Screen-Level Accessibility Requirements

> **Tier note.** The `ux-spec` template carries its own four-tier definition that does not
> match this project's. `design/accessibility-requirements.md` is authoritative: the target
> is **Standard**, with **reduced motion** and **one-hand mode** elevated, and screen reader
> support and high contrast explicitly out of scope. The template's tier list is not
> reproduced here.

**Contrast**

| Text Element | Background | Required | Current | Pass? |
|---|---|---|---|---|
| Button labels | Button plate | ≥ 4.5:1 | ⚠ **Unmeasured** | Unknown — plate colour is unset (§5.4 MM-2/MM-3) |
| Title | Backdrop | ≥ 4.5:1 | ⚠ **Unmeasured** | Unknown — title form is unset |

Both rows stay unmeasured until §7.4 sets the menu palette. **They are not assumed to
pass.** The art bible's existing contrast work covers HUD elements against arbitrary
terrain; a menu renders over its own controlled backdrop, which is an easier problem but
not a solved one.

**Binding requirements for this screen**

| Requirement | Value | Source |
|---|---|---|
| Menu text minimum | **≥ 15 design px** | `accessibility-requirements.md` — the menu floor, not the ≥ 12 px HUD floor |
| UI scaling | **1× and 2× only** | `default_texture_filter=0` (nearest) makes non-integer factors shimmer. 1.5× is forbidden project-wide |
| Focus indication | **Never colour alone** | P8. At this tier the focus indicator is the entire affordance telling the player what will happen next |
| Motion | None (§10) | Reduced motion elevated |
| Screen reader | **Not committed** | See below |

**On screen readers.** `accessibility-requirements.md` places screen reader support out of
scope, giving as one reason that *"No menu system exists to read."* **This screen is that
menu system**, and Godot 4.5+ integrates AccessKit specifically over `Control` nodes —
though every `Control` ships with no accessible role or name until one is explicitly
configured, so it is a real cost rather than a free win. The decline's *other* reason —
that this game is entirely spatial and visual — is untouched by any of this and may still
carry the decision on its own. **Recorded, not revisited here.**
`interaction-patterns.md` **O8**, owner accessibility-specialist.

---

## 13. Localization Considerations

**This screen contradicts a claim made in two other documents, and the claim is now false.**

`hud.md` states that E2's action label is *"the only player-facing string in the game,"*
and `interaction-patterns.md` P2 repeats it. This screen adds at minimum **"Start Game"**
and **"Quit"**, and a title element that may also be set type rather than an image. The
localizable surface has gone from one string to three or four.

| String | Est. length (en) | Notes |
|---|---|---|
| "Start Game" | 10 | A 40% expansion (the figure P2 already uses) reaches ~14 characters |
| "Quit" | 4 | ~6 expanded |
| Title | ⚠ Unset | If the title is an image, it is an **asset** to localize, not a string — materially more expensive. Owner: art-director |

**Consequence for layout.** The action column is content-sized and centred, so horizontal
expansion is absorbed without a layout rule — unlike P2's panel, where expansion feeds a
displacement rule. This screen is the easy case, and it is worth saying so explicitly so
that nobody assumes the pause menu (which overlays live gameplay) is equally forgiving.

**Owed**: `hud.md` and `interaction-patterns.md` P2 both need their "only player-facing
string" claim corrected. Recorded in §15.

---

## 14. Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| **AC-MM-1** | On entry, focus is on **Start Game**, on a cold launch and on a return from the pause menu alike | Integration |
| **AC-MM-2** | The screen is fully operable with the keyboard alone, from launch to entering `level_01`, without any mouse input. **This is the criterion `start_menu.gd` fails today (MM-1)** | Integration |
| **AC-MM-3** | Focus is never null while the screen is open, including after a click into dead space | Integration |
| **AC-MM-4** | `ui_up` and `ui_down` wrap at both ends of the two-item column | Integration |
| **AC-MM-5** | Hovering the non-focused button shows the hover state, leaves focus unchanged, and `ui_accept` still fires the **focused** button | Integration |
| **AC-MM-6** | A mouse press begun on a button and released off it activates nothing | Integration |
| **AC-MM-7** | `ui_cancel` does nothing — in particular it does not quit | Integration |
| **AC-MM-8** | Activating Start Game twice within one frame changes scene exactly once | Integration |
| **AC-MM-9** | Button labels render without clipping at both 1× and 2× UI scale | UI — manual |
| **AC-MM-10** | Button labels measure ≥ 15 design px at 1× | UI — manual |
| **AC-MM-11** | The focus indicator is distinguishable in a greyscale screenshot | UI — manual |
| **AC-MM-12** | No colour on the screen falls outside the 56-entry NES palette. **Fails today (MM-2)** | UI — manual |

AC-MM-9 through AC-MM-12 cannot be executed until §7.4 sets the menu's visual treatment.
They are stated now so that work has a target rather than being reverse-engineered later.

---

## 15. Open Questions

| # | Question | Affects | Owner |
|---|---|---|---|
| MM-Q1 | **No settings entry exists on this screen, by decision (2026-08-18).** The settings screen is unowned and deferred; ADR-0010 records *"Owner: unassigned. Prerequisite: a settings-screen UX spec."* Four accessibility commitments — remapping, one-hand presets, text scaling, reduced motion — have no delivery surface, and `T4`/`T5`/`T6` stay blocked. **This is the single largest owed addition to this screen**, and adding it changes §3, §4, §8 and §13 rather than only §5 | Whole screen | Unassigned. Needs a settings-screen UX spec |
| MM-Q2 | **The title element's form is unset** — image or set type. It decides whether the title is a localizable string or a localizable asset (§13) | §5.3, §12, §13 | art-director, under art bible §7.4 |
| MM-Q3 | **MM-2: the shipped backdrop is a non-palette green**, contradicting art bible §4.2 and §2.7 | §5.4 | art-director |
| MM-Q4 | **The "only player-facing string in the game" claim is now false** in `hud.md` and `interaction-patterns.md` P2. Both need correcting | Those two documents | ux-designer |
| MM-Q5 | **No ADR owns menu screen architecture** — scene structure, focus wiring, process modes, instancing. This spec stops at behaviour deliberately. `interaction-patterns.md` **O9** | §9, implementation | technical-director |
| MM-Q6 | **No level select or continue**, because `game-concept.md` leaves "one level or several per session" open and `level-flow.md` R10 leaves post-final-level ⚠ TBD. Deciding either may add items to this screen | §4, §5 | game-designer |
| MM-Q7 | **Design resolution 1152 × 648 was never authored** (`accessibility-requirements.md` A3). Every pixel figure here inherits that | §5, §12 | `project.godot` |
| MM-Q8 | **Hit-target minimum unverified** (§11) — button metrics depend on type not yet chosen | §11 | art-director |
