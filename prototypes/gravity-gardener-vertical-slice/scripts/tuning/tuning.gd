# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Const holder. Consumers reach tuning ONLY through Tuning.WATERING / .OXYGEN — no
# consumer names a .tres path itself (ADR-0006 D6.3). preload(), never load(), so a
# missing/renamed file fails loudly at parse time (D6.6-equivalent rationale).
# NOT an autoload and must never become one — preload already gives universal reach.
class_name Tuning
extends RefCounted

const WATERING: WateringTuning = preload("res://resources/tuning/watering_tuning.tres")
const OXYGEN: OxygenTuning = preload("res://resources/tuning/oxygen_tuning.tres")
