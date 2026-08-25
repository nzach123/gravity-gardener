# Retrospective: Sprint 1

> **Period**: 2026-08-18 to 2026-08-31 (written at day 6 of 10)
> **Generated**: 2026-08-25
> **Branch**: `vertical-slice`, HEAD `9bfa6a8`
> **Stage**: Pre-Production
> **Review mode**: lean

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Rows | 21 | 22 | +1 |
| Rows done | — | 20 | 90.9% |
| Must-have done | 19 | 17 | 89.5% |
| Effort days | 5.75 | 5.84 delivered | +0.09 |
| Effort days remaining | — | 0.35 | CLR-005 + TUN-006 |
| Bugs found | — | 1 (BUG-0002, S4) | — |
| Bugs fixed | — | 1 (BUG-0001, S2) | — |
| Unplanned rows added | — | 1 (GA-001, pulled from the cut block) | — |
| Commits in window | — | 40 | — |
| TODO/FIXME/HACK in `src` + `tests` | — | **0** | — |
| Open tech-debt items | — | 10 | +10 |

Commit mix: 21 `docs`, 5 unprefixed, 4 `test`, 3 `feat`, 3 `chore`, 2 `fix`,
1 `ci`, 1 `revert`. **Documentation and paperwork outnumbered code roughly 3:1.**

## Velocity Trend

| Sprint | Planned | Delivered | Rate |
|--------|---------|-----------|------|
| 1 (current) | 5.75 d | 5.84 d | 101% of commitment, 90.9% of rows |

**Trend**: no baseline — this is Sprint 1. The number worth carrying forward is
**throughput per active day**: 5.84 estimate-days landed across the 4 days on
which commits actually happened (18, 23, 24, 25 Aug) — about **1.46
estimate-days per active day**. Six working days elapsed; three of them
(19–21 Aug) produced zero commits, and one active day (23 Aug) was a Sunday.
Sprint 2 should plan against active days, not calendar days.

## What Went Well

- **The commitment was met on effort.** 5.84 delivered against 5.75 committed,
  with GA-001 pulled forward for free.
- **The mid-sprint re-plan on 2026-08-24 was the highest-value action of the
  sprint.** Expanding three rolled-up rows into 22 per-story rows surfaced an
  unstarted story (TUN-006), a story with no row at all (LV-005), and a 60%
  under-estimate on GA-1 — and brought scope from 7.75 to 5.75 against 8
  available days.
- **Zero TODO/FIXME/HACK markers in `src` and `tests`.** Debt is written down in
  a register with story traceability instead of buried in comments. Ten items,
  each naming its origin story.
- **The editor blocker was routed around rather than waited on.** The windowed
  editor segfaults and the godot-ai MCP disables itself headless; a read-only
  headless probe reading `get_property_list()` hint metadata closed the editor
  checks on TUN-002, TUN-003 and CLR-003 AC-5, with an explicit statement of
  what it does *not* prove.
- **Divergences were annotated, never reworded.** Four ACs now carry METHOD
  SUBSTITUTED / CLAUSE SUPERSEDED / DEFECT RESOLVED notes. The requirement text
  is intact in every case.
- **The suite held green throughout** — 178/178, 11/11 suites, 0 flaky,
  0 orphans, exit 0, re-confirmed after the TUN-005 mutations were reverted.

## What Went Poorly

- **Two rows were closed on evidence that had never been recorded.** TUN-005 had
  its implementation landed but all 15 ACs unticked, a Test Evidence status of
  "[ ] Not yet created", and no Implementation Record. A QA strategy pass read it
  as "met" without opening the file. Running the two demonstrable negative checks
  took about two minutes and changed the outcome. Completed work with unwritten
  paperwork cost real time twice this sprint.
- **An empty `blocker` field was treated as proof of no gate.** TUN-006's blocker
  was empty while its final AC was unmet. That misreading survived two sessions.
- **A CI workflow targeted a branch that does not exist.** `tests.yml` triggered
  on `main`; this repository has no `main` local or remote, and `origin/HEAD`
  points at `origin/development`. The job had never fired once. Nobody noticed
  because *"CI is configured"* was never distinguished from *"CI has run"*.
- **A subagent reported four BLOCKING findings premised on an assumed project
  config.** `project.godot` declares no `debug/gdscript/warnings/*` section, so
  the `unsafe_*` warnings it assumed were fatal are off by default and the suite
  was green. The findings were real; the severity was invented.
- **Two zero-margin thresholds slipped through review.** `MIN_TILEMAP_LAYERS = 9`
  sits *at* the real count of 9, so any legitimate level merge fails with a
  message blaming a broken scan; and a proposed 1-degree settle epsilon landed on
  exactly 100.0 ms against a 100 ms requirement. Both read as correct and fail on
  the first legitimate change.
- **`git add -A` swept an unrelated level edit into a docs commit.** SpikeHazard3
  in `level_04.tscn` had drifted during a play session and was committed
  unreviewed, then reverted in `df0c332`.
- **Three working days (19–21 Aug) produced no commits**, then 30 of 40 commits
  landed in the final two days. The sprint was back-loaded.

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---|---|---|---|
| Windowed Godot editor segfaults; MCP plugin self-disables headless | Whole sprint, still open | Headless read-only probe script reading the same metadata the inspector renders from | Keep the probe script; never quote an "open the editor" AC on this machine without a substitution plan |
| CI workflow triggered on a nonexistent `main` branch | Latent since authoring; found 2026-08-25 | Trigger widened to `development` (`d77337c`) | A new CI guard does not close its story until one live-fire run is recorded |
| CI live-fire run needs a PR or a direct push to `development`; no `gh` CLI on this machine | Open — blocks CLR-005 + TUN-006 | Unresolved. Needs a human web-UI action | Identify human-only gates at planning, not at close-out |
| GA-1 under-estimated by ~60% inside a rolled-up row | 6 days, until the 08-24 re-plan | Expanded to 7 story rows; cut to Sprint 2 | One plan row per story file, always |

## Estimation Accuracy

**Per-task accuracy cannot be computed. No story file, sprint row, or commit
records actual effort spent** — only estimates. This is itself the finding.

The two measurable variances both come from rolled-up rows:

| Task | Estimated | Actual (derived) | Variance | Likely Cause |
|---|---|---|---|---|
| GA-1 (as one row) | 1.75 d | 2.83 d across 7 stories | **+62%** | Rolled-up row estimated against a label, not against decomposed work |
| TUN-2 (as one row) | — | 5 story files, one never started | unquantifiable | Same cause; the row read as "blocked on editor checks only" |

**Overall estimation accuracy: not measurable.** Aggregate delivery was within
2% of commitment (5.84 vs 5.75), but that is a coincidence of a re-plan, not
evidence of calibration.

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|---|---|---|---|---|
| CLR-005 | 1 | 0 | AC-5 needs a live CI run; a scratch branch alone will not trigger the workflow | Complete — human PR/push against `development` |
| TUN-006 | 1 | 0 | The same run, four violations (V6 path literal, V7 assignment, V7 `.duplicate()`, V8 GravityTuning script) | Complete — same run |
| GA-002…GA-007 | 1 (cut 08-24) | 1 | Cut at the plan's declared cut line; 2.39 d remaining | Schedule Sprint 2 |
| LV-005 | 1 (cut 08-24) | 1 | `LevelState` / `OxygenState` do not exist, and this story's subject is the ordering against their construction | Blocked — schedule after the level-state epic |
| LV-006 | 1 (cut 08-24) | 1 | Needs `class_name PropBody` under ADR-0011, and **no epic covers physics props** | Unschedulable — create the physics-props epic first |
| BUG-0002 | 1 | 0 | S4, deliberately sequenced after CLR-003's playtest | Schedule Sprint 2 |

## Technical Debt Status

- TODO: **0** · FIXME: **0** · HACK: **0** (no previous baseline)
- Register items open: **10** — 3 from GA-001, 7 from the CLR-004 code review
- Closed: 0
- Trend: **growing**, but deliberately and traceably. Every item names its origin
  story.
- Concern: the register has no repayment schedule and no closed section. Ten
  items with no owner is how a register becomes a graveyard.

## Previous Action Items Follow-Up

None — this is Sprint 1 and `production/retrospectives/` did not exist before
this file.

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|---|---|---|---|
| 1 | Execute the live-fire CI run — one deliberate violation per check, each confirmed red, then reverted. Needs a PR against `development` or a direct push. Closes CLR-005, TUN-006 and QA condition 1 | developer + devops-engineer | **High** | 2026-08-28 |
| 2 | Add to the Definition of Done: a CI guard does not close its story until one live-fire run is recorded. "Configured" is not "observed" | producer | High | Sprint 2 planning |
| 3 | Record actual effort per story at `/story-done`, so Sprint 2's retrospective can compute real estimation accuracy | producer | High | Sprint 2 start |
| 4 | Add a margin check to the code-review checklist: where a spec states a duration, tolerance or floor, compute the margin, not just whether it passes | lead-programmer | Medium | Sprint 2 start |
| 5 | Give the 10 tech-debt items an owner and a target sprint; open a Closed section | producer | Medium | Sprint 2 planning |

## Process Improvements

- **Never tick a blocking AC on inference.** Open the story file and read its
  Test Evidence status and Implementation Record before recording a row as met.
  Two rows were closed on assumption this sprint and both had to be re-opened;
  running the checks was a two-minute job.
- **Verify a subagent's severity against the config it assumes.** Open
  `project.godot` (or the equivalent) yourself before relaying BLOCKING. The
  findings are usually real; the severity often is not.
- **Stage named paths, never `git add -A`.** If Godot is open, expect `.tscn`
  files to drift, and read the diff before committing.

## Summary

Sprint 1 delivered its commitment — 20 of 22 rows, 5.84 of 5.75 effort-days,
suite green at 178/178, and the S2 bug closed on a real playtest. The recurring
failure mode was not in the code: it was **treating a written artifact as
evidence that the thing it describes actually happened** — a CI workflow that
had never fired, ACs ticked from an unopened story file, an empty blocker field
read as no gate. The single most important change for Sprint 2 is to require
observation, not configuration, before anything is marked done.
