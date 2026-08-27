# Continuation Prompt — written 2026-08-26 (end of the twenty-second session)

Paste the block below into a new session. Delete this file once it is consumed.

---

## Start here

Read `production/session-state/active.md`, and in particular its last Session
Extract, `/dev-story 2026-08-26 (LS-004)`. Then re-derive git state yourself:

    git log -3 --oneline
    git status --short

**Do not trust any commit hash, file list, scope claim or test count written
into a document, including this one.** A previous continuation prompt in this
series carried a false scope claim that would have sent a session down a wrong
path. Re-derive from source.

## What the twenty-second session did

**LS-004 is implemented and committed at `a071da6`.** The story is NOT closed —
`Status:` is still `Ready` and its 8 acceptance-criteria boxes are still
unticked. `/story-done` is what changes that.

Expected state: tree CLEAN at `a071da6`, plus whatever this prompt's own commit
adds. `sprint-status.yaml` has LS-004 at `status: in_progress`.

## The work waiting for you

    /code-review    →    /story-done

Run `/code-review` on the five files, then `/story-done` on the story path:

    src/scripts/main.gd
    src/scripts/plant.gd
    src/scripts/goal.gd
    src/scripts/player.gd
    tests/integration/level_state/level_root_injection_test.gd

    production/epics/level-state/story-004-level-root-construction-and-injection.md

Review mode is `lean` (`production/review-mode.txt`), so director gates skip.

## Facts established this session — reuse, do not re-derive

All verified from source or from a probe in the working tree.

| Fact | Where |
|---|---|
| Suite green: 322 tests, 18 suites, 0 failures, 0 errors, 0 skipped, 0 orphans, exit 0 | `reports/report_34/results.xml`, read directly |
| Baseline before this story was 304 tests / 17 suites | `reports/report_31` |
| The new integration suite has **18** test functions | `grep -c "^func test_"` |
| `LevelValidation.count_buckets(level) -> int` seeds `buckets_total` | `level_validation.gd:71` |
| `Tuning.OXYGEN` is the only sanctioned tuning route | `tuning.gd:19`, ADR-0006 D6.3 |
| `level_validation.gd:115` reads `level.get("oxygen_capacity")` under V-OXY-CAP | that line |
| `REQUIRED_CONSUMERS` = player, goal, hud, level_bounds | `level_validation.gd:40-45` |
| `validate()` is still called from tests only — the LV-005 seam is unwired | grep over `src/ tests/` |

## The gdUnit4 fact that cost this session a debugging cycle

**`assert_object(obj)` RETAINS A STRONG REFERENCE to `obj` for the rest of the
test function.** The AC-7 lifetime test failed twice with "LevelState outlived
LevelRoot" purely because its own two pre-checks were
`assert_object(ref.get_ref()).is_not_null()`. Changing ONLY those two lines to
`assert_bool(ref.get_ref() != null).is_true()` took the suite from 2 failures to
322/322 PASSED. No source file changed.

The release was real. The test was holding what it measured.

A comment at `level_root_injection_test.gd:333-342` says so in place. **If a
reviewer proposes "tidying" those two `assert_bool` calls back to
`assert_object`, that is the answer — it reintroduces the false failure.** The
FINAL assertions in that test are unaffected and keep their teeth: on success
they receive null, and on a real leak they receive the live object and fail.

## Decisions made this session that a reviewer may question

Each was approved by the developer before implementation. None is open.

1. **`plant.gd` declares `pour_completed` now.** `Plant.pour_completed` appeared
   in 8 documents and zero `.gd` files. It is emitted beside `plant_watered` in
   `_complete_watering()`. ADR-0009 later moves the emit into `receive_pour()`
   so it fires once per BUCKET rather than once per PLANT — a behaviour change,
   not a rename, and the two agree only while `buckets_required == 1`. Precedent:
   `plant.gd:12-18`, where `buckets_required` was declared the same way.
2. **`Goal` moved BOTH its `GameManager.goal_unlocked` reads onto the injected
   `LevelState`**, behind a guarded `_is_goal_unlocked()`. Without a real read
   the AC-4 bind guard would have been vacuous. Story 006 still owns deleting
   the `GameManager` fields themselves.
3. **`Player` has `bind()` and one guarded `is_carrying_bucket()` with no caller
   yet.** ADR-0009's `PlayerWateringComponent` is the reader that arrives later.
   This is deliberate, and it is documented at the accessor.
4. **`class_name LevelRoot` was added to `main.gd`**, and `@export var hud: Node`
   is declared and left UNASSIGNED. `REQUIRED_CONSUMERS` already expects the
   shape. No HUD node was created — a stub that binds successfully would make a
   later real consumer's missing `bind()` invisible.
5. **`GameManager.plants_total` assignment stayed after `reset_level_state()`**,
   not up in step (d) with the type scan. `reset_level_state()` zeroes it, so
   moving it would leave `plants_total` at 0 and break goal unlocking. Only the
   discovery changed.

## Seams left unwired ON PURPOSE — do not fill them

- **Step (b), `LevelValidation.validate()`** — a named comment in
  `main.gd._ready()` citing LV-005 and ADR-0003 D3.1. It records that
  `validate()` runs BEFORE the state objects are constructed, reading only raw
  authored `@export` scene data. Do not call it here.
- **The HUD bind** — ADR-0010, Presentation epic. Carries the A2-03 note: a
  persistent or cross-scene HUD would hold a stale `LevelState` with no error
  and no crash. `RefCounted` leaks are invisible and there is no watchdog.
- **The OxygenDrain bind** — ADR-0008, Core `oxygen-drain` epic. A CHILD of
  `LevelRoot`, never an export and never a child of `Player`.

## Untouched on purpose — a reviewer flagging these is wrong

Steps (e) and (f) and the `hazards` / `gravityzone` group scans (gravity-authority
epic) · the camera wiring and `next_level` · the two `player_reached_goal`
connections (story 005) · `GameManager.reset_level_state()` and `restart_level()`
(story 006) · `plant.gd`'s `add_to_group("plants")` and its `GameManager` writes.

## Open, and NOT blocking LS-004

**Level content is mostly empty, and this is now visible in behaviour.** Verified
by grep over `src/scenes/levels/*.tscn`:

| Level | `Plant` | `Bucket` |
|---|---|---|
| level_01 | 1 | 1 |
| level_02 | 1 | 0 |
| level_03 … level_08 | 0 | 0 |

Only level_01 is well-formed. level_02 is a `V-BUCKET-SUM` breach. Under the old
`GameManager` path levels 02-08 NEVER unlocked the goal, because `goal_unlocked`
was written only inside `Plant._complete_watering()`. Under `LevelState`,
`buckets_total` of 0 makes `goal_unlocked` true at construction for 03-08. Both
states are broken; the new one is at least completable. **No story in this epic
owns authoring that content.** Decide where it belongs.

**Oxygen band boundary text, wrong and binding.** Two documents still call the
exact-boundary side undecided:
`production/epics/level-state/story-002-oxygen-state-object.md` (AC-4 edge-case
note) and `production/qa/qa-plan-sprint-2.md` (2026-08-25 addendum). It IS
decided — `design/gdd/suit-oxygen.md:97` puts the boundary in the LOWER band and
the shipped `_band_for()` already matches. LS-002 is closed, so that text has
binding force while wrong.

**No CI grep step** in `.github/workflows/tests.yml` for the LS-003 AC-4/AC-5
scans. **The `vertical-slice` → `development` merge** is now 80+ commits behind,
and `.github/` does not exist on `development`, so the guards are proven but
their reach is not.

**Housekeeping.** Three consumed continuation prompts are still tracked in
`production/sprints/`: `continue-2026-08-26-ls-001-review.md`,
`continue-2026-08-26-ls-003.md`, and `continue-2026-08-26-ls-003-review.md`.
Committed, so deletion is recoverable. Delete this file too once consumed.
`.probe_tmp/` is committed at `871fbf4` and is NOT gitignored — disposable probe
scaffolding, decide whether to remove or ignore it.

## Carry these forward — they cost real sessions to learn

1. **Run `/story-readiness` before `/dev-story` and believe a NEEDS WORK.**
   Three for three now. LS-004 had five real gaps.
2. **When reality and an approved criterion diverge, ANNOTATE the criterion.**
   Never reword it, never silently tick it, never change code to chase a claim
   the engine disproves.
3. **Never relay a suite count you did not read from `results.xml` yourself.**
   The LS-004 executor reported 17 test functions; the real count is 18.
4. **Check that a guard has TEETH, not just that it is green.** Ask of every
   test: what would the realistic violation LOOK like, and would this catch THAT?
   A `bind()` with no reader is a guard with no teeth.
5. **Check the MARGIN, not just that it passes.** A filter is its own vacuity
   surface. Give every repo-scanning test a floor.
6. **Open the config file before relaying a config-dependent severity.** Seven
   findings in this project have invented one.
7. **Never `git add -A`.** Stage named paths and read `--stat` before committing.
8. **A failing test is not automatically a defect in the code.** Probe which side
   is wrong. This session's two failures were the test framework retaining the
   object the test was checking had been released.

## The test command

    "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

Keep the `-c`. Without it a red run stops at the first failure and under-reports.
If it fails to load with a "Could not find type" error naming a NEWLY ADDED
script, or a newly added script has no `.uid`, the `.godot` class cache is stale
— run the same binary with `--headless --path . --import` first, then retry.

Expect **322/322 across 18 suites, exit 0** as the inherited baseline. That was
verified this session from `reports/report_34/results.xml`.

Several `ERROR:` lines are EXPECTED. LS-001, LS-002 and now LS-004 negative tests
deliberately trigger `push_error()` — `LevelState requires buckets_total >= 0`,
`OxygenState requires capacity > 0`, `Goal: _is_goal_unlocked() called before
bind()`, `Player: is_carrying_bucket() called before bind()`. gdUnit4 reports
`0 errors` regardless. Do not chase them.

**This project treats GDScript warnings as errors.** `var x := weakref(...)`
infers `Variant` and fails the parse. Annotate the type.
