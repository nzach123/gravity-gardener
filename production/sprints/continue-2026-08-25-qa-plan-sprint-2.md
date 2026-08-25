# Continuation Prompt — After the Production Gate (2026-08-25, twelfth session close)

Paste the block below into a fresh Claude Code session.

**Supersedes `continue-2026-08-25-gate-check.md`**, which is fully consumed. Its
one job was `/gate-check production`. That gate ran on 2026-08-25 and its verdict
is on disk. Delete that file when you commit this one.

One thing changed on 2026-08-25 that every earlier handoff document gets wrong:

**`/gate-check production` has been run.** Verdict **CONCERNS**, recorded at
`production/gate-checks/gate-check-2026-08-25-production.md`. Do not run it again
to "check". Read the report.

---

## Copy from here

    Resume work on branch `vertical-slice`. Sprint 1 is closed. Sprint 2 is
    planned and starts 2026-09-01. The Production gate has been run.

    Ground yourself first. Do not trust any status you have not checked this
    session. Four handoff documents in this repo have now outlived the facts they
    asserted, and one of them sent a session down a wrong path.

    1. Read `production/gate-checks/gate-check-2026-08-25-production.md`. This is
       the newest and most reliable document in the repo. Everything in it was
       re-derived on 2026-08-25, not carried from a handoff.
    2. Read `production/sprints/sprint-2.md` — the plan you are executing.
    3. Read `production/sprint-status.yaml` — the live machine-readable rows.
       Sprint 1's are archived at `production/sprint-status-sprint-1.yaml`.
    4. Read `production/session-state/active.md`. Its Working Rules and Where
       State Lives sections are current. **Its "Next Steps" list is now stale** —
       step 1 was the gate, and the gate is done.
    5. Run `git log --oneline -5` and `git status --short`.
    6. Run the suite and confirm green before changing anything:

       "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -c

       Keep the `-c`. Without it the runner stops at the first failure and a red
       run under-reports. If it fails to load with `Could not find type
       "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
       then retry. Expect 178/178, 11/11 suites, exit 0.

    ## Where things stand

    **Stage: still Pre-Production.** `production/stage.txt` reads
    `Pre-Production` and was deliberately NOT advanced. The gate returned
    CONCERNS, not PASS, and the skill advances the stage only on PASS. Advancing
    is the developer's decision and has not been made.

    **The gate verdict is CONCERNS, with one explicit override.** Read the
    "Override of the automatic-FAIL rule" section of the gate report before you
    act on anything else in it. Summary: vertical-slice validation item 2 ("the
    game communicates what to do within the first 2 minutes") is NO on the slice
    report's own words — invisible gravity zones, no interact prompts, no win
    feedback. The gate's rule turns any NO into an automatic FAIL. The developer
    judged the core mechanic sound and classed legibility as Production scope,
    matching the slice's own PROCEED. **Four entry conditions were attached.** Do
    not treat item 2 as though it passed.

    **Sprint 1: closed 2026-08-25, QA verdict APPROVED WITH CONDITIONS.** 20 of
    22 rows done, must-have 17 of 19. Suite 178/178. No S1 or S2 bug open.
    QA sign-off condition 1 (the live-fire CI run) is DISCHARGED.

    **CI-1 IS DONE. CLR-005 and TUN-006 are closed.** Do not re-run it. Evidence:
    `production/qa/evidence/ci-1-live-fire-2026-08-25.md`.

    **Sprint 2: planned, not started.** 20 rows, 6.26 days against 8 available.
    Must Have alone is 4.88, below Sprint 1's proven 5.84.

      - GA-002..GA-007        gravity-authority tail, 2.39 d, Must Have
      - LS-001..LS-006        level-state epic, 2.14 d, Must Have
      - PP-001 -> LV-005 -> LV-006   Should Have, 0.93 d, a strict chain
      - BUG-0002, PROC-1, DEBT-1     Nice to Have, 0.45 d

    The GA and LS tracks are independent of each other and can run side by side.

    DO NOT re-run `/gate-check production`, `/retrospective`, `/sprint-plan new`,
    or CI-1. All four are done and committed.

    ## Do these, in this order

    ### 1. `/qa-plan sprint` — the reason this session exists

    Sprint 2 has no QA plan. The full prompt is already written at
    `production/sprints/qa-plan-sprint-2-prompt.md` — use it rather than
    improvising. Sprint 1's Definition of Done depended on a QA plan that was
    still a Nice-to-Have on day one and had to be promoted mid-sprint. Running
    this before implementation is how that does not happen twice.

    ### 2. Strike the four stale rows from `architecture.md`

    The gate found the Open Questions table at `architecture.md:851` unreliable
    in both directions: it lists resolved questions as open, while the one real
    gap it carries reads as no more urgent than the stale rows around it.

    **Stale — strike**: QQ-01 (closed in the body at `architecture.md:165-166`),
    QQ-02 (resolved by ADR-0001 part 7), QQ-04 (resolved by ADR-0010),
    QQ-06 (asserts `game-concept.md` does not exist — it does, 443 lines).

    **Genuinely open — keep**: QQ-03, QQ-05. QQ-07 is correctly parked by design.

    Ask before editing. This is a small self-contained changeset and the
    developer wants to see it before it is written.

    ### 3. On 2026-09-01, start implementing

    `/story-readiness` on GA-002, then `/dev-story`. GA-002's unsatisfiable
    settle assertion was fixed in `41ea6fd` with a 2.5-degree snap threshold, so
    it should come back READY — confirm rather than assume. LS-001 is the other
    valid starting point and is independent of the GA track.

    ## The gate's ranked concerns — do not re-derive these

    All eleven are in the gate report with evidence. The top five:

    1. **QQ-03 — the 8 built levels do not implement the current design, and no
       epic owns migrating them.** Confirmed three independent ways, including a
       direct grep: no `level_01..08.tscn` declares `default_gravity` or
       `oxygen_capacity`. `architecture.md` names a "Level migration epic" that
       does not exist. Pillars 2 and 3 are not true of the shipped game. Does not
       block Sprint 2 (Foundation only, authors no levels); compounds if new
       level content is authored first.
    2. **The stale QQ table.** Item 2 above.
    3. **CI guards do not reach the trunk.** See the open question below.
    4. **The four slice legibility gaps**, carried as override entry conditions.
    5. **QQ-05 — two shipped traversal mechanics have no design authority.**
       `src/scripts/moving_platform.gd` and
       `src/scripts/components/player_wall_jump_component.gd` both ship with zero
       TR-registry entries. Moving platforms DO have collision-layer coverage
       under ADR-0004 — the accurate claim is "no behavioural ADR", not "no ADR".

    ## One open question for the developer

    **Merge `vertical-slice` into `development`?** The branch is **78** commits
    ahead and unmerged. `.github/` does not exist on `development` at all, so the
    four ADR guards — which are proven, all four fired in one run against five
    planted violations — do not guard the trunk and will not until the workflow
    reaches that branch. The four CI runs happened only because GitHub runs a
    same-repo pull request's workflow from the HEAD branch. This is the
    developer's call, not the agent's. There is no `gh` CLI on this machine, so
    opening a PR is a browser action.

    ## Stale claims corrected — do not reintroduce them

    1. **"No epic covers physics props" is WRONG.** The `physics-props` epic
       exists: created 2026-08-24 in `c53c421`, decomposed into six stories in
       `4c5572c`. LV-006 is schedulable and is scheduled.
    2. **LV-006 needs more than `PropBody`.** `PropBody._ready()` calls
       `GravityAuthority.register_prop()`, so PP-001 pulls gravity-authority
       stories 001 (done) and 007 with it. Order is GA-007 -> PP-001 -> LV-006.
    3. **"77 commits ahead" is WRONG — it is 78.** `214190e` landed after that
       count was written. Re-derive with
       `git rev-list --left-right --count development...vertical-slice`.
    4. **"The gate is blocked on CI-1" is WRONG.** The gate has been run.

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
      while its final AC was unmet. That cost two sessions. Equally, a `Blocked`
      status header is not proof of a live gate — LV-005 and LV-006 both carry
      stale `Blocked` headers while being scheduled inside Sprint 2.
    - When reality and an approved AC diverge, **annotate the AC**. Do not
      silently tick it and do not reword the requirement.
    - **Before relaying a subagent's severity that depends on project config,
      open the config file yourself.** `project.godot` has no
      `debug/gdscript/warnings/*` section, which invalidated four BLOCKING
      findings in Sprint 1. The findings were real; the severity was invented.
      The 2026-08-25 gate run caught a similar overstatement — a director
      reported moving platforms as having no ADR when ADR-0004 covers them.
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
      unidentified cause.** Both are gitignored. The tracked record is the source
      of truth: `production/gate-checks/`, `production/sprints/`,
      `production/qa/`, `production/retrospectives/`, `production/epics/`,
      `docs/tech-debt-register.md`, and the git log. Do not reconstruct lost
      history from inference.

## Copy to here

---

## Shorter variant

    Resume on `vertical-slice`. Sprint 1 is closed. **`/gate-check production`
    has been RUN** — verdict CONCERNS, at
    `production/gate-checks/gate-check-2026-08-25-production.md`. Read that first;
    it is the most reliable document in the repo and re-derives nothing from
    handoffs. Note its "Override of the automatic-FAIL rule" section — slice
    validation item 2 is NO and was overridden by developer decision with four
    entry conditions attached. `production/stage.txt` still reads
    `Pre-Production` and was deliberately not advanced. Sprint 2 is planned,
    starts 2026-09-01. Re-derive git and test state (expect 178/178), then run
    `/qa-plan sprint` using the prompt at
    `production/sprints/qa-plan-sprint-2-prompt.md`. Then propose striking the
    four stale QQ rows from `architecture.md` (QQ-01, 02, 04, 06 — keep QQ-03 and
    QQ-05). Do not re-run /gate-check, /retrospective, /sprint-plan, or CI-1.
    Ask before writing.

## Quick map of what is open

| Item | Type | Blocks |
|---|---|---|
| `/qa-plan sprint` | agent work, prompt ready | Sprint 2 implementation |
| Strike 4 stale QQ rows in `architecture.md` | agent work, needs approval | nothing; the table misleads until done |
| Advance `production/stage.txt` to `Production` | **human** — gate was CONCERNS, not PASS | nothing mechanical |
| Merge `vertical-slice` into `development` | **human** — browser PR, 78 commits | CI guards reaching the trunk |
| QQ-03 — level migration epic | unowned | Pillars 2 and 3 being true of the built game |
| GA-002…GA-007, LS-001…LS-006 | agent work, 2026-09-01 | Foundation completion |
| PP-001 → LV-005 → LV-006 | agent work, strict chain | LV-006 |
| The 4 override entry conditions | mixed | any Sprint 3 content work |
| `/create-control-manifest update` | owed | `oxygen-drain` story 006, Sprint 3 |
| `/review-all-gdds` + `/design-review` ×6 | never run, no owner | nothing formally; the gate's least-confident check |
| BUG-0002 (S4) | Sprint 2, nice-to-have | nothing |
| 12 tech-debt items | backlog, no owners | nothing |
