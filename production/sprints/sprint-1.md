# Sprint 1 — 2026-08-18 to 2026-08-31

> **Stage**: Pre-Production
> **Engine**: Godot 4.7.1
> **Review Mode**: lean (PR-SPRINT producer gate skipped — not a phase gate)
> **Generated**: 2026-08-18
> **Revised**: 2026-08-24 (`/sprint-plan update`)
> **Closed out**: 2026-08-25 — QA verdict **APPROVED WITH CONDITIONS**
> **Retrospective**: `production/retrospectives/retro-sprint-1-2026-08-25.md`
> **Successor**: `production/sprints/sprint-2.md`

**Status at close-out: 20 of 22 rows done, must-have 17 of 19.** The status
column in the tables below was refreshed on 2026-08-25 against
`production/sprint-status-sprint-1.yaml`, which is the archived machine-readable
record for this sprint. `production/sprint-status.yaml` now holds Sprint 2.

The only outstanding work is **CI-1** — one live-fire CI run that closes both
CLR-005 and TUN-006, and that needs a human. See Remaining Work below.

## Sprint Goal

Land the Foundation layer's data and validation base — collision registry,
tuning resources, and level-load validation — so Core epics have something
to build on, and close BUG-0001.

*The goal is unchanged by the 2026-08-24 revision. Both items cut were Should
Have, and the Foundation implementation chain is complete without them.*

## What Changed on 2026-08-24

Three tasks were each one row in the plan while mapping to several story files.
Expanding them to one row per story surfaced three things the rolled-up shape
had hidden:

1. **TUN-2 maps to five story files, not four**, and one of them —
   story 006, CI greps for V6/V7/V8 — **had never been started**. TUN-2 was
   being carried as "blocked on editor checks only", which was not true.
2. **`level-validation/story-005` had no row at all.** It is blocked on the
   level-state epic. It now has one, in Sprint 2.
3. **LV-2 is not unblocked.** Earlier notes said `PropTuning` existing had
   cleared it. `PropTuning` cleared the *first* of its two prerequisites. The
   second is `class_name PropBody` under ADR-0011, and **no epic covers physics
   props** — `index.md` files it under *Not yet epic'd*. LV-2 is unschedulable,
   not merely unstarted.

**GA-1 was cut** to Sprint 2 at the plan's own declared cut line. It was
estimated at 1.75 days as a single task; its seven Ready story files total
22.5 hours ≈ **2.83 days**, a ~60% under-estimate.

Cutting GA-1 and LV-2 brings the sprint inside capacity for the first time:
**5.75 days committed against 8 available**, down from 7.75.

## Capacity

- Total days: 10 (full-time, 2 weeks)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- **Committed after revision: 5.75 days**
- **Elapsed at revision: 4 of 10 working days. Six remain (24–28 Aug, 31 Aug).**

## Task IDs

Rows are now one per story file, keyed `<EPIC>-<NNN>` where `NNN` is the story
file number. Rows without a story file — story-creation runs, the architecture
sweep, the QA plan — keep their original ID.

| Old | New |
|-----|-----|
| CLR-1 … CLR-5 | CLR-001 … CLR-005 *(already 1:1; renamed for consistency)* |
| TUN-1 | TUN-001 |
| TUN-2 | **TUN-002 … TUN-006** |
| LV-1 | **LV-001 … LV-004** |
| LV-2 | LV-006 *(cut to Sprint 2)* |
| — | **LV-005** *(new — had no row)* |
| GA-1 | **GA-001 … GA-007** *(cut to Sprint 2)* |
| ARCH-1, TUN-0, LV-0, GA-0, LS-0, QA-1 | unchanged |

## Tasks

### Must Have (Critical Path) — 5.25 days

| ID | Task | Agent/Owner | Est. Days | Status | Acceptance Criteria |
|----|------|-------------|-----------|--------|---------------------|
| CLR-001 | CollisionLayers registry, correct `project.godot` naming | godot-gdscript-specialist | 0.25 | **done** | Warning-clean; constants match `[layer_names]` |
| CLR-002 | Fix BUG-0001 dead kill-plane masks (levels 05, 06) | gameplay-programmer | 0.25 | **done** | Both levels restart on out-of-bounds fall; BUG-0001 closed |
| CLR-003 | Remove vestigial `PlayerArea2D` and dead platform mask | godot-gdscript-specialist | 0.15 | **done** | Nodes deleted; no behaviour change |
| CLR-004 | Collision layer invariant test suite | qa-tester | 0.40 | **done** | Fails on each ADR-0004 criterion-1 violation |
| CLR-005 | CI grep enforcing the D4.6 runtime-mutation ban | devops-engineer | 0.15 | review | CI step fails on a planted violation |
| ARCH-1 | Sweep `hazards.md` / `level-flow.md` into `tr-registry.yaml` | technical-director | 0.50 | **done** | `TR-hazards-*` and level-flow entries exist |
| TUN-0 | `/create-stories tuning-resources` | producer | 0.25 | **done** | Stories written with TR-ID and ADR-0006 guidance |
| TUN-001 | T4 spike — does `@export_range` clamp a hand-edited `.tres`? | godot-specialist | 0.50 | **done** | Executed against 4.7.1; result recorded |
| TUN-002 | Create the three tuning resource scripts | godot-gdscript-specialist | 0.30 | **done** | Classes registered; `resource_local_to_scene = false` |
| TUN-003 | Author the three tuning `.tres` files | godot-gdscript-specialist | 0.15 | **done** | Knobs match GDD defaults; committed `prop_gravity_scale` stays `1.0` |
| TUN-004 | Create the `Tuning` accessor | godot-gdscript-specialist | 0.15 | **done** | `preload`, not `load`; no autoload |
| TUN-005 | Tuning validation suite | godot-gdscript-specialist | 0.30 | **done** | V1–V4 and V9 pass headless |
| TUN-006 | **CI greps for V6, V7 and V8** | devops-engineer | 0.20 | review | CI step fails on a planted violation |
| LV-0 | `/create-stories level-validation` | producer | 0.25 | **done** | Stories written |
| LV-001 | Validation scaffold and discovery | gameplay-programmer | 0.30 | **done** | Seven codes declared; discovery finds nodes at any depth and with no owner |
| LV-002 | `V-BUCKET-SUM` and `V-PLANT-MIN` | gameplay-programmer | 0.30 | **done** | Both mismatch directions fire; `V-PLANT-MIN` reports per plant |
| LV-003 | `V-OXY-CAP` and `V-GRAV-EXPORT` | gameplay-programmer | 0.30 | **done** | Absent export is a breach, not a skip |
| LV-004 | `V-WIRING` and the required-consumer table | gameplay-programmer | 0.30 | **done** | Four rows; both authoring shapes resolve |
| QA-1 | `/qa-plan sprint` | qa-lead | 0.25 | **done** | Test cases defined per story — `production/qa/qa-plan-sprint-1.md` |

**QA-1 was promoted from Nice-to-Have to Must Have on 2026-08-24.** This
sprint's Definition of Done requires `production/qa/qa-plan-sprint-1.md`. A
Nice-to-Have that the DoD depends on makes the DoD unsatisfiable by definition.

### Should Have — 0.25 days

| ID | Task | Agent/Owner | Est. Days | Status | Acceptance Criteria |
|----|------|-------------|-----------|--------|---------------------|
| GA-0 | `/create-stories gravity-authority` | producer | 0.25 | **done** | Stories written; `TR-gravity-008` recorded as parked |

### Nice to Have — 0.25 days

| ID | Task | Agent/Owner | Est. Days | Status | Acceptance Criteria |
|----|------|-------------|-----------|--------|---------------------|
| LS-0 | `/create-stories level-state` | producer | 0.25 | **done** | Stories written |

## Remaining Work: 0.35 Days, and It Needs a Human

*Updated 2026-08-25 at close-out. Every agent-doable row is done.*

| ID | Task | Est. Days | Who |
|----|------|-----------|-----|
| CLR-005 | AC-5 — a live CI run with a planted D4.6 violation | 0.15 | **Human** |
| TUN-006 | Final AC — the same run, four planted tuning violations | 0.20 | **Human** |
| | **Total** | **0.35** | |

Both are one action. It is carried into Sprint 2 as **CI-1** and is the only
thing standing between this project and `/gate-check production`.

**Mechanics matter.** The workflow fires on push to `development` or `main`, or
on a pull request targeting them. **A scratch branch pushed on its own will not
fire it.** There is no `gh` CLI on this machine, so opening a PR is a web-UI
action by the developer. The trigger was widened from `main` to `development` on
2026-08-25 in `d77337c` — before that it had never fired once, because this
repository has no `main` branch at all.

### The four human-only checks — three of four are now closed

They were parked in `production/qa/smoke-2026-08-24.md`:

- **CLR-002 AC-5** — **CLOSED 2026-08-25.** Developer playtest of the
  out-of-bounds fall in levels 05 and 06. BUG-0001 closed on the same sign-off.
  Evidence: `production/qa/evidence/bug-0001-killplane-playtest-2026-08-25.md`
- **CLR-003 AC-5** — **CLOSED 2026-08-25.** Items 1–2 by headless probe, items
  3–4 directly in the playtest. Annotated METHOD SUBSTITUTED, not reworded.
- **TUN-003 / TUN-002** — **CLOSED 2026-08-25** by a headless probe reading the
  same `@export_range` hint metadata the inspector renders from. Annotated
  METHOD SUBSTITUTED.
- **CLR-005 AC-5** — **OPEN.** The CI run above. The only survivor.

The windowed Godot editor **still segfaults on this machine**. The route around
it is the read-only headless probe recorded in
`production/qa/evidence/editor-facts-probe-2026-08-25.md`. It proves the data,
not the rendering, and says so explicitly. Reuse it rather than re-deriving it.

## Cut to Sprint 2 (2026-08-24, statuses refreshed 2026-08-25)

| ID | Task | Est. Days | Blocker |
|----|------|-----------|---------|
| GA-002 … GA-007 | GravityAuthority epic — easing, player consumer, zones, level defaults, space-gravity write, prop registry | **2.39** | ARCH-1, done 2026-08-24. **GA-001 was NOT cut** — it landed in `783953b` and carries its own done row above |
| LV-005 | Wire `validate()` into `LevelRoot._ready()` at step (a) | 0.31 | The level-state epic must land first. Scheduled Sprint 2 behind LS-004 |
| LV-006 | `V-PROP-BUDGET` and `V-BOUNDS` (was LV-2) | 0.31 | **CORRECTED 2026-08-25** — the earlier blocker, "`class_name PropBody`, and ADR-0011 has no epic", is stale. The `physics-props` epic was created 2026-08-24 in `c53c421` and decomposed in `4c5572c`. This is sequencing, not a design gap: it needs PP-001, which needs GA-007 |

All three are scheduled in `production/sprints/sprint-2.md`. The per-story GA
breakdown is preserved in `production/sprint-status-sprint-1.yaml`, the archived
Sprint 1 record, so the derived estimate is not re-discovered a third time.

## Carryover from Previous Sprint

None — this is Sprint 1.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| The remaining critical path is human-only and the windowed editor segfaults | High | High | Four checks parked in `production/qa/smoke-2026-08-24.md`. No agent can clear them. This is the single largest threat to closing the sprint |
| ADR-0011 has no epic, so LV-006 is unschedulable | High | Medium | Create the physics-props epic during Sprint 2 planning, before LV-006 is quoted again |
| ADR-0003 D3.3 now makes a HUD **and** a bounds area mandatory on every level | Medium | High | Landed 2026-08-24 via the D3.3 amendment. The level migration epic must author both before Validation Criterion 5 can close — a real scope increase on an unplanned epic |
| CI still triggers on `main`; this repo's main branch is `development` | High | Medium | Widening the trigger was ruled out of scope by the developer. **A live decision, not a closed one** — CLR-005 cannot close without a real run |
| A red CI run under-reports — the suite stops at the first failure | Medium | Medium | `tests/README.md:52` — the local runner needs `-c`. CI uses `MikeSchulze/gdUnit4-action@v1` instead, so it needs its own fix |
| gdUnit4 fails the whole suite on one GDScript warning | High | Medium | Warning-clean gate on every new script before commit. Hit again on 2026-08-24 during a scratch probe |
| Rolled-up yaml rows hid unstarted work | — | — | **Closed** by the 2026-08-24 per-story expansion |
| No milestone document exists to trace this sprint to | High | Low | Foundation completion is the implied milestone; formalise it in Sprint 2 |

### Retired risks

| Risk | Outcome |
|------|---------|
| T4 spike disproves the `@export_range` clamp assumption | **Materialised and closed.** T4 is VERIFIED TRUE — `@export_range` neither clamps nor rejects a hand-edited `.tres`. Every `@export_range` is an inspector hint, not a validator. Clamp in code where it matters. Evidence: `production/qa/evidence/t4-export-range-clamp-spike.md` |
| ADR-0006 rates HIGH engine-risk with no `modules/core.md` reference | **Closed.** APIs verified against the 4.7 docs; the epic landed |
| GA-1 slips — gravity is the largest single item | **Materialised.** Cut to Sprint 2 at the declared cut line |
| Must Have + Should Have consume 7.75 of 8 available days | **Closed** by the 2026-08-24 cut — now 5.75 of 8 |

## Dependencies on External Factors

- A human playtest is needed for CLR-002 (levels 05 and 06, out-of-bounds fall).
- A human must perform the CLR-003 and TUN-002/TUN-003 editor checks. The
  windowed editor segfaults on this machine.
- A real CI run is needed for CLR-005, on a branch the workflow actually fires on.
- The Godot 4.7.1 binary must be reachable for headless runs.

## Scope Boundaries

Deferred to Sprint 2 and stated here so they are not pulled in silently:

- `gravity-authority` implementation (GA-001…GA-007) — cut 2026-08-24
- `level-state` implementation (story creation only is Nice to Have this sprint)
- A **physics-props epic** for ADR-0011 — does not exist, and LV-006 needs it
- `player-core`, `oxygen-drain`, `level-outcomes` (Core layer)
- Hazards, Watering, HUD, Pause Menu, moving platforms (Feature and Presentation runs)

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed — **17 of 19.** CLR-005 and TUN-006 both wait on CI-1
- [ ] All tasks pass acceptance criteria — the same two rows, and no others
- [x] QA plan exists (`production/qa/qa-plan-sprint-1.md`) — **QA-1**, done 2026-08-24
- [x] All Logic/Integration stories have passing unit/integration tests — 178/178, 11/11 suites, exit 0 (2026-08-25)
- [x] Smoke check passed — `production/qa/smoke-2026-08-25.md`, zero missing test evidence
- [x] QA sign-off report: **APPROVED WITH CONDITIONS** — `production/qa/qa-signoff-sprint-1-2026-08-25.md`
- [x] No S1 or S2 bugs in delivered features — BUG-0001 closed 2026-08-25 on developer playtest sign-off. BUG-0002 is S4 and deferred
- [x] Design documents updated for any deviations — four ACs annotated (TUN-003 AC-4/5/6, CLR-003 AC-5, LV-001 AC-3, GA-002 AC-1). No requirement was reworded
- [ ] Code reviewed and merged — **reviewed, not merged.** Nothing has been pushed — `vertical-slice` is many commits ahead of `origin` (re-derive the count). CI-1 will be the first push

**Code review status:** the owed review over `collision_layers.gd`,
`level_validation.gd` and their five test files was run in one pass on
2026-08-24. Verdict **APPROVED WITH SUGGESTIONS** — no blocking findings, no
architectural violation. CLR-001/CLR-004's deferred review and LV-001…LV-004's
owed review are both discharged.
