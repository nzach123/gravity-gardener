# Gate Check: Pre-Production → Production

**Date**: 2026-08-25
**Checked by**: `/gate-check production`
**Review mode**: `lean` (`production/review-mode.txt`)
**Branch**: `vertical-slice` at `214190e`, working tree clean
**Prior run**: `gate-check-2026-08-17-pre-production-c.md` — verdict CONCERNS
**Context**: the first run of this gate since CI-1 closed. The 2026-08-25 QA
sign-off (`production/qa/qa-signoff-sprint-1-2026-08-25.md`) instructed that this
gate not be run until condition 1 — a live-fire CI run — was complete. It is
complete. See "CI-1 and the reach gap" below.

---

## Verdict: **CONCERNS**

Recorded with one **explicit override**, documented in full under "Override of the
automatic-FAIL rule". This gate does not pass silently over it.

---

## Grounding

Every figure below was re-derived this session. Nothing is carried from a handoff
document.

| Check | Result |
|---|---|
| `git log -1` | `214190e` |
| `git status --short` | clean |
| Test suite | **178/178 cases, 11/11 suites**, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit 0 |
| Test command | `Godot_v4.7.1-stable_win64_console.exe --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c` |

One correction to the standing handoff figure: `vertical-slice` is **78** commits
ahead of `development`, not 77. `214190e` landed after that count was written.
`development` is 0 commits behind. Verified with
`git rev-list --left-right --count development...vertical-slice`.

---

## Required Artifacts: 13/16 present

| Artifact | Status | Evidence |
|---|---|---|
| Vertical slice + REPORT.md | ✅ | `prototypes/gravity-gardener-vertical-slice/REPORT.md`, verdict PROCEED |
| Slice is built and playable | ✅ | isolated `project.godot`, scenes, scripts; headless import 23/23 clean |
| Slice playtested, ≥1 session | ✅ | 1 human session + 2 agent-driven passes, `REPORT.md:68-78` |
| First sprint plan | ✅ | `production/sprints/sprint-1.md`, `sprint-2.md` |
| All MVP-tier GDDs complete | ✅ | 6 GDDs, all 8 required sections each |
| Master architecture document | ✅ | `docs/architecture/architecture.md` |
| ≥3 Foundation-layer ADRs | ✅ | 14 ADRs, ADR-0001 … ADR-0014 |
| **All Foundation/Core ADRs `Accepted`** | ✅ | all 14 statuses parsed individually this session — none `Proposed` |
| Control manifest | ✅ | `docs/architecture/control-manifest.md` |
| Foundation and Core epics | ✅ | 9 epics: 5 Foundation, 3 Core, 1 Presentation |
| UX specs, key screens | ✅ | `design/ux/hud.md`, `main-menu.md`, `pause-menu.md` |
| HUD design document | ✅ | `design/ux/hud.md` |
| Art bible, all 9 sections | ✅ | `design/art/art-bible.md` §1–§9 |
| AD-ART-BIBLE sign-off recorded | ⚠️ | `art-bible.md:807` — **skipped by design**, not forgotten. Not a PHASE-GATE outside `full` review mode |
| Key screen UX specs passed `/ux-review` | ❌ | only `hud.md` was reviewed, twice, all findings closed. `main-menu.md:3`, `pause-menu.md:3`, `interaction-patterns.md:3` are all `Status: Draft` and have **never** been reviewed |
| Entity inventory | ❌ | `design/assets/entity-inventory.md` absent; `/asset-spec` never run. Recommended, not blocking — Production is where that work starts |
| Playtest report in `production/playtests/` | ❌ | directory absent. The session is documented inside `REPORT.md:68-118`, which satisfies the substance |

---

## Quality Checks: 6/9 passing

| Check | Status | Evidence |
|---|---|---|
| Tests passing | ✅ | 178/178, exit 0, run this session |
| Sprint plan references real story files | ✅ | all 18 paths in `production/sprint-status.yaml` resolve on disk |
| Core loop fun validated | ✅ | `REPORT.md:172-179` — a human completed the full loop; verdict PROCEED |
| No critical or blocker bugs | ✅ | only BUG-0002, severity S4, scheduled Sprint 2 nice-to-have |
| `/architecture-review` run recently | ✅ | 5 reports, latest `architecture-review-2026-08-16.md` |
| All ADRs carry Engine Compatibility + GDD Requirements sections | ✅ | 14/14, checked by heading grep |
| Traceability has no unowned Core requirements | ⚠️ | **13 of 74 TR IDs have no ADR owner**: 10 `TR-hazards`, 2 `TR-flow`, 1 `TR-watering-002`. The hazards block is a documented deliberate deferral to the Feature run (`production/epics/index.md`, "Core" scoping note) — not an oversight |
| Architecture doc has no open Foundation/Core questions | ❌ | `architecture.md:851` lists QQ-01 … QQ-07. **3 rows are stale, 2 are genuinely open.** See below |
| GDDs cross-reviewed and individually reviewed | ❌ | **no GDD has ever passed `/design-review`** — all six say "pending" or "not yet validated" in their own headers. `/review-all-gdds` has **never** been run; no `design/gdd/gdd-cross-review-*.md` exists |

---

## Director Panel Assessment

Review mode is `lean`, so all four directors ran, in parallel.

```
Creative Director:  CONCERNS
Technical Director: CONCERNS
Producer:           CONCERNS
Art Director:       READY
```

**Escalation rule applied**: three CONCERNS, no NOT READY → verdict floor is
CONCERNS. No director returned NOT READY, so nothing forces a FAIL from the panel.

**Creative Director** — the pillars are strongly corroborated across all four
system GDDs, and the one fantasy-threatening slice finding (inverted controls) is
already closed at the design level by `gravity.md` R11 and ADR-0013. The gap is
that the two most load-bearing pillars are not true of any built level.

**Technical Director** — Foundation ADRs are complete, Accepted and internally
consistent. Held back by a stale Open Questions table and by QQ-03 having no
owning epic.

**Producer** — Sprint 2 capacity is realistic: 6.26 days committed against 8
available, against a proven 5.84. Dependencies are correctly ordered. Four blocked
stories, two of them unowned. Settings is the largest unplanned cost.

**Art Director** — READY. Only art-bible §6.3 (gravity-zone fill colour) and §6.4
(room-boundary treatment) gate anything, and they gate `/asset-spec`, not this
phase transition. The other eight unset items can close during Production.

---

## The finding three independent paths converged on

**QQ-03 — the eight built levels do not implement the current design, and no epic
owns migrating them.**

The Creative Director, the Technical Director, and a direct grep reached this
separately. Confirmed three ways:

1. `grep -lE 'default_gravity|oxygen_capacity'` across
   `src/scenes/levels/level_01.tscn` … `level_08.tscn` returns **zero** hits.
   No level declares either export.
2. `design/gdd/systems-index.md:114-115` lists both under **"Designed but not
   built"**: *"All 8 levels use the old one-bucket / many-plants model"* and
   *"`O_level` not yet computed for any level."*
3. `docs/architecture/architecture.md` QQ-03 names the resolution path as a
   **"Level migration epic"**. No such epic exists. There are nine epics and none
   covers level migration.

Why it matters at this gate: `game-concept.md:231-235` (Pillar 2) rejects any
hand-set `oxygen_capacity`, and Pillar 3 (`game-concept.md:237-245`, "every bucket
is a commitment") presumes the multi-bucket routing economy. Neither is true of
the shipped game. This is a Core-layer content gap, not documentation lag.

It does **not** block the start of Production: Sprint 2 is entirely Foundation
work and authors no levels. It compounds only if new level content is authored
before the migration lands.

---

## `architecture.md` Open Questions — 3 stale, 2 open, 1 correctly parked

The table at `architecture.md:851` is currently unreliable as a planning artifact.
A Production-phase reader trusting it at face value would be misled in both
directions: it lists resolved questions as open, while the one real gap it does
carry (QQ-03) reads as no more urgent than the stale rows around it.

| ID | Finding | Evidence |
|---|---|---|
| QQ-01 | **Stale** | Closed in the body at `architecture.md:165-166` — both GDD ownership lines were amended 2026-08-14 — yet the row still sits in the table |
| QQ-02 | **Stale** | Resolved by ADR-0001 (Accepted) decision part 7, `adr-0001…md:216`. `production/epics/index.md:86` already cites it as a closed build-order constraint |
| QQ-03 | **OPEN** | No epic owns the 8-level migration. See the section above |
| QQ-04 | **Stale** | Resolved by ADR-0010 (Accepted), `adr-0010…md:167-183` — `PauseController` owns `SceneTree.paused` and the process-mode table gives oxygen's pause-halt a structural mechanism. The remaining pause-menu UI is `level-outcomes` story 003, a Presentation asset, not a Foundation/Core unknown |
| QQ-05 | **OPEN** | Verified directly. `src/scripts/moving_platform.gd` and `src/scripts/components/player_wall_jump_component.gd` both ship with **zero** TR-registry entries. `production/epics/index.md:120` cites QQ-05 by name and marks `PlayerWallJumpComponent` "Unowned" |
| QQ-06 | **Stale** | The row asserts *"No `game-concept.md` or pillars document exists"*. It exists — reverse-documented 2026-08-15, 443 lines, pillars at §202 |
| QQ-07 | **Parked by design, not a gap** | `production/epics/index.md:127` — `TR-gravity-008` correctly parked pending a future design change, exactly as the row states |

**Correction to the Technical Director's QQ-05 finding**: it reported moving
platforms as having no ADR at all. ADR-0004 (collision layer allocation) does
cover them. The accurate statement is that they have collision-layer coverage but
**no behavioural ADR** and no TR IDs. This changes the finding's shape, not its
conclusion.

---

## CI-1 and the reach gap

**The four ADR guards are proven.** Run #3 of 2026-08-25 planted five deliberate
violations and all four guards fired in a single run, each naming its clause. Run
#4 reverted and went green. Evidence:
`production/qa/evidence/ci-1-live-fire-2026-08-25.md`. QA sign-off condition 1 is
discharged. CLR-005 and TUN-006 are `done`.

**Their reach is not proven, and this gate declares it rather than letting it
pass.**

`.github/` does not exist on `development` — not the workflow, not the directory.
Verified this session with `git ls-tree -r --name-only development -- .github`,
which returns empty, against `vertical-slice`, which returns
`.github/workflows/tests.yml`.

The four runs happened only because GitHub runs a same-repo pull request's
workflow from the **head** branch. PR #1 was `ci-1-live-fire` → `development`, so
the workflow came from the head. **A push to `development` will not be guarded by
anything until the workflow reaches that branch.** `vertical-slice` is 78 commits
ahead and unmerged; merging it is what closes the gap, and that is a decision
separate from this gate and belonging to the developer, not to an agent.

Two further items from the same run, already recorded in
`docs/tech-debt-register.md` and named here rather than re-derived:

1. The CI test step has no `-c` equivalent, so a red CI suite may stop at the
   first failure and under-report. **Recorded as INFERRED and never
   reproduced** — every CI run so far has been green. Confirm that
   `MikeSchulze/gdUnit4-action@v1` exposes such an option before scheduling a fix.
2. `actions/checkout@v4` and `actions/upload-artifact@v4` log a Node 20
   deprecation warning. A warning, not a failure.

---

## Override of the automatic-FAIL rule

This section exists so the override is on the record and cannot later be mistaken
for a check that passed.

The gate defines four Vertical Slice Validation items and states: *"Slice was
built AND any validation item is NO → verdict is automatically FAIL."* Assessed
against `REPORT.md:80-118`:

| # | Validation item | Reading | Evidence |
|---|---|---|---|
| 1 | A human played the core loop without developer guidance | **Qualified** | Found the bucket and reached the gravity zone unprompted, but *"once **told** the pour mechanic requires a sustained hold"* — `REPORT.md:84-85` |
| 2 | The game communicates what to do within the first 2 minutes | **NO** | *"Gravity zones are completely invisible"*, *"No interact prompts anywhere"*, *"No level-complete feedback"* — `REPORT.md:89-101` |
| 3 | No critical "fun blocker" bugs | **YES** | The `goal.gd` entry-timing race was found, fixed, and independently re-verified by an agent replay and the human's own completed run — `REPORT.md:102-110` |
| 4 | The core mechanic feels good to interact with | **YES — developer's call, asked and answered 2026-08-25** | The developer judged the gravity-flip loop satisfying and classed the recorded inverted-control dislike as polish addressed by ADR-0013 |

**Item 2 is NO.** A mechanical reading of the rule therefore produces FAIL.

**The override, and its basis.** The slice's own recommendation was PROCEED, and
`REPORT.md:180-183` states that PROCEED *"does not paper over"* precisely these
findings — it classes them as Production work. The rule's stated intent, in the
skill's own words, is that *"a broken or unfun vertical slice should not advance"*.
This slice is neither: the loop works end to end and a human completed it. The
four findings are legibility and affordance gaps, and three of the four already
have designed homes:

| Slice finding | Designed home | Ownership |
|---|---|---|
| Mirrored controls when upside-down | `gravity.md` R11 + ADR-0013 (Accepted) | Partly owned — `player-core` story 005 takes the Foundation function and the movement caller. The `PlayerVisualComponent` caller stays unowned until a Presentation visual epic exists |
| No level-complete feedback | `level-outcomes` epic, story 004 | Owned, not scheduled. `complete_hold_duration` needs a **human** playtest |
| No interact prompts | `design/ux/hud.md`, E-series elements | Designed, **no HUD epic exists** |
| Invisible gravity zones | `art-bible.md` §6.3, gravity-zone fill colour | **⚠ unset.** Art Director rates it "before asset production" |

**Decision, taken by the developer on 2026-08-25**: record CONCERNS, treating
legibility as Production scope, with the four gaps above carried as named entry
conditions rather than absorbed silently.

**Entry conditions attached to this override.** None blocks starting Production —
Sprint 2 is Foundation work and touches none of them — but all four must be closed
before any Sprint 3 content work is scheduled:

1. ADR-0013's screen-relative input basis lands, closing the inverted-control
   finding in the built game.
2. A HUD / Pause Menu epic exists, covering interact prompts.
3. Level-complete feedback is scheduled, `level-outcomes` story 004.
4. `art-bible.md` §6.3 and §6.4 close before `/asset-spec` runs.

---

## Blockers

**None that block the phase transition.** No director returned NOT READY, no
required Foundation or Core ADR is unaccepted, and the suite is green.

---

## Concerns, ranked

1. **QQ-03 — 8-level migration has no owning epic.** Core-layer content gap.
   Pillars 2 and 3 are not true of the built game. Compounds if new levels are
   authored first. → Add a level-migration epic, or add the row explicitly to the
   "Not yet epic'd" table so it stops being invisible.
2. **`architecture.md` Open Questions table is unreliable.** 3 of 6 checkable rows
   are stale. → Strike QQ-01, QQ-02, QQ-04, QQ-06.
3. **CI guards do not reach the trunk.** → Merge `vertical-slice` into
   `development`, or re-point the workflow. Developer's call; a browser action,
   as there is no `gh` CLI on this machine.
4. **Slice legibility gaps.** Carried as the four entry conditions above.
5. **QQ-05 — two shipped traversal mechanics have no design authority.**
   `moving_platform.gd` and `player_wall_jump_component.gd`, zero TR IDs each.
   `player-core` story 006 is Blocked on it with no owner.
6. **No GDD has passed `/design-review`; `/review-all-gdds` has never run.** Six
   GDDs, zero reviews. A conflict between them has no authority to appeal to.
7. **Three UX specs never reviewed.** `main-menu.md`, `pause-menu.md`,
   `interaction-patterns.md`, all `Status: Draft`.
8. **4 blocked stories, 2 unowned.** LV-005 and LV-006 carry stale `Blocked`
   headers while scheduled inside Sprint 2 — doc lag, not a live gate.
   `player-core` story 006 (QQ-05) and `level-outcomes` story 007
   (`level-flow.md` R10, a design decision owed) have no owner and no resolution
   path. Both are Sprint 3 critical-path risk, neither is a Sprint 1/2 risk.
9. **Settings system is the largest unplanned cost.** No GDD, no ADR, no menu
   code — `production/epics/index.md:126`. No first-two-sprint risk; a
   Production-milestone scope risk.
10. **No milestone document exists** for either sprint to trace to. Flagged as a
    live risk in `sprint-1.md:186` and `sprint-2.md:103`.
11. **10 open tech-debt items have no repayment schedule** beyond the Nice-to-Have
    `DEBT-1` row.

---

## Recommendations

**Before Sprint 2 starts (2026-09-01)**

1. `/qa-plan sprint` for Sprint 2. Prompt is written at
   `production/sprints/qa-plan-sprint-2-prompt.md`. Sprint 1's DoD depended on a
   QA plan that was Nice-to-Have on day one and had to be promoted mid-sprint.
2. Decide the `vertical-slice` → `development` merge. This is what closes the CI
   reach gap.
3. Strike the four stale QQ rows from `architecture.md`.

**During Sprint 2**

4. Give QQ-03 a home — an epic, or an explicit row in the "Not yet epic'd" table.
5. `/create-control-manifest update` is owed before Sprint 3; `oxygen-drain`
   story 006 has an Accepted governing ADR (ADR-0014) with no manifest rule to
   quote.

**Before Sprint 3 content work**

6. The four override entry conditions above.
7. `/review-all-gdds`, and `/design-review` on the six GDDs.
8. `/ux-review` on `main-menu.md` and `pause-menu.md`.

---

## Chain-of-Verification

**5 questions checked — verdict revised from CONCERNS to FAIL to CONCERNS-with-
override.**

| # | Question | Answer |
|---|---|---|
| 1 | Could any listed CONCERN be elevated to a blocker? | **[TOOL ACTION]** Re-read `REPORT.md:68-118` rather than trusting the summary line. This surfaced that validation item 2 is NO, which the gate's own rule turns into an automatic FAIL. The draft verdict was wrong and was corrected. Resolved by an explicit, documented developer override rather than by softening the reading |
| 2 | Is the QQ-03 concern resolvable in the next phase, or does it compound? | **[TOOL ACTION]** Grepped all 8 level scenes for `default_gravity` and `oxygen_capacity` — zero hits — and confirmed no migration epic exists. It is resolvable during Production and compounds only if new level content is authored first. Sprint 2 authors none |
| 3 | Did I soften a FAIL condition into a CONCERN to avoid a harder verdict? | **Yes, and deliberately, on the developer's explicit decision.** The full reasoning, the NO item, and the four entry conditions are recorded above rather than omitted. This is the single item most worth re-reading if this gate is revisited |
| 4 | Are there artifacts I did not check that could reveal more blockers? | Checked after drafting: `production/milestones/` does not exist; `production/gate-checks/` holds 6 prior reports; the tech-debt register carries 10 open items. None is a blocker; all are listed as concerns |
| 5 | Which single check am I least confident in? | The `/design-review` and `/review-all-gdds` gap. Six GDDs have never been formally reviewed, which is a Systems Design gate item carried unresolved through three phases. No director rated it blocking, and the vertical slice is empirical evidence the designs cohere in practice — but it is the item where a real defect is most likely to be hiding unseen |

---

## Stage

`production/stage.txt` remains **`Pre-Production`**. The skill advances the stage
only on PASS. This verdict is CONCERNS, so the advance is the developer's
decision and was deliberately not written by this run.
