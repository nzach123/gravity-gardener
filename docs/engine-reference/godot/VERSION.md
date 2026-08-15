# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7.1 |
| **Project Pinned** | 2026-08-15 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | HIGH — version is beyond LLM training data (training covers ~4.3) |
| **Last Docs Verified** | 2026-08-15 |

Installed binary: `Godot_v4.7.1-stable_win64`. A `4.7.2-rc1` exists (2026-08-03)
but no 4.7.2 stable has been released — do not pin to an rc.

## Post-Cutoff Version Timeline

| Version | Release Date | Key Changes |
|---------|-------------|-------------|
| 4.4 | ~Jan 2025 | Interactive music, tighter editor, GDScript improvements |
| 4.5 | Sep 2025 | Stencil buffer support, accessibility improvements, screen reader GUI support |
| 4.6 | Jan 2026 | **Jolt Physics native integration** (now default 3D physics), "Modern" editor theme, performance polish |
| 4.7 | 2026-06-18 | AreaLight3D, HDR output, `Control.offset_transform_*`, path snapping, animation track management |
| 4.7.1 | 2026-07-14 | Maintenance release — stability and usability fixes, no new APIs |
| 4.8 | *unreleased* | Dev snapshots only (dev 3 as of Aug 2026). Editor/workflow focus. **Do not adopt.** |

## Migration Guide URLs

- 4.3 → 4.4: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- 4.4 → 4.5: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5 → 4.6: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.6 → 4.7: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

## Key Risks for Agents

1. **Typed return inheritance** (4.7): A method overriding one with a typed return now
   inherits that return type, so the override requires an explicit `return` statement
   (GH-115763). This project enforces static typing everywhere — highest-impact change.
2. **Jolt Physics is now native** (4.6+): The old Bullet-based 3D physics is no longer the
   default. Agents must not suggest Bullet-specific workarounds or settings.
3. **`Control.offset_transform_*`** (4.7): New feature, *not* a breaking change. Lets a
   Control be slid, rotated, or scaled without a container re-sort discarding it
   (CSS `transform`-like). Visual-only by default, so hover state survives. Do not
   suggest the pre-4.7 workarounds for animating Controls inside containers.
4. **`RichTextLabel.add_image()` signature change** (4.7): sizes are now `float`, and
   `width_in_percent`/`height_in_percent` became `width_unit`/`height_unit` taking
   `RichTextLabel.ImageUnit` (GH-112617). Affects HUD work.
5. **AreaLight3D** (4.7): New light type — do not suggest pre-4.7 area-lighting workarounds.
6. **HDR Output** (4.7): Desktop platforms now support HDR output.
7. **Editor theme "Modern"** (4.6): New default theme — older screenshots will not match.
8. **Stencil buffer** (4.5): Available for outlines, portals, and masking.

## Note

When uncertain about any API in Godot 4.5–4.7, agents should use WebSearch
to verify against the official docs before suggesting code. The training data
does NOT reliably cover APIs introduced or changed after Godot 4.3.

Run `/setup-engine refresh` to update these docs at any time.
