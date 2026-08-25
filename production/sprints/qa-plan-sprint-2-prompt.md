# `/qa-plan sprint` — Continuation Prompt for Sprint 2

Written 2026-08-25 at Sprint 1 close-out. Paste the block below into a fresh
Claude Code session.

**Why this exists**: Sprint 2 is planned but has no QA plan. Sprint 1's own
Definition of Done depended on a QA plan that was still a Nice-to-Have on day
one — a Nice-to-Have the DoD depends on makes the DoD unsatisfiable by
definition, and it had to be promoted mid-sprint on 2026-08-24. Running this
before implementation starts is how that does not happen twice.

Delete this file once the plan is written.

---

## Copy from here

    Run `/qa-plan sprint` for Sprint 2 on branch `vertical-slice`.

    Ground yourself first. Do not trust any status you have not checked this
    session — two handoff documents in this repo have already outlived the facts
    they asserted.

    1. Read `production/sprints/sprint-2.md` — the sprint being planned for.
    2. Read `production/sprint-status.yaml` — the live machine-readable rows.
       Sprint 1's are archived at `production/sprint-status-sprint-1.yaml`.
    3. Read `production/qa/qa-plan-sprint-1.md` — the format to follow, and the
       open items it still carries.
    4. Read `production/retrospectives/retro-sprint-1-2026-08-25.md` — five
       action items, two of which are QA's to enforce.
    5. Run `git log --oneline -5` and `git status --short`.
    6. Run the suite and confirm green before writing anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Keep the `-c`. Without it the runner stops at the first failure and a red
       run under-reports. If it fails to load with `Could not find type
       "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
       then retry. Expect 178/178, 11/11 suites, exit 0.

    ## What Sprint 2 contains

    20 rows, 6.26 days committed against 8 available. Two independent
    implementation tracks plus one human-gated carryover.

    - **CI-1** — carryover. One live-fire CI run closing CLR-005 and TUN-006.
      **Needs a human**; see the section below.
    - **GA-002…GA-007** — the gravity-authority tail, 2.39 d. Must Have.
    - **LS-001…LS-006** — the level-state epic, 2.14 d. Must Have.
      GA and LS are independent of each other and can run side by side.
    - **PP-001 → LV-005 → LV-006** — Should Have, 0.93 d. A strict chain.
    - **BUG-0002, PROC-1, DEBT-1** — Nice to Have, 0.45 d.

    ## What the plan must cover

    Classify every row by story type and assign evidence per
    `.claude/docs/coding-standards.md`'s table — Logic and Integration are
    BLOCKING gates, Visual/Feel and UI are ADVISORY, Config/Data needs a smoke
    check. Then, specifically:

    1. **GA-006 carries an OPEN engine verification.** ADR-0001 Verification 2 —
       whether a default-space gravity write in `_physics_process` reaches every
       `RigidBody2D` in the same step. This is unverified against 4.7.1. The plan
       must name how it gets discharged and what evidence counts, because a named
       fallback exists (a dirty flag consumed by the authority's
       `_physics_process`, costing one frame of stale space gravity at load) and
       choosing it is a real decision, not a workaround.
    2. **LV-006 carries a second 4.7.1 unknown.** Reading an `Area2D` extent
       headlessly, on a node instantiated but never added to a tree, is not
       covered by ADR-0003 E1–E3. Verify before quoting an AC that depends on it.
    3. **LS-003, the frame priority contract, is a 1-hour story with an ordering
       assertion as its whole point.** Order-dependent tests are exactly the ones
       that pass for the wrong reason. Say what a real failure looks like.
    4. **PP-001 is pulled out of a deferred epic.** Only story 001 of
       `physics-props` is in scope — `art-bible.md` §1.3 defers the epic's content
       to Vertical-Slice tier. Do not write test cases for stories 002–006.
    5. **CI-1 needs an evidence artifact**, not a checkbox. Name the file and what
       it must contain: which violation, which check fired, the run URL, and the
       confirmation that the revert went green.

    ## Two retrospective action items that are QA's to enforce

    Both are new clauses in Sprint 2's Definition of Done. The plan should say
    how each is checked, not merely restate it.

    - **A CI guard does not close its story until one live-fire run is recorded.**
      "Configured" is not "observed". A workflow in this repo triggered on a
      `main` branch that does not exist and had never fired once; nobody noticed,
      because nobody distinguished the two.
    - **Actual effort is recorded per story at `/story-done`.** Sprint 1's
      estimation accuracy came back NOT MEASURABLE — no story file, sprint row or
      commit records effort spent anywhere.

    ## Standing rules that shape test design

    - **Never tick a blocking AC on inference.** Open the story file and read its
      Test Evidence status and Implementation Record. TUN-005 was recorded as
      "met" by two separate passes while carrying 15 unticked ACs, an evidence
      status of "[ ] Not yet created", and no Implementation Record. Running the
      checks took two minutes and changed the outcome.
    - **Where a spec states a duration, tolerance or floor, compute the MARGIN**,
      not just whether it passes. Two zero-margin thresholds were caught in
      Sprint 1: `MIN_TILEMAP_LAYERS = 9` against a real count of 9, and a settle
      epsilon landing on exactly 100.0 ms against a 100 ms requirement.
    - **Before relaying a subagent's severity that depends on project config,
      open the config file yourself.** Four BLOCKING findings in Sprint 1 were
      premised on GDScript warnings that `project.godot` does not enable.
    - **When reality and an approved AC diverge, annotate the AC.** Do not
      silently tick it and do not reword the requirement.
    - **TUN-005's V1 stands.** Re-pointing a `.tres` at the wrong script is a
      parse error at load, not a group-1 failure. V1 guards GH#73615, where a
      preload resolves non-null yet wrong-type. Do NOT weaken V1 to a null check
      to make the negative path observable.
    - **The windowed Godot editor segfaults on this machine.** The route around
      it is the read-only headless probe recorded at
      `production/qa/evidence/editor-facts-probe-2026-08-25.md`. It proves the
      data, not the rendering, and says so. Reuse it; do not re-derive it. Never
      quote an "open the editor" acceptance criterion without a substitution plan.
    - **gdUnit4 treats GDScript warnings as errors at discovery** — one warning
      anywhere fails the whole suite. Static typing everywhere.
    - **`-a "res://path/test.gd:test_name"` is NOT a supported selector.** It
      exits 0 having run nothing, which looks exactly like a pass.

    ## The CI-1 mechanics, so they are not rediscovered

    The workflow fires on push to `development` or `main`, or on a pull request
    TARGETING them. **A scratch branch pushed on its own will NOT trigger it.**
    There is no `gh` CLI on this machine, so opening a PR is a web-UI action by
    the developer. This repository has no `main` branch — not local, not remote;
    `origin/HEAD` points at `development`. The trigger was widened to
    `development` on 2026-08-25 in `d77337c`; before that the job had never run.

    Five violations, one at a time, each confirmed red, then reverted:

      - `set_collision_mask_value()` in `player.gd` → the ADR-0004 D4.6 step
        fails with a readable message, and the GdUnit4 step still runs or is
        correctly short-circuited (CLR-005)
      - a `res://src/resources/tuning/prop_tuning.tres` literal in a gameplay
        script → V6 fails (TUN-006)
      - `Tuning.PROP.prop_gravity_scale = 1.5` → V7 fails (TUN-006)
      - `Tuning.PROP.duplicate()` → V7 fails (TUN-006)
      - a `src/scripts/tuning/gravity_tuning.gd` file → V8 fails (TUN-006)

    Note that CI uses `MikeSchulze/gdUnit4-action@v1`, not the local command, and
    still needs its own continue-past-first-failure fix. Confirm the run surfaces
    every planted violation, not only the first.

    ## Working rules

    - Follow the collaboration protocol in `CLAUDE.md`. Ask before Write/Edit,
      show the changeset, do not commit unless told.
    - Review mode is `lean` (`production/review-mode.txt`).
    - **NEVER `git add -A`.** It swept an unrelated level edit into a docs commit
      on 2026-08-25 and had to be reverted in `df0c332`. Stage named paths and
      read the diff. If Godot is open, expect scene files to drift.
    - Use the Write tool, not Bash heredocs, for any file containing apostrophes
      or long prose. Heredocs have mangled two sessions' worth of writes.
    - Nothing has been pushed. `vertical-slice` is many commits ahead of
      `origin` — re-derive the count rather than quoting one.

## Copy to here

---

## Shorter variant

    Run `/qa-plan sprint` for Sprint 2 on `vertical-slice`. Read
    `production/sprints/sprint-2.md` and `production/qa/qa-plan-sprint-1.md`,
    re-derive git and test state (expect 178/178), then write the plan. Sprint 2
    is 20 rows / 6.26 d: CI-1 (human-gated), GA-002..007, LS-001..006, then
    PP-001 -> LV-005 -> LV-006. Two rows carry OPEN 4.7.1 engine unknowns —
    GA-006 (ADR-0001 Verification 2) and LV-006 (headless Area2D extent read);
    the plan must say how each is discharged. Two new DoD clauses are QA's to
    enforce: a CI guard needs one recorded live-fire run, and actual effort is
    recorded per story. Ask before writing.

## After the plan is written

1. `/story-readiness` on GA-002 — its unsatisfiable settle assertion was fixed in
   `41ea6fd` with a 2.5-degree snap threshold.
2. `/dev-story` on the first ready story.
3. **Do not run `/gate-check production` until CI-1 is done.** A phase gate
   resting on two CI guards nobody has seen execute is the same class of gap
   Sprint 1 spent effort closing.
