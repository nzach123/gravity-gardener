# Godot — Deprecated APIs (4.4 → 4.7.1)

Last verified: 2026-08-15

## General Guidance

Godot maintains backward compatibility within the 4.x cycle. Most deprecated
APIs still work but emit warnings. Always prefer the replacement API.

## Known Deprecations

| Version | Deprecated API | Replacement | Notes |
|---------|---------------|-------------|-------|
| 4.6 | Bullet physics (as default) | Jolt Physics (native) | Bullet is still available but Jolt is default for 3D |
| 4.7 | `RichTextLabel.add_image(..., width_in_percent, height_in_percent)` | `width_unit` / `height_unit` taking `RichTextLabel.ImageUnit` | Also `int` → `float` for `width`/`height`. GH-112617 |
| 4.7 | `RichTextLabel.update_image(...)` — same parameters | Same replacement as `add_image()` | GH-112617 |
| 4.7 | `DisplayServer.AccessibilityLiveMode` (as the type of `Control.accessibility_live`) | `AccessibilityServer.AccessibilityLiveMode` | GDScript call sites unaffected; C# breaks |
| 4.7 | `AudioEffectSpectrumAnalyzer.tap_back_pos` | *(removed, no replacement)* | GH-114355 |

> A previous revision listed "various Control offset behaviors" as deprecated in 4.7.
> That entry was unsourced and has been removed — `Control.offset_transform_*` is a new
> feature in 4.7, and nothing about the existing anchor/offset system was deprecated.

## How to Check

When agents are unsure about an API:

1. Search the Godot class reference: `https://docs.godotengine.org/en/stable/classes/`
2. Check the interactive changelog: `https://godotengine.github.io/godot-interactive-changelog/`
3. Use WebSearch: `"Godot 4.7 [api_name] deprecated"`

## Note

The LLM training data covers Godot up to ~4.3. Any API that was introduced,
changed, or deprecated in 4.4–4.7 may be incorrectly suggested. When in doubt,
verify against the official docs.
