# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7 |
| **Project Pinned** | 2026-08-13 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | HIGH — version is beyond LLM training data (training covers ~4.3) |
| **Last Docs Verified** | 2026-08-13 |

## Post-Cutoff Version Timeline

| Version | Release Date | Key Changes |
|---------|-------------|-------------|
| 4.4 | ~Jan 2025 | Interactive music, tighter editor, GDScript improvements |
| 4.5 | Sep 2025 | Stencil buffer support, accessibility improvements, screen reader GUI support |
| 4.6 | Jan 2026 | **Jolt Physics native integration** (now default 3D physics), "Modern" editor theme, performance polish |
| 4.7 | Jun 2026 | AreaLight3D, HDR output, UI/UX improvements, path snapping, animation track management |

## Migration Guide URLs

- 4.3 → 4.4: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- 4.4 → 4.5: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5 → 4.6: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.6 → 4.7: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

## Key Risks for Agents

1. **Jolt Physics is now native** (4.6+): The old Bullet-based 3D physics is no longer the default. Agents must not suggest Bullet-specific workarounds or settings. Jolt Physics is the standard 3D physics engine.
2. **AreaLight3D** (4.7): New light type — agents may not know about it. Do not suggest workarounds for area lighting that were needed pre-4.7.
3. **HDR Output** (4.7): Desktop platforms now support HDR output. Rendering pipeline advice from pre-4.7 may be incomplete.
4. **Control offset transforms** (4.7): Changes to how anchored layouts and menus resolve — may affect UI code suggestions.
5. **Editor theme "Modern"** (4.6): New default editor theme — screenshots and UI guidance from older versions may look different.
6. **Stencil buffer** (4.5): Now available for rendering effects — agents should suggest stencil-based approaches where appropriate instead of older workarounds.

## Note

When uncertain about any API in Godot 4.5–4.7, agents should use WebSearch
to verify against the official docs before suggesting code. The training data
does NOT reliably cover APIs introduced or changed after Godot 4.3.

Run `/setup-engine refresh` to update these docs at any time.
