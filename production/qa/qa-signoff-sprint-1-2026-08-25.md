# QA Sign-Off Report: Sprint 1

**Date**: 2026-08-25
**Build**: branch `vertical-slice`, `ae6de11`
**Stage**: Pre-Production
**Review mode**: lean
**Sprint window**: 2026-08-18 to 2026-08-31

---

## Test Coverage Summary

**20 of 22 rows done. Must-have: 17 of 19.** Five rows are sprint tasks
(story-creation runs, the architecture sweep, the QA plan), not stories.

| Story | Type | Auto test | Manual QA | Result |
|---|---|---|---|---|
| CLR-001 | Logic | PASS | — | PASS |
| CLR-002 | Integration | PASS | PASS — playtest | PASS |
| CLR-003 | Integration | PASS | PASS with notes | PASS WITH NOTES |
| CLR-004 | Logic | PASS | — | PASS |
| CLR-005 | Logic | PASS locally | — | **INCOMPLETE** — see condition 1 |
| TUN-001 | Integration | PASS | — | PASS |
| TUN-002 | Config/Data | n/a | PASS — smoke | PASS |
| TUN-003 | Config/Data | n/a | PASS — smoke | PASS WITH NOTES |
| TUN-004 | Logic | PASS | — | PASS |
| TUN-005 | Logic | PASS | PASS with notes | PASS WITH NOTES |
| TUN-006 | Logic | PASS locally | — | **INCOMPLETE** — see condition 1 |
| LV-001 | Logic | PASS | — | PASS |
| LV-002 | Logic | PASS | — | PASS |
| LV-003 | Logic | PASS | — | PASS |
| LV-004 | Logic | PASS | — | PASS |
| GA-001 | Logic | PASS | — | PASS |

**Automated suite**: 178 cases, 178 passing, 0 errors, 0 failures, 0 flaky,
0 skipped, 0 orphans. 11/11 suites, exit 0. Re-confirmed green after the TUN-005
negative-check mutations were reverted.

**Smoke check**: PASS — `production/qa/smoke-2026-08-25.md`. Zero missing test
evidence.

**Manual QA sessions required**: zero remaining. CLR-002's playtest was the
sprint's one required human session and it is complete.

---

## The PASS WITH NOTES rows

Each carries an annotation rather than a silent tick. In no case was a
requirement reworded to match what was done.

- **CLR-003** — AC-5's editor-console clause was verified by headless probe and a
  clean runtime load, not by opening the editor, which segfaults on this machine.
  Annotated METHOD SUBSTITUTED. Items 3 and 4 were confirmed directly in the
  playtest.
- **TUN-003** — AC-4/5/6 name an editor method (open the inspector, drag the
  slider, view the checkbox). Closed by a headless probe reading the same
  `@export_range` metadata one layer down. Annotated METHOD SUBSTITUTED.
- **TUN-005** — negative check 3 of 3 is not demonstrable. See condition 3.

---

## Bugs

| ID | Title | Severity | Status |
|---|---|---|---|
| BUG-0001 | Out-of-bounds kill plane never fires in levels 05 and 06 | S2-Major | **Closed** 2026-08-25, developer playtest sign-off |
| BUG-0002 | Moving platform root node misspelled `MovingPlatfornm` | S4-Trivial | Open — scheduled Sprint 2 |

**No S1 or S2 bugs are open.** The Definition of Done's bar — no open S2 at sprint
close — is met.

---

## Verdict: **APPROVED WITH CONDITIONS**

Rule applied: S4 bug open and PASS WITH NOTES issues documented, with no S1 or S2
open.

### Conditions

1. **CLR-005 and TUN-006 need one scratch-branch CI run.** A deliberate violation
   per check, confirmed red, then reverted. Both greps are written and were
   verified locally; what is missing is live-fire confirmation.

   Mechanics matter here. The workflow triggers on push to `development` or
   `main`, and on pull requests targeting them. **A scratch branch pushed on its
   own will not fire it.** The run needs either a PR against `development` or a
   direct push to `development`. There is no `gh` CLI on this machine, so opening
   a PR is a web-UI action.

   Background: the trigger was widened from `main` to `development` on 2026-08-25
   in `d77337c`. This repository has no `main` branch — not local, not remote;
   `origin/HEAD` points at `development` — so that CI job had never once fired
   since it was written. Owner: devops-engineer.

2. **BUG-0002 (S4)** stays open and is scheduled to Sprint 2. It is deliberately
   sequenced after CLR-003's playtest so the fix cannot invalidate that sign-off.

3. **TUN-005's V1 negative path is accepted as unreachable by design.** Re-pointing
   a `.tres` at the wrong script is a parse error at load, so group 1 is never
   reached. V1 guards GH#73615, where a `preload()` resolves non-null yet
   wrong-type — a condition the engine produces internally and no hand edit can
   reproduce. **V1 must not be weakened to a null check to make the negative path
   observable.** Reopen only if a vector is found that yields a non-null,
   wrong-type resource.

   Negative checks 1 and 2 WERE demonstrated red on 2026-08-25 and are recorded in
   the story's Implementation Record.

4. **Ten tech-debt items are open** — 3 from GA-001, 7 from the CLR-004 code
   review — in `docs/tech-debt-register.md`. None block this gate.

---

## Process notes

Phases 3, 4 and 5 of `/team-qa` were no-ops and were not run:

- **Phase 3** — the QA plan at `production/qa/qa-plan-sprint-1.md` already exists
  and sprint scope did not change. Re-authoring would have churned the file.
- **Phase 4** — no story required test cases to be written.
- **Phase 5** — zero manual QA sessions remained.

This report was written directly rather than by a spawned `qa-lead`. The Phase-2
strategy pass recorded TUN-005 as "met" without noticing that it had 15 unticked
acceptance criteria, a Test Evidence status of "[ ] Not yet created", and no
Implementation Record. That assumption had to be checked by hand regardless, and
the check changed the outcome: two negative demonstrations that had never been
recorded were run, and the row moved from `review` to `done` on evidence rather
than on inference.

---

## Next Step

Verdict is APPROVED WITH CONDITIONS. Resolve the conditions before advancing a
phase. S4 bugs may be deferred to polish.

Remaining close-out sequence, not yet run:

1. `/retrospective`
2. `/sprint-plan new`

Do not run `/gate-check` for a Pre-Production to Production advance until the
condition-1 CI run is complete — a phase gate that rests on two CI guards nobody
has seen execute is the same class of gap this sprint spent effort closing.
