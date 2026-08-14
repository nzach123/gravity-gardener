# Godot — Deprecated APIs (4.4 → 4.7)

Last verified: 2026-08-13

## General Guidance

Godot maintains backward compatibility within the 4.x cycle. Most deprecated
APIs still work but emit warnings. Always prefer the replacement API.

## Known Deprecations

| Version | Deprecated API | Replacement | Notes |
|---------|---------------|-------------|-------|
| 4.6 | Bullet physics (as default) | Jolt Physics (native) | Bullet is still available but Jolt is default for 3D |
| 4.7 | Various Control offset behaviors | Updated anchor/offset system | Check UI layouts |

## How to Check

When agents are unsure about an API:

1. Search the Godot class reference: `https://docs.godotengine.org/en/stable/classes/`
2. Check the interactive changelog: `https://godotengine.github.io/godot-interactive-changelog/`
3. Use WebSearch: `"Godot 4.7 [api_name] deprecated"`

## Note

The LLM training data covers Godot up to ~4.3. Any API that was introduced,
changed, or deprecated in 4.4–4.7 may be incorrectly suggested. When in doubt,
verify against the official docs.
