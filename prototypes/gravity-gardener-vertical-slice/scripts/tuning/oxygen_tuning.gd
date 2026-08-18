# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# One of three Resource subclasses, one per GDD (ADR-0006 D6.1).
class_name OxygenTuning
extends Resource

## Slack over the theoretical minimum route (suit-oxygen.md §4/§7).
@export_range(0.3, 0.6) var margin: float = 0.4

## Accessibility hook only — leave at 1.0 so oxygen_capacity reads as real
## seconds (suit-oxygen.md "Why drain_rate stays at 1.0").
@export_range(0.5, 1.0) var drain_rate: float = 1.0

@export_range(0.0, 1.0) var threshold_caution: float = 0.50
@export_range(0.0, 1.0) var threshold_warning: float = 0.25
@export_range(0.0, 1.0) var threshold_critical: float = 0.10
