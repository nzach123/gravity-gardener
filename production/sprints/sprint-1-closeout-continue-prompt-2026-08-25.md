# Sprint 1 Close-Out — Continuation Prompt (2026-08-25, evening)

Paste the block below into a fresh Claude Code session.

**Supersedes `sprint-1-continue-prompt-2026-08-25.md`**, which is now stale in
every important way: all six decisions it asks for have been taken, both
playtests are signed off, and QA has returned a verdict. That file and
`sprint-1-continue-prompt-2026-08-24.md` are both dead paper — delete them when
convenient.

State at time of writing: branch `vertical-slice`, HEAD `09c8fc4`, tree clean,
16 commits unpushed. Suite green at 178/178. Sprint 1 ends 2026-08-31.

---

## Copy from here

    Resume Sprint 1 close-out on branch `vertical-slice`.

    Ground yourself first. Do not trust any status you have not checked this
    session.

    1. Read `production/sprint-status.yaml` — the source of truth for status.
    2. Read `production/qa/qa-signoff-sprint-1-2026-08-25.md` — the QA verdict
       and its four conditions. This is the most important file for what remains.
    3. Read `production/session-state/active.md` (gitignored).
    4. Run `git log --oneline -5` and `git status --short`.
    5. Run the suite and confirm green before changing anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Keep the `-c`. Without it the runner stops at the first failure and a red
       run under-reports. If it fails to load with `Could not find type
       "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
       then retry.

    ## Where the sprint actually stands

    QA verdict: APPROVED WITH CONDITIONS. 20 of 22 rows done, must-have 17/19.
    No S1 or S2 bugs open — BUG-0001 closed on playtest sign-off, so the
    Definition of Done's bar is met.

    DO NOT re-ask the six decisions from the previous prompt. All are settled and
    committed:

      D1  Five rows closed via /story-done.
      D2  TUN-003 closed on substituted evidence, ACs annotated not reworded.
      D3  CI trigger widened to `development` (d77337c).
      D4  Two superseded sprint files deleted and committed (f70e965).
      D5  BUG-0002 filed, S4, Sprint 2 (02ef7fb).
      D6  GA-002 settle threshold set to 2.5 degrees (41ea6fd).

    ## What is left — in this order

    ### 1. /retrospective   (not yet run)

    Material worth surfacing, all verifiable in this session's commits:

      - Two rows were closed on evidence that had never been recorded. TUN-005
        had its work landed but every AC unticked, "[ ] Not yet created" as its
        test evidence status, and no Implementation Record. A QA strategy pass
        called it "met" without opening it. Completed work with unwritten
        paperwork cost real time twice this sprint.
      - An empty `blocker` field is not proof of no gate. TUN-006's blocker was
        empty while its final AC was unmet. This has now cost two sessions.
      - A CI workflow targeted a branch that does not exist. tests.yml triggered
        on `main`; this repo has no `main`, local or remote, and `origin/HEAD`
        points at `development`. That job had never fired once. Nobody noticed
        because "CI is configured" was never distinguished from "CI has run".
      - A subagent reported four BLOCKING findings from an assumed project
        config. `project.godot` has no `debug/gdscript/warnings/*` section, so
        the warnings it premised them on are off by default and the suite was
        green. The findings were real; the severity was invented.
      - Two zero-margin thresholds were caught, one proposed in-session:
        `MIN_TILEMAP_LAYERS = 9` against a real count of 9, and a 1-degree settle
        epsilon that landed on exactly 100.0 ms against a 100 ms requirement.

    ### 2. /sprint-plan new   (not yet run)

    Sprint 2 input, already known:

      - GA-002..GA-007 — the gravity-authority epic, 2.39 d. GA-002 is now READY;
        its unsatisfiable settle assertion was fixed in 41ea6fd. Run
        /story-readiness to confirm before /dev-story.
      - LV-005 — blocked until the level-state epic lands. LevelState and
        OxygenState do not exist, and this story's subject is the ORDERING
        between validate() and their construction.
      - LV-006 — blocked on TWO prerequisites. PropTuning landed and satisfies
        the first. The second is `class_name PropBody` under ADR-0011, and NO
        EPIC COVERS PHYSICS PROPS. Unschedulable until that epic exists. Earlier
        notes calling it "now genuinely unblocked" were wrong.
      - BUG-0002 — S4, the `MovingPlatfornm` root-node typo. Five-line rename, no
        code references, found by group not by name. Land it AFTER anything that
        depends on CLR-003's playtest.
      - `docs/tech-debt-register.md` holds 10 open items — 3 from GA-001, 7 from
        the CLR-004 code review. Do not lose them.

    ### 3. The CI run — QA condition 1, closes CLR-005 and TUN-006

    The only remaining must-have work in Sprint 1, and it needs a human.

    READ THIS BEFORE ATTEMPTING IT: a scratch branch pushed on its own will NOT
    trigger the workflow. It fires on push to `development`/`main`, or on a pull
    request TARGETING them. The verification needs either a PR against
    `development` or a direct push to `development`. There is no `gh` CLI on this
    machine, so opening a PR is a web-UI action by the developer.

    What must be demonstrated, one violation at a time, each confirmed red, then
    reverted:

      - CLR-005: a `set_collision_mask_value()` call added to `player.gd` -> the
        ADR-0004 D4.6 step fails with a readable message, and the GdUnit4 step
        still runs or is correctly short-circuited.
      - TUN-006: a `res://src/resources/tuning/prop_tuning.tres` literal in a
        gameplay script -> V6 fails. `Tuning.PROP.prop_gravity_scale = 1.5` ->
        V7 fails. `Tuning.PROP.duplicate()` -> V7 fails. A
        `src/scripts/tuning/gravity_tuning.gd` file -> V8 fails.

    Do NOT run /gate-check for a Pre-Production to Production advance until this
    is done. A phase gate resting on two CI guards nobody has seen execute is the
    same class of gap this sprint spent effort closing.

    ## Working rules

    - Follow the collaboration protocol in CLAUDE.md. Ask before Write/Edit, show
      the changeset, do not commit unless told.
    - Review mode is `lean` (`production/review-mode.txt`).
    - NEVER `git add -A`. It swept an unrelated level edit into a docs commit this
      session — SpikeHazard3 in level_04.tscn had moved during a play session and
      was committed unreviewed, then reverted in df0c332. Stage named paths and
      read the diff first. If Godot is open, expect scene files to drift.
    - When reality and an approved AC diverge, annotate the AC with the
      divergence. Do not silently tick it and do not reword the requirement. Four
      examples now exist: TUN-003 AC-4/5/6 and CLR-003 AC-5 (METHOD SUBSTITUTED),
      LV-001 AC-3 (CLAUSE SUPERSEDED), GA-002 AC-1 (DEFECT RESOLVED).
    - Do not tick a blocking AC on inference. TUN-005's negative checks were
      assumed done by two separate passes; they had never been recorded, and
      running them was a two-minute job that turned assumption into evidence.
    - Before relaying a subagent's severity that depends on project config, open
      the config file yourself.
    - Where a spec states a duration, tolerance, or floor, compute the MARGIN,
      not just whether it passes.
    - TUN-005's V1 stands. Re-pointing a `.tres` at the wrong script is a parse
      error at load, not a group-1 failure. V1 guards GH#73615, where a preload
      resolves non-null yet wrong-type. Do NOT weaken V1 to a null check to make
      the negative path observable.
    - Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
      discovery, so one warning anywhere fails the whole suite.
    - 16 commits are unpushed. Nothing from the close-out has left the machine.

    Start with /retrospective.

## Copy to here

---

## Shorter variant

    Resume Sprint 1 close-out on `vertical-slice`. Read
    `production/sprint-status.yaml` and
    `production/qa/qa-signoff-sprint-1-2026-08-25.md`, re-derive git and test
    state, then run /retrospective followed by /sprint-plan new. QA returned
    APPROVED WITH CONDITIONS; the six earlier decisions are all settled — do not
    reopen them. The only outstanding must-have work is a scratch-branch CI run
    that needs a PR against `development` or a direct push, which is the
    developer's call. Ask before writing.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/retrospective` | agent work | sprint close |
| `/sprint-plan new` | agent work | Sprint 2 start |
| Scratch-branch CI run | **human** — needs a PR or a push | CLR-005 + TUN-006, and `/gate-check` |
| BUG-0002 | Sprint 2 | nothing |
| 10 tech-debt items | backlog | nothing |
