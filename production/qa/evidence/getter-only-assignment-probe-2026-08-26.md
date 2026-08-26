# Probe: getter-only property assignment semantics — Godot 4.7.1

> **Date**: 2026-08-26
> **Binary**: `Godot_v4.7.1-stable_win64_console.exe` (v4.7.1.stable.official.a13da4feb)
> **Method**: read-only `--headless --path . -s <script>` probe. No project file was modified.
> **Raised by**: LS-001's assignment criterion — QA case **AC-4**, "the getter-only
> properties refuse assignment" — which instructs the developer to probe this before
> writing the assertion and to treat a mismatch as a finding, not a test to soften.
> **Status**: CONFIRMED — ADR-0002's A2-01 correction is factually wrong for 4.7.1.

## Question

ADR-0002 `adr-0002-level-state-ownership.md:246-248` states:

> Assignment to a getter-only property raises a runtime error, which is what makes
> the guarantees below properties of the type rather than rules to police.

Does assignment to a getter-only computed property actually raise in Godot 4.7.1?

## Result — NO. The write is silently ignored.

Probe target: a `RefCounted` with a getter-only `value: int` over `_value: int = 7`,
plus a plain read-write `flag: bool` as negative control.

| # | Shape | Parses? | Value after | Error raised? |
|---|---|---|---|---|
| B | `t.set("value", 99)` | n/a | 7 — unchanged | **none** |
| D | `o.value = 42` via `Variant`-typed parameter | yes | 7 — unchanged | **none** |
| F | `o.value = 42` via statically-typed parameter | yes | 7 — unchanged | **none** |
| G | `t.value = 55`, typed, same script, direct | yes | 7 — unchanged | **none** |
| E | `o.flag = true` (negative control) | yes | `true` — **assigned** | n/a |

### The error channel was proven live in the same run

Probe 3 performed the getter-only assignment at line 8 and an out-of-bounds array
read at line 13. Only the second produced output:

```
G_before value=7
G_after  value=7
H_control — the next line SHOULD raise, proving errors surface here
SCRIPT ERROR: Out of bounds get index '9' (on base: 'Array')
   at: _initialize (res://.probe_tmp/probe3.gd:13)
```

Line 8 emitted nothing. The silence is the finding, not a capture artefact.

## Interpretation

Split the ADR's claim in two:

- **Safety — HOLDS.** External code cannot corrupt the object. Every write was
  discarded and the backing field kept its value. The getter-only declaration is
  doing real work.
- **Detection — DOES NOT HOLD.** The write is discarded *silently*. A caller
  writing `level_state.goal_unlocked = true` gets a no-op with no diagnostic,
  which is precisely the failure mode A2-01 claimed getter-only properties remove.

So the type is still safe to build as specified. What is false is the ADR's stated
*reason* that the guarantee is self-enforcing: it is enforced, but it is not
observable at the call site.

## Consequences

1. **LS-001's assignment criterion (QA case AC-4) cannot be satisfied as written.**
   It requires assignment to
   "raise a runtime error rather than succeeding silently." 4.7.1 delivers neither
   a raise nor a success — it delivers a silent discard. The criterion is annotated in
   the story rather than reworded.
2. **The QA-plan addendum of 2026-08-25 is unsatisfiable on this point.** It
   requires asserting that external assignment "raises a runtime error, not merely
   that the value is unchanged." Against a correct implementation that assertion
   fails. The test asserts the observable truth instead — value unchanged, with
   `carrying_bucket` as the assignable negative control that proves the test can
   tell the two shapes apart.
3. **ADR-0002:246-248 is an erratum candidate.** Logged in
   `docs/tech-debt-register.md`. The ADR is Accepted and has NOT been amended.

## Second engine fact — `is Node` on a `RefCounted` type is a PARSE error

Found 2026-08-26 while implementing LS-001's AC-6 test. Asserting at runtime that
`LevelState` is not a `Node` cannot be written in the obvious shape:

```
Parse Error: Expression is of type "LevelState" so it can't be of type "Node".
```

This failed gdUnit4 discovery for the WHOLE run (`Abnormal exit with 105`) — the
compile-time, whole-suite failure mode the story's Engine Notes warn about.

The engine is giving a *stronger* guarantee than ADR-0002 asks for: with a statically
known type, "`LevelState` is not a `Node`" is unrepresentable to violate, so there is
nothing left for a runtime test to catch. It is simply not assertable in that form.
The working shape is `get_class() == "RefCounted"` plus
`ClassDB.is_parent_class(..., "Node") == false`.

## Incidental finding

`Object.set()` returns `void` in 4.7.1. Capturing its return value is itself a
script error:

```
SCRIPT ERROR: Trying to get a return value of a method that returns "void"
```

This corrects an earlier session note that described `set()` as returning `null`.

## Reproduction

Probe scripts were written to `.probe_tmp/` (untracked) and are disposable. The
shapes above are sufficient to reconstruct them: a `RefCounted` target with one
getter-only property and one plain `var`, plus assigner scripts typed three ways
and a control error in the same script body.
