# Story 006: Wall-jump behaviour and tuning

> **Epic**: Player Core
> **Status**: **Blocked**
> **Layer**: Core
> **Type**: Integration
> **Estimate**: *(not estimable while Blocked)*
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## BLOCKED

**BLOCKED: `PlayerWallJumpComponent` has no GDD, no TR-ID and no ADR.** There is no design
source to verify any behavioural change against, so no acceptance criterion in this story
can be written from an approved document.

`architecture.md` **QQ-05** rates this **Medium**: load-bearing traversal mechanics with no
design authority. The epic Risks table states the rule this story follows —

> Stories may wire the component into the D7.3 call order, because that is ADR-0007's scope.
> Stories that change wall-jump *behaviour* are **Blocked** — they would have no design
> source to verify against.

**The wiring is not blocked and is not in this story.** D7.3 step 4's call, with its
`enable_wall_jump` guard, is implemented by **story 001**. This story covers only what wall
jump *does*, which nothing specifies.

### Two supporting facts, both re-derived from source

1. **No TR-ID exists to claim.** `docs/architecture/tr-registry.yaml` (v2, 74 requirements)
   contains no wall-jump requirement under any `TR-gravity-*`, `TR-flow-*` or other prefix.
   This is not a lookup failure — there is nothing to look up.
2. **The reviewed reference implementation does not have this component at all.**
   `prototypes/gravity-gardener-vertical-slice/scripts/components/` holds five components;
   `PlayerWallJumpComponent` is not among them. The vertical slice dropped the mechanic and
   still reached a PROCEED verdict. So the shipped `src/scripts/components/player_wall_jump_component.gd`
   is undocumented **and** unexercised by the slice — which raises the cost of guessing at
   its intended behaviour, and is a live input to the resolution decision below.

### How to unblock

Pick one and record it. Both are legitimate; neither is the default.

- **Document it.** Run `/reverse-document` against
  `src/scripts/components/player_wall_jump_component.gd` to produce a wall-jump GDD section,
  then allocate TR-IDs via a `tr-registry.yaml` sweep, then decide whether it needs its own
  ADR or falls under ADR-0007. Only then does this story become writable.
- **Accept it as undocumented, explicitly.** Record the choice — that wall jump stays a
  shipped, unspecified mechanic frozen at its current behaviour — and close QQ-05 with that
  decision rather than leaving it open. If this is chosen, this story is deleted rather than
  implemented, and story 001's step 4 wiring is all that remains.

A third option exists and should be named: **cut the mechanic**, on the evidence that the
vertical slice shipped a PROCEED verdict without it. That is a creative-director call, not
an architecture one.

---

## Context

**GDD**: *None.* No document in `design/gdd/` describes wall jump.
**Requirement**: *None.* No TR-ID exists.
**ADR**: **N/A — no ADR covers wall-jump behaviour.** ADR-0007 covers only *where in the
call order* the component runs (D7.3 step 4), not what it does. That wiring is story 001's.

**Engine**: Godot 4.7.1 | **Risk**: *(unassessable — no decision to assess)*
**Engine Notes**: the existing component uses `is_on_wall()` and a `get_wall_normal()`
callable passed in by the facade. Both are pre-4.4 and unchanged through 4.7. This tells us
the mechanic is implementable; it tells us nothing about what it should do.

**Control Manifest Rules (Core layer)**:
- Required: fixed call order — wall jump is step 4, after gravity (3) and before jump (5) —
  source ADR-0007 (D7.3). **This rule is already satisfied by story 001** and is not what
  blocks this story.
- Forbidden: any node keeping a private gravity field — source ADR-0001
  (`private_gravity_copy`). Applies to `player_wall_jump_component.gd` like any other node,
  and story 001's AC-3 already asserts it.

---

## Acceptance Criteria

*Cannot be written. Acceptance criteria come from GDDs (`.claude/docs/coding-standards.md`),
and no GDD covers this mechanic.*

The criteria this story would need, once a source exists:

- [ ] *(pending)* The launch velocity and its direction relative to the wall normal.
- [ ] *(pending)* Whether the mechanic holds at every gravity angle, and what "wall" means
      when gravity is horizontal — the case where `is_on_wall()` and `is_on_floor()` swap
      meaning on screen.
- [ ] *(pending)* Interaction with R6's variable-jump release cap. Story 003 deliberately
      does **not** extend the release cap to wall-jump velocity, because doing so would be
      a behaviour change to an undocumented mechanic. Whether it should is one of the
      questions this story must answer.
- [ ] *(pending)* Interaction with R5. If wall jump grants a second launch, it is a second
      traversal lever, and R10's rationale argues explicitly against those — a gap's
      crossability would no longer follow from the zone multiplier alone.
- [ ] *(pending)* Whether `enable_wall_jump` stays a per-level flag, and if so which levels
      set it.

---

## Implementation Notes

*None. Writing implementation guidance here would be inventing the design, which
`.claude/docs/coding-standards.md` and this project's collaboration protocol both forbid.*

The one observation worth carrying forward, because it is evidence rather than design: the
release-cap and single-lever questions above are **not stylistic**. Both touch rules
(`gravity.md` R5, R6, R10) that other stories in this epic assert against. Whatever
resolution is chosen must be checked against story 003's AC-1 and story 004's AC-1, or the
mechanic will be specified into conflict with two passing tests.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001: the D7.3 step 4 wiring**, including the `enable_wall_jump` guard and the
  `get_wall_normal()` callable. That is ADR-0007's scope and is **Ready**, not Blocked.
- Story 003: the R6 release cap, which applies to `PlayerJumpComponent` only.
- Stories 002, 004, 005: unrelated.

---

## QA Test Cases

*Cannot be written. Test cases are derived from acceptance criteria, and this story has
none.*

Story 001's AC-1 already asserts that `wall_jump_component.try(...)` appears at position 4
in the call order, and its AC-3 asserts the component holds no gravity field. Those are the
only wall-jump assertions this epic can currently justify, and they both live in story 001.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: *(undetermined — depends on which unblocking route is taken)*

**Status**: [ ] Blocked — no evidence path defined

---

## Dependencies

- Depends on: a design decision. `/reverse-document`, an explicit accept-as-undocumented
  record, or a cut decision. Owner: **creative-director** for the cut question,
  **game-designer** for the reverse-document route.
- Blocks: nothing. Every other story in this epic proceeds without it.
- Related: `architecture.md` QQ-05.
