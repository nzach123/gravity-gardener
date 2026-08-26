# Integration tests for story GA-004 — zones report to the authority, and the
# Area2D space-gravity override is cleared.
#
# This crosses three things: `GravityZone`, the `main.gd` level-root wiring, and
# the `GravityAuthority` autoload. The zone declares a direction and a
# multiplier and emits; `main.gd` routes that emission to
# `GravityAuthority.set_gravity()`; the authority validates and broadcasts.
# The zone never reaches the player and never validates for itself.
#
# Several cases are deliberately *source* assertions rather than behavioural
# ones. Two defects this story guards against are invisible to behaviour today:
#   - `gravity_space_override` on an `Area2D` does nothing until a
#     `RigidBody2D` exists, which is after this epic closes.
#   - a no-op `_on_body_exited` on `GravityZone` passes every persistence test
#     while remaining a live regression risk.
#
# Fixture is the GDD section 4 derived pair — baseline ascent 2990.72 and
# ascent/descent ratio 0.390625 — seeded straight into the authority, so no
# `Player` needs to enter the tree. Every case is deterministic: the direction
# ease is stepped by calling `_physics_process()` with a fixed delta, never by
# waiting on wall time.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const MAIN_SCRIPT := "res://src/scripts/main.gd"
const ZONE_SCRIPT := "res://src/scripts/gravity_zone.gd"
const ZONE_SCENE := "res://src/scenes/gravity_zone.tscn"
const SRC_ROOT := "res://src"

# GDD section 4 derived values — see player_gravity_consumer_test.gd.
const BASELINE_ASCENT := 2990.72
const ASCENT_DESCENT_RATIO := 0.390625

const DELTA := 1.0 / 60.0
const TOLERANCE := 0.01

# Enough steps for the 32.0-rate ease to reach the settle epsilon many times
# over. AC-6 asks for 300; the ease settles inside ~5.
const PERSISTENCE_FRAMES := 300

# The zone's authored RectangleShape2D is 50x50, so its bounds reach 25 px from
# its origin. The AC-7 observers sit orders of magnitude outside that.
const ZONE_HALF_EXTENT := 25.0
const OBSERVER_A_POSITION := Vector2(5000.0, 5000.0)
const OBSERVER_B_POSITION := Vector2(-4000.0, -3000.0)

var _spy_calls: Array[Vector2] = []
var _spy_multipliers: Array[float] = []
var _broadcasts: Array[Vector2] = []


func before_test() -> void:
	_spy_calls = []
	_spy_multipliers = []
	_broadcasts = []
	GravityAuthority.initialize(BASELINE_ASCENT, ASCENT_DESCENT_RATIO)
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)


func after_test() -> void:
	# Leave the autoload seeded and pointing down, so no later suite inherits a
	# flipped or unseeded singleton from this one.
	GravityAuthority.initialize(BASELINE_ASCENT, ASCENT_DESCENT_RATIO)
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)


# ── AC-1 — no wiring anywhere targets the player ─────────────────────────────

func test_no_source_file_connects_a_zone_to_player_set_gravity() -> void:
	# Scanned across every .gd under src/, not main.gd alone:
	# `zone_targets_player_directly` is a project-wide ban, and a second wiring
	# site in any other script would satisfy a single-file grep.
	var offenders: PackedStringArray = _scan_src_for("player.set_gravity")
	assert_array(offenders) \
		.override_failure_message(
			"A zone still reaches Player.set_gravity() from: %s — that method is " % str(offenders)
			+ "removed by ADR-0001 and the pattern is forbidden."
		) \
		.is_empty()


func test_no_source_file_calls_set_gravity_on_anything_but_the_authority() -> void:
	# The grep above only catches the literal receiver name `player`. This one
	# catches any other receiver: only `GravityAuthority.set_gravity` is legal.
	var offenders: PackedStringArray = _scan_src_matching("(?<!GravityAuthority)\\.set_gravity\\b")
	assert_array(offenders) \
		.override_failure_message(
			"set_gravity() is called on a non-authority receiver in: %s" % str(offenders)
		) \
		.is_empty()


func test_main_connects_every_zone_signal_to_the_authority() -> void:
	# The positive half — the negatives above pass trivially on a file that
	# wires nothing at all.
	var code: String = _code_of(MAIN_SCRIPT)
	assert_bool(code.contains("zone.gravity_changed.connect(GravityAuthority.set_gravity)")) \
		.override_failure_message(
			"main.gd does not connect zones to GravityAuthority.set_gravity()."
		) \
		.is_true()


# ── AC-2 — the camera follows the authority, once ────────────────────────────

func test_main_connects_the_camera_handler_to_the_authority_signal() -> void:
	var code: String = _code_of(MAIN_SCRIPT)
	assert_bool(
		code.contains("GravityAuthority.gravity_changed.connect(_rotate_camera_to_gravity)")
	) \
		.override_failure_message(
			"The camera handler is not connected to GravityAuthority.gravity_changed."
		) \
		.is_true()


func test_main_never_connects_the_camera_handler_to_a_zone_signal() -> void:
	var code: String = _code_of(MAIN_SCRIPT)
	assert_bool(code.contains("zone.gravity_changed.connect(_rotate_camera_to_gravity)")) \
		.override_failure_message(
			"The camera handler is connected to a zone's own signal, not the authority's."
		) \
		.is_false()


func test_the_camera_handler_is_connected_exactly_once() -> void:
	# A second connection would run the 0.6 s tween twice per broadcast.
	assert_int(_code_of(MAIN_SCRIPT).count("connect(_rotate_camera_to_gravity)")).is_equal(1)


func test_the_camera_connection_sits_outside_the_zone_loop() -> void:
	# The count check alone passes on a single connection that still sits INSIDE
	# `for zone in ...:` — one line, but N connections at runtime for N zones.
	# Indentation is the structural evidence: the connect must not be nested
	# deeper than the `for` that precedes it.
	var lines: PackedStringArray = _code_of(MAIN_SCRIPT).split("\n")
	var loop_indent: int = -1
	var connect_indent: int = -1
	var connect_line: int = -1

	for index: int in lines.size():
		var line: String = lines[index]
		if line.strip_edges().begins_with("for ") and line.contains("gravityzone"):
			loop_indent = _indent_of(line)
		if line.contains("connect(_rotate_camera_to_gravity)"):
			connect_indent = _indent_of(line)
			connect_line = index

	assert_int(loop_indent).override_failure_message(
		"No `for ... gravityzone` loop found in main.gd — the fixture moved."
	).is_greater_equal(0)
	assert_int(connect_line).override_failure_message(
		"No camera connection found in main.gd."
	).is_greater_equal(0)
	assert_int(connect_indent) \
		.override_failure_message(
			"The camera connection is nested inside the zone loop (indent %d vs loop indent %d) "
			% [connect_indent, loop_indent]
			+ "— one zone entry would start one tween per zone."
		) \
		.is_less_equal(loop_indent)


# ── AC-3 — gravity_zone.tscn declares no space gravity ───────────────────────

func test_gravity_zone_scene_declares_no_space_override() -> void:
	assert_bool(_text_of(ZONE_SCENE).contains("gravity_space_override")) \
		.override_failure_message(
			"gravity_zone.tscn still sets gravity_space_override — props inside a "
			+ "zone would be pinned to that zone's never-updated vector (ADR-0001 part 5)."
		) \
		.is_false()


func test_gravity_zone_scene_declares_no_area_gravity_value() -> void:
	var pattern: RegEx = _regex("(?m)^gravity\\s*=")
	assert_bool(pattern.search(_text_of(ZONE_SCENE)) != null) \
		.override_failure_message("gravity_zone.tscn still sets `gravity` on the Area2D root.") \
		.is_false()


func test_gravity_zone_scene_keeps_its_collision_and_script_authoring() -> void:
	# The removal above passes on an emptied file. Pin what must survive it.
	var text: String = _text_of(ZONE_SCENE)
	assert_bool(text.contains("collision_layer = 0")).is_true()
	assert_bool(text.contains("collision_mask = 2")).is_true()
	assert_bool(text.contains("gravity_zone.gd")).is_true()
	assert_bool(text.contains("groups=[\"gravityzone\"]")).is_true()


# ── AC-4 — no Area2D anywhere declares space gravity ─────────────────────────

func test_no_scene_under_src_declares_a_gravity_space_override() -> void:
	# `gravity_space_override` exists only on Area2D/Area3D, so a project-wide
	# text ban carries no false positives and needs no node-type resolution.
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _scene_files(SRC_ROOT):
		if _text_of(path).contains("gravity_space_override"):
			offenders.append(path)

	assert_array(offenders) \
		.override_failure_message(
			"gravity_space_override survives in: %s — this reintroduces " % str(offenders)
			+ "per-region gravity and stays invisible until a RigidBody2D exists."
		) \
		.is_empty()


func test_no_area2d_node_in_any_scene_declares_a_gravity_value() -> void:
	# Node-type aware, and it resolves instanced/inherited roots back to the
	# scene they instance — an override authored on a zone *instance* inside a
	# level is exactly as damaging as one on gravity_zone.tscn itself.
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _scene_files(SRC_ROOT):
		offenders.append_array(_area2d_gravity_offenders(path))

	assert_array(offenders) \
		.override_failure_message(
			"An Area2D declares `gravity` in: %s" % str(offenders)
		) \
		.is_empty()


func test_the_area2d_scan_covers_every_scene_and_actually_sees_area2d_nodes() -> void:
	# A scanner that silently matches nothing would make the case above pass on
	# any project. Prove it resolves the zone scene's root as an Area2D.
	assert_array(_scene_files(SRC_ROOT)).contains([ZONE_SCENE])
	assert_str(_root_node_type(ZONE_SCENE, [])).is_equal("Area2D")


# ── AC-5 — a mis-authored zone is rejected AT THE AUTHORITY ──────────────────

func test_zone_source_declares_no_validation_of_its_own() -> void:
	# A zone that returns early on its own leaves the authority's guard
	# untested and lets the two implementations diverge silently.
	var code: String = _code_of(ZONE_SCRIPT)
	for needle: String in ["is_zero_approx", "push_error", "push_warning"]:
		assert_bool(code.contains(needle)) \
			.override_failure_message(
				"gravity_zone.gd contains `%s` — validation belongs to the " % needle
				+ "authority alone (ADR-0001 part 2)."
			) \
			.is_false()


func test_a_zero_direction_zone_reaches_the_authority_and_is_rejected() -> void:
	var settled: Vector2 = GravityAuthority.gravity
	var settled_up: Vector2 = GravityAuthority.up_dir
	_fire_zone_entry(Vector2.ZERO, 1.0)

	# The zone emitted, unsanitized — proof it did not validate locally.
	assert_int(_spy_calls.size()).override_failure_message(
		"The zone swallowed a zero-length direction instead of reporting it."
	).is_equal(1)
	assert_that(_spy_calls[0]).is_equal(Vector2.ZERO)

	# And the authority refused it, leaving every derived field untouched.
	assert_array(_broadcasts).is_empty()
	assert_that(GravityAuthority.gravity).is_equal(settled)
	assert_that(GravityAuthority.target_gravity).is_equal(settled)
	assert_that(GravityAuthority.up_dir).is_equal(settled_up)


func test_a_negative_multiplier_zone_reaches_the_authority_and_is_rejected() -> void:
	var settled: Vector2 = GravityAuthority.gravity
	var settled_magnitude: float = GravityAuthority.ascent_magnitude()
	_fire_zone_entry(Vector2.UP, -1.0)

	assert_int(_spy_calls.size()).override_failure_message(
		"The zone swallowed a negative multiplier instead of reporting it."
	).is_equal(1)
	assert_float(_spy_multipliers[0]).is_equal(-1.0)

	assert_array(_broadcasts).is_empty()
	assert_that(GravityAuthority.gravity).is_equal(settled)
	assert_float(GravityAuthority.ascent_magnitude()).is_equal(settled_magnitude)


func test_a_zero_multiplier_zone_is_rejected_and_leaves_gravity_unchanged() -> void:
	# The boundary itself: R7 rejects `<= 0`, not `< 0`.
	var settled: Vector2 = GravityAuthority.gravity
	_fire_zone_entry(Vector2.UP, 0.0)

	assert_array(_broadcasts).is_empty()
	assert_that(GravityAuthority.gravity).is_equal(settled)


func test_a_valid_zone_entry_is_accepted_and_broadcast() -> void:
	# The rejections above all pass on an authority that accepts nothing.
	_fire_zone_entry(Vector2.UP, 0.5)

	assert_int(_broadcasts.size()).is_equal(1)
	assert_that(_broadcasts[0]).is_equal(Vector2.UP)
	assert_float(GravityAuthority.ascent_magnitude()).is_equal_approx(
		BASELINE_ASCENT * 0.5, TOLERANCE
	)


# ── AC-6 — gravity persists after the player leaves the zone ─────────────────

func test_gravity_zone_declares_no_body_exited_handler() -> void:
	# Source-level, because a persistence test passes on a zone whose exit
	# handler happens to be a no-op today.
	assert_bool(_code_of(ZONE_SCRIPT).contains("body_exited")) \
		.override_failure_message(
			"gravity_zone.gd references body_exited — GDD R2/AC6 requires a zone's "
			+ "gravity to persist indefinitely, so no exit handler may exist."
		) \
		.is_false()

	var zone: GravityZone = auto_free(GravityZone.new())
	assert_bool(zone.has_method("_on_body_exited")).is_false()


func test_the_zone_scene_wires_no_body_exited_signal() -> void:
	assert_bool(_text_of(ZONE_SCENE).contains("body_exited")) \
		.override_failure_message("gravity_zone.tscn connects body_exited.") \
		.is_false()


func test_gravity_persists_for_300_frames_after_the_player_leaves_the_zone() -> void:
	_fire_zone_entry(Vector2.UP, 0.5)
	for _step: int in PERSISTENCE_FRAMES:
		GravityAuthority._physics_process(DELTA)

	assert_that(GravityAuthority.gravity.normalized()).is_equal(Vector2.UP)
	assert_that(GravityAuthority.up_dir).is_equal(Vector2.DOWN)
	assert_float(GravityAuthority.ascent_magnitude()).is_equal_approx(
		BASELINE_ASCENT * 0.5, TOLERANCE
	)
	# Exactly one broadcast — nothing re-fired or reverted over 300 frames.
	assert_int(_broadcasts.size()).is_equal(1)


# ── AC-7 — the change is global, not per-body or per-region ──────────────────

func test_two_observers_outside_the_zone_read_the_same_gravity() -> void:
	var zone: GravityZone = _instantiate_zone(Vector2.UP, 1.0)
	var observer_a: Node2D = _add_observer(OBSERVER_A_POSITION)
	var observer_b: Node2D = _add_observer(OBSERVER_B_POSITION)

	# Both observers stand well outside the zone's bounds. A body INSIDE a zone
	# reads correct gravity even when the defect is present, so an observer
	# inside cannot detect it.
	_assert_outside_zone(zone, observer_a)
	_assert_outside_zone(zone, observer_b)

	var reads_a: Array[Vector2] = []
	var reads_b: Array[Vector2] = []
	var sample: Callable = func(_direction: Vector2, _multiplier: float) -> void:
		reads_a.append(GravityAuthority.gravity)
		reads_b.append(GravityAuthority.gravity)
	GravityAuthority.gravity_changed.connect(sample)

	_enter(zone)

	GravityAuthority.gravity_changed.disconnect(sample)
	assert_int(reads_a.size()).is_equal(1)
	assert_that(reads_a[0]).is_equal(reads_b[0])


func test_both_observers_track_the_same_vector_across_every_ease_step() -> void:
	# The same-frame read above is one sample. The turn is where a per-region
	# implementation would diverge, so sample every step of it.
	var zone: GravityZone = _instantiate_zone(Vector2.UP, 1.0)
	var observer_a: Node2D = _add_observer(OBSERVER_A_POSITION)
	var observer_b: Node2D = _add_observer(OBSERVER_B_POSITION)
	_assert_outside_zone(zone, observer_a)
	_assert_outside_zone(zone, observer_b)

	_enter(zone)

	for _step: int in 12:
		GravityAuthority._physics_process(DELTA)
		var read_a: Vector2 = _gravity_at(observer_a)
		var read_b: Vector2 = _gravity_at(observer_b)
		assert_that(read_a).is_equal(read_b)
		assert_bool(read_a.is_zero_approx()).is_false()

	assert_that(GravityAuthority.gravity.normalized()).is_equal(Vector2.UP)


# ── AC-8 — the zone's authored surface is preserved ──────────────────────────

func test_zone_still_exports_direction_multiplier_and_priority() -> void:
	var zone: GravityZone = auto_free(GravityZone.new())
	for property_name: String in [
		"zone_gravity_direction", "zone_gravity_multiplier", "zone_priority",
	]:
		assert_bool(_is_exported(zone, property_name)) \
			.override_failure_message("GravityZone no longer exports %s" % property_name) \
			.is_true()


func test_get_zone_gravity_direction_returns_the_normalized_direction() -> void:
	var zone: GravityZone = auto_free(GravityZone.new())
	zone.zone_gravity_direction = Vector2(0.0, 50.0)
	assert_that(zone.get_zone_gravity_direction()).is_equal(Vector2.DOWN)

	zone.zone_gravity_direction = Vector2(-7.0, 0.0)
	assert_that(zone.get_zone_gravity_direction()).is_equal(Vector2.LEFT)


func test_zone_priority_is_exported_but_read_by_nothing() -> void:
	# GDD R8 parks overlap resolution deliberately. Silently implementing it and
	# deleting the export are both wrong, so both directions are asserted.
	var zone: GravityZone = auto_free(GravityZone.new())
	assert_bool(_is_exported(zone, "zone_priority")).is_true()

	var consumers: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(SRC_ROOT):
		for line: String in _code_of(path).split("\n"):
			if not line.contains("zone_priority"):
				continue
			if _regex("^\\s*(@export\\s+)?var\\s+zone_priority\\b").search(line) != null:
				continue
			consumers.append("%s: %s" % [path, line.strip_edges()])

	assert_array(consumers) \
		.override_failure_message(
			"zone_priority is consumed by %s — TR-gravity-008 is parked by GDD R8 "
			% str(consumers) + "and has no story in this epic."
		) \
		.is_empty()


# ── Regression re-added from GA-003 — direction length is not strength ───────

func test_a_long_zone_direction_does_not_leak_into_gravity_strength() -> void:
	# GA-003 dropped this assertion as deduped, but the contract suite drives
	# non-unit directions without ever pinning the resulting MAGNITUDE. A zone
	# authoring `Vector2(0, 50)` is squarely this story's subject.
	_fire_zone_entry(Vector2(0.0, 50.0), 1.0)
	var long_magnitude: float = GravityAuthority.target_gravity.length()

	_fire_zone_entry(Vector2.DOWN, 1.0)
	var unit_magnitude: float = GravityAuthority.target_gravity.length()

	assert_float(long_magnitude).is_equal(unit_magnitude)
	assert_float(long_magnitude).is_equal_approx(BASELINE_ASCENT, TOLERANCE)


func test_a_long_zone_direction_broadcasts_a_unit_direction() -> void:
	_fire_zone_entry(Vector2(0.0, 50.0), 2.0)

	assert_that(_broadcasts[0]).is_equal(Vector2.DOWN)
	assert_float(GravityAuthority.ascent_magnitude()).is_equal_approx(
		BASELINE_ASCENT * 2.0, TOLERANCE
	)


# ── helpers ──────────────────────────────────────────────────────────────────

# Builds a zone (no tree, no scene) and drives one `body_entered` through the
# real `main.gd` wiring shape: zone signal -> authority. The spy sits on the
# zone's own signal, so it records what the ZONE emitted before the authority
# had any chance to validate it.
func _fire_zone_entry(direction: Vector2, multiplier: float) -> void:
	var zone: GravityZone = auto_free(GravityZone.new())
	zone.zone_gravity_direction = direction
	zone.zone_gravity_multiplier = multiplier
	_enter(zone)


# Wires a zone the way `main.gd` does, records both sides, and fires an entry.
func _enter(zone: GravityZone) -> void:
	var spy: Callable = func(direction: Vector2, multiplier: float) -> void:
		_spy_calls.append(direction)
		_spy_multipliers.append(multiplier)
		GravityAuthority.set_gravity(direction, multiplier)
	var broadcast: Callable = func(direction: Vector2, _multiplier: float) -> void:
		_broadcasts.append(direction)

	zone.gravity_changed.connect(spy)
	GravityAuthority.gravity_changed.connect(broadcast)
	zone.body_entered.connect(zone._on_body_entered)

	zone.body_entered.emit(auto_free(Player.new()))

	GravityAuthority.gravity_changed.disconnect(broadcast)


# The full authored zone, in the tree, so its collision bounds are real.
func _instantiate_zone(direction: Vector2, multiplier: float) -> GravityZone:
	var scene: PackedScene = load(ZONE_SCENE) as PackedScene
	var zone: GravityZone = scene.instantiate() as GravityZone
	zone.zone_gravity_direction = direction
	zone.zone_gravity_multiplier = multiplier
	add_child(auto_free(zone))
	return zone


func _add_observer(position: Vector2) -> Node2D:
	var observer: Node2D = auto_free(Node2D.new())
	add_child(observer)
	observer.global_position = position
	return observer


# What a body at this observer's position reads. There is exactly one place to
# read it from — that is the whole of GDD R9.
func _gravity_at(_observer: Node2D) -> Vector2:
	return GravityAuthority.gravity


func _assert_outside_zone(zone: GravityZone, observer: Node2D) -> void:
	var offset: Vector2 = observer.global_position - zone.global_position
	assert_bool(absf(offset.x) > ZONE_HALF_EXTENT or absf(offset.y) > ZONE_HALF_EXTENT) \
		.override_failure_message(
			"Observer at %s sits inside the zone's bounds — it cannot detect a "
			% str(observer.global_position) + "per-region defect."
		) \
		.is_true()


func _is_exported(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if str(property["name"]) != property_name:
			continue
		return (int(property["usage"]) & PROPERTY_USAGE_EDITOR) != 0
	return false


func _indent_of(line: String) -> int:
	var count: int = 0
	for character: String in line:
		if character != "\t" and character != " ":
			break
		count += 1
	return count


func _regex(pattern: String) -> RegEx:
	var compiled: RegEx = RegEx.new()
	compiled.compile(pattern)
	return compiled


func _text_of(path: String) -> String:
	return FileAccess.get_file_as_string(path)


# Script source with comment-only lines stripped, so a rule quoted in a doc
# comment cannot satisfy or break a source scan.
func _code_of(script_path: String) -> String:
	var code: PackedStringArray = PackedStringArray()
	for line: String in _text_of(script_path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)


func _scan_src_for(needle: String) -> PackedStringArray:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(SRC_ROOT):
		if _code_of(path).contains(needle):
			offenders.append(path)
	return offenders


func _scan_src_matching(pattern: String) -> PackedStringArray:
	var compiled: RegEx = _regex(pattern)
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(SRC_ROOT):
		if compiled.search(_code_of(path)) != null:
			offenders.append(path)
	return offenders


func _gd_files(directory: String) -> PackedStringArray:
	return _files_under(directory, ".gd")


func _scene_files(directory: String) -> PackedStringArray:
	return _files_under(directory, ".tscn")


func _files_under(directory: String, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_directories_at(directory):
		found.append_array(_files_under(directory.path_join(name), suffix))
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(suffix):
			found.append(directory.path_join(name))
	return found


# Every `gravity = ...` in `scene_path` that belongs to an Area2D node, whether
# the node declares `type="Area2D"` outright or instances a scene whose root is
# an Area2D (a zone placed in a level, or an inherited scene).
func _area2d_gravity_offenders(scene_path: String) -> PackedStringArray:
	var ext_resources: Dictionary = _ext_resource_paths(scene_path)
	var offenders: PackedStringArray = PackedStringArray()
	var in_area2d: bool = false

	for line: String in _text_of(scene_path).split("\n"):
		if line.begins_with("["):
			in_area2d = line.begins_with("[node ") \
				and _node_header_type(line, ext_resources, [scene_path]) == "Area2D"
			continue
		if in_area2d and _regex("^gravity\\s*=").search(line) != null:
			offenders.append("%s: %s" % [scene_path, line.strip_edges()])
	return offenders


# Resolves a `[node ...]` header to its node type, following `instance=` back
# to the instanced scene's own root when the header carries no `type=`.
func _node_header_type(header: String, ext_resources: Dictionary, visited: Array) -> String:
	var typed: RegExMatch = _regex("type=\"([^\"]+)\"").search(header)
	if typed != null:
		return typed.get_string(1)

	var instanced: RegExMatch = _regex("instance=ExtResource\\(\"([^\"]+)\"\\)").search(header)
	if instanced == null:
		return ""
	var resource_id: String = instanced.get_string(1)
	if not ext_resources.has(resource_id):
		return ""
	return _root_node_type(str(ext_resources[resource_id]), visited)


# The type of a scene file's first `[node ...]` header. `visited` breaks the
# cycle a malformed scene graph could otherwise create.
func _root_node_type(scene_path: String, visited: Array) -> String:
	if visited.has(scene_path) or not FileAccess.file_exists(scene_path):
		return ""
	var seen: Array = visited.duplicate()
	seen.append(scene_path)

	var ext_resources: Dictionary = _ext_resource_paths(scene_path)
	for line: String in _text_of(scene_path).split("\n"):
		if line.begins_with("[node "):
			return _node_header_type(line, ext_resources, seen)
	return ""


# Maps each `[ext_resource ... id="X"]` to its `res://` path.
func _ext_resource_paths(scene_path: String) -> Dictionary:
	var paths: Dictionary = {}
	var pattern: RegEx = _regex("path=\"([^\"]+)\".*id=\"([^\"]+)\"")
	for line: String in _text_of(scene_path).split("\n"):
		if not line.begins_with("[ext_resource "):
			continue
		var found: RegExMatch = pattern.search(line)
		if found != null:
			paths[found.get_string(2)] = found.get_string(1)
	return paths
