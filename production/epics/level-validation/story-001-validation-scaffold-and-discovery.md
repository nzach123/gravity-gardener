# Story 001: LevelValidation scaffold — type-scan discovery and count_buckets()

> **Epic**: Level Load Validation
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md`
**Requirement**: `TR-watering-008` (partial — this story delivers the shared
counting primitive that `V-BUCKET-SUM` is built on, not the rule itself)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Level load validation contract
**ADR Decision Summary**: `LevelValidation` is a pure, static, tree-free checker
over a level subtree. Discovery is hand-rolled `get_children()` recursion matching
by class identity. Findings are returned as a `PackedStringArray` of coded strings;
the function pushes no errors and mutates nothing.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Two engine facts this story stands on, both verified on
2026-08-14 against `scene/resources/packed_scene.cpp` and the live class
reference. **Do not re-search them** — ADR-0003 states this explicitly.

- **E1** — `PackedScene.instantiate()` populates `@export` values without running
  `_ready()`. Exported properties are set by a `node->set(...)` loop that completes
  before `instantiate()` returns; `_ready()` is dispatched by `NOTIFICATION_READY`,
  which fires only on tree entry. This is what lets every test here build or load a
  subtree, validate it, and free it with no `SceneTree`.
- **F10** — gdUnit4 treats GDScript warnings as errors at test *discovery*. A
  shadowed native method name, an unused variable or a narrowing conversion in
  `level_validation.gd` fails the **entire** suite at compile time, not one test.
  This project has been bitten by this before.

**Control Manifest Rules (this layer)**:

- Required: "Level-content discovery is by recursive `get_children()` type scan
  (`node is Plant`, etc.), never by group membership." — source: ADR-0003 (D3.2)
- Required: "`validate()` returns a `PackedStringArray` of coded findings
  (`[V-CODE] message`); codes are stable contract, message prose may be reworded
  freely." — source: ADR-0003 (D3.4)
- Required: "`validate()` never pushes an error itself. It is a pure function; the
  caller (`LevelRoot`) iterates the result and `push_error()`s each finding."
  — source: ADR-0003
- Required: "One shared `count_buckets(level)` static primitive, used both by
  `validate()`'s `V-BUCKET-SUM` and by `LevelRoot` to seed `LevelState`."
  — source: ADR-0003 (D3.5)
- Required: "`class_name` is required on `Plant`, `Bucket`, `PropBody` — the type
  scan depends on it, making these declarations load-bearing for correctness."
  — source: ADR-0003
- Forbidden: "Never discover plants/buckets/props via `get_nodes_in_group()` inside
  `LevelValidation`" — `get_nodes_in_group()` is a `SceneTree` method and is
  unavailable on the CI path. — source: ADR-0003 (`group_based_level_discovery`)
- Forbidden: "Never use `Node.find_children()` with the default `owned = true` for
  level discovery" — it silently drops descendants without a valid `owner`.
  — source: ADR-0003 (`find_children_owned_default`)
- Forbidden: "`LevelValidation.validate()` must never return on the first breach."
  — source: ADR-0003 (`validation_first_failure_return`)
- Guardrail: One depth-first subtree walk per level load. Zero per-frame cost —
  `validate()` is never called from `_process` or `_physics_process`.

---

## Acceptance Criteria

*From ADR-0003 D3.2, D3.4, D3.5 and Validation Criterion 6, scoped to this story:*

- [ ] `src/scripts/level_validation.gd` exists, declaring `class_name LevelValidation
      extends RefCounted`, with the doc comment block from ADR-0003 §Key Interfaces
      (including the "do NOT substitute `Node.find_children()`" warning).
- [ ] All **seven** stable code constants are declared, in the manifest's order:
      `V_BUCKET_SUM`, `V_PLANT_MIN`, `V_OXY_CAP`, `V_GRAV_EXPORT`, `V_PROP_BUDGET`,
      `V_WIRING`, `V_BOUNDS`. The last three are declared now and consumed by later
      stories — this discharges the epic's "specified with its constant in place"
      condition for `V-PROP-BUDGET`.
- [ ] `static func validate(level: Node) -> PackedStringArray` exists and returns an
      empty array. It contains **no** rule logic yet — rules arrive in stories
      002-004 and 006.
- [ ] `static func count_buckets(level: Node) -> int` returns the number of `Bucket`
      instances anywhere in the subtree, at any depth.
- [ ] Discovery is a private hand-rolled recursive helper over `get_children()`,
      matching by `node is <Class>`. It carries an inline comment citing ADR-0003
      D3.2 and F3 so a future reader does not "simplify" it to `find_children()`.
- [ ] `validate()` pushes no errors, mutates nothing, and returns an equal result on
      a second call over the same tree (ADR-0003 Validation Criterion 6).
- [ ] Both `level_validation.gd` and its test file are warning-clean under the
      headless gdUnit4 run (F10). Run the documented command locally before calling
      this story done.
- [ ] `grep -n "is_debug_build" src/scripts/level_validation.gd` returns nothing
      (ADR-0003 Validation Criterion 3, D3.6).
- [ ] `grep -nE "^[^#]*(get_nodes_in_group|find_children)[[:space:]]*\(" src/scripts/level_validation.gd`
      returns nothing — i.e. no **call site**. *(Amended 2026-08-24: the grep was
      unscoped and required the bare identifiers to be absent, which AC-1 makes
      impossible — the ADR-0003 doc block AC-1 mandates contains the string
      `find_children` in its "do NOT substitute" warning, and D3.2/F3 require a
      rationale comment naming it. The intent of this check has always been "no
      call site", so it is scoped to one. `^[^#]*` is what does the scoping: it
      requires the identifier to appear before any `#` on the line, so a call in
      code matches and a mention in a comment does not. Note that requiring a
      following `(` alone is NOT sufficient — the rationale comments write
      `find_children()` and `get_nodes_in_group()` with parentheses. Verified
      2026-08-24 against the shipped file, and against a copy with two call
      sites injected, which the grep catches.)*

---

## Implementation Notes

*Derived from ADR-0003 D3.2, D3.4, D3.5:*

Discovery matches by class identity, not by group membership, for two reasons and
the second is decisive. A node an author forgot to add to a group is **invisible to
validation**, so the level reports clean and ships unwinnable — the precise failure
this system exists to close, reintroduced inside the mechanism meant to close it.
And technically, `get_nodes_in_group()` is a method on `SceneTree`, not on `Node`;
the CI path instantiates a level and never adds it to a tree, so `get_tree()`
returns `null` and group lookup is not merely risky there, it is unavailable.

`class_name Plant` and `class_name Bucket` already exist in `src/scripts/`. No
`PropBody` exists yet — it is created under ADR-0011 and consumed by story 006.
Write the recursion generically enough that adding a third matched type is one call
site, but do not add a `PropBody` branch that will not compile.

Keep `count_buckets()` as the single definition of "a bucket in this level".
`LevelRoot` will seed `LevelState(buckets_total)` from it in story 005. Without one
shared primitive, `V-BUCKET-SUM` could pass while `LevelRoot` seeded `buckets_total`
from a subtly different count — a validation pass certifying a value the game does
not actually use.

Codes are contract; message prose is not. Tests assert on the bracketed code so
message wording can be improved freely without breaking a test.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `V-BUCKET-SUM` and `V-PLANT-MIN`, and the `Plant.buckets_required`
  export.
- **Story 003**: `V-OXY-CAP` and `V-GRAV-EXPORT`.
- **Story 004**: `V-WIRING` and its required-consumer table.
- **Story 005**: the `LevelRoot._ready()` call site and the `push_error` loop.
- **Story 006**: `V-PROP-BUDGET` and `V-BOUNDS` bodies.
- **The level migration epic**: the suite-wide CI test over all 8 level scenes.
  ADR-0003 D3.7 defers it there deliberately — it is RED until the migration
  completes, and the coding standards forbid landing a skipped or failing test.

---

## QA Test Cases

*Derived from ADR-0003 Validation Criteria 3 and 6, and D3.2/D3.5. The developer
implements against these — do not invent new test cases during implementation.*

**Test file**: `tests/unit/level/level_validation_scaffold_test.gd`

- **AC-1**: `count_buckets()` finds buckets at any depth
  - Given: a synthetic `Node` tree with one `Bucket` as a direct child, one nested
    three levels deep, and one non-`Bucket` sibling
  - When: `LevelValidation.count_buckets(root)` is called
  - Then: it returns `2`
  - Edge cases: a tree with zero buckets returns `0`; a tree that is a single
    childless node returns `0`; a `Bucket` passed in as the root itself — decide
    and assert one way, recommended that the root is scanned too

- **AC-2**: discovery is not `owner`-filtered
  - Given: a synthetic tree containing a `Bucket` whose `owner` is `null` (the
    default for a node created with `Bucket.new()` and never saved into a scene)
  - When: `count_buckets(root)` is called
  - Then: that bucket **is** counted
  - Edge cases: this is the `find_children(owned = true)` regression guard — the
    test must fail if someone substitutes the built-in with its default parameter

- **AC-3**: `validate()` is pure and idempotent (Validation Criterion 6)
  - Given: any synthetic tree
  - When: `validate(tree)` is called twice
  - Then: the two results are equal, and the tree's child count and node names are
    unchanged between calls
  - Edge cases: assert on an empty tree and on a populated one

- **AC-4**: `validate()` returns empty on a tree with nothing to check
  - Given: a bare `Node` with no children
  - When: `validate()` is called
  - Then: the returned `PackedStringArray` is empty
  - Edge cases: none — this is the baseline that later stories build on

- **AC-5**: all seven codes are declared and distinct
  - Given: the `LevelValidation` class
  - When: the seven constants are read
  - Then: each is a non-empty `String`, and all seven are unique
  - Edge cases: assert the exact literal values (`"V-BUCKET-SUM"` and the rest) —
    these are contract, and a typo here silently breaks every downstream assertion

- **AC-6**: grep guards — run as shell checks, recorded in the story rather than as
  gdUnit4 cases
  - Setup: from the repository root
  - Verify: `grep -nE "^[^#]*(is_debug_build|get_nodes_in_group|find_children)[[:space:]]*\(" src/scripts/level_validation.gd`
  - Pass condition: no output — the check is for a **call site**, not for the
    identifier. The identifiers appear in the doc block and rationale comments
    that AC-1 and D3.2/F3 require, parentheses included, so the `^[^#]*` prefix
    is what makes the check meaningful (amended 2026-08-24).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level/level_validation_scaffold_test.gd` — must
exist and pass under the headless gdUnit4 run:

```bash
".../Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests/unit
```

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None. `class_name Plant` and `class_name Bucket` already exist.
- Unlocks: Stories 002, 003, 004, 006 — every rule story builds on this scaffold.
