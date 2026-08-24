# LevelValidation scaffold — discovery and count_buckets() (ADR-0003 D3.2, D3.5,
# and Validation Criterion 6). Story 001 of the level-validation epic.
#
# What this file is actually protecting:
#
#   Discovery must find nodes by TYPE, at any depth, including inside
#   instantiated sub-scenes. The two rejected alternatives both fail silently
#   rather than loudly — get_nodes_in_group() misses a node an author forgot to
#   group (and is unavailable at all on the null-tree CI path, because it is a
#   SceneTree method), and find_children() defaults owned = true and drops
#   descendants with no valid owner. A discovery mechanism that under-reports
#   converts "unknown" into a false "clean", which is worse than no validation.
#   So the depth and the no-owner cases below are the point of this suite, not
#   incidental coverage.
#
#   count_buckets() must be the SINGLE definition of "a bucket in this level"
#   (D3.5). LevelRoot seeds LevelState(buckets_total) from it in story 005.
#
# Every level here is synthetic and built in code. Nothing touches the eight
# shipped level scenes — the suite-wide CI test over those belongs to the level
# migration epic (D3.7) and is RED until that migration runs.
extends GdUnitTestSuite

# A bare level root that declares none of the LevelRoot exports, matching
# main.gd as it stands today.
class BareRoot extends Node2D:
	pass


func _make_bucket(node_name: String) -> Bucket:
	var bucket := Bucket.new()
	bucket.name = node_name
	return bucket


func _make_plant(node_name: String, required: int) -> Plant:
	var plant := Plant.new()
	plant.name = node_name
	plant.buckets_required = required
	return plant


# ── the file exists and declares its contract ────────────────────────────────

func test_all_seven_finding_codes_are_declared() -> void:
	# The last three are declared now and consumed later. V_PROP_BUDGET in
	# particular discharges the "specified with its constant in place" condition
	# the epic placed on ADR-0006.
	assert_str(LevelValidation.V_BUCKET_SUM).is_equal("V-BUCKET-SUM")
	assert_str(LevelValidation.V_PLANT_MIN).is_equal("V-PLANT-MIN")
	assert_str(LevelValidation.V_OXY_CAP).is_equal("V-OXY-CAP")
	assert_str(LevelValidation.V_GRAV_EXPORT).is_equal("V-GRAV-EXPORT")
	assert_str(LevelValidation.V_PROP_BUDGET).is_equal("V-PROP-BUDGET")
	assert_str(LevelValidation.V_WIRING).is_equal("V-WIRING")
	assert_str(LevelValidation.V_BOUNDS).is_equal("V-BOUNDS")


# ── count_buckets() ──────────────────────────────────────────────────────────

func test_count_buckets_returns_zero_on_an_empty_level() -> void:
	var level := auto_free(BareRoot.new()) as Node2D
	assert_int(LevelValidation.count_buckets(level)).is_equal(0)


func test_count_buckets_finds_direct_children() -> void:
	var level := auto_free(BareRoot.new()) as Node2D
	level.add_child(_make_bucket("Bucket1"))
	level.add_child(_make_bucket("Bucket2"))
	assert_int(LevelValidation.count_buckets(level)).is_equal(2)


func test_count_buckets_finds_buckets_at_any_depth() -> void:
	# The depth case is why discovery is a recursion rather than one
	# get_children() pass. A bucket parented under a container three levels down
	# is still a bucket in this level.
	var level := auto_free(BareRoot.new()) as Node2D
	var depth_one := Node2D.new()
	var depth_two := Node2D.new()
	var depth_three := Node2D.new()
	level.add_child(depth_one)
	depth_one.add_child(depth_two)
	depth_two.add_child(depth_three)
	depth_three.add_child(_make_bucket("DeepBucket"))
	level.add_child(_make_bucket("ShallowBucket"))
	assert_int(LevelValidation.count_buckets(level)).is_equal(2)


func test_count_buckets_finds_nodes_with_no_owner() -> void:
	# This is the find_children(owned = true) trap, asserted directly. Nodes
	# built in code have no owner, and a discovery mechanism that filters on
	# owner would report zero here while the level really holds two buckets.
	var level := auto_free(BareRoot.new()) as Node2D
	var first := _make_bucket("Orphan1")
	var second := _make_bucket("Orphan2")
	level.add_child(first)
	level.add_child(second)
	assert_object(first.owner) \
		.override_failure_message("Precondition failed: this bucket has an owner, so the test proves nothing.") \
		.is_null()
	assert_int(LevelValidation.count_buckets(level)).is_equal(2)


func test_count_buckets_ignores_non_bucket_nodes() -> void:
	var level := auto_free(BareRoot.new()) as Node2D
	level.add_child(_make_plant("Plant1", 1))
	level.add_child(Node2D.new())
	level.add_child(_make_bucket("Bucket1"))
	assert_int(LevelValidation.count_buckets(level)).is_equal(1)


func test_count_buckets_is_zero_on_a_null_level() -> void:
	assert_int(LevelValidation.count_buckets(null)).is_equal(0)


# ── validate() contract guarantees (Validation Criterion 6) ──────────────────

func test_validate_returns_empty_on_a_fully_satisfying_level() -> void:
	# Built to satisfy every implemented rule, so the scaffold has a proven
	# green case. Without one, every later assertion could be passing for the
	# wrong reason.
	var level := auto_free(SatisfyingRoot.new()) as Node2D
	level.player = auto_free(Node2D.new())
	level.goal = auto_free(Node2D.new())
	level.hud = auto_free(Node2D.new())
	level.level_bounds = auto_free(Node2D.new())
	level.add_child(_make_plant("Plant1", 2))
	level.add_child(_make_bucket("Bucket1"))
	level.add_child(_make_bucket("Bucket2"))
	assert_array(LevelValidation.validate(level)) \
		.override_failure_message("A level satisfying every rule must return no findings.") \
		.is_empty()


func test_validate_is_idempotent() -> void:
	# ADR-0003 Validation Criterion 6: validate() mutates nothing, so calling it
	# twice is identical to calling it once.
	var level := auto_free(BareRoot.new()) as Node2D
	level.add_child(_make_plant("Plant1", 3))
	var first := LevelValidation.validate(level)
	var second := LevelValidation.validate(level)
	assert_array(first).is_equal(second)
	assert_int(first.size()) \
		.override_failure_message("This level breaches rules; an empty result means nothing was compared.") \
		.is_greater(0)


func test_validate_does_not_mutate_the_level() -> void:
	var level := auto_free(BareRoot.new()) as Node2D
	var plant := _make_plant("Plant1", 3)
	level.add_child(plant)
	var child_count_before := level.get_child_count()
	LevelValidation.validate(level)
	assert_int(level.get_child_count()).is_equal(child_count_before)
	assert_int(plant.buckets_required).is_equal(3)


func test_validate_returns_empty_on_a_null_level() -> void:
	assert_array(LevelValidation.validate(null)).is_empty()


# A synthetic root declaring every export the implemented rules read, all valid.
class SatisfyingRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: Node = null
	var goal: Node = null
	var hud: Node = null
	var level_bounds: Node = null
