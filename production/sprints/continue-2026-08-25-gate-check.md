# Continuation Prompt — The Production Gate (2026-08-25, eleventh session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `continue-2026-08-25-sprint-2-start.md`**, which is fully consumed.
Its Route A was CI-1, and CI-1 is done. That file is deleted in the same commit
as this one.

Two things changed on 2026-08-25 that every earlier handoff document gets wrong:

1. **CI-1 is done.** `/gate-check production` is no longer blocked.
2. **`production/session-state/active.md` was deleted**, along with all of
   `production/session-logs/`, by something outside the session that noticed it.
   The cause was not identified. `active.md` has been reconstructed and says so
   in its own first section. The Session Extracts history is gone for good.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 1 is closed. Sprint 2 is
    planned and starts 2026-09-01.

    Ground yourself first. Do not trust any status you have not checked this
    session. Three handoff documents in this repo have already outlived the facts
    they asserted, and one of them sent a session down a wrong path.

    1. Read `production/session-state/active.md`. It was RECONSTRUCTED on
       2026-08-25 after the original was deleted by an unidentified cause. Its
       first section explains what was lost. Its live content is current.
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

    **Stage: Pre-Production.** The vertical slice passed with PROCEED. The next
    milestone is the Pre-Production to Production gate.

    **Sprint 1: closed 2026-08-25, QA verdict APPROVED WITH CONDITIONS.** 20 of
    22 rows done, must-have 17 of 19, 5.84 estimate-days against 5.75 committed.
    Suite 178/178. No S1 or S2 bug open.

    **CI-1 IS DONE. CLR-005 and TUN-006 are closed.** Four workflow runs on
    2026-08-25 from PR #1. Run #3 planted five violations and all four ADR guards
    fired in one run, each naming its clause. Run #4 reverted and went green.
    Evidence: `production/qa/evidence/ci-1-live-fire-2026-08-25.md`.
    Cleanup is complete — branch `ci-1-live-fire` was deleted local and remote at
    `4d16a26`, which closes PR #1 unmerged.

    DO NOT re-run `/retrospective`, `/sprint-plan new`, or CI-1. All three are
    done and committed. DO NOT re-ask the six decisions from the older prompts —
    all settled.

    **Sprint 2: planned, not started.** 20 rows, 6.26 days against 8 available.
    Must Have alone is 4.88, below Sprint 1's proven delivery.

      - GA-002..GA-007        gravity-authority tail, 2.39 d, Must Have
      - LS-001..LS-006        level-state epic, 2.14 d, Must Have
      - PP-001 -> LV-005 -> LV-006   Should Have, 0.93 d, a strict chain
      - BUG-0002, PROC-1, DEBT-1     Nice to Have, 0.45 d

    The GA and LS tracks are independent of each other and can run side by side.

    ## Do these, in this order

    ### 1. `/gate-check production` — the reason this session exists

    This is the verdict on whether the project enters Production. It was blocked
    only on CI-1, and CI-1 is done.

    **Declare this gap in the gate record rather than letting it pass silently:**
    `.github/` does not exist on `development`. The workflow lives only on
    feature branches. For a same-repo pull request GitHub runs the workflow from
    the HEAD branch, which is the only reason the four runs happened at all. The
    guards are proven. Their reach is not. They will never run on a push to
    `development` until the workflow reaches that branch.

    Two more non-blocking items from the same run are already in
    `docs/tech-debt-register.md` and should be named, not re-derived:
    the CI test step has no `-c` equivalent so a red suite may under-report
    (recorded as INFERRED, never reproduced — every CI run so far has been
    green), and `actions/checkout@v4` plus `actions/upload-artifact@v4` log a
    Node 20 deprecation warning.

    ### 2. `/qa-plan sprint`

    Sprint 2 has no QA plan. The full prompt is already written at
    `production/sprints/qa-plan-sprint-2-prompt.md` — use it rather than
    improvising. Sprint 1's DoD depended on a QA plan that was still a
    Nice-to-Have on day one and had to be promoted mid-sprint. Running this
    before implementation is how that does not happen twice.

    ### 3. On 2026-09-01, start implementing

    `/story-readiness` on GA-002, then `/dev-story`. GA-002's unsatisfiable
    settle assertion was fixed in `41ea6fd` with a 2.5-degree snap threshold, so
    it should come back READY — confirm rather than assume. LS-001 is the other
    valid starting point and is independent of the GA track.

    ## One open question for the developer

    **Merge `vertical-slice` into `development`?** The branch is 77 commits
    ahead and unmerged. This is what puts the CI guards on the trunk and closes
    the reach gap above. It is a separate decision from the gate and it is the
    developer's call, not the agent's. There is no `gh` CLI on this machine, so
    opening a PR is a browser action.

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
    - **`active.md` and `session-logs/` were deleted on 2026-08-25 by an
      unidentified cause.** Both are gitignored. If session history matters to
      you, the tracked record is the source of truth: `production/sprints/`,
      `production/qa/`, `production/retrospectives/`, `production/epics/`,
      `docs/tech-debt-register.md`, and the git log. Do not reconstruct lost
      history from inference.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. Sprint 1 is closed (APPROVED WITH CONDITIONS).
    CI-1 is DONE — CLR-005 and TUN-006 are closed, and `/gate-check production`
    is no longer blocked. Sprint 2 is planned and starts 2026-09-01. Read
    `production/session-state/active.md` (reconstructed 2026-08-25 after the
    original was deleted — it explains itself) and `production/sprints/sprint-2.md`,
    re-derive git and test state (expect 178/178), then run `/gate-check
    production`. Declare in the record that `.github/` is absent from
    `development`, so the proven guards do not yet run on the trunk. Then
    `/qa-plan sprint` using the prompt at
    `production/sprints/qa-plan-sprint-2-prompt.md`. Do not re-run /retrospective,
    /sprint-plan, or CI-1. Ask before writing.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/gate-check production` | agent work, UNBLOCKED | the Production transition |
| `/qa-plan sprint` | agent work, prompt ready | Sprint 2 implementation |
| Merge `vertical-slice` into `development` | **human** — browser PR, 77 commits | CI guards reaching the trunk |
| GA-002…GA-007, LS-001…LS-006 | agent work, 2026-09-01 | Foundation completion |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| BUG-0002 (S4) | Sprint 2, nice-to-have | nothing |
| 12 tech-debt items | backlog, no owners | nothing |
| `/create-control-manifest update` | owed | `oxygen-drain` story 006, Sprint 3 |
