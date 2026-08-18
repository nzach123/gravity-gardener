# Art Bible: Gravity Gardener

*Created: 2026-08-16*
*Status: Complete — all 9 sections authored (2026-08-18)*

> **Session note (2026-08-16)**: Section 8 (Asset Standards) authored first, before
> a Visual Identity Statement existed — its standards are grounded directly in
> `game-concept.md`'s Technical Considerations (2D pixel, NES-influenced) and
> `.claude/docs/technical-preferences.md` performance budgets, not in Section 1.
>
> **Session note (2026-08-17)**: Sections 1–4 (Visual Identity Foundation)
> authored this session, closing the one blocker on `/gate-check
> pre-production` (`gate-check-2026-08-16-pre-production-b.md`). Before
> drafting Section 1, the user resolved a live tension `/gate-check` surfaced
> between Pillar 1's presentation clause (flip legibility comes from "the room
> itself") and the MVP scope cut of physics props: the art bible narrows the
> mechanism for MVP tier only (camera + player-sprite rotation, both already
> implemented) without editing `game-concept.md` — see §1.3. Section 4 also
> formally adopts the NES palette (`docs/Pallete/nes-aesprite-1x.png`) as a
> project-wide constraint, closing `hud.md`'s Q4 ("no art bible... needs
> relocation"), and Sections 3.5/4.6 jointly close
> `accessibility-requirements.md`'s A4 (the capped-plant pour-refusal marker's
> form). AD-ART-BIBLE sign-off (Phase 5) was skipped — lean review mode
> (`production/review-mode.txt`); the skill's own rule treats it as
> non-blocking outside `full` mode.

> **Session note (2026-08-18)**: Sections 5, 6, 7 and 9 authored this session,
> closing the art-bible half of `/gate-check pre-production`'s FAIL. Section 5
> folds the template's **Animation Standards**; sections 6.7 and 7 fold its
> **VFX Standards** — neither earned a top-level section, because every VFX and
> animation question already had an owner in §§2–4, `hud.md`, or
> `watering-system.md`. Section 8 was also re-checked against §§1–4 for the first
> time (it was authored before they existed): §§8.3 and 8.5 are confirmed and
> strengthened, §§8.1/8.2/8.4/8.6/8.7/8.9/8.10 are unaffected, and **§8.8's shader
> example was corrected** — it named a "gravity-flip screen effect" that §2.5
> forbids by name. Ten items are flagged ⚠ unset with named owners rather than
> invented; §6.3's gravity-zone fill colour and §6.4's room-boundary treatment are
> the two that block asset work. §5.3 also surfaced a code question for
> `godot-gdscript-specialist`: sprite rotation eases at `16.0 * delta` on top of
> `gravity.md` R3's own 32-rate ease, so one rotation may be double-smoothed.
> AD-ART-BIBLE sign-off remains skipped — lean review mode
> (`production/review-mode.txt`).

---

## 1. Visual Identity Statement

### 1.1 The One-Line Rule

**Read the room, not the readout.** Every visual decision in Gravity Gardener must make the room's current truth — which way is down, what this action costs, how far the route has left to run — legible from the space itself. The HUD may confirm what the environment already shows; it must never be the only place a truth is visible.

### 1.2 Supporting Principles

**1. World-state motion over iconography** *(Pillar 1 — gravity is world state, not a player power)*
Gravity is global, broadcast state, so its visual proof must be a property of the whole scene, not a symbol pointing at it. *Design test: when a gravity change needs confirmation, choose an effect that moves the room/character (rotation, falling debris, changed silhouette) over an effect that adds an icon, arrow, or readout — even a well-designed one.*

**2. Weight scales with irreversibility** *(Pillar 3 — every bucket is a commitment)*
A bucket held is a bucket about to be spent forever; the player must feel that stake before they pour, not learn it from a tooltip. *Design test: when an object's silhouette, color, or animation weight is ambiguous, scale it up for anything single-use and route-defining (buckets), and keep it visually quiet for anything that isn't (cosmetic props, background dressing).*

**3. Geometry carries the clock, not a countdown widget** *(Pillar 2 — the clock is the route)*
Because oxygen capacity is derived from the level's own walked path, the level's geometry is already the timer — visual hierarchy should draw the eye toward routes and distances before it draws the eye toward a shrinking number. *Design test: when a screen could foreground either a dramatic ticking-down effect or clearer route/path readability, choose route readability — the number is a symptom, the space is the cause.*

### 1.3 Resolving the Pillar 1 / MVP Physics-Props Tension

Pillar 1 requires gravity-flip legibility to live in the room, not the UI. At MVP tier, that requirement is met without physics props: `main.gd`'s `_rotate_camera_to_gravity()` tweens the camera to the new gravity direction over 0.6s, and `player_visual_component.gd` continuously rotates the player sprite to track the current gravity vector. Together these already satisfy Principle 1.2.1 — the world moves, nothing is read off a number.

Physics props tumbling to the new down are a **Vertical-Slice-tier addition**, not the MVP-tier proof mechanism. Their absence at MVP does not leave Pillar 1 unmet — it's satisfied by camera and character rotation alone. Sections 5–8 should treat physics-prop tumble as an enhancement to design toward, not a dependency to design around.

---

## 2. Mood & Atmosphere

The station's ambient palette is cool, low-contrast, and functional throughout — nothing in this section adds warmth, comfort, or spectacle for its own sake. Each state below shifts *what the room emphasizes*, not the base register: this is a budgeted-urgency game, not a relaxation one, and no state should read as cozy.

### 2.1 Exploration / Routing

*The default state — reading a room's gravity and bucket/plant layout to plan a route.*

- **Primary mood target**: Watchful calculation. The calm of someone doing math with their own air supply — appraisal, not peace.
- **Lighting character**: Cool, low-contrast ambient (station backup lighting register). Desaturated blue-grey base. Flat palette bands, no gradients, no dynamic light.
- **Atmospheric descriptors**: derelict, sparse, functional, watchful, cold
- **Energy level**: Measured
- **Concrete visual element**: Every gravity-relevant surface, prop, and zone marker must read at a clean silhouette against the background at rest — this is the baseline the room needs before it can *move* to prove a flip (Principle 1). If the resting room is visually noisy, the flip has nothing legible to change *from*.

### 2.2 Carrying / Committed

*Holding a bucket at reduced speed — the point-of-no-return window before pouring.*

- **Primary mood target**: Held tension. The specific dread of carrying something you can't take back, while your own speed drops and the oxygen clock does not slow down to match.
- **Lighting character**: No lighting shift from Exploration — carrying is player state, not room state, and the room shouldn't lie about that. The bucket itself, not the environment, carries the visual weight.
- **Atmospheric descriptors**: burdened, exposed, deliberate, vulnerable
- **Energy level**: Measured, taut undertone — every second is now doubly costly (carry penalty stacked on constant drain).
- **Concrete visual element**: The full bucket reads heavier and higher-contrast than any cosmetic prop in the room (Principle 2 — weight scales with irreversibility), and the carry-speed walk cycle should visibly read as a slower cadence, not just a slower stat — the player should *see* they're moving through resistance before they'd ever check a number.

### 2.3 Pouring

*Held-input action that locks movement — the moment of spend.*

- **Primary mood target**: Committed exhale. The single point of no return, input locked, nothing left to decide.
- **Lighting character**: No lighting shift from Carrying. No full-screen flash or vignette — a screen-wide effect would compete with route/geometry readability (Principle 3) for a moment that should read as small and final, not spectacular.
- **Atmospheric descriptors**: locked, irreversible, exposed, brief
- **Energy level**: Contemplative snap — movement is locked, but the moment carries an undertone of exposure, since standing still to pour is mechanically the most dangerous action in the game (identical drain, zero mobility).
- **Concrete visual element**: The bucket's destruction must read immediately and unambiguously at pour-end — no lingering frame where its state is ambiguous — and the plant should visibly advance a growth stage as confirmation. The payoff lives in the world, not a UI counter (Principle 1 + Pillar 3).

### 2.4 Oxygen-Critical (50/25/10% thresholds)

*Escalating urgency as the non-refilling budget runs down.*

- **Primary mood target**: Escalating claustrophobia. The room itself should feel like it's closing in as each threshold crosses — a cumulative squeeze, not a jump-scare.
- **Lighting character**: Mandatory baseline — a three-step palette desaturation/cooling bound to the 50/25/10% crossings, achieved entirely in flat pixel palette (no dynamic lighting required). **Flagged, not specified**: a slow Light2D pulse layered on top at the 10% threshold only, as a candidate for technical-artist to cost against the draw-call/shader budget in Section 8 — the palette shift alone must carry the full mood on its own; the pulse is an enhancement, never a dependency.
- **Atmospheric descriptors**: airless, encroaching, thinning, cold, urgent
- **Energy level**: Escalates in three steps — measured (50%) → taut (25%) → controlled-frenetic (10%). Never true panic-chaos: the player's route-reading agency must stay legible even at the lowest threshold, or the state undermines the Challenge aesthetic it's meant to sharpen.
- **Concrete visual element**: The threshold-bound palette shift is itself the primary carrier — the environment's own color state becomes the ambient reminder of the budget, which is what Principle 3 (geometry carries the clock) actually asks for: the room cooling is a symptom of the same route-geometry that set the clock in the first place, not a decoration layered on top of it.

### 2.5 Gravity Flip Transition (~0.6s)

*The camera/sprite rotation moment itself.*

- **Primary mood target**: Vertiginous reorientation — a brief, controlled inversion. Disorienting enough to register as a real event, never disorienting enough to cost the player their bearings (this is also the game's flagged motion-sensitivity risk — see `accessibility-requirements.md`).
- **Lighting character**: No lighting or palette change during the flip itself. Compounding a color/brightness shift with the rotation risks worsening the motion-sensitivity load the accessibility tier already treats as the dealbreaker case. The palette holds constant; only geometry moves.
- **Atmospheric descriptors**: brief, inverting, mechanical, controlled
- **Energy level**: Frenetic but short-lived — one sharp beat, not a sustained state.
- **Concrete visual element**: Per Section 1.3, the camera tween and continuous player sprite rotation are the entire mood-delivery mechanism at MVP. No competing VFX layer (flash, particle burst, screen shake) should be added on top — Principle 1 requires the room's own motion to be the legible proof, unclouded by an effect fighting for the same half-second.

### 2.6 Level Complete / Restart

*Reaching the airlock, or an instant full-scene restart on any death.*

- **Primary mood target**: Complete — threshold quiet: relief that is resolved, not triumphant. Restart — a clean reset with zero punishment weight; the moment should carry no more emotional charge than closing a door.
- **Lighting character**: Complete — the Exploration-tier ambient palette holds through the level. The exit needs some diegetic "this is safe" marker (Principle 1: the environment answers the question, not a banner), but its specific visual treatment is left undecided here and deferred to Section 6 (Environment Design Language). Restart — no fade-to-black, no mourning beat; the existing instant scene reload is the entire transition, by design.
- **Atmospheric descriptors**: Complete — quiet, resolved, still cold, survivable. Restart — brisk, neutral, unceremonious.
- **Energy level**: Complete — release, dropping from whatever Oxygen-Critical energy preceded it. Restart — flat/neutral; no energy build at all.
- **Concrete visual element**: The exit must function as the room's own answer to "where do I go" (Principle 1's ban on icon-first communication) — the specific color, light, or silhouette treatment that achieves this is a Section 6 decision, not fixed here. Restart's concrete element is a deliberate absence: no transition animation beyond the current instant reload, because adding one would add friction to failure recovery that `game-concept.md`'s flow-state intent ("must never be surprised") extends into "must never be punished."

### 2.7 Menus (main menu / pause)

*Currently placeholder-only in `src/` — full UI/UX layout belongs to Section 7, not here.*

Tone-continuity note only: menus must read as continuous with the station's own cold, functional palette (2.1's ambient register) rather than adopting a separate "welcoming" or warm menu aesthetic. The moment a player opens a menu should not feel like leaving the world of the game — it should feel like the station's own status screen. Full layout, hierarchy, and interaction direction for menus is deferred to Section 7 (UI/HUD Visual Direction).

---

## 3. Shape Language

Section 1 fixed the *why* (world-state motion over iconography, weight scales with irreversibility, geometry carries the clock) and Section 2 fixed the *mood* (cool, functional, no coziness). Shape is where those become concrete: what silhouette family each object belongs to, and why that family is the one that lets the eye do the work the HUD is explicitly not allowed to do alone.

### 3.1 Character Silhouette Philosophy

**Default: silhouette-first, blocky, low internal detail.** At 64×64 on-screen (32×32 source, Section 8.3's deliberate one-step-up exception) the gardener has just enough room for pose identity to live in outline mass, not in surface detail — so every pose (idle, run, jump, fall, carry, pour) should be identifiable as a flat black silhouette, with color and shading doing confirmation work only. This also keeps the character register consistent with Section 2's anti-coziness mood: chunky NES-proportioned limbs read as functional and worn, not cute-rounded. *Flagged alternative*: a softer, rounded silhouette to humanize "the last gardener" against the cold station — rejected as default because it fights the mood register Section 2.1–2.4 already committed to; revisit only if playtesting shows the station reads as *too* alienating around the one character players are supposed to root for.

**The hard requirement is carry vs. non-carry, at any rotation angle.** Because the player sprite continuously rotates to track the live gravity vector (Section 1.3), a pose that only reads correctly upright is a latent bug — the moment gravity tips off vertical, that pose's silhouette is now unfamiliar. This is where Principle 1 (the room proves gravity, not an icon) and Pillar 3 (every bucket is a commitment) collide: the *carry* read has to survive the same rotation that *proves* gravity, or the two systems undercut each other exactly when it matters most (mid-puzzle, bucket in hand, room turning over).

**Recommended solution: the bucket is a satellite shape, not a pose change.** Rather than relying on arm/leg angle alone to signal "carrying" (which can rotate into ambiguity), attach the bucket as a distinct, high-contrast mass offset from the body's own outline — a second silhouette riding alongside the first. A satellite shape stays legible as "something is attached that wasn't there before" at any rotation, the same way a person can tell someone is carrying a box in silhouette from any angle, where a bent elbow alone might not survive an upside-down read. This directly extends Principle 2 (weight scales with irreversibility): the added shape isn't decorative, it's the single-use commitment made visible as extra mass on the silhouette. *Flagged alternative*: pose-only distinction (bent arms, lower stance, no separate attached shape) — simpler to animate, but weaker at oblique rotation angles; recommend against as default, acceptable as a fallback if the satellite-shape approach proves too heavy for the 512×512 player-sheet budget (Section 8.7).

**Pour deepens the carry silhouette rather than replacing it.** Pour is carry's silhouette with the bucket shape reoriented (tilted, arm extended toward the plant) and the whole pose locked — the player should be able to tell "carrying-and-moving" from "carrying-and-pouring" from silhouette alone, since pour is mechanically the most exposed state in the game (Section 2.3) and deserves to look like it.

**Jump vs. fall** should differ in limb extension (jump: gathered/rising mass; fall: extended/falling mass) rather than in a directional cue, since "which way is falling" is answered by the room's rotation, not the character's pose — the pose only needs to answer "am I airborne and which phase," a smaller, silhouette-cheap distinction.

### 3.2 Environment Geometry — Safe Terrain vs. Hazards

**Default: predominantly rectilinear/orthogonal for all safe terrain.** A derelict station reads as engineered, not grown — angular geometry communicates "built structure now abandoned," which is the entire fictional premise, and it also happens to be the natural output of a 16×16 grid-snapped `TileMapLayer` (Section 8.3/8.9). This gives Section 2.1's "every gravity-relevant surface must read at a clean silhouette at rest" a concrete shape vocabulary: flat, orthogonal, low edge-frequency — a calm baseline the room can visibly *move away from* when gravity flips (Principle 1 needs a quiet resting state to prove motion against; a visually busy baseline has nothing left to change).

**Hazards must break that grammar, not just recolor it.** Spikes and kill zones use a shape family that appears nowhere else in safe geometry — sharp, irregular, high edge-frequency triangulation — so a hazard is identifiable by contour alone, before color is ever read. This is the shape-level half of the colorblind-safety requirement flagged in `accessibility-requirements.md`'s Colour-as-Only-Indicator audit: Section 4 will own the actual hazard color, but shape independence has to be designed in now, not patched on after the fact, because a shape decision made late tends to get "solved" with a color overlay instead — exactly the failure mode Principle 1 exists to prevent. *Design test*: if a hazard and a piece of safe terrain could be told apart only by their fill color in a greyscale screenshot, the shape hasn't done its job yet.

**Plants are the one deliberate organic exception.** Curved, irregular silhouettes exist nowhere else in the station's shape vocabulary, which means a plant is automatically the odd shape in the room — a Gestalt figure-ground pop that needs no extra size or color trick to draw the eye (see 3.4). This is not a stylistic accident; it is Pillar 2's route-geometry principle expressed as shape: the plant is the destination the route is walked toward, so it should be the one shape family the rectilinear station can't produce on its own.

### 3.3 Gravity Zone Shape Language

The zone's trigger-volume fill (`ColorRect` in `gravity_zone.gd`) should stay a plain rectangle matched to its collision shape, undecorated — consistent with 3.2's "clean silhouette at rest" requirement; an ornamented zone boundary would compete with the terrain it overlays for no communicative gain.

The **directional arrow is confirmatory, not primary.** Per Section 1.3, the camera tween and player-sprite rotation already carry the full proof that gravity changed; the arrow's job is narrower — telling the player, before they commit to entering, which way a zone *will* set gravity. Recommend a simple, bold, unmistakably-tipped chevron (wide flat tail, sharp point) rather than a stylized or multi-part icon, so its meaning survives at small size and at any of the rotation angles a zone might be authored at. Keep its visual weight subordinate to hero shapes (3.4) — it's a wayfinding aid attached to reversible, exploratory information (you can look at a zone without committing to anything), not an irreversible-stakes object like a full bucket, so it should never out-compete those for attention.

### 3.4 Hero Shapes vs. Supporting Shapes

This is Principle 2 (weight scales with irreversibility) and Pillar 2 (route geometry must read against background noise) applied directly to visual hierarchy: what the eye is *pulled toward* should track what the fiction is asking the player to weigh.

**Hero shapes** (largest mass, highest local contrast, most complex silhouettes):
- **Full buckets** — the heaviest-reading object at rest, since picking one up is the start of every irreversible commitment in the game.
- **Near-complete and capped plants** — see 3.5; growth stage is itself a shape hierarchy.
- **The airlock/exit** — recommend it be the one architectural feature permitted a contour break from the surrounding rectilinear wall grammar (e.g. a rounded or beveled aperture set into an otherwise orthogonal wall), so "this is not a wall" is answerable by silhouette alone, satisfying Principle 1's ban on icon-first wayfinding — the shape-level half of Section 2.6's deferred exit decision; color and light treatment stay with Section 4/6. *Flagged alternative*: keep the airlock fully rectilinear and mark it only with beveled corners/a threshold frame — more conservative, consistent with the station's grammar throughout, but weaker at a glance from range; recommend the contour-break default given how directly it serves Principle 1.

**Supporting shapes** (recede, visually quiet, deliberately unremarkable):
- **Terrain** — clean but flat, per 3.2; it's the ground the hero shapes stand out from, and if it competes for attention it has failed its job.
- **Cosmetic physics props** — `physics-props.md` R1 already forbids them from affecting solvability; shape language should reinforce that by keeping prop silhouettes visually subordinate (smaller mass, lower contrast) to anything route-relevant, so their eventual Vertical-Slice-tier addition doesn't accidentally start competing with buckets/plants for eye priority.
- **Spent/empty buckets** — must not just be a full bucket recolored. Per Section 2.3's "destruction must read immediately and unambiguously," the empty-bucket silhouette should be a genuinely different, deflated/collapsed shape (smaller footprint, flattened form) rather than the same vessel outline in a different palette — this is the shape-level guarantee that a glance, not a color check, tells full from spent.

### 3.5 Plant Growth-Stage Shape Progression

Growth stage should read as **accumulating shape mass and complexity**, not a palette swap — the plant literally gets bigger and more structurally elaborate as `growth_fraction` climbs (`watering-system.md` §4), which lets a glance at a room's plants estimate remaining work before a single bucket count is read (Pillar 2: geometry carries the clock, extended to "the room's own state carries the delivery risk"). Recommend: early stages read as sparse, thin-lined, small-footprint (a sprout); mid stages add bulk and branching; the final, capped stage adds a shape found at no earlier stage — a bloom or pod silhouette — so full growth is recognizable in outline alone, at any distance, without requiring the player to be close enough to read a color band.

This also resolves `accessibility-requirements.md`'s open item A4 (the capped-plant "pour refused" marker's form was left unspecified — colour, shape, or icon) at the shape level: recommend the capped-stage bloom/pod silhouette *itself* be the non-color signal, doing double duty as both "this plant is done growing" and "don't try to pour here," rather than inventing a second icon vocabulary. ADR-0010 already architects the pour-refusal marker (E4) as a rendered element in the world-tracked layer, offset from the plant along eased gravity-up — recommend that marker reuse the same bloom/pod shape rather than a distinct glyph, so there is exactly one shape grammar for "this plant is finished," not two. *Flagged alternative*: a separate small refusal icon in the Z2 slot, independent of the plant's own growth silhouette — more flexible for HUD styling, but reintroduces a second shape language for the same fact, which Principle 1 argues against by default. Full icon/marker visual design (size, exact rendering) remains Section 7's job; this only fixes that the *shape family* should be the plant's own bloom, not a bolted-on symbol.

### 3.6 UI Shape Grammar (brief — full design deferred to Section 7)

Recommend a **restrained echo**, not a fully separate language: HUD elements should share the station's rectilinear, angular vocabulary (thin straight strokes, no rounded panels) for the tonal continuity Section 2.7 already committed to — but every HUD shape should stay visually quieter (thinner strokes, smaller mass, lower contrast) than any world hero shape from 3.4, so it never wins the eye's attention against the room it's reporting on. This is Principle 1 taken literally: the world carries the truth, so the readout's shapes should look like confirmation, not competition. Full HUD shape grammar — panel geometry, the tick-mark/numeral system already partly fixed in `design/ux/hud.md`, icon treatment — is Section 7's job; this is only the standing constraint that governs it.

---

## 4. Color System

Section 3 fixed *what* needs to read at a glance — hero shapes, hazard contours, growth stages, the airlock's contour break. Color's job here is strictly reinforcing: every gameplay-critical read Section 3 already secured with silhouette stays secured without color; color adds legibility, mood, and a small amount of thematic coherence on top, never a load-bearing signal on its own.

### 4.1 Primary Palette

All colors below are drawn from the project's fixed 56-entry NES palette (`docs/Pallete/nes-aesprite-1x.png`), which `hud.md`'s Palette section and `accessibility-requirements.md`'s U8.15 reference both already treat as a binding project-wide constraint with no home of its own (`hud.md` Q4 flags exactly this gap). This section is that home — the constraint is formally adopted here, and every hex below is a direct entry from that set, not an approximation of one.

| Name | Hex | Role |
|---|---|---|
| **Station Cool** | `#305182` | Default ambient/safe register. The base wash for backdrop, walls, and structural mass at rest — this *is* the "desaturated blue-grey" Section 2.1 already committed to. |
| **Structural Grey** | `#797979` (highlight variant `#A2A2A2`) | Neutral mass for terrain and supporting shapes (Section 3.4). Deliberately under-saturated relative to every hero color so supporting geometry stays visually quiet. |
| **Signal Cyan** | `#61D3E3` | "Full / good / nominal" — carried by the full bucket. Deliberately the same hex as `hud.md`'s E1 nominal oxygen band, so world and HUD share one hue-family for "you're fine," without the two channels ever rendering the same shape (see 4.5 for why this isn't a restrained-echo violation). |
| **Growth Green** | `#306141` → `#49A269` → `#71E392` (one contiguous NES palette row, used as a three-stage ramp) | The plant's vitality color, and the one deliberate organic hue-family in a station otherwise built from blue-grey (Section 3.2's "deliberate organic exception" made literal in color, not just shape). |
| **Hazard Crimson** | `#B21030` | Reserved exclusively for spike/kill-zone geometry. Never appears anywhere else in the palette, so any crimson onscreen is unambiguously "this will kill you." |
| **Exit Amber** | `#FFDBA2` | Reserved exclusively for the airlock. The single warm-hued color permitted anywhere in the game — see 4.4. |
| **Void Black** | `#000000` / `#010101` | Silhouette outlines (Section 3.1's silhouette-first mandate), background depth, and the anchor value the oxygen-critical progression recedes toward (4.3). |

### 4.2 Semantic Color Usage

**The unifying rule: depletion is expressed as desaturation, everywhere, without exception.** A full bucket is Signal Cyan; a spent one desaturates to Structural Grey rather than getting a new hue (Section 3.4's deflated-shape answer already carries the fact — the recolor is confirmation, not the signal). Oxygen dropping recedes the room's own Station Cool toward Structural Grey and Void Black in three steps (4.3). Nothing in this game "warms up" as a resource depletes — warmth is reserved entirely for the one moment that's a genuine resolution, not a loss (4.4). This gives the player one consistent color grammar to learn instead of a different one per system: *cool and saturated = has value, grey and dark = spent it.*

**Why the world cools while the HUD warms.** `hud.md`'s E1 gauge already escalates through conventional semaphore hues — cyan → yellow (`#EBD320`) → orange (`#FFA200`) → red-orange (`#E35100`) — chosen for worst-case contrast against arbitrary terrain, which is a different design constraint than the world's own mood language. Rather than fight that fixed HUD contract, this section deliberately does *not* mirror it: the room's own oxygen-critical response cools and desaturates (below) while the HUD gauge warms in the conventional direction. This is Principle 1 taken seriously — the room and the readout are different channels answering different questions ("how does the air in this room feel" vs. "what's my exact remaining budget"), and giving them different color behavior instead of a shared one keeps the player from mistaking a HUD glance for a room read, or vice versa.

**Green is quarantined to plants; crimson is quarantined to hazards.** Neither hue appears anywhere else in the primary palette. This means a player under any color-vision variant still has one dependable fact available even before shape resolves at distance: if it's green, it's alive and progressing; if it's crimson, it's dangerous. Shape remains the actual guarantee (Section 3.2, 3.5) — this is a free second layer of consistency on top, not a substitute for it.

### 4.3 Oxygen-Critical Three-Step Progression

This is the palette system's single most load-bearing decision, and it is implemented entirely as **proportion swaps between existing entries** — no new hues, no gradients (Section 2.1 forbids gradients outright), no blended/interpolated values outside the fixed 56-entry set. Concretely, the ambient wash recedes Station Cool's blue coverage toward Structural Grey and then Void Black in three discrete bands, matched to the 50/25/10% crossings already fixed by `hud.md`'s E1 tick marks:

| State | Dominant ambient | Secondary | Depth/shadow | Read |
|---|---|---|---|---|
| Baseline (100–50%) | Station Cool `#305182` | Structural Grey `#797979` | `#010101` | Watchful calculation (2.1) |
| Step 1 — cross 50% | Structural Grey `#797979` (blue recedes to accent-only) | Station Cool `#305182`, reduced coverage | `#000000` | The room loses its dominant hue; grey takes over |
| Step 2 — cross 25% | Structural Grey `#797979` only — Station Cool removed from ambient dressing entirely | Structural Grey highlight `#A2A2A2` | `#000000` | Blue is gone. The room reads flat, cold, and thinning |
| Step 3 — cross 10% | Structural Grey `#797979`, compressed toward near-monochrome | — | `#000000`, expanded coverage | The room is effectively greyscale; only Growth Green and (once visible) Exit Amber remain as color anywhere onscreen |

This delivers 2.4's "cumulative squeeze" honestly: each threshold doesn't add a new warning color, it *removes* one — the station's one hue (blue) drains out of the world in the same three steps the HUD's tick marks already make legible by position, so this is redundant confirmation of an already-resolved cue (see 4.6), never a new color-only signal. It's also implementable as a straightforward palette-index swap on the tileset/backdrop rather than a per-pixel shader blend — flagged for technical-artist to confirm feasibility and cost against the GL Compatibility budget (Section 8.8), but the design intent doesn't require a shader to exist.

### 4.4 Airlock / Exit Color Resolution

**Recommendation: Exit Amber (`#FFDBA2`) is the one warm-hued color permitted anywhere in the game, but it is explicitly *not* the most saturated value available — that's the softening this section commits to.**

Section 2 fixed "no coziness, ever" as a standing constraint, and Section 3.4 flagged the airlock's color/light treatment as deliberately deferred here. The prior draft idea — give the exit the single warmest *and* most saturated color in the game — risks reading as a fanfare/reward beat, which 2.6 explicitly rejects ("relief that is resolved, not triumphant"). The fix isn't to drop warmth, it's to drop saturation: `#FFDBA2` is a pale, institutional amber — closer to fire-exit signage than firelight — chosen specifically because it's flat and low-key rather than glowing. It earns its significance through **scarcity, not intensity**: it is the only warm value in a 7-color palette otherwise built from blue-grey, green, and crimson, and by the time a player is close enough to see it, the oxygen-critical progression (4.3) has likely already receded the rest of the screen toward greyscale — so the amber's relative visual weight *increases* as the world cools, without the color itself ever changing. The resolution point earns its prominence by being the last color standing, not by being turned up.

No full-screen wash, no glow/bloom VFX layer, no pulse — that treatment stays confined to the contour-break aperture shape Section 3.4 already fixed, consistent with 2.1's "flat palette bands" rule. *Flagged alternative*: keep the airlock in Structural Grey/Station Cool like the rest of the station, relying on the contour-break shape alone — the more conservative, fully-consistent-with-"no coziness" option, but it forfeits a resolution beat the mood arc in Section 2.6 ("relief that is resolved") seems to want. Recommend against as default; the pale, quarantined-warmth version above satisfies both constraints rather than trading one for the other.

### 4.5 UI Palette Relationship

**The HUD's color language stays decoupled from the world's, even though its shape language does not.** Section 3.6 already fixed the HUD as a *restrained echo* of the world's shape vocabulary — thin strokes, low mass, subordinate contrast. Color doesn't inherit that same echo relationship, and that's a deliberate choice, not an oversight: `hud.md`'s E1 bands (`#61D3E3` / `#EBD320` / `#FFA200` / `#E35100`) were chosen and contrast-validated against the worst-case arbitrary terrain they render over (`accessibility-requirements.md`'s E1 band contrast table), which is a legibility constraint the world's own mood-driven palette isn't built to satisfy — the world palette is allowed to recede toward black at 10% oxygen; a HUD element is never allowed to do that, because R7's "always legible" rule doesn't get a pass just because the room went dark. Decoupling color while keeping shape coupled resolves that tension cleanly: the HUD looks like it belongs to the station (thin rectilinear glyphs, Section 3.6) without being handed the world's own palette rules, which weren't designed to guarantee HUD-grade contrast in the first place.

Both palettes still draw from the same 56-entry NES source (satisfying `hud.md` H23), and the HUD's existing black-outline/white-text requirement (`#000000` / `#FFFFFF`, both native palette entries) is unchanged by this section — it's confirmed, not revised. Full HUD color application (backing plates, E2–E8 treatment) remains Section 7's job; this section only fixes that world and HUD are two dialects of one palette, not one shared rulebook.

### 4.6 Colorblind Safety Table

Every gameplay-critical color assignment above is reinforcing a signal Section 3 already secured by shape. None of the five required states below is color-only.

| State | Color | Non-color backup (Section 3 citation) | Status |
|---|---|---|---|
| Hazard danger | Hazard Crimson `#B21030` | 3.2 — hazards use a sharp, irregular, high-edge-frequency shape family that appears nowhere in safe terrain; identifiable by contour alone in a greyscale screenshot | Reinforcing |
| Oxygen-critical world state (50/25/10%) | Three-step recession of Station Cool toward Structural Grey/Void Black (4.3) | Same crossings are already resolved non-color by `hud.md` E1's static tick marks + numerals — `accessibility-requirements.md`'s Colour-as-Only-Indicator audit marks this row **Resolved** independent of this section | Reinforcing — redundant with an already-resolved cue |
| Full vs. spent bucket | Full = Signal Cyan `#61D3E3`; spent desaturates to Structural Grey `#797979` | 3.4 — the spent bucket is a genuinely different, deflated/collapsed silhouette, not the full shape recolored | Reinforcing |
| Plant growth / completion | Growth Green ramp `#306141` → `#49A269` → `#71E392` | 3.5 — growth reads as accumulating shape mass/complexity, culminating in a bloom/pod silhouette that exists at no earlier stage | Reinforcing |
| Pour-refused marker | Same capped-stage Growth Green accent — no new hue introduced | 3.5 — the capped-stage bloom/pod shape *is* the marker (reused, not a bolted-on icon), closing `accessibility-requirements.md` A4 at the shape layer; color here only confirms the same silhouette | Reinforcing — closes A4 jointly with Section 3.5 |

**No gap flagged.** Every state this section assigns a gameplay-critical color already had a non-color answer from Section 3 before this section started; color's job throughout was confirmation, never the only channel carrying the fact.

---

## 5. Character Design Direction

Section 3.1 fixed the *why* of the gardener's shape (silhouette-first, blocky, carry as a
satellite mass) and Section 4.1 fixed which hexes render it. This section is the character
spec sheet those decisions produce: scale, proportion, how the sprite behaves under the
game's one continuous transform (gravity rotation), what states it must render, and where
squash-and-stretch sits today.

### 5.1 Scale and Silhouette Readability

The gardener renders at **64×64 on-screen from a 32×32 source** — one grid-step above every
other asset category, a deliberate exception fixed in §8.3 specifically so gravity-flip pose
states have "enough silhouette room to stay legible per Pillar 1." This section inherits that
exception rather than re-deciding it: the extra resolution exists to serve §3.1's
silhouette-first mandate, not for its own sake. Every pose must still pass §3.1's test at that
size — identifiable as a flat black silhouette before any internal colour or shading is read.

The player's outline uses **Void Black** (`#000000`/`#010101`, §4.1) at a fixed weight,
matching the black-outline convention `debugger.gd` and `hud.md`'s E1–E4 elements already use
for the same reason: an outline is what keeps a small silhouette legible against the Station
Cool ambient backdrop (§2.1) at any of the three oxygen-critical desaturation steps (§4.3),
including the near-monochrome step 3 band where most of the screen's colour has already
drained out.

### 5.2 Proportions

**Direction, not a grid.** §3.1 already commits to "chunky NES-proportioned limbs" over a
softer, rounded silhouette, specifically to keep the character register consistent with §2's
anti-coziness mood — worn and functional, not cute. This section holds that line: thick limb
masses, a low ratio of fine internal detail to outline mass, no rounded or plush silhouette
treatment anywhere on the body.

> ⚠ **Unset.** The precise proportion grid (head-to-body ratio, limb width as a fraction of
> torso width, exact pixel counts per limb) is deliberately not invented here — a number
> picked without a reference sprite sheet in hand would be constructed rationale, which this
> document avoids. **Owner: whoever executes the 32×32 master sheet** (currently
> `src/assets/GG-MainPlayer_Master_SpriteSheet_v1.png`), working from §3.1's qualitative
> direction and this section's silhouette test, with sign-off against §3.1 before the sheet
> is treated as final.

### 5.3 Rotation Behaviour Under Gravity Flips

Per `gravity.md` R1/R3, gravity direction eases toward its target via `lerp_angle`, and per
§1.3, continuous player-sprite rotation is one of exactly two mechanisms carrying Pillar 1's
flip-legibility proof at MVP (the other is the camera tween). `player_visual_component.gd`'s
`update()` implements this today: `sprite.rotation` tracks
`gravity.normalized().angle() - (PI * 0.5)`, itself eased via a second `lerp_angle` at a
`16.0 * delta` rate.

**The character must read correctly at every angle along that sweep, not just at the four
cardinal rests.** This is §3.1's hard requirement restated for the rotation system
specifically: because the sprite is genuinely mid-rotation for the tween's full duration, a
pose that only reads upright is a bug the instant a flip begins, not just at 90°/180°
intervals. The carry satellite-shape solution (§3.1) exists precisely because it survives this
continuous sweep where a pose-only carry cue would not.

> ⚠ **Flagged inconsistency — a code question, not an art-direction one.** `gravity.md` R3
> eases the gravity vector at a 32 rad/s-scaled rate. `player_visual_component.gd:41` then
> eases `sprite.rotation` toward that already-eased target at a separate `16.0 * delta` rate,
> so the sprite may be double-smoothing one rotation through two independent lerps at two
> different rates. Whether that is an intentional secondary softening (visually distinct from
> the physics-relevant `up_dir`) or an unintended duplicate adding latency to the "decisive
> but trackable" feel `gravity.md` §2 targets is undetermined. **Owner:
> godot-gdscript-specialist**, to confirm which rate is authoritative for the *visual*
> rotation before this section's silhouette-at-any-angle requirement is tested against a build.

### 5.4 Animation State Coverage

| State | Status today | Direction |
|---|---|---|
| Idle | Implemented (`Idle`) | Holds current form |
| Walk/Run | Implemented (`Run`) | Holds current form |
| Jump | Implemented (`Jump`) | Gathered/rising limb mass per §3.1's jump-vs-fall distinction — the pose answers "airborne, which phase," not "which way is down" |
| Fall | Implemented (`Falling`, selected by `velocity.dot(-up_dir) > 0`) | Extended/falling limb mass, same rationale |
| Land | **Not a distinct animation.** `_on_landed()` only arms `land_squash_timer` for the (currently disabled, §5.5) squash pose | A short, cheap landing read is still owed even with squash-stretch off — at minimum a 1–2 frame settle on the existing Idle/Run pose, so a landing is not visually identical to never having left the floor. ⚠ **Unset**: no frame budget or timing authored. **Owner: pixel artist executing the sheet**, once §5.2's proportion grid exists to draw against |
| Carry | **Not implemented.** `_on_watering_started`/`_on_watering_stopped` are empty stubs | Per §3.1 the bucket is a satellite shape attached to the existing pose, not a new limb-pose animation. Carry is therefore an overlay riding the Idle/Run/Jump/Fall poses, not a fifth clip. Authoring it as a duplicate pose set would double the sheet for no legibility gain the satellite shape does not already provide |
| Pour | **Not implemented.** Same empty stubs as Carry | Per §3.1, "Pour deepens the carry silhouette rather than replacing it" — bucket reoriented, arm extended toward the plant, whole pose locked (matches `watering-system.md` R3's movement lock). Carry's silhouette with a distinct held frame, not a new limb set |
| Death | **Not implemented.** No death handler exists on the component at all | ✅ **CLOSED 2026-08-18 by ADR-0014.** `hud.md` E6 places the death sequence at Z3, full-viewport, described only as "visual and audio effects" — it does not say whether the player sprite changes pose, freezes, or is occluded. Recommended: the sprite holds its last pose and the full-viewport E6 effect carries the beat — cheapest to build and consistent with §2.3's instinct against a lingering ambiguous frame. **This was a recommendation; it is now the structural default.** ADR-0014 D14.3 leaves `Player` at `PROCESS_MODE_INHERIT` → `PAUSABLE` while the death sequence holds the tree paused, so the sprite freezes holding its last pose with no death animation authored and no clip added to the sheet. The agreement this row was waiting on is supplied by that process-mode assignment rather than by a separate ruling. **No death pose is owed to the pixel artist** |

### 5.5 Squash-and-Stretch Stance

`player_visual_component.gd` ships a full squash-and-stretch system (`scale_jump`,
`scale_land`, `scale_run`, lerped at `squash_stretch_speed`) gated behind
`squash_stretch_enabled: bool = false` — **off by default in the current code.**

This section takes no position on whether it should turn on. Squash-and-stretch is a
classic-animation weight cue, and §3.1 already chose to carry weight and state through
*silhouette mass* (the carry satellite shape) rather than through squash-driven deformation.
The two are not in conflict, but enabling squash would add a *second* weight-communication
channel to a system §3.1 built to work without one.

**Recommended: leave it disabled for now**, consistent with §2's anti-spectacle register. The
`scale_land` value in particular (`Vector2(2.6, 1.4)`) is an aggressive squash that risks
reading as bouncy in a game whose mood target is watchful calculation, not physical comedy. If
it is ever enabled it should be revisited against §2.1–2.4 first, not switched on because the
export already exists.

> ⚠ **Unset.** Squash-and-stretch has not been evaluated against the escalating
> oxygen-critical states (§2.4) — whether a landing squash should compress differently as the
> room's palette recedes toward monochrome is open if the system is ever turned on. Not
> assigned; flagged only, because the system is off.

### 5.6 Facing and Flip Behaviour

`sprite.flip_h` is driven by the same screen-relative axis the movement component uses —
`GravityAuthority.apply_screen_relative_axis(input_axis, right_dir, camera_rotation)`
(ADR-0013 D13.2). One shared function, two callers, so facing cannot diverge from travel
direction at any gravity angle or any camera rotation (`TR-gravity-013`).

No art-direction decision is needed beyond confirming what that mechanism means for the
character: **facing is a screen-space read.** It matches `gravity.md` R11's contract that a
movement key always moves the player the same direction on screen, so the character's flip
state never requires the player to reason about the current gravity angle. This is the same
category of screen-relative-only information as §3.1's stance that jump and fall poses answer
"airborne, which phase" rather than "which way is down."

---

## 6. Environment Design Language

§§3.2–3.4 fixed environment shape language: rectilinear safe terrain, a reserved hazard shape
family, a quiet gravity-zone rectangle with a confirmatory chevron, and hero/supporting shape
hierarchy. This section extends that into material, rendering, and the multi-room readability
problem the MVP scope now requires (`game-concept.md` MVP Definition: "several chambers
connected by gravity-zone traversal").

### 6.1 Tile and Terrain Material Language

Safe terrain renders in **Structural Grey** (`#797979`, highlight `#A2A2A2`, §4.1) over the
**Station Cool** (`#305182`) ambient wash — flat palette bands, no gradients, per §2.1. §3.2
already fixed the shape grammar (orthogonal, 16×16 grid-snapped, low edge-frequency); this
section confirms that grammar survives contact with rendering: no per-tile lighting variation,
no ambient-occlusion fake, no bevel or emboss on tile edges. Anything that adds false depth or
light direction to a category that is supposed to recede (§3.4's "supporting shapes…
deliberately quiet") implies a light source the flat-band lighting model does not have, and
reads as a mood contradiction the moment a player notices it matches nothing else on screen.

> ⚠ **Unset.** Whether structural surfaces (walls, floors meant to be stood on) and
> background-depth surfaces (far walls, non-traversable dressing) get any rendering
> differentiation beyond §6.5's depth cueing is undecided. Flagged rather than invented: a
> wrong answer here — a texture-detail difference, say — risks reintroducing the visually busy
> baseline §3.2 warns against. **Owner: technical-artist**, once a tileset exists to test
> against.

### 6.2 Hazard Legibility in the Environment

§3.2 and `hazards.md` R4 both already require that a hazard be identifiable by contour alone,
in greyscale, before colour confirms it: sharp, irregular, high-edge-frequency triangulation,
reserved nowhere else in safe geometry, paired with **Hazard Crimson** (`#B21030`, §4.1) used
for nothing else.

This section adds the rendering consequence of `hazards.md` R5: a hazard must mount and read
correctly on floor, ceiling, or either wall — R5 flags that the current code does not satisfy
this, since `spike_hazard.gd` is hard-coded horizontal-only. The hazard shape family therefore
cannot be authored as a single orientation-locked sprite. It must render legibly at 0°, 90°,
180° and 270° (`hazards.md` AC6) without the triangulated silhouette collapsing into ambiguity
at any of them: a spike run mounted on a side wall must still read as sharp and irregular from
a horizontal approach, not only from below.

**Kill areas get no shape treatment at all**, by design. `hazards.md` R2 makes them invisible
volumes outside playable space, and R8 restricts them to bounding the space rather than being a
designed challenge. Giving a kill area a visible silhouette would misrepresent it as a readable
hazard when its entire job is to be unreachable on the intended route.

### 6.3 Gravity Zone Visual Treatment

Already specified in §3.3 and implemented in `gravity_zone.gd`: a plain, undecorated rectangle
(`ColorRect`) matched to the trigger volume, plus a bold, unmistakably-tipped chevron
(`ArrowSprite2D`) that is confirmatory rather than primary. The camera tween and player-sprite
rotation (§1.3) carry the proof that gravity *changed*; the chevron tells the player, before
commitment, which way it *will* change.

This section adds one rendering constraint: the zone rectangle's fill must stay in the
palette's low-saturation register — Structural Grey, or a low-alpha Station Cool wash — so it
never competes with Signal Cyan buckets or Growth Green plants for the hero-shape attention
§3.4 reserves for those.

> ⚠ **Unset.** The zone rectangle's exact fill colour and alpha have never been decided.
> `gravity_zone.gd`'s `ColorRect` exists in code with no colour recorded anywhere in this
> document. **Owner: art-director (follow-up pass) or technical-artist**, once a level with an
> instanced zone exists to preview against. Inventing a hex now, with nothing to check contrast
> or legibility against, would be the unfounded-value problem this document avoids.

### 6.4 Room-to-Room Readability (Multi-Room MVP)

**Two camera modes exist across the eight shipped levels, and both must be supported.**
`level_01` and `level_07` run follow-plus-rotate: the camera tracks the player and tweens to
match the gravity basis, so screen-up always equals gravity-up. `level_02` through `06` and
`08` run static: the camera neither follows nor rotates, so screen-up is fixed world-up and the
player sprite visibly rotates instead. This changes what room-to-room readability *means* per
level.

- **In follow-plus-rotate rooms** the player never sees the room itself rotate — their camera
  turns with it. Legibility here is almost entirely a terrain-grammar problem (§6.1): the
  player must tell "this chamber's floor" from "the chamber I just left" from the tile language
  alone, because the camera will not announce a room transition the way gravity does.
- **In static-camera rooms** the player sprite rotating against a fixed frame is itself a
  strong "your state changed" cue — but only if the room's geometry stays legible through that
  rotation. A room that clusters its important surfaces on one side, assuming the player always
  approaches from below, reads badly the moment gravity flips that side to the ceiling.

**Level-authoring implication, not an asset spec:** rooms in static-camera levels should be
checked for legibility at every orientation they can be entered under, not only their default
one. This is the same family of discipline as `hazards.md` R5's mount-at-any-angle requirement.

Beyond camera mode, multi-room readability needs a way to tell "this is a different chamber"
from "this is more of the same chamber" at a glance, independent of gravity state. §6.1's flat,
undifferentiated tile grammar is deliberately quiet *within* a room, which means it currently
offers **no signal for a room boundary at all.**

> ⚠ **Unset — and this is a real gap, not an oversight.** As a starting point for decision
> rather than a fixed answer: a consistent doorway or threshold silhouette, distinct from both
> the airlock's contour-break aperture (§3.4) and from ordinary wall geometry, marking chamber
> transitions — so a player can tell "I am leaving this puzzle" from "I am still inside it"
> without relying on memory of the room's layout. **Owner: art-director, with whoever authors
> the multi-room MVP level**, since a threshold treatment only earns its shape once there is a
> real room boundary to test it against.

### 6.5 Background vs. Foreground Separation

No parallax or background-depth system is wired into any level scene today.
`src/assets/Simple-Platformer-Asset-Pack/`'s background PNGs exist as unused placeholder files,
not instanced content, and §8.7's texture budget reserves headroom for background and parallax
layers without any layer count or behaviour having been decided.

This section sets the principle, not the numbers. Background layers should read as **more
receded** than midground terrain along the axis §4.2 already uses for depletion: lower
contrast, cooler and greyer, closer to Structural Grey or Void Black than anything in the
traversable layer. Depth then reads through the same "saturated equals present, grey and dark
equals recede" grammar the player is already learning from oxygen depletion and spent buckets,
instead of introducing a second, unrelated depth language. Blur in particular is ruled out — a
flat nearest-filter pixel pipeline should not use it (§8.5).

> ⚠ **Unset.** Layer count, parallax scroll ratio, and whether background art is authored
> per-room or shared across rooms are all open. These are technical-artist decisions gated on
> the draw-call budget (§8.9's TileMapLayer-first policy) and the 500-call ceiling in
> `technical-preferences.md`. This section fixes only that whatever depth cueing is chosen must
> stay inside the existing depletion grammar rather than invent a new visual language for "far
> away."

### 6.6 Pre-Commitment Gravity Telegraphing

The chevron (§6.3) is the primary telegraph, legible before the player enters a zone, per
§3.3's "before they commit to entering" framing.

This section adds one reinforcing layer available only to the environment: **the terrain beyond
a zone should already be authored with the same safe-terrain grammar (§6.1) that reads as
"floor" everywhere else.** A player who enters a zone without registering the chevron then gets
passive confirmation the instant the room stops rotating — the surface they land on already
looks like ground they have learned to trust, not like an ambiguous or unfinished wall. This is
not a new asset category. It is a constraint on how zone-adjacent chambers get dressed, and it
requires only that §6.1's grammar be applied on *both* sides of every zone, including the side
that starts out oriented as a wall or ceiling.

**No additional VFX on the zone itself.** An animated glow, pulse, or particle emitter would
compete with the clean-silhouette-at-rest baseline §2.1 and §3.2 both require, and would read
as a second, decorative proof of the flip sitting alongside the camera and sprite rotation
§1.3 already established as sufficient.

### 6.7 Environmental VFX

Folded from the template's standalone VFX Standards section. Three items, all decided
elsewhere, gathered here as a single environmental-VFX reference rather than re-litigated.

- **Oxygen-critical Light2D pulse.** §2.4 flags a slow pulse at the 10% threshold as a
  *candidate enhancement*, explicitly not a dependency: "the palette shift alone must carry the
  full mood on its own." Cost against the GL Compatibility budget is owed to technical-artist.
- **Gravity-flip transition.** §2.5 **forbids** any competing VFX layer — flash, particle
  burst, screen shake — during the 0.6 s flip. A hard rule, not an open question.
- **Physics-prop tumble.** Deferred past MVP per §1.3. When built at Vertical-Slice tier,
  `physics-props.md` R3/R4 already govern the physical behaviour and §3.4 already fixes prop
  shape priority as subordinate to route-relevant hero shapes. No new decision owed.

---

## 7. UI/HUD Visual Direction

This section governs how the HUD *looks* — type, iconography, framing, and the
diegetic-versus-abstract line. It does not decide placement, timing, trigger conditions, or
element cardinality. Those belong to `design/ux/hud.md`, and this section cites rather than
restates them. Where the two documents could appear to overlap, **`hud.md` is authoritative on
behaviour and this section is authoritative on appearance.**

### 7.1 Typography

The HUD carries very little text: E1's numerals (shown only at `oxygen_fraction <= 0.50`),
E2's single player-facing string plus the interact-key glyph, and E5/E8's
`buckets_consumed / buckets_total` tally. `hud.md` confirms E2's label is "the only
player-facing string in the game." This is a numerals-and-one-label problem, not a body-text
problem, and the type direction should reflect that scale.

**Recommended: a fixed-width, pixel-grid bitmap font**, sized to the 8/16/24 px UI canvas tiers
§8.3 already sets, rather than a proportional or hand-drawn display face. A monospace numeral
set keeps E1's threshold numerals and E5/E8's tally from re-flowing or kerning unevenly as
digit counts change (`buckets_total` varies per level), which matters more here than expressive
letterforms do given how little text exists. This matches §3.6's "restrained echo" — thin,
rectilinear, quiet — rather than a display face competing with world hero shapes.

Text size floors are **not re-decided here.** `accessibility-requirements.md` fixes ≥12 design
px for E1 numerals and E2's label, ≥15 design px for future menu text, both cited in `hud.md`.
Any typeface chosen must hit those floors at 1× and clear them cleanly at 2×, since the nearest
filter forbids any factor between.

### 7.2 Iconography Style

The only icon the HUD currently needs is E2's interact-key glyph (**E**).

**Recommended: a keycap motif built from §3.6's own vocabulary** — a thin rectilinear outline
stroke around the glyph, no rounded corners, no drop shadow or bevel — rather than either bare
text or a realistic beveled-keyboard skeuomorph. A bare glyph risks being missed at a glance. A
realistic keycap would be the one place the HUD borrows a soft, dimensional shape language
nothing else in the game uses. The thin-outline rectangle keeps the keycap legible as a control
hint while staying inside the stroke-weight budget §3.6 sets for every other HUD shape.

E4's capped-state marker is **not** a new icon. §3.5 already resolves
`accessibility-requirements.md` A4 by reusing the plant's own capped-stage bloom/pod silhouette
rather than inventing a bolted-on glyph. No icon design work is owed for E4.

Future icons — a settings iconset, once one exists — should extend this same
thin-rectilinear-outline family rather than introduce a second icon language.

### 7.3 Framing and Plate Treatment

`hud.md` already commits the mechanism: E1–E4 require a black outline or backing plate,
matching `debugger.gd`'s precedent (black `font_outline_color`, outline size 4), specifically
because the outline must be black rather than white — white drops the critical band to ~3.9:1
and fails AA, against ~5.4:1 on black. This section owns the visual character of that plate,
not its contrast math.

**Recommended: solid Void Black (`#000000`/`#010101`) backing at full or near-full opacity**
wherever gameplay-critical text renders, not a translucent panel. `hud.md`'s Z1 occlusion rule
already ruled out fading the backing plate for a directly analogous reason — "the plate is what
H22's contrast figures rest on, so reducing it trades a legibility problem for a legibility
problem" — and that reasoning applies identically to E2's label and E5/E8's tally, both of which
render over arbitrary terrain the same way E1 does. A translucent plate reintroduces exactly the
worst-case-background variability the "worst-case, not average" rule was written to eliminate.

**Plate geometry stays minimal:** a thin rectangle sized to its content, no corner ornaments, no
multi-layer frame, per §3.6's mandate that HUD shapes stay quieter than any world hero shape.
Rounded corners, drop shadows or gradient fills would violate §2.1's no-gradients rule and risk
the plate becoming a hero-weight shape competing with buckets and plants.

### 7.4 Diegetic vs. Abstract Stance

`hud.md`'s HUD Philosophy commits the *behaviour* — minimal, adaptive, diegetic, information in
the world rather than in a frame drawn around it. This section carries that stance into the
appearance of the one element that cannot be proximity-hidden. **E1, the always-visible oxygen
gauge, is the HUD's single largest art-direction opportunity**, because R7 forces it to exist
permanently and Principle 1 still asks that a permanent readout not feel like UI bolted onto
the world.

**Recommended: an analog-gauge motif** rather than a flat progress bar — a segmented or lightly
beveled bar treatment, consistent with the tick-mark content `hud.md` already requires at 0.50,
0.25 and 0.10 for colourblind safety. A gauge-like rendering reinforces `game-concept.md`'s
core fantasy — the last gardener aboard a derelict station, reading their own suit — over a
generic HUD-bar read, at effectively no cost beyond how the existing tick marks and fill are
drawn. This is direction for how to *render* content `hud.md` has already fully specified, not
a new content decision.

E2's prompt panel and E5/E8's tally stay in the flat, unornamented plate family (§7.3) rather
than adopting the gauge motif. They are momentary, world-attached confirmations, not the
player's one permanent readout, and giving them the same instrument treatment would dilute what
makes E1's motif mean anything.

**Future menus** should extend the same diegetic instinct — rectilinear panels, the same
monospace technical type family (§7.1), no rounded dialog boxes. §2.7 already commits to tone
continuity: the station's own status screen, not a separate warm menu aesthetic.

> ⚠ **Unset.** Full menu visual layout is undecided. No menu system exists in `src/` today, and
> `interaction-patterns.md` records that no button, focus, slider, toggle or key-capture pattern
> exists anywhere in the project. **Owner: ux-designer**, once a settings-screen UX spec exists
> for this section to art-direct against.

### 7.5 Legibility Against Arbitrary Terrain

`accessibility-requirements.md`'s E1 band contrast table and `hud.md`'s Accessibility section
already establish the numeric targets — ≥4.5:1 against the worst-case background, all four E1
bands clearing AA on black. This section does not restate or re-derive them.

What it owns is that the *method* is a visual-direction fact: black outline (never white, §7.3)
plus a solid backing plate is the entire mechanism, and **no additional treatment should be
layered on top** in an attempt to improve legibility further. A glow, halo or secondary colour
fringe would cost more to render against §8.8's shader budget and would blur the black
outline's crisp edge, which is what is doing the actual contrast work.

### 7.6 Element-Specific Visual Notes

| Element | Visual note | Layout/behaviour owner |
|---|---|---|
| E1 oxygen gauge | Analog-gauge motif (§7.4); solid black plate; monospace numerals appear only at or below 0.50 | `hud.md` Layout Zones (Z1), HUD Elements |
| E2 prompt / E3 pour fill | Thin-outline keycap glyph (§7.2) plus flat plate (§7.3). E3's fill drains back to zero on early release — a content fact `hud.md` owns, rendered as a simple fill-level change, with no separate failure colour or shake | `hud.md` HUD Elements |
| E4 pour refusal | No new visual — reuses §3.5's capped-plant bloom/pod silhouette | `hud.md` HUD Elements; §3.5 here |
| E5 / E8 tally | Flat plate family (§7.3), same monospace numerals as E1. Identical content, so identical rendering — no visual distinction between the pushed (E5) and pulled (E8) presentations beyond the trigger and duration differences `hud.md` specifies | `hud.md` HUD Elements |
| E6 death / E9 completion | Full-viewport, no text, both. §5.4 recommends the player sprite hold its last pose under E6 rather than receiving a dedicated death animation. `hud.md` requires the two be distinguishable in a single frame; this section adds only that if they share a hold-and-fade structure, they must still diverge in at least one immediately-readable property — colour direction, for instance, E6 cooling further against E9 briefly holding steady — so a win is never misread as a death for even one frame | `hud.md` HUD Elements, `level-flow.md` |
| E7 dev overlay | **Out of scope for this section.** `hud.md` states the dev overlay "has no player-facing contract — no accessibility tier, no localization, no art direction — and it is permitted to be dense and ugly." This document defers rather than contradicts | `hud.md` HUD Elements |

---

## 8. Asset Standards

> Grounded in `game-concept.md`'s Technical Considerations (2D pixel, NES-influenced) and
> `.claude/docs/technical-preferences.md` performance budgets. Authored before Sections 1–4
> existed, so it is not anchored to the Visual Identity Statement below. Sections 1–4 are now
> authored (2026-08-17) — this section has not yet been re-checked against them; flagged as an
> open item, not yet revisited.

### 8.1 File Formats

| Asset type | Format | Notes |
|---|---|---|
| Sprites (character, prop, plant) | PNG, 32-bit RGBA | Every asset in `src/assets/` already follows this. Never JPEG — lossy compression breaks hard pixel edges. |
| Tilesets | PNG, single sheet per set, imported as a Godot `TileSet` resource | One sheet per environment set, not one file per tile. |
| UI (icons, panels, HUD glyphs) | PNG, 32-bit RGBA | Resizable panels (dialogs, buttons) use 9-slice-ready PNG for `NinePatchRect`. Icons stay flat PNG. |
| Source working files | Native art-tool format (e.g. `.aseprite`), stored beside the exported PNG | Preserves layers/timing for re-export. Godot imports the exported PNG, not the source file. |

### 8.2 Naming Convention

`[category]_[name]_[variant]_[size].[ext]`. Categories: `char`, `env`, `ui`, `vfx`. This governs art asset filenames only — it does not conflict with the code naming convention in `.claude/docs/technical-preferences.md` (snake_case for `.gd`/scene classes).

Applies to new custom work and to placeholder assets **at the point they're replaced** — not retroactively across the `Simple-Platformer-Asset-Pack/` and `Industrial/` third-party packs, which are licensed external content on a path to replacement.

Retrofit examples from current assets:

| Current file | Renamed |
|---|---|
| `Wall_tile_temp_16x16.png` | `env_wall_default_16.png` |
| `GG-WaterJug.png` | `env_bucket_full_16.png` |
| `GG-Plant_v1.png` | `env_plant_default_16.png` |
| `GG-MainPlayer_Master_SpriteSheet_v1.png` | `char_player_spritesheet_master.png` |

### 8.3 Texture Resolution Tiers

Base source-art grid: **16×16 px**, displayed at **2× integer node scale** (32×32 px on-screen) — already the project's working convention (`Simple_tileset.tres`, `GG-Plant_v1.png`, `GG-WaterJug.png` all confirm this) and compatible with `accessibility-requirements.md`'s integer-only (1×/2×) scaling requirement.

| Category | Source grid | On-screen (2×) | Basis |
|---|---|---|---|
| Environment tiles | 16×16 px, grid-snapped | 32×32 px | Matches `Simple_tileset.tres` |
| Small props (bucket, cosmetic physics props) | 16×16 or 16×32 px | 32×32 or 32×64 px | Matches `GG-WaterJug.png`; multi-tile props snap to 16px multiples |
| Plants | 16×16 px/frame | 32×32 px | Matches `GG-Plant_v1.png` |
| **Player character** | **32×32 px — deliberate exception** | 64×64 px | One grid-step above the world tile, intentionally, to give gravity-flip pose states (idle/run/jump/fall/carry/pour) enough silhouette room to stay legible per Pillar 1. Not an artifact of mixed placeholder packs. |
| UI icons / HUD glyphs | 8, 16, or 24 px canvas | Per accessibility doc's px minimums | Sized by legibility, not tile alignment. Hard floors already fixed: HUD-critical text ≥12 design px, menu text ≥15 design px, 1×/2× only. |

**Action needed**: the Crouch pose currently borrows a 16×16 frame from the `Industrial` placeholder pack (`industrial.v2.png`) rather than the player's own 32×32 sheet. Re-author Crouch at 32×32 on the player's own sheet before adding the carry/pour poses the watering system requires — this closes the one place the player character currently violates its own tier.

### 8.4 LOD (Level of Detail)

Not applicable. No 3D meshes exist in this pipeline (`game-concept.md`: "no 3D pipeline"). Every asset has exactly one canonical source resolution per 8.3 — do not author low/high-detail sprite variants.

### 8.5 Export Settings Philosophy

- **Filtering: Nearest, always.** Already the project-wide default (`project.godot`: `default_texture_filter=0`). Keep the explicit per-node override on `Player` and `Bucket` as defensive redundancy, and add the same explicit override to `Plant/AnimatedSprite2D`, which currently relies on the project default only.
- **Mipmaps: off.** Sprites render near-native at fixed integer multiples — a mip chain adds import cost with no benefit and risks blurring if a mip level is ever sampled.
- **Compression: Lossless, not VRAM-compressed.** VRAM compression (S3TC/ETC-style) is block-based and visibly damages hard pixel edges. At this asset volume the memory saved isn't worth the visual cost — see 8.7 for why the budget doesn't need it either.
- **No pre-scaling before import.** Author and export at exact source size (8.3) or a clean integer multiple. Never let the importer downscale a non-16px-multiple source — defeats pixel-perfect authoring and can shimmer under Nearest filtering.
- **Color space: sRGB, no HDR.** Flat-shaded 2D pixel game — Godot 4.7's HDR output does not apply here.
- **Repeat mode**: Repeat only on scrolling/tiling backgrounds; Clamp on single-placement sprites.

### 8.6 Poly Count Budgets

Not applicable. 2D-only pipeline — no `MeshInstance3D`, no `Mesh` resources. All visible geometry is `Sprite2D`, `AnimatedSprite2D`, and `TileMapLayer` drawn from flat textures.

### 8.7 Texture Memory Limits

Total memory ceiling is 512 MB (`technical-preferences.md`), covering the whole running game, not textures alone. Proposed split — confirm against Godot's Debugger memory monitor once real assets exist:

| Category | Budget |
|---|---|
| Engine/runtime/audio/game objects | ~200 MB (unmeasured baseline) |
| Texture memory (VRAM-resident) | ≤ 250 MB |
| Safety margin | ~62 MB (12%) |

Per-category atlas ceilings within the 250 MB texture cap (worst case ~120–140 MB across all categories — comfortable headroom):

| Category | Atlas ceiling |
|---|---|
| Shared tileset atlases | 2048×2048, up to 5 |
| Player spritesheet | 512×512 |
| Prop atlas (shared, see 8.10) | 1024×1024 |
| VFX atlas | 1024×1024 |
| UI/HUD atlas | 1024×1024 |
| Background/parallax layers | 2048×2048, a handful |

### 8.8 Material Slot Constraints

Godot 2D has no 3D-style material-slot array — a `CanvasItem` carries one `material` or inherits its parent's. What actually matters:

1. **Distinct active shader count** — each unique `ShaderMaterial` visible in a frame breaks Godot's same-texture/same-material 2D batching. Proposed cap: ~8–10 distinct custom shaders visible at once (oxygen-critical `Light2D` pulse candidate — §2.4, water/plant highlight, UI transition, etc. **Not** a gravity-flip screen effect: §2.5 forbids any competing VFX layer during the flip) — a proposal, not yet confirmed against an actual VFX list.
2. **Shader complexity per material** — GL Compatibility is Godot's lean renderer; keep shaders simple (minimal samples, no per-pixel loops/heavy branching). Flag separately if dynamic `Light2D` nodes get used — Compatibility costs more per additional 2D light than Forward+.

### 8.9 Importer & Draw Call Notes

- Configure Nearest filter / no mipmaps / Lossless as the **project-default import preset**, not a per-file toggle — one missed toggle is a visible blur bug.
- Import each tileset/sprite family as one sheet, referenced via `TileSet` regions or `AtlasTexture` — not one PNG per tile.
- Use `TileMapLayer` for level geometry, not individual `Sprite2D` nodes — the single biggest lever against the <500 draw call budget.
- Share one atlas per asset category so separately-instanced nodes still batch.
- Avoid mid-layer `z_index`/light-mask changes between otherwise-identical sprites — breaks batching.

### 8.10 Physics Prop Asset Budget

Connects directly to ADR-0011 (Accepted), which fixed script-cost at rest but explicitly left solver cost unmitigated: *"40 bodies waking in one substep spike the frame beyond 16.6ms — through solver cost, not script cost."* Three asset-side levers, none currently owned by an ADR:

1. **One shared prop atlas**, not one texture per prop. `physics-props.md` budgets 40 props/level (range 10–80), and ADR-0011 already counts these against the 500-call budget. A shared atlas lets the full prop set batch toward a handful of draw calls instead of spending up to 40.
2. **Simple collision shapes only.** Cap prop `CollisionShape2D` to primitives (rectangle/capsule); forbid `CollisionPolygon2D` over ~8 vertices. Solver cost scales with shape complexity — this is the one lever over the "40 bodies wake at once" risk that lives in asset authoring, not script. Recorded here as an **advisory standard in the art bible only** — not (yet) binding via ADR.
3. **No per-prop wake VFX.** `physics-props.md` R1 already makes props purely cosmetic. Extend that to the pipeline: no particle trail/glow/dust-puff triggered per prop on wake — would multiply cost at exactly the moment (a gravity flip, all props waking together) ADR-0011's own flagged risk is most likely to bite.

Clarification: `technical-preferences.md` lists "Physics: Jolt Physics," but ADR-0011's Engine Compatibility table confirms Jolt is 3D-only and inert here — prop collision runs on Godot's built-in 2D physics. Nothing in this section depends on Jolt.

---

## 9. Reference Direction

The palette source (`docs/Pallete/nes-aesprite-1x.png`) already anchors colour as a
project-wide constraint (§4.1). This section names the touchstones that inform everything else
— shape, mood, mechanic presentation — and is explicit about what each one is *not* lending the
project, since an unstated boundary on a reference is how style drift happens.

| Reference | Medium | What we take | What we explicitly do not take |
|---|---|---|---|
| **NES-era 8-bit platformer silhouette design** (as a class — Mega Man, Metroid; not a single title) | Games, mid-1980s hardware generation | The whole shape vocabulary in §3: blocky, low-internal-detail character silhouettes that read at small on-screen scale; flat, orthogonal, engineered-not-grown architecture (§3.2); hard palette-band shading with no gradients (§2.1). `gravity.md` §2 already names this target directly — "Jump feel targets the Super Mario Bros. (NES) curve" | The actual hardware constraint — per-sprite three-colour limits, tile-attribute colour clashing. We use a curated 56-entry palette on modern hardware. Nothing here is reproduced *because* the NES could only do it; it is reproduced because the resulting grammar serves Pillar 1's silhouette-first legibility need |
| **VVVVVV** (Terry Cavanagh, 2010) | Game | The only reference already recorded in `game-concept.md`'s Inspiration and References — flagged there as TBD and not user-validated, a caveat this section inherits rather than overrides. Structural precedent: gravity flip as the core traversal verb, minimal geometry, bold flat colour with no gradients | VVVVVV's flip is an **instant, un-eased snap** — no camera tween, no sprite rotation. This project's flip is deliberately eased over 0.6 s (`gravity.md` R3, §2.5), partly a feel choice and partly because `accessibility-requirements.md` elevates reduced motion specifically because viewport rotation is a vestibular trigger, a concern an instant cut does not carry the same way. We also do not take VVVVVV's single-screen, non-scrolling room structure — this game's MVP is multi-room with camera follow in some levels (§6.4) |
| **Metroid / Super Metroid** (Nintendo, 1986/1994) | Games | Mood and atmosphere only, not shape: a solitary explorer on a hostile abandoned structure; functional rather than decorative environment art; sparse deliberate colour supporting isolation over spectacle. Matches §2's watchful, cold, functional mood target and the derelict-station premise | Metroid's combat-and-ability-gated progression — enemies, weapon upgrades, sequence-breaking backtracking. `game-concept.md`'s Anti-Pillars explicitly rule out a combat game, and this project has no ability gating. We also do not take its heavily-shadowed dynamic lighting; §2.1 commits to flat palette bands with no dynamic light |

**Deliberately positioned against**, for contrast rather than as borrowed reference:

- **High-colour-count painterly pixel art** (the Owlboy / Dead Cells register). Ruled out
  structurally by the fixed 56-entry palette and flat-band shading, not as a matter of taste.
- **Retro-nostalgia signalling** — CRT scanline shaders, chromatic aberration, forced low
  resolution beyond the actual asset grid. Nothing in §§2–4 asks the game to *look* like it is
  running on period hardware, only for its shape and colour grammar to descend from that
  period's design constraints. The NES influence is a design-language source, not a filter.

> ⚠ **Not user-validated.** None of the three rows above has been confirmed as a marketing or
> positioning claim. `game-concept.md`'s own Inspiration and References section carries the same
> flag on its single entry, for the same reason: no comparable-titles list has been confirmed by
> the user. Treat this table as reference direction for internal art decisions, not as
> external-facing pitch material, until reviewed.

---

> **Art Director Sign-Off (AD-ART-BIBLE)**: Skipped — Lean review mode (`production/review-mode.txt`), not a PHASE-GATE outside `full` mode. **All nine sections are authored as of 2026-08-18.** Ten items remain flagged ⚠ unset with named owners; none blocks the pre-production gate, but §6.3 (gravity-zone fill colour) and §6.4 (room-boundary treatment) block asset production and should be closed before `/asset-spec` runs.
