# Tuning resource validation suite (ADR-0006 Validation Criteria V1-V4 and V9,
# Migration Plan step 5). ADR-0006 requires this suite green BEFORE any consumer
# depends on the tuning resources.
#
# Two assertions here are load-bearing and must not be weakened:
#
#   V1 (group 1) asserts TYPE IDENTITY, not non-null. Engine bug GH#73615 lets a
#   preload()ed resource resolve non-null yet be the wrong type, so a null check
#   reports green on exactly the defect V1 exists to catch.
#
#   V2 (group 2) asserts resolution with a GENUINELY NULL SceneTree. The test
#   instantiates a level scene via PackedScene.instantiate(), never adds it to
#   the tree, asserts get_tree() == null as a precondition, and only then reads
#   Tuning.PROP through a static call. Reading Tuning.PROP from an ordinary test
#   method proves nothing about the ADR-0003 LevelValidation path. T2 is the
#   verified basis: preload resolves when the SCRIPT loads, independent of the
#   tree. This is a DIFFERENT mechanism from ADR-0003 E1/E2 — do not conflate.
#
# Group 4 asserts typeof() alongside every value. That is not redundancy. The
# 2026-08-24 T4 spike found that a wrong-TYPE value authored into a .tres
# resolves at runtime as 0.0 for a float knob and truncates for an int knob —
# silently, with no error and no log. These .tres files were hand-authored, so
# the type assertions are the guard against the exact failure mode that vector
# produces (evidence: production/qa/evidence/t4-export-range-clamp-spike.md).
#
# NO TEST IN THIS FILE MAY ASSIGN TO A TUNING PROPERTY. The three resources are
# process-wide singletons by design (T3), so a single write would pollute every
# later test and would violate D6.5 from inside the suite meant to protect it.
extends GdUnitTestSuite

const TUNING_SCRIPT_PATH: String = "res://src/scripts/tuning/tuning.gd"
const LEVEL_SCENE_PATH: String = "res://src/scenes/levels/level_01.tscn"

# Float tolerance for the twelve authored defaults. The coding standards forbid
# non-deterministic tests and an exact == on 0.10 is a source of one.
const EPSILON: float = 0.0001

# Anti-vacuous-pass floor. Group 6 scans the global class list, and a scan that
# finds nothing passes silently.
const MIN_GLOBAL_CLASSES: int = 3


# ── helpers ──────────────────────────────────────────────────────────────────

# Reads Tuning.PROP from a STATIC context, mirroring the ADR-0003
# LevelValidation call shape. Static so no instance and no tree can be involved
# in the resolution.
static func _read_prop_statically() -> PropTuning:
	return Tuning.PROP


func _script_property_names(resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			names.append(String(property["name"]))
	return names


func _global_class_names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		names.append(String(entry["class"]))
	return names


func _autoload_setting_names() -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name := String(property["name"])
		if setting_name.begins_with("autoload/"):
			names.append(setting_name)
	return names


# ── group 1 — V1, type identity (the GH#73615 guard) ─────────────────────────

func test_watering_constant_is_watering_tuning_type() -> void:
	assert_bool(Tuning.WATERING is WateringTuning) \
		.override_failure_message(
			"Tuning.WATERING is not a WateringTuning. GH#73615 lets a preload " +
			"resolve non-null yet wrong-typed; a null check would pass here.") \
		.is_true()


func test_oxygen_constant_is_oxygen_tuning_type() -> void:
	assert_bool(Tuning.OXYGEN is OxygenTuning) \
		.override_failure_message("Tuning.OXYGEN is not an OxygenTuning.") \
		.is_true()


func test_prop_constant_is_prop_tuning_type() -> void:
	assert_bool(Tuning.PROP is PropTuning) \
		.override_failure_message("Tuning.PROP is not a PropTuning.") \
		.is_true()


# ── group 2 — V2, resolution with a null SceneTree (the ADR-0003 path) ───────

func test_tuning_resolves_from_static_call_with_null_scene_tree() -> void:
	var packed: PackedScene = load(LEVEL_SCENE_PATH)
	assert_object(packed) \
		.override_failure_message("Could not load %s." % LEVEL_SCENE_PATH) \
		.is_not_null()

	var instance: Node = packed.instantiate()
	# auto_free registers the instance for teardown, so the orphan gdUnit4 would
	# otherwise report does not leak out of this test.
	auto_free(instance)

	# PRECONDITION, not scaffolding. Without it this test proves nothing — it
	# would pass identically from an ordinary test method with a live tree.
	assert_object(instance.get_tree()) \
		.override_failure_message(
			"The instantiated level already has a SceneTree, so this test " +
			"cannot prove null-tree resolution. It must never be added to the tree.") \
		.is_null()

	var resolved: PropTuning = _read_prop_statically()
	assert_bool(resolved is PropTuning) \
		.override_failure_message(
			"Tuning.PROP failed to resolve to a PropTuning from a static call " +
			"while a null-tree level instance was alive (ADR-0006 V2 / T2).") \
		.is_true()


# ── group 3 — V3, cache identity (T3) ────────────────────────────────────────

func test_repeated_reads_return_the_same_prop_instance() -> void:
	var first: PropTuning = Tuning.PROP
	var second: PropTuning = Tuning.PROP
	# Object identity, not field equality. Comparing ten field values would pass
	# even if the cache had handed out two separate copies — the exact failure
	# D6.9 exists to prevent.
	assert_int(first.get_instance_id()).is_equal(second.get_instance_id())


func test_repeated_reads_return_the_same_oxygen_instance() -> void:
	var first: OxygenTuning = Tuning.OXYGEN
	var second: OxygenTuning = Tuning.OXYGEN
	assert_int(first.get_instance_id()).is_equal(second.get_instance_id())


func test_repeated_reads_return_the_same_watering_instance() -> void:
	var first: WateringTuning = Tuning.WATERING
	var second: WateringTuning = Tuning.WATERING
	assert_int(first.get_instance_id()).is_equal(second.get_instance_id())


# ── group 4 — V4, every authored default matches its GDD §7 default ──────────
#
# The exact number IS the point here, which is the documented exception to the
# no-hardcoded-data rule in the coding standards. Types are asserted alongside
# the values; see the file header for why.

func test_watering_defaults_match_gdd() -> void:
	assert_float(Tuning.WATERING.carry_speed_multiplier).is_equal_approx(0.6, EPSILON)
	assert_float(Tuning.WATERING.throw_arc_height).is_equal_approx(120.0, EPSILON)
	assert_float(Tuning.WATERING.throw_duration).is_equal_approx(0.6, EPSILON)
	assert_float(Tuning.WATERING.throw_angle_spread).is_equal_approx(45.0, EPSILON)


func test_watering_defaults_are_floats() -> void:
	assert_int(typeof(Tuning.WATERING.carry_speed_multiplier)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.WATERING.throw_arc_height)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.WATERING.throw_duration)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.WATERING.throw_angle_spread)).is_equal(TYPE_FLOAT)


func test_oxygen_defaults_match_gdd() -> void:
	assert_float(Tuning.OXYGEN.margin).is_equal_approx(0.4, EPSILON)
	assert_float(Tuning.OXYGEN.drain_rate).is_equal_approx(1.0, EPSILON)
	assert_float(Tuning.OXYGEN.threshold_caution).is_equal_approx(0.50, EPSILON)
	assert_float(Tuning.OXYGEN.threshold_warning).is_equal_approx(0.25, EPSILON)
	assert_float(Tuning.OXYGEN.threshold_critical).is_equal_approx(0.10, EPSILON)


func test_oxygen_defaults_are_floats() -> void:
	assert_int(typeof(Tuning.OXYGEN.margin)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.OXYGEN.drain_rate)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.OXYGEN.threshold_caution)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.OXYGEN.threshold_warning)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.OXYGEN.threshold_critical)).is_equal(TYPE_FLOAT)


func test_prop_defaults_match_gdd() -> void:
	assert_float(Tuning.PROP.prop_gravity_scale).is_equal_approx(1.0, EPSILON)
	assert_float(Tuning.PROP.prop_max_speed).is_equal_approx(2000.0, EPSILON)
	assert_int(Tuning.PROP.props_per_level_budget).is_equal(40)


func test_props_per_level_budget_is_an_int_not_a_float() -> void:
	# V-PROP-BUDGET compares a node count against this. A float here is also
	# what a wrong-typed .tres value produces.
	assert_int(typeof(Tuning.PROP.props_per_level_budget)).is_equal(TYPE_INT)
	assert_int(typeof(Tuning.PROP.prop_gravity_scale)).is_equal(TYPE_FLOAT)
	assert_int(typeof(Tuning.PROP.prop_max_speed)).is_equal(TYPE_FLOAT)


# ── group 5 — V9, resource_local_to_scene stays false ────────────────────────
#
# Cheap, and the failure it catches is otherwise invisible: if this is ever
# true, the engine hands each instantiating scene its own copy, T3 cache
# identity stops holding, "exactly one instance project-wide" quietly becomes
# false, and the D6.5 read-only reasoning stops describing reality. Nothing
# errors and nothing logs.

func test_watering_is_not_local_to_scene() -> void:
	assert_bool(Tuning.WATERING.resource_local_to_scene).is_false()


func test_oxygen_is_not_local_to_scene() -> void:
	assert_bool(Tuning.OXYGEN.resource_local_to_scene).is_false()


func test_prop_is_not_local_to_scene() -> void:
	assert_bool(Tuning.PROP.resource_local_to_scene).is_false()


# ── group 6 — absence cases (Story 002) ──────────────────────────────────────
#
# These matter as much as the presence cases. The failure they catch is a
# well-meaning author "completing" a resource with a knob ADR-0006 deliberately
# placed on a node instead, which silently moves the tuning surface and breaks
# the D6.1 ownership guarantee with no error.

func test_watering_holds_exactly_its_four_knobs() -> void:
	var names := _script_property_names(Tuning.WATERING)
	assert_array(names).contains_exactly_in_any_order([
		"carry_speed_multiplier",
		"throw_arc_height",
		"throw_duration",
		"throw_angle_spread",
	])
	# Per-plant knobs live on Plant; interact_radius is not a watering knob.
	assert_array(names).not_contains(["buckets_required", "water_duration", "interact_radius"])


func test_oxygen_holds_exactly_its_five_knobs() -> void:
	var names := _script_property_names(Tuning.OXYGEN)
	assert_array(names).contains_exactly_in_any_order([
		"margin",
		"drain_rate",
		"threshold_caution",
		"threshold_warning",
		"threshold_critical",
	])
	# oxygen_capacity is the per-level dial on the level root (suit-oxygen.md R6).
	assert_array(names).not_contains(["oxygen_capacity"])


func test_prop_holds_exactly_its_three_knobs() -> void:
	var names := _script_property_names(Tuning.PROP)
	assert_array(names).contains_exactly_in_any_order([
		"prop_gravity_scale",
		"prop_max_speed",
		"props_per_level_budget",
	])
	# Per-prop physics is a scene export — variation is the point.
	assert_array(names).not_contains(["mass", "friction", "bounce", "linear_damp", "angular_damp"])


func test_no_gravity_tuning_class_is_registered() -> void:
	# D6.7 standing ban. The jump constants stay @export on Player (ADR-0001
	# part 7); changing that requires superseding the ADR-0001
	# jump_constants_location entry, not extending ADR-0006.
	var classes := _global_class_names()
	assert_int(classes.size()) \
		.override_failure_message("Global class list came back empty — the scan is broken.") \
		.is_greater_equal(MIN_GLOBAL_CLASSES)
	assert_array(classes).not_contains(["GravityTuning"])


# ── group 7 — derived invariants ─────────────────────────────────────────────

func test_threshold_ordering_holds() -> void:
	# Following the ADR-0004 precedent: assert a derived invariant, so a later
	# edit that inverts two thresholds fails loudly rather than producing
	# silently wrong feedback escalation.
	assert_float(Tuning.OXYGEN.threshold_critical).is_less(Tuning.OXYGEN.threshold_warning)
	assert_float(Tuning.OXYGEN.threshold_warning).is_less(Tuning.OXYGEN.threshold_caution)


# ── group 8 — Tuning accessor shape (Story 004 AC-1..AC-3, folded in here) ───

func test_tuning_holds_exactly_three_constants() -> void:
	var tuning_script: GDScript = load(TUNING_SCRIPT_PATH)
	var constant_names: Array = tuning_script.get_script_constant_map().keys()
	# A fourth constant added later must fail this test — that is the point.
	# architecture.md already records one declined fourth tuning resource.
	assert_array(constant_names).contains_exactly_in_any_order(["WATERING", "OXYGEN", "PROP"])


func test_tuning_declares_no_behaviour() -> void:
	var tuning_script: GDScript = load(TUNING_SCRIPT_PATH)
	var declared: Array[String] = []
	for method: Dictionary in tuning_script.get_script_method_list():
		var method_name := String(method["name"])
		# Compiler-generated entries are prefixed with @.
		if not method_name.begins_with("@"):
			declared.append(method_name)
	assert_array(declared) \
		.override_failure_message(
			"Tuning must hold three constants and nothing else — no methods, " +
			"no variables, no signals, no _ready (ADR-0006 D6.3). Found: %s" % [declared]) \
		.is_empty()
	assert_array(tuning_script.get_script_signal_list()).is_empty()


func test_tuning_is_not_registered_as_an_autoload() -> void:
	# preload already gives Tuning universal reach. Registering it would hand it
	# exactly the tree dependency D6.3 exists to avoid, and would break the
	# LevelValidation null-tree path.
	for setting_name: String in _autoload_setting_names():
		var value := String(ProjectSettings.get_setting(setting_name, ""))
		# An entry disabled with a leading * still counts as present, so match on
		# the value as well as the key.
		assert_bool(setting_name == "autoload/Tuning") \
			.override_failure_message("Tuning is registered as an autoload (%s)." % setting_name) \
			.is_false()
		assert_bool(value.contains("tuning.gd")) \
			.override_failure_message("An autoload (%s) points at tuning.gd." % setting_name) \
			.is_false()
