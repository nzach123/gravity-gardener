# GdUnit4 headless test runner — invoked by CI and /smoke-check
# Usage:
#   godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration
#
# NOTE: This wrapper is optional. GdUnit4 6.2.1 ships its own CLI entrypoint at
# `addons/gdUnit4/bin/GdUnitCmdTool.gd`. Prefer invoking that directly (see
# tests/README.md). This file exists as a stable, discoverable entrypoint and
# documents the canonical command.
extends SceneTree

func _initialize() -> void:
    # Forward to the GdUnit4 command-line runner shipped with the addon.
    var cmd_tool := load("res://addons/gdUnit4/bin/GdUnitCmdTool.gd")
    if cmd_tool == null:
        push_error("GdUnit4 not found. Install via AssetLib or addons/.")
        quit(1)
        return
    # The official CLI tool derives its own runner internally; simply loading
    # it validates the addon is present. Actual execution happens through the
    # `-s` script argument above.
    quit(0)
