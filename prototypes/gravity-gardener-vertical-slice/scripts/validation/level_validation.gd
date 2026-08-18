# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Pure function — never pushes an error itself; the caller (LevelRoot) iterates the
# result and push_error()s each finding (ADR-0003). Discovery is by recursive
# get_children() type scan, never group membership (get_nodes_in_group is a
# SceneTree method, unavailable when a level is instantiated but never added to a
# tree — the CI path). Never uses find_children() with its default owned=true.
#
# This slice implements 5 of the project's 7 validation rules: V-BUCKET-SUM,
# V-PLANT-MIN, V-OXY-CAP, V-GRAV-EXPORT, V-WIRING. V-PROP-BUDGET and V-BOUNDS
# belong to ADR-0011 (physics props), which is out of this slice's scope.
class_name LevelValidation
extends RefCounted

static func validate(level_root: Node) -> PackedStringArray:
	var findings: PackedStringArray = []
	var descendants: Array[Node] = _all_descendants(level_root)

	var plants: Array[Plant] = []
	var bucket_count: int = 0
	for n in descendants:
		if n is Plant:
			plants.append(n)
		elif n is Bucket:
			bucket_count += 1

	# V-BUCKET-SUM (watering-system.md R8)
	var required_sum: int = 0
	for plant in plants:
		required_sum += plant.buckets_required
	if bucket_count != required_sum:
		findings.append("[V-BUCKET-SUM] buckets_total (%d) != sum of buckets_required (%d)" % [bucket_count, required_sum])

	# V-PLANT-MIN
	if plants.is_empty():
		findings.append("[V-PLANT-MIN] level has no Plant nodes")

	# V-OXY-CAP (suit-oxygen.md §5)
	if level_root.oxygen_capacity <= 0.0:
		findings.append("[V-OXY-CAP] oxygen_capacity must be > 0, got %f" % level_root.oxygen_capacity)

	# V-GRAV-EXPORT (ADR-0001)
	if level_root.default_gravity_direction.is_zero_approx():
		findings.append("[V-GRAV-EXPORT] default_gravity_direction must not be zero")

	# V-WIRING (ADR-0010 D10.9 — Required consumer once ADR-0010 is Accepted)
	if level_root.hud_path.is_empty() or level_root.get_node_or_null(level_root.hud_path) == null:
		findings.append("[V-WIRING] hud NodePath export does not resolve to a node")

	return findings


## Shared static primitive, used both by V-BUCKET-SUM and by LevelRoot to seed
## LevelState (ADR-0003 D3.5).
static func count_buckets(level_root: Node) -> int:
	var count: int = 0
	for n in _all_descendants(level_root):
		if n is Bucket:
			count += 1
	return count


## Shared with LevelRoot so plant-candidate wiring uses the same discovery method
## as validation, rather than a second recursive scan.
static func find_plants(level_root: Node) -> Array[Plant]:
	var plants: Array[Plant] = []
	for n in _all_descendants(level_root):
		if n is Plant:
			plants.append(n)
	return plants


static func _all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result
