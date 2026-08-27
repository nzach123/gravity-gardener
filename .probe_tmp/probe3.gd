extends SceneTree

const Target := preload("res://.probe_tmp/target.gd")

func _initialize() -> void:
	var t := Target.new()
	print("G_before value=", t.value)
	t.value = 55                      # typed, in-script, direct assignment
	print("G_after  value=", t.value)

	print("H_control — the next line SHOULD raise, proving errors surface here")
	var arr: Array = []
	print("H_control_read=", arr[9])   # out of bounds -> must error
	print("PROBE3_DONE")
	quit()
