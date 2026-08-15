# ADR-0004: Collision layer allocation

## Status

Proposed

## Date

2026-08-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (project runs 4.7.1-stable) |
| **Domain** | Physics (2D) — collision layers and masks, `Area2D` detection, body-pair filtering |
| **Knowledge Risk** | **LOW, and this is a verified downgrade rather than an assumption.** `VERSION.md` rates the project HIGH overall on post-4.3 physics and rendering churn. Every item in that churn is 3D or rendering. `docs/engine-reference/godot/modules/physics-2d.md` states outright that 2D physics is unchanged 4.4 → 4.7 and instructs that 2D decisions **not** be marked unverified — and that claim was independently re-checked during the 2026-08-14 specialist gate rather than taken on trust. See *Engine facts this decision rests on*. |
| **References Consulted** | `docs/engine-reference/godot/modules/physics-2d.md`, `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `docs/architecture/architecture.md` §Collision layer allocation, ADR-0001, ADR-0003, and the engine specialist review of 2026-08-14 (L1–L6, F1–F8) |
| **Post-Cutoff APIs Used** | **None.** `collision_layer`, `collision_mask`, `Area2D.body_entered`, `PackedScene.instantiate()` and `ProjectSettings.get_setting()` all predate 4.0, appear in neither `deprecated-apis.md` nor `breaking-changes.md`, and are unchanged across 4.4 → 4.7. |
| **Verification Required** | **None outstanding** for the decision itself — L1–L6 were each verified against engine source on 2026-08-14. Three implementation-time items remain and are listed under *Validation Criteria*, the most important being F8: this decision guarantees authored state only. |

> **Jolt is irrelevant here.** `project.godot` sets `3d/physics_engine="Jolt Physics"`,
> but this is a 2D game and the setting is inert (`physics-2d.md` §"Jolt does NOT
> apply to this project"). No statement in this ADR derives from Jolt behaviour.

### Engine facts this decision rests on

Verified on 2026-08-14 during the engine specialist gate, against Godot engine
source and the live class reference. **Numbering is local to this ADR** — these are
not ADR-0003's E1–E3. Do not re-search them.

**L1 — `Area2D.body_entered` gates on the *area's* mask against the *body's*
layer, and nothing else.** In `godot_area_pair_2d.cpp:36` the only test is
`area->collides_with(body)`. The area's own `collision_layer` is never consulted
for body detection. This is what makes the "layer 0, mask 2" detector idiom in
this project correct rather than accidental: a detector needs no layer at all.

**L2 — An `Area2D` is never solid.** Areas do not appear in the body-body
contact path (`GodotBodyPair2D`) at all. A `RigidBody2D` whose mask includes an
area's layer is *detected by* it, never *blocked by* it. Consequence: prop
isolation from the interactables cannot be achieved by, and does not depend on,
any physical-blocking behaviour — only detection matters on that side.

**L3 — Body-vs-body pairing is an OR, not an AND. ⚠** `godot_body_pair_2d.cpp:256-260`
requires `collide_A || collide_B`. **A one-sided mask mistake still produces
contact.** It is not enough that props do not mask the player; the player must
also not mask props. This single fact is why D4.3 specifies *both* directions and
why D4.5 asserts both — an allocation that only got one side right would look
correct in review and fail in play.

**L4 — A static or animatable body's own mask is never evaluated for its own
motion.** `godot_body_pair_2d.cpp:256` only reads `collide_A` when
`mode > KINEMATIC`. `AnimatableBody2D.collision_mask` therefore has no effect on
what the platform pushes or is blocked by. This makes `moving_platform.tscn:16`
dead configuration, not a behaviour to preserve.

**L5 — `collision_layer` / `collision_mask` are populated by
`PackedScene.instantiate()` without a `SceneTree` and without `_ready()`.** They
are plain integer properties set by the `node->set(...)` loop inside
`SceneState::instantiate()` — the same mechanism ADR-0003 verified as its E1.
This is what makes D4.5's test runnable headlessly over every scene.

**L6 — `ProjectSettings.get_setting()` is a static configuration read and is
headless-safe.** The test can therefore assert that `project.godot`'s
`layer_names/2d_physics/*` agree with the `CollisionLayers` constants.

> **Caveat on method, recorded plainly.** As with ADR-0003, no literal `4.7` git
> tag is publicly fetchable, so the source citations are 4.3-stable plus the
> documented-unchanged 4.4 → 4.7 changelogs. The specialist independently
> re-verified `physics-2d.md`'s "no 2D change" claim against the live class
> reference rather than repeating it. Stated rather than overclaimed.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **None.** This ADR can be accepted independently of every other. ADR-0001 names it as enabled work, but nothing here reads gravity state. |
| **Enables** | **ADR-0011** (physics props implementation) — a prop cannot be authored before the layer it belongs on exists. |
| **Blocks** | **ADR-0011**, and with it every `physics-props.md` acceptance criterion. `architecture.md` §Acceptance ordering states it directly: *"ADR-0004 before ADR-0011. Props AC1/AC2 hold by construction only if the layer allocation exists before the first prop does."* |
| **Ordering Note** | Deliberately narrow. This ADR allocates bits and specifies how the allocation is enforced. It does **not** decide prop mass, damping, spawn or lifetime (ADR-0011), nor where `PropTuning` lives (ADR-0006). It touches no gravity, level-state or frame-ordering concern, which is why it carries no upstream dependency. |

## Context

### Problem Statement

`physics-props.md` R2 makes an unusually strong claim for a GDD — it specifies not
just a behaviour but the *mechanism that must enforce it*:

> "This is enforced by collision layer and mask, not by conditional logic, so R1
> holds by construction rather than by careful coding. A prop that could be made to
> collide with the player by a code path is a bug in the layer setup, not a
> behaviour to special-case."

`architecture.md` P2 generalises it: *"Contracts are enforced by structure, not by
discipline. A rule that depends on every future author remembering it is not
enforced."* And `systems-index.md` lists "Props never affect level solvability" as
a cross-document invariant guarded by "Collision layer, AC1 / AC2".

Three documents therefore delegate a load-bearing guarantee to a layer allocation
that **does not exist**. `project.godot` names three bits; the fourth — the one
props need — has never been created.

Auditing the project to write that allocation surfaced that the existing three are
in worse shape than the missing fourth:

| # | Defect | Evidence |
|---|---|---|
| 1 | **The out-of-bounds kill plane is dead.** `KillArea2D` declares no layer or mask, so both default to `1`. The player is on layer `2`. `1 & 2 == 0`, so `body_entered` can never fire and `main.gd:71` is unreachable in the two levels that wire it. | `level_05.tscn:386` + `:400`, `level_06.tscn:392` + `:409`, `player.tscn:117`, `main.gd:71` |
| 2 | **`PlayerArea2D` is vestigial and sits on `world`.** No signal anywhere connects to it. `player.gd:48` reaches through it only to bind `col_shape`, which is never read again in any file. It defaults to layer `1` — a player-owned collider on the terrain layer. | `player.tscn:131`, `player.gd:48` |
| 3 | **Dead mask on the moving platform.** `collision_mask = 2` on an `AnimatableBody2D`, which per L4 has no effect whatsoever. It reads as intent and is noise. | `moving_platform.tscn:16` |
| 4 | **Bit 3 `item` is named but occupied by nothing.** All five interactables are detectors (`collision_layer = 0`). Worse, `architecture.md:171` documents the bit as live and "masked by player only", so the blueprint describes a configuration the code does not have. | `project.godot`, `bucket.tscn:18`, `goal.tscn:73`, `gravity_zone.tscn:10`, `plant.tscn:87`, `spike_hazard.tscn:11` |
| 5 | **Terrain's layer is configured in five independent places.** Levels 03–06 and `test_main` each embed a private `[sub_resource type="TileSet"]` carrying `physics_layer_0/collision_layer = 1`; levels 01/02/07/08 share `Simple_tileset.tres`, which sets no value and inherits the default. Five places for one invariant to drift. | `level_03.tscn:230`, `level_04.tscn`, `level_05.tscn`, `level_06.tscn`, `src/resources/Simple_tileset.tres` |

Defect 1 is a live gameplay bug that predates this ADR and is independent of it.
It is recorded here because allocating layers is what made it visible, and fixing
it is part of the same rollout.

The common cause is that layer allocation has never been anybody's decision. Each
node was configured when it was authored, by whoever authored it, against no
written table. That is precisely the "depends on every future author remembering
it" failure P2 rejects — and adding a prop layer to that situation without fixing
it would put the strongest structural guarantee in the game on the weakest
foundation in the project.

### Constraints

- **Both directions must be zero (L3).** Body pairing is an OR. A correct-looking
  one-sided allocation is silently broken.
- **Only 4 of 32 bits are needed.** This is a small 2D game; an elaborate scheme
  would be its own maintenance burden.
- **The 5 interactable scenes work today.** Every detector uses `body_entered`
  against the player body — verified across all seven call sites. Any allocation
  that rewrites the detection direction rewrites every handler for no gameplay gain.
- **`src/` is untouched through the architecture phase.** ADR-0001, ADR-0002 and
  ADR-0003 all specified code deltas without applying them. This ADR follows suit.
- **Enforcement must not amend ADR-0003.** Its D3.3 froze `LevelValidation` at six
  coded rules; a seventh would reopen an already-reviewed decision.

### Requirements

- Props must be incapable of contacting the player, plants, buckets, the airlock or
  hazards — verified in both mask directions (`physics-props.md` R1/R2, AC1/AC2).
- The allocation must be readable from code, not just from editor checkboxes.
- Drift must be caught automatically, not by review.
- Bits must be allocated centrally, so bit 5 is never claimed twice.

## Decision

### D4.1 — Four allocated bits; the rest reserved

| Bit | Value | Name | Carried by | Masks |
|---|---|---|---|---|
| 1 | `1` | `world` | `TileSet.physics_layer_0` (all 8 levels), `AnimatableBody2D` platform bodies | — *(static; see L4)* |
| 2 | `2` | `player` | The `Player` `CharacterBody2D`, and nothing else | `1` — `world` |
| 3 | `4` | *(retired)* | **Nothing. Reserved and deliberately unused.** | — |
| 4 | `8` | `prop` | `PropBody` `RigidBody2D` | `9` — `world \| prop` |
| 5–32 | — | *(unallocated)* | Nothing. Claiming one requires amending this ADR. | — |

Detector `Area2D`s — `Bucket`, `Plant`, `Goal`, `GravityZone`, `SpikeHazard`,
`KillArea2D` — carry `collision_layer = 0` and `collision_mask = 2`.

### D4.2 — Things detect the player; the player never queries. Bit 3 is retired

The existing detection direction is kept unchanged. Every interactable is a
detector with no layer of its own, which per L1 is exactly what `body_entered`
requires. All seven detector call sites already work this way:
`bucket.gd:4`, `goal.gd:15/38`, `gravity_zone.gd:23`, `plant.gd:51/57`,
`spike_hazard.gd:37/39`, `main.gd:71`. Not one uses `area_entered`.

Bit 3 `item` is therefore retired rather than populated. Naming a bit that nothing
occupies is an invitation: the next author to need "an item layer" will find one
already named and wire half a system to it. The name is removed from
`project.godot` and the bit is recorded here as reserved.

**This decision corrects `architecture.md:171`**, which currently documents bit 3
as live and "masked by player only". The blueprint is wrong and the code is right.

*Rejected alternative:* activating bit 3 and inverting detection so the player
queries. It rewrites 5 scenes and every handler above, and buys nothing — see
*Alternative 4*.

### D4.3 — Props: layer `8`, mask `9`, verified zero in both directions

```
PropBody      collision_layer = 8  (prop)      collision_mask = 9  (world | prop)
Player        collision_layer = 2  (player)    collision_mask = 1  (world)
Interactable  collision_layer = 0               collision_mask = 2  (player)
```

Per L3 the guarantee needs both directions checked. All four checks are zero:

| Pair | Check | Result |
|---|---|---|
| Prop → Player | `prop.mask(9) & player.layer(2)` | `0` |
| Player → Prop | `player.mask(1) & prop.layer(8)` | `0` |
| Interactable → Prop | `area.mask(2) & prop.layer(8)` | `0` |
| Prop → Interactable | area is not solid (L2); prop has no mask bit for layer 0 | no path |

`physics-props.md` AC1 and AC2 are therefore not merely satisfied but
*unreachable to violate* through authored configuration — subject to D4.6.

Props retain `world` in their mask because R2 requires exactly that: props collide
with terrain and each other, and nothing else.

### D4.4 — `project.godot` names plus a const class; the const class wins

Both exist, with a stated precedence so a divergence has an answer:

- **`project.godot` `layer_names/2d_physics/*`** — makes the editor's collision
  checkboxes readable while authoring. Cosmetic; nothing reads it at runtime except
  the test in D4.5.
- **`class_name CollisionLayers`** — the authoritative source. Code that needs a
  layer value reads it here. On any disagreement between the two, the const class
  is correct and `project.godot` is the thing to fix.

The script is named `CollisionLayers`, **not** `architecture.md`'s
`CollisionLayerRegistry`. It registers nothing at runtime — it is a constant table
— and `CollisionLayers.PROP` reads better at every call site than
`CollisionLayerRegistry.PROP`. Recorded as a deliberate rename of a blueprint name.

### D4.5 — A gdUnit4 scene test asserting derived invariants

`tests/unit/physics/collision_layers_test.gd` instantiates each scene via
`PackedScene.instantiate()` without adding it to the tree (L5) and asserts:

1. **The four isolation invariants of D4.3**, expressed as derived bit tests —
   `prop.collision_mask & CollisionLayers.PLAYER == 0`, and so on — **never as raw
   integer equality.** Raw equality fails the moment an unrelated bit is legitimately
   added, even though R1 still holds; the derived form fails only when the guarantee
   actually breaks. *(Specialist finding F6.)*
2. **No scene uses an unallocated bit:**
   `(layer | mask) & ~(WORLD | PLAYER | PROP) == 0`. This one assertion catches bit-3
   revival and any future silent claim on bits 5–32.
3. **Every `TileSet.physics_layer_0/collision_layer` equals `WORLD`** — across all
   five inline sub-resources and the shared `.tres` (defect 5).
4. **`project.godot` names agree with the constants**, read via
   `ProjectSettings.get_setting()` (L6).

This is a unit test rather than a seventh `LevelValidation` rule, so ADR-0003's
frozen six-rule set is untouched. It also covers scenes that are not levels —
`player.tscn`, `bucket.tscn` — which `LevelValidation` never sees.

Both the test and `CollisionLayers` must be **warning-clean**: gdUnit4 treats
GDScript warnings as errors at discovery, and one warning fails the entire suite
at compile time, not just this file. *(F5; the same hazard ADR-0003 recorded as F10.)*

### D4.6 — Runtime layer and mask mutation is forbidden

**New forbidden pattern**, raised by the specialist gate as F8 and the sharpest
limitation on everything above:

> D4.3's guarantee covers **authored** state. The test in D4.5 reads scene files.
> A single `set_collision_mask_value()` call at runtime would break R1 invisibly to
> every check in this ADR.

Therefore: no gameplay script may call `set_collision_layer_value()`,
`set_collision_mask_value()`, or assign `collision_layer` / `collision_mask` at
runtime. Layers are authored data. A feature that appears to need a runtime layer
change is a design change requiring `physics-props.md` to be revised first — the
same escalation P1 imposes on per-body gravity.

Without D4.6, "by construction" quietly degrades back into "by discipline", which
is the exact failure this ADR exists to prevent.

### D4.7 — Existing defects are specified here and fixed in the migration epic

All five defects get a numbered remedy in *Migration Plan*. No `.tscn`, `.gd` or
`project.godot` file is edited by this ADR, consistent with ADR-0001 through
ADR-0003. Defect 1 is additionally filed as a bug report — **BUG-0001**
(`production/qa/bugs/BUG-0001.md`, filed 2026-08-14) — because a live
player-facing defect should not exist only inside an architecture document.

### Architecture Diagram

```
bit 1  world ──────────────────────────────────────────────┐
   │  TileSet.physics_layer_0 (8 levels)                   │
   │  AnimatableBody2D (moving platforms)                   │
   │                                                        │
   ├──◀── masked by ── Player   (layer 2, mask 1)          │
   └──◀── masked by ── PropBody (layer 8, mask 9) ──┐      │
                                                     │      │
bit 2  player ◀── masked by ── every detector Area2D │      │
   │  Player CharacterBody2D ONLY                    │      │
   │     (Bucket · Plant · Goal · GravityZone ·      │      │
   │      SpikeHazard · KillArea2D — all layer 0)    │      │
   │                                                  │      │
bit 3  ── RETIRED, occupied by nothing ──             │      │
                                                      │      │
bit 4  prop ◀─────────────────────────────────────────┘      │
   │  PropBody RigidBody2D                                   │
   └── masks world ──────────────────────────────────────────┘

The isolation, stated as absence:
   NOTHING that masks bit 4 also masks bit 2.
   NOTHING on bit 2 masks bit 4.
   Detector areas mask bit 2 only, so bit 4 is invisible to them.
```

### Key Interfaces

```gdscript
## Central allocation of 2D physics collision layer bits (ADR-0004).
##
## Authoritative source. project.godot's layer_names are editor-facing only;
## on any disagreement, this file is correct and project.godot is the bug.
##
## Layer/mask values are AUTHORED data. Never assign collision_layer or
## collision_mask at runtime, and never call set_collision_layer_value() or
## set_collision_mask_value() — doing so breaks physics-props.md R1 in a way
## no test in this project can observe (ADR-0004 D4.6).
class_name CollisionLayers
extends RefCounted

## Terrain and animatable platforms.
const WORLD: int = 1 << 0   # 1
## The Player CharacterBody2D, and nothing else.
const PLAYER: int = 1 << 1  # 2
# bit 3 (value 4) is RETIRED — see ADR-0004 D4.2. Do not claim it.
## Cosmetic RigidBody2D props. Never interacts with PLAYER (physics-props.md R1).
const PROP: int = 1 << 3    # 8

## Every bit this project has allocated. Used to assert no scene claims another.
const ALLOCATED: int = WORLD | PLAYER | PROP  # 11

## Masks, named by the role that carries them.
const PLAYER_MASK: int = WORLD              # 1
const PROP_MASK: int = WORLD | PROP         # 9
const DETECTOR_MASK: int = PLAYER           # 2
const DETECTOR_LAYER: int = 0               # detectors need no layer (ADR-0004 L1)
```

## Alternatives Considered

### Alternative 1: Assign layers in code, in `_ready()`, from the constants

- **Description**: Each script sets its own `collision_layer` / `collision_mask`
  from `CollisionLayers` on ready. Scene files carry no collision configuration.
- **Pros**: One uniform mechanism; impossible for a scene to disagree with the
  constants; trivially greppable.
- **Cons**: The editor's collision checkboxes would display values that are never
  the runtime truth — a genuinely nasty debugging trap, since the inspector is the
  first place anyone looks. Also delays correct layers until tree entry.
- **Rejection Reason**: It *requires* the exact runtime mutation D4.6 forbids,
  making the ban unstatable and leaving no way to distinguish sanctioned assignment
  from an accidental one. It also breaks D4.5: with layers absent from scene files,
  the headless test has nothing to assert without running `_ready()`.

### Alternative 2: `project.godot` `layer_names` only

- **Description**: Name all four bits, document the table in the control manifest,
  write no code.
- **Pros**: Zero code, zero sync burden, nothing to keep in agreement.
- **Cons**: No script can reference a layer by name, and nothing is testable.
- **Rejection Reason**: This is what the project has today for three bits, and it
  produced all five defects in *Problem Statement*. It is the null decision.

### Alternative 3: Enforce isolation with conditional guards in code

- **Description**: `if body is PropBody: return` at the top of each detector
  handler and in the player's collision response.
- **Pros**: No project-wide configuration; each system self-defends; obvious when read.
- **Cons**: Every future detector must remember the guard.
- **Rejection Reason**: `physics-props.md` R2 forbids it by name — "enforced by
  collision layer and mask, **not by conditional logic**". Worse, per L2/L3 the
  contact has *already occurred* in the physics step by the time a handler runs; a
  guard suppresses the reaction while the prop has already pushed the player. The
  guarantee would be cosmetic.

### Alternative 4: Activate bit 3 and invert detection so the player queries items

- **Description**: Interactables move onto layer 3; `PlayerArea2D` masks 3 and
  reports overlaps; matches `architecture.md:171` as currently written.
- **Pros**: Makes the blueprint's existing text true without editing it; one place
  to reason about interaction.
- **Cons**: Rewrites 5 scenes and all 7 detector call sites, and revives
  `PlayerArea2D`, which defect 2 shows is dead weight.
- **Rejection Reason**: Substantial churn across working code for no gameplay or
  structural gain. The blueprint is easier to correct than the codebase, and D4.2
  corrects it.

## Consequences

### Positive

- `physics-props.md` R1/R2 and AC1/AC2 become structurally unviolatable in authored
  data, verified in both mask directions rather than one (L3).
- Four latent defects and one live gameplay bug are documented with exact
  locations, having previously been invisible.
- Bit allocation acquires an owner. Claiming bit 5 now requires amending this ADR.
- ADR-0011 is unblocked and inherits an unambiguous prop configuration.
- A small broadphase win: props are never paired against the player or the five
  interactables, which at the 40-prop budget removes pairs that would otherwise be
  filtered later in the pipeline.

### Negative

- Two sources of truth (`project.godot` and `CollisionLayers`) that can diverge.
  Mitigated by D4.5's agreement assertion and an explicit precedence rule, but the
  duplication is real and is the cost of readable editor checkboxes.
- Fixing defect 1 changes live behaviour: the kill plane in levels 05 and 06 will
  begin firing. Those levels have only ever been played with it dead, so a fall
  that currently strands the player will now restart the level. This is the
  intended behaviour, but it is a behaviour change and needs a playtest.
- D4.6 forecloses a legitimate technique. Runtime layer toggling is the normal
  Godot solution for one-way platforms, temporary invulnerability and phasing. Any
  such future feature must revise this ADR rather than just implement.

### Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| **A prop is authored with a hand-edited mask that reintroduces player contact** | Medium — the failure L3 makes easy | D4.5 assertion 1, in both directions. Fails CI, not playtest |
| **Bit 3 is revived by a future author who finds it free** | Medium | D4.5 assertion 2 fails on any use of an unallocated bit; the name is removed from `project.godot` so the editor no longer suggests it |
| **Runtime mutation silently voids the guarantee (F8)** | Medium | D4.6 bans it and it is registered as a forbidden pattern. Honestly assessed: this is the **weakest** link in the chain — it is enforced by review and grep, not by structure, which is exactly the property this ADR criticises elsewhere. A static check would be better and does not exist |
| **Terrain layer drifts in one of the five tileset definitions** | Low | D4.5 assertion 3 covers all five. Migration step 6 proposes consolidation, which would remove the risk class |
| **The test's scene list goes stale as scenes are added** | Medium | Enumerate `src/scenes/**/*.tscn` by directory scan rather than a hardcoded list, so a new scene is covered on creation. Note `.tscn*.tmp` editor autosaves exist in `src/scenes/levels/` (gitignored via `.gitignore:39`) and must not be picked up — filter on exact `.tscn` suffix |
| **gdUnit4 warnings-as-errors fails the whole suite** | Medium | F5. Run the headless command locally before calling the test step done |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `physics-props.md` | **R1** — props never collide with the player, objectives or hazards | D4.3 gives props a layer no other body masks and a mask covering only `world` and `prop` |
| `physics-props.md` | **R2** — enforced by layer and mask, *not conditional logic* | D4.1/D4.3 are pure configuration. Alternative 3 (guards) is rejected explicitly, on the GDD's own instruction and on L2/L3 grounds |
| `physics-props.md` | **AC1** — a prop never collides with the player from either direction, at any gravity angle | Both directions verified zero in D4.3. Gravity angle is irrelevant to mask filtering, so the "at any angle" clause needs no separate mechanism |
| `physics-props.md` | **AC2** — a prop never collides with a plant, bucket or the airlock | Detector areas mask `player` only; props are invisible to them (L1), and areas are not solid (L2) |
| `physics-props.md` | R7 — out-of-bounds props are freed | Noted, not decided: whether the kill plane should also mask `prop` (mask `10`) rather than using a per-prop notifier is **ADR-0011's** call. This ADR only makes the option available |
| `systems-index.md` | Cross-document invariant: *"Props never affect level solvability"*, guarded by *"Collision layer, AC1 / AC2"* | D4.5 turns the guard from an assertion in a table into an automated test |
| `gravity.md` | Zones set gravity when the player enters | D4.2 preserves the existing detector direction, so `gravity_zone.gd:23` is unaffected |

Traceability: this ADR covers `TR-props-002` per `architecture.md`'s Required ADRs table.

## Performance Implications

- **CPU**: Negligible and slightly positive. Mask filtering happens in the
  broadphase regardless; a narrower mask removes candidate pairs rather than adding
  work. At the 40-prop budget, props are never paired against the player or the
  five interactables at all.
- **Memory**: Zero. `CollisionLayers` is constants only and is never instantiated.
- **Load Time**: Zero at runtime. The D4.5 test adds one CI step that instantiates
  every scene once.
- **Network**: Not applicable — single-player.

This ADR claims no performance budget. `prop_gravity` remains ADR-0001's, and the
40-prop budget remains `physics-props.md` §7 / ADR-0006's.

## Migration Plan

No step is applied by this ADR. Steps 1–5 belong to the migration epic; step 6 is
optional cleanup.

1. **Add the prop layer name.** `project.godot` `[layer_names]` gains
   `2d_physics/layer_4="prop"`, and `2d_physics/layer_3="item"` is **removed** (D4.2).
2. **Create `src/scripts/collision_layers.gd`** with the D4.4 contract verbatim.
   Must be warning-clean (F5).
3. **Fix the dead kill plane** *(defect 1, specialist F1, filed as **BUG-0001**)*.
   `level_05.tscn:386` and `level_06.tscn:392` each gain `collision_layer = 0` and
   `collision_mask = 2`. **Requires a playtest of both levels** — see *Negative
   consequences*; this restores behaviour that has never actually run.
4. **Delete `PlayerArea2D`** *(defect 2, F2)* — remove the node at
   `player.tscn:131` with its child `CollisionShape2D`, and the now-dangling
   `col_shape` at `player.gd:48`. Deletion rather than re-layering: nothing reads
   it, and a node kept "just in case" on the wrong layer is how defect 1 happened.
   Confirm no `.tscn` references the path before deleting.
5. **Remove the dead platform mask** *(defect 3, F3)* — delete
   `moving_platform.tscn:16`, which per L4 does nothing.
6. **Optional — consolidate the tilesets** *(defect 5)*. Levels 03–06 and
   `test_main` embed private `TileSet` sub-resources duplicating what
   `Simple_tileset.tres` provides. Pointing all 8 levels at the shared resource
   reduces five drift sites to one. Out of scope here; worth its own task, and
   `Simple_tileset.tres` should gain an explicit `physics_layer_0/collision_layer = 1`
   rather than relying on the default either way.
7. **Add `tests/unit/physics/collision_layers_test.gd`** implementing D4.5's four
   assertion groups. It will **fail on assertion 1 only when a prop scene exists**,
   so unlike ADR-0003's suite-wide test this one is green from the moment it lands
   and does not need to be held back for the migration.

Steps 1, 2 and 7 have no dependency on the others and can land immediately.

## Validation Criteria

The decision is correct if:

1. `collision_layers_test.gd` passes on the current codebase after migration steps
   1–5, and **fails** when any of these is deliberately introduced in a scratch
   branch: a prop masking `player`; a player masking `prop`; any node using bit 3
   or bit 5; a tileset whose physics layer is not `world`.
2. A prop dropped onto the player at any gravity angle passes through with no
   velocity change to either body (`physics-props.md` AC1, playtest evidence).
3. A prop resting on a plant, bucket or the airlock produces no `body_entered` on
   that detector (AC2).
4. Levels 05 and 06 restart when the player falls out of bounds (defect 1 fixed).
5. No file outside `collision_layers.gd` contains `set_collision_layer_value`,
   `set_collision_mask_value`, or an assignment to `collision_layer` /
   `collision_mask` (D4.6). Greppable; a CI grep step would make it structural.

Open at implementation time:

- Whether `KillArea2D` should also mask `prop` — **ADR-0011's** decision (R7).
- Whether the D4.6 ban warrants a CI grep step rather than review. Recommended, and
  deliberately left to the epic rather than asserted here.
- Whether `Simple_tileset.tres` should state its physics layer explicitly rather
  than inherit the default. Recommended; folded into migration step 6.

## Related Decisions

- **ADR-0001** — Gravity ownership and global broadcast. Names this ADR under
  *Enables*; supplies the other half of prop isolation. Props receive gravity from
  the default physics space, which is orthogonal to layer allocation. Its forbidden
  pattern `area2d_gravity_space_override` remains in force and is not weakened here.
- **ADR-0003** — Level load validation contract. D4.5 deliberately uses a unit test
  rather than a seventh validation rule, leaving ADR-0003's D3.3 six-rule set
  frozen. Its E1 (`instantiate()` populates properties before `_ready()`) is the
  basis of L5.
- **ADR-0011** — Physics props implementation. Blocked on this ADR. Inherits layer
  `8` / mask `9`, and owns the open `KillArea2D`-masks-props question.
- **ADR-0006** — Tuning resource strategy. Owns `PropTuning`, including
  `props_per_level_budget`. No overlap: this ADR allocates bits, ADR-0006 allocates
  values.
- `design/gdd/physics-props.md` — R1, R2, AC1, AC2, §5.
- `design/gdd/systems-index.md` — the cross-document solvability invariant.
- `docs/architecture/architecture.md` §Collision layer allocation (line 171) —
  **corrected by D4.2**; its bit-3 row describes a configuration the code does not
  have, and its module name `CollisionLayerRegistry` is renamed by D4.4.
