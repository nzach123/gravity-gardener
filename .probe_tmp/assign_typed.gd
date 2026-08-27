extends RefCounted

const Target := preload("res://.probe_tmp/target.gd")

func go(o: Target) -> void:
	o.value = 42
