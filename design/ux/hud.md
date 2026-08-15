# HUD Design

> **Status**: Complete draft — all 8 sections authored and approved.
> Not yet validated with `/ux-review`.
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-15
> **Template**: HUD Design
> **Sources**: `suit-oxygen.md` (R7, §4, §5, AC9, AC10) · `watering-system.md` (R1, R3,
> R5, R6, §5, §6, AC5, AC12, AC14) · `gravity.md` and `physics-props.md` state no UI
> requirements

---

## HUD Philosophy

The player-facing UI is **minimal, adaptive, and diegetic**. Information lives in the
world rather than in a frame drawn around it. Interaction prompts float in world space
above the object they refer to, and appear only when the player is close enough to act
or is already acting. Nothing is docked permanently to a screen corner if it can be
attached to the thing it describes.

- **Minimal** — an element must earn permanence. The default answer to "should this be
  on screen" is no.
- **Adaptive** — density responds to what the player is doing: prompts appear on
  approach, escalate during an interaction, and disappear on departure.
- **Diegetic** — prefer the world object, the player sprite, or a surface inside the
  fiction over a screen-space overlay.

### Two GDD requirements this philosophy has to answer to

Neither is waived. Both are flagged here and resolved in later sections.

**1. `suit-oxygen.md` R7 — the oxygen readout must be *always visible*.** This is the
one value that cannot be proximity-triggered: R7 exists so "the player must never be
surprised by the tank running out." Minimal and diegetic can both still be honoured — a
gauge carried on the suit is diegetic and permanent at once — but **"adaptive" cannot
apply to its visibility.** Adaptive may still govern its *prominence* at the §4
thresholds (0.50 / 0.25 / 0.10). Resolved in HUD Elements.

**2. `watering-system.md` §6 assigns a carry indicator to the HUD.** Under a diegetic
stance the bucket is already in the player's hands, and AC14 requires the player read as
"visibly slower and visibly burdened." The world already carries this information, so a
screen-space indicator would be the least diegetic possible answer to it. **This spec
proposes satisfying §6 diegetically rather than with a HUD element** — a departure from
what that GDD says, recorded here rather than silently dropped.

### Developer diagnostic overlay — a separate tier, not player-facing

A second tier exists that this philosophy does **not** govern: a developer diagnostic
overlay. Key-toggled, off by default, **stripped from release exports**. It has no
player-facing contract — no accessibility tier, no localization, no art direction — and
it is permitted to be dense and ugly. Minimal / adaptive / diegetic apply to the player
UI only.

It supersedes `src/scripts/debugger.gd`, which is always-on when instanced,
movement-only, and reads `Player` fields directly.

Its requirement: **a developer must be able to diagnose a scene from the overlay alone**,
without attaching a debugger or reading the log — gravity state, player kinematics,
watering state, oxygen state, level-flow flags, load-time validation results, and
**collision layer/mask assignment**.

That last item is concrete, not speculative. **BUG-0001**: `KillArea2D` sets no mask, so
it defaults to `world`(1) while the player is on layer 2; `1 & 2 == 0` and the kill plane
is silently dead in `level_05` and `level_06`. Invisible in play *and* invisible in the
logs. A layer/mask readout catches that entire class of defect.

Because the overlay can be on screen alongside player UI, it **must not obscure any
player-facing element**. Resolved in Layout Zones.

---

## Information Architecture

### Full Information Inventory

| # | Information | Source | Owning system |
|---|---|---|---|
| 1 | `oxygen_remaining` / `oxygen_fraction` | `suit-oxygen.md` R7 | `OxygenState` |
| 2 | Threshold band — caution / warning / critical | `suit-oxygen.md` §4, AC10 | `OxygenTuning` |
| 3 | Death occurred | `suit-oxygen.md` R3; `spike_hazard`, kill area | `main.gd` restart path |
| 4 | Carry state | `watering-system.md` R1, §6 | `LevelState.carrying_bucket` |
| 5 | Interact prompt — pour available | `watering-system.md` R3 | `PlayerWateringComponent` |
| 6 | Pour progress — `water_progress` / `water_duration` | `watering-system.md` R3 | `PlayerWateringComponent` |
| 7 | Pour refusal — plant at capacity | `watering-system.md` R5, §5 | `Plant` |
| 8 | Plant capacity — `buckets_received` / `buckets_required` | `watering-system.md` R5 | `Plant` |
| 9 | Pickup refusal — 2nd bucket while carrying | `watering-system.md` R1, AC5 | `Bucket` |
| 10 | Level progress — `buckets_consumed` / `buckets_total` | `watering-system.md` R6, R8 | `LevelState` |
| 11 | Airlock unlocked — `goal_unlocked` | `watering-system.md` R6 | `LevelState` (derived) |
| 12 | Gravity direction | `gravity.md` | global gravity vector |

`gravity.md` and `physics-props.md` state no UI requirements. The developer diagnostic
overlay is a separate tier and is deliberately excluded from this categorization.

### Categorization

| # | Information | Category | Treatment |
|---|---|---|---|
| 1 | Oxygen readout | **Must Show** | The single permanent element. R7 forces it |
| 2 | Threshold band | **Must Show** | Not its own element — adaptive prominence of #1 |
| 3 | Death | **Contextual** | Shared cause-agnostic death sequence (below) |
| 4 | Carry state | **Hidden — diegetic** | Bucket in hands; AC14 burdened sprite read |
| 5 | Interact prompt | **Contextual** | World-space, above the plant, on approach |
| 6 | Pour progress | **Contextual** | World-space, above the plant, during the lock |
| 7 | Pour refusal | **Contextual** | Must be *legible*, not merely absent (§5) |
| 8 | Plant capacity | **Contextual** | Carried **inside** the #5 prompt, not a standalone element |
| 9 | Pickup refusal | **Hidden — diegetic** | The untouched bucket staying put is the message |
| 10 | Level progress | **Contextual** | Brief confirmation on pour completion, when the tally advances |
| 11 | `goal_unlocked` | **Hidden — diegetic** | The airlock changes state itself |
| 12 | Gravity direction | **Hidden — diegetic** | Sprite rotates to the gravity basis |

**Totals: 2 Must Show (one element) · 5 Contextual · 4 Hidden-diegetic · 0 On Demand.**

**Conflict check — passes.** There is one permanent element, and it is permanent only
because R7 compels it. Every optional item resolved to Contextual or Hidden. This is
consistent with the minimal stance in HUD Philosophy; no tension to resolve.

**On #8** — plant capacity rides *inside* the approach prompt rather than existing as its
own element. Growth visuals alone are ambiguous: with `buckets_required` ranging 1–4, a
4-bucket plant at 2 received reads identically to a 2-bucket plant at 1. Attaching the
count to the prompt resolves the ambiguity exactly when the player is deciding whether to
pour, and adds no new screen element.

**On #10** — the tally surfaces at the moment it changes rather than being monitored. The
player is told "3 of 5" on completing a pour, then it clears. This covers the blind spot
a purely diegetic reading has: buckets in rooms the player has not reached are
uncountable.

### Death sequence — a new requirement with no GDD home

Death is presented as **a brief hold on the frame of death — visual and audio effects,
game systems paused — followed by the existing restart.**

This is **not specified in any GDD.** `suit-oxygen.md` R3 and §6 require only that oxygen
death route through `main.gd`'s `restart_level` and be indistinguishable from spike and
kill-area death. This spec adds presentation on top of that path.

Two constraints it inherits:

1. **The sequence must be cause-agnostic.** R3 requires oxygen death be indistinguishable
   from spike or kill-area death "in both handling and presentation." One shared sequence
   satisfies this; anything that names or hints at the cause violates it.
2. **It must not be reachable while the level is completing.** ADR-0005's `level_complete`
   guard exists because `suit-oxygen.md` §5 gives airlock entry priority over zero oxygen
   on the same frame. A death hold triggered before that guard resolves would present a
   death the player did not suffer.

This needs a GDD owner, exactly as `level_complete` does (`systems-index.md` §"New
requirement with no GDD home"). Logged in Open Questions.

---

## Layout Zones

### Viewport and camera basis

No base viewport size is set in `project.godot [display]`, so the Godot default applies.
Stretch mode `canvas_items`, aspect `expand` — the visible area grows in whichever
dimension has spare aspect and **content is never cropped**, so anchored elements cannot
be pushed off screen. No title-safe margin is strictly required; margins here are for
comfort, not safety.

**Two camera modes exist across the 8 shipped levels. Both must be supported.**

| Mode | Levels | Behaviour |
|---|---|---|
| Follow + rotate | `level_01`, `level_07` | `camera_moving = true`. The camera tracks the player and tweens `rotation` to the gravity basis over **0.6 s** (`TRANS_SINE`, `EASE_IN_OUT`) — `main.gd:36–41` |
| Static | `level_02`–`06`, `08` | Both camera flags default `false`. The camera neither follows nor rotates; the player moves within a fixed frame |

Consequence: **"up" is not a single direction.** In follow+rotate levels the camera basis
turns with gravity, so screen-up equals gravity-up and the player does not appear to
rotate. In static levels screen-up is fixed world-up and the player sprite visibly
rotates.

Therefore **every element in this spec is specified in viewport space.** Position may
*track* a world object; rotation is always zero relative to the viewport.

### The four zones

**Z1 — Player-tracked readout** *(Must Show)*

Oxygen gauge. Position: the player's projected viewport position, offset a fixed distance
toward viewport-up. Rotation: always zero relative to the viewport.

- Never rotates with gravity or with the camera — satisfies R7 identically in both camera
  modes. This is the resolution of the R7 conflict flagged in HUD Philosophy.
- The offset is in **viewport pixels**, so it does not scale with camera zoom.
- Requires an outline or backing plate; it renders over arbitrary terrain. `debugger.gd`
  sets the precedent (black `font_outline_color`, `outline_size` 4).
- **In static-camera levels the gauge roams the screen with the player.** An accepted
  consequence of the player-attached placement — it is always adjacent to what the player
  is already watching, but it is not a fixed learned location in 6 of the 8 levels.

**Z2 — World-tracked prompts** *(Contextual)*

Interact prompt with embedded plant capacity, pour progress, and pour refusal. Position:
tracks the owning object (plant, bucket, airlock), offset toward viewport-up. Rotation:
zero relative to the viewport.

- Prompts belong to the object, not the player. Several may exist in a level; only those
  within proximity render.

**Z3 — Transient** *(Contextual)*

Pour-completion tally and the death sequence.

- Tally: brief, adjacent to the plant just poured.
- Death sequence: full-viewport, and the only element permitted to cover Z1 and Z2.

**Z4 — Debug overlay** *(dev-only)*

Screen-anchored, top-left, matching the existing `debugger.tscn`. Requires a **new input
action** — none exists in the input map (`move_left`, `move_right`, `jump`, `interact`,
`crouch` only).

### Layering, bottom → top

1. **Z4** debug overlay
2. **Z2** world-tracked prompts
3. **Z1** player-tracked readout
4. **Z3** transient / death sequence

Z1 sits above Z2 because R7 outranks a contextual prompt. Z3 covers everything because
the level is ending. **Z4 is bottom-most** — since Z1 roams the screen, a fixed corner
cannot guarantee separation by position, so the debug overlay is separated by *layer*
instead. This is how the philosophy's "must not obscure player-facing elements" is
actually enforced.

### Z1 / Z2 collision rule

When the player stands in a plant's interact area, Z1 and Z2 are adjacent by construction
and may overlap. **Z1 never yields** — R7 makes the oxygen readout non-negotiable. Z2
displaces along the viewport-horizontal axis, away from the player.

---

## HUD Elements

Seven elements. E1 is the only permanent one; E3 lives inside E2; E7 is dev-only.

### E1 — Oxygen gauge

| Field | Value |
|---|---|
| Zone / category | Z1 · **Must Show** |
| Content | `oxygen_fraction` as bar length; `oxygen_remaining` in seconds as numerals **only when `oxygen_fraction <= 0.50`** |
| Form | Horizontal bar, viewport-upright, offset above the player's projected position |
| Update | Real-time, per frame, from `OxygenState` |
| Trigger | Always — R7 |
| Data | `OxygenState.remaining` / `.capacity`; thresholds from `OxygenTuning` |

A per-frame read satisfies **AC9** ("HUD readout matches `oxygen_remaining` within 0.1 s")
trivially. The numerals appearing at the caution threshold means the §4 threshold set
governs the element's *content*, not only its colour — the gauge tells the player less
when there is slack and more when there is not.

**Error state — `oxygen_capacity <= 0`.** `suit-oxygen.md` §5 and **AC7** define this as a
mis-authored level, and AC7 requires an error be logged at load. `oxygen_fraction` is
undefined here (division by zero or a negative capacity), so E1 must not attempt a bar.

E1 renders a **distinct error appearance** — not an empty bar, and not nothing:

- An empty bar would make a mis-authored level look identical to a player about to die,
  which misleads in precisely the wrong direction.
- Hiding E1 would violate R7's always-visible rule and reads as the HUD failing rather
  than the level being wrong.

Making the fault visible on screen, not only in the log, means a mis-authored level
cannot ship unnoticed.

### E2 — Interact prompt

| Field | Value |
|---|---|
| Zone / category | Z2 · **Contextual** |
| Content | `interact` key glyph (**E**), action label, and plant capacity `buckets_received` / `buckets_required` |
| Form | World-tracked panel above the plant, viewport-upright |
| Trigger | Player inside the plant's `InteractArea2D` **and** carrying a bucket **and** the plant has remaining capacity |
| Update | Event-driven on area enter/exit and on capacity change |
| Animation | Rise + fade in on appear; fade out on departure |

**Only one prompt may be visible at a time.** `watering-system.md` §5 and **AC12** specify
that with overlapping interact areas the pour targets *the nearest plant with remaining
capacity*. Prompting on both plants would misrepresent which one receives the pour — so
the prompt appears on the resolved target only, and must move if the target changes while
the player is standing still.

### E3 — Pour progress *(inside E2)*

| Field | Value |
|---|---|
| Zone / category | Z2 · **Contextual** — not a separate element |
| Content | `water_progress` / `water_duration` as a fill of the E2 panel |
| Trigger | E2 visible **and** `interact` held |
| Update | Real-time |
| Animation | Fill advances with progress. **On early release the fill drains back to zero.** On completion the fill completes, E2 dismisses, E5 fires |

The drain-back is the visible proof of **R4 / AC3** — no partial credit. A fill that froze
or persisted would imply progress had been banked, which is exactly what the rule forbids.

### E4 — Pour refusal

| Field | Value |
|---|---|
| Zone / category | Z2 · **Contextual** |
| Content | A capped / complete state marker on the plant |
| Trigger | Player inside the interact area of a plant at `buckets_received == buckets_required` |
| Animation | Static. No pulse, no shake |

**This is not the absence of E2.** `watering-system.md` §5 requires the refusal be
"legible rather than silent" — suppressing the prompt alone leaves the player unable to
distinguish a capped plant from one they are simply not close enough to. It is
deliberately static because a full plant is a success, not an error.

### E5 — Pour tally confirmation

| Field | Value |
|---|---|
| Zone / category | Z3 · **Contextual** |
| Content | `buckets_consumed` / `buckets_total` |
| Trigger | Fires when `LevelState.buckets_consumed` advances — i.e. on pour completion |
| Duration | Brief, then clears |

**E5 does not announce the airlock unlock.** On the final pour it reads `5 / 5` and
nothing more; the airlock changing state is the message, per the Hidden-diegetic
categorization of `goal_unlocked` (#11). An "airlock open" line here would relocate a
working diegetic channel into UI for no gain.

### E6 — Death sequence

| Field | Value |
|---|---|
| Zone / category | Z3 · **Contextual** |
| Content | Visual and audio effects. **No text, no cause named** |
| Trigger | Any death — oxygen depletion, spike, kill area |
| Duration | **~0.35 s** hold with game systems paused, then `main.gd` `restart_level` |
| Constraints | Cause-agnostic (R3); must not fire before ADR-0005's `level_complete` guard resolves |

- The 0.35 s is a **feel value and a playtest target**, not a derived one. It is short
  because the game's loop is repeated attempts.
- **This element will appear broken in `level_05` and `level_06` until BUG-0001 is
  fixed.** Those levels' kill planes never fire (mask defaults to `world`(1), player is on
  layer 2, `1 & 2 == 0`), so no death sequence can play there. Anyone testing E6 against a
  kill plane in those two levels will see nothing and conclude E6 is at fault.

### E7 — Developer diagnostic overlay

| Field | Value |
|---|---|
| Zone / category | Z4 · **dev-only**, not player-facing |
| Toggle | **F3** — requires a new input action; default off |
| Build | **Stripped from release exports** |
| Update | Per frame while visible |
| Supersedes | `src/scripts/debugger.gd` (always-on, movement-only, reads `Player` fields directly) |

Content, grouped:

| Group | Values |
|---|---|
| Gravity | Gravity vector and direction label, multiplier, `up_dir` / `right_dir`, active `GravityZone`, **`camera_moving` and `camera_rotation_enabled`** |
| Player | Velocity, `is_on_floor`, `is_on_wall`, coyote and jump-buffer timers, wall-jump state |
| Watering | `carrying_bucket`, resolved target plant, `water_progress` / `water_duration`, per-plant `buckets_received` / `buckets_required` |
| Oxygen | `remaining`, `capacity`, `fraction`, active threshold band, `drain_rate` |
| Level flow | Level id, `goal_unlocked`, `buckets_consumed` / `buckets_total`, `level_complete`, `_transition_pending` |
| Validation | R8 bucket-sum result, `oxygen_capacity > 0`, presence of `default_gravity_direction` / `_multiplier` |
| Collision | Player layer/mask, and **every `Area2D` whose mask ANDed with the player's layer is zero — highlighted as a warning** |

Two of these earn their place specifically:

- **The collision group is a computed check, not a dump.** Printing raw layer/mask numbers
  would still require a developer to notice `1 & 2 == 0` by eye. Computing the
  intersection and flagging the empty ones is what actually surfaces BUG-0001 and every
  defect shaped like it.
- **The two camera flags are shown together** because nothing in the code couples them,
  and a level setting one without the other inverts the player's controls against a view
  that never turned.

---

## Dynamic Behaviors

### Oxygen escalation

Escalation is by **colour and content. Nothing moves.** `suit-oxygen.md` §2 asks for
"budgeted urgency rather than panic"; a readout that becomes more *informative* as it
worsens serves that, while one that becomes more *agitated* works against it.

| Band | `oxygen_fraction` | Bar | Numerals |
|---|---|---|---|
| Nominal | > 0.50 | Base colour | Hidden |
| Caution | ≤ 0.50 | Caution colour | **Appear** — integer seconds |
| Warning | ≤ 0.25 | Warning colour | Shown |
| Critical | ≤ 0.10 | Critical colour | Shown |

**Threshold tick marks.** The bar carries static tick marks at the 0.50, 0.25 and 0.10
positions. Without them the table above has an accessibility failure: numerals appearing
at caution is a non-colour signal, but the warning and critical transitions would be
**conveyed by colour alone**. Ticks make every crossing readable as *position*, and they
let the player see the next threshold approaching rather than only being told they have
arrived — which is closer to what §2 asks for than the bands alone are.

**AC10** ("threshold feedback fires at 50%, 25% and 10%") is satisfied by the colour
change plus the tick crossing. It does not require motion.

### Why the bar is permanent, not threshold-triggered

`suit-oxygen.md` §2 wants the player to "know roughly thirty seconds out that they are not
going to make it." In the §4 worked example (48 s capacity) caution fires at 24 s
remaining — thirty seconds out is still **nominal**. For any capacity below roughly 60 s
the first threshold lands *after* the thirty-second mark.

The thresholds therefore cannot be the mechanism for that awareness. **The permanent bar
is.** The bands are escalation layered on an already-visible readout, not its trigger.
This is the load-bearing argument for E1 being Must Show, beyond R7's bare wording.

### Contextual element lifecycle

| Element | Appears | Dismisses |
|---|---|---|
| E2 prompt | Player enters the resolved target plant's interact area while carrying, plant has capacity | On exit, on capacity fill, or when the resolved target changes |
| E3 fill | `interact` pressed while E2 shown | Released (drains to zero) or completed |
| E4 refusal | Player enters the area of a capped plant | On exit |
| E5 tally | `buckets_consumed` advances | After its brief duration |
| E6 death | Any death, after the `level_complete` guard clears | After ~0.35 s, into restart |

### Objects that deliberately get no prompt

Recorded so the absence reads as a decision rather than an oversight.

| Object | Why | Considered |
|---|---|---|
| Bucket / jug | `watering-system.md` **R1** — pickup is on body contact with **no input required**, matching `bucket.gd:4–7`. There is no action to prompt | A no-key affordance indicator on approach was proposed and **declined**. A key prompt was also rejected: it would contradict R1 and change live behaviour |
| Airlock | `goal_unlocked` is Hidden-diegetic (#11) — the door's own state is the message, and it is a large obvious object | Both an unlocked indicator and a locked/unlocked pair were proposed and **declined** |

### Density profile

| Gameplay state | Player-facing elements |
|---|---|
| Traversing, empty-handed | E1 |
| Carrying, in transit | E1 |
| At a plant with capacity, carrying | E1 + E2 |
| Pouring | E1 + E2/E3 |
| At a capped plant | E1 + E4 |
| Pour just completed | E1 + E5 |
| Dying | E6 (covers everything) |

**Never more than two player-facing elements at once.** This is the minimal claim from
HUD Philosophy expressed as a number the spec can be tested against. If a future element
breaks it, what changed is the philosophy — not just the count.

### Debug overlay paging

**F3 cycles**: Off → Gravity → Player → Watering → Oxygen → Level flow → Validation →
Collision → Off. One binding, one group on screen at a time.

The order runs from most frequently needed (gravity and kinematics, tuned daily) to
rarest (validation and collision, consulted when something is structurally wrong), so a
developer paging in from Off reaches the common cases first.

---

## Platform & Input Variants

**Target: PC only.** Keyboard/mouse, no gamepad, no touch
(`.claude/docs/technical-preferences.md`). There are no per-platform layout variants to
design.

The variants that do exist are internal:

| Variant | Difference |
|---|---|
| **Follow + rotate camera** (`level_01`, `level_07`) | The camera basis turns with gravity. E1 and E2 hold viewport-upright, so they are unaffected — but the world visibly rotates beneath them |
| **Static camera** (`level_02`–`06`, `08`) | The camera is fixed. E1 roams the screen with the player rather than sitting in a learned position |
| **Aspect ratio** | `stretch/aspect="expand"` — the visible area grows in the spare dimension and is never cropped. Z4 anchors safely at any ratio; Z1/Z2/Z3 track objects and are unaffected |
| **Release build** | **E7 is absent.** Stripped at export, along with its F3 binding |

**Input additions required**: one new action, for the F3 debug toggle. No player-facing
element consumes input — the HUD is entirely readouts and prompts.

---

## Accessibility

**No accessibility tier is defined for this project** —
`design/accessibility-requirements.md` does not exist. This spec is written against a
WCAG-AA-informed baseline as a working assumption. Logged in Open Questions.

**Keyboard navigation: not applicable.** No player-facing HUD element is interactive —
there are no buttons, no focus order, nothing to tab through. The prompts describe world
interactions performed by the existing movement and `interact` bindings. The only HUD
input is F3, which is dev-only.

**Text scale.** `default_texture_filter=0` (nearest) means non-integer scaling shimmers.
Any text-size option must scale at integer factors.

**Colour independence.** Carried by Dynamic Behaviors — numerals appear at caution and
tick marks make every threshold crossing readable as position. No band depends on colour
to be read.

### Palette

**All colour in the game comes from the NES palette** at
`docs/Pallete/nes-aesprite-1x.png` — 56 entries:

```
#000000 #010101 #797979 #A2A2A2  #305182 #4192C3 #61D3E3 #A2FFF3
#306141 #49A269 #71E392 #A2FFCB  #386D00 #49AA10 #71F341 #A2F3A2
#396E01 #51A200 #9AEB00 #CBF382  #495900 #8A8A00 #EBD320 #FFF392
#794100 #C37100 #FFA200 #FFDBA2  #A23000 #E35100 #FF7930 #FFCBBA
#B21030 #DB4161 #FF61B2 #FFBAEB  #9A2079 #DB41C3 #F361FF #E3B2FF
#6110A2 #9241F3 #A271FF #C3B2FF  #2800BA #4141FF #5182FF #A2BAFF
#2000B2 #4161FB #61A2FF #92D3FF  #B2B2B2 #EBEBEB #FEFEFE #FFFFFF
```

> This is a **project-wide art constraint, not a HUD one.** Its proper home is
> `design/art/art-bible.md`, which does not exist. It is recorded here because the HUD
> needs it; the misplacement is logged in Open Questions.
>
> **Existing art may not comply.** `src/assets/Simple-Platformer-Asset-Pack/` ships its
> own `5 GUI/Palette.png`. Whether that pack is NES-palette has not been checked. If it
> is not, this constraint means either re-paletting existing art or scoping the rule to
> new work only — an unresolved decision, not an assumption this spec should make.

### E1 band colours and contrast

| Band | Colour | Contrast vs `#000000` |
|---|---|---|
| Nominal | `#61D3E3` cyan | ~12:1 ✅ |
| Caution | `#EBD320` yellow | ~14:1 ✅ |
| Warning | `#FFA200` orange | ~10:1 ✅ |
| Critical | `#E35100` red-orange | ~5.9:1 ✅ |

Text `#FFFFFF`; outline and backing `#000000`, matching `debugger.gd`'s existing black
outline at size 4.

**The outline must be black, not white.** Against `#FFFFFF` the critical colour falls to
roughly 3.5:1 and fails AA. Against black all four bands clear 4.5:1 comfortably.

E1, E2, E3 and E4 all render over arbitrary terrain rather than a controlled background,
so each requires that outline or backing plate. Text targets 4.5:1 against the
worst-case background it can appear over, not the average one.

Warning and critical sit adjacent in hue, which is weak for protanopia and deuteranopia.
Acceptable here only because colour independence is already carried by the tick marks and
numerals.

### Finding 1 — reduced motion cannot currently be offered

The largest motion in the game is not in the HUD: it is the **camera rotating through
0.6 s on every gravity flip** in `level_01` and `level_07` (`main.gd:36–41`). Rotating an
entire viewport is a known vestibular trigger, and it is the one thing a motion-sensitive
player would need to disable.

**It cannot currently be disabled.** `camera_moving` gates rotation *and* camera-follow
together, so turning off rotation also turns off follow. And `camera_rotation_enabled` —
which drives the player's input-axis inversion — is a separate, uncoupled flag; disabling
rotation without it would leave the player's controls inverted against a view that never
turned.

A reduced-motion option therefore requires **decoupling three concerns first**: camera
follow, camera rotation, and input-basis inversion. That is an architecture change, not a
UX one.

### Finding 2 — E1 displays real time, not raw `oxygen_remaining`

`suit-oxygen.md` §7 designates `drain_rate` (range 0.5–1.0) an **accessibility hook
only**, and §4 notes that at exactly 1.0 `oxygen_capacity` "reads directly as wall-clock
seconds."

Below 1.0 that stops holding. `oxygen_remaining` decreases by `drain_rate · delta`, so at
`drain_rate = 0.5` a reading of `24` means **48 real seconds**. A player who enabled an
accessibility setting would get a readout understating their remaining time by half — the
opposite of what the setting exists for.

**E1 therefore displays `oxygen_remaining / drain_rate`.** At the default 1.0 the two are
identical, so this changes nothing today and is correct the moment the hook is used.

This interacts with ADR-0006 **D6.6**, which assigned the `drain_rate` accessibility
override to **ADR-0008**. That ADR needs to know the HUD reads the *composed* value, not
the resource value.

---

## Open Questions

### Missing upstream documents

| # | Gap | Impact |
|---|---|---|
| Q1 | **No accessibility tier.** `design/accessibility-requirements.md` does not exist | This spec assumed WCAG-AA. If the project commits to a different tier, the contrast targets and colour-independence rules need re-checking |
| Q2 | **No player journey map.** `design/player-journey.md` does not exist | Player context on arrival at each HUD state was inferred from the GDDs rather than read. Template at `.claude/docs/templates/player-journey.md` |
| Q3 | **No game concept or pillars.** `systems-index.md:111` confirms neither exists | Nothing on disk arbitrates between the four GDDs. The minimal / adaptive / diegetic stance was chosen without a pillar to check it against |
| Q4 | **No art bible.** The NES palette constraint is recorded in this spec because it has nowhere else to live | A project-wide constraint sitting in a HUD document. Needs relocation to `design/art/art-bible.md` |
| Q5 | **No interaction pattern library.** This spec invents three patterns — world-tracked prompt panel, fill-on-hold, viewport-upright tracked readout | They should be catalogued in `design/ux/interaction-patterns.md` before a second screen reinvents them |

### Requirements with no owner

| # | Question |
|---|---|
| Q6 | **The death sequence has no GDD home.** Specified only here, exactly as `level_complete` is specified only in the architecture document (`systems-index.md` §"New requirement with no GDD home"). It needs an owner in `suit-oxygen.md` or elsewhere |
| Q7 | **HUD behaviour while paused is undefined.** `suit-oxygen.md` §5 requires pausing to halt oxygen drain, but no pause menu exists (only `start_menu.tscn`). Whether E1 dims, holds, or is covered is unanswered |
| Q8 | **AC9 and AC10 are the only HUD acceptance criteria, and both are advisory.** No BLOCKING criterion covers any element in this spec. Whether that is acceptable is a QA decision |

### Conflicts requiring resolution outside this spec

| # | Conflict |
|---|---|
| Q9 | **`watering-system.md` §6 assigns a carry indicator to the HUD; this spec satisfies it diegetically instead.** A genuine departure. Route through `/propagate-design-change` or reverse it — it must not remain a silent divergence |
| Q10 | **`camera_moving` and `camera_rotation_enabled` are uncoupled** (`main.gd:8–9`). Blocks any reduced-motion option (Accessibility Finding 1) and lets a level invert the player's controls against a view that never turned. Architecture, not UX |
| Q11 | **`drain_rate` composition.** E1 displays `oxygen_remaining / drain_rate`. ADR-0006 **D6.6** assigned the accessibility override to **ADR-0008** — that ADR must know the HUD reads the composed value, not the resource value |
| Q12 | **Asset pack palette compliance unverified.** `src/assets/Simple-Platformer-Asset-Pack/` ships its own `5 GUI/Palette.png`. If it is not NES-palette, adopting the constraint means re-paletting existing art or scoping the rule to new work only |
| Q13 | **`suit-oxygen.md` §2 vs §4.** §2 wants thirty-seconds-out awareness; §4's caution threshold fires at 24 s for a 48 s level, i.e. *after* that mark. This spec resolves it by making the bar permanent, but the GDD's own numbers remain in tension |

### Implementation gaps

| # | Question |
|---|---|
| Q14 | **How E7 is stripped at export is unspecified.** A build-configuration decision (feature tags, conditional instancing) that this spec states as a requirement without prescribing a mechanism |
| Q15 | **BUG-0001 blocks E6 verification.** Kill planes never fire in `level_05` and `level_06`, so the death sequence cannot be tested against them until the mask is fixed |
