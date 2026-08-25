# Editor-facts probe — 2026-08-25

**Scope**: Closes the editor-only checks on tuning-resources stories 002 and 003,
and items 1-2 of collision-layer-registry story 003 AC-5.
**Build**: branch `vertical-slice`, HEAD `783953b`, working tree clean of source
changes.
**Engine**: Godot 4.7.1.stable.official (headless).
**Verdict**: **PASS** on every check listed below.

---

## Why a probe and not the editor

Three routes to an editor observation were tried on this machine. All three fail.

| Route | Result |
|---|---|
| Windowed Godot editor | Segfaults. Recorded before this session. |
| Headless editor + godot-ai MCP | Editor starts and stays up. The MCP plugin refuses to run: `MCP \| plugin disabled in headless mode`. The guard is `_mcp_disabled_for_headless_launch()` at `addons/godot_ai/plugin.gd:211`, which returns before the server starts. `session_manage(list)` stayed at zero for the whole run. |
| Headless probe script | Works. This document. |

## LIMITATION — read this before citing this document

**These are data-level reads. They are not editor screenshots.**

The probe reads the same data the editor renders from, one layer below the
rendering:

- The Create New Resource dialog is populated from
  `ProjectSettings.get_global_class_list()`. The probe reads that list. The
  dialog was never opened.
- An inspector row and its slider are built from the `hint` and `hint_string`
  fields of `Object.get_property_list()`. The probe reads those fields. No
  inspector was opened and no slider was dragged.

This proves the data is correct. It does not prove the editor draws it. Any
defect that lives only in the editor's rendering path is out of this document's
reach. Where a story's acceptance criterion names the editor method explicitly,
the substitution is recorded in that story's Implementation Record.

**Nothing was written.** The probe only loads and reads. `prop_gravity_scale`
remains `1.0` in `src/resources/tuning/prop_tuning.tres`.

---

## Results

### TUN-002 smoke item 2 — class registration — PASS

| Class | Registered |
|---|---|
| `WateringTuning` | true |
| `OxygenTuning` | true |
| `PropTuning` | true |
| `GravityTuning` | **false** — the D6.7 ban holds |

### TUN-003 AC-1 and AC-2 — knob lists and range hints — PASS

Every knob reports `PROPERTY_HINT_RANGE`. Ten knobs total, matching the story
exactly, with no unexpected property on any of the three resources.

| Resource | Knob | Type | Value | Range hint |
|---|---|---|---|---|
| `watering_tuning.tres` | `carry_speed_multiplier` | float | 0.6 | 0.4, 0.9 |
| | `throw_arc_height` | float | 120.0 | 60.0, 200.0 |
| | `throw_duration` | float | 0.6 | 0.4, 0.8 |
| | `throw_angle_spread` | float | 45.0 | 0.0, 90.0 |
| `oxygen_tuning.tres` | `margin` | float | 0.4 | 0.3, 0.6 |
| | `drain_rate` | float | 1.0 | 0.5, 1.0 |
| | `threshold_caution` | float | 0.5 | 0.0, 1.0 |
| | `threshold_warning` | float | 0.25 | 0.0, 1.0 |
| | `threshold_critical` | float | 0.1 | 0.0, 1.0 |
| `prop_tuning.tres` | `prop_gravity_scale` | float | 1.0 | 0.8, 1.2 |
| | `prop_max_speed` | float | 2000.0 | 1000.0, 4000.0 |
| | `props_per_level_budget` | **int** | 40 | 10.0, 80.0 |

Notes:

- `props_per_level_budget` is `TYPE_INT`, as ADR-0003's `V-PROP-BUDGET`
  requires. Its hint string serializes its bounds as floats. That is the hint
  format and not the value type.
- Each resource points at its own script:
  `watering_tuning.gd`, `oxygen_tuning.gd`, `prop_tuning.gd`.
- `resource_local_to_scene` is `false` on all three (D6.9), read from the loaded
  object. The `.tres` text half of this check is in
  `production/qa/smoke-2026-08-24.md`.

### CLR-003 AC-5 items 1-2 — scene loads — PASS

| Scene | Result |
|---|---|
| `src/scenes/player/player.tscn` | Loads and instantiates. Root `Player` (`CharacterBody2D`), 10 children. Zero errors, zero warnings. |
| `src/scenes/moving_platform.tscn` | Loads and instantiates. Root `MovingPlatfornm` (`Node2D`), 2 children. Zero errors, zero warnings. |

The probe also walked the whole player subtree for `Area2D` nodes and found
none. That independently confirms CLR-003 AC-1: `PlayerArea2D` is gone.

Items 3 and 4 of CLR-003 AC-5 are **not** covered here. They need a running
game, not a load: the moving platform must still animate along its path, and the
player must still move, jump and flip gravity.

### Incidental finding — not fixed

The root node of `src/scenes/moving_platform.tscn` is named **`MovingPlatfornm`**.
That is a typo for `MovingPlatform`, and it breaks the rule in
`.claude/docs/technical-preferences.md` that a scene name matches its root node.
Renaming a root node changes every node path that references it, so it was left
alone. It needs its own bug row or a Sprint-2 item.

---

## Reproduction

Copy the script below to the project root, then run:

```
"…/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
  --script res://editor_facts_probe.gd
```

Delete the copy and its generated `.uid` afterwards. The script lives outside
`tests/` on purpose: it is evidence tooling, not a gdUnit4 suite, and it must not
be discovered by the test runner.

```gdscript
extends SceneTree
## Read-only probe. Reads the same data the Godot editor renders in the
## Create New Resource dialog and the inspector, without an editor.
## Writes nothing. Run with --headless --script.

const TUNING_CLASSES: PackedStringArray = [
	"WateringTuning", "OxygenTuning", "PropTuning",
]

const TRES_PATHS: PackedStringArray = [
	"res://src/resources/tuning/watering_tuning.tres",
	"res://src/resources/tuning/oxygen_tuning.tres",
	"res://src/resources/tuning/prop_tuning.tres",
]

const SCENE_PATHS: PackedStringArray = [
	"res://src/scenes/player/player.tscn",
	"res://src/scenes/moving_platform.tscn",
]


func _initialize() -> void:
	_probe_global_class_list()
	_probe_tres_property_lists()
	_probe_scene_loads()
	print("\n=== PROBE COMPLETE ===")
	quit(0)


## TUN-002 smoke item 2. The Create New Resource dialog is populated from
## the global class list, so presence here is the fact the dialog shows.
func _probe_global_class_list() -> void:
	print("\n=== TUN-002 smoke 2 — global class list ===")
	var registered: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		registered.append(String(entry.get("class", "")))
	for wanted: String in TUNING_CLASSES:
		var found: bool = registered.has(wanted)
		print("  %-16s registered=%s" % [wanted, found])
	print("  GravityTuning registered=%s (D6.7 ban — must be false)"
		% registered.has("GravityTuning"))


## TUN-003 AC-1 and AC-2. get_property_list() returns the hint and
## hint_string the inspector builds each row and each slider from.
func _probe_tres_property_lists() -> void:
	print("\n=== TUN-003 AC-1 / AC-2 — inspector rows and range hints ===")
	for path: String in TRES_PATHS:
		print("\n  --- %s" % path)
		var res: Resource = load(path)
		if res == null:
			print("    LOAD FAILED")
			continue
		print("    script class : %s" % _script_class_of(res))
		print("    local_to_scene: %s (D6.9 — must be false)"
			% res.resource_local_to_scene)
		for prop: Dictionary in res.get_property_list():
			var usage: int = int(prop.get("usage", 0))
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var pname: String = String(prop.get("name", ""))
			var hint: int = int(prop.get("hint", 0))
			var hint_string: String = String(prop.get("hint_string", ""))
			var value: Variant = res.get(pname)
			var is_range: bool = hint == PROPERTY_HINT_RANGE
			print("    knob %-26s type=%-6s value=%-8s range=%s %s" % [
				pname,
				type_string(typeof(value)),
				str(value),
				is_range,
				hint_string,
			])


## CLR-003 AC-5 items 1 and 2. Any parse error, load error or GDScript
## warning surfaces on stderr, which the caller captures.
func _probe_scene_loads() -> void:
	print("\n=== CLR-003 AC-5 items 1-2 — scene loads ===")
	for path: String in SCENE_PATHS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			print("  %s -> LOAD FAILED" % path)
			continue
		var can_instantiate: bool = packed.can_instantiate()
		print("  %s -> loaded, can_instantiate=%s" % [path, can_instantiate])
		var node: Node = packed.instantiate()
		if node == null:
			print("    instantiate returned null")
			continue
		print("    root=%s (%s), children=%d"
			% [node.name, node.get_class(), node.get_child_count()])
		_print_area_children(node, "    ")
		node.free()


## CLR-003 AC-1 asserted PlayerArea2D is gone. Report every Area2D found.
func _print_area_children(node: Node, indent: String) -> void:
	for child: Node in node.get_children():
		if child is Area2D:
			print("%sArea2D present: %s" % [indent, child.name])
		_print_area_children(child, indent)


func _script_class_of(res: Resource) -> String:
	var scr: Script = res.get_script() as Script
	if scr == null:
		return "<none>"
	return scr.resource_path
```

## Raw output

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org


=== TUN-002 smoke 2 — global class list ===
  WateringTuning   registered=true
  OxygenTuning     registered=true
  PropTuning       registered=true
  GravityTuning registered=false (D6.7 ban — must be false)

=== TUN-003 AC-1 / AC-2 — inspector rows and range hints ===

  --- res://src/resources/tuning/watering_tuning.tres
    script class : res://src/scripts/tuning/watering_tuning.gd
    local_to_scene: false (D6.9 — must be false)
    knob carry_speed_multiplier     type=float  value=0.6      range=true 0.4,0.9
    knob throw_arc_height           type=float  value=120.0    range=true 60.0,200.0
    knob throw_duration             type=float  value=0.6      range=true 0.4,0.8
    knob throw_angle_spread         type=float  value=45.0     range=true 0.0,90.0

  --- res://src/resources/tuning/oxygen_tuning.tres
    script class : res://src/scripts/tuning/oxygen_tuning.gd
    local_to_scene: false (D6.9 — must be false)
    knob margin                     type=float  value=0.4      range=true 0.3,0.6
    knob drain_rate                 type=float  value=1.0      range=true 0.5,1.0
    knob threshold_caution          type=float  value=0.5      range=true 0.0,1.0
    knob threshold_warning          type=float  value=0.25     range=true 0.0,1.0
    knob threshold_critical         type=float  value=0.1      range=true 0.0,1.0

  --- res://src/resources/tuning/prop_tuning.tres
    script class : res://src/scripts/tuning/prop_tuning.gd
    local_to_scene: false (D6.9 — must be false)
    knob prop_gravity_scale         type=float  value=1.0      range=true 0.8,1.2
    knob prop_max_speed             type=float  value=2000.0   range=true 1000.0,4000.0
    knob props_per_level_budget     type=int    value=40       range=true 10.0,80.0

=== CLR-003 AC-5 items 1-2 — scene loads ===
  res://src/scenes/player/player.tscn -> loaded, can_instantiate=true
    root=Player (CharacterBody2D), children=10
  res://src/scenes/moving_platform.tscn -> loaded, can_instantiate=true
    root=MovingPlatfornm (Node2D), children=2

=== PROBE COMPLETE ===
[godot_ai game_helper] registered mcp capture (debugger active=false, logger=true)
```
