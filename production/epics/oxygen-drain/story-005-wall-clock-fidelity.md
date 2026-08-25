# Story 005: Wall-clock fidelity — `oxygen_capacity` seconds ±0.1 s, at multiplier 1.0 and 0.5

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §4 · §7 · §8 AC6 ·
`design/accessibility-requirements.md` T3, "Timing extension"
**Requirement**: `TR-oxygen-001` *(wall-clock half — the drain half closed in
story 002)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **`level-state` story 002 owns the arithmetic half of AC6 and says so**: "with
> `drain_rate` 1.0, draining a fixed timestep repeatedly for `capacity` seconds of
> accumulated delta brings `remaining` to exactly zero, within float tolerance.
> *(The wall-clock half is the `oxygen-drain` epic — this story owns the
> arithmetic, not the loop.)*" This story is that loop. Do not re-assert the
> arithmetic here.

**ADR Governing Implementation**: ADR-0008: Oxygen Drain, Shared Death Path, and
the Accessibility Drain-Rate Override (Decision §3, Validation Criteria)
*(primary)* · ADR-0006 D6.5/D6.6 *(secondary — `drain_rate` is an authored
constant of 1.0 and must stay there)*

**ADR Decision Summary**: ADR-0008's own Validation Criteria name this test: "a
level with `oxygen_capacity` authored and `drain_rate_multiplier` left at default
1.0 must survive exactly `oxygen_capacity` wall-clock seconds ±0.1 s". Because
`Tuning.OXYGEN.drain_rate` is authored at 1.0 (`suit-oxygen.md` §7: "Leave at 1.0
so capacity reads as real seconds"), the composition reduces to the multiplier
alone, and capacity reads directly as seconds.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. This story is mostly a test, and the test
harness facts matter more than the engine ones:

- **The runner command must include `-a res://tests/integration` and `-c`.**
  Unit-only was documented until 2026-08-24 and silently excluded 8 integration
  cases. See `tests/README.md`.
- **`-a "res://path/test.gd:test_name"` is not a supported selector** — it exits
  `0` having run nothing. Isolate with a `tests/scratch/` suite and delete it.
- **Tests must be deterministic** — the project's testing standard forbids
  time-dependent assertions. **Do not measure this against a real clock.** Drive
  the physics step count and derive seconds from it. See Implementation Notes.
- gdUnit4 fails the whole suite on one GDScript warning at discovery.

**Control Manifest Rules (this layer)**:
- Required: "Effective drain pre-scales `delta` by
  `OxygenAccessibility.drain_rate_multiplier` before calling
  `OxygenState.drain(scaled_delta)`." — ADR-0008 (§3)
- Required: "Any rule-bearing quantity whose value on a specific frame decides an
  outcome (pour progress, oxygen, death timers) must live in `_physics_process`,
  never `_process`." — ADR-0005 (D5.5)
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`, and never call `.duplicate()` on a tuning resource." — ADR-0006
  (`tuning_resource_runtime_mutation`)
- Forbidden: "Never accumulate or evaluate a rule-bearing quantity in
  `_process`." — ADR-0005 (`gameplay_timing_in_idle_process`)

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md` and `design/accessibility-requirements.md`,
scoped to this story:*

- [ ] **AC6, wall-clock half** — with `drain_rate` = 1.0 and the multiplier at
      its default 1.0, an idle level survives exactly `oxygen_capacity`
      wall-clock seconds, ±0.1 s
- [ ] At multiplier 0.5, the same level survives **2× `oxygen_capacity`**
      seconds, ±0.1 s — the "timing extension" ceiling
      `accessibility-requirements.md` records
- [ ] The committed `OxygenTuning.drain_rate` value is **still 1.0** after this
      story. Nothing in this story tunes it
- [ ] The test is deterministic and clock-free — no `Time.get_ticks_msec()`
      assertion, no `await` on a real duration
- [ ] `oxygen_capacity` is read from the level's authored export, not from a
      constant in the test

---

## Implementation Notes

*Derived from ADR-0008's Validation Criteria:*

- **Drive frames, do not wait on a clock.** Step `_physics_process` a known number
  of times at the project's fixed physics tick and assert on the count, then
  convert: at 60 Hz, `capacity` seconds is `capacity * 60` steps. Read the tick
  rate from the project setting rather than hardcoding 60 — a later change to
  `physics/common/physics_ticks_per_second` must not silently move this test's
  meaning. This is what makes ±0.1 s a real tolerance rather than a scheduling
  artefact of the CI machine.
- **The ±0.1 s tolerance is the GDD's, and it is generous on purpose.** Do not
  tighten it to prove precision; float accumulation over thousands of steps is
  exactly what the tolerance is there to absorb.
- **Do not write `Tuning.OXYGEN.drain_rate` to test the 0.5 case.** That is the
  `tuning_resource_runtime_mutation` forbidden pattern and the precise D6.5
  violation that D6.6 and the whole accessibility autoload exist to prevent. Set
  `OxygenAccessibility.drain_rate_multiplier` instead — which is the point of the
  design, and testing it this way is itself a check that the design works.
- **`accessibility-requirements.md` T3 is only half-runnable here, and the doc is
  optimistic about it.** T3 is marked "Runnable now", but its pass condition is
  "**E1** reads real seconds remaining" — and E1 is the HUD oxygen gauge, owned by
  the Presentation HUD epic under ADR-0010. **This story closes the arithmetic
  half**: at multiplier 0.5 the level really does last twice as long. The readout
  half stays owed to the HUD epic. Record it that way; do not tick T3 whole.
- **The 2× ceiling is a GDD fact, not a settings choice.**
  `accessibility-requirements.md` records that 0.5–1.0 caps timing extension at
  2×, below the template's 3× guidance, and that widening it "is a GDD amendment,
  not a settings change". If a playtest later shows 2× is short, that is a GDD
  change request, not a test adjustment.
- **`oxygen_capacity` is a per-level authored export derived from `O_level`, never
  guessed** (`suit-oxygen.md` §7, R6). The test reads whatever the synthetic level
  authors; it does not assert a particular capacity value.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **`level-state` story 002**: AC6's arithmetic half — that a fixed accumulated
  delta brings `remaining` to exactly zero within float tolerance.
- **Story 002**: the per-frame composition itself, and that the multiplier is
  read fresh each frame.
- **Story 001**: the clamp. This story uses 1.0 and 0.5, both in range.
- **`accessibility-requirements.md` T3's readout half** — E1, the HUD oxygen
  gauge, Presentation HUD epic under ADR-0010. Also E1's "displays the COMPOSED
  `oxygen_remaining / drain_rate`" rule (D10.5) belongs there, not here.
- **Tuning `oxygen_capacity` for any actual level.** Capacity is derived per level
  from `O_level` and is the level-design epic's business. This story proves the
  clock is honest, not that any particular level is fair.
- **`margin` and the threshold knobs.** Untouched by this story.

---

## QA Test Cases

*Story type: **Integration** — automated test specs.*

- **AC-1 — an idle level survives exactly capacity seconds at default**
  - Given: a synthetic level with an authored `oxygen_capacity`, `drain_rate` at
    its committed 1.0, multiplier at its default 1.0, and no player input
  - When: physics frames are stepped until `remaining` reaches `0.0`
  - Then: the step count, converted at the project's physics tick rate,
    is `oxygen_capacity` seconds ±0.1 s
  - Edge cases: read the tick rate from the project setting, not as a literal.
    Also assert the level was genuinely idle — a test that accidentally drives
    the player still passes, and would hide a state-dependent drain that AC1
    (story 002) is supposed to have ruled out.

- **AC-2 — multiplier 0.5 doubles the survival time**
  - Given: the same level with `OxygenAccessibility.drain_rate_multiplier = 0.5`
  - When: stepped to depletion
  - Then: the converted duration is `2 × oxygen_capacity` seconds ±0.1 s
  - Edge cases: set the multiplier through the autoload, never by writing
    `Tuning.OXYGEN.drain_rate` — a test that mutates the tuning resource to reach
    the same number passes while demonstrating the forbidden pattern.

- **AC-3 — the committed tuning value is unchanged**
  - Given: `src/resources/tuning/oxygen_tuning.tres` after this story
  - When: read
  - Then: `drain_rate` is `1.0`, and `typeof()` is `TYPE_FLOAT`
  - Edge cases: a **wrong-type** value in a `.tres` resolves silently on this
    project — `0.0` for a float knob. That is why `tuning_resources_test.gd`
    asserts `typeof()` on all twelve knobs, and why this check is worth its two
    lines. It is also the guard against a "temporary" test tweak being committed.

- **AC-4 — the test is clock-free**
  - Given: the test file
  - When: searched for `Time.get_ticks`, `OS.get_ticks`, and `await` on a timer
    or a real duration
  - Then: no match
  - Edge cases: capture the match and branch on emptiness — a bare `grep` exits
    `1` on no match and passes forever. The project's testing standard forbids
    time-dependent assertions outright; this AC is what keeps AC-1 from
    reintroducing one to look more realistic.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/oxygen/oxygen_wallclock_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (the multiplier) · Story 002 (the composition and the
  loop) · `level-state` stories 002 and 004 (`OxygenState` and its construction
  from the level's authored capacity).
- **Unlocks**: None in this epic. It closes `TR-oxygen-001`'s wall-clock half and
  the arithmetic half of `accessibility-requirements.md` T3.
