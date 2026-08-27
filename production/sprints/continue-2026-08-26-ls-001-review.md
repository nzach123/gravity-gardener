# Continuation Prompt — GA-004 closed; LS-001 built and green, awaiting review (2026-08-26, sixteenth session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `continue-2026-08-26-ga-004-close.md`**, which is fully consumed —
delete it when you commit this file. The three prompts it told you to delete were
deleted this session and are already staged.

What changed this session:

1. **GA-004 is Complete and closed.** `/story-done` ran. All 8 ACs ticked.
2. **LS-001 is IMPLEMENTED and GREEN but NOT reviewed and NOT closed.**
3. **A probe invalidated a load-bearing claim in ADR-0002.** This is the most
   important thing in this file and it changes LS-002 as well.
4. **The suite grew 233 -> 256** across 14 -> 15 suites.
5. **Nothing is committed.** The tree has ~12 changed/new paths.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 2 is in progress. GA-001 through
    GA-004 are Complete. LS-001 is IMPLEMENTED, GREEN and NOT YET REVIEWED. Review it,
    close it, then continue down the LS track.

    Ground yourself first. Do not trust any status you have not checked this session.
    Eight handoff documents in this repo have now outlived the facts they asserted.

    1. Run `git log --oneline -3` and `git status --short`. Expect a DIRTY tree with
       roughly twelve paths — GA-004's closure, LS-001's implementation, a new probe
       evidence doc, and three deleted continue-*.md prompts already staged.
    2. Read `production/session-state/active.md`. Its last extract is LS-001, dated
       2026-08-26, and it is current. **Read it before doing anything else.**
    3. Read `production/sprint-status.yaml` — LS-001 reads `status: in-progress`.
    4. Run the suite and confirm green before you change anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Expect **256/256, 15/15 suites, exit 0**. Keep the `-c` — without it the runner
       stops at the first failure and a red run under-reports. Use `-a res://tests`, not
       `-a res://tests/unit`. If the runner fails to load with `Could not find type
       "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`, retry.

    ## The finding that matters most — read this before touching LS-002

    **ADR-0002's A2-01 correction is factually wrong for Godot 4.7.1.** The ADR states
    at `adr-0002-level-state-ownership.md:246-248` that assignment to a getter-only
    property "raises a runtime error, which is what makes the guarantees below
    properties of the type rather than rules to police."

    It does not raise. It is **silently discarded**. Probed against the binary in four
    shapes — `Object.set()`, a `Variant`-typed reference, a statically-typed reference,
    and an in-script typed direct assignment. All four parse, all four leave the backing
    field unchanged, none raises anything. An out-of-bounds array read in the same
    script body raised loudly, so the silence is real and not a capture artefact.

    Full evidence: `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`.

    Split the claim in two and keep the halves apart:

    - **Safety HOLDS.** External code cannot corrupt the object. Building `LevelState`
      and `OxygenState` exactly as ADR-0002 specifies is still correct.
    - **Detection DOES NOT.** A caller writing `level_state.goal_unlocked = true` gets
      a no-op with no diagnostic — precisely the failure mode A2-01 claimed getter-only
      properties remove.

    Already absorbed, do not redo: LS-001's assignment criterion (**QA case AC-4**, not
    AC-5) is ANNOTATED in the story rather than reworded; the 2026-08-25 QA-plan
    addendum bullet demanding an assertion that the write "raises a runtime error" is
    annotated as unsatisfiable against a correct implementation; an ADR-0002 erratum row
    is logged in `docs/tech-debt-register.md`.

    **LS-002 (`OxygenState`) inherits this exact problem** — same pattern, same ADR
    paragraph at `:291`. Read the tech-debt row before writing its assignment test. Do
    not re-run the probe; it is settled.

    ## Two more engine facts, probed this session

    - **`x is Node` on a statically-typed `RefCounted` is a PARSE error**, not a runtime
      check: `Expression is of type "LevelState" so it can't be of type "Node"`. It
      failed gdUnit4 discovery for the WHOLE run (`Abnormal exit with 105`). The engine
      gives a stronger guarantee than the ADR asks for, but it is not assertable in that
      shape. Working form: `get_class() == "RefCounted"` plus
      `ClassDB.is_parent_class(..., "Node") == false`.
    - **`Object.set()` returns `void` in 4.7.1.** Capturing its return value is itself a
      script error. This corrects an older session note that said it returns `null`.

    ## Do these, in this order

    ### 1. `/code-review` on the two new LS-001 files

        src/scripts/level_state.gd
        tests/unit/level_state/level_state_test.gd

    Review mode is `lean`. Nothing else in `src/` or `tests/` was touched — verify that
    with `git status` rather than trusting it.

    Three things the review must NOT "fix":

    1. **The AC-4 assignment test does not assert that an error is raised.** That is
       deliberate and correct per the probe above. Asserting a raise fails against a
       correct implementation. `carrying_bucket` is asserted in the same test as the
       assignable negative control so the test cannot pass vacuously.
    2. **`_init`'s parameter is `initial_buckets_total`, not `buckets_total`** as
       ADR-0002 Key Interfaces spells it. The ADR spelling shadows the property, and
       `SHADOWED_VARIABLE` is a default-on warning that gdUnit4 escalates to a
       discovery-time error. Type, arity and call shape are unchanged; GDScript has no
       named arguments, so no caller is affected.
    3. **The no-reset test asserts by reflection over `get_method_list()`**, never by
       source grep. A grep for `reset` passes on a method named `clear()`.

    ### 2. `/story-done` on LS-001

    Record in its Completion Notes:

    - **An accepted out-of-scope deviation**: `_init` clamps a negative
      `buckets_total` to 0 with `push_error()`. The story and ADR-0002 say only
      "callers must pass `>= 0`", so a negative is a caller bug with no defined
      behaviour. Kept by explicit developer decision on 2026-08-26 because the silent
      alternative is worse — with no clamp `_goal_unlocked = (0 >= -3)` is true, so a
      mis-authored level unlocks its goal at construction with no diagnostic. Two tests
      cover it at the end of the test file.
    - **The ADR-0002 erratum**, cross-referenced to the probe evidence and the
      tech-debt row.
    - **The parameter-name deviation** in item 2 above.

    ### 3. Then continue: LS-002 -> LS-003 -> LS-004

    Run `/story-readiness` before `/dev-story` on each. All six LS story files exist
    under `production/epics/level-state/` and LS-002..006 read `ready-for-dev`.

    **LS-004 is the one that matters most.** It creates `LevelRoot`, which unblocks
    GA-005, which is what closes BOTH halves of the zero-gravity-at-load gap and makes
    the game playable in sequence again.

    ## A design consequence to carry into LS-004

    `goal_unlocked_changed` is **never emitted at construction**, because a signal
    emitted inside `_init()` cannot be received — nothing is connected yet. A level with
    `buckets_total == 0` is therefore unlocked from construction with NO signal ever
    firing.

    **Consumers must READ `goal_unlocked` when they bind, not rely on the signal alone.**
    A consumer that only connects will never unlock a zero-bucket level. This is a real
    constraint on LS-004's `bind()` guards and on the Goal and HUD consumers. It is in
    the signal's doc comment and asserted by a test.

    ## What LS-001 actually built

    `src/scripts/level_state.gd` — `class_name LevelState extends RefCounted`. Signals
    `goal_unlocked_changed(unlocked: bool)` and `bucket_consumed(consumed: int, total:
    int)`. Getter-only `buckets_total`, `buckets_consumed`, `goal_unlocked`,
    `level_complete` over private backing fields; plain read-write `carrying_bucket`.
    `_init(initial_buckets_total: int)` and `consume_bucket()`. **No `mark_complete()`**
    (story 005), no `reset()`, no `clear()`, no setters. It is NOT wired into anything
    and is NOT an autoload — that is LS-004.

    `tests/unit/level_state/level_state_test.gd` — 23 test functions, `.uid` present.

    ## Still open, unchanged

    - **GA-005 is BLOCKED on LS-004.** Its `blocker` field says why.
    - **The zero-gravity-at-load gap has TWO halves** and half (b) produces no log line:
      every level after the first inherits the PREVIOUS level's gravity, because the
      authority is an autoload surviving scene changes. Closed by GA-005 AC-2.
    - **GA-004's AC-1/AC-2 are proven ONLY by source-text matching.** No test runs
      `main.gd._ready()`. The deferred manual camera check is the only runtime proof.
      The fix is to make `LevelRoot`'s wiring test BEHAVIOURAL when LS-004 lands — not a
      throwaway test against `main.gd`, which LS-004 deletes.
    - **Stage is still `Pre-Production`.** The 2026-08-25 gate returned CONCERNS.
      Advancing is the developer's call.
    - **Merge `vertical-slice` into `development`?** Developer's call. `.github/` does
      not exist on `development`, so the four proven CI guards do not guard the trunk.
      No `gh` CLI here — opening a PR is a browser action.
    - **A pre-existing ADR-0002 violation sits in `main.gd:36,66`** —
      `GameManager.reset_level_state()`, the registered forbidden pattern
      `level_state_reset_method`. Removal is owned by LS-001..LS-004. It is NOT a
      gravity regression.
    - **QQ-03** — the 8 built levels do not implement the current design and no epic
      owns migrating them. Intersects GA-005 AC-3.
    - Open tech-debt rows: `direction_ease_rate` has no `@export_range` floor;
      `_settle_steps()` lacks a ceiling assertion; **`control-manifest.md:170` is stale
      at "~6-7 frames", actually 5 — fix BEFORE GA-007 sizes its wake pass against it.**
    - `/create-control-manifest update` is owed. `/review-all-gdds` and `/design-review`
      x6 have never been run and have no owner.
    - BUG-0002 and the remaining tech-debt items sit in the backlog with no owners.
    - **Untracked probe scripts may still sit at `.probe_tmp/`.** They are disposable —
      the evidence doc captures everything. Delete them.

    ## Working rules

    - Follow the collaboration protocol in `CLAUDE.md`. Ask before Write or Edit, show
      the changeset, do not commit unless told.
    - **NEVER `git add -A`.** It swept an unrelated level edit into a docs commit on
      2026-08-25. Stage named paths and read the diff.
    - **Commit messages must follow Conventional Commits** and reference the story ID in
      the body (`Story: LS-001`).
    - **Run `--import` after writing any new test file** to generate its `.uid` sidecar.
    - **Never tick a blocking AC on inference.** Open the story file and read its Test
      Evidence status.
    - **When reality and an approved AC diverge, ANNOTATE the AC.** Do not silently tick
      it and do not reword the requirement. That is what was done to LS-001's AC-4.
    - **A `--headless --script` probe is the sanctioned way to settle an engine-semantics
      question.** Three findings this session came from one. The windowed Godot editor
      segfaults on this machine; do not try to open it.
    - **Verify a subagent's completion claim yourself.** Re-run the suite; check whether
      a flagged line is even part of the changeset. An executor's numbering can also be
      right where your own brief was wrong — that happened this session.
    - **Before relaying a subagent's severity that depends on project config, open the
      config file yourself.** `project.godot` has NO `debug/gdscript/warnings/*` section.
      That has invalidated five BLOCKING findings so far.
    - Static typing everywhere. gdUnit4 treats a GDScript warning as an error AT
      DISCOVERY, so one warning anywhere fails the whole suite at compile time.
    - Use the Write tool, not Bash heredocs, for any file with apostrophes or long prose.
    - `session-logs/` was deleted on 2026-08-25 by an unidentified cause and is
      gitignored. The tracked record is the source of truth.

    DO NOT re-run `/gate-check production`, `/retrospective`, `/sprint-plan new`,
    `/qa-plan sprint`, CI-1, `/code-review` on GA-003 / GA-004, or the getter-only
    probe. All are done.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. Tree is DIRTY and nothing is committed. GA-001..GA-004
    are Complete. **LS-001 is implemented and green (256/256 across 15 suites) but NOT
    reviewed and NOT closed** — run `/code-review` on `src/scripts/level_state.gd` and
    `tests/unit/level_state/level_state_test.gd`, then `/story-done`.

    Before anything else read
    `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`: **ADR-0002's
    claim that assignment to a getter-only property "raises a runtime error" is FALSE in
    4.7.1** — the write is silently discarded, probed in four shapes with a live error
    control. Safety holds, detection does not. LS-001's AC-4 is already annotated and an
    erratum is logged; **LS-002 inherits the same problem** — read the tech-debt row
    before writing its assignment test.

    In review, do NOT "fix" three things: the AC-4 test deliberately does not assert a
    raise; `_init`'s parameter is `initial_buckets_total` to avoid a shadowing warning
    that gdUnit4 escalates to a discovery-time error; the no-reset test uses reflection,
    not source grep. At close, record the accepted out-of-scope deviation — `_init`
    clamps a negative total to 0 with `push_error()`, kept deliberately because the
    silent alternative unlocks a mis-authored level's goal with no diagnostic.

    Then LS-002 -> LS-003 -> LS-004. LS-004 unblocks GA-005, which makes the game
    playable in sequence again. Review mode is `lean`. Ask before writing. Never
    `git add -A`.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/code-review` + `/story-done` on LS-001 | agent work, ~20 min | the LS track continuing |
| Commit the working tree (~12 paths) | needs developer instruction | nothing; risk of loss |
| Delete `.probe_tmp/` and the consumed prompt | agent work | nothing; noise |
| LS-002 → LS-003 → LS-004 | agent work, unblocked | GA-005, and a playable build |
| GA-005 | **blocked on LS-004** | the game being playable again |
| Zero-gravity-at-load, halves (a) and (b) | tech debt, fix is GA-005 AC-2 | playing levels in sequence |
| ADR-0002 A2-01 erratum | doc fix | nothing; do not add error-raising setters |
| ADR-0001 basis erratum | doc fix | nothing; do not re-add local basis |
| Make `LevelRoot`'s wiring test behavioural | owed by GA-004's advisory | runtime proof of GA-004 AC-1/AC-2 |
| GA-006, GA-007 | agent work | Foundation completion |
| Sprint gravity playtest (GA-003 AC-8 + GA-004 camera) | **human** — editor segfaults | closing both stories fully |
| Fix `control-manifest.md:170` (6-7 → 5 frames) | agent work, ~1 line | GA-007 sizing its wake pass |
| `GameManager.reset_level_state()` in `main.gd` | pre-existing ADR-0002 breach | owned by LS-001..004 |
| Advance `production/stage.txt` to `Production` | **human** — gate was CONCERNS | nothing mechanical |
| Merge `vertical-slice` into `development` | **human** — browser PR | CI guards reaching the trunk |
| QQ-03 — level migration epic | unowned | pillars 2 and 3 |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| BUG-0002, remaining tech-debt items | backlog, no owners | nothing |
