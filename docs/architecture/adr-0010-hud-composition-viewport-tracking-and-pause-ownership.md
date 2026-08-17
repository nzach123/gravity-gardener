# ADR-0010: HUD Composition, Viewport Tracking, and Pause Ownership

## Status

Accepted

## Date

2026-08-16 (Proposed) · 2026-08-16 (Accepted)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | UI |
| **Knowledge Risk** | MEDIUM — the pinned 4.7.1 is post-LLM-cutoff, and this is the only UI-domain ADR in the project |
| **References Consulted** | `docs/engine-reference/godot/modules/ui-control.md` · `docs/engine-reference/godot/modules/core.md` § *Pause and process modes* · `docs/engine-reference/godot/breaking-changes.md` § *Control / UI* · `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Control.offset_transform_*` (new in 4.7). Used for Z1/Z2 displacement only, never for rotation |
| **Verification Required** | **V-E2 only.** Confirm by test that `get_global_transform_with_canvas().origin` yields correct viewport-space pixels under *simultaneous* camera rotation and non-default zoom. V1 and V2 are that test. Every other engine claim was resolved at review — see below |

**Engine gate result (godot-specialist, 2026-08-16): 1 BLOCKING finding, since fixed. 7 of 9 claims CONFIRMED.**

| Claim | Verdict |
|---|---|
| **V-E1** — `PROCESS_MODE_WHEN_PAUSED` processes *only* while paused, so E7 needs `ALWAYS` | **CONFIRMED.** Semantics stable 4.0 → 4.7.1. This confirms `tr-registry.yaml:576` is wrong — see D10.6 |
| **V-E2** — the world-to-viewport projection formula | **Unconfirmable under rotation + zoom.** Resolved by switching to the class-documented `get_global_transform_with_canvas()`, and by V1/V2 testing it empirically. The one claim still owed |
| **V-E3** — `OS.has_feature("debug")` is false in a release export; runtime `InputMap.add_action()` satisfies H5 | **CONFIRMED**, with a re-registration gotcha now handled in D10.8 |
| **V-E4** — a `CanvasLayer` descendant ignores the `Camera2D` transform including rotation | **CONFIRMED.** This is the documented mechanism for screen-fixed UI |
| **V-E5** — `offset_transform_position` is additive and survives a per-frame `position` write; `offset_transform_enabled` defaults false; `offset_transform_visual_only` defaults true | **CONFIRMED.** But the in-project precedent sets it once, not per frame — V11 closes that gap |
| **V-E6** — `PROCESS_MODE_INHERIT` resolves chain-wide, so an ancestor silently changes descendants | **CONFIRMED.** Drives D10.6's leaf-nodes-only rule |
| **V-E7** — `CanvasLayer.layer` ordering, and whether nesting `CanvasLayer` is sane | **PARTIALLY REFUTED — this was the BLOCKING finding.** Sibling layers are supported; *nested* layers have open issues where declared order is not honoured. D10.1 was rewritten to a plain `Node` root with four siblings |
| **V-E8** — avoiding `RichTextLabel` avoids the 4.7 `add_image()` break | **CONFIRMED.** No other common HUD node changed 4.4 → 4.7 |
| **V-E9** — `_process` reads post-physics values | **CONFIRMED.** Idle and physics frames are not 1:1, but an idle frame with no physics step still reads the last stepped value, so the claim holds |

**Two authoring rules this ADR inherits and does not itself trigger.** `RichTextLabel.add_image()` / `update_image()` changed signature in 4.7 (GH-112617): sizes are `float`, and `width_in_percent` / `height_in_percent` became `width_unit` / `height_unit` taking `RichTextLabel.ImageUnit`. `breaking-changes.md` names `hud.md` as the active work most likely to hit this. **No element in this ADR uses `RichTextLabel`** — E2's key glyph is a `TextureRect`, so the hazard is avoided rather than managed. Second, `Control.accessibility_live` moved from `DisplayServer.AccessibilityLiveMode` to `AccessibilityServer.AccessibilityLiveMode` (GH-116839). GDScript call sites are unaffected. This ADR sets no accessibility metadata, because `ui-control.md` records the AccessKit integration as experimental with incomplete coverage, and `accessibility-requirements.md` places screen reader support out of tier.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (injection contract), ADR-0003 (`V-WIRING`), ADR-0005 (frame ordering), ADR-0006 (tuning strategy), ADR-0008 (oxygen, pause mechanism) — all Accepted |
| **Enables** | None. This is the last ADR in the planned set |
| **Blocks** | The level migration epic. It cannot close until all 8 levels wire a HUD and `validate()` returns empty |
| **Ordering Note** | Acceptance moves the `hud` row of ADR-0003 D3.3's required-consumer table from **No** to **Yes**. That is a one-line change to ADR-0003 with an eight-level authoring consequence — see *Migration Plan* |

## Context

### Problem Statement

`design/ux/hud.md` specifies the HUD completely as user experience — 8 elements, 4 zones, a two-element visual budget, a single-slot arbitration rule, and 30 acceptance criteria of which 19 are BLOCKING. Nothing in `src/` implements any of it. There is no HUD scene, no HUD script, and no level wires one.

Four requirements have waited on this decision since the traceability registry was written: **TR-oxygen-007** (readout always visible), **TR-oxygen-009** (threshold feedback at 50 / 25 / 10 percent), **TR-watering-017** (the HUD reads `carrying_bucket` as a prompt precondition) and **TR-watering-018** (a fully grown plant shows a positive refusal marker). All four sit at `status: gap`, `adr_status: not_written`.

Two Accepted ADRs also name this one by name and are waiting on it. ADR-0003 D3.3 holds the `hud` consumer at "not required" **only** because ADR-0010 is unwritten, and records that scoping as "an obligation on ADR-0010, recorded here so its author inherits it rather than discovers it." ADR-0008 names ADR-0010 as owner of the pause toggle, which leaves `accessibility-requirements.md` T9 unrunnable.

The decision needed now is structural, not visual: what the HUD *is* as a node graph, how it obtains the state it reads, how it holds viewport-upright while the camera rotates, where its tuning values live, and who owns `SceneTree.paused`.

### Constraints

- **The camera rotates in 2 of 8 levels.** `level_01` and `level_07` tween camera `rotation` to the gravity basis over 0.6 s. `hud.md` requires every element hold **rotation zero relative to the viewport** in both camera modes.
- **Elements track world objects but render in viewport space.** Z1 follows the player, Z2 follows a plant. Neither may inherit the camera's rotation, and the Z1 offset is in viewport pixels so it must not scale with camera zoom.
- **ADR-0002 injects state bottom-up.** `_ready()` runs children first, so the HUD is ready before `LevelState` and `OxygenState` exist. Every injected consumer must refuse to operate before `bind()` and `push_error()`.
- **ADR-0006 D6.1 fixed the tuning set at three resources**, one per GDD. The HUD is not a GDD and has no resource in that set. D6.3 makes the `Tuning` const holder the only place a `.tres` path may appear.
- **Two of the elements' input actions do not exist.** The input map holds `move_left`, `move_right`, `jump`, `interact`, `crouch` only.
- **`hud.md` H19 requires the HUD be strictly read-only** against `OxygenState`, `LevelState`, `Plant` and `PlayerWateringComponent`.
- **ADR-0012 D12.5 grants no pause exemption.** The spent-jug arc freezes with the game, so whatever this ADR decides about pause must not carve out an exception it relies on.

### Requirements

- Must satisfy `suit-oxygen.md` R7 — the oxygen readout is always visible — in both camera modes.
- Must render no more than two player-facing elements at once, in every state of `hud.md`'s density profile.
- Must hold E1 within 0.1 s of `oxygen_remaining` at `drain_rate = 1.0` (H20 / AC9).
- Must display `oxygen_remaining / drain_rate`, the *composed* value, not the resource value (H15, and `hud.md` Accessibility Finding 2).
- Must let a designer change the 10 layout knobs without editing code.
- Must halt oxygen drain on pause without any bespoke pause-check code, preserving ADR-0008's structural guarantee.
- Must leave no HUD element able to write to game state.

## Decision

### D10.1 — The HUD is one scene: a plain `Node` coordinator over four sibling `CanvasLayer` zones

`src/scenes/hud.tscn`, script `src/scripts/hud.gd`, `class_name HUD extends Node`. The root is a **plain `Node`**. Its four children are **sibling `CanvasLayer` nodes**, one per zone, and every element is a `Control` descendant of its zone's layer. Levels wire the root through the `@export var hud` that ADR-0002 part 3 already adds to `LevelRoot`.

**A `CanvasLayer` is what makes the zones viewport-upright, because a `CanvasLayer` does not observe the `Camera2D` transform at all** — the engine documents this as the mechanism for keeping UI screen-fixed while the 2D view changes. This is the whole reason the HUD holds upright while the camera tweens through 0.6 s of rotation in `level_01` and `level_07`. The alternative — `Node2D` elements in world space, counter-rotated each frame by the negative camera angle — produces the same picture by cancelling a rotation it first inherited, and every frame in which the cancellation is one step stale shows a visibly tilted gauge. **`hud.md` H1 is then satisfied structurally rather than by arithmetic**, which is the distinction `architecture.md` P2 asks for.

**The root is deliberately NOT a `CanvasLayer`, and this is a correction made at engine review.** The first draft put a `CanvasLayer` at the root and the four zones inside it, which nests `CanvasLayer` under `CanvasLayer`. That is not the documented arrangement — the engine's own material describes zone layers as *siblings* — and nested layers have open, unresolved issues in which the declared `layer` order is not honoured (godotengine/godot#25384, #22687). The ordering below is load-bearing for a written requirement, so it must not rest on undefined behaviour. A plain `Node` root holds four siblings and nests nothing.

**Layer ordering is by `CanvasLayer.layer`, matching `hud.md`'s bottom-to-top stack:** Z4 debug overlay `layer = 1`, Z2 world-tracked prompts `layer = 2`, Z1 player-tracked readout `layer = 3`, Z3 transient and death `layer = 4`. Z4 sits *below* everything player-facing, which is how `hud.md`'s "the overlay must not obscure any player-facing element" is enforced — by layer, because Z1 roams the screen and no fixed corner can guarantee separation by position.

**An explicit `layer` integer is chosen over tree order for the same reason.** Ordinary `Control` siblings under one layer would order by position in the scene tree, which anyone can change by dragging a node in the editor, silently and with no error. A `layer` number is declarative and survives a reordering. Enforcing the rule structurally rather than by discipline is `architecture.md` P2 again.

**`follow_viewport_enabled` stays `false` on all four layers, its engine default, and `follow_viewport_scale` stays `1.0`.** Stated because the property exists precisely to make a `CanvasLayer` track the viewport transform, which is the one thing these layers must not do. Enabling either would silently break D10.2's viewport-pixel projection, and the symptom would be a drifting gauge rather than an error.

One scene, not seven. There is exactly one HUD per level, its elements share the state references and the arbitration rules that decide which of them renders, and splitting them into separately-instanced scenes would distribute one arbitration decision across seven nodes.

### D10.2 — World tracking is a per-frame projection into canvas space, offset along gravity-up

Z1 and Z2 compute their `position` each frame in `_process`:

```gdscript
var screen_pos: Vector2 = tracked.get_global_transform_with_canvas().origin
```

**`get_global_transform_with_canvas()` is specified rather than `get_viewport().get_canvas_transform() * tracked.global_position`.** The two are equivalent for a bare position, because `global_position` already bakes in every ancestor transform. The engine review could not confirm the multiply form under simultaneous camera rotation and non-default zoom, and `get_global_transform_with_canvas()` is the class-documented API for exactly this question — where does this `CanvasItem` currently sit in canvas space. Preferring the documented call over an equivalent-looking formula costs nothing and removes the one claim the review would not sign off. V1 and V2 test the result empirically under a live camera tween regardless of which form ships.

Rotation is **never assigned** on any HUD `Control`. The zero-rotation guarantee comes from D10.1's `CanvasLayer`, and a HUD that never writes `rotation` cannot break it.

**The offset is applied after projection, in viewport pixels**, which is what makes it independent of camera zoom as `hud.md` Z1 requires. Both zones offset along **eased gravity-up**:

```gdscript
position = screen_pos + GravityAuthority.up_dir * z1_offset
```

`up_dir` is read from `GravityAuthority`, which ADR-0007 D7.4 establishes as its owner. The HUD **reads** it and never caches it in a surviving field, which keeps it clear of ADR-0007 D7.1 and of the registry's `private_gravity_copy` ban — both of those forbid *storing* a gravity value, not reading one.

**Z2 offsets along `up_dir` too. This closes `hud.md` Q17**, which was the last open question blocking this ADR. One rule governs both zones, it adds no knob and no authored per-object field, and it is what the `hud.md` correction of 2026-08-16 records. The more precise alternative — a per-object anchor direction keyed to the mounting surface — was declined while no level instances a plant, and it remains additive if a level ever needs it.

**Displacement under the Z1/Z2 collision rule uses `Control.offset_transform_position`**, the 4.7 feature, not a write to `position`. `position` carries the tracked object's projection and is recomputed every frame from the world; overwriting it with a collision-avoidance value would mean the next frame's projection discards the displacement. `offset_transform_*` is an additive visual layer that survives exactly this.

**The in-project precedent is weaker than it looks, and is recorded as supporting rather than proving.** `gravity_zone.gd:41-42` writes `position` and `offset_transform_position` in the same block, which does show the two properties coexist on one `Control`. It writes them **once**, in setup, not every frame. **No shipped code in this project co-writes them per frame**, which is what D10.2 proposes. V11 exists to close that gap by test rather than by analogy.

Two properties must be set in the `.tscn`, not at runtime:

- **`offset_transform_enabled = true`** — every other `offset_transform_*` property is inert without it. `ui-control.md` requires it be set in the scene so the dependency is visible rather than buried in a script.
- **`offset_transform_visual_only`** stays at its `true` default. It means hit-testing uses the un-offset rect, which is **harmless here and not a compromise**: no player-facing HUD element is interactive, so there is no hit-test to be wrong.

### D10.3 — Tuning knobs are `@export` on the HUD scene's nodes (closes Q16)

All 10 knobs from `hud.md` § *Tuning Knobs* are `@export` variables on `hud.gd`, edited in the inspector on the single `hud.tscn`.

**No fourth `HudTuning` resource, and no ADR-0006 amendment.** ADR-0006 D6.1 sized the tuning set at three resources deliberately, one per GDD. Adding a fourth to hold layout values would extend a frozen decision for a document that is not a GDD.

**The `.tres` route is not being refused on convenience.** `.claude/docs/coding-standards.md` requires *gameplay* values be data-driven. Every knob here is a viewport-pixel layout measurement or an animation duration — `z1_offset`, `z2_displacement`, `hud_edge_margin`, `prompt_fade_duration` — and none of them changes what the game does, only where it draws. The two knobs that could look like gameplay values are not: `tally_duration` and `death_hold_duration` are presentation timings whose bounds `hud.md` derives from `water_duration`'s 2.0 s floor and from the restart loop, and neither is read by any system outside the HUD.

**The Plant precedent applies directly.** `watering-system.md` §7 already authorises per-instance `@export` for `water_duration` and `buckets_required`. There is exactly one HUD scene, so per-instance equals global here, which is the property that makes the precedent transfer.

**What this gives up**, stated plainly: the values live in a `.tscn` rather than a `.tres`, so they cannot be swapped as a set, and a future second HUD scene would duplicate them rather than share them. Neither is a live concern, and both are recoverable by promoting to a resource later without changing any call site.

### D10.4 — The HUD holds direct references and is read-only by test

`bind(level_state: LevelState, oxygen_state: OxygenState) -> void`, called by `LevelRoot._ready()` exactly as ADR-0002's `level_state_injection` contract specifies. The HUD stores both references directly.

**No read-only facade.** `OxygenState` is already write-proof by construction — the registry guarantees "remaining never increases by any path; no setter, no reset" — so a wrapper would add nothing over it. `LevelState`'s two mutators, `mark_complete()` and `consume_bucket()`, already name their only legal callers in accepted contracts, so a HUD call site would violate an existing stance and not merely a new one. A facade would forward every accessor of both classes for the benefit of one consumer.

**H19 is therefore enforced by test, and the ADR says so rather than implying structure it does not have.** The test asserts no HUD script contains a call to any mutator on the four named types. This is weaker than structural enforcement and is accepted as such.

**Pre-`bind()` refusal.** `hud.gd` holds **`is_bound: bool`**, public and read-only from outside, set true by `bind()`. Every read path checks it, and the first unbound draw calls `push_error()` once. The name is `is_bound` everywhere — prose, interface, and test — because a private `_bound` with a public `is_bound` accessor would be two names for one fact. E1 renders the same error appearance it uses for `oxygen_capacity <= 0` — one appearance rather than two, because the player-facing meaning is identical and the two causes are distinguished in the log. This matches the `hud.md` § E1 *Pre-injection state* text added 2026-08-16.

### D10.5 — Update model: E1 polls, everything else is signal-driven

Transcribed from `hud.md`'s own per-element Update fields rather than chosen here:

| Element | Update | Mechanism |
|---|---|---|
| E1 gauge | Real-time, per frame | `_process` reads `OxygenState` |
| E2 / E4 | Event-driven | `InteractArea2D` `body_entered` / `body_exited`, plus capacity change |
| E3 fill | Real-time while held | `_process` reads `water_progress` |
| E5 tally | On `buckets_consumed` advance | Signal from `LevelState` |
| E8 tally | Live while held | `_process` while the query action is down |
| E7 overlay | Per frame while visible | `_process` |

**The HUD reads in `_process`, not `_physics_process`, so it takes no row in ADR-0005's frame-ordering table.** That is deliberate and worth stating, because its absence from that table would otherwise read as an omission. Idle processing runs after the physics step, so E1 always reads a post-drain value and can never render a figure from before `OxygenDrain` ran in the same frame.

**E1 displays `oxygen_remaining / drain_rate`** — the composed accessibility value from `OxygenAccessibility`, not `OxygenTuning.drain_rate`. This is `hud.md` Accessibility Finding 2 and H15, and it is the dependency ADR-0008 was told to expect. At the default multiplier of 1.0 the two are identical, so this changes nothing today and is correct the moment the accessibility hook is used.

### D10.6 — `PauseController` owns `SceneTree.paused`; only E7 is exempt

A `PauseController` node on `hud.tscn` owns the toggle:

```gdscript
get_tree().paused = not get_tree().paused
```

It renders no menu. **No pause menu exists and this ADR does not design one** — it owns the state that a future menu will drive, because ADR-0008 assigned that ownership here and because the toggle alone unblocks a test that has been blocked on it.

**Process-mode policy, and it is a policy about exactly one node:**

| Node | `process_mode` | Effect |
|---|---|---|
| `HUD` root, the Z1/Z2/Z3 layers, and every player-facing element | `INHERIT` (default, untouched) | Resolves to `PAUSABLE`. The HUD freezes on pause, holding its last values, which is precisely what `hud.md` § *Paused state* requires — nothing hides, nothing dims |
| E7 diagnostic overlay | **`PROCESS_MODE_ALWAYS`** | Keeps updating while paused *and* while running |
| `PauseController` | `PROCESS_MODE_ALWAYS` | It must be able to unpause |

**E7 needs `ALWAYS`, not `WHEN_PAUSED`, and this corrects a note in an existing registry.** `tr-registry.yaml`'s TR-oxygen-006 entry states that ADR-0010 owns "exempting its own Controls with `PROCESS_MODE_WHEN_PAUSED`." Applied literally that is wrong twice over: `WHEN_PAUSED` processes *only* while the tree is paused, so an E7 set to it would go dark during normal play — the opposite of a developer tool — and the player-facing Controls need no exemption at all, because freezing is what `hud.md` asks of them. The correction is recorded here so the next reader of that note does not implement it. It is owed to the registry at acceptance.

**A hazard this ADR must not walk into.** `core.md` records that `PROCESS_MODE_INHERIT` resolves *chain-wide*: any ancestor with a non-`INHERIT` mode silently changes what every `INHERIT` descendant resolves to, with no compile error and no symptom until the tree is actually paused. The exemptions above are therefore set on **leaf nodes only**. Setting `ALWAYS` on the `HUD` root would keep the entire player-facing HUD live through a pause and break `hud.md` H14, and nothing would report it.

**Pausing stops processing, not rendering.** A `PAUSABLE` node stops receiving `_process` while the tree is paused and keeps drawing its last state. That is exactly `hud.md`'s requirement that E1 stay "fully visible, holding its last value" — and because ADR-0008 halts the drain in the same instant, the held value is not stale, it is correct. The freeze needs no code at all: it is the default behaviour of nodes nobody exempted.

**ADR-0008's guarantee is preserved untouched.** `OxygenDrain` keeps its default `INHERIT`, so `SceneTree.paused` halts the drain with no pause-check code anywhere — the structural property ADR-0008 was accepted on. ADR-0012 D12.5's spent-jug arc likewise keeps `PAUSABLE` and freezes with the game. **This ADR claims no pause exemption for any element ADR-0012 depends on.**

### D10.7 — E8 suppresses Z2 while held, and is refused during a pour (closes Q18)

E8 is **screen-anchored in Z3**, at a fixed viewport position rather than tracking a world object. It has no world anchor to track, and an on-demand element that the player deliberately invokes benefits from a learned fixed location in a way that a proximity-triggered one does not.

Arbitration, evaluated in this order:

1. **`interact` is held — a pour is active.** E8 does not appear. The query key is ignored.
2. **Otherwise, E8 is held.** E8 renders and the Z2 element, if any, is suppressed for the duration of the hold.
3. **On release.** Z2 resolves normally and reappears if its trigger still holds.

**Rule 2 mirrors the E5-suppresses-E4 precedent** that `hud.md` § *Density profile* already establishes, so the two-element budget stays literally true rather than being waived for the newest element.

**Rule 1 is forced, not chosen.** E3 lives *inside* E2, so suppressing E2 during a pour would hide the fill of an active pour. `hud.md` states this constraint for E5 in terms this ADR simply inherits: a tally must never suppress E2, because the fill is the visible proof of the no-partial-credit rule. Refusing the query is the smaller cost — the player is mid-pour for at least 2.0 s and can ask immediately afterwards.

### D10.8 — E7 and its input action are created at runtime, only in debug builds (closes Q14)

E7 is **not present in `hud.tscn`**. `hud.gd` instances it in `_ready()` behind a build check, and registers its input action in the same branch:

```gdscript
if OS.has_feature("debug") and not InputMap.has_action("debug_overlay_toggle"):
    InputMap.add_action("debug_overlay_toggle")
    # bind F3, instance the overlay under the Z4 layer
```

**The `has_action` guard is required, not defensive.** `InputMap` is global and survives a scene change, while `hud.gd._ready()` runs once per level load. Without the guard, every level after the first re-registers an action that already exists and logs an engine error each time. It is not a crash and not a GDScript warning, so **gdUnit4's warnings-as-errors gate would not catch it** — it would simply accumulate as console noise across an 8-level run.

**Both halves are required by `hud.md` H5**, which demands that a release export contain no E7 *and* that no input action be registered for it. An action authored in `project.godot` ships in every export and cannot be conditionally removed at build time, so the action is added at runtime instead. This is the only mechanism that satisfies H5 as written.

**The player-facing query action for E8 is the opposite case** — it is authored in `project.godot` normally, because it ships in every build.

**Two input actions are now owed to `project.godot`:** the E8 progress query (player-facing, authored) and the E7 toggle (debug-only, runtime-registered). `interaction-patterns.md` O3 tracks a possible third, owed to ADR-0009's pour-toggle alternative, which this ADR does not own.

### D10.9 — `hud` becomes a required consumer on acceptance

ADR-0003 D3.3's required-consumer table gains its third **Yes**:

| Export | Consumer | Owning ADR | Required |
|---|---|---|---|
| `hud` | `HUD` | **ADR-0010 (Accepted)** | **Yes** |

`V-WIRING` then fails any level whose `hud` export is empty or unresolved. **All 8 levels must author and wire a HUD before `validate()` returns empty**, and ADR-0003's own close condition — Migration Plan step 6, Validation Criterion 5 — depends on that. No new validation code is needed; the rule already exists and this ADR only moves a row.

### Architecture Diagram

```
LevelRoot  (_ready, top-down after children are ready)
   │
   ├── bind(level_state, oxygen_state) ─────► HUD   [plain Node — NOT a CanvasLayer]
   │                                           │
   │        ┌──────────────────────────────────┴─── four SIBLING CanvasLayers,
   │        │                                       nothing nested
   │        ├── Z3 Transient      [CanvasLayer, layer 4]  E5 tally, E6 death, E8
   │        ├── Z1 Player-tracked [CanvasLayer, layer 3]  E1 gauge
   │        ├── Z2 World-tracked  [CanvasLayer, layer 2]  E2/E3 prompt+fill, E4
   │        ├── Z4 Debug          [CanvasLayer, layer 1]  E7  [debug only, ALWAYS]
   │        └── PauseController   [Node, ALWAYS]  owns get_tree().paused
   │
   │        all four layers: follow_viewport_enabled = false  (engine default)
   │
   └── OxygenDrain (child, INHERIT → PAUSABLE, drain halts on pause)

per frame, _process:
   screen   = tracked.get_global_transform_with_canvas().origin
   position = screen + GravityAuthority.up_dir * offset
   rotation = NEVER ASSIGNED  (the CanvasLayer already ignores the camera)
   collision displacement → offset_transform_position  (additive, survives reprojection)
```

### Key Interfaces

```gdscript
class_name HUD extends Node
## Root is a plain Node. Its four zone children are sibling CanvasLayers (D10.1).

## Injected by LevelRoot._ready(). Must be called before any read path runs.
func bind(level_state: LevelState, oxygen_state: OxygenState) -> void

## True once bind() has run. Every read path checks it. One name, no private twin.
var is_bound: bool

# Layout knobs — @export, per D10.3. Ten total, defaults from hud.md § Tuning Knobs.
@export var z1_offset: float = 24.0
@export var z1_max_footprint: Vector2 = Vector2(96, 24)
@export var z2_offset: float = 24.0
@export var z2_displacement: float = 48.0
@export var z2_release_hysteresis: float = 8.0
@export var hud_edge_margin: float = 16.0
@export var tally_duration: float = 1.2
@export var death_hold_duration: float = 0.35
@export var prompt_fade_duration: float = 0.15
@export var hud_outline_size: int = 4
```

```gdscript
class_name PauseController extends Node
## process_mode = PROCESS_MODE_ALWAYS
func toggle_pause() -> void
func set_paused(value: bool) -> void
var is_paused: bool
```

**No signal is added to any existing class.** The HUD subscribes to signals that already exist and defines none of its own, which is what keeps it a leaf consumer.

## Alternatives Considered

### Alternative 1: `Node2D` elements in world space, counter-rotated per frame

- **Description**: Elements live in the 2D world beside the objects they track and set `rotation = -camera.rotation` each frame to appear upright.
- **Pros**: Tracking needs no projection — a child node of the player follows it for free. Zoom scaling comes free too.
- **Cons**: The upright guarantee becomes an arithmetic result recomputed every frame instead of a structural property. Any frame where the counter-rotation is one step stale renders a visibly tilted gauge, and the exposure is worst during the 0.6 s camera tween — exactly when `hud.md` H1 says to verify it. The viewport-pixel offset requirement would also need explicit zoom division, reintroducing a second per-frame correction.
- **Rejection Reason**: It cancels a rotation it first inherited. D10.1's `CanvasLayer` never inherits it, so there is nothing to cancel and nothing to get stale.

### Alternative 2: A fourth `HudTuning` resource

- **Description**: Add `HudTuning` alongside `WateringTuning`, `OxygenTuning` and `PropTuning`, reached through the `Tuning` const holder per D6.3.
- **Pros**: Consistent with the established holder pattern. Values become swappable as a set and live in a `.tres`, which is the route the coding standards prefer for global values.
- **Cons**: ADR-0006 D6.1 sized the set at exactly three, one per GDD, and the HUD is not a GDD. Adopting this means amending an Accepted ADR plus adding registry entries, to hold values that are layout measurements rather than gameplay balance.
- **Rejection Reason**: The cost is an amendment to a frozen decision, and the benefit is set-swapping that nothing needs. `@export` reaches the same designer with no ADR change. Recoverable later without touching call sites.

### Alternative 3: Read-only view objects wrapping each state class

- **Description**: `bind()` receives `OxygenStateView` and `LevelStateView`, exposing getters only.
- **Pros**: Makes H19 structural. The HUD could not write to game state even if a future edit tried.
- **Cons**: Two new classes forwarding every accessor, for one consumer. `OxygenState` already has no setter of any kind, so its wrapper would be pure duplication.
- **Rejection Reason**: Accepted the weaker enforcement knowingly. Recorded as a **Negative** consequence rather than presented as equivalent.

### Alternative 4: One `CanvasLayer` root with the zones as ordinary `Control` containers

- **Description**: Keep `class_name HUD extends CanvasLayer` and make Z1–Z4 plain `Control` children of it, ordered by tree order or `z_index` rather than by `CanvasLayer.layer`.
- **Pros**: Fewer nodes. Matches the shape of Godot's own HUD tutorial, where the script sits on a `CanvasLayer` root with the elements as direct children. Avoids nesting without needing a separate coordinator node.
- **Cons**: Z-ordering becomes implicit. Anyone who drags a node in the scene tree changes which zone occludes which, silently and with no error — and `hud.md`'s "the debug overlay must not obscure any player-facing element" rule is precisely what would break.
- **Rejection Reason**: The ordering is load-bearing for a written requirement, so it should be declared rather than inferred. This is the same structural-over-discipline call as `architecture.md` P2 and ADR-0005's decision to assign frame priorities in code rather than per-scene in the inspector. The idiom cost is real and accepted.

### Alternative 5: Authoring the E7 input action in `project.godot`

- **Description**: Register `debug_overlay_toggle` normally and simply do not instance the overlay in release builds.
- **Pros**: Conventional, visible in the input map, no runtime `InputMap` mutation.
- **Cons**: `hud.md` H5 requires that a release export register **no input action** for E7. An authored action ships in every export.
- **Rejection Reason**: Fails a written acceptance criterion. Silently weakening H5 to fit the convention is how a criterion becomes decoration.

## Consequences

### Positive

- Four requirements move from `gap` to covered: **TR-oxygen-007, TR-oxygen-009, TR-watering-017, TR-watering-018**. Coverage reaches **49 of 52** once ADR-0011 and ADR-0012 are also Accepted.
- **H1 is satisfied structurally.** A `CanvasLayer` cannot inherit camera rotation, and the HUD never writes `rotation`, so there is no path by which an element tilts.
- **ADR-0003's close condition becomes reachable.** D3.3 recorded the `hud` scoping as a temporary state pending this ADR, and D10.9 ends it.
- **`accessibility-requirements.md` T9 becomes runnable**, and TR-oxygen-006's verification is unblocked, without any pause menu being designed.
- **Q16, Q17, Q18 and Q14 all close**, along with `hud.md` H5's mechanism.
- No frozen signature changes. `consume()`, `update_pour()`, `drain()`, `register_prop()` and the `Tuning` reach are all untouched. The ADR adds two classes and consumes one existing export.

### Negative

- **H19 is enforced by test, not by structure.** A future edit could add a write from the HUD, and only the test would catch it. Accepted knowingly in D10.4.
- **Eight levels gain a new authoring obligation.** Every level must author and wire a HUD or fail `V-WIRING`. This lands on the level migration epic **on top of** ADR-0011 D11.3's `level_bounds` obligation, which is also new and also per-level. Those two are now the epic's largest cost.
- **The HUD's tuning values sit in a `.tscn`, not a `.tres`.** They cannot be swapped as a set, and a second HUD scene would duplicate rather than share them.
- **E8 refuses to answer during a pour.** A player mid-pour who asks how many plants remain gets nothing for up to `water_duration`. Forced by the rule that nothing may hide an active pour's fill.
- **The settings screen remains unowned.** See *Explicitly unowned* below.

### Explicitly unowned, and flagged rather than silently dropped

- **The settings screen.** ADR-0008 names ADR-0010 as owner of "the future settings screen that will call `OxygenAccessibility.set_drain_rate_multiplier()`." **This ADR does not deliver it.** No settings-screen UX spec exists, and `interaction-patterns.md` § *Gaps & Patterns Needed* records that no button, focus, slider, toggle, or key-capture pattern exists anywhere in the project — it calls this "the largest gap in the UX layer" and states that a settings-screen UX spec should precede ADR-0010 rather than follow it. Designing that surface inside an architecture document would invent UX no approved spec covers. **Owner: unassigned. Prerequisite: a settings-screen UX spec.** Four accessibility commitments — remapping, one-hand presets, text scaling, reduced motion — have no delivery surface until it exists, and `accessibility-requirements.md` T4, T5 and T6 stay blocked.
- **The camera three-way decouple** (`TR-gravity-010`, `hud.md` Q10, `accessibility-requirements.md` T8). `camera_moving` gates rotation and follow together, and `camera_rotation_enabled` is separately uncoupled, so reduced motion cannot be offered. This is camera architecture, not HUD architecture, and this ADR does not claim it.
- **The session-18 camera-subscription finding.** Under ADR-0003's init order the camera's `gravity_changed` subscription may wire after the first broadcast, so the camera could render unrotated on every level load. ADR-0011 flagged it as unowned with "ADR-0010 or a camera ADR" as candidates. **ADR-0010 declines it** — it is camera wiring inside a frozen init order and touches no HUD node. **With ADR-0010 written, no planned ADR remains to absorb it, so closing it now requires a new ADR.** That is a change in its status and is recorded here rather than left implicit.
- **`TR-oxygen-009` rests on an unresolved GDD conflict.** `suit-oxygen.md` §2 wants thirty-seconds-out awareness while §4's caution threshold fires at 24 s for a 48 s level, i.e. after that mark. This ADR implements the §4 numbers, which are the concrete ones, and `hud.md` already resolves the intent by making the bar permanent rather than threshold-triggered. **The GDD's own numbers remain in tension and this ADR does not edit the GDD.**

### Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `WHEN_PAUSED` vs `ALWAYS` is applied from the stale registry note rather than from D10.6, darkening E7 during play | Medium | V-E1 verifies the enum semantic against the binary. The registry correction is owed at acceptance |
| An ancestor process-mode override silently changes what the HUD freezes | Medium | D10.6 sets exemptions on leaf nodes only. `core.md` documents the chain-wide hazard; V6 tests it |
| Someone re-nests the zone layers, or reorders them, restoring the defect the engine gate caught | Medium | D10.1 states the rule and the reason. **V12 tests it**, including that a tree reorder does not change occlusion. The first draft had no such criterion, which is how the defect nearly shipped |
| `follow_viewport_enabled` is switched on later, silently breaking the projection math | Low | D10.1 states the required default explicitly. The failure mode is a drifting gauge, not an error, so V1/V2 are the detector |
| Per-frame projection for Z1, Z2 and E7 costs more than expected in the 16.6 ms budget | Low | At most three tracked elements exist at once and each is one `Transform2D` multiply. `hud.md` records "no HUD frame-cost criterion" as an open advisory finding — still open, not closed here |
| The 8-level HUD authoring obligation is discovered during migration rather than planned | Medium | D10.9 states it, and the Migration Plan sequences it alongside `level_bounds` |
| E1's error appearance is never seen because no level mis-authors capacity | Low | V5 constructs the state directly rather than relying on an authored level |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `suit-oxygen.md` | **TR-oxygen-007** — R7 / AC9, the readout is always visible | D10.1 makes E1 a permanent `Control` on a `CanvasLayer` that ignores the camera. D10.2 keeps it beside the player in both camera modes. D10.5 polls it per frame, satisfying AC9's 0.1 s bound |
| `suit-oxygen.md` | **TR-oxygen-009** — R7 / AC10, threshold feedback at 50 / 25 / 10 percent | D10.5 reads bands from `OxygenTuning` and never redeclares them. `hud.md`'s tick marks and numerals carry the non-colour signal. The §2 / §4 tension is flagged unresolved above |
| `watering-system.md` | **TR-watering-017** — the HUD reads `carrying_bucket` as a prompt precondition; carry state itself is diegetic | D10.4 binds `LevelState` and reads `carrying_bucket`. No carry indicator is rendered, matching §6 as amended |
| `watering-system.md` | **TR-watering-018** — a fully grown plant shows a positive refusal marker, legible rather than silent | E4 is a rendered marker in Z2, not the absence of E2. D10.7's arbitration keeps it reachable |
| `design/ux/hud.md` | Q16 — where the HUD's tuning knobs live | **D10.3** — `@export` on the HUD scene nodes |
| `design/ux/hud.md` | Q17 — Z2's offset direction under non-default gravity | **D10.2** — Z2 offsets along eased `up_dir`, as Z1 does |
| `design/ux/hud.md` | Q18 — E8's zone and budget arbitration | **D10.7** — screen-anchored in Z3; suppresses Z2 while held; refused during a pour |
| `design/ux/hud.md` | Q14 / H5 — how E7 is stripped at export | **D10.8** — runtime instancing and runtime action registration, both behind a debug build check |
| `design/accessibility-requirements.md` | T9 — pause halts drain | **D10.6** — `PauseController` owns the toggle; `OxygenDrain` keeps `INHERIT` so the drain halts structurally |

## Performance Implications

- **CPU**: One `Transform2D` multiply per tracked element per idle frame, with at most three tracked elements live at once (Z1, one Z2, E7). Negligible against the 16.6 ms budget. Nothing in the HUD runs in `_physics_process`.
- **Memory**: One `CanvasLayer` scene per level, instanced once. Four `CanvasLayer` sublayers and roughly a dozen `Control` nodes.
- **Load Time**: One additional scene instanced per level load, plus one conditional overlay instance in debug builds only.
- **Network**: Not applicable.

**Not claimed**: this ADR does not assert a HUD frame-cost figure. `hud.md` records "no HUD frame-cost criterion" as an open advisory finding, and it stays open.

## Migration Plan

`src/` contains no HUD scene, no HUD script, and no pause handling, so this is new code rather than a change to existing behaviour. `src/scripts/debugger.gd` is the one thing being replaced.

1. Create `src/scripts/hud.gd` (`class_name HUD extends Node`) and `src/scenes/hud.tscn`: a plain `Node` root with **four sibling `CanvasLayer` children** at `layer` 1–4. Leave `follow_viewport_enabled` false on all four. Nest no `CanvasLayer` inside another.
2. Author E1 in Z1 and E2/E3/E4 in Z2, setting `offset_transform_enabled = true` in the `.tscn` on any Control the collision rule displaces.
3. Add the 10 `@export` knobs with the `hud.md` defaults.
4. Implement `bind()` and the `is_bound` refusal path, matching ADR-0002's per-consumer guard shape.
5. Add `PauseController` with `PROCESS_MODE_ALWAYS`. Leave every other HUD node at the default.
6. Port `debugger.gd`'s content into E7 under the paging model, add the runtime debug-build branch with its `has_action` guard, and **delete `debugger.gd` and `debugger.tscn`** once E7 reaches parity. E7's Collision group must implement the computed layer-mask intersection check, not a raw dump — it is what surfaces BUG-0001 and defects shaped like it.

   > **This step is a rewrite, not a move.** `debugger.tscn`'s root is a `Control`, and it is currently instanced as a child of `src/scenes/player/player.tscn`. Re-parenting it under the Z4 `CanvasLayer` changes its coordinate space, and it must also change from always-on to paged and from reading `Player` fields directly to reading injected state. Budget it as new work.
7. Author the E8 progress-query action in `project.godot`.
8. **Wire `hud` in all 8 levels.** Sequence this with ADR-0011 D11.3's `level_bounds` authoring — both are per-level obligations on the same 8 scenes, and doing them in one pass touches each scene once.
9. Re-run `validate()` in every level and confirm empty.

## Validation Criteria

- **V1** — In `level_01`, capture E1's global rotation on every frame across a full 0.6 s camera tween. It is 0.0 on every frame. Repeat in `level_02` under a gravity flip. (`hud.md` H1)
- **V2** — With gravity inverted in a static-camera level, E1 renders on the opposite side of the player from its default-gravity position, and the transition shows no snap or flicker. (H28)
- **V3** — Construct `OxygenState` with `drain_rate` composed to 0.5 and `oxygen_remaining` 24. E1's numerals read **48**. (H15)
- **V4** — E1's numerals are hidden above `oxygen_fraction` 0.50 and shown at and below it. (H16)
- **V5** — Construct the HUD with `oxygen_capacity <= 0`. E1 renders the error appearance — neither an empty bar nor hidden. Separately, draw before `bind()` and assert one `push_error()` and the same appearance. (H17, and the pre-injection state)
- **V6** — Set `SceneTree.paused = true`. Assert `OxygenState.remaining` is unchanged across the pause, every player-facing HUD node stops processing, and E7 keeps processing. Then set a non-`INHERIT` mode on an ancestor and assert the test fails — proving it detects the chain-wide hazard rather than passing by luck.
- **V7** — Hold the query action at a plant with a pour available: E8 renders and E2 does not. Release: E2 returns. Hold `interact` to start a pour, then hold the query action: E8 does not appear and E3's fill stays visible. (H4, Q18)
- **V8** — In a release export, assert `InputMap.has_action("debug_overlay_toggle")` is false and no E7 node exists in the tree. (H5)
- **V9** — Grep every HUD script for calls to mutators on `OxygenState`, `LevelState`, `Plant` and `PlayerWateringComponent`. Zero matches. (H19)
- **V10** — Empty the `hud` export in one level and assert `validate()` returns a `V-WIRING` finding. (D10.9)
- **V11** — Write `position` and `offset_transform_position` on the same displaced Control on every frame for 60 frames, and assert the rendered offset equals the displacement on all 60. **No shipped code in this project co-writes these per frame**, so this closes by test what D10.2 cannot close by precedent.
- **V12** — Assert Z4 renders below Z1, Z2 and Z3 with the player positioned over Z4's screen region, and that reordering the four zone nodes in the scene tree does not change which one occludes which. (`hud.md` H27, and the reason D10.1 uses `layer` integers rather than tree order.) **The first draft's nested-`CanvasLayer` arrangement had no criterion covering this and could have shipped silently broken.**

## Related Decisions

- **ADR-0002** — Level state ownership. Supplies the `@export var hud` and the injection contract this ADR consumes. No change.
- **ADR-0003** — Load validation. D3.3's required-consumer table gains its third **Yes** at acceptance (D10.9). This is the obligation ADR-0003 recorded so that this author would inherit it.
- **ADR-0005** — Frame ordering. The HUD takes no row: it reads in `_process`, after the physics step.
- **ADR-0006** — Tuning strategy. D10.3 declines a fourth resource, so D6.1 and D6.3 are unamended.
- **ADR-0007** — `GravityAuthority` owns `up_dir`. D10.2 reads it and never stores it.
- **ADR-0008** — Oxygen. Supplies the composed `drain_rate` E1 displays, and assigned the pause toggle here. D10.6 preserves its structural drain-halt guarantee unchanged.
- **ADR-0012** — Spent jug. D12.5 grants no pause exemption, and D10.6 claims none on its behalf.
- `design/ux/hud.md` — the UX source, corrected 2026-08-16 before this ADR cited it.
- `design/accessibility-requirements.md` — the tier and the test plan this ADR unblocks in part.
- `design/ux/interaction-patterns.md` — P1–P7. **O1 is owed the same closure this ADR's D10.2 gives `hud.md` Q17.**
