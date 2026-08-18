# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# A setter, not a field (gravity.md R2) — reports its direction/multiplier to
# GravityAuthority.set_gravity() directly. Never connects to the player or calls a
# Player method (ADR-0001 zone_targets_player_directly is forbidden).
# collision_layer = 0, collision_mask = PLAYER (ADR-0004) — set on the .tscn.
class_name GravityZone
extends Area2D

@export var zone_gravity_direction: Vector2 = Vector2.DOWN
## Multiple of the player's derived baseline gravity (gravity.md R7). 1.0 =
## baseline, 0.5 = low gravity (higher jumps), 2.0 = heavy (lower jumps).
@export var zone_gravity_multiplier: float = 1.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GravityAuthority.set_gravity(zone_gravity_direction.normalized(), zone_gravity_multiplier)
