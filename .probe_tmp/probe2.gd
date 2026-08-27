extends SceneTree

func _initialize() -> void:
	var t: Variant = load("res://.probe_tmp/target.gd").new()
	print("F_typed_assigner_loading...")
	var c: Variant = load("res://.probe_tmp/assign_typed.gd")
	print("F_loaded null=", c == null)
	if c == null:
		print("F_RESULT PARSE_ERROR — typed direct assignment is rejected at COMPILE time")
	else:
		print("F_RESULT PARSED — calling")
		var inst: Variant = c.new()
		inst.go(t)
		print("F_after_call value=", t.value)
	print("PROBE2_DONE")
	quit()
