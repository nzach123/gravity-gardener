extends SceneTree

func _initialize() -> void:
	var t: Variant = load("res://.probe_tmp/target.gd").new()
	print("A_baseline value=", t.value, " flag=", t.flag)

	t.set("value", 99)
	print("B_set_on_getter_only value_now=", t.value)

	t.set("nonexistent", 5)
	print("C_set_on_missing_prop survived=true")

	var a: Variant = load("res://.probe_tmp/assign_getter_only.gd")
	print("D_assigner_loaded null=", a == null)
	if a != null:
		print("D_PARSED_OK calling now")
		var inst: Variant = a.new()
		inst.go(t)
		print("D_after_call value=", t.value)

	var b: Variant = load("res://.probe_tmp/assign_rw.gd")
	if b != null:
		var inst2: Variant = b.new()
		inst2.go(t)
		print("E_negative_control flag=", t.flag)
	print("PROBE_DONE")
	quit()
