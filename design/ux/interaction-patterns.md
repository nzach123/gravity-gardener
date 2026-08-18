# Interaction Pattern Library: Gravity Gardener

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-18
> **Version**: 1.1
> **Engine**: Godot 4.7.1
> **UI Framework**: Godot Control nodes
> **Related Documents**:
> - `design/ux/hud.md` — the only screen spec that exists; every pattern below is drawn from it
> - `design/accessibility-requirements.md` — accessibility commitments per feature
> - `design/art/art-bible.md` — complete, all 9 sections (2026-08-18). §7 owns HUD and
>   menu *appearance*; this library owns *behaviour*. Where they meet, §7 defers layout to
>   the UX layer and this library defers visual treatment to §7

> **Why this document exists**: Every screen spec should be able to say "uses
> Fill-on-Hold pattern" rather than re-specifying the behaviour from scratch. This
> library is the single source of truth for reusable interaction behaviours. When a
> screen spec names a pattern, the programmer looks it up here. When the behaviour
> changes, it changes here and applies everywhere.
>
> **Status definitions**:
> - **Draft**: specified but not implemented or validated
> - **Stable**: implemented, tested, and validated in at least one shipped screen
> - **Deprecated**: being phased out — do not use in new screens

> **Every pattern here is `Draft`.** `src/` contains no HUD or UI code, so nothing in
> this library has been implemented or validated. No pattern may be marked Stable on
> the strength of its specification alone.

---

## How to Use This Library

**Designing a screen**: browse the catalogue before inventing an interaction. When a
pattern fits, reference it by name. When none fits, add the new pattern here **before**
the screen spec that uses it.

**Implementing a screen**: when a spec names a pattern, the full specification is here.
The accessibility lines are not negotiable — they trace to commitments in
`design/accessibility-requirements.md`.

**This library exists because `hud.md` invented three patterns with nowhere to put
them** (`hud.md` Q5, open since 2026-08-15). Four more were found in use or newly owed
while cataloguing.

---

## Pattern Catalog

| # | Pattern | Category | Used in | Status |
|---|---|---|---|---|
| P1 | [Viewport-Upright Tracked Readout](#p1--viewport-upright-tracked-readout) | Data Display | `hud.md` E1 (Z1) | Draft |
| P2 | [World-Tracked Prompt Panel](#p2--world-tracked-prompt-panel) | Overlay / Feedback | `hud.md` E2, E4 (Z2) | Draft |
| P3 | [Fill-on-Hold](#p3--fill-on-hold) | Input / Feedback | `hud.md` E3 | Draft |
| P4 | [Transient Confirmation](#p4--transient-confirmation) | Feedback | `hud.md` E5 (Z3) | Draft |
| P5 | [Single-Slot Priority Arbitration](#p5--single-slot-priority-arbitration) | Layout / Arbitration | `hud.md` Z2 slot | Draft |
| P6 | [On-Demand Readout](#p6--on-demand-readout) | Data Display | **None yet** | Draft |
| P7 | [Paged Diagnostic Overlay](#p7--paged-diagnostic-overlay-dev-tier) | Developer tooling | `hud.md` E7 (Z4) | Draft — **dev tier** |
| P8 | [Button](#p8--button) | Input / Control | `main-menu.md`, `pause-menu.md` | Draft |
| P9 | [Focus & Navigation Order](#p9--focus--navigation-order) | Navigation / Input | `main-menu.md`, `pause-menu.md` | Draft |

**P1, P2 and P3 are the three named in `hud.md` Q5.** P4 and P5 were in use and
uncatalogued. P6 is new, committed by `design/accessibility-requirements.md`. P7 is
dev-only and carries a reduced contract — see its entry.

**P8 and P9 are the project's first interactive patterns.** P1–P7 take no input at all.
They were added 2026-08-18 to unblock the main-menu and pause-menu specs, which could
otherwise only have been written by inventing interaction behaviour inside a screen spec —
the exact failure this library exists to prevent. **Only the two patterns those two screens
consume were authored.** Slider, key-rebinding capture and toggle remain in
*Gaps & Patterns Needed* because the settings screen that needs them was deliberately held
out of scope — see that section.

---

## Patterns

### P1 — Viewport-Upright Tracked Readout

**Category**: Data Display
**Used In**: `hud.md` E1 — oxygen gauge (Z1)
**Status**: Draft

**Description**: A permanent readout anchored to a moving world entity, offset along a
direction vector, and held at zero rotation regardless of the camera basis. It exists
for games where "up" is not a fixed direction.

**Specification**

- **Anchor**: tracks its entity continuously. It is not screen-anchored and does not
  occupy a learned corner.
- **Offset direction**: along **eased gravity-up (`up_dir`)**, not viewport-up. This is
  what keeps the readout out of the player's fall path in the six static-camera levels.
- **Rotation**: always zero. Counter-rotated against the camera basis so it stays
  upright in viewport space through a gravity flip (`hud.md` U8.6, U8.7).
- **Everything is specified in viewport space**, never world space. Two camera modes
  exist — `level_01` and `level_07` rotate the camera over 0.6 s per flip; the other six
  never move — so world space cannot express the layout.
- **Footprint cap**: `z1_max_footprint`, 96 × 24 px. A playtest target, not a derived value.
- **Occlusion**: placed opposite the fall path. Opacity reduction is **explicitly
  declined** — it would undercut the contrast figures the readout depends on.
- **Input**: none. Non-interactive.

**Accessibility**

- Contrast ≥ 4.5:1 against the **worst-case** background it can appear over, not the average.
- Requires a black outline or backing plate — it renders over arbitrary terrain.
- Text ≥ 12 design px.
- Must not encode meaning in colour alone. E1 satisfies this with tick marks and numerals.

**When to Use**: information that must stay legible continuously, whose relevance is
tied to an entity's position, in a game where the camera basis is unstable.

**When NOT to Use**: contextual or on-demand information (use P2 or P6); anything
interactive; anything the player must find in a fixed, learned screen position — this
pattern deliberately roams.

**Reference**: `hud.md` § Layout Zones → Z1, § Z1 occlusion rule.

---

### P2 — World-Tracked Prompt Panel

**Category**: Overlay / Feedback
**Used In**: `hud.md` E2 — interact prompt; E4 — pour refusal (both Z2)
**Status**: Draft

**Description**: A contextual panel anchored to a **static level object** rather than to
the player, appearing on proximity and clearing when the player leaves.

**Specification**

- **Anchor**: a static world object. This is what separates it from P1.
- **Trigger**: the player is inside the object's interact area, **plus** any per-element
  preconditions. E2 requires three conditions; removing any one hides it.
- **Offset**: toward viewport-up. **See Open Question O1** — this is unresolved under
  non-default gravity.
- **Displacement**: displaces along a named axis when it intersects a P1 readout, with
  release hysteresis to stop it oscillating. Clamps at the viewport edge, with a defined
  off-viewport fallback.
- **Cardinality**: at most one panel shows at a time. Arbitration is **P5**, not this pattern.
- **Input**: none. The panel *describes* an interaction performed with existing
  bindings; it never takes input itself.

**Accessibility**

- Outline or backing plate required — renders over arbitrary terrain.
- Text ≥ 12 design px, contrast ≥ 4.5:1 worst-case.
- **E2's action label is the only player-facing string in the game.** It has no
  character budget yet — see Open Question O2. A 40% translation expansion widens the
  panel, which feeds the displacement rule above.

**When to Use**: an affordance attached to a specific world object, relevant only in proximity.

**When NOT to Use**: information not attached to a world object; anything that must
persist after the player leaves proximity; anything needed while the player is elsewhere
(use P6).

**Reference**: `hud.md` § Layout Zones → Z2, § Z1 / Z2 collision rule; E2 and E4 entries.

---

### P3 — Fill-on-Hold

**Category**: Input / Feedback
**Used In**: `hud.md` E3 — pour progress, rendered inside E2
**Status**: Draft

**Description**: A timed commitment the player sustains and may abandon, where progress
fills an **existing** element rather than adding a new one, and abandoning visibly
returns the progress to zero.

**Specification**

- **Fills the host element.** E3 fills E2's panel; it is not a separate element and does
  not count against the density budget.
- **Progress** maps to elapsed / duration. For E3 that is `water_progress / water_duration`
  (default 5.0 s, range 2.0–8.0 s).
- **Early release drains the fill back.** This is the visible proof of `watering-system.md`
  R4 / AC3 — the bucket is retained, progress resets to 0, and there is **no partial
  credit**. The drain-back is the pattern's whole point; an instant cut would make
  abandonment indistinguishable from completion.
- **Paused behaviour**: the fill suspends. The drain-back does **not** fire on pausing.
  On unpause, if the input is still held it resumes; if released, the drain-back fires
  then (`hud.md` U10.3).

**Accessibility**

- **A toggle alternative is required**, per `design/accessibility-requirements.md`
  (Motor). First press begins, second press abandons.
- **Abandonment must be gesture-agnostic.** Hold-release and toggle-press must be the
  same event. This is a standing obligation on **ADR-0009**, and `hud.md` U10.3's
  "still held → resume" rule needs restating in gesture-agnostic terms.
- Progress must be readable without colour. A fill is positional, which satisfies this
  inherently.

**When to Use**: any timed commitment the player can abandon partway.

**When NOT to Use**: instantaneous actions; any action that grants partial credit — this
pattern's drain-back asserts there is none, so using it where partial credit exists
would state something false.

**Reference**: `hud.md` E3, U8.10, U10.3; `watering-system.md` R4, AC2, AC3.

---

### P4 — Transient Confirmation

**Category**: Feedback
**Used In**: `hud.md` E5 — pour tally (Z3)
**Status**: Draft

**Description**: A short, self-clearing acknowledgement that a state change happened.

**Specification**

- **Trigger**: fires when the underlying counter advances.
- **Duration**: fixed. E5 uses `tally_duration` = **1.2 s**.
- **No queue or priority rule among instances** — and this is deliberate. The duration is
  chosen so a queue is *structurally impossible*: `water_duration` floors at 2.0 s and
  every pour is separated by a fetch leg, so two confirmations cannot fall closer than
  roughly 2 s apart. **Raising the duration past ~2.0 s reintroduces the need for a queue
  rule that does not exist.**
- **Early dismissal**: cleared immediately when a higher-priority element resolves. See P5.

**Accessibility**

- **This pattern must never be the sole channel for information the player may need
  later.** A 1.2 s window is below any reasonable reading-time floor for actionable
  information, and a player who looks away has no recovery.
- In `hud.md` this constraint was violated: E5 was the only place level progress
  appeared. **P6 exists to close that**, and the two patterns are paired — if a
  transient confirmation carries state, an on-demand channel must carry it too.

**When to Use**: acknowledging a change the player just caused and is already watching.

**When NOT to Use**: as the only channel for persistent state; for anything the player
may need to consult later.

**Reference**: `hud.md` E5, U10.4; `design/accessibility-requirements.md` § Objective clarity.

---

### P5 — Single-Slot Priority Arbitration

**Category**: Layout / Arbitration
**Used In**: `hud.md` — the single Z2 slot and the cross-zone priority order
**Status**: Draft

**Description**: A rule set that guarantees a density budget by giving competing
contextual elements exactly one slot and a total ordering over it.

**Specification**

- **One slot, at most one occupant.**
- **Award order within the slot**:
  1. the resolved pour target (E2), if one is in range;
  2. otherwise the nearest capped plant (E4).

  E2 and E4 can therefore never coexist. This preserves `watering-system.md` AC12
  exactly — the prompt appears on the nearest plant *with capacity*, even when a capped
  plant is nearer.
- **Cross-zone priority order**: `E2/E3 → E5 → E4`.
- **Suppression does not run both ways, and that asymmetry is the point.** A transient
  confirmation (P4) must never suppress the prompt, because **P3 lives inside P2** —
  suppressing the prompt would hide the fill of an *active* commitment. The reachable
  case: on a plant needing two or more buckets, a player who fetches a nearby bucket and
  resumes within `tally_duration` is pouring while the tally is still up. The
  confirmation yields instead, because by then it has been read or missed.
- **Budget enforced**: never more than two player-facing elements on screen at once.

**Accessibility**

- Arbitration must be deterministic. A player must be able to learn which element wins,
  which rules out proximity ties resolved arbitrarily.
- Suppressing an element must never remove the *only* channel for its information —
  see P4 and P6.

**When to Use**: whenever two or more contextual elements can compete for the same
anchor region or the same density budget.

**When NOT to Use**: when elements occupy distinct zones and cannot overlap. Do not
apply arbitration where no competition exists — it adds a rule the player must learn for
nothing.

**Reference**: `hud.md` § The single Z2 slot, § Density profile; U10.1, U10.6, and the
E5 priority order.

> **This is the pattern most worth catalguing.** It took three sessions and one
> mid-write correction to settle, and the counterexample that broke the first version
> was the most ordinary event in the game. A second screen inventing its own arbitration
> rule is exactly the failure this library prevents.

---

### P6 — On-Demand Readout

**Category**: Data Display
**Used In**: **None yet.** Committed by `design/accessibility-requirements.md`
**Status**: Draft — no element implements it

**Description**: State the player queries by holding a key, shown for as long as it is
held. It buys availability without spending a permanent slot.

**Specification**

- **Trigger**: player holds a dedicated input action. Shows while held, clears on release.
- **Requires a new input action.** It does not exist — see Open Question O3.
- **Consumes no permanent slot.** It honours the two-element budget because it is
  player-invoked and transient, which is what distinguishes it from making the readout
  permanent.
- **Category**: this is `hud.md`'s **On Demand** information category, which the
  Information Architecture section defines and currently uses for nothing.
- **First content**: `buckets_consumed / buckets_total`. Item #10 in `hud.md`'s
  information inventory must move from **Contextual** to **On Demand**.
- **Zone assignment is undecided** — owned by ADR-0010, which must also state how it
  interacts with the single Z2 slot (P5).

**Accessibility**

- This pattern **is** the mechanism satisfying the objective-clarity commitment. It is
  not a convenience.
- Must be available in every gameplay state where its content is meaningful, **including
  while paused** — a player who pauses to think is precisely the player who needs it.
- Must not be the only channel for anything needed reflexively under time pressure. A
  hold gesture costs time.

**When to Use**: information needed occasionally rather than continuously, where a
permanent element would breach a density budget and a transient one (P4) would be missable.

**When NOT to Use**: information needed reflexively under time pressure; anything the
player must react to rather than consult.

**Reference**: `design/accessibility-requirements.md` § Objective clarity — the conflict
and its resolution.

---

### P7 — Paged Diagnostic Overlay *(dev tier)*

**Category**: Developer tooling
**Used In**: `hud.md` E7 (Z4)
**Status**: Draft — **dev tier, reduced contract**

> **This pattern is not player-facing and is not bound by the player-UI contract.**
> `hud.md` U8.2 places the diagnostic overlay in a separate tier: off by default,
> stripped at export, and carrying **no accessibility, localization, or art contract**.
> It is catalogued so a second dev tool does not reinvent the paging convention — not
> because it is a UI standard.

**Specification**

- **Paging**: one key cycles through pages and back to off. E7 uses
  `Off → Gravity → Player → Watering → Oxygen → Level → Validation → Collision → Off`.
- **Off by default.** The player never sees it without deliberately enabling it.
- **Stripped at export.** The mechanism is unspecified — see Open Question O4.
- **Screen-anchored**, unlike P1 and P2. It does not track a world entity.
- **Pages should compute, not dump.** E7's collision page flags every `Area2D` whose
  mask ∧ player layer == 0 rather than printing raw values. A raw dump still needs a
  human to notice that `1 & 2 == 0`; the computed check is what catches BUG-0001.
- Requires an input action that does not exist — see Open Question O3.

**Accessibility**: **none required.** This is a deliberate exemption, not an oversight.

**When to Use**: developer diagnostics that must be readable in a running build without
a debugger or logs.

**When NOT to Use**: anything player-facing. The exemptions above are exactly why.

**Reference**: `hud.md` E7, U8.2, U8.3, U8.13, U8.14.

---

### P8 — Button

**Category**: Input / Control
**Used In**: `main-menu.md`, `pause-menu.md`
**Status**: Draft

**Description**: A discrete labelled target that performs exactly one action when
activated. **This is the first pattern in the project that takes input** — P1 through P7
are all read-only, and `hud.md` states keyboard navigation is "not applicable" precisely
because no HUD element is interactive. This pattern is where that stops being true.

**Specification**

- **Five states**: Normal, Focused, Hovered, Pressed, Disabled.
- **Focus and hover are independent and may co-occur**, and must remain distinguishable
  from each other. The reachable case is ordinary: the player navigates by keyboard to
  one button while the mouse happens to rest over another. Both indicators show at once,
  and the focused one is the one that will activate.
- **Hover never moves focus. Only a click does.** A mouse coming to rest mid-keyboard
  navigation would otherwise silently relocate the activation target, so the player's
  next `ui_accept` would fire something they never selected.
- **Activation**: `ui_accept` while focused, or a left-click press and release both landing
  on the same button. A press that begins on the button and releases off it is **cancelled** —
  the standard affordance for changing your mind mid-click.
- **One action, never a toggle.** A button that changes its own label to report a state it
  holds is a different pattern, and that pattern does not exist yet — see
  *Gaps & Patterns Needed*.
- **Disabled buttons stay visible and readable. They are not removed.** *This is a
  consequence of P9, not a visual preference*: navigation order must not change between
  visits, and removing an item renumbers every item after it. A disabled button is not
  focusable, not hoverable and not activatable, and it must still be legible enough to
  read as "this exists but is unavailable now" rather than as a rendering fault.
  ⚠ **Unset**: how a disabled button communicates *why* it is unavailable. A player who
  cannot tell why is stuck. **Owner: ux-designer**, at the first screen that actually needs
  a disabled state.

**Visual treatment is deferred, not restated.** `art-bible.md` §7.3 fixes the plate family
(thin rectangle sized to content, no rounded corners, no drop shadow, no gradient fill),
§7.1 the monospace pixel-grid type, §4.1 the 56-entry NES palette, and §2.7 the tone —
the station's own status screen, never a warmer menu aesthetic. §7.4 carries the ⚠ for
full menu visual layout with **owner ux-designer**, *"once a settings-screen UX spec exists
for this section to art-direct against."* That ordering is the right one and this pattern
respects it: **behaviour is specified here, appearance is owed by §7 afterwards.**

**Accessibility**

- Label text **≥ 15 design px** — the menu floor, not the ≥ 12 px HUD floor.
- Must clear that floor at **1× and 2× only**. `default_texture_filter=0` (nearest) makes
  any non-integer factor shimmer, so 1.5× is forbidden project-wide.
- Label contrast **≥ 4.5:1** against its own plate.
- **Focus must not be indicated by colour alone.** The project's standing no-colour-only
  rule applies here with more force than anywhere else, because at this tier the focus
  indicator is the *entire* affordance telling the player what will happen next — see P9.
  A positional or shape cue is required: an offset marker, or a full-perimeter outline that
  changes weight rather than only hue.
- **Motion-free by default.** No scale, bounce or slide on press or focus. Reduced motion is
  **elevated** for this project rather than optional, so a suppressible animation is a worse
  answer than an animation that was never added, and a static treatment already matches
  §2.1's flat, gradient-free register.
- Screen reader behaviour is **not committed** — see Open Question O8, which records that the
  documented reason for declining it no longer holds.

**When to Use**: any discrete, immediate, single-outcome action in a menu.

**When NOT to Use**: anything that holds and reports a state (needs a toggle); anything
continuous (needs a slider); anything that captures a raw keypress rather than an activation
(needs a capture field). None of those three patterns exists yet.

**Reference**: `art-bible.md` §2.7, §7.1, §7.3, §7.4 · `accessibility-requirements.md`
§ Visual (menu text floor, integer scaling) · P9 below.

---

### P9 — Focus & Navigation Order

**Category**: Navigation / Input
**Used In**: `main-menu.md`, `pause-menu.md`
**Status**: Draft

**Description**: The rules that make a keyboard-operable screen navigable and *learnable* —
what holds focus on open, how focus moves, and what may never happen to it.

**Specification**

- **Focus is never null while a menu is open.** This is a keyboard-and-mouse game with no
  gamepad and no touch (`technical-preferences.md`), so a menu with nothing focused is a
  menu the player cannot operate at all without reaching for the mouse. There is no state
  in which "nothing is selected" is acceptable.
- **Every screen declares its initial focus target explicitly.** Never left to scene-tree
  order, which is an accident of authoring rather than a decision.
- **Navigation order is authored and stable across visits.** This is what P8's
  "disabled, not removed" rule protects: a player who learns "Resume is second" must find
  it second every time.
- **Movement**: `ui_up` / `ui_down` move within the list, and **wrap at both ends**.
- **Multi-column and grid navigation are deliberately not authored.** Both screens using
  this pattern are single vertical lists. A rule invented for a layout nothing uses would be
  a rule the next author has to either follow or argue with, for no benefit. **Owner:
  ux-designer**, at the first screen that needs one.
- **A click into dead space must not clear focus.** Losing focus to an empty region would
  put the screen into the null state the first rule forbids.
- **Back / cancel is screen-level, not focus-dependent.** `ui_cancel` acts on the screen no
  matter which element holds focus. A visible Back or Resume button may exist as well, and
  when it does, **both must invoke the same handler** — two paths to one exit, never two
  implementations of it.
- **Mouse and keyboard stay coherent**: clicking a button moves focus to it, so a player
  who switches from mouse to keyboard resumes from where they clicked rather than being
  thrown back to the initial target.

**Accessibility**

- At this tier the focus indicator **is** the accessibility affordance for menu navigation.
  Screen reader support is declined at Comprehensive (see O8), so nothing else is carrying
  this information. P8's non-colour-only requirement therefore admits no exception here.
- The indicator must survive 2× UI scaling without clipping, and must not rely on a
  sub-pixel outline that the nearest filter cannot render at 1×.

**Engine notes** *(behaviour-level; the node contract is unowned — see O9)*

- **No new input actions are owed by P8 or P9.** Godot's `ui_accept`, `ui_cancel`, `ui_up`
  and `ui_down` are engine built-ins and do not appear in `project.godot`, which declares
  only the five gameplay actions (`move_left`, `move_right`, `interact`, `jump`, `crouch`).
  This distinguishes these two patterns from P3, P6 and P7, whose three missing actions are
  still open under O3.
- ⚠ **A pause action does not exist.** No entry in `project.godot` opens a menu. This is
  owed by the pause-menu spec, not by this library.

**When to Use**: every screen that accepts input. There is no screen this pattern is optional for.

**When NOT to Use**: non-interactive overlays — P1 through P7 need none of it.

**Reference**: `.claude/docs/technical-preferences.md` § Input & Platform ·
`accessibility-requirements.md` § Motor, § Visual · P8 above.

---

## Gaps & Patterns Needed

**Partly closed 2026-08-18.** P8 (Button) and P9 (Focus & Navigation Order) now exist —
the two patterns the main-menu and pause-menu specs consume. **The settings screen is
still unowned, and the three patterns only it needs were deliberately not authored.**

`design/accessibility-requirements.md` commits to full input remapping, one-hand presets,
adjustable text size, and reduced motion. **Every one of those needs a settings screen.**
No settings UX spec exists, and ADR-0010 — which was expected to own it — states plainly
that it does not deliver it: *"Owner: unassigned. Prerequisite: a settings-screen UX spec."*
Accessibility `T4`, `T5` and `T6` stay blocked until it exists.

| Pattern needed | Driven by | Notes |
|---|---|---|
| Slider / range control | Text size, `drain_rate` | `drain_rate` 0.5–1.0 needs a continuous control; text scale does **not** — it has exactly two legal values (1× and 2×), so it may be better served by the toggle below than by a slider. Decide at the settings spec, not here |
| Key-rebinding capture field | Input remapping | Must show the current binding, capture the next keypress, and refuse duplicates. See **O10** — it must also account for menu built-ins the player cannot see |
| Toggle / checkbox | Reduced motion, hold-to-toggle, one-hand preset | Several boolean settings are committed. Distinct from P8: a toggle reports a state it holds, a button does not |

**Deliberately deferred, with the reasoning recorded.** Authoring these three would have
meant designing the settings screen inside a pattern library — the same failure mode as
designing a pattern inside a screen spec, in the opposite direction. Settings was held out
of scope on 2026-08-18 so that the two screens the pre-production gate actually requires
could be specified against patterns that exist. **Owner: unassigned. The next step for all
three is a settings-screen UX spec, not an addition to this file.**

> **The sequencing advice in v1.0 of this section is now moot.** It read *"A settings-screen
> UX spec should precede ADR-0010, not follow it."* ADR-0010 was Accepted on its own terms
> and explicitly declined to design the screen, so the ordering it warned about has already
> happened. What remains is not a sequencing problem but an ownership one.

---

## Open Questions

| # | Question | Affects | Owner |
|---|---|---|---|
| O1 | **P2's offset direction under non-default gravity is unspecified.** P1 was keyed to eased gravity-up; P2 still offsets toward viewport-up, so a ceiling-mounted object under inverted gravity renders its panel into the geometry. Deferred deliberately — P2 tracks *static* objects, so its anchor may belong to the mounting surface rather than to gravity, and P1's fall-path reasoning does not decide it | P2 | ADR-0010. Inherited from `hud.md` Q17, not new |
| O2 | **No character budget for P2's action label** — the only player-facing string in the game. A 40% translation expansion widens the panel, which feeds the displacement rule | P2 | `hud.md` |
| O3 | **Three input actions are required and none is bound**: the diagnostic paging key (P7), the on-demand query key (P6), and the toggle alternative for P3 if it needs its own binding | P3, P6, P7 | `project.godot` |
| O4 | **How P7 is stripped at export is unspecified** — feature tags, conditional instancing, or something else | P7 | Build configuration. Inherited from `hud.md` Q14 |
| O5 | **P6 has no zone assignment.** It is committed but unplaced | P6 | ADR-0010 |
| O6 | **Should P7 remain in this library long-term?** It is catalogued with a reduced contract, which is a compromise. A separate dev-tooling document may be the better home once a second dev tool exists | P7 | ux-designer |
| O7 | ~~**No art bible.**~~ **CLOSED 2026-08-18.** `art-bible.md` is complete, all 9 sections. Panel treatment is fixed by §7.3, typography by §7.1, outline method by §7.5, palette by §4.1. Menu *layout* remains ⚠ unset in §7.4 — that is a live item, but it is owed by §7 to these specs rather than by these specs to §7 | All | Closed |
| O8 | **The screen-reader decline has outlived its stated reason.** `accessibility-requirements.md` places screen reader support out of scope at Comprehensive tier, giving as the reason that *"No menu system exists to read, and Godot AccessKit covers Controls rather than the game world."* Both halves turn on menus. P8/P9 and the two 2b screen specs create exactly the Control-based menu system that sentence says does not exist, and Godot 4.5+ integrates AccessKit specifically over Control nodes — though every Control ships with **no accessible role or name until one is explicitly configured**, so this is a real cost, not a free win. **The decision has not been revisited, and is not revisited here.** The out-of-scope entry's other reason — that this game is entirely spatial and visual — is untouched by any of this and may well still carry the decision on its own | Menus, P8, P9 | accessibility-specialist |
| O9 | **No ADR owns menu screen architecture.** ADR-0010 owns HUD composition and `SceneTree.paused`, and states it *"renders no menu"*. Nothing owns the node-level contract for a menu screen — scene structure, focus wiring, process modes, or how a menu scene is instanced and freed. P8 and P9 specify behaviour only and stop at that boundary deliberately | P8, P9, `main-menu.md`, `pause-menu.md` | technical-director |
| O10 | **Menu built-ins and remappable gameplay actions share one `InputMap`.** `ui_accept` binds Space by default, which is also `jump`; `accessibility-requirements.md` commits to rebinding any of the five gameplay actions to *any* key. Menus and gameplay never accept input in the same frame, so this is **not a live defect** — but a remapping UI must not report a key as free when a menu built-in still consumes it, and the player cannot see the built-ins to reason about them | Key-rebinding capture field | The deferred settings spec |
