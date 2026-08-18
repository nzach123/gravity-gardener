# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Holds NO process_physics_priority — no per-frame rule-bearing work lives here once
# pour-driving moved to PlayerWateringComponent (ADR-0009). Never writes level-wide
# state or decides level completion — emits pour_completed and holds no level state.
# class_name is required — LevelValidation's type scan depends on it (ADR-0003).
class_name Plant
extends Node2D

signal player_entered_range
signal player_exited_range
signal pour_completed

## Primary risk dial — sets plant size and round trips demanded (watering-system.md §7).
@export_range(1, 4) var buckets_required: int = 1
@export_range(2.0, 8.0) var water_duration: float = 5.0

var buckets_received: int = 0

## Placeholder-quality: a plain Polygon2D stands in for growth-stage sprite frames.
@onready var sprite: Polygon2D = $Polygon2D
@onready var interact_area: Area2D = $InteractArea2D

var growth_fraction: float:
	get: return float(buckets_received) / float(buckets_required)


func _ready() -> void:
	_update_visual()


func is_capped() -> bool:
	return buckets_received >= buckets_required


## Called by PlayerWateringComponent on pour completion. A capped plant refuses
## further pours outright — the interaction never engages (watering-system.md R5).
func receive_bucket() -> void:
	if is_capped():
		return
	buckets_received += 1
	pour_completed.emit()
	_update_visual()


func _update_visual() -> void:
	sprite.color = Color.LIME_GREEN if is_capped() else Color.DARK_OLIVE_GREEN.lerp(Color.LIME_GREEN, growth_fraction)


## The interact prompt is suppressed for a capped plant so the refusal is legible
## rather than silent (watering-system.md §5).
func _on_interact_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and not is_capped():
		player_entered_range.emit()


func _on_interact_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		player_exited_range.emit()
