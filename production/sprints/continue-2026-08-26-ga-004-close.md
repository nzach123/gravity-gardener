# Continuation Prompt — GA-003 closed and committed; GA-004 awaits closure (2026-08-26, fifteenth session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `continue-2026-08-26-ga-003-004-review.md`**, which is fully consumed.
Three consumed prompts are tracked and still on disk — delete all three when you
commit this file:

    production/sprints/continue-2026-08-25-qa-plan-sprint-2.md
    production/sprints/continue-2026-08-26-ga-003.md
    production/sprints/continue-2026-08-26-ga-003-004-review.md

What changed this session, that every earlier handoff gets wrong:

1. **The working tree is CLEAN and everything is COMMITTED.** Every prior handoff
   says "nothing is committed" and agonises over a commit split. That is moot.
   HEAD is `1c58501`, and it contains all of ADR-0001 Changeset A as ONE commit.
2. **GA-003 is Complete and closed.** `/code-review` and `/story-done` both ran.
3. **GA-004 is committed and reviewed but still `in-progress`.** It is the only
   thing standing between you and the LS track.
4. **GA-005's `blocker` field is now filled.** Earlier prompts say it is empty.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 2 is in progress. GA-001, GA-002
    and GA-003 are Complete. GA-004 is IMPLEMENTED, COMMITTED, VERIFIED GREEN AND
    ALREADY CODE-REVIEWED, but it is NOT closed. Close it, then continue.

    Ground yourself first. Do not trust any status you have not checked this
    session. Seven handoff documents in this repo have now outlived the facts they
    asserted.

    1. Run `git log --oneline -3` and `git status --short`. Expect HEAD `1c58501`
       and a CLEAN tree.
    2. Read `production/sprint-status.yaml` — GA-004 reads `status: in-progress`.
    3. Read `production/session-state/active.md`. Its last two Session Extracts are
       GA-003 and GA-004 and they are current as of 2026-08-26. **The GA-004 extract
       contains everything needed to close the story — read it before doing
       anything else.**
    4. Run the suite and confirm green before you change anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Expect **233/233, 14/14 suites, exit 0**. Keep the `-c`. Without it the
       runner stops at the first failure and a red run under-reports. Use
       `-a res://tests`, not `-a res://tests/unit`. If the runner fails to load with
       `Could not find type "GdUnitTestCIRunner"`, the `.godot` class cache is stale
       — run `--import`, then retry.

    ## Do these, in this order

    ### 1. `/story-done` on GA-004 — do NOT re-run `/code-review`

    `/code-review` already ran on 2026-08-26 across all seven changed files in a
    single pass covering BOTH stories. Verdict: **APPROVED WITH SUGGESTIONS, no
    blocking findings.** Review mode is `lean`, so `/story-done` will ask whether
    code review was run. It was. Say so and move on.

    Story: `production/epics/gravity-authority/story-004-zones-report-to-authority-and-clear-area-override.md`
    Test:  `tests/integration/gravity/gravity_zone_wiring_test.gd` (28 functions)

    Three things to get right when you close it:

    1. **Do NOT tick the camera-rewire no-change check.** It is manual, it needs a
       human, and the windowed Godot editor segfaults on this machine. It defers to
       the sprint gravity-path playtest that runs AFTER GA-005, signed off by
       qa-lead at `production/qa/evidence/playtest-sprint-2-gravity-regression.md`.
       That file does not exist yet.
    2. **Its Test Evidence block still reads `**Status**: [ ] Not yet created`.**
       Repoint it at the real test file, the way GA-003's was.
    3. **Log this as an advisory deviation — it is the one substantive finding the
       review produced for GA-004.** GA-004's AC-1 and AC-2 are proven ONLY by
       source-text matching against `main.gd`. No test anywhere instantiates
       `main.gd` or runs its `_ready()` — verified across the whole suite. Wrapping
       either `connect()` in `if false:` leaves every assertion passing while no
       zone reaches the authority and the camera never rotates. **Consequence: the
       deferred manual camera check is currently the ONLY runtime proof those two
       ACs hold. It is not bookkeeping.** Do NOT fix this by writing a live-wiring
       test against `main.gd` — LS-004 deletes that file. The fix is to make
       `LevelRoot`'s own wiring test BEHAVIOURAL when LS-004 lands.

    ### 2. Then continue the sprint

    **GA-005 is the natural next GA story and is BLOCKED on LS-004.** Its `blocker`
    field in `sprint-status.yaml` now says so explicitly — GA-005 AC-2 puts
    `reset_to()` in `LevelRoot._ready()`, and `LevelRoot` is created by LS-004.

    The unblocked work is the level-state track, which is independent of the gravity
    track: **LS-001 → LS-002 → LS-003 → LS-004**. All six LS story files exist under
    `production/epics/level-state/` and all read `ready-for-dev`. Running LS-001..004
    is also what unblocks GA-005, which is what makes the game playable again.

    Run `/story-readiness` before `/dev-story` on whichever you pick.

    ## What GA-004 actually did

    Zones connect to `GravityAuthority.set_gravity` inside the loop in `main.gd`; the
    camera handler connects ONCE to `GravityAuthority.gravity_changed` OUTSIDE the
    loop. `gravity_zone.tscn` lost `gravity_space_override = 3` and `gravity =
    -980.0`; nothing else in that file moved. **`gravity_zone.gd` was not modified at
    all** — it already had no local validation and no `body_exited` handler, so AC-5
    and AC-6 were satisfied by the authored source.

    Worth knowing: **GA-004 fixed a real shipped defect.** The camera handler was
    previously connected INSIDE the zone loop, so N zones meant N connections and N
    concurrent 0.6 s tweens per zone entry. An indentation-structural test now guards
    the fix.

    ## The highest-value open item, and it is not a story

    `docs/tech-debt-register.md` carries a 2026-08-26 row for the
    **zero-gravity-at-load gap**. It has TWO halves and the second is the dangerous
    one:

    - `GravityAuthority.gravity` initialises to `Vector2.ZERO` and **`reset_to()` has
      zero production call sites** — verified by grep across `src/`.
    - **(a) First load** leaves the player INERT, not merely weightless. Observable:
      level scenes under `scene_runner` log `up_direction can't be equal to
      Vector2.ZERO`. A log line, not a test failure — the suite is green.
    - **(b) Every subsequent load** inherits the PREVIOUS level's gravity, because
      the authority is an autoload surviving scene changes and all three transition
      paths (`start_menu.gd:5`, `main.gd:61`, `main.gd:67`) leave it untouched.
      Levels 2-8 and every death-restart begin under whatever gravity the player last
      triggered. **Half (b) produces NO log line** and will not be noticed until
      levels are played in sequence.

    Both halves close together via GA-005 AC-2, which is blocked on LS-004. This is
    the single strongest argument for doing the LS track next.

    ## Resolutions that must survive — do not relitigate

    1. **ADR-0001 vs GA-003 on the derived basis.** ADR-0001's Key Interfaces says
       the component "retains ... the derived basis". GA-003's AC-6 says the
       opposite. **The story won.** `update_derived_dirs()`, `up_dir` and `right_dir`
       were deleted from the component; all basis reads come from `GravityAuthority`.
       The ADR line is loose prose and has NOT been amended. It is logged as an ADR
       erratum candidate in the tech-debt register. If it bothers a reviewer, raise
       the erratum — do not re-add the local basis.
    2. **How `Player` seeds the authority.** Resolved by keeping
       `gravity_ascent_mag` / `gravity_descent_mag` and adding two typed accessors,
       `baseline_ascent_magnitude()` and `ascent_descent_ratio()`. No new stored
       field. The ratio accessor `push_error()`s and returns `0.0` pre-initialize so
       the authority's own guard refuses rather than dividing by zero.
    3. **`main.gd` was on GA-003's exclusion list but GA-003 edited it anyway**,
       deleting `zone.gravity_changed.connect(player.set_gravity)`. Correct and
       necessary: AC-2 requires no surviving `player.set_gravity` call site, and a
       `connect()` to a removed method is a RUNTIME error that aborted `Main._ready()`
       and failed all three `kill_area_death_test` cases. Recorded as an accepted
       out-of-scope deviation in GA-003's Completion Notes.

    ## Two findings from the 2026-08-26 review worth not rediscovering

    1. **A subagent claim that was INVALIDATED.** qa-tester reported that
       `GravityAuthority.initialize()` might be a one-shot guard, making cross-suite
       seeding order-dependent. It is not — there is no `_initialized` early-return
       in the function; it re-seeds unconditionally and its doc comment says that is
       deliberate. The agent correctly flagged its own uncertainty. Premise false, no
       defect.
    2. **A latent defect that was FIXED before close.** `_reset_authority()` in
       `player_gravity_consumer_test.gd` wrote private authority state through
       `Object.set()`. Probed against the 4.7.1 binary: `set()` on a missing property
       returns null and raises NO error. A rename of `_initialized` would have
       silently disabled the AC-3 guard while the test kept passing. Now a direct,
       statically-checked write. Do not revert it to `set()`.

    ## Still open, unchanged

    - **Stage is still `Pre-Production`.** The 2026-08-25 gate returned CONCERNS, not
      PASS, and the skill advances only on PASS. Advancing is the developer's call.
    - **Merge `vertical-slice` into `development`?** Developer's call. `.github/` does
      not exist on `development`, so the four proven ADR CI guards do not guard the
      trunk. No `gh` CLI here — opening a PR is a browser action.
    - **A pre-existing ADR-0002 violation sits in `main.gd:36,66`** —
      `GameManager.reset_level_state()` is the registered forbidden pattern
      `level_state_reset_method`. **Not introduced by GA-003/GA-004**; removal is
      owned by LS-001..LS-004. Do not mistake it for a gravity regression.
    - **QQ-03 — the 8 built levels do not implement the current design and no epic
      owns migrating them.** Intersects GA-005 AC-3, which requires all 8 level
      scenes to declare `default_gravity_direction` / `default_gravity_multiplier`.
    - Open tech-debt rows include: `direction_ease_rate` has no `@export_range` floor
      (owned by GA-001); `_settle_steps()` lacks a ceiling assertion;
      **`control-manifest.md:170` is stale at "~6-7 frames", actually 5 — fix it
      BEFORE GA-007 sizes its wake pass against it.**
    - `/create-control-manifest update` is owed. `/review-all-gdds` and
      `/design-review` x6 have never been run and have no owner.
    - BUG-0002 and the remaining tech-debt items sit in the backlog with no owners.

    ## Working rules

    - Follow the collaboration protocol in `CLAUDE.md`. Ask before Write or Edit,
      show the changeset, do not commit unless told.
    - **NEVER `git add -A`.** It swept an unrelated level edit into a docs commit on
      2026-08-25. Stage named paths and read the diff. If Godot is open, expect scene
      files to drift.
    - **Commit messages must follow Conventional Commits** (`feat:`, `fix:`, `docs:`,
      `test:`) and reference the story ID in the body (`Story: GA-004`). HEAD
      `1c58501` does neither — do not use it as the template.
    - **Run `--import` after writing any new test file** to generate its `.uid`
      sidecar. A clean CI checkout needs them.
    - **Never tick a blocking AC on inference.** Open the story file and read its
      Test Evidence status.
    - **An empty `blocker` field is not proof of no gate**, and a `Blocked` status
      header is not proof of a live one — LV-005 and LV-006 carry stale headers.
    - When reality and an approved AC diverge, **annotate the AC**. Do not silently
      tick it and do not reword the requirement.
    - **Before relaying a subagent's severity that depends on project config, open
      the config file yourself.** `project.godot` has NO `debug/gdscript/warnings/*`
      section. That has now invalidated five BLOCKING findings.
    - **Verify a subagent's completion claim yourself**, and check whether a flagged
      line is even part of the changeset. In the 2026-08-26 review, 9 of 11 specialist
      findings landed on lines the changeset never touched.
    - **Where a spec states a duration, tolerance or floor, compute the MARGIN**, not
      just whether it passes. GA-002's addendum quoted rounded-UP figures (16.7 ms,
      +0.51 deg) whose true values are 16.667 and 0.50806 — an assertion floor at the
      quoted figure fails a correct implementation.
    - **When a QA plan and a story's Out of Scope section disagree, the story wins**,
      and you record the deviation.
    - **Two OPEN 4.7.1 engine unknowns sit in Sprint 2's scope.** GA-006 carries
      ADR-0001 Verification 2 (does a default-space write reach every `RigidBody2D` in
      the same step?). LV-006 carries the headless `Area2D` extent read on a node
      never added to a tree. Verify each against the binary before building on it.
      GA-006 has a named fallback.
    - **The windowed Godot editor segfaults on this machine.** The route around it is
      the read-only headless probe at
      `production/qa/evidence/editor-facts-probe-2026-08-25.md`. It proves data, not
      rendering. Reuse it; do not re-derive it. A one-off `--headless --script` probe
      is also a legitimate way to settle an engine-semantics question — that is how
      the `Object.set()` finding above was confirmed.
    - Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
      discovery, so one warning anywhere fails the whole suite.
    - Use the Write tool, not Bash heredocs, for any file with apostrophes or long
      prose. Heredocs have mangled two sessions' worth of writes.
    - **`session-logs/` was deleted on 2026-08-25 by an unidentified cause** and is
      gitignored. The tracked record is the source of truth:
      `production/gate-checks/`, `production/sprints/`, `production/qa/`,
      `production/retrospectives/`, `production/epics/`,
      `docs/tech-debt-register.md`, and the git log.

    DO NOT re-run `/gate-check production`, `/retrospective`, `/sprint-plan new`,
    `/qa-plan sprint`, CI-1, or `/code-review` on GA-003 / GA-004. All are done.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. HEAD is `1c58501` and the tree is CLEAN — everything
    is committed, so ignore every older prompt that agonises over a commit split.
    GA-003 is Complete. **GA-004 is committed, green and ALREADY code-reviewed
    (APPROVED WITH SUGGESTIONS) but still reads `in-progress`** — run `/story-done`
    on it and do NOT re-run `/code-review`. Suite is **233/233 across 14 suites**.
    When closing GA-004: do not tick the camera-rewire check (manual, needs a human,
    editor segfaults here, defers to the post-GA-005 sprint playtest); repoint its
    Test Evidence block at `tests/integration/gravity/gravity_zone_wiring_test.gd`;
    and log one advisory — GA-004 AC-1/AC-2 are proven ONLY by source-text matching,
    no test ever runs `main.gd._ready()`, so the deferred manual check is the sole
    runtime proof. Do not fix that with a throwaway test against `main.gd`; LS-004
    deletes it. Then continue with **LS-001..LS-004**, the unblocked track, which is
    also what unblocks GA-005 and closes the zero-gravity-at-load gap in
    `docs/tech-debt-register.md`. Review mode is `lean`. Ask before writing. Never
    `git add -A`.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/story-done` on GA-004 | agent work, ~15 min | the LS track starting cleanly |
| Delete the 3 consumed `continue-*.md` prompts | agent work, tracked files | nothing; noise |
| LS-001 → LS-002 → LS-003 → LS-004 | agent work, unblocked | GA-005, and a playable build |
| GA-005 | **blocked on LS-004** | the game being playable again |
| Zero-gravity-at-load, halves (a) and (b) | tech debt, fix is GA-005 AC-2 | playing levels in sequence |
| GA-006, GA-007 | agent work | Foundation completion |
| Sprint gravity playtest (GA-003 AC-8 + GA-004 camera) | **human** — editor segfaults | closing both stories fully |
| Fix `control-manifest.md:170` (6-7 → 5 frames) | agent work, ~1 line | GA-007 sizing its wake pass |
| `direction_ease_rate` range floor (owned by GA-001) | tech debt, cheap | nothing |
| `_settle_steps()` ceiling assertion | tech debt, cheap | nothing |
| ADR-0001 basis erratum | doc fix | nothing; do not re-add local basis |
| `GameManager.reset_level_state()` in `main.gd` | pre-existing ADR-0002 breach | owned by LS-001..004 |
| Advance `production/stage.txt` to `Production` | **human** — gate was CONCERNS | nothing mechanical |
| Merge `vertical-slice` into `development` | **human** — browser PR | CI guards reaching the trunk |
| QQ-03 — level migration epic (intersects GA-005 AC-3) | unowned | pillars 2 and 3 |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| BUG-0002, remaining tech-debt items | backlog, no owners | nothing |
