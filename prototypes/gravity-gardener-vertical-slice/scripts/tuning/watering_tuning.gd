# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# One of three Resource subclasses, one per GDD (ADR-0006 D6.1). Read-only at
# runtime — no writes, no .duplicate() (D6.5). resource_local_to_scene stays false
# (D6.9).
class_name WateringTuning
extends Resource

## Return-leg speed multiplier while carrying a bucket (watering-system.md R2).
@export_range(0.4, 0.9) var carry_speed_multiplier: float = 0.6

## Spent-jug throw arc, cosmetic only (watering-system.md R7 / ADR-0012).
@export_range(60.0, 200.0) var throw_arc_height: float = 120.0
@export_range(0.4, 0.8) var throw_duration: float = 0.6
@export_range(0.0, 90.0) var throw_angle_spread: float = 45.0
