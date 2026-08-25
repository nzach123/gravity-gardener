# Sprint 1 — Continuation Prompt (2026-08-24)

Paste the block below into a fresh Claude Code session to resume Sprint 1.

This supersedes `sprint-1-continue-prompt.md`, which is kept for reference but
is stale: it orders CLR-3, CLR-2, CLR-5, TUN-1, and TUN-1 closed on 2026-08-24.

State at the time of writing: branch `vertical-slice`, clean tree, HEAD
`783953b`. Sprint 1 ends 2026-08-31.

---

## Copy from here

```text
Resume Sprint 1 on branch `vertical-slice`.

Ground yourself first. Do not trust any status you have not checked this session.

1. Read `production/sprint-status.yaml`. It is the source of truth for task
   status — not the sprint plan, not any handoff file.
2. Read `production/sprints/sprint-1-handoff-2026-08-23.md` for known traps.
3. Read `production/session-state/active.md` if it exists (gitignored).
4. Run `git log --oneline -5` and `git status --short`.
5. Run the suite and confirm green before changing anything:

   "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
     --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
     --ignoreHeadlessMode -a res://tests -c

   Keep the `-c`. Without it the runner stops at the first failure and a red run
   under-reports. If it fails to load with `Could not find type
   "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
   then retry.

Sprint 1 ends 2026-08-31. Every remaining Must-Have row is `review` status and
every one is blocked on a check only I can run. That is the critical path — not
more code.

Work in this order.

1. Give me ONE consolidated manual-check list, grouped by what I open once, for
   these rows: CLR-002, CLR-003, CLR-005, TUN-002, TUN-003, TUN-005, TUN-006,
   LV-001, LV-002, LV-003, LV-004. Read each story file for what it still owes;
   do not restate the yaml blocker text back at me. Known specifics:
     - CLR-002 AC-5 — human playtest of the out-of-bounds fall on levels 05
       and 06. Do not sign this off from an agent playtest.
     - CLR-003 AC-5 — editor smoke on player.tscn and moving_platform.tscn.
       The windowed editor segfaults on this machine. Propose a route that
       works instead of telling me to open it.
     - CLR-005 AC-5 — needs a real CI run. The workflow triggers on `main`;
       this repo's main branch is `development`, so no run has fired on this
       sprint's work. Widening the trigger was ruled out of scope. That call is
       still open — put it to me, do not assume it.
     - TUN-002 and TUN-003 — inspector checks, see
       `production/qa/smoke-2026-08-24.md`. TUN-003 asks me to drag
       `prop_gravity_scale` and REVERT BEFORE SAVING; the committed value must
       stay 1.0.
   Wait for my results. Then update each story file and the yaml.

2. TUN-005's V1 note stands. Re-pointing a .tres at the wrong script is a parse
   error at load, not a group-1 failure, so V1 was never demonstrated red. Do
   not weaken V1 to a null check to make it observable.

3. The GravityAuthority epic. GA-001..GA-007 are listed in the Sprint-2 cut
   block, but GA-001 is Complete and committed (783953b) and I am working
   ahead. Before touching GA, reconcile the yaml — completed work must not sit
   in a cut block.

   GA-002 is NOT ready. `/story-readiness` returned NEEDS WORK on 2026-08-24 on
   one specific point, and it is a real defect, not a wording problem:

     The story mandates an exponential ease —
     `lerp_angle(..., clampf(32.0 * delta, 0, 1))` — then asserts in QA AC-1
     that `gravity.is_equal_approx(target_gravity)` holds within 100 ms. At 60
     physics FPS the retained error per step is 1 - 32/60 = 0.4667, so 90°
     decays to 0.93° at 100 ms (6 steps) and needs about 16 steps (~267 ms) to
     satisfy `is_equal_approx`. A correct implementation fails AC-1 as written.
     The story's own Performance note ("roughly 6-7 frames") matches the visual
     settle, not the `is_equal_approx` settle. The story carries two different
     meanings of "settled".

   Recommended fix: add a settle threshold. Snap `gravity` to `target_gravity`
   once `angle_difference()` falls under a stated epsilon, about 0.5°. That
   satisfies GDD AC5's 100 ms, gives AC-7's "bit-identical when idle" an exact
   target, and holds the ease loop to the 6-7 frames the story budgets.
   Editing `design/gdd/gravity.md` AC5 is a separate decision — that document is
   approved. Put it to me before touching it.

   Do not run `/dev-story` on GA-002 until this is resolved.

Working rules for this session:

- Follow the collaboration protocol in CLAUDE.md. Ask before Write/Edit, show
  me the changeset, do not commit unless I say so.
- Review mode is `lean` (`production/review-mode.txt`). Non-phase-gate director
  reviews are skipped.
- `/code-review` is still owed on `collision_layers.gd` and
  `collision_layers_test.gd` before sprint close-out.
- Never mark a story Complete while its required test evidence is missing. Say
  so and let me decide.
- If a spec contradicts the engine or an ADR, verify the mechanism directly with
  a headless probe rather than from recall, then fix the spec before it drives
  code. Tell me what you changed and why.
- Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
  discovery, so one warning anywhere fails the whole suite.
- `docs/tech-debt-register.md` holds 3 open items from GA-001. Do not lose them.

Start by reporting where the sprint actually stands and what you propose to do
first. Do not implement until I confirm.
```

## Copy to here

---

## Shorter variant

For when you already have context and just want to keep moving:

```text
Resume Sprint 1 on `vertical-slice`. Read `production/sprint-status.yaml` and
`production/sprints/sprint-1-continue-prompt-2026-08-24.md`, re-derive git and
test state, then tell me where we stand and what you propose next. The sprint is
gated on manual checks only I can run — lead with that list. Ask before writing.
```

## Sprint close-out sequence

Once all Must-Have rows are done, run in this order:

1. `/code-review` — owed on `collision_layers.gd` and `collision_layers_test.gd`
2. `/qa-plan sprint` — already done 2026-08-24 (`production/qa/qa-plan-sprint-1.md`);
   re-run only if scope changed
3. `/smoke-check sprint`
4. `/team-qa sprint`
5. `/retrospective`
6. `/sprint-plan new`

Do not run `/gate-check` until `/team-qa` returns APPROVED or APPROVED WITH
CONDITIONS.
