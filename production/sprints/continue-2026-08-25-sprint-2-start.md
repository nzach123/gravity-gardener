# Continuation Prompt — Sprint 2 Start (2026-08-25, tenth session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `sprint-1-closeout-continue-prompt-2026-08-25.md`**, which is fully
consumed: `/retrospective` and `/sprint-plan new` have both run, Sprint 1 is
closed out, and Sprint 2 is planned. That file is deleted in the same commit as
this one.

State at time of writing: branch `vertical-slice`, tree clean, roughly twenty
commits unpushed — **re-derive both rather than trusting these**. Suite green at
178/178. Sprint 1 ends 2026-08-31;
Sprint 2 runs 2026-09-01 to 2026-09-14.

There is a second, task-specific prompt at
`production/sprints/qa-plan-sprint-2-prompt.md`. Use that one if you are running
`/qa-plan sprint` and nothing else.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 1 is closed out; Sprint 2 is
    planned and not started.

    Ground yourself first. Do not trust any status you have not checked this
    session. Two handoff documents in this repo have already outlived the facts
    they asserted, and one of them sent a session down a wrong path.

    1. Read `production/session-state/active.md` (gitignored, on disk). Its live
       section was rewritten at the close of the tenth session and is current.
    2. Read `production/sprints/sprint-2.md` — the plan you are executing.
    3. Read `production/sprint-status.yaml` — the live machine-readable rows.
       Sprint 1's are archived at `production/sprint-status-sprint-1.yaml`.
    4. Run `git log --oneline -5` and `git status --short`.
    5. Run the suite and confirm green before changing anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Keep the `-c`. Without it the runner stops at the first failure and a red
       run under-reports. If it fails to load with `Could not find type
       "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
       then retry. Expect 178/178, 11/11 suites, exit 0.

    ## Where things stand

    **Sprint 1: closed out, QA verdict APPROVED WITH CONDITIONS.** 20 of 22 rows
    done, must-have 17 of 19, 5.84 estimate-days delivered against 5.75
    committed. No S1 or S2 bug open — BUG-0001 closed on developer playtest
    sign-off, so the Definition of Done's bar is met.

    DO NOT re-run `/retrospective` or `/sprint-plan new`. Both are done and
    committed (`98d681e`). DO NOT re-ask the six decisions from the older
    prompts — all settled.

    The two open Sprint 1 rows, CLR-005 and TUN-006, both close on one action:
    **CI-1**.

    **Sprint 2: planned, not started.** 20 rows, 6.26 days committed against 8
    available. Must Have alone is 4.88, below Sprint 1's proven delivery.

      - CI-1                  carryover, 0.35 d, HUMAN REQUIRED
      - GA-002..GA-007        gravity-authority tail, 2.39 d, Must Have
      - LS-001..LS-006        level-state epic, 2.14 d, Must Have
      - PP-001 -> LV-005 -> LV-006   Should Have, 0.93 d, a strict chain
      - BUG-0002, PROC-1, DEBT-1     Nice to Have, 0.45 d

    The GA and LS tracks are independent of each other and can run side by side.

    ## Pick one of three routes

    ### Route A — CI-1. The highest-value thing, and it needs the developer.

    This is the only work blocking `/gate-check production`, and it is the one
    task an agent cannot finish alone.

    READ THIS BEFORE ATTEMPTING IT: the workflow fires on push to `development`
    or `main`, or on a pull request TARGETING them. **A scratch branch pushed on
    its own will NOT trigger it.** There is no `gh` CLI on this machine, so
    opening a PR is a web-UI action by the developer. This repository has no
    `main` branch at all — not local, not remote; `origin/HEAD` points at
    `development`. The trigger was widened to `development` on 2026-08-25 in
    `d77337c`; before that the job had never fired once.

    Five violations, one at a time, each confirmed red, then reverted:

      - `set_collision_mask_value()` in `player.gd` -> the ADR-0004 D4.6 step
        fails with a readable message, and the GdUnit4 step still runs or is
        correctly short-circuited                                      (CLR-005)
      - a `res://src/resources/tuning/prop_tuning.tres` literal in a gameplay
        script -> V6 fails                                             (TUN-006)
      - `Tuning.PROP.prop_gravity_scale = 1.5` -> V7 fails             (TUN-006)
      - `Tuning.PROP.duplicate()` -> V7 fails                          (TUN-006)
      - a `src/scripts/tuning/gravity_tuning.gd` file -> V8 fails      (TUN-006)

    CI uses `MikeSchulze/gdUnit4-action@v1`, not the local command, and still
    needs its own continue-past-first-failure fix. Confirm the run surfaces every
    planted violation, not only the first. Record the evidence: which violation,
    which check fired, the run URL, and the confirmation that the revert went
    green.

    ### Route B — `/qa-plan sprint`, then implementation.

    Sprint 2 has no QA plan. The full prompt is already written at
    `production/sprints/qa-plan-sprint-2-prompt.md` — use it rather than
    improvising. Sprint 1's DoD depended on a QA plan that was still a
    Nice-to-Have on day one and had to be promoted mid-sprint; running this
    before implementation is how that does not happen twice.

    ### Route C — start implementing.

    `/story-readiness` on GA-002, then `/dev-story`. GA-002's unsatisfiable
    settle assertion was fixed in `41ea6fd` with a 2.5-degree snap threshold, so
    it should come back READY — confirm rather than assume. LS-001 is the other
    valid starting point and is independent of the GA track.

    **Do NOT run `/gate-check production` until CI-1 is done.** A phase gate
    resting on two CI guards nobody has seen execute is the same class of gap
    Sprint 1 spent effort closing.

    ## Two stale claims corrected on 2026-08-25 — do not reintroduce them

    1. **"No epic covers physics props" is WRONG.** The `physics-props` epic
       exists: created 2026-08-24 in `c53c421`, decomposed into six stories in
       `4c5572c`. `story-001-prop-body-rigid-body-and-registry.md` delivers
       `class_name PropBody`. LV-006 is schedulable and is scheduled.
    2. **LV-006 needs more than `PropBody`.** `PropBody._ready()` calls
       `GravityAuthority.register_prop()`, so PP-001 pulls gravity-authority
       stories 001 (done) and 007 with it. Order is GA-007 -> PP-001 -> LV-006.

    ## Working rules

    - Follow the collaboration protocol in `CLAUDE.md`. Ask before Write/Edit,
      show the changeset, do not commit unless told.
    - Review mode is `lean` (`production/review-mode.txt`).
    - **NEVER `git add -A`.** It swept an unrelated level edit into a docs commit
      on 2026-08-25 — SpikeHazard3 in `level_04.tscn` had drifted during a play
      session and was committed unreviewed, then reverted in `df0c332`. Stage
      named paths and read the diff. If Godot is open, expect scene files to
      drift.
    - **Never tick a blocking AC on inference.** Open the story file and read its
      Test Evidence status and Implementation Record. TUN-005 was recorded as
      "met" by two separate passes while carrying 15 unticked ACs and no
      Implementation Record.
    - **An empty `blocker` field is not proof of no gate.** TUN-006's was empty
      while its final AC was unmet. That cost two sessions.
    - When reality and an approved AC diverge, **annotate the AC**. Do not
      silently tick it and do not reword the requirement.
    - **Before relaying a subagent's severity that depends on project config,
      open the config file yourself.** `project.godot` has no
      `debug/gdscript/warnings/*` section, which invalidated four BLOCKING
      findings in Sprint 1. The findings were real; the severity was invented.
    - **Where a spec states a duration, tolerance or floor, compute the MARGIN**,
      not just whether it passes.
    - **TUN-005's V1 stands.** Re-pointing a `.tres` at the wrong script is a
      parse error at load, not a group-1 failure. Do NOT weaken V1 to a null
      check to make the negative path observable.
    - **Two OPEN 4.7.1 engine unknowns sit in Sprint 2's scope.** GA-006 carries
      ADR-0001 Verification 2 (does a default-space write reach every
      `RigidBody2D` in the same step?); LV-006 carries the headless `Area2D`
      extent read on a node never added to a tree. Verify each against the binary
      before building on it. GA-006 has a named fallback.
    - **The windowed Godot editor segfaults on this machine.** The route around
      it is the read-only headless probe at
      `production/qa/evidence/editor-facts-probe-2026-08-25.md`. It proves the
      data, not the rendering. Reuse it; do not re-derive it.
    - Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
      discovery, so one warning anywhere fails the whole suite.
    - Use the Write tool, not Bash heredocs, for any file with apostrophes or
      long prose. Heredocs have mangled two sessions' worth of writes.
    - **Nothing has been pushed.** Nothing from Sprint 1's close-out has left the
      machine. Re-derive the commit count; do not quote one from a document.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. Sprint 1 is closed out (APPROVED WITH
    CONDITIONS); Sprint 2 is planned and not started. Read
    `production/session-state/active.md` and `production/sprints/sprint-2.md`,
    re-derive git and test state (expect 178/178), then pick a route: CI-1 (the
    live-fire CI run — needs a PR against `development` or a direct push, the
    developer's call, and it blocks /gate-check), `/qa-plan sprint` (prompt ready
    at `production/sprints/qa-plan-sprint-2-prompt.md`), or `/story-readiness`
    GA-002 then `/dev-story`. Do not re-run /retrospective or /sprint-plan. Ask
    before writing.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| CI-1 — the live-fire CI run | **human** — needs a PR or a push | CLR-005 + TUN-006, and `/gate-check` |
| `/qa-plan sprint` | agent work, prompt ready | Sprint 2 implementation |
| GA-002…GA-007, LS-001…LS-006 | agent work | Foundation completion |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| BUG-0002 (S4) | Sprint 2, nice-to-have | nothing |
| 10 tech-debt items | backlog, no owners | nothing |
| `/create-control-manifest update` | owed | `oxygen-drain` story 006, Sprint 3 |
