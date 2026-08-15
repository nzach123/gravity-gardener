# Accessibility Requirements: Gravity Gardener

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-15
> **Accessibility Tier Target**: Standard, with reduced motion elevated from Comprehensive
> **Platform(s)**: PC
> **External Standards Targeted**:
> - WCAG 2.1 Level AA
> - Game Accessibility Guidelines
> - Console guidelines (XAG, Sony): **not targeted** — PC is the only platform
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/hud.md`,
> `design/ux/interaction-patterns.md`

> **Why this document exists**: Per-screen accessibility annotations belong in UX
> specs. This document holds the project-wide commitments, the feature matrix across
> all systems, the test plan, and the audit history. If a feature conflicts with a
> commitment made here, this document wins — change the feature, not the commitment,
> unless the change is approved as a formal revision.
>
> **When to update**: After each `/gate-check` pass, after any accessibility audit,
> and whenever a new system is added to `systems-index.md`.

> **File location**: This file sits at `design/accessibility-requirements.md`, not at
> the `docs/` path used by the document templates. Five skills read this path:
> `/gate-check`, `/architecture-review`, `/create-architecture`, `/team-ui` and
> `/ux-design`. The decision was made on 2026-08-15.

---

## Accessibility Tier Definition

> **Why define tiers**: Accessibility is not binary. Four tiers give the team a shared
> vocabulary, force an explicit commitment at the start of production, and stop scope
> creep in both directions — "we will add it later" and "we have to support everything".

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires colour discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colourblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, colour, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**, with **reduced motion** elevated from Comprehensive.

#### Rationale

This is a single-player 2D puzzle-platformer on PC, played with keyboard and mouse
only (`.claude/docs/technical-preferences.md`). That platform choice removes several
Standard commitments before any work starts: there is no gamepad to remap, no touch
target to size, and no console certification floor to clear.

Two Standard commitments are already satisfied by decisions made in `design/ux/hud.md`.
Colour independence is carried by static tick marks and numerals rather than by a
colourblind mode (U8.8), so no band depends on colour to be read. The "no timed input
that cannot be extended" requirement has a mechanism already designed:
`suit-oxygen.md` §7 designates `drain_rate` (range 0.5–1.0) an accessibility hook,
which extends every oxygen deadline in the game by up to double.

Two Standard commitments are genuinely new work: **full input remapping** and
**adjustable text size**. Neither exists today. The input map is five fixed actions
(`project.godot`), and `hud.md` H24 is blocked precisely because no text-size option
exists to test against.

**Reduced motion is elevated because of what this specific game does.** In `level_01`
and `level_07` the camera rotates the entire viewport through 0.6 s on every gravity
flip (`main.gd:36–41`). Rotating a whole viewport is a recognised vestibular trigger,
and gravity flipping is this game's core mechanic rather than an effect in one scene.
A motion-sensitive player is therefore excluded from the game, not from a feature.
`hud.md` Finding 1 establishes that offering the option requires decoupling three
currently-entangled concerns — camera follow, camera rotation, and input-basis
inversion — which is an architecture change. Elevating it here is what makes that
change an obligation rather than a wish.

**Exemplary is not achievable.** It requires a third-party audit and a dedicated
accessibility budget. Neither exists.

**No claim is made here about how many players each commitment serves.**
`design/gdd/game-concept.md` does not exist, so this project has no documented target
audience to reason from. The commitments above are justified by the game's mechanics,
not by audience research.

#### Features explicitly in scope, beyond the Standard baseline

| Feature | Elevated from | Why |
|---|---|---|
| Reduced motion | Comprehensive | The 0.6 s viewport rotation is core to the game, not incidental to it. See the rationale above |
| One-hand mode | Standard baseline | Remapping alone would leave the player to build the layout themselves. Five actions and no chorded inputs make presets cheap, so the game commits to the mode rather than to the possibility. See Motor Accessibility |

#### Features explicitly out of scope

**Inert, not declined** — the obligation exists but has nothing to attach to yet:

| Feature | Why it is inert | When it activates |
|---|---|---|
| Subtitles and captions | No audio system exists — zero audio files and zero `AudioStream` references in `src/` | The first time audio carries information. See Auditory Accessibility |
| Independent volume controls | Same — there are no audio buses to control | Same |

**Declined for this tier**:

| Feature | Tier | Why |
|---|---|---|
| Screen reader support | Comprehensive | No menu system exists to read. See Known Intentional Limitations |
| Difficulty assist modes | Comprehensive | `drain_rate` already provides the one difficulty axis this game has |
| HUD element repositioning | Comprehensive | `hud.md` shows the player two elements at most, and Z1 tracks the player rather than occupying a fixed corner. There is little to reposition |

---

## Visual Accessibility

### Design resolution basis

`project.godot` sets **no** viewport width or height, so the design canvas is Godot's
default **1152 × 648**. It is presented with `stretch/mode="canvas_items"` and
`stretch/aspect="expand"`.

Every pixel figure below is stated in **design-space pixels**, not screen pixels. The
1080p equivalent is given for cross-reference only (design px × 1.667). The unstated
design resolution is logged in Open Questions — a default is not a decision.

`default_texture_filter=0` (nearest) applies project-wide. **Any scaling of text or UI
must use integer factors.** Non-integer scaling shimmers on a nearest-filtered
pixel-art canvas.

### Feature commitments

| Feature | Tier | Scope | Status | Notes |
|---|---|---|---|---|
| Minimum text size — HUD critical | Standard | E1 numerals | Not Started | **≥ 12 design px** (≈20 px at 1080p). E1 numerals appear only at caution (≤ 0.50) and are gameplay-critical |
| Minimum text size — prompts | Standard | E2 label, E5 tally | Not Started | **≥ 12 design px**. E2's label is the only player-facing string in the game |
| Minimum text size — menu UI | Standard | Future menus | Not Started | **≥ 15 design px** (≈24 px at 1080p). No menu exists yet |
| Text contrast | Standard | All HUD text | Not Started | ≥ 4.5:1 against the **worst-case** background, not the average one. E1–E4 render over arbitrary terrain, so each needs the black outline or a backing plate |
| Outline colour is black, not white | Standard | E1–E4 | **Committed** | Fixed by `hud.md`. On `#FFFFFF` the critical band falls to ~3.9:1 and fails AA. On `#000000` all four bands clear 4.5:1 |
| UI / text scaling | Standard | HUD text, future menus | Not Started | **Integer factors only — 1× and 2×.** The nearest filter forbids 1.5×. This is a narrower range than the template's 75–150%, and the constraint is the renderer rather than a preference |
| Colourblind support | Standard | E1 bands | **Committed by design** | Delivered by tick marks and numerals rather than by a palette-swap mode. See the audit below |
| Motion reduction | **Elevated** | Camera rotation, all HUD | Not Started | Must disable the 0.6 s viewport rotation **without** disabling camera-follow and **without** leaving the input basis inverted. Blocked on the three-way decouple named in `hud.md` Finding 1 |
| Photosensitivity | Basic | All visual output | **Satisfied today** | No flashing content exists. `hud.md` U8.9 fixes oxygen escalation as "colour + content only — nothing moves". Treat this as a standing constraint, not a passed test |
| High contrast mode | Comprehensive | — | Out of scope | Tier |
| Brightness / gamma controls | Basic | — | Not Started | No settings menu exists to host it |

### E1 band contrast

Measured against `#000000`. Text is `#FFFFFF`; outline and backing are `#000000`,
matching `debugger.gd`'s existing black outline at size 4.

| Band | Colour | Contrast vs `#000000` | Verdict |
|---|---|---|---|
| Nominal | `#61D3E3` cyan | ~11.8:1 | ✅ AA |
| Caution | `#EBD320` yellow | ~13.7:1 | ✅ AA |
| Warning | `#FFA200` orange | ~10.4:1 | ✅ AA |
| Critical | `#E35100` red-orange | **~5.4:1** | ✅ AA |

> **The critical-band figures in `hud.md` are wrong.** `hud.md:666` states ~5.9:1 and
> `hud.md:671` states ~3.5:1 on white. Recomputed values are **~5.4:1** on black and
> **~3.9:1** on white. Both of `hud.md`'s conclusions still hold — the critical band
> clears AA on black and fails it on white — so only the numbers are wrong. This
> repeats the 2026-08-15 `/ux-review` advisory finding 4, which was never applied.
> Use the figures in this table.

### Colour-as-Only-Indicator Audit

| Location | Colour signal | Communicates | Non-colour backup | Status |
|---|---|---|---|---|
| E1 oxygen gauge | Cyan → yellow → orange → red-orange | Threshold band | Numerals at ≤ 0.50, **plus** static tick marks at 0.50 / 0.25 / 0.10 — every crossing is readable as position | **Resolved** |
| E4 pour refusal | Unknown | Plant is at capacity | **Not yet specified.** `hud.md` E4 defines the content as "a capped / complete state marker" without stating whether the marker is colour, shape, or icon | **Open** — owed to the art bible or ADR-0010 |
| Gravity direction | None | Which way is down | Sprite rotation — geometric, never colour | **N/A** |
| E7 debug overlay | Various | Diagnostics | None required — dev-only, stripped at export (U8.2) | **Out of scope** |

**Warning and critical sit adjacent in hue**, which is weak for protanopia and
deuteranopia. That is acceptable here **only** because colour independence is carried
by the tick marks and numerals. If the tick marks are ever removed, this row becomes a
failure.

---

## Motor Accessibility

| Feature | Tier | Scope | Status | Notes |
|---|---|---|---|---|
| **One-hand mode** | **Elevated** | All gameplay | Not Started | Two selectable presets — left-hand and right-hand — covering all 5 actions. Presets are a starting point the player may then remap freely, not a locked layout |
| Full input remapping | Standard | All 5 gameplay actions | Not Started | `move_left`, `move_right`, `jump`, `interact`, `crouch`. **Any action to any key, numpad included** — the one-hand presets depend on this being unrestricted. Must prevent duplicate bindings and persist across restart |
| Input method switching | Standard | — | **N/A** | Keyboard only. No gamepad and no touch, so no prompt-swapping problem exists |
| Hold-to-toggle — pour | Standard | `interact` during pour | Not Started | **The one long hold in the game**: `water_duration`, default 5.0 s, range 2.0–8.0 s. Toggle mode = first press begins the pour, second press abandons it. **Obligation on ADR-0009** — see below |
| Hold-to-toggle — crouch | Standard | `crouch` | Not Started | Gesture not yet audited. `crouch` does not appear in `player.gd`. Audit before implementing |
| Rapid input alternatives | Standard | — | **N/A** | No button mashing anywhere in the design. Checked against all four GDDs |
| Timing extension | Standard | Oxygen deadlines | **Mechanism exists** | `drain_rate` 0.5–1.0 extends every oxygen deadline by up to **2×**. This is below the template's 3× guidance. The cap is set by `suit-oxygen.md` §7, so widening it needs a GDD change, not a settings change |
| Aim assist | Standard | — | **N/A** | No ranged combat and no targeting |
| Movement assists | Standard | — | **N/A** | No sprint, and no movement input that is held continuously |
| Platforming assists | Standard | Jump | **Partially satisfied already** | `player.gd:23` sets `coyote_time = 0.12`, and a jump buffer exists (`player.gd:153`). **Neither is documented in any GDD.** Expose both as tunable rather than fixed |
| HUD element repositioning | Comprehensive | — | Out of scope | Tier |

### One-hand mode — reference presets

Testable candidates, not locked values:

| Preset | Move | Jump | Interact | Crouch |
|---|---|---|---|---|
| Left hand | `A` / `D` | `Space` (thumb) | `E` | `Shift` |
| Right hand | `←` / `→` | `↑` | `RCtrl` | `↓` |

**The left-hand preset is close to the current defaults**, which already cluster in the
left-hand region. The preset formalises and tests that rather than inventing it. The
right-hand preset needs no key region beyond the arrow cluster and the right modifier
keys.

**What makes this feasible at all**: five actions, no mouse input during gameplay, no
chorded presses, and a player who is locked during a pour so no hold-while-moving case
exists. **If a sixth action is added, or any action becomes a chord, this commitment
must be re-audited.**

### The pour hold, and why it is not a conflict

`watering-system.md` R4 resets `water_progress` to 0 on early release and keeps the
bucket, with no partial credit (AC3). A toggle alternative preserves that rule exactly.
It changes only which gesture signals abandonment.

**ADR-0009 must define pour abandonment as gesture-agnostic**, so that hold-release and
toggle-press are the same event. `hud.md` U10.3's paused-state rule — "on unpause:
`interact` still held → resume" — also needs restating in gesture-agnostic terms.

### Undocumented assists already shipping

`coyote_time` (0.12 s) and the jump buffer are accessibility features this project
already has and cannot currently claim, because no design document mentions them. They
belong in `gravity.md` §7 as tuning knobs. Recorded here so the gap is not lost.

---

## Cognitive Accessibility

| Feature | Tier | Scope | Status | Notes |
|---|---|---|---|---|
| Difficulty options | Standard | Oxygen pressure | **Mechanism exists** | `drain_rate` is the one difficulty axis this game has. Granular by nature — a continuous 0.5–1.0 range, not an Easy/Normal/Hard label |
| Pause anywhere | Basic | All gameplay states | Not Started | `suit-oxygen.md` §5 already requires that pausing halts drain, and `hud.md` U10.3 defines the frozen HUD state. **No pause exists in `src/` yet** — the requirement is specified and unimplemented |
| Tutorial persistence | Standard | — | **N/A today** | No tutorial or help system exists. Activates if one is added |
| Objective clarity | Standard | Level progress | **Committed — on-demand tally** | See the resolution below |
| Reading time for auto-dismissing UI | Standard | E5 tally | **Committed — on-demand tally** | E5 keeps its 1.2 s duration. The on-demand channel is what satisfies this row, not a longer E5 |
| Visual indicators for audio-only info | Standard | — | **N/A** | No audio exists. See Auditory Accessibility |
| Cognitive load per system | Comprehensive | Per system | Documented below | Not a hard limit — a review trigger |
| Navigation assists | Standard | — | **N/A** | Levels are single-screen. No world map, no fast travel, no waypoints |

### Objective clarity — the conflict and its resolution

**The problem.** E5 is the only place `buckets_consumed / buckets_total` ever appears,
and it shows for 1.2 s after a pour, then clears. A player who looks away, or who
returns after a break, has no way to ask how many plants remain. The information lives
in `LevelState` and is never queryable.

**Why it exists.** This follows from a deliberate decision, not a defect. `hud.md` U8.1
commits to a minimal, adaptive, diegetic HUD, and U8.19 caps the screen at two
player-facing elements. An always-visible tally would spend the second slot permanently
and is exactly what that philosophy excludes.

**The resolution: an on-demand tally.** The player holds a key and the tally shows for
as long as it is held. This satisfies both commitments:

- It honours U8.19, because the element is player-invoked and transient rather than
  permanent.
- It matches `hud.md`'s own **On Demand** category, which the Information Architecture
  section already defines and currently uses for nothing.
- **E5 keeps its 1.2 s duration.** U10.4 fixed that value on a structural argument —
  above roughly 2.0 s an E5 queue becomes possible and the spec has no queue rule. This
  resolution does not reopen it.

**Obligations this creates** — none of them belong to this document:

| Owner | Obligation |
|---|---|
| `project.godot` | **A second new input action.** The input map already owes one for `hud.md`'s F3 debug toggle. This adds a progress-query action. Both are unbound today |
| `hud.md` | A new on-demand element, and item **#10 (level progress)** re-categorised from Contextual to **On Demand** in the Information Architecture section |
| ADR-0010 | Owns the element's design and its interaction with the single Z2 slot and the two-element budget |

### Cognitive load

| System | Simultaneous things tracked | Count |
|---|---|---|
| Gravity | Current down-direction, own momentum | 2 |
| Watering | Carrying or not, which plants remain, plant capacity, bucket locations | 4 |
| Oxygen | Time remaining, threshold band | 2 |
| Props | None — props never affect solvability (`physics-props.md` R1) | 0 |

**Combined peak is 6–8 during a fetch leg**, above the template's review threshold of 4.
The compensating clarity is that watering's four items are *spatial* — they are read
from the level itself rather than held in memory.

That compensation fails precisely for the tally, which has no spatial representation.
This is the same finding as the objective-clarity conflict above, reached from a
different direction, and the on-demand tally is what closes it.

---

## Auditory Accessibility

**No audio system exists.** `src/` contains zero audio files and zero `AudioStream`
references, and no GDD specifies a sound. Every row below is therefore **inert** — the
obligation is real, but it has nothing to attach to yet. Each row names what activates
it.

| Feature | Tier | Status | Activates when |
|---|---|---|---|
| Subtitles for spoken dialogue | Basic | **Inert** | The game gains voiced content. None is designed |
| Captions for gameplay-critical SFX | Comprehensive | **Inert** | A sound first carries information the player cannot see |
| Independent volume controls | Basic | **Inert** | The first audio bus exists. Four sliders minimum: music, SFX, UI, voice |
| Mono audio option | Comprehensive | **Inert** | Audio becomes stereo or positional |
| Visual indicators for directional audio | Comprehensive | **Inert** | A sound first communicates off-screen position |
| Hearing aid compatibility | Standard | **Inert** | Any cue relies on frequencies above 4 kHz |

> **One obligation is already live.** `hud.md` E6 specifies the death sequence as
> "Visual and audio effects". That is the first audio in the game and it is already
> designed. It satisfies the rule on arrival, because E6 carries a visual channel in the
> same element — the audio is reinforcement, never the sole signal. **Keep it that way.**

### Gameplay-Critical SFX Audit

Seeded with the one sound the project has specified. Add a row for every sound that
changes what the player should do next.

| Sound Effect | What it communicates | Visual backup | Caption required | Status |
|---|---|---|---|---|
| E6 death sequence | The player died; a restart follows | **Yes** — E6's visual effect, in the same element | No — the visual is sufficient and simultaneous | Specified, not implemented |

---

## Platform Accessibility API Integration

PC is the only target. Console rows are absent rather than marked N/A — they were never
in scope. The renderer is GL Compatibility, which affects none of the below.

| Platform | API / Standard | Features planned | Status | Notes |
|---|---|---|---|---|
| Windows (PC) | Godot AccessKit | Menu screen-reader exposure | **Not applicable yet** | Godot 4.5+ ships AccessKit for supported Control types. **No menu system exists**, so there is nothing to expose. Revisit when the first menu is authored |
| Steam | Steam Input | System-level remapping | Not Started | Steam Input remaps at the OS layer. It **complements** in-game remapping and does not replace it — a player outside Steam gets nothing from it |
| Windows | Narrator / NVDA / JAWS | Menu navigation announcements | **Not applicable yet** | Depends on the AccessKit row above. Requires accessible names and roles on Control nodes |

---

## Per-Feature Accessibility Matrix

One row per system in `systems-index.md`, plus the HUD. **When a system is added to the
systems index, a row must be added here.**

| System | Visual | Motor | Cognitive | Auditory | Addressed | Notes |
|---|---|---|---|---|---|---|
| Gravity | **Vestibular — the 0.6 s viewport rotation on every flip** | Input basis inverts with gravity | Player must re-read which way is down | None | **Partial** | Reduced motion is committed but blocked on the three-way decouple |
| Watering | E4's marker form unspecified | **The 2–8 s pour hold** | Plant capacity and bucket locations tracked spatially | None | **Partial** | Toggle committed; owed to ADR-0009 |
| Suit Oxygen | E1 band colours | Timed pressure on every action | Time remaining held in working memory | None | **Yes** | `drain_rate` extends deadlines to 2×; tick marks and numerals carry the bands |
| Physics Props | None | None | None | None | **N/A** | `physics-props.md` R1 keeps props off the solution path entirely |
| HUD | Text size, contrast, colour bands | None — no HUD element takes input | The tally was unqueryable | **Inert** | **Partial** | Colour resolved; text scaling not started; on-demand tally committed |

---

## Accessibility Test Plan

| # | Feature | Method | Pass criterion | Owner | Status |
|---|---|---|---|---|---|
| T1 | Text contrast | Measure every band and text colour against its worst-case background | All ≥ 4.5:1 | ux-designer | **Runnable now** |
| T2 | Colour independence | View E1 in greyscale at each band | Band is identifiable from tick-mark position and numerals alone | ux-designer | **Runnable now** |
| T3 | `drain_rate` readout | Set `drain_rate = 0.5`, compare E1 against a stopwatch | E1 reads real seconds remaining, not raw `oxygen_remaining` | qa-tester | **Runnable now** |
| T4 | Text scaling | Render all HUD text at 1× and 2× | No shimmer, no clipping, no overlap at either factor | ux-designer | Blocked — no scaling option exists |
| T5 | Input remapping | Rebind all 5 actions to non-default keys, complete a level | All actions work; duplicate bindings refused; bindings persist across restart | qa-tester | Blocked — no remapping exists |
| T6 | One-hand presets | Complete a full level on each preset, left and right tested separately | Level completable with one hand on each preset, with no key outside that hand's reach | qa-tester | Blocked — depends on T5 |
| T7 | Pour toggle | Complete and abandon a pour in toggle mode | AC2 and AC3 both hold in toggle mode exactly as in hold mode | qa-tester | Blocked — owed to ADR-0009 |
| T8 | Reduced motion | Enable the option in `level_01`, flip gravity | Viewport does not rotate; camera still follows; controls are **not** inverted | qa-tester | Blocked — needs the three-way decouple |
| T9 | Pause halts drain | Pause mid-level, wait, unpause | `oxygen_remaining` is unchanged across the pause; HUD freezes per U10.3 | qa-tester | Blocked — no pause exists |

**Four of nine are runnable today.** Every blocked test names its blocker, so none of
them is waiting on an unknown.

---

## Known Intentional Limitations

| Feature | Tier required | Why not included | Risk / impact | Mitigation |
|---|---|---|---|---|
| Screen reader support | Comprehensive | No menu system exists to read, and Godot AccessKit covers Controls rather than the game world | Blind players cannot play. This game is entirely spatial and visual, so no realistic mitigation exists at any tier | None. Recorded honestly rather than softened |
| High contrast mode | Exemplary | Tier. The NES palette is a fixed project-wide art constraint (U8.15), so a high-contrast palette would contradict the art direction | Affects low-vision players who need more separation than the palette gives | The black outline requirement already forces every element to its maximum available contrast |
| HUD element repositioning | Comprehensive | Tier, and there is little to reposition — at most two elements, and Z1 tracks the player rather than occupying a corner | Low | Z1 already moves with the player, which covers most of what repositioning would give |
| Timing extension caps at 2×, not 3× | Standard | **Not a scope choice.** `suit-oxygen.md` §7 fixes `drain_rate` at 0.5–1.0, so 2× is the ceiling the GDD allows | Players needing more than double time cannot complete oxygen-limited levels | Widening the range is a GDD amendment, not a settings change. Raise it if playtesting shows 2× is short |

---

## Audit History

No accessibility audit has been performed.

**Authoring this document is not an audit.** The first entry belongs to the first time
the committed features are tested against a build.

| Date | Auditor | Type | Scope | Findings | Status |
|---|---|---|---|---|---|
| — | — | — | — | — | None yet |

---

## External Resources

| Resource | URL | Relevance |
|---|---|---|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast ratios and text sizing — the standard this project's AA target refers to |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist organised by implementation cost |
| AbleGamers | https://ablegamers.org/player-panel/ | User testing with disabled players |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free screenshot simulation — supports T2 |

Console guideline and CVAA links are deliberately absent: there is no console target and
the game has no communication features.

---

## Open Questions

| # | Question | Owner | Blocks |
|---|---|---|---|
| A1 | `design/gdd/game-concept.md` does not exist, so the tier scope is justified by mechanics rather than by any documented target audience | `/brainstorm` or `/reverse-document` | Nothing here. Blocks `/art-bible` |
| A2 | `design/player-journey.md` does not exist. Template is at `.claude/docs/templates/player-journey.md` | `/ux-design` | Nothing here |
| A3 | The design resolution is Godot's default 1152 × 648 and was never authored. Every pixel figure in this document rests on it | `project.godot` | T4 |
| A4 | E4's capped-plant marker form is unspecified — colour, shape, or icon. It is the one unresolved row in the colour audit | art bible / ADR-0010 | The colour audit |
| A5 | `crouch` has not been audited for hold-versus-tap. It does not appear in `player.gd` | ADR-0007 | The crouch toggle row |
| A6 | Two input actions are required and unbound: the F3 debug toggle (`hud.md` U8.13) and the progress-query action this document adds | `project.godot` | The on-demand tally |
| A7 | The reduced-motion decouple — camera follow, camera rotation, input-basis inversion — has no owning ADR | technical-director | T8, and the elevated commitment |
| A8 | `hud.md:666` and `hud.md:671` carry wrong critical-band contrast figures (~5.9 and ~3.5; correct values ~5.4 and ~3.9). Conclusions unchanged | `hud.md` | Nothing. Cosmetic but repeated |
