# Continuation Prompt — GA-003 and GA-004 implemented, awaiting review (2026-08-26, fourteenth session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `continue-2026-08-26-ga-003.md`**, which is fully consumed. Delete it
when you commit this file. `continue-2026-08-25-qa-plan-sprint-2.md` is also long
consumed and still present — delete that too.

What changed this session, that every earlier handoff gets wrong:

1. **GA-003 and GA-004 are IMPLEMENTED.** Both were `ready-for-dev` in every
   earlier prompt. Neither is reviewed and neither is closed.
2. **The suite is 233/233 across 14 suites, not 191/191 across 12.** The 191
   figure was correct only at the start of this session.
3. **The "commit the backlog" instruction in the last prompt was already moot.**
   All three groups it described were squashed into `b33c996` before this session
   started. A NEW uncommitted backlog now exists — see below.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 2 is in progress. GA-001 and
    GA-002 are Complete. GA-003 and GA-004 are IMPLEMENTED AND VERIFIED GREEN BUT
    NOT REVIEWED AND NOT CLOSED. Your job is to close them, then continue.

    Ground yourself first. Do not trust any status you have not checked this
    session. Six handoff documents in this repo have now outlived the facts they
    asserted.

    1. Read `production/session-state/active.md`. Read the Session Extract blocks
       at the end first. **WARNING: `active.md` has NO extract for GA-003 or
       GA-004.** `/dev-story` Phase 7 was not run for either story. Its newest
       entry is the GA-002 `/story-done` block from earlier on 2026-08-26, so the
       file understates progress by two stories. The tracked record and the
       working tree are the truth, not `active.md`.
    2. Read `production/sprint-status.yaml` — GA-003 and GA-004 both read
       `status: in-progress`.
    3. Run `git log --oneline -3` and `git status --short`.
    4. Run the suite and confirm green before you change anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Expect **233/233, 14/14 suites, exit 0**. Keep the `-c`. Without it the
       runner stops at the first failure and a red run under-reports. Use
       `-a res://tests`, not `-a res://tests/unit`. If the runner fails to load
       with `Could not find type "GdUnitTestCIRunner"`, the `.godot` class cache
       is stale — run `--import`, then retry.

    ## What is uncommitted

    Nothing from this session is committed. The last commit is `b33c996`. The
    working tree holds ONE logical unit — ADR-0001's atomic Changeset A:

      M src/scripts/components/player_gravity_component.gd   GA-003
      M src/scripts/player.gd                                GA-003
      M src/scripts/debugger.gd                              GA-003
      M tests/unit/gravity/gravity_component_test.gd         GA-003
      M src/scripts/main.gd                                  GA-003 + GA-004
      M src/scenes/gravity_zone.tscn                         GA-004
      ?? tests/integration/gravity/                          both (4 files)
      M production/epics/gravity-authority/story-003-*.md    Last Updated only
      M production/epics/gravity-authority/story-004-*.md    Last Updated only
      M production/sprint-status.yaml                        two status marks

    `tests/integration/gravity/` is UNTRACKED and holds four files:
    `player_gravity_consumer_test.gd` (+ `.uid`) and
    `gravity_zone_wiring_test.gd` (+ `.uid`). Both sidecars exist — verify before
    committing, a clean CI checkout needs them.

    **The developer has not chosen a commit split.** The open proposal is two
    commits (GA-003, then GA-004) because the stories are reviewed separately even
    though ADR-0001 requires them to land together. One "Changeset A" commit is the
    alternative. `main.gd` is touched by both stories, so a two-commit split needs
    a staged hunk, not a whole-file add. **NEVER `git add -A`.**

    ## Do these, in this order

    ### 1. `/code-review`, then `/story-done`, on both stories

    Review mode is `lean`, so `/story-done` skips the QA coverage gate and asks
    whether `/code-review` was run. It has not been.

    Files:
      src/scripts/components/player_gravity_component.gd
      src/scripts/player.gd
      src/scripts/debugger.gd
      src/scripts/main.gd
      tests/integration/gravity/player_gravity_consumer_test.gd
      tests/integration/gravity/gravity_zone_wiring_test.gd
      tests/unit/gravity/gravity_component_test.gd

    **Three items were deliberately sent to review rather than fixed. Do not treat
    them as new findings:**

    1. `player_gravity_consumer_test.gd` mutates the autoload's private
       `_initialized` and `_current_multiplier` through `Object.set()` in a
       `_reset_authority()` helper. The autoload survives between suites and has no
       public route back to its pre-`initialize()` state, and story AC-3 requires
       asserting the state BEFORE `Player._ready()`. `after_test()` re-seeds and
       calls `reset_to(Vector2.DOWN, 1.0)`. `gravity_authority.gd` was not touched.
    2. `gravity_zone_wiring_test.gd` spies on the ZONE's `gravity_changed` rather
       than on `GravityAuthority.set_gravity` directly, to prove the zone did not
       filter before forwarding.
    3. `src/scripts/main.gd` was on GA-003's exclusion list but GA-003 edited it
       anyway, deleting `zone.gravity_changed.connect(player.set_gravity)`. This
       was correct and necessary: AC-2 requires no surviving `player.set_gravity`
       call site anywhere in `src/`, and a `connect()` to a removed method is a
       RUNTIME error — it aborted `Main._ready()` and failed all three
       `kill_area_death_test` cases until removed. Accepted as a deviation by the
       developer. GA-004 then replaced it with the authority wiring.

    **When you close the stories, both have an unmet manual AC. Do not tick
    either.** GA-003 AC-8 (four-angle play regression) and GA-004's camera-rewire
    no-change check are both `DEFERRED`. Each story's QA addendum folds it into the
    sprint's single gravity-path playtest, which runs AFTER GA-005 lands, signed
    off by qa-lead, recorded at
    `production/qa/evidence/playtest-sprint-2-gravity-regression.md`. Neither
    evidence file exists yet. Both story files still carry
    `**Status**: [ ] Not yet created` under Test Evidence — update those to point
    at the real test files.

    The windowed Godot editor segfaults on this machine, so no agent can run these
    manual checks. A human must.

    ### 2. Write the two deferred records the developer approved in principle

    Both were drafted and shown last session; neither is written. Confirm wording
    before writing.

    **A row for `docs/tech-debt-register.md`**, same format as the four 2026-08-26
    GA-002 rows: `GravityAuthority.gravity` initializes to `Vector2.ZERO` and
    nothing seeds it at level load. GA-003 deleted the old seed at
    `player_gravity_component.gd:42` by design; ADR-0001 part 6 puts the
    replacement in `LevelRoot._ready()`, which does not exist yet. Until then a
    freshly loaded level leaves the player INERT, not merely weightless —
    `apply_gravity()` adds a zero vector, `up_dir`/`right_dir` are `Vector2.ZERO`
    so movement, jump and wall-jump all get a zero basis, and `player.gd` assigns
    `up_direction = Vector2.ZERO`, which breaks floor detection too. **Observable
    evidence: level scenes under `scene_runner` now log `up_direction can't be
    equal to Vector2.ZERO`.** It is a log line, not a test failure — the suite is
    green. Gravity starts working the moment any zone fires. The fix is GA-005
    AC-2, already designed and scheduled. No interim workaround was added, by
    explicit developer decision on 2026-08-26.

    **A `blocker` correction in `production/sprint-status.yaml`** — GA-005's
    `blocker` field is EMPTY while its own Dependencies section says it "extends
    `LevelRoot` and cannot create it". Fill it: cross-epic sequencing, GA-005 AC-2
    puts `reset_to()` in `LevelRoot._ready()`, `LevelRoot` is created by LS-004,
    so GA-005 cannot start until LS-004 lands — and that is also what closes the
    zero-gravity-at-load gap above.

    ### 3. Update `production/session-state/active.md`

    Append Session Extract blocks for GA-003 and GA-004. `/dev-story` Phase 7 was
    skipped for both. The file is the crash-recovery record and is currently two
    stories behind.

    ### 4. Then continue the sprint

    **GA-005 is the natural next GA story but is BLOCKED on LS-004** (see above).
    The unblocked work is the level-state track, which is independent of the
    gravity track: **LS-001 → LS-002 → LS-003 → LS-004**. Running LS-001..LS-004
    is also what unblocks GA-005, which is what makes the game playable again.

    Run `/story-readiness` before `/dev-story` on whichever you pick.

    ## What GA-003 and GA-004 actually did

    **GA-003** — `PlayerGravityComponent` is now a consumer. It declares three
    `float` fields and NO `Vector2` at all, so `private_gravity_copy` is
    structurally impossible. Removed: `gravity`, `target_gravity`,
    `baseline_ascent_mag`, `ascent_descent_ratio`, `up_dir`, `right_dir`,
    `set_gravity()`, `update_derived_dirs()`, `update_gravity_lerp()`, and the seed
    at line 42. `Player.set_gravity()` and the `target_gravity` proxy are gone; the
    `up_dir`/`right_dir` proxies survive, repointed at `GravityAuthority`.
    `debugger.gd:13` was repointed to `GravityAuthority.target_gravity` — it was a
    live call site that no compiler would have caught.

    **GA-004** — zones connect to `GravityAuthority.set_gravity` inside the loop in
    `main.gd`; the camera handler connects ONCE to
    `GravityAuthority.gravity_changed` OUTSIDE the loop. `gravity_zone.tscn` lost
    `gravity_space_override = 3` and `gravity = -980.0`; nothing else in that file
    moved. **`gravity_zone.gd` was not modified at all** — it already had no local
    validation and no `body_exited` handler, so AC-5 and AC-6 were already
    satisfied by the authored source.

    Suite went 191/12 → 205/13 (GA-003, +32 new functions) → 233/14 (GA-004, +28).

    ## Two resolutions that must survive — do not relitigate

    1. **ADR-0001 vs GA-003 on the derived basis.** ADR-0001's Key Interfaces says
       the component "retains ... the derived basis". GA-003's AC-6 and
       Implementation Notes say the opposite. **The story won.**
       `update_derived_dirs()`, `up_dir` and `right_dir` were deleted from the
       component; all basis reads come from `GravityAuthority`. Rationale: ADR
       Decision part 1 puts the basis on the authority, GA-001 already implemented
       `_derive_basis()` there, and the control manifest requires reading
       `GravityAuthority.up_dir`. A second local derivation is exactly the
       divergence AC-6's edge case describes — it agrees at both endpoints of an
       ease and disagrees for the ~83 ms between. The ADR line is loose prose. It
       has NOT been amended; if that bothers a reviewer, raise it as an ADR
       erratum, do not re-add the local basis.
    2. **How `Player` seeds the authority.** AC-1 removes `baseline_ascent_mag` and
       `ascent_descent_ratio` as declared fields; AC-3 requires `Player._ready()`
       to pass both to `GravityAuthority.initialize()`. Resolved by keeping
       `gravity_ascent_mag` / `gravity_descent_mag` (initialize-time derivations,
       which AC-1 does not remove) and adding two typed accessors:
       `baseline_ascent_magnitude() -> float` and `ascent_descent_ratio() -> float`.
       No new stored field. The ratio accessor `push_error()`s and returns `0.0`
       pre-initialize so the authority's own guard refuses rather than dividing by
       zero.

    ## One coverage note carried forward

    GA-003 deleted `test_set_gravity_ignores_direction_magnitude` as deduped
    against `gravity_authority_contract_test.gd`. That dedup was genuinely thinner
    than the other nine — the contract test exercises non-unit directions but never
    asserts that a long direction vector does not leak its length into gravity
    STRENGTH. **GA-004 re-added it** as
    `test_a_long_zone_direction_does_not_leak_into_gravity_strength` plus
    `test_a_long_zone_direction_broadcasts_a_unit_direction`. The gap is closed;
    this note exists so nobody "rediscovers" it.

    ## Still open, unchanged from the last handoff

    - **Stage is still `Pre-Production`.** The 2026-08-25 production gate returned
      CONCERNS, not PASS, and the skill advances only on PASS. Advancing is the
      developer's call and has not been made.
    - **Merge `vertical-slice` into `development`?** Developer's call. `.github/`
      does not exist on `development`, so the four proven ADR CI guards do not
      guard the trunk. No `gh` CLI on this machine — opening a PR is a browser
      action.
    - **QQ-03 — the 8 built levels do not implement the current design and no epic
      owns migrating them.** Note this now intersects GA-005 AC-3, which requires
      all 8 level scenes to declare `default_gravity_direction` and
      `default_gravity_multiplier`.
    - Three earlier GA-002 tech-debt rows remain open: `direction_ease_rate` has no
      `@export_range` floor (owned by GA-001, not GA-002); `_settle_steps()` lacks
      a ceiling assertion; **`control-manifest.md:170` is stale at "~6-7 frames",
      actually 5 — fix it BEFORE GA-007 sizes its wake pass against it.** The
      fourth row (the deferred `test_gravity_lerp_*` deletion) is CLOSED by GA-003.
    - `/create-control-manifest update` is owed. `/review-all-gdds` and
      `/design-review` x6 have never been run and have no owner.
    - BUG-0002 and 16 tech-debt items sit in the backlog with no owners.

    ## Working rules

    - Follow the collaboration protocol in `CLAUDE.md`. Ask before Write or Edit,
      show the changeset, do not commit unless told.
    - **NEVER `git add -A`.** It swept an unrelated level edit into a docs commit
      on 2026-08-25. Stage named paths and read the diff. If Godot is open, expect
      scene files to drift.
    - **Run `--import` after writing any new test file** to generate its `.uid`
      sidecar. GA-002's was missed at implementation and caught at code review.
    - **Never tick a blocking AC on inference.** Open the story file and read its
      Test Evidence status.
    - **An empty `blocker` field is not proof of no gate** — GA-005's is empty
      right now and it is genuinely blocked. A `Blocked` status header is not proof
      of a live gate either; LV-005 and LV-006 carry stale ones.
    - When reality and an approved AC diverge, **annotate the AC**. Do not silently
      tick it and do not reword the requirement.
    - **Before relaying a subagent's severity that depends on project config, open
      the config file yourself.** `project.godot` has no
      `debug/gdscript/warnings/*` section. That invalidated four BLOCKING findings
      in Sprint 1 and a fifth on 2026-08-26.
    - **Verify a subagent's completion claim yourself.** Both agents this session
      reported green; both were independently re-run and the files re-read before
      the claim was relayed. Both held up. Keep doing it.
    - **Where a spec states a duration, tolerance or floor, compute the MARGIN**,
      not just whether it passes. GA-002's addendum quoted rounded-UP figures
      (16.7 ms, +0.51 deg) whose true values are 16.667 and 0.50806 — an assertion
      floor at the quoted figure fails a correct implementation.
    - **When a QA plan and a story's Out of Scope section disagree, the story
      wins**, and you record the deviation.
    - **Two OPEN 4.7.1 engine unknowns sit in Sprint 2's scope.** GA-006 carries
      ADR-0001 Verification 2 (does a default-space write reach every
      `RigidBody2D` in the same step?). LV-006 carries the headless `Area2D` extent
      read on a node never added to a tree. Verify each against the binary before
      building on it. GA-006 has a named fallback.
    - **The windowed Godot editor segfaults on this machine.** The route around it
      is the read-only headless probe at
      `production/qa/evidence/editor-facts-probe-2026-08-25.md`. It proves the
      data, not the rendering. Reuse it. Do not re-derive it.
    - Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
      discovery, so one warning anywhere fails the whole suite.
    - Use the Write tool, not Bash heredocs, for any file with apostrophes or long
      prose. Heredocs have mangled two sessions' worth of writes.
    - `sed -i` with explicit line numbers is dangerous on a file being edited in
      the same pass. Prefer replacing a whole block, and read the section back
      after every line-addressed splice.
    - **`session-logs/` was deleted on 2026-08-25 by an unidentified cause** and is
      gitignored. The tracked record is the source of truth:
      `production/gate-checks/`, `production/sprints/`, `production/qa/`,
      `production/retrospectives/`, `production/epics/`,
      `docs/tech-debt-register.md`, and the git log. Do not reconstruct lost
      history from inference.

    DO NOT re-run `/gate-check production`, `/retrospective`, `/sprint-plan new`,
    `/qa-plan sprint`, or CI-1. All five are done.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. GA-003 and GA-004 are IMPLEMENTED and verified
    green but NOT reviewed and NOT closed — both read `in-progress` in
    `production/sprint-status.yaml`. The suite is **233/233 across 14 suites**, not
    the 191 or 178 older prompts state. Nothing is committed; the working tree is
    ADR-0001's Changeset A, including the UNTRACKED `tests/integration/gravity/`
    (4 files, both `.uid` sidecars present). First run `/code-review` on the seven
    changed source and test files, then `/story-done` on both stories — but do NOT
    tick GA-003 AC-8 or GA-004's camera check; both are manual, both need a human,
    and both defer to the sprint playtest after GA-005. Then write the two records
    the developer approved in principle: a `docs/tech-debt-register.md` row for the
    zero-gravity-at-load gap (evidence: `up_direction can't be equal to
    Vector2.ZERO` logged under `scene_runner`; fix is GA-005 AC-2), and a `blocker`
    value for GA-005 in `sprint-status.yaml`, which is empty while GA-005 is
    genuinely gated on LS-004 creating `LevelRoot`. Append GA-003 and GA-004
    Session Extracts to `active.md` — `/dev-story` Phase 7 was skipped for both.
    Then continue with **LS-001..LS-004**, which is the unblocked track and is also
    what unblocks GA-005. Review mode is `lean`. Ask before writing. Never
    `git add -A`.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/code-review` + `/story-done` on GA-003, GA-004 | agent work | closing Changeset A |
| Commit the Changeset A backlog (split undecided) | needs developer decision | nothing mechanical; risk grows |
| Tech-debt row: zero gravity at level load | agent work, ~1 row | nothing; GA-005 owns the fix |
| GA-005 `blocker` field is empty and wrong | agent work, ~1 line | someone pulling GA-005 blind |
| `active.md` missing 2 Session Extracts | agent work | crash recovery accuracy |
| LS-001 → LS-002 → LS-003 → LS-004 | agent work, unblocked | GA-005, and a playable build |
| GA-005 | **blocked on LS-004** | the game being playable again |
| GA-006, GA-007 | agent work | Foundation completion |
| Sprint gravity playtest (GA-003 AC-8 + GA-004 camera) | **human** — editor segfaults | closing both stories fully |
| Fix `control-manifest.md:170` (6-7 → 5 frames) | agent work, ~1 line | GA-007 sizing its wake pass |
| `direction_ease_rate` range floor (owned by GA-001) | tech debt, cheap | nothing |
| `_settle_steps()` ceiling assertion | tech debt, cheap | nothing |
| Advance `production/stage.txt` to `Production` | **human** — gate was CONCERNS | nothing mechanical |
| Merge `vertical-slice` into `development` | **human** — browser PR | CI guards reaching the trunk |
| QQ-03 — level migration epic (now intersects GA-005 AC-3) | unowned | pillars 2 and 3; GA-005 AC-3 |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| BUG-0002, 16 tech-debt items | backlog, no owners | nothing |
