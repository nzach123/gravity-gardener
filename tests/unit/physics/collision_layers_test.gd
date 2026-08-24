# Collision layer invariant suite (ADR-0004 D4.5, Validation Criterion 1).
#
# This is the enforcement half of the CollisionLayers registry. The registry
# (src/scripts/collision_layers.gd) declares what the four allocated bits mean;
# this suite asserts that every authored scene actually obeys them.
#
# It instantiates each scene via PackedScene.instantiate() WITHOUT adding it to
# the SceneTree. Per ADR-0004 L5, collision_layer / collision_mask are plain
# integer properties populated by the node->set(...) loop inside
# SceneState::instantiate(), so they are readable headlessly without _ready().
# Per L6, ProjectSettings.get_setting() is a static configuration read and is
# likewise headless-safe.
#
# STANDING RULE (ADR-0004 D4.5 / F6): scene layer and mask values are asserted
# as derived bit tests (`mask & LAYER == 0`), never as raw integer equality.
# Raw equality breaks the moment an unrelated bit is legitimately added, even
# though the isolation guarantee still holds. The only exact-value assertions
# here are on the registry constants themselves (group 0), where the value IS
# the definition, and on collision_layer == 0, which means "occupies no layer
# at all" rather than "equals some particular bit".
extends GdUnitTestSuite
@warning_ignore("return_value_discarded")

const SCENES_ROOT: String = "res://src/scenes"
const SHARED_TILESET: String = "res://src/resources/Simple_tileset.tres"
const PLAYER_SCENE: String = "res://src/scenes/player/player.tscn"
const MOVING_PLATFORM_SCENE: String = "res://src/scenes/moving_platform.tscn"

# The five interactables ADR-0004 defect 4 enumerates. Named rather than
# derived, so that "these are detectors" is an assertion and not a tautology:
# classifying by `collision_layer == 0` and then asserting it equals 0 would
# prove nothing. Group 2's scan, by contrast, must stay a directory walk.
const INTERACTABLE_SCENES: Array[String] = [
	"res://src/scenes/bucket.tscn",
	"res://src/scenes/goal.tscn",
	"res://src/scenes/gravity_zone.tscn",
	"res://src/scenes/plant.tscn",
	"res://src/scenes/spike_hazard.tscn",
]

# Anti-vacuous-pass floors. Groups 1-3 all loop over discovered nodes, and a
# scan that finds nothing passes silently. These floors sit below the current
# counts (18 scenes, 9 TileMapLayers) so that legitimate authoring does not
# trip them, but far enough above zero that a broken glob fails loudly.
const MIN_SCENES: int = 15
const MIN_COLLISION_BODIES: int = 10
const MIN_TILEMAP_LAYERS: int = 9

const RETIRED_BIT_3: int = 4


# ── helpers ──────────────────────────────────────────────────────────────────

func _scan_scene_paths(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	assert_object(dir) \
		.override_failure_message("Could not open %s for scanning." % dir_path) \
		.is_not_null()
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_scene_paths(full, out)
		elif entry.ends_with(".tscn"):
			# Exact suffix only (T4.7) — never picks up .tscn*.tmp autosaves,
			# which .gitignore:39 excludes from VCS but a local scan can still see.
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _all_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	_scan_scene_paths(SCENES_ROOT, paths)
	paths.sort()
	return paths


# A malformed scene must fail loudly here rather than be skipped by a null
# guard, which would turn a broken scene into a silent green.
func _instantiate(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	assert_object(packed) \
		.override_failure_message("%s did not load as a PackedScene." % scene_path) \
		.is_not_null()
	var root := packed.instantiate()
	assert_object(root) \
		.override_failure_message("%s failed to instantiate." % scene_path) \
		.is_not_null()
	return auto_free(root)


func _collect_bodies(node: Node, out: Array[CollisionObject2D]) -> void:
	if node is CollisionObject2D:
		out.append(node as CollisionObject2D)
	for child: Node in node.get_children():
		_collect_bodies(child, out)


func _collect_tilemap_layers(node: Node, out: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		out.append(node as TileMapLayer)
	for child: Node in node.get_children():
		_collect_tilemap_layers(child, out)


func _bodies_in(scene_path: String) -> Array[CollisionObject2D]:
	var bodies: Array[CollisionObject2D] = []
	_collect_bodies(_instantiate(scene_path), bodies)
	return bodies


# ── Group 0 — registry constants (T1.1-T1.8) ─────────────────────────────────
#
# Exact values are correct here: these constants ARE the allocation table.

func test_world_bit_is_1() -> void:
	assert_int(CollisionLayers.WORLD).is_equal(1)


func test_player_bit_is_2() -> void:
	assert_int(CollisionLayers.PLAYER).is_equal(2)


func test_prop_bit_is_8() -> void:
	assert_int(CollisionLayers.PROP).is_equal(8)


func test_allocated_is_world_player_prop() -> void:
	# Load-bearing for group 2 — get this wrong and the unallocated-bit scan
	# silently stops catching things.
	assert_int(CollisionLayers.ALLOCATED).is_equal(11)
	assert_int(CollisionLayers.ALLOCATED) \
		.is_equal(CollisionLayers.WORLD | CollisionLayers.PLAYER | CollisionLayers.PROP)


func test_detector_layer_occupies_no_bit() -> void:
	assert_int(CollisionLayers.DETECTOR_LAYER).is_equal(0)


func test_detector_mask_watches_player() -> void:
	assert_int(CollisionLayers.DETECTOR_MASK & CollisionLayers.PLAYER).is_not_equal(0)


func test_player_mask_watches_world_but_never_prop() -> void:
	assert_int(CollisionLayers.PLAYER_MASK & CollisionLayers.WORLD).is_not_equal(0)
	assert_int(CollisionLayers.PLAYER_MASK & CollisionLayers.PROP).is_equal(0)


func test_prop_mask_watches_world_and_prop_but_never_player() -> void:
	assert_int(CollisionLayers.PROP_MASK & CollisionLayers.WORLD).is_not_equal(0)
	assert_int(CollisionLayers.PROP_MASK & CollisionLayers.PROP).is_not_equal(0)
	assert_int(CollisionLayers.PROP_MASK & CollisionLayers.PLAYER).is_equal(0)


func test_retired_bit_3_is_not_allocated() -> void:
	# A missing constant cannot be asserted directly, so this is a value test
	# (T1.8): whatever the registry declares, bit 3 must not be inside it.
	assert_int(CollisionLayers.ALLOCATED & RETIRED_BIT_3).is_equal(0)


# ── Group 1 — isolation invariants (D4.3 four-pair table) ────────────────────
#
# Bodies are classified by the bits they carry, not by class name, so the
# prop-side pairs start covering ADR-0011's PropBody the moment one is authored
# without this file changing. Per ADR-0004 there are no props yet, so those
# loops legitimately iterate zero times today — the floors in group 2 are what
# prove the scan itself is alive.

func _classify_all() -> Dictionary:
	var players: Array[CollisionObject2D] = []
	var props: Array[CollisionObject2D] = []
	for scene_path: String in _all_scene_paths():
		for body: CollisionObject2D in _bodies_in(scene_path):
			if body.collision_layer & CollisionLayers.PLAYER != 0:
				players.append(body)
			if body.collision_layer & CollisionLayers.PROP != 0:
				props.append(body)
	return {"players": players, "props": props}


func test_prop_never_masks_player() -> void:
	# T4.1. Body-vs-body pairing is an OR, not an AND (L3), so both directions
	# of every pair must be asserted — a one-sided mask still produces contact.
	var props: Array = _classify_all()["props"]
	for prop: CollisionObject2D in props:
		assert_int(prop.collision_mask & CollisionLayers.PLAYER) \
			.override_failure_message(
				"Prop '%s' masks PLAYER — breaks physics-props.md R1." % prop.name) \
			.is_equal(0)


func test_player_never_masks_prop() -> void:
	# T4.2 — the other half of the pair.
	var players: Array = _classify_all()["players"]
	assert_int(players.size()) \
		.override_failure_message("No player-layer body found in any scene.") \
		.is_greater_equal(1)
	for player: CollisionObject2D in players:
		assert_int(player.collision_mask & CollisionLayers.PROP) \
			.override_failure_message(
				"Player body '%s' masks PROP — breaks physics-props.md R1." % player.name) \
			.is_equal(0)


func test_interactables_are_detectors_that_never_mask_prop() -> void:
	# T4.3, plus the non-circular half of T4.4: the isolation of props from
	# interactables rests on interactables carrying no layer at all, so that is
	# asserted directly against the five scenes ADR-0004 defect 4 enumerates.
	for scene_path: String in INTERACTABLE_SCENES:
		var bodies := _bodies_in(scene_path)
		assert_int(bodies.size()) \
			.override_failure_message("%s declares no CollisionObject2D." % scene_path) \
			.is_greater_equal(1)
		for body: CollisionObject2D in bodies:
			assert_int(body.collision_layer) \
				.override_failure_message(
					"%s: '%s' occupies a collision layer; interactables are detectors "
					% [scene_path, body.name]
					+ "and must carry DETECTOR_LAYER (no bits).") \
				.is_equal(CollisionLayers.DETECTOR_LAYER)
			assert_int(body.collision_mask & CollisionLayers.PROP) \
				.override_failure_message(
					"%s: '%s' masks PROP." % [scene_path, body.name]) \
				.is_equal(0)
			assert_int(body.collision_mask & CollisionLayers.PLAYER) \
				.override_failure_message(
					"%s: '%s' does not watch PLAYER." % [scene_path, body.name]) \
				.is_not_equal(0)


func test_prop_never_masks_interactable_layer() -> void:
	# T4.4. Holds by construction while DETECTOR_LAYER is 0 — nothing can mask a
	# body that occupies no layer. Kept explicit so the pair table is complete;
	# the load-bearing half is the DETECTOR_LAYER assertion in the test above,
	# which is what would actually go red if an interactable gained a layer.
	var props: Array = _classify_all()["props"]
	for prop: CollisionObject2D in props:
		assert_int(prop.collision_mask & CollisionLayers.DETECTOR_LAYER) \
			.override_failure_message(
				"Prop '%s' masks the interactable layer." % prop.name) \
			.is_equal(0)


# ── Group 2 — no scene claims an unallocated bit ─────────────────────────────

func test_no_scene_uses_an_unallocated_bit() -> void:
	# T4.5-T4.7. Scene list is a directory walk, never a hardcoded array, so a
	# newly authored scene is covered the moment it lands.
	var scene_paths := _all_scene_paths()
	assert_int(scene_paths.size()) \
		.override_failure_message(
			"Scene scan found %d scenes under %s; expected at least %d. "
			% [scene_paths.size(), SCENES_ROOT, MIN_SCENES]
			+ "A broken scan must fail, not pass vacuously.") \
		.is_greater_equal(MIN_SCENES)

	var checked := 0
	for scene_path: String in scene_paths:
		for body: CollisionObject2D in _bodies_in(scene_path):
			var claimed := body.collision_layer | body.collision_mask
			assert_int(claimed & ~CollisionLayers.ALLOCATED) \
				.override_failure_message(
					"%s: '%s' claims a bit outside ALLOCATED (layer=%d mask=%d). "
					% [scene_path, body.name, body.collision_layer, body.collision_mask]
					+ "Bit 3 is retired and bits 5-32 are unallocated — "
					+ "claiming one requires amending ADR-0004.") \
				.is_equal(0)
			checked += 1

	assert_int(checked) \
		.override_failure_message("Scanned %d scenes but found no collision bodies." % scene_paths.size()) \
		.is_greater_equal(MIN_COLLISION_BODIES)


# ── Group 3 — every TileSet physics layer is WORLD ───────────────────────────

func test_every_tileset_physics_layer_is_world() -> void:
	# T4.8. Covers the five inline sub-resources (levels 03-06, test_main) and
	# the shared resource the other four levels point at, in one walk.
	var found := 0
	for scene_path: String in _all_scene_paths():
		var layers: Array[TileMapLayer] = []
		_collect_tilemap_layers(_instantiate(scene_path), layers)
		for tilemap: TileMapLayer in layers:
			assert_object(tilemap.tile_set) \
				.override_failure_message("%s: '%s' has no TileSet." % [scene_path, tilemap.name]) \
				.is_not_null()
			if tilemap.tile_set == null:
				continue
			assert_int(tilemap.tile_set.get_physics_layers_count()) \
				.override_failure_message(
					"%s: '%s' TileSet declares no physics layer." % [scene_path, tilemap.name]) \
				.is_greater_equal(1)
			assert_int(tilemap.tile_set.get_physics_layer_collision_layer(0)) \
				.override_failure_message(
					"%s: '%s' terrain is not on WORLD." % [scene_path, tilemap.name]) \
				.is_equal(CollisionLayers.WORLD)
			found += 1

	assert_int(found) \
		.override_failure_message(
			"Found %d TileMapLayers; expected at least %d." % [found, MIN_TILEMAP_LAYERS]) \
		.is_greater_equal(MIN_TILEMAP_LAYERS)


func test_shared_tileset_physics_layer_is_world() -> void:
	# T4.9. Asserted independently of any scene: ADR-0004 migration step 6 wants
	# this resource to state its layer explicitly rather than inherit a default,
	# so it is worth a direct check even though the walk above also reaches it.
	var tileset := load(SHARED_TILESET) as TileSet
	assert_object(tileset).is_not_null()
	assert_int(tileset.get_physics_layers_count()).is_greater_equal(1)
	assert_int(tileset.get_physics_layer_collision_layer(0)).is_equal(CollisionLayers.WORLD)


# ── Group 4 — project.godot agrees with the constants (T1.9-T1.12) ───────────

func test_project_godot_layer_names_match_the_registry() -> void:
	assert_str(_layer_name(1)).is_equal("world")
	assert_str(_layer_name(2)).is_equal("player")
	assert_str(_layer_name(4)).is_equal("prop")


func test_project_godot_does_not_name_retired_bit_3() -> void:
	# T1.11. Assert the VALUE is empty, not merely that it is no longer "item" —
	# a rename would satisfy an inequality check and is exactly what D4.2 forbids.
	# has_setting() is unusable here: it returns true for every 2D layer slot,
	# declared or not, because the slots are pre-registered engine settings.
	assert_str(_layer_name(3)) \
		.override_failure_message("Bit 3 is retired (D4.2) and must not be named.") \
		.is_equal("")


func _layer_name(bit_index: int) -> String:
	return str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % bit_index, ""))


# ── Group 5 — absence cases inherited from story 003 (T3.1-T3.3) ─────────────

func test_player_scene_has_no_vestigial_area_node() -> void:
	# T3.1 — the named node is gone.
	var player := _instantiate(PLAYER_SCENE)
	assert_object(player.find_child("PlayerArea2D", true, false)) \
		.override_failure_message("PlayerArea2D is vestigial (ADR-0004 defect 2) and must be deleted.") \
		.is_null()


func test_player_scene_has_no_area2d_descendant() -> void:
	# T3.2 — catches a rename-instead-of-delete, which T3.1 alone would miss.
	var areas: Array[CollisionObject2D] = []
	_collect_bodies(_instantiate(PLAYER_SCENE), areas)
	for body: CollisionObject2D in areas:
		assert_bool(body is Area2D) \
			.override_failure_message(
				"Player scene still has an Area2D descendant ('%s')." % body.name) \
			.is_false()


func test_moving_platform_mask_is_the_engine_default() -> void:
	# T3.3. The authored `collision_mask = 2` line is deleted (ADR-0004 defect 3),
	# leaving CollisionObject2D's default of 1 — NOT 0. Verified by direct probe
	# on Godot 4.7.1. Per L4 an animatable body's own mask is never evaluated for
	# its own motion, so the residual 1 is as inert as the 2 it replaced; what
	# this asserts is that nothing reads as deliberate configuration.
	var bodies := _bodies_in(MOVING_PLATFORM_SCENE)
	var animatables := 0
	for body: CollisionObject2D in bodies:
		if body is AnimatableBody2D:
			assert_int(body.collision_mask) \
				.override_failure_message(
					"'%s' declares a deliberate mask; ADR-0004 defect 3 requires none." % body.name) \
				.is_equal(1)
			animatables += 1
	assert_int(animatables) \
		.override_failure_message("moving_platform.tscn has no AnimatableBody2D.") \
		.is_equal(1)
