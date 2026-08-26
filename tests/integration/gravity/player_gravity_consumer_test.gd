# Integration tests for story GA-003 — PlayerGravityComponent becomes a consumer.
#
# This crosses three objects: the `GravityAuthority` autoload, `Player`, and
# `PlayerGravityComponent`. The component no longer owns a vector; it derives
# its magnitudes from the authority, and `Player._ready()` seeds the authority's
# baseline from the player's jump constants.
#
# Fixture is the GDD section 4 "current values" set — h=200, d_peak=128,
# d_land=80, s=350 — which derives g_ascent=2990.72, g_descent=7656.25,
# v_jump=1093.75, ratio=0.390625. Those numbers are the R4 relocation bar: this
# story moves ownership, it does not retune feel.
#
# Every case is deterministic. The ease is stepped by calling the authority's
# `_physics_process()` with a fixed delta rather than by waiting on wall time.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const PLAYER_SCENE := "res://src/scenes/player/player.tscn"
const COMPONENT_SCRIPT := "res://src/scripts/components/player_gravity_component.gd"
const PLAYER_SCRIPT := "res://src/scripts/player.gd"
const SRC_ROOT := "res://src"

# GDD section 4 current values.
const JUMP_HEIGHT := 200.0
const JUMP_DISTANCE_TO_PEAK := 128.0
const JUMP_DISTANCE_TO_LAND := 80.0
const MAX_SPEED := 350.0

const BASELINE_ASCENT := 2990.72
const BASELINE_DESCENT := 7656.25
const JUMP_VELOCITY := 1093.75
const ASCENT_DESCENT_RATIO := 0.390625

const DELTA := 1.0 / 60.0
const TOLERANCE := 0.01
const RATIO_TOLERANCE := 0.000001

var _player: Player


func before_test() -> void:
	_reset_authority()


func after_test() -> void:
	_player = null
	GameManager.carrying_bucket = false
	# Leave the autoload seeded and pointing down, so no later suite inherits
	# an uninitialized singleton from this one.
	GravityAuthority.initialize(BASELINE_ASCENT, ASCENT_DESCENT_RATIO)
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)


# ── AC-1 — the component declares no gravity state ───────────────────────────

func test_component_source_declares_no_gravity_or_target_gravity_field() -> void:
	# `var gravity` matched at a word boundary: `gravity_ascent_mag` is a
	# legitimate initialize-time derivation and must not trip this scan.
	assert_bool(_declares(COMPONENT_SCRIPT, "gravity")) \
		.override_failure_message(
			"player_gravity_component.gd declares `var gravity` — that is the " +
			"forbidden private_gravity_copy (ADR-0001, control manifest)."
		) \
		.is_false()
	assert_bool(_declares(COMPONENT_SCRIPT, "target_gravity")).is_false()


func test_component_source_declares_no_baseline_or_ratio_field() -> void:
	# Both are accessors over the surviving magnitudes now, not stored copies.
	assert_bool(_declares(COMPONENT_SCRIPT, "baseline_ascent_mag")).is_false()
	assert_bool(_declares(COMPONENT_SCRIPT, "ascent_descent_ratio")).is_false()


func test_component_source_defines_none_of_the_removed_functions() -> void:
	var code: String = _code_of(COMPONENT_SCRIPT)
	assert_bool(code.contains("func set_gravity")).is_false()
	assert_bool(code.contains("func update_gravity_lerp")).is_false()
	assert_bool(code.contains("func update_derived_dirs")).is_false()


func test_component_instance_exposes_none_of_the_removed_methods() -> void:
	# The source scan proves the text is gone; this proves the object is too.
	var component: PlayerGravityComponent = auto_free(PlayerGravityComponent.new())
	for method_name: String in ["set_gravity", "update_gravity_lerp", "update_derived_dirs"]:
		assert_bool(component.has_method(method_name)) \
			.override_failure_message("PlayerGravityComponent still has %s()" % method_name) \
			.is_false()


func test_component_still_exposes_the_retained_consumer_api() -> void:
	# The negative scans above pass trivially on an emptied file. This is the
	# positive half of AC-1.
	var component: PlayerGravityComponent = auto_free(PlayerGravityComponent.new())
	for method_name: String in [
		"initialize", "apply_gravity", "baseline_ascent_magnitude", "ascent_descent_ratio",
	]:
		assert_bool(component.has_method(method_name)) \
			.override_failure_message("PlayerGravityComponent lost %s()" % method_name) \
			.is_true()


# ── AC-2 — Player.set_gravity is gone, with no surviving caller ──────────────

func test_player_node_has_no_set_gravity_method() -> void:
	# Asserted on Player specifically: Node has no inherited set_gravity, so a
	# true here means the method genuinely survived.
	var player: Player = auto_free(_new_player())
	assert_bool(player.has_method("set_gravity")).is_false()


func test_player_source_declares_no_target_gravity_proxy() -> void:
	assert_bool(_declares(PLAYER_SCRIPT, "target_gravity")).is_false()


func test_no_source_file_calls_player_set_gravity() -> void:
	# A deleted method with a live caller is a runtime error, not a parse
	# error, on a dynamically resolved property access — the compiler will not
	# catch it, so the scan must.
	var offenders: PackedStringArray = _scan_src_for("player.set_gravity")
	assert_array(offenders) \
		.override_failure_message(
			"Player.set_gravity() is removed but still called from: %s" % str(offenders)
		) \
		.is_empty()


func test_no_source_file_reads_a_gravity_component_vector() -> void:
	for needle: String in [
		"gravity_component.gravity",
		"gravity_component.target_gravity",
		"gravity_component.up_dir",
		"gravity_component.right_dir",
	]:
		assert_array(_scan_src_for(needle)) \
			.override_failure_message("Stale read of %s survives" % needle) \
			.is_empty()


# ── AC-3 — Player._ready() seeds the authority ───────────────────────────────

func test_authority_refuses_to_broadcast_before_player_ready() -> void:
	# The end state alone would also pass on an authority that self-seeds with
	# a silent 1.0 ratio — exactly the failure GA-001's guard exists to
	# prevent. Assert the BEFORE state observably: a refused broadcast.
	var received: Array[Vector2] = []
	var handler: Callable = func(direction: Vector2, _multiplier: float) -> void:
		received.append(direction)
	GravityAuthority.gravity_changed.connect(handler)

	GravityAuthority.set_gravity(Vector2.DOWN, 1.0)

	GravityAuthority.gravity_changed.disconnect(handler)
	assert_array(received).is_empty()
	assert_that(GravityAuthority.gravity).is_equal(Vector2.ZERO)


func test_player_ready_seeds_the_authority_baseline_ascent_magnitude() -> void:
	_ready_player()
	assert_float(GravityAuthority.baseline_ascent_mag).is_equal_approx(
		BASELINE_ASCENT, TOLERANCE
	)


func test_player_ready_seeds_the_authority_ascent_descent_ratio() -> void:
	_ready_player()
	assert_float(GravityAuthority.ascent_descent_ratio).is_equal_approx(
		ASCENT_DESCENT_RATIO, RATIO_TOLERANCE
	)


func test_the_authority_broadcasts_only_after_player_ready() -> void:
	# The before/after pair in one case, so the transition itself is pinned.
	var count: Array[int] = [0]
	var handler: Callable = func(_direction: Vector2, _multiplier: float) -> void:
		count[0] += 1
	GravityAuthority.gravity_changed.connect(handler)

	GravityAuthority.set_gravity(Vector2.DOWN, 1.0)
	assert_int(count[0]).is_equal(0)

	_ready_player()
	GravityAuthority.set_gravity(Vector2.DOWN, 1.0)

	GravityAuthority.gravity_changed.disconnect(handler)
	assert_int(count[0]).is_equal(1)


func test_seeded_authority_reproduces_the_gdd_magnitudes() -> void:
	_ready_player()
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)
	assert_float(GravityAuthority.ascent_magnitude()).is_equal_approx(
		BASELINE_ASCENT, TOLERANCE
	)
	assert_float(GravityAuthority.descent_magnitude()).is_equal_approx(
		BASELINE_DESCENT, TOLERANCE
	)


# ── AC-4 — the R4 asymmetry survives the move byte-identically ───────────────

func test_apply_gravity_while_ascending_applies_the_ascent_magnitude() -> void:
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)

	var velocity := Vector2(0.0, -100.0)  # rising against down-gravity
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)

	assert_float(result.y - velocity.y).is_equal_approx(BASELINE_ASCENT * DELTA, TOLERANCE)


func test_apply_gravity_while_descending_applies_the_descent_magnitude() -> void:
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)

	var velocity := Vector2(0.0, 100.0)
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)

	assert_float(result.y - velocity.y).is_equal_approx(BASELINE_DESCENT * DELTA, TOLERANCE)


func test_apply_gravity_at_the_zero_boundary_takes_the_descent_branch() -> void:
	# vel_up == 0.0 — a velocity exactly perpendicular to gravity. The
	# pre-migration guard was `vel_up > 0.0`, so zero falls to DESCENT. Apex
	# frames land on this boundary; flipping it would change jump feel.
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)

	var velocity := Vector2(250.0, 0.0)  # purely lateral
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)
	var applied: float = result.y - velocity.y

	assert_float(applied).is_equal_approx(BASELINE_DESCENT * DELTA, TOLERANCE)
	# And demonstrably NOT the ascent branch — the two differ by ~78 px/s here,
	# so a flipped boundary cannot hide inside the tolerance.
	assert_bool(absf(applied - BASELINE_ASCENT * DELTA) > 1.0).is_true()


func test_apply_gravity_on_the_floor_returns_the_velocity_unmodified() -> void:
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)

	var velocity := Vector2(123.0, -45.0)
	assert_that(component.apply_gravity(DELTA, velocity, true)).is_equal(velocity)


func test_apply_gravity_follows_the_authority_direction_after_a_flip() -> void:
	# The asymmetry must be relative to the CURRENT vector, not to screen-down.
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.RIGHT, 1.0)

	var velocity := Vector2(-100.0, 0.0)  # rising against right-gravity
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)

	assert_float(result.x - velocity.x).is_equal_approx(BASELINE_ASCENT * DELTA, TOLERANCE)
	assert_float(result.y).is_equal_approx(0.0, TOLERANCE)


func test_apply_gravity_scales_with_the_zone_multiplier() -> void:
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 0.5)

	var velocity := Vector2(0.0, 100.0)
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)

	assert_float(result.y - velocity.y).is_equal_approx(
		BASELINE_DESCENT * 0.5 * DELTA, TOLERANCE
	)


# ── AC-5 — jump_velocity is derived once and never recomputed ────────────────

func test_player_ready_derives_the_gdd_jump_velocity() -> void:
	var player: Player = _ready_player()
	assert_float(player.gravity_component.jump_velocity).is_equal_approx(
		JUMP_VELOCITY, TOLERANCE
	)
	assert_float(player.jump_component.jump_velocity).is_equal_approx(
		JUMP_VELOCITY, TOLERANCE
	)


func test_jump_velocity_is_bit_identical_after_ten_broadcasts() -> void:
	var player: Player = _ready_player()
	var before: float = player.gravity_component.jump_velocity

	var multipliers: Array[float] = [0.5, 2.0, 0.25, 4.0, 1.0, 0.1, 3.0, 0.5, 2.0, 1.0]
	var directions: Array[Vector2] = [
		Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.ONE,
		Vector2.DOWN, Vector2(0.5, -0.5), Vector2.UP, Vector2(-0.2, 0.9), Vector2.DOWN,
	]

	for index: int in multipliers.size():
		GravityAuthority.set_gravity(directions[index], multipliers[index])
		# Asserted after EVERY broadcast — a value that drifts and returns
		# would pass an end-only assertion.
		assert_float(player.gravity_component.jump_velocity).is_equal(before)
		assert_float(player.jump_component.jump_velocity).is_equal(before)


func test_jump_velocity_is_unchanged_by_a_broadcast_while_carrying_a_bucket() -> void:
	# GDD R10 / AC11, the reciprocal of watering-system.md AC1: carry scales
	# max_speed only and must never reach the launch speed.
	var player: Player = _ready_player()
	var before: float = player.gravity_component.jump_velocity

	GameManager.carrying_bucket = true
	GravityAuthority.set_gravity(Vector2.UP, 2.0)

	assert_float(player.gravity_component.jump_velocity).is_equal(before)
	assert_float(player.jump_component.jump_velocity).is_equal(before)


func test_set_jump_velocity_is_called_exactly_once_in_the_player_source() -> void:
	# `recompute_jump_velocity` is a registered forbidden pattern. One call
	# site, in _ready(), is the whole contract.
	var code: String = _code_of(PLAYER_SCRIPT)
	assert_int(code.count("jump_component.set_jump_velocity(")).is_equal(1)


func test_halving_gravity_doubles_the_jump_height_for_a_fixed_launch_speed() -> void:
	# GDD AC3 — the traversal lever the fixed launch speed exists to enable.
	# Migrated from gravity_component_test.gd; the magnitudes now come from
	# the authority.
	var player: Player = _ready_player()
	var v: float = player.gravity_component.jump_velocity

	GravityAuthority.reset_to(Vector2.DOWN, 1.0)
	var height_at_baseline: float = (v * v) / (2.0 * GravityAuthority.ascent_magnitude())

	GravityAuthority.set_gravity(Vector2.DOWN, 0.5)
	var height_at_half: float = (v * v) / (2.0 * GravityAuthority.ascent_magnitude())

	assert_float(height_at_half).is_equal_approx(height_at_baseline * 2.0, TOLERANCE)


func test_the_seeded_ratio_matches_the_components_own_derivation() -> void:
	# Migrated: initialize() preserves the ascent/descent ratio, and the
	# baseline is the 1.0x reference zones scale off.
	var component: PlayerGravityComponent = _ready_player().gravity_component
	var expected: float = component.gravity_ascent_mag / component.gravity_descent_mag

	assert_float(component.ascent_descent_ratio()).is_equal(expected)
	assert_float(component.baseline_ascent_magnitude()).is_equal(component.gravity_ascent_mag)
	assert_float(component.baseline_ascent_magnitude()).is_greater(0.0)


# ── AC-6 — the basis is read from the authority, never cached ────────────────

func test_player_basis_matches_the_authority_at_every_settled_angle() -> void:
	var player: Player = _ready_player()
	for direction: Vector2 in [
		Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.ONE,
	]:
		GravityAuthority.reset_to(direction, 1.0)
		_assert_player_basis_tracks_the_authority(player)
		assert_that(player.up_dir).is_equal(-direction.normalized())


func test_player_basis_matches_the_authority_mid_ease() -> void:
	# The settled-only check above passes on a component that caches the basis
	# on `gravity_changed`: such a cache agrees at both endpoints and diverges
	# for the ~100 ms in between. Sample inside the turn.
	var player: Player = _ready_player()
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)
	var settled_start: Vector2 = GravityAuthority.up_dir

	GravityAuthority.set_gravity(Vector2.RIGHT, 1.0)
	# One fixed step of the authority's own ease. No wall-clock waiting.
	GravityAuthority._physics_process(DELTA)

	# Genuinely mid-turn: past the start, not yet at the destination.
	assert_that(GravityAuthority.up_dir).is_not_equal(settled_start)
	assert_that(GravityAuthority.up_dir).is_not_equal(Vector2.LEFT)
	_assert_player_basis_tracks_the_authority(player)


func test_player_basis_tracks_the_authority_across_every_ease_step() -> void:
	var player: Player = _ready_player()
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)
	GravityAuthority.set_gravity(Vector2.LEFT, 1.0)

	for _step: int in 12:
		GravityAuthority._physics_process(DELTA)
		_assert_player_basis_tracks_the_authority(player)


func test_player_up_direction_adopts_the_authority_basis_each_physics_step() -> void:
	# up_direction is what move_and_slide() reads to decide "floor". It must
	# come from the authority, not from a locally derived vector.
	var player: Player = _ready_player()
	GravityAuthority.reset_to(Vector2.RIGHT, 1.0)

	player._physics_process(DELTA)

	assert_that(player.up_direction).is_equal(GravityAuthority.up_dir)


# ── AC-7 — no private gravity copy anywhere on the component ─────────────────

func test_component_declares_no_vector2_field_of_its_own() -> void:
	# Property-list scan rather than a text scan: it catches a cached vector
	# introduced under any name, which the AC-1 greps by construction cannot.
	var component: PlayerGravityComponent = auto_free(PlayerGravityComponent.new())
	var vector_fields: PackedStringArray = PackedStringArray()

	for property: Dictionary in component.get_property_list():
		var usage: int = int(property["usage"])
		if int(property["type"]) == TYPE_VECTOR2 and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			vector_fields.append(str(property["name"]))

	assert_array(vector_fields) \
		.override_failure_message(
			"PlayerGravityComponent declares Vector2 field(s) %s — the component " % str(vector_fields)
			+ "must hold no vector of its own (private_gravity_copy)."
		) \
		.is_empty()


func test_component_reads_the_live_authority_vector_not_a_snapshot() -> void:
	# A vector cached at initialize() time would keep applying the old
	# direction after a flip. Flip, then apply, with no signal in between.
	var component: PlayerGravityComponent = _ready_player().gravity_component
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)
	GravityAuthority.reset_to(Vector2.LEFT, 1.0)

	var velocity := Vector2.ZERO
	var result: Vector2 = component.apply_gravity(DELTA, velocity, false)

	assert_float(result.x).is_equal_approx(-BASELINE_DESCENT * DELTA, TOLERANCE)
	assert_float(result.y).is_equal_approx(0.0, TOLERANCE)


# ── helpers ──────────────────────────────────────────────────────────────────

# Drives the autoload back to its pre-initialize() state so AC-3 can observe
# the refusal. The autoload survives between tests; nothing else can undo it.
func _reset_authority() -> void:
	GravityAuthority._initialized = false
	GravityAuthority._current_multiplier = 1.0
	GravityAuthority.baseline_ascent_mag = 0.0
	GravityAuthority.ascent_descent_ratio = 1.0
	GravityAuthority.gravity = Vector2.ZERO
	GravityAuthority.target_gravity = Vector2.ZERO
	GravityAuthority.up_dir = Vector2.ZERO
	GravityAuthority.right_dir = Vector2.ZERO


# Instantiates the player scene WITHOUT entering the tree, so `_ready()` has
# not run yet and the authority is still unseeded.
func _new_player() -> Player:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	var player: Player = scene.instantiate() as Player
	player.jump_height = JUMP_HEIGHT
	player.jump_distance_to_peak = JUMP_DISTANCE_TO_PEAK
	player.jump_distance_to_land = JUMP_DISTANCE_TO_LAND
	player.max_speed = MAX_SPEED
	return player


# Adds the player to the tree, which runs `_ready()` and seeds the authority.
func _ready_player() -> Player:
	_player = auto_free(_new_player())
	add_child(_player)
	return _player


func _assert_player_basis_tracks_the_authority(player: Player) -> void:
	assert_that(player.up_dir).is_equal(GravityAuthority.up_dir)
	assert_that(player.right_dir).is_equal(GravityAuthority.right_dir)


# Returns the script source with comment-only lines stripped, so a rule quoted
# in a doc comment cannot satisfy or break a source scan.
func _code_of(script_path: String) -> String:
	var code: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)


# True when `script_path` declares `var <field_name>` at a word boundary.
func _declares(script_path: String, field_name: String) -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?m)^\\s*(@\\w+(\\(.*\\))?\\s+)*var\\s+%s\\s*[:=]" % field_name)
	return pattern.search(_code_of(script_path)) != null


# Every .gd file under src/ whose code (comments excluded) contains `needle`.
func _scan_src_for(needle: String) -> PackedStringArray:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(SRC_ROOT):
		if _code_of(path).contains(needle):
			offenders.append(path)
	return offenders


func _gd_files(directory: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_directories_at(directory):
		found.append_array(_gd_files(directory.path_join(name)))
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append(directory.path_join(name))
	return found
