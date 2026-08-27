# Continuation Prompt — written 2026-08-26 (end of the nineteenth session)

Paste the block below into a new session. Delete this file once it is consumed.

---

## Start here

Read `production/session-state/active.md` in full, then the last Session Extract
at the bottom of it (`/dev-story 2026-08-26 (LS-003)`). Then re-derive git state
yourself:

    git log -4 --oneline
    git status --short

Do NOT trust any commit hash or file list written into a document, including
this one. Earlier versions of `active.md` went stale within a day and sent one
session down a wrong path.

## Where things stand

**The tree is COMMITTED and clean apart from three untracked leftovers.** The
last session ended the three-session dirty-tree risk. Four commits landed:

- `6e4f0cf` `feat(level-state)` — `LevelState` and `OxygenState` + 940 lines of tests
- `295c1d1` `docs` — GA-004 / LS-001 / LS-002 closures, sprint status, ADR-0002 erratum
- `ee18763` `feat(level-state)` — `FramePriority` + 17 tests
- one `docs` commit carrying this prompt

Untracked and deliberately left alone: `.probe_tmp/` (disposable, NOT
gitignored), `production/sprints/continue-2026-08-26-ls-001-review.md` and
`production/sprints/continue-2026-08-26-ls-003.md` (both consumed prompts —
delete them when you are sure, they have no git copy).

**Track status: LS-001 done -> LS-002 done -> LS-003 CODE COMPLETE, story still
open -> LS-004 next.**

**Baseline suite is now 303/303 across 17 suites, exit 0** (`report_29`). It was
286/16 before LS-003.

## The task

**Finish LS-003 first — it is coded and green but NOT closed.** The story file
still reads `Status: In Progress` and `sprint-status.yaml` still reads
`in-progress`. Two steps remain:

    /code-review src/scripts/frame_priority.gd tests/unit/level_state/frame_priority_test.gd
    /story-done production/epics/level-state/story-003-frame-priority-contract.md

Then move to **LS-004**,
`production/epics/level-state/story-004-level-root-construction-and-injection.md`,
status `ready-for-dev`, Must Have, 0.50 days. Run the full loop on it:
`/story-readiness` -> `/dev-story` -> `/code-review` -> `/story-done`.

LS-004 is the high-value one. It constructs and injects both state objects, it
unblocks GA-005, and it is what lets GA-004's wiring test become behavioural
instead of source-text matching. It also DELETES `main.gd`, which is why no
live-wiring test was written against that file.

## What LS-003 actually shipped

- `src/scripts/frame_priority.gd` — `class_name FramePriority`, no `extends`
  (matching `tuning.gd`), three typed int constants: `GRAVITY = -100`,
  `PLAYER = 0`, `OXYGEN = +100`. No methods, no autoload registration.
- `tests/unit/level_state/frame_priority_test.gd` — 17 test functions covering
  all five acceptance criteria.
- **No call sites.** The three `process_physics_priority = FramePriority.*`
  assignments belong to `gravity-authority`, `player-core` and `oxygen-drain`.
  None of those three nodes exists in its ADR-final form yet.

## Two open items the last session raised and the developer did not answer

Neither blocks LS-004. Both are text that is now WRONG while carrying binding
force, so fix them before anyone cites them. **Annotate, never reword.**

1. **LS-003's own AC-5 edge-case note is known-wrong** (story lines ~169-170).
   It says `process_physics_priority` CONTAINS `process_priority` as a
   substring. It does NOT — in `process_physics_priority`, `process_` is
   followed by `physics_`, not by `priority`. Verified, not assumed. The hazard
   the note points at is real but one step broader: a naive matcher on
   `priority` or `_priority`, which is what a grep actually reaches for, flags
   every CORRECT assignment and turns the guard permanently red. The shipped
   matcher was built against that real hazard and proved in both directions.
   The correction currently lives only in the test file's header comment.

2. **Two documents still claim the oxygen band boundary is undecided.** The
   AC-4 edge-case note in
   `production/epics/level-state/story-002-oxygen-state-object.md` and the
   2026-08-25 addendum in `production/qa/qa-plan-sprint-2.md` both say the
   exact-boundary side must be picked by the implementer. It is not undecided.
   `design/gdd/suit-oxygen.md:97` states it verbatim:
   `nominal > 0.50 · caution <= 0.50 · warning <= 0.25 · critical <= 0.10`.
   The boundary belongs to the LOWER band, and the shipped `_band_for()`
   already matches. LS-002 is closed and committed, so this text now has
   binding force while being wrong.

## Carry these forward — they cost real sessions to learn

1. **Run `/story-readiness` before `/dev-story` and believe a NEEDS WORK.**
   LS-002 came back NEEDS WORK on a genuinely unsatisfiable criterion.
2. **When reality and an approved criterion diverge, ANNOTATE the criterion.**
   Never reword it, never silently tick it, never "fix" the code to chase a
   claim the engine disproves.
3. **An external write to a getter-only property is DISCARDED SILENTLY in
   4.7.1.** Evidence:
   `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`.
   ADR-0002 `:246-248` and `:291` both still claim otherwise and are both still
   wrong; the erratum row is in `docs/tech-debt-register.md`. The ADR is
   Accepted and has NOT been amended.
4. **Fix every open decision BEFORE dispatching an executor.** LS-003 went in
   one clean pass because the brief pre-decided the file path, the class
   declaration, the constant names, whether a `static func` was permitted, and
   the test discipline. An executor given latitude spends it.
5. **Verify a subagent's numbers yourself.** Read
   `reports/report_NN/results.xml`. Do not relay a suite count you did not see.
   LS-003's executor reported honestly and the numbers checked out — that is
   the outcome the check confirms, not a reason to drop the check.
6. **Check that a guard has TEETH, not just that it is green.** Both of LS-003's
   structural guards return zero matches against the current repo, which is
   exactly how a vacuous guard also looks. Each is therefore paired with
   synthetic positives — six realistic violating spellings for the
   `process_priority` scan, a synthetic scene for the inspector scan — plus
   correct spellings asserted NOT flagged. Vacuity floors have real margin:
   28 scripts vs `MIN_SRC_SCRIPTS = 20`, 19 scenes vs `MIN_SRC_SCENES = 15`.
   Ask of every structural test: what would the realistic violation LOOK like,
   and would this catch THAT?
7. **Open the config file before relaying a config-dependent severity.** Six
   findings in this project have invented one. The seventh, in LS-002, was real.
8. **Never `git add -A`.** It swept an unreviewed level edit into a docs commit
   on 2026-08-25. Stage named paths and read the diff.

## Finding noted and stopped on

LS-003's AC-4 instructs the implementer to note this and stop, so it was NOT
done: **no CI grep step was added to `.github/workflows/tests.yml`.** The AC-4
and AC-5 scans would sit naturally beside the existing ADR-0004 D4.6 and
ADR-0006 V6/V7/V8 steps there. Adding them is a separate decision.

## Still unanswered, and larger

Merge `vertical-slice` into `development`. It is 80+ commits ahead, and the
merge is what puts the CI guards on the trunk where they can actually run.

## The test command

    "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

Keep the `-c`. Without it a red run stops at the first failure and under-reports.
If it fails to load with a "Could not find type" error naming a NEWLY ADDED
script, the `.godot` class cache is stale — run the same command with `--import`
first, then retry. This happened on LS-003 and `--import` fixed it. Expect
**303/303 across 17 suites, exit 0** as the baseline.
