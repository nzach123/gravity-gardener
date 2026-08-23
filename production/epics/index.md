# Epics Index

Last Updated: 2026-08-23
Engine: Godot 4.7.1
Control Manifest Version: 2026-08-17

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Gravity Authority](gravity-authority/EPIC.md) | Foundation | Gravity | `gravity.md` | 7 stories | Ready |
| [Level State Ownership](level-state/EPIC.md) | Foundation | Watering / Suit Oxygen | `watering-system.md`, `suit-oxygen.md` | Not yet created | Ready |
| [Level Load Validation](level-validation/EPIC.md) | Foundation | Watering / Suit Oxygen / Physics Props | `watering-system.md`, `suit-oxygen.md`, `physics-props.md` | 6 stories | Ready |
| [Collision Layer Registry](collision-layer-registry/EPIC.md) | Foundation | Physics Props | `physics-props.md` | 5 stories | Ready |
| [Tuning Resources](tuning-resources/EPIC.md) | Foundation | Watering / Suit Oxygen / Physics Props | `watering-system.md`, `suit-oxygen.md`, `physics-props.md` | 6 stories | Ready |
| [Player Core](player-core/EPIC.md) | Core | Gravity (player share) | `gravity.md` | Not yet created | Ready |
| [Oxygen Drain](oxygen-drain/EPIC.md) | Core | Suit Oxygen | `suit-oxygen.md` | Not yet created | Ready |
| [Level Outcomes](level-outcomes/EPIC.md) | Core | Level Flow | `level-flow.md` | Not yet created | Ready |

## Scoping notes

### Foundation

`systems-index.md` lists one Foundation-tier system (Gravity). `architecture.md`
§System Layer Map lists six Foundation modules. Epics follow the **architecture**,
because the five non-Gravity modules hold requirements that Core systems depend on,
and because the skill unit is one epic per architectural module.

`LevelRoot` appears in the `level-state` epic for state construction and injection
only. Its restart path, level transition and terminal sequences belong to
`level-outcomes`.

### Core

The two source documents disagree, because `level-flow.md` and `hazards.md` were
authored 2026-08-17 — after `architecture.md` v1.0 and after the 52-TR baseline was
frozen.

| Source | Core membership |
|---|---|
| `systems-index.md` Core tier | Watering · Suit Oxygen · Level Flow · Hazards |
| `architecture.md` CORE layer | `Player` facade · 4 player components · `OxygenDrain` |

Resolution taken: `player-core` and `oxygen-drain` follow the architecture.
`level-outcomes` was added for `level-flow.md` because ADR-0005 and ADR-0014 both
cover it and the work is fully specified. **Hazards is deferred to the Feature
run** — `architecture.md` places `SpikeHazard` / `KillArea` in Feature, the GDD is
still pending `/design-review`, and it has no ADR at all.

### Requirement splits across layers

- **Gravity's 13 TRs span three layers.** `gravity-authority` (Foundation) takes
  001, 002, 003, 009, 011, 012. `player-core` (Core) takes 004–007. TR-gravity-013
  belongs to the Presentation visual epic.
- **Watering and Oxygen TRs are split by module**, not kept whole per GDD. Their
  Foundation shares sit in `level-state`, `level-validation` and `tuning-resources`.

## Recommended build order

Hard ordering constraints, each stated in the ADRs themselves:

1. **`tuning-resources` before `level-validation` completes.** `V-PROP-BUDGET`
   reads `PropTuning.props_per_level_budget` (ADR-0003 Ordering Note).
2. **`level-state` before `oxygen-drain`**, and before the Feature watering epic
   and the Presentation HUD epic. ADR-0002 blocks all three by name.
3. **`gravity-authority` before `player-core`.** The components read the authority
   rather than holding a gravity field, and the mandatory init-order guard lives in
   the authority (architecture.md QQ-02).

Suggested order: `collision-layer-registry` → `tuning-resources` →
`level-validation` → `gravity-authority` → `level-state` → `player-core` →
`oxygen-drain` → `level-outcomes`.

## Open risks carried by these epics

| Item | Epic | Status |
|---|---|---|
| ADR-0006 T4 — `@export_range` does not clamp a hand-edited `.tres`; verified from documentation only, never executed | `tuning-resources` | **OPEN** — execute against the 4.7.1 binary |
| ADR-0001 Verification 2 — a default-space gravity write in `_physics_process` reaches every `RigidBody2D` in the same step | `gravity-authority` | **OPEN** — confirm at implementation |
| ADR-0004 F8 — the registry guarantees authored state only, not runtime mutation | `collision-layer-registry` | **Decided** — story 005 adds a CI grep step |
| ADR-0003 D3.3's printed `V-WIRING` table is stale — `hud` still reads "not required" and `level_bounds` is absent, though ADR-0010 and ADR-0011 are both Accepted | `level-validation` | **Doc lag** — D3.3's own admission rule resolves it; story 004 implements four rows, a doc-only ADR amendment is owed |
| `V-WIRING` has no TR-ID, and neither does `V-BOUNDS` | `level-validation` | **Traceability gap** — extend `tr-registry.yaml` or record the exception; do not back-fill during implementation |
| Reading an `Area2D` extent headlessly, on a node instantiated but never added to a tree, is unverified — not covered by ADR-0003 E1–E3 | `level-validation` | **OPEN** — verify against the 4.7.1 binary in story 006 |
| ADR-0008 — the `LevelRoot`-ancestor `process_mode` invariant has no automated check | `oxygen-drain` | **OPEN** — scene test owed once a pause menu exists |
| `level-flow.md` R10 — what follows the final level | `level-outcomes` | **BLOCKED** — design decision owed |
| `complete_hold_duration` ⚠ unset (0.6 s proposed, 0.2–1.5 s range) | `level-outcomes` | **OPEN** — needs a human playtest, not an agent one |
| No `pause` action exists in `project.godot` | `level-outcomes` | **Blocked** on `design/ux/pause-menu.md` |
| TR-gravity-010 — camera-follow / camera-rotation split specified but not applied (ADR-0013 D13.5) | `gravity-authority` | **Blocked** on a human playtest of `level_01` and `level_07` |
| TR-watering-002 — carry scales `max_speed` only; ADR-0007 explicitly declines it | *(Feature watering)* | **GAP** — no accepted ADR owns the mechanism |
| `PlayerWallJumpComponent` — no GDD, no TR IDs, no ADR (QQ-05) | `player-core` | **Unowned** — behaviour stories are Blocked |
| `level-flow.md` has no TR IDs; traces by rule anchor | `level-outcomes` | **Traceability gap** — extend `tr-registry.yaml` or record the exception |
| Settings system — remapping, presets, text scaling; no GDD, no ADR, no menu code | *(unassigned)* | **Unowned** — largest hidden cost per the 2026-08-17 Producer gate |
| TR-gravity-008 — `zone_priority` overlap resolution | `gravity-authority` | **Parked** by design; no story |

## Not yet epic'd

| System | Layer per architecture.md | Why not yet |
|---|---|---|
| Watering | Feature | Feature run. Blocked on `level-state`. |
| Physics Props | Presentation | Presentation run. Content deferred to Vertical-Slice tier by `art-bible.md` §1.3. |
| Hazards | Feature | No ADR; GDD pending `/design-review`; records 3 code defects to fix. |
| HUD / Pause Menu | Presentation | Presentation run, under ADR-0010 and ADR-0014. |
| Moving platforms | Feature | Implemented, undocumented. No GDD, no TRs, no ADR. |

## Next Step

Run `/create-stories [epic-slug]` for each epic above before developers pick up work.

Foundation and Core are both required for the Pre-Production → Production gate.
Run `/gate-check production` to check readiness.
