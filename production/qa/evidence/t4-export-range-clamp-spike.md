# T4 Spike — Does `@export_range` Clamp a Hand-Edited `.tres`?

> **Story**: `production/epics/tuning-resources/story-001-t4-export-range-clamp-spike.md`
> **Task**: Sprint 1, TUN-1
> **ADR**: ADR-0006 — Tuning resource strategy, engine fact **T4**
> **Date executed**: 2026-08-24
> **Type**: Integration — documented spike. This is not a committed test.

## Verdict

**T4 is VERIFIED TRUE — executed.** `@export_range` does not clamp a value and
does not reject a value that a person types into a `.tres` by hand. The
out-of-range value survives intact into the loaded resource. `@export_range` is
an authoring-time constraint only. D6.4 keeps its stance, and the failure mode
that D6.4 describes is correct.

**One new finding, outside the T4 question**: the editor load path and the game
load path do not agree when the authored value has the *wrong type*. Numeric
out-of-range values agree on both paths. See "Finding N1" below.

## Binary

```
4.7.1.stable.official.a13da4feb
```

Full version info reported by the running engine:

```
{ "major": 4, "minor": 7, "patch": 1, "hex": 263937, "status": "stable",
  "build": "official", "hash": "a13da4feb8d8aefc283c3763d33a2f170a18d541",
  "string": "4.7.1-stable (official)" }
```

Binary path:
`C:\00_repos\00-Godot-installer\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`

## Method

An isolated throwaway project was built outside the repository, in the session
scratchpad. The project is not committed. This document is the deliverable.

The project holds one `Resource` subclass, nine hand-written `.tres` files, and
two probes. No `.tres` file was ever opened in the editor. Every `.tres` file
was written by a text editor.

### Resource script — `t4_probe.gd`

```gdscript
class_name T4Probe
extends Resource

@export_range(0.8, 1.2) var prop_gravity_scale: float = 1.0
@export_range(10, 80) var props_per_level_budget: int = 40
```

### Case file format — `case_01.tres`

```
[gd_resource type="Resource" script_class="T4Probe" load_steps=2 format=3]

[ext_resource type="Script" path="res://t4_probe.gd" id="1"]

[resource]
script = ExtResource("1")
prop_gravity_scale = 1.9
props_per_level_budget = 500
```

The other eight files are identical except for the two authored values.

### Probe

Both probes call the same function. The function loads each `.tres` with
`ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`, reads the two
properties, and records the value and the runtime type.

1. **Game path** — `godot --headless --path . -s headless_runner.gd`. The script
   extends `SceneTree`. This is the runtime load path.
2. **Editor path** — an `EditorPlugin` under `addons/t4/`, enabled in
   `project.godot`, run by `godot --headless --path . -e --quit-after 900`. The
   plugin probes twice: once in `_enter_tree`, and once again 5 seconds later.
   Both editor probes returned identical values, so editor startup order does
   not affect the result.

## Observed values

Defaults are `prop_gravity_scale = 1.0` and `props_per_level_budget = 40`.
"Survives" means the loaded value equals the authored value.

| Case | Authored float | Game path | Editor path | Authored int | Game path | Editor path |
|---|---|---|---|---|---|---|
| 01 | `1.9` (above range) | `1.9` | `1.9` | `500` (above range) | `500` | `500` |
| 02 | `1.2` (upper bound) | `1.2` | `1.2` | `80` (upper bound) | `80` | `80` |
| 03 | `1.2000001` (just above) | `1.2000001` | `1.2000001` | `81` (just above) | `81` | `81` |
| 04 | `0.1` (below range) | `0.1` | `0.1` | `0` (below range) | `0` | `0` |
| 05 | `-1.0` (negative) | `-1.0` | `-1.0` | `-5` (negative) | `-5` | `-5` |
| 06 | `"abc"` (string) | `0.0` | `1.0` | `40` | `40` | `40` |
| 07 | `1.0` | `1.0` | `1.0` | `40.7` (float) | `40` | `40.7` |
| 08 | `2.5` | `2.5` | `2.5` | `55.7` (float) | `55` | `55.7` |
| 09 | `1.0` | `1.0` | `1.0` | `"abc"` (string) | `0` | `40` |

### Answers to the three questions in the story

1. **Does loading clamp the value to the range bound?** No. Observed on cases
   01, 03, 04 and 05, on both paths.
2. **Does loading reject the file, error, or fall back to the default?** No. The
   load returned a valid resource for every case. No error and no warning was
   printed for any numeric case.
3. **Does the out-of-range value survive intact?** Yes. Observed on cases 01,
   03, 04 and 05, on both paths.

Neither path rewrote any `.tres` file. All nine files kept their authored bytes
after both runs.

## Finding N1 — the two paths disagree on a wrong-type value

This is outside the T4 question, and it is recorded because AC-3 of the story
asks for it.

For a value of the **declared type**, the two paths agree exactly. Cases 01 to
05 are identical on both paths.

For a value of the **wrong type**, the two paths differ:

| Authored | Game path | Editor path |
|---|---|---|
| A string in a `float` knob (case 06) | `0.0` | `1.0` — the default |
| A float in an `int` knob (cases 07, 08) | truncated to `int` — `40`, `55` | kept as `float` — `40.7`, `55.7` |
| A string in an `int` knob (case 09) | `0` | `40` — the default |

Two consequences for this project:

- On the game path, a wrong-type value becomes `0` or `0.0`. It does not fall
  back to the declared default. A typo of that shape gives the knob a zero
  value, not the safe value.
- On the editor path, a property declared `int` can hold a `float`. Code that
  reads a tuning knob in a `@tool` script must not assume the runtime type
  matches the declaration.

The mechanism was not investigated. The values above are observed, not
explained.

## Limitation — the editor run had no window

The editor path was run with `--headless`. It is a real editor process with a
real `EditorPlugin`, and it uses the editor load path. It has no window.

A windowed editor run was attempted three times and crashed each time, at
`drivers/gles3/shader_gles3.cpp:802`, before any project code ran. The crash is
an environment problem with the GL compatibility driver on this machine's Intel
GPU. It is not a project problem.

The display driver is not part of the resource load path, so this limitation
does not put the verdict in doubt. A person who wants the windowed observation
can open the isolated project, enable the plugin, and read
`res://result_editor.txt`.

## Effect on ADR-0006

- **T4's verdict changes** from "VERIFIED TRUE — documentation only, not
  executed" to "VERIFIED TRUE — executed 2026-08-24 against 4.7.1-stable".
- **D6.4 does not change.** Its stance and its closing paragraph are correct as
  written.
- **The T4 risk closes.** The Risks entry and the "T4 remains open in practice"
  note can both be removed.
- **Story 002 keeps its assumption.** Treat every `@export_range` as an
  inspector hint. Clamp in code if a knob must be clamped.
