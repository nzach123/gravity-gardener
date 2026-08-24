# Sprint 1 — Continuation Prompt

Paste the block below into a fresh Claude Code session to resume Sprint 1.
It is written to survive a clean checkout: it names sources rather than
restating state, so it does not go stale as tasks close.

Re-read `sprint-1-handoff-2026-08-23.md` alongside it for the detail.

---

## Copy from here

```text
Resume Sprint 1 on branch `vertical-slice`.

Ground yourself first — do not trust any status you have not checked this session:

1. Read `production/sprints/sprint-1-handoff-2026-08-23.md` for context and known traps.
2. Read `production/sprint-status.yaml` for live task status. This is the source
   of truth, not the handoff file and not the sprint plan.
3. Read `production/session-state/active.md` if it exists (gitignored — it may not).
4. Run `git log --oneline -5` and `git status --short`.

Then run the test suite and confirm it is green before changing anything:

  "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
    --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests

If it fails to load with `Could not find type "GdUnitTestCIRunner"`, the .godot
class cache is stale. Run `--import` first, then retry. This is a known trap.

Work the sprint in this order, stopping at the first one that is not already done:

  1. CLR-3 — close it. Code is complete; only its four manual editor checks
     remain, and I have to run those. Tell me exactly what to look at, wait for
     my result, then update the story file and the yaml.
  2. CLR-2 — BUG-0001, the dead kill-plane masks on levels 05 and 06.
     Mechanism is already confirmed: KillArea2D declares no mask so it defaults
     to 1 (WORLD) while the player is on layer 2, and 1 & 2 == 0. The fix needs
     a human playtest — do not sign it off from an agent playtest.
  3. CLR-5 — the CI grep for the D4.6 runtime-mutation ban. While you are in
     `.github/workflows/tests.yml`, also address the two CI problems recorded in
     the handoff: the stale-class-cache load failure, and the suite stopping at
     the first failing test.
  4. TUN-1 — the @export_range spike. This is the real schedule risk: it heads
     the TUN-1 → TUN-2 → LV-1 chain and the CLR work is not on the critical path.
     If the sprint is tight, prioritise this over finishing the CLR epic.

Working rules for this session:

- Follow the collaboration protocol in CLAUDE.md. Ask before Write/Edit, show me
  the changeset, and do not commit without being told.
- Use `/dev-story <path>` to implement and `/story-done <path>` to close. Do not
  mark a story Complete while its required test evidence is missing — say so and
  let me decide.
- Review mode is `lean`. Non-phase-gate director reviews are skipped, but
  `/code-review` is still owed on `collision_layers.gd` and
  `collision_layers_test.gd` before sprint close-out.
- If a story's spec contradicts the engine or an ADR, verify the mechanism
  directly (a headless probe, not recall), then fix the spec before it drives
  code. Tell me what you changed and why.
- Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
  discovery, so one warning anywhere fails the whole suite.

Start by reporting where the sprint actually stands and what you propose to do
first. Do not start implementing until I confirm.
```

## Copy to here

---

## Shorter variant

For when you just want to keep moving and already have context:

```text
Resume Sprint 1 on `vertical-slice`. Read
`production/sprints/sprint-1-handoff-2026-08-23.md` and
`production/sprint-status.yaml`, re-derive git and test state, then tell me
where we stand and what you propose next. Ask before writing anything.
```

## Sprint close-out sequence

Once all Must-Have tasks are done, run in this order:

1. `/code-review` — owed on `collision_layers.gd` and `collision_layers_test.gd`
2. `/qa-plan sprint` — the sprint DoD requires `production/qa/qa-plan-sprint-1.md`
3. `/smoke-check sprint`
4. `/team-qa sprint`
5. `/retrospective`
6. `/sprint-plan new`

Do not run `/gate-check` until `/team-qa` returns APPROVED or APPROVED WITH
CONDITIONS.
