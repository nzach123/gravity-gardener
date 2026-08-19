# Sprint 1 — 2026-08-18 to 2026-08-31

> **Stage**: Pre-Production
> **Engine**: Godot 4.7.1
> **Review Mode**: lean (PR-SPRINT producer gate skipped — not a phase gate)
> **Generated**: 2026-08-18

## Sprint Goal

Land the Foundation layer's data and validation base — collision registry,
tuning resources, and level-load validation — so Core epics have something
to build on, and close BUG-0001.

## Capacity

- Total days: 10 (full-time, 2 weeks)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

## Tasks

### Must Have (Critical Path) — 5.5 days

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| CLR-1 | Story 001 — Create CollisionLayers registry, correct `project.godot` naming | godot-gdscript-specialist | 0.25 | — | `collision_layers.gd` warning-clean; constants match `[layer_names]` |
| CLR-2 | Story 002 — Fix BUG-0001 dead kill-plane masks (levels 05, 06) | gameplay-programmer | 0.25 | CLR-1 | Both levels restart on out-of-bounds fall; BUG-0001 closed |
| CLR-3 | Story 003 — Remove vestigial `PlayerArea2D` and dead platform mask | godot-gdscript-specialist | 0.15 | CLR-1 | Nodes deleted; no behaviour change in playtest |
| CLR-4 | Story 004 — Collision layer invariant test suite | qa-tester + godot-gdscript-specialist | 0.4 | CLR-1, CLR-2, CLR-3 | Test passes; fails on each ADR-0004 criterion-1 violation |
| CLR-5 | Story 005 — CI grep enforcing the D4.6 runtime-mutation ban | devops-engineer | 0.15 | CLR-1 | CI step fails on a planted violation |
| ARCH-1 | `/architecture-review` — sweep `hazards.md` and `level-flow.md` into `tr-registry.yaml` | technical-director | 0.5 | — | `TR-hazards-*` and level-flow entries exist; story 002 cites a real TR-ID |
| TUN-0 | `/create-stories tuning-resources` | producer | 0.25 | — | Stories written, each with TR-ID and ADR-0006 guidance |
| TUN-1 | T4 spike — does `@export_range` clamp a hand-edited `.tres`? | godot-specialist | 0.5 | TUN-0 | Executed against the 4.7.1 binary; result recorded in ADR-0006 |
| TUN-2 | Implement `WateringTuning` / `OxygenTuning` / `PropTuning` + `Tuning` accessor | godot-gdscript-specialist | 1.5 | TUN-1 | V1–V4 and V9 pass headless; `resource_local_to_scene = false` on all three |
| LV-0 | `/create-stories level-validation` | producer | 0.25 | — | Stories written |
| LV-1 | Implement 5 of 6 `LevelValidation` rules + tests | gameplay-programmer | 1.25 | LV-0, TUN-2 | 5 rules pass headless; `V-PROP-BUDGET` named but stubbed |

### Should Have — 2.25 days

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| LV-2 | Close `V-PROP-BUDGET`; remove the "BLOCKED on ADR-0006" note from ADR-0003 | gameplay-programmer | 0.25 | TUN-2, LV-1 | Sixth rule live; the note is removed once, not twice |
| GA-0 | `/create-stories gravity-authority` | producer | 0.25 | — | Stories written; TR-gravity-008 recorded as parked |
| GA-1 | Implement `GravityAuthority` autoload, broadcast, prop registry, force-wake | gameplay-programmer | 1.75 | ARCH-1 | Props adopt the vector on the same frame as the player; ADR-0001 Verification 2 confirmed |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| LS-0 | `/create-stories level-state` | producer | 0.25 | — | Stories written |
| QA-1 | `/qa-plan sprint` | qa-lead | 0.25 | — | Test cases defined per story |

## Carryover from Previous Sprint

None — this is Sprint 1.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| T4 spike disproves the `@export_range` clamp assumption | Medium | Medium | TUN-2 clamps in code instead; +0.25 day, absorbed by buffer |
| ADR-0006 domain rates HIGH engine-risk with no `modules/core.md` reference | Medium | High | Verify Resource / `preload` / `@export_range` APIs against the official 4.7 docs before writing code — do not answer from training data |
| gdUnit4 fails the whole suite on one GDScript warning | High | Medium | Warning-clean gate on every new script before commit |
| GA-1 slips — gravity is the largest single item | Medium | Low | It is Should Have; slipping it does not break the sprint goal |
| No milestone document exists to trace this sprint to | High | Low | Foundation completion is the implied milestone; formalise it in Sprint 2 |
| Must Have + Should Have consume 7.75 of 8 available days | Medium | Medium | GA-1 is the declared cut line if the sprint runs long |

## Dependencies on External Factors

- A human playtest is needed for CLR-2 (levels 05 and 06, out-of-bounds fall).
  Agent playtests do not judge this reliably.
- The Godot 4.7.1 binary must be reachable for the TUN-1 spike.

## Scope Boundaries

Deferred to Sprint 2 and stated here so they are not pulled in silently:

- `level-state` implementation (story creation only is Nice to Have this sprint)
- `player-core`, `oxygen-drain`, `level-outcomes` (Core layer)
- Hazards, Watering, HUD, Pause Menu, moving platforms (Feature and Presentation runs)

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features (BUG-0001 is S2 — it must close)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
