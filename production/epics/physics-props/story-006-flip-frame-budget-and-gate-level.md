# Story 006: Flip frame-budget harness, and the AC10 gate-level decision

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration *(see "On this story's type" below — the GDD types AC10 **Performance**, and that is the decision this story owes)*
> **Estimate**: L (4 hours — a harness, a measurement, and a standards decision)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (R8, AC10, §7)
**Requirement**: `TR-props-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, V7 and Performance Implications) · ADR-0006
(secondary — owns `props_per_level_budget`, the lever if the measurement fails)
**ADR Decision Summary**: V7 specifies the measurement — 40 `PropBody` instances, one
scripted 90° flip, frame time sampled across the ease window, under 16.6 ms. ADR-0011
**specifies how to measure and deliberately does not decide the gate level**, because
`physics-props.md` types AC10 *Performance* and `.claude/docs/coding-standards.md`'s
evidence table has no Performance row.

**Engine**: Godot 4.7.1 | **Risk**: LOW for the API; the *result* is genuinely unknown
**Engine Notes**: No post-cutoff API is involved. The engine facts underpinning the
budget claim were traced against 4.7.1-stable source at the 2026-08-16 review:
`godot_step_2d.cpp:140,151` (only active bodies are stepped) and
`godot_body_2d.cpp:139-147` (a sleeping body leaves the active list).

> **Read this before treating V7 as a formality.** ADR-0011 says in those words: *"V7
> exists to measure it, not to confirm a foregone conclusion."* The script cost is
> trivial — at most 40 clamps plus 40 `sleeping = false` writes per frame over 6-7
> frames. **The engine-side cost is the real budget threat.** Waking 40 bodies in one
> substep moves them all onto the solver's active list, forcing a broadphase AABB
> refresh, narrow-phase pair regeneration, and contact-solver iterations for every prop
> that was resting on terrain. That is the more plausible source of a frame spike than
> any line of GDScript in this system, and **nothing in ADR-0011 mitigates it.**

**If the measurement fails**, ADR-0011 names the levers and rules one out: the levers are
`props_per_level_budget` (ADR-0006 owns it, range 10–80) and per-prop `can_sleep`.
**A change to D11.2 is not a lever** — the clamp is not the cost.

**Control Manifest Rules (this layer)**:
- Guardrail: "`prop_gravity`: 0 per-frame script cost in steady state; ≤40-prop wake pass
  only while the vector is easing (~6-7 frames per gravity change at 60 FPS)." — source:
  ADR-0001
- Guardrail: **Target Framerate 60 FPS, frame budget 16.6 ms; draw calls < 500 per frame**
  — source: `.claude/docs/technical-preferences.md`
- Required: "`props_per_level_budget` is read through `Tuning.PROP`." — source: ADR-0006

---

## On this story's type, and the decision it owes

`physics-props.md` types AC10 **Performance**. `.claude/docs/coding-standards.md`'s test
evidence table defines five story types — Logic, Integration, Visual/Feel, UI,
Config/Data — and **has no Performance row**, so AC10's gate level (BLOCKING or ADVISORY)
is undefined. ADR-0011 records this under Consequences → Negative and declines to re-type
it.

This story is typed **Integration** so that it routes to a real, non-advisory evidence
path rather than falling through the table. That is a routing choice, **not** the gate
decision — the gate decision is AC-1 below, and it must be made explicitly rather than
inherited from the type field.

ADR-0011 also notes this is the **second** instance of the same tension — ADR-0012
recorded an identical AC10 problem for `watering-system.md` — *"which suggests the
standards table, not the two GDDs, is the thing that needs the edit."* Weigh that when
deciding where the fix lands.

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` R8 and AC10, and ADR-0011 V7, scoped to this story:*

- [ ] **The gate level for AC10 / V7 is recorded — BLOCKING or ADVISORY — with its
      rationale, and in a named location.** Either a Performance row is added to
      `.claude/docs/coding-standards.md`'s evidence table, or `physics-props.md` re-types
      AC10 to an existing type. If neither is done, the story records **why not**, and
      names the owner. Silence does not close this.
- [ ] If a Performance row is added to the standards table, `watering-system.md`'s
      matching AC10 tension is resolved by the same edit — ADR-0011 says the second
      instance points at the table, not the GDDs.
- [ ] A repeatable harness exists that instantiates 40 `PropBody` instances, runs one
      scripted 90° flip, and samples frame time across the ease window.
- [ ] The measurement is reported: peak frame time, mean across the ease window, and the
      frame count sampled. Numbers, not a pass/fail alone.
- [ ] The 40 figure is read from `Tuning.PROP.props_per_level_budget`, not hardcoded, so
      the harness follows the knob if it moves.
- [ ] Props rest on terrain before the flip, so the measurement includes the contact-pair
      regeneration cost that is the actual risk. A harness that flips 40 free-falling
      props measures the wrong thing.
- [ ] The result is recorded in ADR-0011's Validation Criteria section against V7,
      whether it passes or fails.
- [ ] If it fails, the remediation names a lever — `props_per_level_budget` or per-prop
      `can_sleep` — and **does not** propose changing D11.2.
- [ ] The harness and any test file are warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 V7 and Performance Implications:*

**Measure the engine, not the script.** The script-side cost is bounded and known: at
most 40 `_integrate_forces` clamps (story 002) plus ADR-0001's 40 `sleeping = false`
writes (gravity-authority story 007) per frame, over roughly 6-7 frames per gravity
change at 60 FPS. Each clamp is one length comparison and, rarely, one normalise. If the
harness reports a spike, do not go looking for it in GDScript first.

**The setup is what makes the measurement honest.** Let the props settle onto terrain and
go to sleep *before* the flip. The cost under test is 40 bodies rejoining the solver's
active list at once — broadphase AABB refresh, narrow-phase pair regeneration, contact
solving. Props already awake and airborne skip most of that.

**Headless measurement caveat.** `.claude/docs/coding-standards.md` warns that
platform-specific rendering should be tested on target hardware, not headlessly. Frame
time here is physics-dominated rather than render-dominated, so a headless run is
informative — but say which it was in the report, and do not present a headless number as
a 60 FPS guarantee on target hardware.

**Do not confirm a foregone conclusion.** The honest outcomes are "measured, passed at
40", "measured, failed at 40, passes at N", or "could not measure reliably, here is why".
All three are acceptable deliverables. A report that says "should be fine, the script
cost is trivial" is not — that is the reasoning V7 exists to replace.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: the clamp itself. This story measures a prop that already clamps.
- **`gravity-authority` story 007**: the wake pass. This story measures its cost and does
  not modify it.
- **Changing `props_per_level_budget`.** If the measurement says the budget must drop,
  that is a finding and a recommendation. ADR-0006 owns the knob, and the change is a
  separate action with its own approval.
- **AC11** — "a gravity flip in a prop-furnished room reads as the room turning over".
  The GDD types it **Visual, advisory**, and it needs a human playtest in a furnished
  level. It cannot be closed from a session, and prop content is deferred to
  Vertical-Slice tier by `art-bible.md` §1.3.
- **Draw-call measurement.** R8 names both 60 FPS and < 500 draw calls; V7 specifies frame
  time only. If draw calls are sampled opportunistically, report them separately and do
  not let them gate V7.

---

## QA Test Cases

*Derived from ADR-0011 V7. The developer implements against these — do not invent new
test cases during implementation.*

- **AC-1**: the gate-level decision is recorded
  - Setup: read `.claude/docs/coding-standards.md`'s evidence table,
    `physics-props.md` AC10, and ADR-0011 Consequences → Negative
  - Verify: a named document now states whether AC10 / V7 gates as BLOCKING or ADVISORY,
    with rationale — or states explicitly that the decision is deferred, to whom, and why
  - Pass condition: a reader who knows nothing of this session can find the answer in a
    committed file. **This AC is not satisfied by a decision made only in conversation.**

- **AC-2** (V7): the 40-prop flip measurement
  - Given: a harness level with `Tuning.PROP.props_per_level_budget` `PropBody` instances,
    all settled and asleep on terrain
  - When: one scripted 90° gravity flip runs
  - Then: frame time across the ease window is reported — peak, mean and sample count —
    and compared against 16.6 ms
  - Edge cases: assert the props were actually **asleep** at the moment of the flip,
    otherwise the harness silently measures a cheaper scenario than the one at risk; run
    the flip at more than one angle if peak times differ; and report whether the run was
    headless or windowed

- **AC-3**: the harness follows the knob
  - Given: `props_per_level_budget` changed to a different value in the tuning resource
  - When: the harness runs
  - Then: it instantiates that many props
  - Edge cases: assert no literal `40` appears in the harness

- **AC-4**: the result is written down
  - Setup: ADR-0011's Validation Criteria section
  - Verify: V7's row or an adjacent note carries the measured numbers and the date
  - Pass condition: pass or fail, the number is in the ADR. A failing measurement that is
    recorded is a successful story; an unrecorded passing one is not

---

## Test Evidence

**Story Type**: Integration *(routing choice — see "On this story's type")*
**Required evidence**: `tests/integration/physics/prop_flip_budget_test.gd` — the harness
— plus a measurement report at `production/qa/evidence/prop-flip-budget-evidence.md`
carrying the numbers.

**Gate level**: **undecided — AC-1 is what decides it.** Until AC-1 lands, treat the
measurement as reported-but-not-gating, and do not let an unrecorded assumption about the
gate level pass for the decision.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`PropBody`), Story 002 (the clamp), Story 003 (correct space
  gravity from the first physics step), `gravity-authority` story 007 (the wake pass —
  without it there is no wake cost to measure, and the measurement would be meaningless)
- **Unlocks**: None. This is the epic's last story, and the one that closes the epic's
  "V7's evidence gate level is recorded, either way" Definition-of-Done line
