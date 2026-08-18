# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Const-only script, not on LevelRoot — GravityAuthority is an autoload present
# before any level scene loads (ADR-0005 A5-05, control-manifest Core Layer).
class_name FramePriority
extends RefCounted

const GRAVITY_AUTHORITY: int = -100
const PLAYER: int = 0
const OXYGEN_DRAIN: int = 100
