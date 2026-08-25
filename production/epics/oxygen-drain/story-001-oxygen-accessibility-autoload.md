# Story 001: `OxygenAccessibility` — one clamped field, scene autoload, no `class_name`

> **Epic**: Oxygen Drain
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/suit-oxygen.md` §7 (`drain_rate` knob) ·
`design/accessibility-requirements.md` §"Timing extension", T3
**Requirement**: **No TR-ID, by design.** `tr-registry.yaml`'s SCOPE rule admits
GDD-derived requirements only, and names
`design/accessibility-requirements.md` as the exact document whose UX commitments
are **not** TRs. This is the same recorded exception `FramePriority`
(`level-state` story 003) and `V-WIRING` rely on. Do not invent a TR ID for it.

**ADR Governing Implementation**: ADR-0008: Oxygen Drain, Shared Death Path, and
the Accessibility Drain-Rate Override (Decision §3)

**ADR Decision Summary**: `OxygenTuning.drain_rate` is a read-only authored
constant (ADR-0006 D6.5), yet `suit-oxygen.md` §7 calls `drain_rate` a
player-facing accessibility hook. ADR-0008 resolves the contradiction with a
separate autoload holding **exactly one field**, a multiplier that `OxygenDrain`
composes onto the authored value. Nothing ever writes `Tuning.OXYGEN`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: ADR-0008 declares no post-cutoff API. Two engine facts bind
this story, and one of them contradicts the ADR's own code block:

- **`@export_range` does not clamp and does not reject a hand-edited `.tres`.**
  Verified against the 4.7.1 binary on 2026-08-24 —
  `production/qa/evidence/t4-export-range-clamp-spike.md`. Every `@export_range`
  is an inspector hint, not a validator. **ADR-0008's Key Interfaces block relies
  on `@export_range(0.5, 1.0, 0.01)` alone for the property and clamps only
  inside `set_drain_rate_multiplier()`** — so a direct assignment
  (`OxygenAccessibility.drain_rate_multiplier = 5.0`) escapes the range entirely.
  The prototype already hardened this with a property-level `set:` that calls
  `clampf`. **Implement the prototype's shape.** This is a hardening of ADR-0008,
  not a departure from its decision; the decision is the 0.5–1.0 range, and the
  property setter is what actually delivers it.
- **A `class_name` that matches an autoload singleton name is a conflict, not a
  convenience.** See the Implementation Notes below — this is the one thing in
  this story to verify against the binary rather than recall.
- gdUnit4 treats GDScript warnings as errors at discovery: one warning fails the
  whole suite at compile time. Annotate types explicitly.

**Control Manifest Rules (this layer)**:
- Required: "`OxygenAccessibility` is a scene autoload (not bare script), so
  `@export_range(0.5, 1.0)` gets inspector surface; `drain_rate_multiplier` is
  clamped via `set_drain_rate_multiplier()`." — ADR-0008
- Required (pattern precedent, Foundation layer): "`GravityAuthority` must be a
  *scene* autoload (`.tscn` with script attached), never a bare script autoload —
  a bare script autoload gives `@export` no inspector surface." — ADR-0001
- Forbidden (pattern precedent, Foundation layer): "Do NOT declare `class_name`
  on `gravity_authority.gd`. It is reached only through the autoload singleton
  name; a `class_name` would create two competing [identities]." — ADR-0001
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`, and never call `.duplicate()` on a tuning resource." — ADR-0006
  (`tuning_resource_runtime_mutation`)
- Forbidden: "`OxygenState` (or any `RefCounted` state object) must never read
  `OxygenAccessibility` or any other autoload directly." — ADR-0008
  (`oxygen_state_reads_accessibility_autoload`) — *this story creates the object
  that rule protects against; do not add a back-reference.*

---

## Acceptance Criteria

*From `design/gdd/suit-oxygen.md` §7 and `design/accessibility-requirements.md`,
scoped to this story:*

- [ ] `oxygen_accessibility.tscn` exists as a **scene** autoload (script
      attached to a `Node` root), registered in `project.godot`'s `[autoload]`
      block, and the script declares **no `class_name`**
- [ ] `drain_rate_multiplier` is a `float` defaulting to `1.0`, so an untouched
      setting is a no-op rather than a special case
- [ ] Any write outside `[0.5, 1.0]` is clamped into range — **through the
      property setter, not only through `set_drain_rate_multiplier()`**
- [ ] `set_drain_rate_multiplier()` exists and clamps, per ADR-0008's read
      contract for the future settings-screen ADR
- [ ] The autoload holds **exactly one field**. No second field, no
      `ConfigFile`, no `user://` access, no persistence of any kind
- [ ] The value resets to `1.0` on every launch — this is the accepted negative
      consequence in ADR-0008, not a defect to fix here

---

## Implementation Notes

*Derived from ADR-0008 Decision §3:*

- **Do not declare `class_name OxygenAccessibility`, despite ADR-0008's Key
  Interfaces block showing it.** ADR-0008's code block writes
  `class_name OxygenAccessibility` on a node whose autoload singleton name is
  also `OxygenAccessibility`. ADR-0001 bans exactly this on `gravity_authority.gd`
  and the manifest carries that ban, but the manifest has **no oxygen
  equivalent** — which is why the ADR's slip has gone unremarked. The
  prototype (`prototypes/.../autoloads/oxygen_accessibility.gd`) already omits
  `class_name`, citing "same rationale as GravityAuthority". **Follow ADR-0001's
  established pattern and the prototype, not ADR-0008's code block.**
- **Verify the collision behaviour, do not assume it.** Before settling the
  above, confirm against the 4.7.1 binary what Godot actually does when a global
  `class_name` matches an autoload singleton name — an error at parse, a warning,
  or silence. Use a `tests/scratch/` gdUnit4 suite and delete it afterwards; a
  bare `-s script.gd` with a `SceneTree` MainLoop hangs with no output on this
  machine. Record the result in the Implementation Record. **Neither ADR is
  amended by this story** — if the check confirms a hard conflict, the mechanism
  is a registry supersession entry or a manifest rule, raised as a finding, not
  an edit to ADR-0008's frozen text.
- **The range is 0.5–1.0 and the ceiling is a GDD fact, not a settings choice.**
  `accessibility-requirements.md` records that this range caps timing extension at
  2×, below the template's 3× guidance, and that widening it "is a GDD amendment,
  not a settings change". Do not widen the clamp to be generous.
- **`clampf()` absorbing an out-of-range value silently is accepted, for now.**
  ADR-0008 records this as a known risk and says it is acceptable *because nothing
  calls the setter yet*. Do not add error reporting here; the future
  settings-screen ADR owns that decision once a UI can produce bad input.
- **Nothing in this story reads or writes `Tuning.OXYGEN`.** The composition
  happens in `OxygenDrain` (story 002), and it is the only place the two numbers
  meet.
- Register the autoload in `project.godot`. Order relative to `GravityAuthority`
  does not matter — ADR-0008 states the two have no dependency on each other.
  Note that `GravityAuthority` is not yet in `[autoload]` either; that is
  `gravity-authority` story 001's job, not this story's.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **Story 002**: reading `drain_rate_multiplier` and composing it onto
  `Tuning.OXYGEN.drain_rate`. This story creates the field; it does not consume it.
- **Story 005**: proving the multiplier changes wall-clock survival time.
- **A settings screen, and disk persistence.** ADR-0008 names a future
  settings-screen ADR as the owner and rejects specifying a save format with no
  writer. Do not add one.
- **Any second accessibility field** (text scale, remapping, reduced motion).
  ADR-0008 names the scope as exactly one field and says extending it needs its
  own ADR.
- **`accessibility-requirements.md` T3 as written.** T3 compares the **E1 HUD
  gauge** against a stopwatch, and E1 belongs to the Presentation HUD epic
  (ADR-0010). Story 005 covers the arithmetic half only.

---

## QA Test Cases

*Story type: **Logic** — automated test specs.*

- **AC-1 — the autoload is a scene autoload with no `class_name`**
  - Given: `project.godot` after this story
  - When: the `[autoload]` block and `oxygen_accessibility.gd` are read
  - Then: the entry points at a `.tscn`, not a bare `.gd`, and the script
    contains no `class_name` declaration
  - Edge cases: structural, so assert on the file text rather than on runtime
    behaviour. A bare-script autoload still *works* at runtime — it just silently
    loses the inspector surface the ADR chose it for, which is precisely the
    failure that would go unnoticed.

- **AC-2 — the default is 1.0 and is a true no-op**
  - Given: a freshly launched tree
  - When: `OxygenAccessibility.drain_rate_multiplier` is read with nothing having
    written it
  - Then: it is exactly `1.0`
  - Edge cases: assert `is_equal_approx(v, 1.0)` **and** `typeof(v) == TYPE_FLOAT`.
    A wrong-type value in a resource resolves silently on this project — the
    `tuning_resources_test.gd` precedent asserts `typeof()` for that reason.

- **AC-3 — the property setter clamps, not only the method**
  - Given: the autoload
  - When: `drain_rate_multiplier` is **assigned directly** to `5.0`, then `-1.0`,
    then `0.0`
  - Then: it reads `1.0`, `0.5`, `0.5` respectively
  - Edge cases: **this is the test that distinguishes the implemented shape from
    ADR-0008's code block**, which would leave all three unclamped. Test direct
    assignment explicitly; testing only `set_drain_rate_multiplier()` passes
    against the weaker implementation and proves nothing.

- **AC-4 — `set_drain_rate_multiplier()` clamps**
  - Given: the autoload
  - When: called with `5.0`, `-1.0`, `0.75`
  - Then: reads `1.0`, `0.5`, `0.75`
  - Edge cases: the boundary values `0.5` and `1.0` themselves must pass through
    unchanged — an off-by-one clamp that excludes its own endpoints is the likely
    slip.

- **AC-5 — exactly one field**
  - Given: `oxygen_accessibility.gd`
  - When: its property list is enumerated (or the script text is read)
  - Then: `drain_rate_multiplier` is the only declared member variable
  - Edge cases: structural guard against the "implicit general settings
    singleton" risk ADR-0008 names. Filter engine-supplied `Node` properties out
    of the enumeration, or assert on script text instead.

- **AC-6 — no persistence exists**
  - Given: `oxygen_accessibility.gd`
  - When: searched for `user://`, `ConfigFile`, `FileAccess`, `save`, `load`
  - Then: no match
  - Edge cases: capture the match and branch on emptiness — a bare `grep` in a CI
    step passes forever, because `grep` exits `1` when it finds nothing. Four
    steps in `.github/workflows/tests.yml` already follow the correct shape; copy
    one rather than reinventing it.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/oxygen/oxygen_accessibility_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None. This autoload has no dependency on `GravityAuthority`,
  on `Tuning`, or on any level object — ADR-0008 states it plainly. It is the one
  story in this epic that can start before `level-state` lands.
- **Unlocks**: Story 002 (which reads the field every physics frame).
