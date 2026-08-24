# Epic: Physics Props

> **Layer**: Presentation
> **GDD**: design/gdd/physics-props.md
> **Architecture Module**: `PhysicsProps` (`architecture.md:118` — cosmetic rigid bodies, new)
> **Status**: Ready — **scheduling deferred to Vertical-Slice tier**
> **Stories**: 6 stories — created 2026-08-24

## Overview

Physics props are loose objects — tables, chairs, crates, debris — that share the
level's single global gravity vector with the player. When a Gravity Zone rewrites
down, unsecured props fall the new way, and a room full of them is what makes a
flip read as *the room turning over* rather than a camera trick. This epic
implements the prop body itself: `PropBody`, a scripted `RigidBody2D` that is the
only prop type in the project (D11.1); a fall-speed clamp applied inside
`_integrate_forces` (D11.2); one `LevelBounds` area per level that frees props
leaving the level, on all four sides, gravity-agnostically (D11.3); and the two
`PhysicsServer2D` space writes that make a freshly loaded level's gravity correct
before the first physics step (D11.5).

Props are **purely cosmetic and must stay that way**. They never collide with the
player, the objectives, or the hazards, and that holds by collision-layer
construction rather than by conditional logic — ADR-0004 already allocated layer
`8` / mask `9` for exactly this. Restart reset is likewise structural: props return
to authored transforms because ADR-0002 rebuilds the level, not because anything
saves and restores them, and D11.4 bans runtime prop spawning to keep it that way.

**This epic implements ADR-0001 Changeset B** (parts 4, 4a, 4b), which ADR-0001
assigned here by name (`adr-0001:530`).

## Scheduling Note — Read Before Planning This Into A Sprint

ADR-0011 carries an Implementation Scope Note (added 2026-08-17): the architecture
is Accepted and binding, but **implementation is not scheduled at MVP tier**.
`art-bible.md` §1.3 formally defers physics-prop *content* to Vertical-Slice tier,
because MVP's "the room moves, not a camera trick" proof (Pillar 1) is already
satisfied by `main.gd`'s camera tween and `player_visual_component.gd`'s continuous
sprite rotation. Props are a second, corroborating layer. `game-concept.md` Core
Mechanics item 4 carries a matching footnote.

The epic is therefore **well-formed and unblocked, but not next-up.** Nothing in
ADR-0011's Decision or Migration Plan changes because of this — the note records
*when* the work is scheduled, not *how* it is built.

**One exception is worth scheduling on its own merits.** `LV-006` in the level
migration epic is currently *unschedulable* rather than merely unstarted: it needs
`class_name PropBody` to exist, and no other epic delivers it. The D11.1 story
alone clears that, ahead of any prop content.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0011: Physics prop body, lifetime and speed cap | `PropBody` is the only prop type (D11.1); the cap clamps `linear_velocity` inside `_integrate_forces` (D11.2); one `LevelBounds` area frees out-of-bounds props, not the kill plane (D11.3); restart reset is structural and runtime spawning is banned (D11.4); `reset_to()` writes the space parameters synchronously (D11.5) | LOW |

### Consumed, not owned

These ADRs supply pieces this epic uses. **This epic does not re-open or re-claim
any of them**, and ADR-0011 is explicit that it does not either.

| ADR | What it supplies |
|---|---|
| ADR-0001 | The prop registry, the space write, and the wake loop that satisfies R5 / AC3 |
| ADR-0004 | Collision layer `8` / mask `9` — the allocation that makes R1 and R2 structural |
| ADR-0003 | `V-PROP-BUDGET`, and the `V-BOUNDS` row D11.7 adds to its table |
| ADR-0006 | The `PropTuning` resource carrying `prop_gravity_scale`, `prop_max_speed`, `props_per_level_budget` |

### Engine risk is LOW, and that is a verified downgrade

The project pin rates HIGH on post-4.3 churn overall, and every item in that churn
is 3D or rendering. `docs/engine-reference/godot/modules/physics-2d.md` states that
`RigidBody2D`, `Area2D`, `CharacterBody2D` and `move_and_slide()` carry no breaking
change across 4.4 → 4.7, and instructs agents not to mark 2D physics decisions
unverified. Jolt is 3D only and inert here. ADR-0011 uses **no post-cutoff API**;
`CollisionShape2D.one_way_collision_direction` is new in 4.7 and deliberately not
used. **GH-115763 does not apply** — `_integrate_forces` returns `void`, so the 4.7
typed-return-inheritance break leaves the D11.2 override alone.

## GDD Requirements

All nine trace to an Accepted ADR. **There are no untraced requirements.**

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-props-001 | Props obey the global vector including during easing; symmetric | ADR-0001 ✅ |
| TR-props-002 | Cosmetic isolation enforced by layer and mask | ADR-0004 ✅ |
| TR-props-003 | Props reset to authored transforms on restart | ADR-0011 ✅ |
| TR-props-004 | Sleeping props are force-woken on every change | ADR-0001 ✅ |
| TR-props-005 | Props leaving level bounds are freed | ADR-0011 ✅ |
| TR-props-006 | Fall-speed cap; per-prop mass and damping | ADR-0011 ✅ |
| TR-props-007 | Prop count is budgeted and flagged at load | ADR-0003 ✅ |
| TR-props-008 | A room of props at budget holds 60 FPS during a flip | ADR-0011 ✅ |
| TR-props-009 | `PropTuning` knobs and defaults | ADR-0006 ✅ |

ADR-0011 declines to re-claim TR-props-001, -002, -004 and -007. Four of the nine
requirements are therefore satisfied by work that belongs to *other* epics — this
epic consumes their output and adds no guard of its own.

## Validation Criteria

Inherited from ADR-0011. Stories must map onto these rather than invent their own.

| # | Test | Type |
|---|---|---|
| V1 | A `PropBody` at 3 000 px/s in a 2.0× zone reports `linear_velocity.length()` ≤ `prop_max_speed` next frame, at 0° / 90° / 180° / 270° | Logic |
| V2 | A prop falls 200 px at `m` = 1.0 in 0.229 s ± 5%, and the clamp never engages during that fall | Logic |
| V3 | A prop `sleeping` when gravity changes has non-zero `linear_velocity` on the **next** physics frame | Logic |
| V4 | Fall time is identical upward and downward at the same `m`, to float tolerance | Logic |
| V5 | A `PropBody` driven outside `level_bounds` is freed within one physics frame of `body_exited`, and the registry is empty afterwards | Integration |
| V6 | After `reload_current_scene()`, `area_get_param(space, AREA_PARAM_GRAVITY_VECTOR)` equals the new level's `default_gravity_direction` **before** any zone fires | Integration |
| V7 | 40 `PropBody` instances, one scripted 90° flip, frame time across the ease window stays under 16.6 ms | *Performance — gate level undefined* |
| V8 | `validate()` returns `[V-BOUNDS]` when `level_bounds` is unset, and when a `PropBody` starts outside its extent | Integration |
| V9 | After a restart, every `PropBody` global transform equals its authored value, following a flip that scattered them | Integration |

**AC3 / V3 is the one that will actually fail.** `physics-props.md` R5 says so in
those words: a settled `RigidBody2D` sleeps, and a sleeping body ignores a gravity
change. The failure presents as "gravity works, but only sometimes." **Write V3
before the feature.**

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **V7's evidence type is undefined, and ADR-0011 explicitly does not resolve it.** `physics-props.md` types AC10 *Performance*; the test-evidence table in `.claude/docs/coding-standards.md` has no Performance row, so the gate level (BLOCKING vs ADVISORY) is unset | **Decision owed by this epic** | A story must either assign the gate level or record why not. The measurement itself is fully specified by V7. Same shape as the D4.6 CI-grep decision that `collision-layer-registry` carried |
| **V-E2 is the only outstanding engine check** — that a synchronous `PhysicsServer2D.area_set_param` write from `LevelRoot._ready()` lands before the new scene's first physics step (D11.5) | **OPEN** — verify against the 4.7.1 binary | V-E1 and V-E3 were resolved at the 2026-08-16 specialist review against 4.7.1 engine source (`godot_step_2d.cpp:140,151`, `godot_body_2d.cpp:139-147`) |
| **The engine-side cost of a flip is the real budget threat, not the script cost.** Waking 40 bodies moves them all onto the solver's active list, forcing a broadphase AABB refresh, narrow-phase pair regeneration and contact solving for every prop resting on terrain | **Measured, not assumed** | ADR-0011: "V7 exists to measure it, not to confirm a foregone conclusion." Do not treat V7 as a formality |
| **`level_bounds` became a Required `V-WIRING` consumer the moment ADR-0011 was Accepted**, per ADR-0003 D3.3's own rule. Every level must wire it | **Recorded, owned elsewhere** | Belongs to `level-validation` and the level migration epic. `production/epics/index.md` already tracks it. Do not resolve it here |
| **D11.6 specifies the kill plane's correct mask but does not apply it.** ADR-0004's open deferral on `KillArea2D` masking `prop` is closed **with a no** by D11.3 | **Closed as a decision, owned elsewhere** | The application belongs to `collision-layer-registry`. This epic consumes the answer |
| **No props exist in any level.** `systems-index.md:113` records this, and content is deferred by `art-bible.md` §1.3 | **Expected** | Code stories are implementable with authored test fixtures. Content authoring is a Vertical-Slice tier concern |
| **Changing `prop_gravity_scale` away from 1.0 deliberately breaks prop/player fall coherence** — the 1.0× figure is exactly `gravity.md`'s `t_down` | **Guarded by tuning** | ADR-0006 already governs `PropTuning`; the committed value stays 1.0. §4 says a non-1.0 value needs a specific visual reason |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/physics-props.md` are verified
- ADR-0011 validation criteria V1–V6, V8 and V9 have passing tests
- V7's evidence gate level is recorded, either way
- V-E2 is verified against the 4.7.1 binary, or recorded as an accepted limitation
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

`AC11` — "a gravity flip in a prop-furnished room reads as the room turning over" —
is typed **Visual, advisory** by the GDD and needs a human. It cannot be closed
from a session.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | `PropBody` — the scripted rigid body and its registry membership | Logic | Ready | ADR-0011 (D11.1) |
| 002 | The fall-speed cap, clamped inside `_integrate_forces` | Logic | Ready | ADR-0011 (D11.2) |
| 003 | `reset_to()` writes the space parameters synchronously | Integration | Ready | ADR-0011 (D11.5) |
| 004 | `LevelBounds` frees out-of-bounds props | Integration | Ready | ADR-0011 (D11.3) |
| 005 | Restart reset is structural, and runtime spawning is banned | Integration | Ready | ADR-0011 (D11.4) |
| 006 | Flip frame-budget harness, and the AC10 gate-level decision | Integration | Ready | ADR-0011 (V7) |

**Validation coverage**: V1, V2, V4 → story 002. V6 → story 003. V5 → story 004.
V9 → story 005. V7 → story 006. **V3 and V8 have no story here, by design** —
V3 (the force-wake criterion) belongs to `gravity-authority` story 007, and V8
(`validate()` returns `[V-BOUNDS]`) to `level-validation` story 006. This epic
consumes both.

### Two scope corrections made at decomposition

1. **The Overview above overstates this epic's scope.** It claims to implement
   ADR-0001 Changeset B parts 4, 4a and 4b. `gravity-authority` stories 006 and
   007 already own exactly those. What ADR-0011 genuinely adds is **D11.5**, the
   *synchronous* `reset_to()` write, which no gravity-authority story covers —
   that is story 003, and it is the only part of Changeset B claimed here.

2. **D11.1 cannot be pulled forward alone.** `index.md`'s build-order note says
   the D11.1 story by itself clears `LV-006`. `PropBody._ready()` calls
   `GravityAuthority.register_prop()`, and **no `GravityAuthority` autoload
   exists** — `project.godot` registers only `GameManager`. Pulling story 001
   forward pulls `gravity-authority` stories 001 and 007 with it.

## Next Step

Run `/story-readiness production/epics/physics-props/story-001-prop-body-rigid-body-and-registry.md`,
then `/dev-story`. Work through the stories in order — each story's `Depends on:`
field names what must be DONE first.

Note that every story here depends on `gravity-authority`, and stories 004 and 005
also depend on `level-state` and `level-outcomes` respectively. This epic remains
**unblocked but not next-up**, per the Scheduling Note above.
