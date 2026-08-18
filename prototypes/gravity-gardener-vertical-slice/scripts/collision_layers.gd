# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Authoritative source for collision bits (ADR-0004 D4.1/D4.4). project.godot's
# layer_names are editor-facing cosmetic only.
class_name CollisionLayers
extends RefCounted

const WORLD: int = 1
const PLAYER: int = 2
# bit 3 is RETIRED — never claim it (ADR-0004)
const PROP: int = 8  # reserved by ADR-0004's allocation; unused — props are out of this slice's scope
