# Story 007: What follows the final level — the end-of-game state

> **Epic**: Level Outcomes
> **Status**: **Blocked**
> **Layer**: Core
> **Type**: Logic
> **Estimate**: Not estimable until unblocked
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

> ## ⛔ BLOCKED — a design decision is owed, not an architecture one
>
> **`design/gdd/level-flow.md` R10 is marked ⚠ TBD by the GDD itself**, and §5's
> "Final level completed" row says only ⚠ **TBD. Not decided**. The blocker is
> upstream of both: `game-concept.md`'s open question of **whether a session is one
> level or several**. `tr-registry.yaml` carries `TR-flow-010` as
> `status: gap, adr: null, adr_status: unowned`. ADR-0014 **D14.6** states plainly
> that it leaves R10 untouched. `production/epics/index.md` line 115 carries it as
> **BLOCKED — design decision owed**.
>
> **To unblock:** resolve R10 with the `game-designer` — one level or several, and
> what the player sees after the last one. Then run `/architecture-decision` if the
> answer needs a structural owner, and re-run `/story-readiness` on this file.
> **Resolve it before the final level ships**, not after.
>
> **Do not implement any part of this story in the meantime, and do not let another
> story implement it by accident.** Story 006's Implementation Notes forbid a silent
> fallback to a menu, a restart, or level 01 for a null `next_level` — each of those
> would be this decision made by implementation rather than by the designer.

## Context

**GDD**: `design/gdd/level-flow.md` §3 R10 ⚠ TBD · §5 *"Final level completed"* ⚠ TBD ·
`design/game-concept.md` *(open: session length)*
**Requirement**: `TR-flow-010` — **the remaining half**. The advance-to-next-level
path is story 006 and is not blocked.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: **N/A — no ADR claims this.** `TR-flow-010` is
recorded as `adr: null, adr_status: unowned`. This field is not blank: it is checked
and the answer is that no architectural decision covers it, because the design
decision it would rest on has not been made. ADR-0003 owns load-time validity of the
next level's scene, which is a **different** question and does not close this one.

**ADR Decision Summary**: None. Filling this in is part of unblocking the story.

**Engine**: Godot 4.7.1 | **Risk**: Not assessable until the behaviour is decided.
**Engine Notes**: None recorded. Whatever is decided — a results screen, a return to
the start menu, a credits scene, a loop — will have its own engine surface, and an
engine-risk assessment belongs in the ADR that owns it, not here.

**Control Manifest Rules (this layer)**:
- Required: "`restart_level()` must return early when `level_complete` is true OR
  `_transition_pending` is set; BOTH paths must check and set it." — ADR-0005 (D5.4).
  *Whatever the end-of-game transition turns out to be, it is a transition and it
  sits behind this guard.*
- Required: "Gameplay values must be data-driven (external config), never
  hardcoded." — `.claude/docs/coding-standards.md`
- Required: "Every system must have a corresponding architecture decision record in
  `docs/architecture/`." — `.claude/docs/coding-standards.md`. *This story has none,
  which is one of the reasons it is Blocked.*

---

## Acceptance Criteria

**None can be written yet.** Acceptance criteria come from GDDs, and the GDD marks
this ⚠ TBD in two places. Inventing criteria here would be inventing the design.

What the criteria will need to cover once R10 is resolved, recorded so the gap is
scoped rather than merely flagged:

- [ ] *(pending)* What a completion does when the finished level is the last in the
      authored sequence
- [ ] *(pending)* Whether `next_level` being unset is the definition of "last", or
      whether the sequence is authored somewhere outside the level scene
- [ ] *(pending)* Whether the end-of-game state is a scene, a screen, or a return to
      an existing one — and who owns its content
- [ ] *(pending)* Whether `GameManager.player_lives` — the one field ADR-0002 leaves
      on the autoload — has any meaning across a completed run
- [ ] *(pending)* Whether the pause lock's "never cleared, it dies with the scene"
      property (ADR-0014 D14.4) still holds if the end-of-game state does **not**
      replace the scene

---

## Implementation Notes

*Nothing to implement. These are notes for whoever unblocks the story.*

- **The blocker is a design question with a real fork, not a formality.** If a
  session is one level, "after the final level" is the whole ending of the game and
  needs content. If a session is several, it may be as small as a results screen and
  a return to the menu. The two answers produce different amounts of work in
  different departments, which is why the estimate is blank rather than optimistic.
- **Two decisions in this epic are already waiting on adjacent unowned ground**, and
  whoever resolves R10 should look at them at the same time rather than in three
  passes:
  - The pause menu's node contract — `interaction-patterns.md` **O9**, owner
    technical-director, unowned. An end-of-game screen and a pause menu are the same
    class of node and probably want one answer.
  - `t_transition` and any transition effect — ⚠ unset, no effect specified.
- **When it unblocks, this may not stay one story.** If the answer is "several
  levels, with a results screen", that is plausibly a story here plus a Presentation
  story. Re-decompose rather than stretching this file to cover both.
- **Do not resolve this by writing an ADR first.** The GDD decision comes first; an
  ADR that decides a design question is the wrong document doing the wrong job.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Story 006**: advancing to the next authored level. That path is **not blocked**
  and is where all non-final completions are handled.
- **Story 004**: the hold. Whatever the end-of-game transition is, it will reuse the
  driver rather than adding a second one.
- **ADR-0003 / `level-validation`**: load-time validity of a next-level scene. A
  different question.
- **The pause menu and any menu screen contract** — `interaction-patterns.md` O9,
  unowned, technical-director.

---

## QA Test Cases

*Test cases cannot be specified for undecided behaviour.* Write them when R10 is
resolved, and classify the story's type again at the same time — a results screen
would make this **UI**, not **Logic**.

One case is already known and can be written the moment the decision lands:

- **AC-1 *(pending the decision)***: The final level does not dead-end silently
  - Given: the last level in the authored sequence
  - When: it is completed
  - Then: whatever R10 decides happens, happens — and in particular the build does
    not sit paused on a hold that never transitions
  - Edge cases: the "sits there paused forever" outcome is the failure mode this
    story exists to prevent, and it is invisible to any test that only exercises
    non-final levels

---

## Test Evidence

**Story Type**: Logic *(provisional — re-classify when unblocked)*
**Required evidence**: **Not assigned.** No test path is reserved, because the story
type may change with the decision.

**Status**: [ ] Blocked — no evidence expected

---

## Dependencies

- **Depends on: a design decision on `level-flow.md` R10 / `game-concept.md` session
  length, owed by the `game-designer`.** Not on any story.
- Also depends on: Story 006 (the non-final advance path this extends)
- Unlocks: the epic's Definition of Done. The epic states it is complete when all
  `level-flow.md` acceptance criteria are verified "**except those depending on
  R10**" — so the epic can close with this story still Blocked, and this file is
  what keeps that exception visible.
