# FramePriority contract suite (story LS-003; ADR-0005 D5.1, F1, F3, A5-05).
#
# Two things in here are load-bearing and must not be weakened:
#
#   Every structural / source-text guard is exercised against a SYNTHETIC
#   POSITIVE as well as against the real repository. A guard that only ever runs
#   against a clean repo passes vacuously and proves nothing. The question each
#   matcher must answer is not "does the repo look clean" but "what would the
#   realistic violation actually LOOK like, and would this catch THAT".
#
#   The AC-1 ordering assertion is paired with a mis-ordered local fixture. A
#   test that would still be green with all three constants set to the same
#   value is not testing an ordering, and an ordering is this story's entire
#   subject (QA-plan addendum, 2026-08-25).
#
# Note on AC-5, correcting the story text: `process_physics_priority` does NOT
# contain `process_priority` as a literal substring -- "process_" is followed by
# "physics_", not by "priority". The real trap is one step broader: a matcher on
# `priority` or `_priority`, which is what a naive grep reaches for, DOES flag
# the correct spelling and turns the guard permanently red.
# `_process_priority_offenders()` is written against that hazard and is proved
# in both directions below.
extends GdUnitTestSuite

const FRAME_PRIORITY_SCRIPT_PATH: String = "res://src/scripts/frame_priority.gd"
const LEVEL_SCENE_PATH: String = "res://src/scenes/levels/level_01.tscn"
const SRC_ROOT: String = "res://src"

# Anti-vacuous-pass floors. Every scan below walks the filesystem, and a scan
# that finds no files to read passes silently green.
const MIN_SRC_SCRIPTS: int = 20
const MIN_SRC_SCENES: int = 15
const MIN_GLOBAL_CLASSES: int = 3


# -- helpers ------------------------------------------------------------------

# Reads a constant from a STATIC context: no instance, no node and no tree can
# be involved in the resolution. Mirrors the ADR-0003 LevelValidation shape.
static func _read_gravity_statically() -> int:
	return FramePriority.GRAVITY


static func _read_player_statically() -> int:
	return FramePriority.PLAYER


static func _read_oxygen_statically() -> int:
	return FramePriority.OXYGEN


# The requirement AC-1 actually states. Strict, so an all-equal triple is false.
func _is_strictly_ascending(first: int, second: int, third: int) -> bool:
	return first < second and second < third


func _regex(pattern: String) -> RegEx:
	var compiled: RegEx = RegEx.new()
	compiled.compile(pattern)
	return compiled


func _text_of(path: String) -> String:
	return FileAccess.get_file_as_string(path)


# Source with comment-only lines stripped, so a rule quoted in a doc comment
# cannot satisfy or break a source scan. frame_priority.gd's own doc comment
# names `process_priority` several times; without this it would self-report.
func _code_of(script_path: String) -> String:
	var code: PackedStringArray = PackedStringArray()
	for line: String in _text_of(script_path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)


func _files_under(directory: String, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry_name: String in DirAccess.get_directories_at(directory):
		found.append_array(_files_under(directory.path_join(entry_name), suffix))
	for entry_name: String in DirAccess.get_files_at(directory):
		if entry_name.ends_with(suffix):
			found.append(directory.path_join(entry_name))
	return found


# THE AC-5 MATCHER. Returns every line that assigns the `_process`-ordering
# property. Narrow at the identifier boundary so the physics spelling cannot be
# reached, and wide on the assignment forms a real author would write: bare,
# `self.`-qualified, member-qualified, and the reflective `set("...")` route.
func _process_priority_offenders(text: String) -> PackedStringArray:
	var pattern: RegEx = _regex(
		"(?:^|[^A-Za-z0-9_])process_priority\\s*="
		+ "|set\\(\\s*&?\"process_priority\"")
	var offenders: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if pattern.search(line) != null:
			offenders.append(line.strip_edges())
	return offenders


# THE AC-4 MATCHER. A `.tscn` property line is an unqualified assignment at the
# start of a line, which is what separates an inspector-authored value from a
# mention inside a resource path or a string.
func _inspector_physics_priority_offenders(text: String) -> PackedStringArray:
	var pattern: RegEx = _regex("^\\s*process_physics_priority\\s*=")
	var offenders: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if pattern.search(line) != null:
			offenders.append(line.strip_edges())
	return offenders


func _autoload_setting_names() -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = String(property["name"])
		if setting_name.begins_with("autoload/"):
			names.append(setting_name)
	return names


func _global_class_entry(class_id: String) -> Dictionary:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) == class_id:
			return entry
	return {}


# -- group 1 -- AC-1, the three values and the ordering they encode -----------

func test_gravity_priority_is_negative_one_hundred() -> void:
	assert_int(FramePriority.GRAVITY).is_equal(-100)


func test_player_priority_is_zero() -> void:
	assert_int(FramePriority.PLAYER).is_equal(0)


func test_oxygen_priority_is_positive_one_hundred() -> void:
	assert_int(FramePriority.OXYGEN).is_equal(100)


func test_priorities_are_strictly_ascending() -> void:
	# The three values above are three numbers. THIS is the requirement: gravity
	# settles the vector, the player moves through it, oxygen judges the result.
	# Only the relative order is load-bearing.
	var message: String = (
		"GRAVITY < PLAYER < OXYGEN is violated: %d, %d, %d. The frame chain no "
		+ "longer runs gravity -> movement -> death check (ADR-0005 D5.1)."
	) % [FramePriority.GRAVITY, FramePriority.PLAYER, FramePriority.OXYGEN]
	assert_bool(_is_strictly_ascending(
			FramePriority.GRAVITY, FramePriority.PLAYER, FramePriority.OXYGEN)) \
		.override_failure_message(message) \
		.is_true()


func test_ordering_predicate_rejects_a_mis_ordered_fixture() -> void:
	# QA-plan addendum, 2026-08-25. Without this, the assertion above stays green
	# for a predicate that returns true unconditionally, and green for a constant
	# table whose three values are identical.
	assert_bool(_is_strictly_ascending(100, 0, -100)) \
		.override_failure_message(
			"The ordering predicate accepted a fully reversed triple, so the "
			+ "AC-1 ordering assertion proves nothing.") \
		.is_false()
	assert_bool(_is_strictly_ascending(-100, 100, 0)) \
		.override_failure_message(
			"The ordering predicate accepted a triple with only the last two "
			+ "swapped.") \
		.is_false()
	assert_bool(_is_strictly_ascending(0, 0, 0)) \
		.override_failure_message(
			"The ordering predicate accepted an all-equal triple. Equal "
			+ "priorities order NOTHING -- the tie-break falls to tree position.") \
		.is_false()


# -- group 2 -- AC-2, reach without a SceneTree -------------------------------

func test_constants_resolve_from_a_static_call_with_a_null_scene_tree() -> void:
	var packed: PackedScene = load(LEVEL_SCENE_PATH)
	assert_object(packed) \
		.override_failure_message("Could not load %s." % LEVEL_SCENE_PATH) \
		.is_not_null()

	var instance: Node = packed.instantiate()
	# auto_free registers the instance for teardown, so the orphan gdUnit4 would
	# otherwise report does not leak out of this test.
	auto_free(instance)

	# PRECONDITION, not scaffolding. Without it this test proves nothing -- it
	# would pass identically from an ordinary test method with a live tree.
	assert_object(instance.get_tree()) \
		.override_failure_message(
			"The instantiated level already has a SceneTree, so this test "
			+ "cannot prove null-tree resolution. It must never be added.") \
		.is_null()

	assert_int(_read_gravity_statically()).is_equal(-100)
	assert_int(_read_player_statically()).is_equal(0)
	assert_int(_read_oxygen_statically()).is_equal(100)


func test_frame_priority_is_registered_as_a_global_class() -> void:
	# This is the MECHANISM behind the test above, asserted directly. A
	# class_name resolves at SCRIPT LOAD, independent of the tree, which is what
	# lets GravityAuthority (autoload, pre-level) and a level-scene node reach
	# one source by one mechanism. A LevelRoot-hosted constant cannot (A5-05).
	var classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	assert_int(classes.size()) \
		.override_failure_message(
			"The global class list is empty or near-empty, so this scan "
			+ "cannot prove anything about FramePriority.") \
		.is_greater_equal(MIN_GLOBAL_CLASSES)

	assert_dict(_global_class_entry("FramePriority")) \
		.override_failure_message(
			"FramePriority is not in the global class list. Without a "
			+ "class_name it is reachable only by path, and A5-05's "
			+ "one-shared-mechanism requirement is unmet.") \
		.is_not_empty()


func test_frame_priority_is_declared_on_its_own_script_not_on_level_root() -> void:
	# The placement decision itself, asserted. A5-05 forbids hosting these
	# constants on LevelRoot: GravityAuthority exists before any level scene
	# loads and cannot source a constant from a per-level scene script.
	var entry: Dictionary = _global_class_entry("FramePriority")
	assert_dict(entry).is_not_empty()

	var declared_path: String = String(entry.get("path", ""))
	var message: String = (
		"FramePriority is declared at '%s', not '%s'. If it has moved onto a "
		+ "level or scene script, A5-05 is breached."
	) % [declared_path, FRAME_PRIORITY_SCRIPT_PATH]
	assert_str(declared_path) \
		.override_failure_message(message) \
		.is_equal(FRAME_PRIORITY_SCRIPT_PATH)


# -- group 3 -- AC-3, const-only and not an autoload --------------------------

func test_frame_priority_holds_exactly_three_constants() -> void:
	var script: GDScript = load(FRAME_PRIORITY_SCRIPT_PATH)
	var constant_names: Array = script.get_script_constant_map().keys()
	# A fourth constant added later must fail this test -- that is the point.
	# ADR-0005 gives Goal no row: it resolves at the physics-query phase, which
	# is a different point in the frame, not a different priority.
	assert_array(constant_names) \
		.override_failure_message(
			"FramePriority must declare exactly GRAVITY, PLAYER and OXYGEN. "
			+ "Found: %s" % [constant_names]) \
		.contains_exactly_in_any_order(["GRAVITY", "PLAYER", "OXYGEN"])


func test_frame_priority_declares_no_behaviour() -> void:
	var script: GDScript = load(FRAME_PRIORITY_SCRIPT_PATH)
	var declared: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = String(method["name"])
		# Compiler-generated entries are prefixed with @.
		if not method_name.begins_with("@"):
			declared.append(method_name)
	assert_array(declared) \
		.override_failure_message(
			"FramePriority must hold constants and nothing else -- no methods, "
			+ "no _ready, and no static func helper. AC-2 settles the AC-3 edge "
			+ "case: a helper is NOT permitted. Found: %s" % [declared]) \
		.is_empty()
	assert_array(script.get_script_signal_list()) \
		.override_failure_message("FramePriority declares a signal.") \
		.is_empty()


func test_frame_priority_declares_no_variables() -> void:
	var script: GDScript = load(FRAME_PRIORITY_SCRIPT_PATH)
	var variables: Array[String] = []
	for property: Dictionary in script.get_script_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			variables.append(String(property["name"]))
	assert_array(variables) \
		.override_failure_message(
			"FramePriority declares a variable. A var is mutable, and a "
			+ "mutable ordering table is a drift surface. Found: %s" % [variables]) \
		.is_empty()


func test_frame_priority_is_not_registered_as_an_autoload() -> void:
	# class_name already gives FramePriority universal reach with no tree
	# dependency. Registering it would hand it exactly the dependency A5-05
	# exists to avoid.
	for setting_name: String in _autoload_setting_names():
		var value: String = String(ProjectSettings.get_setting(setting_name, ""))
		# An entry disabled with a leading * still counts as present, so match on
		# the value as well as the key.
		assert_bool(setting_name == "autoload/FramePriority") \
			.override_failure_message(
				"FramePriority is registered as an autoload (%s)." % setting_name) \
			.is_false()
		assert_bool(value.contains("frame_priority.gd")) \
			.override_failure_message(
				"An autoload (%s) points at frame_priority.gd." % setting_name) \
			.is_false()


# -- group 4 -- AC-4, no scene sets the priority in the inspector -------------

func test_no_scene_sets_process_physics_priority_in_the_inspector() -> void:
	var scenes: PackedStringArray = _files_under(SRC_ROOT, ".tscn")
	assert_int(scenes.size()) \
		.override_failure_message(
			"Found %d scenes under %s. The scan has nothing to read and would "
			% [scenes.size(), SRC_ROOT] + "pass vacuously.") \
		.is_greater_equal(MIN_SRC_SCENES)

	var offenders: PackedStringArray = PackedStringArray()
	for path: String in scenes:
		for line: String in _inspector_physics_priority_offenders(_text_of(path)):
			offenders.append("%s: %s" % [path, line])
	assert_array(offenders) \
		.override_failure_message(
			"A scene authors process_physics_priority in the inspector "
			+ "(ADR-0005 D5.1). Assign it in _ready() from FramePriority "
			+ "instead -- eight level scenes are eight chances to drift. "
			+ "Offenders: %s" % [offenders]) \
		.is_empty()


func test_inspector_matcher_flags_a_synthetic_scene_violation() -> void:
	# Without this, the test above is equally green against a matcher that never
	# matches anything at all.
	var violating_scene: String = (
		"[node name=\"OxygenDrain\" type=\"Node2D\"]\n"
		+ "process_physics_priority = 100\n"
		+ "script = ExtResource(\"1_oxy\")\n")
	assert_array(_inspector_physics_priority_offenders(violating_scene)) \
		.override_failure_message(
			"The AC-4 matcher did not flag an inspector-authored "
			+ "process_physics_priority. It cannot detect the real defect.") \
		.has_size(1)

	# And it must not fire on the neighbouring property or on a path mention.
	var clean_scene: String = (
		"[node name=\"Hud\" type=\"CanvasLayer\"]\n"
		+ "process_priority = 5\n"
		+ "script = ExtResource(\"res://src/scripts/frame_priority.gd\")\n")
	assert_array(_inspector_physics_priority_offenders(clean_scene)) \
		.override_failure_message(
			"The AC-4 matcher fired on a line that does not author "
			+ "process_physics_priority.") \
		.is_empty()


# -- group 5 -- AC-5, no process_priority ordering a physics callback ---------

func test_no_physics_process_script_orders_with_process_priority() -> void:
	var scripts: PackedStringArray = _files_under(SRC_ROOT, ".gd")
	assert_int(scripts.size()) \
		.override_failure_message(
			"Found %d scripts under %s. The scan has nothing to read and would "
			% [scripts.size(), SRC_ROOT] + "pass vacuously.") \
		.is_greater_equal(MIN_SRC_SCRIPTS)

	var offenders: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		var code: String = _code_of(path)
		# AC-5 permits process_priority on a node that genuinely orders
		# _process. The breach is using it where a _physics_process callback is
		# what needs ordering, so the physics callback is the qualifier.
		if not code.contains("func _physics_process"):
			continue
		for line: String in _process_priority_offenders(code):
			offenders.append("%s: %s" % [path, line])
	assert_array(offenders) \
		.override_failure_message(
			"A script with a _physics_process callback assigns "
			+ "process_priority. That property orders _process only -- it "
			+ "orders the physics callback NOTHING, with no compile error and "
			+ "no runtime error (ADR-0005 F1). Use process_physics_priority. "
			+ "Offenders: %s" % [offenders]) \
		.is_empty()


func test_process_priority_matcher_flags_synthetic_violations() -> void:
	# The spellings a real author would write, not a token nobody types.
	var violations: PackedStringArray = PackedStringArray([
		"\tprocess_priority = -100",
		"\tprocess_priority=-100",
		"\tself.process_priority = FramePriority.GRAVITY",
		"\t_drain.process_priority = 100",
		"\tset(\"process_priority\", 0)",
		"\tset(&\"process_priority\", 0)",
	])
	for line: String in violations:
		assert_array(_process_priority_offenders(line)) \
			.override_failure_message(
				"The AC-5 matcher missed a realistic violation: %s" % [line]) \
			.has_size(1)


func test_process_priority_matcher_ignores_the_physics_spelling() -> void:
	# The trap this matcher exists to survive. A naive scan for `priority` or
	# `_priority` reports every CORRECT assignment as a violation, which turns
	# the guard permanently red and gets it deleted.
	var correct: PackedStringArray = PackedStringArray([
		"\tprocess_physics_priority = FramePriority.GRAVITY",
		"\tprocess_physics_priority = FramePriority.PLAYER",
		"\tself.process_physics_priority = FramePriority.OXYGEN",
		"\tset(&\"process_physics_priority\", FramePriority.OXYGEN)",
	])
	for line: String in correct:
		assert_array(_process_priority_offenders(line)) \
			.override_failure_message(
				"The AC-5 matcher flagged a CORRECT assignment: %s" % [line]) \
			.is_empty()

	# And the real frame_priority.gd source, whose doc comment names the
	# forbidden property repeatedly, must survive the same scan once comment-only
	# lines are stripped.
	assert_array(_process_priority_offenders(_code_of(FRAME_PRIORITY_SCRIPT_PATH))) \
		.override_failure_message(
			"frame_priority.gd itself was flagged by the AC-5 matcher.") \
		.is_empty()
