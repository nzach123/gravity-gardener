# V-WIRING and the combined report-all-failures gate (ADR-0003 D3.3 and
# Validation Criterion 1). Story 004 of the level-validation epic.
#
# V-WIRING checks WIRING, not BINDING. Under D3.1 validate() runs at step (a) and
# bind() at step (c), so binding has not happened and cannot be observed. What can
# be observed is that each required export holds a live node — the condition under
# which step (c) will succeed. A consumer that is wired but whose bind() call was
# never written is caught later by the ADR-0002 per-consumer guard. Neither check
# subsumes the other.
#
# THE TABLE HAS FOUR ROWS, and the fourth section of this file is what stops that
# number drifting. ADR-0003's printed table still shows three rows and marks `hud`
# as "admitted when ADR-0010 is Accepted" — ADR-0010 and ADR-0011 are both now
# Accepted, and D3.3's own admission rule says an Accepted ADR admits its
# consumer. The printed table is stale prose; the four rows are what the accepted
# decisions require. Flagged for a doc-only amendment, not resolved here.
extends GdUnitTestSuite

# Declares all four consumer exports plus the root exports the other rules read,
# so a single row can be unwired per test without other rules contaminating the
# count.
class WiredRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: Node = null
	var goal: Node = null
	var hud: Node = null
	var level_bounds: Node = null


# Declares none of the four. Stands in for main.gd, which today declares `player`,
# `goal`, `bucket`, `next_level` and two camera flags — so `hud` and
# `level_bounds` are absent rather than empty.
class UnwiredRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0


# The NodePath authoring shape ADR-0003 D3.3 describes, as opposed to the direct
# node references main.gd uses. Both must satisfy the rule.
class NodePathRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: NodePath = NodePath("")
	var goal: NodePath = NodePath("")
	var hud: NodePath = NodePath("")
	var level_bounds: NodePath = NodePath("")


const EXPECTED_CONSUMERS: Array[String] = ["player", "goal", "hud", "level_bounds"]


func _make_wired_root() -> Node2D:
	var level := auto_free(WiredRoot.new()) as Node2D
	for export_name: String in EXPECTED_CONSUMERS:
		level.set(export_name, auto_free(Node2D.new()))
	return level


func _make_node_path_root() -> Node2D:
	var level := auto_free(NodePathRoot.new()) as Node2D
	for export_name: String in EXPECTED_CONSUMERS:
		var child := Node2D.new()
		child.name = export_name.to_pascal_case()
		level.add_child(child)
		level.set(export_name, level.get_path_to(child))
	return level


func _count_code(findings: PackedStringArray, code: String) -> int:
	var total := 0
	for finding: String in findings:
		if finding.begins_with("[%s]" % code):
			total += 1
	return total


func _wiring_findings(findings: PackedStringArray) -> Array[String]:
	var matched: Array[String] = []
	for finding: String in findings:
		if finding.begins_with("[%s]" % LevelValidation.V_WIRING):
			matched.append(finding)
	return matched


# ── the table itself ─────────────────────────────────────────────────────────

func test_required_consumer_table_holds_exactly_four_rows() -> void:
	# Adding a consumer must be a one-line table edit, so the table is asserted
	# directly rather than inferred from behaviour. A fifth row added without an
	# Accepted ADR fails here, which is the point.
	assert_array(LevelValidation.REQUIRED_CONSUMERS) \
		.contains_exactly_in_any_order(EXPECTED_CONSUMERS)


func test_oxygen_drain_is_not_in_the_table() -> void:
	# ADR-0002 part 4 makes OxygenDrain a CHILD of LevelRoot, not an export, so
	# there is no path for this rule to resolve. Its binding failure mode is the
	# ADR-0002 per-consumer guard instead.
	assert_array(LevelValidation.REQUIRED_CONSUMERS).not_contains(["oxygen_drain"])


# ── V-WIRING ─────────────────────────────────────────────────────────────────

func test_wiring_passes_when_every_consumer_resolves() -> void:
	var level := _make_wired_root()
	assert_array(_wiring_findings(LevelValidation.validate(level))) \
		.override_failure_message("A fully wired level must produce no V-WIRING finding.") \
		.is_empty()


func test_wiring_fires_once_per_unwired_consumer() -> void:
	var level := _make_wired_root()
	level.set("hud", null)
	level.set("level_bounds", null)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_WIRING)).is_equal(2)


func test_wiring_fires_for_each_of_the_four_consumers_individually() -> void:
	# Every row is exercised. A table-driven rule that silently skipped one row
	# would still pass a test that only unwired `player`.
	for export_name: String in EXPECTED_CONSUMERS:
		var level := _make_wired_root()
		level.set(export_name, null)
		var findings := _wiring_findings(LevelValidation.validate(level))
		assert_int(findings.size()) \
			.override_failure_message("Unwiring \"%s\" produced %d findings, expected 1." % [export_name, findings.size()]) \
			.is_equal(1)
		assert_str(findings[0]) \
			.override_failure_message("The finding for \"%s\" does not name the export." % export_name) \
			.contains(export_name)


func test_wiring_fires_when_the_export_is_absent_entirely() -> void:
	# Absent and empty are the same condition: the level is not wired. This is
	# what lets a row be added to the table before the export exists anywhere.
	var level := auto_free(UnwiredRoot.new()) as Node2D
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_WIRING)).is_equal(4)


func test_wiring_fires_when_a_consumer_points_at_a_freed_node() -> void:
	# Non-null but dead. Resolution means a LIVE node, so a null check alone
	# would report this level clean.
	var level := _make_wired_root()
	var doomed := Node2D.new()
	level.set("goal", doomed)
	doomed.free()
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_WIRING)).is_equal(1)


func test_wiring_passes_on_node_paths_that_resolve() -> void:
	# The case a NodePath-shaped LevelRoot would hit on every correctly wired
	# level. Before this shape was handled, the rule reported all four consumers
	# unwired no matter how carefully the level was authored.
	var level := _make_node_path_root()
	assert_array(_wiring_findings(LevelValidation.validate(level))).is_empty()


func test_wiring_fires_on_an_empty_node_path_export() -> void:
	# An empty NodePath is the unset case for this authoring shape.
	var level := _make_node_path_root()
	level.set("player", NodePath(""))
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_WIRING)).is_equal(1)


func test_wiring_fires_on_a_node_path_that_points_nowhere() -> void:
	# Non-empty but dangling. A "non-empty" check alone would report this clean.
	var level := _make_node_path_root()
	level.set("goal", NodePath("NoSuchChild"))
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_WIRING)).is_equal(1)


func test_wiring_does_not_call_methods_on_the_resolved_node() -> void:
	# Resolution, not binding. A plain Node with no script satisfies the rule —
	# if the rule ever started asking the node questions, this would break.
	var level := _make_wired_root()
	level.set("player", auto_free(Node.new()))
	assert_array(_wiring_findings(LevelValidation.validate(level))).is_empty()


# ── ADR-0003 Validation Criterion 1: report ALL failures, never the first ────

func test_a_level_breaching_every_implemented_rule_reports_every_code() -> void:
	# The gate this whole contract exists for. One finding per code, not one
	# finding and not a partial set. Scoped to the five rules live after stories
	# 002-004; story 006's two join when they land.
	var level := auto_free(UnwiredRoot.new()) as Node2D
	level.set("oxygen_capacity", 0.0)
	level.set("default_gravity_direction", Vector2.ZERO)
	level.set("default_gravity_multiplier", 0.0)

	var plant := Plant.new()
	plant.name = "BrokenPlant"
	plant.buckets_required = 0
	level.add_child(plant)

	var bucket := Bucket.new()
	bucket.name = "StrayBucket"
	level.add_child(bucket)

	var findings := LevelValidation.validate(level)

	assert_int(_count_code(findings, LevelValidation.V_PLANT_MIN)) \
		.override_failure_message("V-PLANT-MIN did not fire.").is_equal(1)
	assert_int(_count_code(findings, LevelValidation.V_BUCKET_SUM)) \
		.override_failure_message("V-BUCKET-SUM did not fire (1 bucket vs required sum 0).").is_equal(1)
	assert_int(_count_code(findings, LevelValidation.V_OXY_CAP)) \
		.override_failure_message("V-OXY-CAP did not fire.").is_equal(1)
	assert_int(_count_code(findings, LevelValidation.V_GRAV_EXPORT)) \
		.override_failure_message("V-GRAV-EXPORT did not fire for both halves.").is_equal(2)
	assert_int(_count_code(findings, LevelValidation.V_WIRING)) \
		.override_failure_message("V-WIRING did not fire for all four consumers.").is_equal(4)

	# Nine findings, five codes. The count is asserted so that a rule added
	# without a test cannot slip in unnoticed.
	assert_int(findings.size()).is_equal(9)


func test_the_unimplemented_rules_never_fire() -> void:
	# V-PROP-BUDGET and V-BOUNDS have constants but no logic (story 006). If
	# either starts firing before its story lands, that is a defect, not
	# progress.
	var level := auto_free(UnwiredRoot.new()) as Node2D
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_PROP_BUDGET)).is_equal(0)
	assert_int(_count_code(findings, LevelValidation.V_BOUNDS)).is_equal(0)
