# Test Infrastructure

**Engine**: Godot 4.7.1 (GL Compatibility)
**Test Framework**: GdUnit4 6.2.1
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-08-13

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system tests (gravity + movement, watering, etc.)
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

### From the editor
1. Open the GdUnit4 dock (bottom panel).
2. Select `tests/unit` or `tests/integration` and press run.

### From the command line (headless)
```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
      --ignoreHeadlessMode \
      -a res://tests/unit \
      -a res://tests/integration
```

`--ignoreHeadlessMode` is required. GdUnit4 refuses to run headless without it
(exit 103), because `InputEvent` is not delivered in headless mode. Our unit
tests are pure math and unaffected; any future test that drives input must run
in a real window instead.

**Working invocation on this machine** (verified 2026-08-24, 157/157 passing):
```bash
"/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -c \
  -a res://tests/unit \
  -a res://tests/integration
```

> **Both `-a` paths are required, and this was wrong until 2026-08-24.** The
> command previously documented here passed `res://tests/unit` only, which
> silently excluded `tests/integration/main/kill_area_death_test.gd` — 8 cases,
> and the regression guard for BUG-0001. Every "149/149 green" reported during
> Sprint 1 omitted them. With both paths the suite is 157/157. CI already passes
> both paths, so this affected local runs only.
>
> **`-c` is required for any run you intend to read.** Without it the runner
> stops at the first failing test and every later failure is hidden, so a red
> run reports one failure regardless of how many exist. Observed across five
> deliberate-failure runs on 2026-08-23.

Two gotchas in that path:
- `Godot_v4.7.1-stable_win64.exe` is a **directory** containing the real binary
  of the same name — the nested path is not a typo.
- Use the `_console.exe` variant. The plain `.exe` detaches from the console on
  Windows, so test output never reaches stdout.

Add `-c` to continue past the first failure, and `-rd <dir>` to override the
report output directory (default `res://reports/`).

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `gravity_vector_test.gd` → `test_flip_vertical_returns_inverted_vector()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

## Writing Your First Test

Create `tests/unit/gravity/gravity_vector_test.gd`:

```gdscript
extends GdUnitTestSuite

@warning_ignore("unused_parameter")
func test_get_gravity_vector_returns_normalized_direction_times_strength() -> void:
    # Example — adapt to the actual system under test
    assert_that(1 + 1).is_equal(2)
```

Run it from the GdUnit4 dock or the headless command above.
