# Epics Index

Last Updated: 2026-08-24
Engine: Godot 4.7.1
Control Manifest Version: 2026-08-17

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Gravity Authority](gravity-authority/EPIC.md) | Foundation | Gravity | `gravity.md` | 7 stories | Ready |
| [Level State Ownership](level-state/EPIC.md) | Foundation | Watering / Suit Oxygen | `watering-system.md`, `suit-oxygen.md` | 6 stories | Ready |
| [Level Load Validation](level-validation/EPIC.md) | Foundation | Watering / Suit Oxygen / Physics Props | `watering-system.md`, `suit-oxygen.md`, `physics-props.md` | 6 stories | Ready |
| [Collision Layer Registry](collision-layer-registry/EPIC.md) | Foundation | Physics Props | `physics-props.md` | 5 stories | Ready |
| [Tuning Resources](tuning-resources/EPIC.md) | Foundation | Watering / Suit Oxygen / Physics Props | `watering-system.md`, `suit-oxygen.md`, `physics-props.md` | 6 stories | Ready |
| [Player Core](player-core/EPIC.md) | Core | Gravity (player share) | `gravity.md` | 6 stories | Ready |
| [Oxygen Drain](oxygen-drain/EPIC.md) | Core | Suit Oxygen | `suit-oxygen.md` | 6 stories | Ready |
| [Level Outcomes](level-outcomes/EPIC.md) | Core | Level Flow | `level-flow.md` | 7 stories | Ready |
| [Physics Props](physics-props/EPIC.md) | Presentation | Physics Props | `physics-props.md` | 6 stories | Ready — scheduling deferred |

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
frozen. **The traceability half of that is closed.** The 2026-08-24 ARCH-1 sweep
allocated `TR-flow-001`–`010` and `TR-hazards-001`–`012`, taking the baseline from
52 to 74. The layer disagreement below is unchanged.

| Source | Core membership |
|---|---|
| `systems-index.md` Core tier | Watering · Suit Oxygen · Level Flow · Hazards |
| `architecture.md` CORE layer | `Player` facade · 4 player components · `OxygenDrain` |

Resolution taken: `player-core` and `oxygen-drain` follow the architecture.
`level-outcomes` was added for `level-flow.md` because ADR-0005 and ADR-0014 both
cover it and the work is fully specified. **Hazards is deferred to the Feature
run** — `architecture.md` places `SpikeHazard` / `KillArea` in Feature, the GDD is
still pending `/design-review`, and it has no ADR at all.

### Presentation

`physics-props` is the first Presentation-tier epic, created 2026-08-24. It is
well-formed and has **no untraced requirements** — all nine `TR-props-*` IDs trace
to an Accepted ADR — but **its content is deferred to Vertical-Slice tier** by
`art-bible.md` §1.3, and ADR-0011 carries a matching Implementation Scope Note.
Read it as unblocked-but-not-next-up rather than as ready to schedule whole.

Four of its nine requirements are satisfied by other epics. ADR-0011 deliberately
declines to re-claim `TR-props-001`, `-002`, `-004` and `-007`, which ADR-0001,
ADR-0004 and ADR-0003 already cover, so `physics-props` consumes their output and
adds no guard of its own.

`HUD / Pause Menu` remains the other Presentation system, still un-epic'd.

**A third Presentation module is referenced by name and does not exist.** `gravity-authority` story 003 and this index's requirement-split note both defer TR-gravity-013 to "the Presentation visual epic" (`PlayerVisualComponent`). No such epic has been created. Found during `player-core` decomposition on 2026-08-24 — see the two new rows in the open-risk table above.

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
4. **`physics-props` story 001 before `LV-006`.** `LV-006` is *unschedulable*, not
   merely unstarted: it needs `class_name PropBody` to exist, and no other epic
   delivers it. Story 001 clears that, ahead of any prop content — so this one
   story can be pulled forward without pulling the whole epic forward.
   **Corrected 2026-08-24 at decomposition**: it is not free. `PropBody._ready()`
   calls `GravityAuthority.register_prop()`, and no `GravityAuthority` autoload
   exists — `project.godot` registers only `GameManager`. Pulling story 001
   forward pulls `gravity-authority` stories 001 and 007 with it.

Suggested order: `collision-layer-registry` → `tuning-resources` →
`level-validation` → `gravity-authority` → `level-state` → `player-core` →
`oxygen-drain` → `level-outcomes`. `physics-props` sits after all of these, with
the D11.1 exception noted above.

## Open risks carried by these epics

| Item | Epic | Status |
|---|---|---|
| ADR-0006 T4 — `@export_range` does not clamp a hand-edited `.tres` | `tuning-resources` | **CLOSED 2026-08-24** — executed against the 4.7.1 binary; the claim held |
| ADR-0001 Verification 2 — a default-space gravity write in `_physics_process` reaches every `RigidBody2D` in the same step | `gravity-authority` | **OPEN** — confirm at implementation |
| ADR-0004 F8 — the registry guarantees authored state only, not runtime mutation | `collision-layer-registry` | **Decided** — story 005 adds a CI grep step |
| ADR-0003 D3.3's printed `V-WIRING` table is stale — `hud` still reads "not required" and `level_bounds` is absent, though ADR-0010 and ADR-0011 are both Accepted | `level-validation` | **Doc lag** — D3.3's own admission rule resolves it; story 004 implements four rows, a doc-only ADR amendment is owed |
| `V-WIRING` has no TR-ID, and neither does `V-BOUNDS` | `level-validation` | **CLOSED 2026-08-24 (ARCH-1) — as an exception, not by back-filling.** `V-BOUNDS` traces through its GDD source to `TR-props-005` (`physics-props.md` R7) and `V-PROP-BUDGET` to `TR-props-007` (R8, §5); both already existed. `V-WIRING` gets no ID and should not get one — its source is an ADR-0002 delegation, and `tr-registry.yaml`'s own SCOPE rule admits GDD-derived requirements only |
| `V-HAZARD-MASK` and `V-HAZARD-SPAWN` are owed and absent from ADR-0003's seven-rule set | `level-validation` / *(Hazards)* | **OPEN** — `TR-hazards-011` / `TR-hazards-012`. Route decided 2026-08-24: a hazards ADR adds them to D3.3 in the same changeset, the mechanism ADR-0011 D11.7 used for `V-BOUNDS`. ADR-0003 is **not** reopened now. `V-HAZARD-SPAWN` also needs the headless extent read verified first — same 4.7.1 unknown as `V-BOUNDS` |
| Reading an `Area2D` extent headlessly, on a node instantiated but never added to a tree, is unverified — not covered by ADR-0003 E1–E3 | `level-validation` | **OPEN** — verify against the 4.7.1 binary in story 006 |
| ADR-0008 — the `LevelRoot`-ancestor `process_mode` invariant has no automated check | `oxygen-drain` | **OPEN** — scene test owed once a pause menu exists |
| ADR-0008's Key Interfaces block declares `class_name OxygenAccessibility` on a node whose autoload singleton name is also `OxygenAccessibility`. ADR-0001 bans exactly this shape on `gravity_authority.gd` and the manifest carries that ban, but there is **no oxygen equivalent** in the manifest | `oxygen-drain` | **Flagged, not amended, 2026-08-24** — story 001 follows ADR-0001 and the prototype (which already omits `class_name`) and verifies the collision behaviour against the 4.7.1 binary. If the check confirms a hard conflict, the mechanism is a registry supersession entry or a manifest rule, not an edit to ADR-0008 |
| `control-manifest.md` extracts **no rule from ADR-0014**, and its header is stale for ADR-0013 | *(cross-epic)* / `oxygen-drain` | **OPEN — `/create-control-manifest update` is owed.** Investigated 2026-08-24: the body cites ADR-0013 at two places, added by commit `584e1d8` without regenerating the header or bumping `Manifest Version`; ADR-0014 is cited **nowhere** (loose grep for `0014`, "pause gating", "terminal sequence" → zero hits). So this is a real regeneration, not the header edit it was first assumed to be. Bites `oxygen-drain` story 006, which has an Accepted governing ADR with no manifest rule to quote. Every story to date embeds `Manifest Version: 2026-08-17`, which `/story-readiness` checks against |
| `level-flow.md` R10 — what follows the final level | `level-outcomes` | **BLOCKED** — design decision owed. Now has a named home: **story 007**, written Blocked with no acceptance criteria and no test path, so the gap stays visible rather than living only in a risk table. The not-blocked half (advance to the next authored level) is story 006 |
| `complete_hold_duration` ⚠ unset (0.6 s proposed, 0.2–1.5 s range) | `level-outcomes` | **OPEN** — needs a human playtest, not an agent one. Carried by **story 004**, which exports the value at the 0.6 s proposal and forbids recording it as chosen; evidence path `production/qa/evidence/complete-hold-duration-playtest.md` |
| No `pause` action exists in `project.godot` | `level-outcomes` | **Blocked** on `design/ux/pause-menu.md`. **Story 003** builds the `PauseController` mechanism and binds no action — the lock and the sole-writer rule are exercised by calling the methods directly |
| TR-gravity-010 — camera-follow / camera-rotation split specified but not applied (ADR-0013 D13.5) | `gravity-authority` | **Blocked** on a human playtest of `level_01` and `level_07` |
| TR-watering-002 — carry scales `max_speed` only; ADR-0007 explicitly declines it | *(Feature watering)* | **GAP** — no accepted ADR owns the mechanism |
| `PlayerWallJumpComponent` — no GDD, no TR IDs, no ADR (QQ-05) | `player-core` | **Unowned** — behaviour stories are Blocked |
| TR-gravity-013 — `apply_screen_relative_axis` had **no owning story in any epic**. ADR-0013's step 1 puts it on `GravityAuthority` (Foundation), but no `gravity-authority` story adds it, and that epic's story 003 routes ADR-0013 to a "Presentation visual-component epic" that does not exist | `player-core` (absorbed) / *(Presentation visual)* | **Half-owned by decision, 2026-08-24** — `player-core` story 005 takes the Foundation static function and the `PlayerMovementComponent` caller. The `PlayerVisualComponent` caller stays unowned until a Presentation visual epic exists; **TR-gravity-013 does not close until then** |
| ADR-0013's supersession is scoped to "the method contract of ADR-0007 D7.4 only", but D7.3's code block also passes `camera_rotation_enabled` at its step 6 and step 8 call sites | `player-core` | **Flagged, not amended** — story 005 changes those call sites to `camera_rotation`. Neither ADR is edited; recorded here so the change is not read as drift |
| `level-flow.md` has no TR IDs; traces by rule anchor | `level-outcomes` | **CLOSED 2026-08-24 (ARCH-1)** — `TR-flow-001`–`010`, one per rule R1–R10. 8 of 10 entered already covered by ADR-0005, ADR-0014 and ADR-0002. The two that did not are `TR-flow-005` (HUD element, Presentation) and `TR-flow-010` (R10, the blocked decision already on this table) |
| ADR-0011 V-E2 — a synchronous `PhysicsServer2D.area_set_param` write from `LevelRoot._ready()` lands before the new scene's first physics step | `physics-props` | **OPEN** — story 003 discharges it against the 4.7.1 binary. Named fallback exists (a dirty flag consumed by the authority's `_physics_process`, costing one frame of stale space gravity at load) |
| AC10's evidence gate level is undefined — `coding-standards.md`'s table has no Performance row, and this is the **second** instance (ADR-0012 recorded the same for `watering-system.md`) | `physics-props` | **OPEN — decision owed** — story 006 AC-1. ADR-0011 notes the repeat suggests the standards table, not the two GDDs, is what needs the edit |
| Settings system — remapping, presets, text scaling; no GDD, no ADR, no menu code | *(unassigned)* | **Unowned** — largest hidden cost per the 2026-08-17 Producer gate |
| TR-gravity-008 — `zone_priority` overlap resolution | `gravity-authority` | **Parked** by design; no story |

## Not yet epic'd

| System | Layer per architecture.md | Why not yet |
|---|---|---|
| Watering | Feature | Feature run. Blocked on `level-state`. |
| Hazards | Feature | No ADR; GDD pending `/design-review`; records 3 code defects to fix. `TR-hazards-001`–`012` allocated 2026-08-24, and **10 of the 12 are unowned** — the largest block of unowned requirements in the registry. Sequence: `/design-review` first, then the ADR, then the epic. The rule numbering those IDs anchor to is not stable until the review runs. |
| HUD / Pause Menu | Presentation | Presentation run, under ADR-0010 and ADR-0014. |
| Moving platforms | Feature | Implemented, undocumented. No GDD, no TRs, no ADR. |

## Next Step

Run `/create-stories [epic-slug]` for each epic above before developers pick up work.

Foundation and Core are both required for the Pre-Production → Production gate.
Run `/gate-check production` to check readiness.
