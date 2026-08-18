# HUD Design

> **Status**: Complete draft — all 10 sections authored and approved.
> **Reviewed**: `/ux-review` 2026-08-15 — verdict **NEEDS REVISION**, 7 blocking findings.
> **All seven are now closed**: Acceptance Criteria · Tuning Knobs
> with placement routed to the Presentation-tier ADR (Q16) · `tally_duration` = 1.2 s ·
> the single Z2 slot and the `E2/E3 → E5 → E4` priority order · the completed Z1/Z2 collision rule ·
> the paused HUD state (Q7) · the carry-indicator divergence (Q9), ratified into
> `watering-system.md` §6 and `systems-index.md:102` on 2026-08-15.
> **Re-reviewed**: `/ux-review` 2026-08-15 — verdict **NEEDS REVISION**, 1 blocking finding
> (Z1 occluding the play area), **now closed** by the Z1 occlusion rule, `z1_max_footprint`,
> and H28/H29. The criteria set is now **H1–H30, 19 BLOCKING**.
>
> **Corrected 2026-08-16**, before this spec gains binding force through ADR-0010.
> Seven edits: the accessibility tier now cites `accessibility-requirements.md` instead
> of denying it exists · the E1 contrast figures are recomputed · every element now
> carries its `interaction-patterns.md` pattern name · item #10 is re-categorised to
> **On Demand** and **E8** is added · E1's pre-injection appearance is defined ·
> **Q17 is closed** (Z2 offsets along eased `up_dir`, as Z1 does) · stale **Q1, Q3 and
> Q5** are moved to *Resolved*.
>
> Still open, and not touched by that pass: the stale carry-indicator entries in
> `architecture.md:108` and `TR-watering-017/018` (both assigned to ADR-0010), no size
> cap on Z2, no character budget for E2's label, no HUD frame-cost criterion, and
> **Q18** — E8's zone and budget arbitration, assigned to ADR-0010.
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-16
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

Neither is waived. #1 is resolved in HUD Elements; #2 was resolved upstream, in the GDD.

**1. `suit-oxygen.md` R7 — the oxygen readout must be *always visible*.** This is the
one value that cannot be proximity-triggered: R7 exists so "the player must never be
surprised by the tank running out." Minimal and diegetic can both still be honoured — a
gauge carried on the suit is diegetic and permanent at once — but **"adaptive" cannot
apply to its visibility.** Adaptive may still govern its *prominence* at the §4
thresholds (0.50 / 0.25 / 0.10). Resolved in HUD Elements.

**2. `watering-system.md` §6 — carry state.** Under a diegetic
stance the bucket is already in the player's hands, and AC14 requires the player read as
"visibly slower and visibly burdened." The world already carries this information, so a
screen-space indicator would be the least diegetic possible answer to it. §6 originally
assigned a carry indicator to the HUD, which made this spec's treatment a departure; that
was resolved in the diegetic treatment's favour on 2026-08-15
(`/propagate-design-change`, Q9), and §6 now states there is no carry indicator.
**No longer a divergence.**

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
| 10 | Level progress | **On Demand** | Held-key readout (E8), plus a brief confirmation when the tally advances (E5) |
| 11 | `goal_unlocked` | **Hidden — diegetic** | The airlock changes state itself |
| 12 | Gravity direction | **Hidden — diegetic** | Sprite rotates to the gravity basis |

**Totals: 2 Must Show (one element) · 4 Contextual · 4 Hidden-diegetic · 1 On Demand.**

**Conflict check — passes.** There is one permanent element, and it is permanent only
because R7 compels it. Every optional item resolved to Contextual, On Demand, or Hidden.
This is consistent with the minimal stance in HUD Philosophy. No tension to resolve.

**On #8** — plant capacity rides *inside* the approach prompt rather than existing as its
own element. Growth visuals alone are ambiguous: with `buckets_required` ranging 1–4, a
4-bucket plant at 2 received reads identically to a 2-bucket plant at 1. Attaching the
count to the prompt resolves the ambiguity exactly when the player is deciding whether to
pour, and adds no new screen element.

**On #10** — the tally has two surfaces, and it needs both.

E5 pushes it at the moment it changes. The player is told "3 of 5" on completing a pour,
then it clears. This covers the blind spot a purely diegetic reading has: buckets in
rooms the player has not reached are uncountable.

E8 lets the player pull it at any time. **Push alone was not enough.**
`design/accessibility-requirements.md` § *Objective clarity* found that E5 is the only
place `buckets_consumed / buckets_total` ever appears, so a player who looks away, or
who returns after a break, cannot ask how many plants remain. The information sits in
`LevelState` and was never queryable. The same document reaches the finding a second way
under § *Cognitive load*: watering asks the player to track four things at once, and the
compensating clarity is that three of them are spatial and read from the level itself.
The tally is the one item with no spatial representation.

**A held key rather than a permanent element**, because a permanent tally would spend
the second slot of a two-element budget forever, which is exactly what the minimal
stance excludes. **E5 keeps its 1.2 s duration** — that value rests on a structural
argument (see E5) and this addition does not reopen it.

### Death sequence — a new requirement with no GDD home

Death is presented as **a brief hold on the frame of death — visual and audio effects,
game systems paused — followed by the existing restart.**

**Owned by `design/gdd/level-flow.md` as of 2026-08-17** (R6, R7 and §7). It was
previously specified only here, in no GDD. `suit-oxygen.md` R3 and §6 require only that oxygen
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

Both this sequence and `level_complete` now have that owner: `design/gdd/level-flow.md`.
See Open Questions § Resolved, Q6.

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
along **eased gravity-up (`up_dir`)**, projected into viewport space. Rotation: always zero
relative to the viewport.

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
tracks the owning object (plant, bucket, airlock), offset along **eased gravity-up
(`up_dir`)**, the same axis Z1 uses. Rotation: zero relative to the viewport.

- Prompts belong to the object, not the player. Several may exist in a level; only those
  within proximity render.

**The single Z2 slot.** At most **one** Z2 element renders at any moment, however many
plants are in range. The slot is awarded in this order:

1. The **resolved pour target** — the nearest plant with remaining capacity whose interact
   area contains the player, with the player carrying a bucket → **E2** (with E3 inside it
   while `interact` is held).
2. Otherwise, the **nearest plant in range at capacity** → **E4**.
3. Otherwise, nothing.

This preserves `watering-system.md` **AC12** exactly — the pour still targets the nearest
plant *with capacity*, and rule 1 puts the prompt on that same plant even when a capped
plant is nearer. Rule 2 fires only when rule 1 found no target, so **E2 and E4 can never
both be on screen.**

Without this rule the two-element visual budget is not achievable: two capped plants in
range would render two E4s, and a capped plant overlapping an uncapped one would render
E1 + E2 + E4. E2 had a cardinality rule from AC12; E4 had none.

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
and may overlap. **Z1 never yields** — R7 makes the oxygen readout non-negotiable.

| Rule | Behaviour |
|---|---|
| Displacement axis | Z2 displaces along the viewport-horizontal axis, away from the player's projected position. Z1 does not move |
| Trigger / release | Displacement applies while Z1's and Z2's bounding boxes intersect, and releases when they separate by `z2_release_hysteresis`. **The hysteresis is required, not cosmetic**: both boxes track moving objects, so without it a player standing at the intersection boundary makes Z2 flicker every frame |
| Z1 against a viewport edge | Z1 clamps inside the viewport by `hud_edge_margin` and stops tracking on that axis until the player moves back. `stretch/aspect="expand"` guarantees content is never cropped, so this clamp guards only against the player themselves reaching the edge |
| Z2 displaced off-viewport | If displacing away from the player would put Z2 past the viewport edge, it displaces **toward** the player instead. Z1 still does not move |
| Z2 onto another Z2 | **Cannot occur** — at most one Z2 element exists at a time (see *The single Z2 slot*) |
| Z3 | Exempt. Z3 layers above both and is permitted to overlap them |

Magnitudes are knobs, not fixed values — see **Tuning Knobs**. The behaviours above are
the part that had to be specified here; the pixel figures are playtest targets.

### Z1 occlusion rule

Z1 is permanent and sits adjacent to the player, so it necessarily covers world. R7 forbids
the usual remedy — hiding it — so occlusion is bounded by *placement* and *size* instead.

**Placement: the offset follows gravity-up, not viewport-up.** The player's sustained travel
direction is gravity-down; falling is how hazards are reached and how the player dies.
Offsetting along `up_dir` puts the gauge opposite the fall path in every gravity basis.

| Camera mode | Effect |
|---|---|
| Follow + rotate (`level_01`, `level_07`) | **No change.** The camera basis already equals the gravity basis, so viewport-up and gravity-up coincide. H1 is unaffected |
| Static (`level_02`–`06`, `08`) | Under inverted or rotated gravity the gauge moves to the opposite side of the player — off the direction the player is falling |

`up_dir` is already eased at `direction_ease_rate` (`gravity.md` R3), so the gauge arcs around
the player in step with the sprite and the control basis. No new duration, no new knob, and no
flicker: `lerp_angle` easing is continuous and gravity changes are discrete zone events, not
per-frame noise. On a 180° flip the gauge sweeps through the horizontal, passing briefly
beside the player — matching the sprite's own sweep.

**Size: the footprint is capped.** Z1's rendered extent — bar, outline, and numerals at their
largest, i.e. any band at or below caution — must not exceed `z1_max_footprint`.

**Opacity is deliberately not used.** Fading the backing plate over busy terrain was
considered and **declined**: the plate is what H22's contrast figures rest on, so reducing it
trades a legibility problem for a legibility problem.

**This rule covers Z2 as well.** *(Extended 2026-08-16 — closes Q17.)* Z2 offsets from its
owning object along the same eased `up_dir`, so a plant mounted on a ceiling under inverted
gravity renders its prompt away from the geometry rather than into it.

One offset rule now governs both zones. It reuses the `up_dir` the HUD already reads for Z1,
adds no knob, and adds no per-object authored field.

**The trade this accepts.** Z2's anchor arguably belongs to the object's *mounting surface*
rather than to gravity, and Z1's fall-path reasoning genuinely does not settle that — the
reasoning above is about where the player falls, which says nothing about an object bolted to
a wall. A per-object authored anchor direction would be more precise. It was **declined**
because it puts a new authored field on every plant, bucket, and airlock, and **no level
instances a plant today** (`plant.tscn` exists and is used in none of the 8 level scenes,
verified 2026-08-16). A single rule is worth more than a more precise one while there is no
authored content to be precise about.

**What would reopen this:** a level that mounts a prompt-owning object against gravity and
reads badly under it. At that point the per-object anchor is the answer, and it is additive —
an authored direction that defaults to `up_dir` changes no existing behaviour.

`interaction-patterns.md` **O1** states the identical question for P2 and is owed this same
closure. That is a separate file and a separate edit.

---

## HUD Elements

Eight elements. E1 is the only permanent one. E3 lives inside E2. E7 is dev-only, and
E8 shows only while its key is held.

### Pattern mapping

Every element implements a catalogued pattern from `design/ux/interaction-patterns.md`.
That library postdates this spec, so the names are recorded here rather than being
invented twice. **Use the pattern name in code and in review comments.**

| Element | Pattern | Category |
|---|---|---|
| E1 oxygen gauge | **P1** — Viewport-Upright Tracked Readout | Data Display |
| E2 interact prompt · E4 pour refusal | **P2** — World-Tracked Prompt Panel | Overlay / Feedback |
| E3 pour progress | **P3** — Fill-on-Hold | Input / Feedback |
| E5 tally confirmation | **P4** — Transient Confirmation | Feedback |
| The single Z2 slot | **P5** — Single-Slot Priority Arbitration | Layout / Arbitration |
| E8 on-demand tally | **P6** — On-Demand Readout | Data Display |
| E7 diagnostic overlay | **P7** — Paged Diagnostic Overlay | Developer tooling |
| E6 death sequence | *No pattern.* Full-viewport and used once | — |
| E9 level-complete sequence | *No pattern.* Full-viewport and used once | — |

P1, P2 and P3 are the three this spec's Q5 named as uncatalogued. P4 and P5 were in use
and unnamed. P6 is new and is what E8 implements.

### E1 — Oxygen gauge

| Field | Value |
|---|---|
| Zone / category | Z1 · **Must Show** |
| Content | `oxygen_fraction` as bar length; `oxygen_remaining` in seconds as numerals **only when `oxygen_fraction <= 0.50`** |
| Form | Horizontal bar, viewport-upright, offset **along gravity-up** from the player's projected position |
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

**Pre-injection state — before `bind()` runs.** The HUD receives `OxygenState` and
`LevelState` by injection from `LevelRoot._ready()`. `_ready()` runs bottom-up, so the
HUD is ready *before* the state it reads exists, and there is a window in which E1 has
no data source at all. This is a distinct condition from `oxygen_capacity <= 0`: there
the level is mis-authored, here the level is merely still loading.

**E1 renders the same error appearance in both cases, and the HUD pushes an error if it
is ever asked to draw while unbound.** One appearance rather than two, because the
player-facing meaning is identical — the readout cannot be trusted — and a second error
visual would have to be distinguishable from the first for no player benefit. The two
cases are told apart in the log, not on screen.

The refusal itself is not this spec's to design: every injected consumer must refuse to
operate before `bind()` and must `push_error()`, which is an architectural contract.
This section states only what the player sees. **The mechanism belongs to ADR-0010.**

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
| Trigger | Player inside the interact area of a plant at `buckets_received == buckets_required`, **and** the single Z2 slot resolves to that plant — i.e. no pour target is in range |
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
| Duration | **1.2 s**, then clears |

**1.2 s, and the ceiling is structural rather than a matter of feel.** `water_duration`
has a **2.0 s floor** (`watering-system.md` §7, range 2.0–8.0 s) and every pour is
separated by at least one fetch leg, so two `buckets_consumed` increments cannot fall
closer than roughly 2 s apart. Any duration below ~1.5 s therefore makes an E5 queue
**structurally impossible** — which is why this spec specifies no queue or priority rule
for E5. Raising the value past ~2.0 s would reintroduce the need for one.

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

### E9 — Level-complete sequence

| Field | Value |
|---|---|
| Zone / category | Z3 · **Contextual** |
| Content | Visual and audio effects. **No text.** Does not announce the airlock unlock and does not restate the tally (`level-flow.md` R5) |
| Trigger | `level_complete` latches (`level-flow.md` R2) |
| Duration | `complete_hold_duration` — ⚠ **unset**, 0.6 s proposed — hold with game systems paused, then the level transition |
| Constraints | Must be distinguishable from E6 in a single frame — a player must never read a win as a death. Cannot fire while a death sequence is playing (`level-flow.md` R9) |

- The 0.6 s proposal is a **starting value, not a derived one**, matching the
  gravity-flip camera tween the player is already calibrated to. It needs the same
  playtest E6's 0.35 s needs.
- **This element exists because of a measured failure.** In the vertical slice the only
  observable win state was the oxygen counter silently ceasing to fall, which made a
  working completion and a broken one identical to the player, and masked a real bug
  (`prototypes/gravity-gardener-vertical-slice/REPORT.md` §Observations).
- **No pattern**, for the same reason as E6: full-viewport and used once per level.

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
| Gravity | Gravity vector and direction label, multiplier, `up_dir` / `right_dir`, active `GravityZone`, **`camera_moving` and the live `camera_rotation`** |
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

### E8 — On-demand tally

| Field | Value |
|---|---|
| Zone / category | **Assigned to ADR-0010** — see *What this spec does not decide* below · **On Demand** |
| Pattern | **P6** — On-Demand Readout |
| Content | `buckets_consumed` / `buckets_total`. Identical to E5's content |
| Form | Text readout with the same outline treatment as E1–E4 |
| Trigger | A new progress-query input action, **held**. Appears on press, clears on release |
| Duration | As long as the key is held. **No timer, no minimum, no maximum** |
| Update | Live while held, in case a pour completes during the hold |
| Data | `LevelState.buckets_consumed` / `.buckets_total` |

**Held rather than toggled.** A toggle can be left on, which turns an on-demand element
into a permanent one and defeats the reason it is on demand. Holding also needs no
dismissal rule and cannot be left in a wrong state across a restart.

**Content identical to E5, deliberately.** The player is asking the same question E5
answers unprompted. Two different presentations of one fact would be two things to
learn.

**E8 does not announce the airlock unlock**, for the same reason E5 does not. On a
complete level it reads `N / N` and nothing more.

**Input.** This is the **second** new input action this spec requires, after F3. Neither
is bound today. `interaction-patterns.md` O3 tracks a possible third, owed to ADR-0009's
pour-toggle alternative, which this spec does not own.

#### What this spec does not decide

Three questions about E8 are architecture rather than UX, and
`design/accessibility-requirements.md` § *Objective clarity* assigns all three to
**ADR-0010** by name:

1. **Which zone E8 occupies.** It tracks neither the player nor a world object, so none
   of Z1, Z2, or Z3 obviously fits. `interaction-patterns.md` O5 records P6 as committed
   but unplaced.
2. **How E8 arbitrates against the single Z2 slot.** E1 is permanent and E8 is
   player-invoked, so the pair is two elements and inside the budget. E1 + E2 + E8 is
   three, and reachable — the player can hold the query key while standing at a plant.
3. **Whether E8 suppresses a Z2 element, yields to one, or is refused while one is
   showing.** This spec states the constraint the answer must satisfy and no more: the
   two-element budget in *Density profile* is not waived for E8.

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
| E4 refusal | The Z2 slot resolves to a capped plant in range **and** E5 is not showing | On exit, or when E5 fires |
| E5 tally | `buckets_consumed` advances | After 1.2 s, or immediately when a pour target resolves |
| E6 death | Any death, after the `level_complete` guard clears | After ~0.35 s, into restart |
| E9 complete | `level_complete` latches (`level-flow.md` R2) | After `complete_hold_duration`, into the level transition |
| E8 tally *(On Demand)* | The progress-query key is pressed | The key is released. No timer |

### Paused state

`suit-oxygen.md` §5 requires pausing to halt oxygen drain. **No pause menu exists yet** —
`start_menu.tscn` is the only menu scene — so this specifies HUD behaviour for whenever
one lands. It does not design the menu.

**The HUD freezes. Nothing hides, nothing dims.**

| Element | While paused |
|---|---|
| E1 | Fully visible, holding its last value. Drain is halted, so the value is not stale — it is **correct**. R7 is honoured literally |
| E2 / E4 | Hold as-is |
| E3 | **Freezes at its current fill.** See below |
| E5 | Its 1.2 s timer holds and resumes |
| E6 | **Runs. `PROCESS_MODE_ALWAYS`** (ADR-0014 D14.3). *Corrected 2026-08-18 — this row read "Unreachable — the death sequence already pauses game systems itself," which was circular:* that pause **is** `SceneTree.paused` (D14.1), so E6 was not excluded from the paused state, it was caught by it. Left `PAUSABLE`, E6 would freeze at its first frame and the player would see a still image for the whole 0.35 s hold |
| E9 | **Runs. `PROCESS_MODE_ALWAYS`** (ADR-0014 D14.3). Same correction, same reason. E9 exists because the vertical slice had no observable win state; freezing it at frame one would have reproduced that failure in a new form |
| E7 | Continues updating. It is a developer tool, and a frozen readout is less useful than a live one |

**On E3 specifically.** Pause is not an input release, so the R4 / AC3 drain-back does
**not** fire on pausing — draining there would read as the game confiscating progress the
player never released. R4 forbids *partial credit*, not *suspension*. On unpause: if
`interact` is still held the pour resumes from the same fill; if it is not, the drain-back
fires at that moment, exactly as an ordinary release would.

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
| Re-pour begun while the tally is up | E1 + E2/E3 — E5 dismissed |
| Querying progress, in transit | E1 + E8 |
| Querying progress at a plant | **Undecided — ADR-0010.** E1 + E2 + E8 would be three |
| Dying | E6 (covers everything) |

**Never more than two player-facing elements at once.** This is the minimal claim from
HUD Philosophy expressed as a number the spec can be tested against. If a future element
breaks it, what changed is the philosophy — not just the count.

**What makes this structurally true rather than aspirational is the single Z2 slot plus
a priority order.** E1 is permanent and Z2 holds at most one, which caps the common cases
at two. Z3 is what would break it:

> **Z3's tally never coexists with a Z2 element. Priority, highest first: E2/E3 → E5 → E4.**

**E5 suppresses E4** for its duration. Without that the budget fails on the most ordinary
event in the game: completing a pour on a `buckets_required = 1` plant dismisses E2, fires
E5, and leaves the plant capped with the player still standing in its interact area — so
rule 2 of the single Z2 slot awards E4, and E1 + E4 + E5 renders three elements at once.

Suppression is the right resolution rather than a reordering because **E5 already carries
E4's message.** "3 / 5 buckets delivered" is only true because the plant in front of the
player just filled; showing a capped marker beside it restates that. E4 exists for the
player who *arrives* at a plant already full, which is a different moment. When E5 clears
after 1.2 s, Z2 resolves normally and E4 appears if the player is still in range.

**A resolved pour target dismisses E5 immediately.** That argument does not run the other
way: a tally says nothing about pour progress, so E5 must never suppress E2 — and because
**E3 lives inside E2**, suppressing it would hide the fill of an *active pour*. The case is
reachable: on a plant with `buckets_required` ≥ 2, a player who fetches a nearby bucket and
resumes within `tally_duration` is pouring while the tally is still up. E5 yields instead,
because by then the player has moved on and the tally has been read or missed. The next
pour re-fires it at least `water_duration` later.

E6 is the deliberate exception to everything: it covers the screen because the level is
ending.

**E8 is the one open hole in this budget.** Every case above is settled by the single Z2
slot plus the priority order, because every element is either permanent or triggered by
the world. E8 is triggered by the player, who can invoke it in any state including one
that already renders two elements. The budget is **not waived** for it — the resolution
is assigned to ADR-0010 (see E8 § *What this spec does not decide*), and until that
lands the claim above holds for every state except a query made at a plant.

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

**Input additions required**: **two** new actions — the F3 debug toggle (E7, dev-only)
and the progress-query key (E8, player-facing). Neither is bound today. The input map
holds `move_left`, `move_right`, `jump`, `interact` and `crouch` only.

E8 is the one player-facing element that consumes input, and it consumes it as a
momentary hold rather than as a control to navigate. Everything else in the HUD is a
readout or a prompt. `interaction-patterns.md` O3 tracks a possible third action, owed
to ADR-0009's pour-toggle alternative, which this spec does not own.

---

## Accessibility

**The accessibility tier is Standard, with reduced motion and one-hand mode elevated
above it.** `design/accessibility-requirements.md` (2026-08-15) defines the tier and its
commitments. This spec's WCAG-AA-informed contrast targets match that document's
Standard baseline, so no target in this section changes. Where the two documents state a
figure for the same thing, `accessibility-requirements.md` is authoritative.

**Keyboard navigation: not applicable.** No player-facing HUD element is interactive —
there are no buttons, no focus order, nothing to tab through. The prompts describe world
interactions performed by the existing movement and `interact` bindings. The two HUD
inputs are both momentary readout toggles, not navigable controls: F3 pages E7, and the
progress-query key holds E8 open.

> This stops being true the moment a settings screen exists.
> `interaction-patterns.md` § *Gaps & Patterns Needed* records that no button, focus,
> slider, or key-capture pattern exists anywhere in the project, and that a
> settings-screen UX spec should precede ADR-0010.

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
| Nominal | `#61D3E3` cyan | ~11.8:1 ✅ |
| Caution | `#EBD320` yellow | ~13.7:1 ✅ |
| Warning | `#FFA200` orange | ~10.4:1 ✅ |
| Critical | `#E35100` red-orange | ~5.4:1 ✅ |

> **Figures corrected 2026-08-16.** This table previously read ~12 / ~14 / ~10 / ~5.9:1.
> The recomputed values above come from `design/accessibility-requirements.md`
> § *E1 band contrast*, which is authoritative. Every conclusion drawn from the old
> numbers still holds — all four bands clear AA on black — so only the numbers changed.
> The 2026-08-15 `/ux-review` raised this as advisory finding 4 and it was never applied.

Text `#FFFFFF`; outline and backing `#000000`, matching `debugger.gd`'s existing black
outline at size 4.

**The outline must be black, not white.** Against `#FFFFFF` the critical colour falls to
roughly 3.9:1 and fails AA. Against black all four bands clear 4.5:1 comfortably.

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

**Update 2026-08-18.** One of the three is closed. ADR-0013 D13.4 deletes
`camera_rotation_enabled`, and D13.2 derives the input basis from the camera's live
rotation instead of any flag, so no setting can invert the controls against the view.
ADR-0013 D13.5 specifies the remaining follow/rotate split and deliberately does not
apply it — that changes live camera behaviour in `level_01` and `level_07` and needs a
human playtest first. `accessibility-requirements.md` A7 ("no owning ADR") is closed;
T8 stays blocked until the split lands.

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

## Tuning Knobs

Values this spec introduces that a designer should be able to change without editing code.

> Defaults marked ***playtest target*** are **not derived** from any formula, sprite
> dimension, or GDD figure. They are starting points, labelled so that no later reader
> mistakes them for computed values. The same treatment the 0.35 s death hold already had.

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `death_hold_duration` | 0.35 s *(playtest target)* | 0.2 – 1.0 s | E6. How long the frame of death holds before restart. Past ~1.0 s it fights a loop built on repeated attempts |
| `tally_duration` | **1.2 s** | 0.6 – 1.5 s | E5. **The ceiling is structural, not feel** — above ~1.5 s consecutive tallies can overlap and E5 needs a queue rule it deliberately does not have |
| `z1_offset` | 24 px *(playtest target)* | 12 – 64 px | Z1. Viewport-pixel distance from the player's projected position **along eased gravity-up**. Too small and E1 overlaps the sprite; too large and it leaves the region the player is actually watching |
| `z1_max_footprint` | 96 × 24 px *(playtest target)* | 64×16 – 160×40 px | Z1 occlusion rule. The permanent element's maximum rendered extent. Past ~160 px wide it covers a meaningful share of the frame in every level |
| `z2_offset` | 24 px *(playtest target)* | 12 – 64 px | Z2. The same measurement, taken from the owning object |
| `z2_displacement` | 48 px *(playtest target)* | 24 – 96 px | Z1/Z2 collision rule. Too small and the boxes still intersect after displacing, which defeats the rule |
| `z2_release_hysteresis` | 8 px *(playtest target)* | 4 – 24 px | Z1/Z2 collision rule. Below ~4 px the displacement flickers when the player stands at the intersection boundary |
| `hud_edge_margin` | 16 px *(playtest target)* | 8 – 48 px | Z1's clamp distance from the viewport edge |
| `prompt_fade_duration` | 0.15 s *(playtest target)* | 0.05 – 0.4 s | E2's rise-and-fade in and out. Past ~0.4 s the prompt visibly lags the player's arrival |
| `hud_outline_size` | 4 px | 2 – 8 px | E1–E4 outline width. 4 px is not a playtest target — it matches `debugger.gd`'s existing `outline_size` |

### Placement is not decided here

ADR-0006 **D6.1** fixed the tuning set at exactly three resources — `WateringTuning`,
`OxygenTuning`, `PropTuning` — one per GDD, and **D6.3** made the `Tuning` const holder
the only place a `.tres` path may appear. **There is no HUD resource in that set, and the
HUD is not a GDD.**

Two placements are available, and this spec chooses neither:

- a fourth **`HudTuning`** resource — consistent with D6.3's holder pattern, but it extends
  a set D6.1 sized deliberately, so it needs an ADR-0006 amendment and registry entries; or
- **`@export` on the HUD scene's nodes** — follows the `Plant` precedent
  (`watering-system.md` §7 *Placement*), and since there is exactly one HUD scene,
  per-instance equals global. Needs no ADR change, but is not the data-driven `.tres`
  route `.claude/docs/coding-standards.md` prefers for global values.

**Assigned to the Presentation-tier ADR.** A UX spec states what needs tuning; where the
value lives is an architecture decision, and settling it here would silently amend
ADR-0006 from a UX document. Logged as **Q16**.

### Not owned here

Consumed by the HUD, tuned elsewhere. The HUD **reads** these and must never redeclare
them — a second copy of a threshold is a divergence waiting to happen.

| Value | Owner | Used by |
|---|---|---|
| Threshold bands 0.50 / 0.25 / 0.10 | `OxygenTuning` (`suit-oxygen.md` §4) | E1's band colour, numeral appearance, and tick positions |
| `drain_rate` | `OxygenTuning`; its accessibility composition is **ADR-0008**'s per ADR-0006 **D6.6** | E1 displays the *composed* value — Accessibility Finding 2 |
| `oxygen_capacity` | `suit-oxygen.md` R6, authored per level | E1's bar length, and its error state at `<= 0` |
| `interact_radius` | `Plant`'s `InteractArea2D` (`watering-system.md` §7) | When E2 and E4 appear at all |
| `water_duration` | `Plant`, per instance (`watering-system.md` §7) | E3's fill rate — and its 2.0 s floor is what `tally_duration`'s ceiling rests on |
| `buckets_required` | `Plant`, per instance | E2's embedded capacity readout |
| Band colours | The NES palette constraint (Accessibility § Palette) | Not free values — each must be one of the 56 entries (H23) |

---

## Acceptance Criteria

> Type and gate level follow `.claude/docs/coding-standards.md` § Testing Standards.
> `H*` numbering is local to this document; bare `AC*` references throughout this
> spec belong to `suit-oxygen.md` and `watering-system.md`.

### Layout & visibility

| # | Criterion | Source | Type |
|---|---|---|---|
| H1 | E1 renders at zero rotation relative to the viewport in both camera modes — verified mid-gravity-flip in `level_01` (follow+rotate) and in `level_02` (static) | Z1, R7 | Integration — BLOCKING |
| H2 | E1 remains fully within the viewport at every position the player can reach in all 8 levels, including against the top edge of the visible area | Z1 | Integration — BLOCKING |
| H3 | When E1 and E2 are both visible, no part of either overlaps the other; the displacement does not flicker while the player stands at the intersection boundary; and when the player is against a viewport edge, E1 stays fully inside it and E2 displaces toward the player rather than off screen | Z1/Z2 collision rule | UI — ADVISORY |
| H4 | No more than two player-facing elements render simultaneously — in every state in the Density profile, in the overlapping-interact-area case of `watering-system.md` §5, **on the frame a `buckets_required = 1` plant fills while the player remains in its interact area** (E5 must suppress E4), **and when a pour is resumed on a `buckets_required` ≥ 2 plant while the tally is still showing** (E5 must dismiss, and E3's fill must remain visible throughout) | Visual budget, single Z2 slot, priority order | Integration — BLOCKING |
| H5 | A release export contains no E7: F3 produces no overlay and no input action is registered for it | E7, Platform variants | Integration — BLOCKING |
| H28 | E1's offset from the player follows eased gravity-up: with gravity inverted, E1 renders on the opposite side of the player from where it renders under default gravity, in every static-camera level. During the transition it arcs continuously around the player with no snap, jump, or flicker. In `level_01` and `level_07` the behaviour is visually unchanged from viewport-up offsetting | Z1 occlusion rule | Integration — BLOCKING |
| H29 | E1's rendered extent, including outline and numerals in the critical band, stays within `z1_max_footprint` at every supported aspect ratio | Z1 occlusion rule | UI — ADVISORY |

### Per-context correctness

| # | Criterion | Source | Type |
|---|---|---|---|
| H6 | E2 renders only when all three hold: player inside the resolved target's `InteractArea2D`, carrying a bucket, plant has remaining capacity. Removing any one condition hides it | E2, R3 | Logic — BLOCKING |
| H7 | With two overlapping interact areas both having capacity, exactly one E2 renders, on the nearer plant; it moves to the other plant when the resolved target changes **without the player leaving either area** | E2, AC12 | Integration — BLOCKING |
| H8 | Releasing `interact` mid-pour drains E3's fill to zero, leaves E2 visible, and leaves `buckets_received` unchanged | E3, R4 / AC3 | Integration — BLOCKING |
| H9 | Entering a capped plant's interact area with no pour target in range renders E4 and not E2. With a farther uncapped plant also in range and a bucket carried, E2 renders on that farther plant and **no E4 renders** | E4, single Z2 slot, R5, §5 | Logic — BLOCKING |
| H10 | E5 fires exactly once per `buckets_consumed` increment and clears after **1.2 s** | E5, R6 | Logic — BLOCKING |
| H11 | E5 on the final pour reads `N / N` and contains no airlock or unlock text | E5, #11 | UI — ADVISORY |
| H12 | E6 does not fire when `level_complete` is latched: entering the airlock on the frame oxygen reaches zero completes the level with no death hold | E6, ADR-0005, `suit-oxygen.md` AC8 | Integration — BLOCKING |
| H13 | E6 is identical in presentation across oxygen death and spike death, and names no cause | E6, R3 | Integration — BLOCKING |
| H14 | While paused, E1 stays fully visible holding its last value and no element hides or dims. Pausing mid-pour freezes E3's fill without draining it; on unpause with `interact` still held the pour resumes from that fill with no progress lost, and on unpause with `interact` released the drain-back fires then | Paused state, `suit-oxygen.md` §5, R4 / AC3 | Integration — BLOCKING |

> **H13 coverage is partial.** Kill-area death cannot be included until **BUG-0001** is
> fixed — the kill planes in `level_05` and `level_06` never fire (Q15). H13 must be
> re-run against a kill area once that lands.

### Data correctness

| # | Criterion | Source | Type |
|---|---|---|---|
| H15 | E1's numerals display `oxygen_remaining / drain_rate`: at `drain_rate = 0.5` with `oxygen_remaining = 24`, the readout shows **48**, not 24 | Accessibility Finding 2 | Logic — BLOCKING |
| H16 | E1's numerals are hidden while `oxygen_fraction > 0.50` and shown at and below it | E1, §4 | Logic — BLOCKING |
| H17 | At `oxygen_capacity <= 0`, E1 renders the distinct error appearance — neither an empty bar nor hidden — and the load-time error of `suit-oxygen.md` AC7 is still logged | E1 error state | Logic — BLOCKING |
| H18 | E2's embedded capacity readout matches the target plant's `buckets_received` / `buckets_required` and updates on pour completion without the player leaving the area | E2, #8 | Logic — BLOCKING |
| H19 | No HUD element writes to `OxygenState`, `LevelState`, `Plant`, or `PlayerWateringComponent`. The HUD is read-only | Information Architecture | Logic — BLOCKING |
| H20 | E1 tracks `oxygen_remaining` within 0.1 s at `drain_rate = 1.0` | `suit-oxygen.md` AC9 | UI — ADVISORY |
| H30 | E8 appears while the progress-query key is held and clears on release, with no timer and no minimum display time. Its `buckets_consumed` / `buckets_total` matches E5's for the same `LevelState`, and a pour completing mid-hold updates it live | E8, P6 | UI — ADVISORY |

### Accessibility

| # | Criterion | Source | Type |
|---|---|---|---|
| H21 | In a greyscale capture, all three threshold crossings remain identifiable from tick position and numeral presence alone | Colour independence | Visual — ADVISORY |
| H22 | All four E1 band colours measure ≥ 4.5:1 against `#000000`, and E1–E4 render their black outline or backing plate over the lightest terrain present in all 8 levels | Band colours & contrast | Visual — ADVISORY |
| H23 | Every colour used by any player-facing HUD element is a member of the 56-entry NES palette | Palette | Visual — ADVISORY |
| H24 | Any text-size option scales at integer factors only, with no shimmer under `default_texture_filter=0` | Text scale | UI — ADVISORY |

### Developer overlay

| # | Criterion | Source | Type |
|---|---|---|---|
| H25 | The Collision group flags every `Area2D` whose mask ANDed with the player's layer is zero. With BUG-0001 open, it flags `KillArea2D` in `level_05` and `level_06` | E7 Collision group | Logic — BLOCKING |
| H26 | F3 cycles Off → Gravity → Player → Watering → Oxygen → Level flow → Validation → Collision → Off, one group at a time | Debug overlay paging | UI — ADVISORY |
| H27 | E7 never occludes E1–E6, verified with the player positioned over Z4's screen region | Layering | UI — ADVISORY |
| H30 | E9 and E6 are distinguishable from any single frame of either sequence, so a win never reads as a death | E9 constraints | Visual — ADVISORY |

### Answer to Q8

**Nineteen** of the criteria above are BLOCKING. Q8 asked whether it was acceptable
that AC9 and AC10 — both advisory — were the only HUD acceptance criteria. This
section supersedes that state. **Q8 is closed.**

> The count rose from seventeen to eighteen when **H14** was written against the
> paused-state rules, and to nineteen when **H28** was written against the Z1 occlusion
> rule. **H30 (2026-08-16, E8) is ADVISORY, so the BLOCKING count stays nineteen.**
> No criterion has been removed.

### Criteria still blocked

| # | Blocked on |
|---|---|
| H24 | No text-size option is specified anywhere in the project; this criterion constrains one **if** it is added. It is not blocked on a decision this spec can make |

H3, H10 and H14 were unblocked by the Z1/Z2 collision rule, `tally_duration`, and the
Paused state section respectively.

---

## Open Questions

### Missing upstream documents

> **Three of the five rows here were stale and have moved to *Resolved* below.**
> Q1, Q3 and Q5 each named a document that now exists. Verified against the filesystem
> on 2026-08-16, not inferred. Q2 and Q4 remain correct — those two files are still
> absent.

| # | Gap | Impact |
|---|---|---|
| Q2 | **No player journey map.** `design/player-journey.md` does not exist | Player context on arrival at each HUD state was inferred from the GDDs rather than read. Template at `.claude/docs/templates/player-journey.md` |
| Q4 | **No art bible.** The NES palette constraint is recorded in this spec because it has nowhere else to live | A project-wide constraint sitting in a HUD document. Needs relocation to `design/art/art-bible.md` |

### Requirements with no owner

| # | Question |
|---|---|
| Q16 | **Where the HUD's tuning knobs live is undecided.** ADR-0006 D6.1 fixed the tuning set at three resources, none of them a HUD resource. Either a fourth `HudTuning` (needs an ADR-0006 amendment plus registry entries) or `@export` on the HUD scene nodes. **Assigned to the Presentation-tier ADR** — see Tuning Knobs § *Placement is not decided here* |

### Resolved since the 2026-08-15 review

| # | Question | Resolution |
|---|---|---|
| Q7 | HUD behaviour while paused | **Closed.** Dynamic Behaviors § *Paused state* — the HUD freezes, nothing hides or dims, and E3 suspends rather than draining. H14 is written against it |
| Q8 | Whether advisory-only HUD criteria were acceptable | **Closed.** The Acceptance Criteria section now carries 19 BLOCKING criteria |
| Q9 | `watering-system.md` §6 carry indicator vs. this spec's diegetic treatment | **Closed 2026-08-15 by `/propagate-design-change watering-system.md`.** Ratified, not reversed: §6's HUD row now states there is no carry indicator, and `systems-index.md:102` matches. 0 of the 5 ADRs referencing that GDD were affected — ADR-0002's `HUD ← LevelState` binding survives, because the HUD still reads `carrying_bucket` as an E2 precondition and owns the level tally |
| Q6 | The death sequence has no GDD home | **Closed 2026-08-17.** `design/gdd/level-flow.md` exists and owns the death sequence (R6, R7), `level_complete` (R2), restart (R8), and the new completion sequence E9 presents. This closes the same gap `systems-index.md` recorded as "New requirement with no GDD home." No constraint in this spec changed — the sequence it specified is now sourced rather than orphaned |
| Q1 | No accessibility tier | **Closed 2026-08-16.** `design/accessibility-requirements.md` exists and sets the tier at **Standard**, with reduced motion and one-hand mode elevated above it. This spec's WCAG-AA assumption matches that baseline, so no contrast target or colour-independence rule changed. The Accessibility section now cites the tier instead of denying it |
| Q3 | No game concept or pillars | **Closed 2026-08-16.** `design/gdd/game-concept.md` exists (reverse-documented). Its pillars, hook, audience and scope are user-confirmed; session structure, retention and comparable titles are marked ⚠ TBD. The minimal / adaptive / diegetic stance was chosen before it existed and has **not** been re-checked against it — worth one pass, but nothing here is known to conflict |
| Q5 | No interaction pattern library | **Closed 2026-08-16.** `design/ux/interaction-patterns.md` exists and catalogues **P1–P7**. It named the three patterns this spec invented, plus two that were in use and unnamed (P4, P5) and one new one (P6). Every element now carries its pattern name — see HUD Elements § *Pattern mapping* |
| Q17 | Z2's offset direction under non-default gravity | **Closed 2026-08-16 by decision.** Z2 offsets along eased `up_dir`, the same axis as Z1. One rule for both zones, no new knob, no per-object field. The per-object mounting-surface anchor was considered and declined while no level instances a plant. See Layout Zones § *Z1 occlusion rule*. `interaction-patterns.md` O1 is owed the same closure |

### Conflicts requiring resolution outside this spec

| # | Conflict |
|---|---|
| Q10 | **`camera_moving` and `camera_rotation_enabled` are uncoupled** (`main.gd:8–9`). Blocks any reduced-motion option (Accessibility Finding 1) and lets a level invert the player's controls against a view that never turned. Architecture, not UX. **Narrowed 2026-08-17:** `gravity.md` R11 fixes the input basis as screen-relative unconditionally, which removes the input-inversion leg. **Resolved in part 2026-08-18:** the R11 / ADR-0007 D7.4 conflict is **closed** by ADR-0013 — D13.2 reads the camera's live rotation, D13.4 deletes `camera_rotation_enabled`. What remains of Q10 is the two-way camera-follow / camera-rotation coupling, now owned by ADR-0013 D13.5, specified but not applied pending a playtest |
| Q11 | **`drain_rate` composition.** E1 displays `oxygen_remaining / drain_rate`. ADR-0006 **D6.6** assigned the accessibility override to **ADR-0008** — that ADR must know the HUD reads the composed value, not the resource value |
| Q12 | **Asset pack palette compliance unverified.** `src/assets/Simple-Platformer-Asset-Pack/` ships its own `5 GUI/Palette.png`. If it is not NES-palette, adopting the constraint means re-paletting existing art or scoping the rule to new work only |
| Q13 | **`suit-oxygen.md` §2 vs §4.** §2 wants thirty-seconds-out awareness; §4's caution threshold fires at 24 s for a 48 s level, i.e. *after* that mark. This spec resolves it by making the bar permanent, but the GDD's own numbers remain in tension |

### Implementation gaps

| # | Question |
|---|---|
| Q14 | **How E7 is stripped at export is unspecified.** A build-configuration decision (feature tags, conditional instancing) that this spec states as a requirement without prescribing a mechanism |
| Q15 | **BUG-0001 blocks E6 verification.** Kill planes never fire in `level_05` and `level_06`, so the death sequence cannot be tested against them until the mask is fixed |
| Q18 | **E8's zone, and how it arbitrates against the two-element budget, are undecided.** Assigned to ADR-0010 by `design/accessibility-requirements.md` § *Objective clarity*, together with `interaction-patterns.md` O5. See HUD Elements § E8 |
