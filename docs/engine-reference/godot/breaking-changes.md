# Godot — Breaking Changes (4.4 → 4.7)

Last verified: 2026-08-13

## 4.6 → 4.7

### Rendering
- **Control offset transforms**: Changes to how anchored layouts and menus resolve. UI with complex anchor setups may need adjustment.
- **HDR/SDR output**: Updates to HDR/SDR output pipeline. Clearcoat materials may render differently.

### Platform
- **Android**: Export presets, splash screens may need updates.
- **XR**: Action maps may have changed — review XR export presets.

### GDExtension
- **Recompilation required**: All C++ GDExtensions must be recompiled against 4.7 headers.

---

## 4.5 → 4.6

### Physics
- **Jolt Physics native integration**: Jolt is now the default 3D physics engine, replacing the previous Bullet-based implementation. Projects using custom physics workarounds for Bullet may need migration.

### Editor
- **"Modern" theme**: New default editor theme introduced. Custom editor themes/plugins may need visual adjustment.

### Rendering
- Performance improvements across rendering pipeline.

---

## 4.4 → 4.5

### Rendering
- **Stencil buffer support**: New stencil buffer API available for rendering effects.

### Accessibility
- **Screen reader support**: GUI elements now have better screen reader integration. Custom controls should implement accessibility metadata.

---

## 4.3 → 4.4

### GDScript
- Various GDScript language improvements and fixes.

### Editor
- Interactive music support.
- Tighter editor integration.

---

## Impact Assessment for This Project

This project uses:
- **GL Compatibility renderer**: Most rendering changes (HDR, clearcoat) have minimal impact since they primarily affect Forward+/Mobile renderers.
- **Jolt Physics (3D)**: Already configured — no migration needed from Bullet.
- **2D gameplay**: Control offset transform changes could affect UI layouts. Test menus and HUD carefully.
- **No GDExtensions**: No recompilation concerns.
