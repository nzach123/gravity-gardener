# Sprint 1 — Continuation Prompt (2026-08-25)

Paste the block below into a fresh Claude Code session to resume Sprint 1.

Supersedes `sprint-1-continue-prompt-2026-08-24.md`. That file is stale in one
important way: it states every remaining Must-Have row is blocked on a human-only
check. That was wrong for LV-001..LV-004, whose blockers were empty and whose
work was already landed and green.

State at the time of writing: branch `vertical-slice`, HEAD `c4f1b4e`, clean
tree apart from this file. Suite green at 178 cases. Sprint 1 ends 2026-08-31.

---

## Copy from here

```text
Resume Sprint 1 on branch `vertical-slice`.

Ground yourself first. Do not trust any status you have not checked this session.

1. Read `production/sprint-status.yaml`. It is the source of truth for status —
   not the sprint plan, not any handoff file.
2. Read `production/session-state/active.md` (gitignored). Its live sections were
   rewritten on 2026-08-25 and its newest Session Extract explains the editor
   route.
3. Read `production/qa/evidence/editor-facts-probe-2026-08-25.md` BEFORE you plan
   any editor work. It records that the windowed editor segfaults, that the
   godot-ai MCP plugin disables itself under a headless editor
   (`addons/godot_ai/plugin.gd:211`), and that a read-only headless probe script
   is the working route. The script is in that document. Reuse it. Do not
   re-derive this.
4. Run `git log --oneline -5` and `git status --short`.
5. Run the suite and confirm green before changing anything:

   "/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
     --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
     --ignoreHeadlessMode -a res://tests -c

   Keep the `-c`. Without it the runner stops at the first failure and a red run
   under-reports. If it fails to load with `Could not find type
   "GdUnitTestCIRunner"`, the `.godot` class cache is stale — run `--import`,
   then retry.

Sprint 1 has no implementation work left. It is gated on SIX DECISIONS and TWO
PLAYTESTS. Nothing else moves until those clear.

Work in this order.

## STEP 1 — Put all six decisions to me in ONE round. Do not trickle them.

Each decision carries your recommendation. Do not start work on any of them
until I answer.

D1. STATUS FLIPS. Five rows have complete evidence and nothing outstanding:
    TUN-002, LV-001, LV-002, LV-003, LV-004. Flip them to `done` in the yaml and
    their story headers to `Complete`? The yaml header says to use `/story-done`
    rather than editing by hand — say which route you propose.

D2. TUN-003. Also complete, but AC-4, AC-5 and AC-6 name an editor METHOD, not
    only a fact: open the inspector, drag a slider, view the checkbox. They were
    closed by a probe reading the same data one layer down. Each AC carries an
    inline METHOD SUBSTITUTED note and the ACs were NOT reworded. Close it on
    substituted evidence, or hold it at `review` until a machine with a working
    editor exists?

D3. THE CI TRIGGER. This blocks CLR-005 AC-5 and TUN-006's last AC — one
    decision, two rows. `.github/workflows/tests.yml` triggers on `main`; this
    repo's main branch is `development`, so no run has ever fired on this
    sprint's work. Widening the trigger was ruled out of scope earlier. That call
    is OPEN, not closed. Widen it, or accept both rows without a live CI run and
    record the gap?

D4. THE TWO RESTORED FILES. `sprint-1-continue-prompt.md` and
    `sprint-1-handoff-2026-08-23.md` were deleted in the working tree, I
    confirmed the deletion was intentional, and both reappeared on disk
    mid-session restored from git. No session command touches those paths.
    Delete again and COMMIT the deletion so it stops reverting, or leave them?
    Check first whether a hook restores them — look in `.claude/settings.json`
    and `.claude/hooks/`.

D5. THE `MovingPlatfornm` TYPO. The root node of
    `src/scenes/moving_platform.tscn` is misspelled. It breaks the
    scene-name-matches-root-node rule in `.claude/docs/technical-preferences.md`.
    Renaming a root node changes every referencing node path. File it as a bug
    row, put it in Sprint 2, or fix it now?

D6. GA-002. Not a Sprint-1 row — the GA epic is cut to Sprint 2 — but the defect
    is real and blocks `/dev-story` on it whenever it starts. `/story-readiness`
    returned NEEDS WORK on 2026-08-24:

      The story mandates an exponential ease —
      `lerp_angle(..., clampf(32.0 * delta, 0, 1))` — then asserts in QA AC-1
      that `gravity.is_equal_approx(target_gravity)` holds within 100 ms. At 60
      physics FPS the retained error per step is 1 - 32/60 = 0.4667, so 90°
      decays to 0.93° at 100 ms (6 steps) and needs about 16 steps (~267 ms) to
      satisfy `is_equal_approx`. A CORRECT implementation fails AC-1 as written.
      The story's own Performance note ("roughly 6-7 frames") matches the visual
      settle, not the `is_equal_approx` settle. The story carries two different
      meanings of "settled".

    Recommended fix: add a settle threshold. Snap `gravity` to `target_gravity`
    once `angle_difference()` falls under a stated epsilon, about 0.5°. That
    satisfies GDD AC5's 100 ms, gives AC-7's "bit-identical when idle" an exact
    target, and holds the ease loop to the 6-7 frames the story budgets.
    Editing `design/gdd/gravity.md` AC5 is a SEPARATE decision — that document is
    approved. Put it to me before touching it. Do not run `/dev-story` on GA-002
    until this is resolved.

## STEP 2 — While I answer, run the one piece of agent work that needs no decision.

`/code-review` on `src/scripts/collision_layers.gd` and
`tests/unit/physics/collision_layers_test.gd`. It is owed before sprint close-out
and depends on nothing above. Report findings; do not apply fixes without asking.

## STEP 3 — Hand me the two playtests as ONE checklist.

These are the only genuinely human items left. Give me one list I can work
through in a single sitting, in the order that needs the fewest restarts.

  - CLR-002 AC-5 — fall out of bounds on level 05 and on level 06. Confirm the
    level restarts cleanly with nothing stranded, and that neither level has an
    IN-BOUNDS spot where the kill plane fires. BUG-0001 is S2 and stays Open
    until this passes, and the DoD forbids closing the sprint with an open S2.
    So this is the true critical path. Do NOT sign it off from an agent
    playtest — agent playtests misjudge pacing and feel.
  - CLR-003 AC-5 items 3-4 — in a running level, the moving platform still
    animates along its configured path unchanged, and the player still moves,
    jumps and flips gravity. Items 1-2 are already closed by the probe.

Wait for my results. Then update each story file and the yaml.

## STEP 4 — Close out, in this order, and not before.

  1. `/code-review`  (from step 2, if not already done)
  2. `/smoke-check sprint`
  3. `/team-qa sprint`
  4. `/retrospective`
  5. `/sprint-plan new`

`/qa-plan sprint` is already done (`production/qa/qa-plan-sprint-1.md`) — re-run
only if scope changed. Do NOT run `/gate-check` until `/team-qa` returns APPROVED
or APPROVED WITH CONDITIONS.

## Working rules for this session

- Follow the collaboration protocol in CLAUDE.md. Ask before Write/Edit, show me
  the changeset, do not commit unless I say so.
- Review mode is `lean` (`production/review-mode.txt`). Non-phase-gate director
  reviews are skipped.
- Never mark a story Complete while its required test evidence is missing. Say so
  and let me decide.
- An empty `blocker` field on a `review` row is NOT proof of a human gate. Open
  the story file. That assumption cost a session.
- When reality and an approved AC diverge, annotate the AC with the divergence.
  Do not silently tick it, and do not quietly reword the requirement to match
  what was done. Two examples are in the repo: TUN-003 AC-4/5/6
  (METHOD SUBSTITUTED) and LV-001 AC-3 (CLAUSE SUPERSEDED).
- If a spec contradicts the engine or an ADR, verify the mechanism directly with
  a headless probe rather than from recall, then fix the spec before it drives
  code. Tell me what you changed and why.
- Static typing everywhere. gdUnit4 treats GDScript warnings as errors at
  discovery, so one warning anywhere fails the whole suite.
- `docs/tech-debt-register.md` holds 3 open items from GA-001. Do not lose them.
- TUN-005's V1 note stands. Re-pointing a `.tres` at the wrong script is a parse
  error at load, not a group-1 failure, so V1 was never demonstrated red. Do not
  weaken V1 to a null check to make it observable.

Start with STEP 1. Give me the six decisions in one round, each with your
recommendation, and nothing else until I answer.
```

## Copy to here

---

## Shorter variant

For when you already have context and just want to keep moving:

```text
Resume Sprint 1 on `vertical-slice`. Read `production/sprint-status.yaml`,
`production/session-state/active.md` and
`production/sprints/sprint-1-continue-prompt-2026-08-25.md`, re-derive git and
test state, then put the six open decisions to me in ONE round with your
recommendation on each. No implementation work remains in this sprint. Ask
before writing.
```

## Quick map of what is open

| # | Item | Type | Blocks |
|---|---|---|---|
| D1 | Flip 5 complete rows to `done` | decision | burndown accuracy |
| D2 | TUN-003 on substituted evidence | decision | 1 row |
| D3 | CI trigger | decision | CLR-005 + TUN-006 |
| D4 | Two restored sprint files | decision | tree hygiene |
| D5 | `MovingPlatfornm` typo | decision | nothing; needs a home |
| D6 | GA-002 settle threshold | decision | Sprint 2 `/dev-story` |
| — | `/code-review` on collision_layers | agent work | close-out |
| — | CLR-002 AC-5 playtest | **human** | **the sprint** (open S2) |
| — | CLR-003 AC-5 items 3-4 | **human** | 1 row |
