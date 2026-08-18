# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Scene autoload (not a bare script), so @export_range gets inspector surface
# (ADR-0008). No class_name, same rationale as GravityAuthority — reached only via
# the autoload singleton name.
extends Node

@export_range(0.5, 1.0) var drain_rate_multiplier: float = 1.0:
	set(value):
		drain_rate_multiplier = clampf(value, 0.5, 1.0)

func set_drain_rate_multiplier(value: float) -> void:
	drain_rate_multiplier = value
