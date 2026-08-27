# Integration tests for story LS-004: LevelRoot constructs both state objects
# and injects them (ADR-0002 parts 1, 3, 4; the corrected init order).
#
# Synthetic trees only — no level scene is loaded. Player, Goal and Plant are
# instantiated from their own scenes because main.gd's exports are TYPED
# (`@export var player: Player`), so a bare stand-in node cannot be assigned.
#
# The tests that matter here are the NEGATIVE ones. Bottom-up `_ready()` makes
# reading-before-bind the natural mistake, and "refuses to operate" has two
# halves that need two separate assertions: the `push_error()` AND the early
# `return`. A push_error that falls through still runs the body, and a test that
# only captures the error message passes on that defect.
extends GdUnitTestSuite

const PLAYER_SCENE := "res://src/scenes/player/player.tscn"
const GOAL_SCENE := "res://src/scenes/goal.tscn"
const PLANT_SCENE := "res://src/scenes/plant.tscn"
const MAIN_SCRIPT := "res://src/scripts/main.gd"

const GOAL_UNBOUND_ERROR := "Goal: _is_goal_unlocked() called before bind()"
const PLAYER_UNBOUND_ERROR := "Player: is_carrying_bucket() called before bind()"


func before_test() -> void:
	GameManager.reset_level_state()


# ── construction helpers ────────────────────────────────────────────────────
#
# The level is built detached and only then added to the tree, because
# `LevelRoot._ready()` is the whole subject: every child must already exist when
# it runs, exactly as it would in an authored scene.
func _new_level(plant_count: int = 0) -> LevelRoot:
	var level := LevelRoot.new()
	level.name = "LevelRoot"

	# main.gd's `@onready var camera_2d: Camera2D = $Camera2D` resolves during
	# _ready(), so the node must be present before the level enters the tree.
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	level.add_child(camera)

	level.player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	level.add_child(level.player)
	level.goal = (load(GOAL_SCENE) as PackedScene).instantiate() as Goal
	level.add_child(level.goal)

	for i: int in plant_count:
		var plant := (load(PLANT_SCENE) as PackedScene).instantiate() as Plant
		plant.name = "Plant%d" % i
		plant.buckets_required = 1
		level.add_child(plant)
		# One bucket per plant keeps the level internally consistent
		# (V-BUCKET-SUM), which the bucket-count tests then vary deliberately.
		var bucket := Bucket.new()
		bucket.name = "Bucket%d" % i
		level.add_child(bucket)

	return level


# Runs `LevelRoot._ready()` by entering the tree, then stops every per-frame
# loop in the subtree. Nothing here asserts on frames, and a live `_process()`
# on a detached-from-a-real-game level would read `bucket` (null) and poll input.
func _activate(level: LevelRoot) -> LevelRoot:
	add_child(level)
	_freeze(level)
	return level


func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children():
		_freeze(child)


func _plants_of(level: LevelRoot) -> Array[Plant]:
	var found: Array[Plant] = []
	for child: Node in level.get_children():
		if child is Plant:
			found.append(child as Plant)
	return found


# ── AC-1: construction happens at step (a), before any bind ─────────────────

func test_ready_constructs_both_state_objects() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(2)))

	assert_object(level._level_state) \
		.override_failure_message(
			"LevelRoot._ready() must construct LevelState at step (a) (ADR-0002 part 1)."
		) \
		.is_not_null()
	assert_object(level._oxygen_state) \
		.override_failure_message(
			"LevelRoot._ready() must construct OxygenState at step (a) (ADR-0002 part 1)."
		) \
		.is_not_null()
	# Plain RefCounted, never an autoload and never a Node.
	assert_str(level._level_state.get_class()).is_equal("RefCounted")
	assert_str(level._oxygen_state.get_class()).is_equal("RefCounted")


func test_each_consumer_received_a_non_null_state_object() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(1)))

	# Non-null AND the same instance — a consumer holding some other LevelState
	# would satisfy a null check while observing a different level entirely.
	assert_object(level.player._level_state).is_not_null()
	assert_object(level.player._level_state).is_same(level._level_state)
	assert_object(level.goal._level_state).is_not_null()
	assert_object(level.goal._level_state).is_same(level._level_state)


func test_oxygen_state_is_built_from_the_root_export_and_shared_tuning() -> void:
	# `oxygen_capacity` is the new @export this story adds; the drain rate and
	# thresholds are NOT exports — they come from Tuning.OXYGEN (ADR-0006 D6.3).
	var level: LevelRoot = _new_level(0)
	level.oxygen_capacity = 42.0
	auto_free(_activate(level))

	assert_float(level._oxygen_state.capacity).is_equal(42.0)
	assert_float(level._oxygen_state.remaining).is_equal(42.0)


# ── AC-2: buckets_total is seeded from the shared counting primitive ────────

func test_buckets_total_matches_the_shared_counting_primitive() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(3)))

	# D3.5: one shared primitive. With two independent counts, V-BUCKET-SUM
	# could pass while LevelRoot seeded a different number.
	assert_int(level._level_state.buckets_total) \
		.is_equal(LevelValidation.count_buckets(level))
	assert_int(level._level_state.buckets_total).is_equal(3)


func test_buckets_at_different_depths_including_an_ungrouped_one_are_all_counted() -> void:
	var level: LevelRoot = _new_level(0)

	# Depth 1, in a group.
	var shallow := Bucket.new()
	shallow.name = "ShallowBucket"
	shallow.add_to_group("buckets")
	level.add_child(shallow)

	# Depth 2, in a group.
	var middle_holder := Node2D.new()
	middle_holder.name = "Crates"
	level.add_child(middle_holder)
	var middle := Bucket.new()
	middle.name = "MiddleBucket"
	middle.add_to_group("buckets")
	middle_holder.add_child(middle)

	# Depth 3, in NO group at all. This is the case a group scan gets wrong and
	# a recursive type scan gets right — a forgotten group assignment is
	# invisible bookkeeping and the level would report clean (ADR-0003 D3.2).
	var deep_holder := Node2D.new()
	deep_holder.name = "Shelf"
	middle_holder.add_child(deep_holder)
	var deep := Bucket.new()
	deep.name = "UngroupedBucket"
	deep_holder.add_child(deep)

	auto_free(_activate(level))

	# The ungrouped bucket really is ungrouped — otherwise this test is vacuous.
	assert_array(deep.get_groups()).is_empty()
	assert_int(level._level_state.buckets_total) \
		.override_failure_message(
			"All 3 Buckets must be counted regardless of depth or group membership."
		) \
		.is_equal(3)


# ── AC-3: player and goal each received bind() ──────────────────────────────

func test_player_received_bind_from_level_root() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(0)))
	assert_bool(level.player._bound).is_true()


func test_goal_received_bind_from_level_root() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(0)))
	assert_bool(level.goal._bound).is_true()


# ── AC-4: an unbound consumer refuses to operate ────────────────────────────
#
# Two halves, two assertions each. `push_error()` LOGS but does NOT pause
# execution, so the early `return` is what actually prevents the null
# dereference — asserting only the error message passes on a guard that falls
# through. `assert()` is not used in the guards: it compiles out of release
# exports (ADR-0002, A2-02).

func test_unbound_goal_pushes_an_error() -> void:
	var goal: Goal = auto_free((load(GOAL_SCENE) as PackedScene).instantiate() as Goal)
	add_child(goal)
	_freeze(goal)

	await assert_error(func() -> void: goal._is_goal_unlocked()) \
		.is_push_error(GOAL_UNBOUND_ERROR)


func test_unbound_goal_returns_early_without_touching_the_null_reference() -> void:
	var goal: Goal = auto_free((load(GOAL_SCENE) as PackedScene).instantiate() as Goal)
	add_child(goal)
	_freeze(goal)

	# Precondition: there genuinely is nothing to read.
	assert_bool(goal._bound).is_false()
	assert_object(goal._level_state).is_null()

	# The refusal value. Reaching `_level_state.goal_unlocked` on a null
	# reference cannot produce `false` — it produces a null dereference — so a
	# false here is evidence the body was skipped, not merely that push_error
	# was logged.
	assert_bool(goal._is_goal_unlocked()) \
		.override_failure_message(
			"An unbound Goal must return early with false, not fall through "
			+ "into `_level_state.goal_unlocked` (ADR-0002 part 3)."
		) \
		.is_false()
	# Still untouched afterwards: the guard read nothing and wrote nothing.
	assert_object(goal._level_state).is_null()
	assert_bool(goal.is_unlocked).is_false()


func test_unbound_player_pushes_an_error() -> void:
	var player: Player = auto_free((load(PLAYER_SCENE) as PackedScene).instantiate() as Player)
	add_child(player)
	_freeze(player)

	await assert_error(func() -> void: player.is_carrying_bucket()) \
		.is_push_error(PLAYER_UNBOUND_ERROR)


func test_unbound_player_returns_early_without_touching_the_null_reference() -> void:
	var player: Player = auto_free((load(PLAYER_SCENE) as PackedScene).instantiate() as Player)
	add_child(player)
	_freeze(player)

	assert_bool(player._bound).is_false()
	assert_object(player._level_state).is_null()

	assert_bool(player.is_carrying_bucket()) \
		.override_failure_message(
			"An unbound Player must return early with false, not fall through "
			+ "into `_level_state.carrying_bucket` (ADR-0002 part 3)."
		) \
		.is_false()
	assert_object(player._level_state).is_null()


# ── AC-5: LevelRoot owns the Plant wiring; Plant writes no level state ──────

func test_level_root_connects_every_plant_pour_completed_to_consume_bucket() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(3)))
	var plants: Array[Plant] = _plants_of(level)

	assert_int(plants.size()).is_equal(3)
	for plant: Plant in plants:
		assert_bool(plant.pour_completed.is_connected(level._level_state.consume_bucket)) \
			.override_failure_message(
				"LevelRoot._ready() step (d) must connect %s.pour_completed to "
				% plant.name + "LevelState.consume_bucket()."
			) \
			.is_true()


func test_emitting_pour_completed_increments_buckets_consumed() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(2)))
	var plants: Array[Plant] = _plants_of(level)

	assert_int(level._level_state.buckets_consumed).is_equal(0)
	plants[0].pour_completed.emit()
	assert_int(level._level_state.buckets_consumed).is_equal(1)
	plants[1].pour_completed.emit()
	assert_int(level._level_state.buckets_consumed).is_equal(2)
	# Two buckets authored, two consumed — the goal unlocks through the state
	# object, never through the plant.
	assert_bool(level._level_state.goal_unlocked).is_true()


func test_plant_holds_no_reference_to_any_state_object() -> void:
	var level: LevelRoot = auto_free(_activate(_new_level(2)))

	for plant: Plant in _plants_of(level):
		# No bind() surface at all — Plant is not on the consumer table.
		assert_bool(plant.has_method("bind")) \
			.override_failure_message("Plant must receive no state object (ADR-0002).") \
			.is_false()
		for property: Dictionary in plant.get_property_list():
			var value: Variant = plant.get(property["name"])
			assert_bool(value is LevelState or value is OxygenState) \
				.override_failure_message(
					"Plant property \"%s\" holds a state object; " % property["name"]
					+ "`plant_decides_level_outcome` is forbidden."
				) \
				.is_false()


func test_a_plant_outside_a_level_root_connects_nothing_to_itself() -> void:
	# The forbidden pattern is `plant_decides_level_outcome`. If the plant wired
	# its own pour_completed, this connection would exist without a LevelRoot —
	# which is what distinguishes "LevelRoot made the connection" from "a
	# connection exists".
	var plant: Plant = auto_free((load(PLANT_SCENE) as PackedScene).instantiate() as Plant)
	add_child(plant)
	_freeze(plant)

	assert_int(plant.pour_completed.get_connections().size()) \
		.override_failure_message(
			"A Plant readied outside a LevelRoot must have no pour_completed "
			+ "connections — the wiring belongs to LevelRoot, not the plant."
		) \
		.is_equal(0)


# ── AC-7: the state objects do not outlive the level ───────────────────────

func test_freeing_level_root_releases_both_state_objects() -> void:
	var level: LevelRoot = _activate(_new_level(2))
	# Deliberately NOT auto_free()'d — this test frees the level itself, and a
	# second free would be a double free.

	var level_state_ref: WeakRef = weakref(level._level_state)
	var oxygen_state_ref: WeakRef = weakref(level._oxygen_state)
	# These two pre-checks use assert_bool, NOT assert_object, and that is
	# load-bearing. gdUnit4's assert_object(obj) RETAINS A STRONG REFERENCE to
	# obj for the remainder of the test. Written as
	# `assert_object(level_state_ref.get_ref()).is_not_null()` the assertion
	# itself keeps both state objects alive past level.free(), and the two
	# assertions below then fail against a leak that does not exist. Verified by
	# probe on 2026-08-26: the only change was assert_object -> assert_bool here,
	# and the test went from 2 failures to PASSED. Do not "tidy" these back.
	# The assertions below are unaffected — on success they receive null, and on
	# a REAL leak they receive the live object and fail. The teeth are intact.
	assert_bool(level_state_ref.get_ref() != null).is_true()
	assert_bool(oxygen_state_ref.get_ref() != null).is_true()

	# Bound consumers (Player, Goal) hold strong references, and they are
	# descendants of LevelRoot — the A2-03 invariant. Freeing the root frees
	# every strong holder in the same synchronous pass.
	remove_child(level)
	level.free()

	# Engine fact for 4.7.1, established by probe on 2026-08-24: `== null` is
	# TRUE for a freed Object held in a Variant, and `value as Node` on a freed
	# object RAISES. A plain null check is the safe probe; `as` is not.
	assert_object(level_state_ref.get_ref()) \
		.override_failure_message(
			"LevelState outlived LevelRoot — restart would reuse stale state "
			+ "(ADR-0002 part 2, A2-03)."
		) \
		.is_null()
	assert_object(oxygen_state_ref.get_ref()) \
		.override_failure_message(
			"OxygenState outlived LevelRoot — restart would reuse stale oxygen "
			+ "(ADR-0002 part 2, A2-03)."
		) \
		.is_null()


# ── AC-8: no group-based discovery remains FOR PLANTS ──────────────────────
#
# Scoped on purpose. The "hazards" and "gravityzone" group scans in main.gd
# stay — they belong to other epics — so a blanket get_nodes_in_group assertion
# would fail on code this story is not allowed to change. The source is read
# through the resource loader rather than raw file I/O.

func _main_source() -> String:
	var script: GDScript = load(MAIN_SCRIPT) as GDScript
	assert_object(script).is_not_null()
	return script.source_code


func test_main_gd_no_longer_discovers_plants_by_group() -> void:
	var source: String = _main_source()

	# Vacuity floor: the scan must have found real source, and must still see
	# the group scans this story leaves alone. Without this the test would pass
	# on an empty string.
	assert_int(source.length()).is_greater(500)
	assert_str(source).contains("func _ready")
	assert_int(source.count("get_nodes_in_group")) \
		.override_failure_message(
			"Vacuity floor: main.gd must still contain the hazards and "
			+ "gravityzone group scans, which belong to other epics."
		) \
		.is_greater_equal(2)

	assert_int(source.count("get_nodes_in_group(\"plants\")")) \
		.override_failure_message(
			"Plant discovery must be a recursive type scan, never a group scan "
			+ "(ADR-0003 D3.2)."
		) \
		.is_equal(0)


func test_main_gd_discovers_plants_by_recursive_type_scan() -> void:
	var source: String = _main_source()

	assert_int(source.length()).is_greater(500)
	assert_str(source) \
		.override_failure_message(
			"main.gd must discover plants with a `node is Plant` type scan."
		) \
		.contains("is Plant")
	assert_str(source).contains("pour_completed.connect")
