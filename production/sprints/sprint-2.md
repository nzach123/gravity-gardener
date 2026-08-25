# Sprint 2 — 2026-09-01 to 2026-09-14

> **Stage**: Pre-Production
> **Engine**: Godot 4.7.1
> **Review Mode**: lean (PR-SPRINT producer gate skipped — not a phase gate)
> **Generated**: 2026-08-25
> **Retrospective input**: `production/retrospectives/retro-sprint-1-2026-08-25.md`

## Sprint Goal

Complete the Foundation layer — finish the gravity authority, land level and
oxygen state ownership, and close the two CI guards Sprint 1 could not verify —
so the Core layer has an unblocked base and `/gate-check production` can be run
honestly.

## Capacity

- Total days: 10 (Sep 1–4, 7–11, 14)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- **Committed: 6.26 days**

Sprint 1 delivered 5.84 estimate-days. Must Have alone is 4.88 — below that
proven figure. The Should Have and Nice to Have tail is the declared cut line.

Estimates convert story sizes at 8 h per day, the same convention Sprint 1 used.

## Corrections to the Sprint 1 handoff, verified 2026-08-25

Two statements carried forward from Sprint 1 were re-derived and are wrong:

1. **"No epic covers physics props."** The `physics-props` epic exists —
   created 2026-08-24 in `c53c421`, decomposed into six stories in `4c5572c`.
   `production/epics/physics-props/story-001-prop-body-rigid-body-and-registry.md`
   delivers `class_name PropBody`. **LV-006 is therefore schedulable**, and it is
   scheduled below.
2. **"LV-006 needs only `PropBody`."** `index.md`'s corrected build note is the
   accurate one: `PropBody._ready()` calls `GravityAuthority.register_prop()`,
   so PP-001 pulls `gravity-authority` stories 001 (done) and **007** with it.
   GA-007 is Must Have here, ahead of PP-001.

## Tasks

### Must Have (Critical Path) — 4.88 days

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| CI-1 | Live-fire CI run: five deliberate violations (D4.6 mask mutation; V6 path literal; V7 assignment; V7 `.duplicate()`; V8 GravityTuning script), each confirmed red, then reverted | developer + devops-engineer | 0.35 | **Human** — a PR against `development` or a direct push | Each check observed red with a readable message; the GdUnit4 step still runs or is correctly short-circuited; closes CLR-005 AC-5 and TUN-006's final AC |
| GA-002 | Direction easing and the exported rate | godot-gdscript-specialist | 0.31 | GA-001 (done) | Settles within 100 ms at the 2.5° threshold set in `41ea6fd` |
| GA-003 | Player gravity component becomes a consumer | godot-gdscript-specialist | 0.50 | GA-002 | No private gravity copy; the component reads the authority |
| GA-004 | Zones report to the authority; clear the `Area2D` override | godot-gdscript-specialist | 0.38 | GA-003 | No zone writes to the player; ADR-0001 R9 holds |
| GA-005 | Level default gravity and reset on load | godot-gdscript-specialist | 0.38 | GA-004 | Reset fires on every level load |
| GA-006 | Default-space gravity write | godot-gdscript-specialist | 0.44 | GA-005 | **Discharges ADR-0001 Verification 2** against the 4.7.1 binary |
| GA-007 | Prop registry and the force-wake pass | godot-gdscript-specialist | 0.38 | GA-006 | Registry accepts and releases; the wake pass reaches every registered body |
| LS-001 | `LevelState` object | gameplay-programmer | 0.38 | ADR-0002 | Injectable, no singleton |
| LS-002 | `OxygenState` object | gameplay-programmer | 0.44 | LS-001 | Injectable; ADR-0008 drain contract |
| LS-003 | Frame priority contract | gameplay-programmer | 0.13 | LS-002 | The documented order is enforced by a test |
| LS-004 | `LevelRoot` construction and injection | gameplay-programmer | 0.50 | LS-003 | Both states constructed at step (a) |
| LS-005 | `level_complete` latch | gameplay-programmer | 0.38 | LS-004 | The ADR-0005 guard holds; the latch is one-way |
| LS-006 | Restart is reconstruction | gameplay-programmer | 0.31 | LS-005 | No state survives a restart |

The GA and LS tracks are independent of each other and can run side by side.
Only PP-001, LV-005 and LV-006 need both.

### Should Have — 0.93 days

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| PP-001 | `PropBody` RigidBody and registry | godot-gdscript-specialist | 0.31 | **GA-007** | `class_name PropBody` exists; registers on ready, releases on free |
| LV-005 | Wire `validate()` into `LevelRoot._ready()` at step (a) | gameplay-programmer | 0.31 | **LS-004** | The ordering against state construction is asserted, not assumed |
| LV-006 | `V-PROP-BUDGET` and `V-BOUNDS` rules | gameplay-programmer | 0.31 | **PP-001** + LV-005 | Both rules fire; the headless `Area2D` extent read is verified against 4.7.1 |

### Nice to Have — 0.45 days

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| BUG-0002 | Rename the `MovingPlatfornm` root node | gameplay-programmer | 0.05 | Sequenced **after** anything depending on CLR-003's playtest | Root renamed in `moving_platform.tscn` and its four level instances; suite green |
| PROC-1 | Retrospective action items 2–5 | producer | 0.15 | Retro (done) | DoD live-fire clause, per-story effort logging, code-review margin check, and tech-debt owners plus a Closed section all landed |
| DEBT-1 | Repay three zero-cost tech-debt items | godot-gdscript-specialist | 0.25 | — | `MIN_TILEMAP_LAYERS` margin, the `_layer_name()` bit-versus-number comment, and the `push_error`/`push_warning` comment; entries moved to Closed; suite green |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| CLR-005 | AC-5 needs a live CI run. A scratch branch pushed on its own does not trigger the workflow | 0.15 — folded into CI-1 |
| TUN-006 | The final AC needs the same run, four violations | 0.20 — folded into CI-1 |
| GA-002…GA-007 | Cut 2026-08-24 at the Sprint 1 plan's declared cut line | 2.39 |
| LV-005 | Was blocked on the level-state epic. **Unblocks inside this sprint** at LS-004 | 0.31 |
| LV-006 | Was recorded unschedulable. **That record is stale** — see Corrections above | 0.31 |
| BUG-0002 | S4, deliberately deferred so it could not invalidate CLR-003's sign-off | 0.05 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| CI-1 needs a human web-UI action; there is no `gh` CLI on this machine | High | **High** | Do it in week 1, not at close-out. It is the only thing standing between this project and `/gate-check production` |
| GA-006 carries an OPEN engine verification — ADR-0001 Verification 2, whether a default-space write reaches every `RigidBody2D` in the same step | Medium | High | Verify against the 4.7.1 binary before building on it. A named fallback exists: a dirty flag consumed by the authority's `_physics_process`, costing one frame of stale space gravity at load |
| The windowed Godot editor still segfaults | High | Medium | Reuse the headless probe recorded in `production/qa/evidence/editor-facts-probe-2026-08-25.md`. Do not quote an "open the editor" AC without a substitution plan |
| `control-manifest.md` is stale at version 2026-08-17 — ADR-0014 is cited nowhere and the ADR-0013 header was never bumped. `/story-readiness` checks a story's embedded version | Medium | Medium | Does not bite this sprint's scope: GA cites ADR-0001, LS cites ADR-0002 and ADR-0005. **It bites `oxygen-drain` story 006.** Run `/create-control-manifest update` before Sprint 3 |
| gdUnit4 fails the whole suite on one GDScript warning | High | Medium | Warning-clean gate on every new script before commit |
| A red CI run under-reports — the local runner stops at the first failure without `-c`, and CI uses `MikeSchulze/gdUnit4-action@v1`, which needs its own fix | Medium | Medium | Confirm CI-1 surfaces every planted violation, not only the first |
| GA plus LS is a 12-story dependency chain with little parallelism inside each track | Medium | Medium | Run the two tracks side by side; they do not depend on each other |
| No milestone document exists to trace this sprint to | High | Low | Foundation completion is the implied milestone. Formalise it or stop carrying the risk |

### Risks retired from Sprint 1

| Risk | Outcome |
|------|---------|
| The remaining critical path is human-only and the windowed editor segfaults | **Mostly closed.** Both playtests are signed off and the editor checks were substituted by headless probe. Only the CI run survives, as CI-1 |
| CI still triggers on `main`; this repository's main branch is `development` | **Closed** by `d77337c`. The trigger now fires on `development`. The live-fire run it enables is CI-1 |
| ADR-0011 has no epic, so LV-006 is unschedulable | **Closed 2026-08-24.** The `physics-props` epic exists with six stories |
| Rolled-up yaml rows hid unstarted work | **Closed** by the 2026-08-24 per-story expansion. Sprint 2 is authored one row per story from the start |

## Dependencies on External Factors

- **A human must open a PR against `development` or push to it directly** for
  CI-1. This is the single hard external dependency in the sprint.
- The Godot 4.7.1 binary must be reachable for headless runs.
- The windowed editor is unavailable; the headless probe is the substitute.
- 17 commits on `vertical-slice` are unpushed as of 2026-08-25. Nothing from
  Sprint 1's close-out has left the machine — CI-1 will be the first push.

## Scope Boundaries

Deferred, and stated here so they are not pulled in silently:

- `player-core` (Core) — follows `gravity-authority` per the index build order
- `oxygen-drain` (Core) — blocked by ADR-0002 until `level-state` lands, and by
  the stale control manifest at story 006
- `level-outcomes` (Core) — story 007 is Blocked on a design decision
- `physics-props` stories 002–006 — content deferred to Vertical-Slice tier by
  `art-bible.md` §1.3. Only story 001 is pulled forward, which `index.md`
  explicitly sanctions
- Hazards, Watering, HUD, Pause Menu, moving platforms (Feature and Presentation)
- A Presentation visual epic for `PlayerVisualComponent` — referenced by name in
  two places and does not exist. TR-gravity-013 does not close until it does

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-2.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] **Every new CI guard has one recorded live-fire run — "configured" is not
      "observed"** *(new — retrospective action item 2)*
- [ ] **Actual effort recorded per story at `/story-done`** *(new —
      retrospective action item 3)*
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
