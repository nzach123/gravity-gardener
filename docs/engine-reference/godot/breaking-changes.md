# Godot — Breaking Changes (4.4 → 4.7.1)

Last verified: 2026-08-15

Source: [Upgrading to Godot 4.7](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html).
GH numbers reference godotengine/godot pull requests.

## 4.7 → 4.7.1

Maintenance release. Stability and usability fixes only — no API changes.

## 4.6 → 4.7

### GDScript
- **Typed return inheritance** (GH-115763): A method that overrides a method with a typed
  return now inherits that return type. The override must have an explicit `return`
  statement; add `return null` where the body previously fell off the end.
- **Packed array element assignment** (GH-113228): Setting one element of a packed array
  no longer calls the setter for the entire packed array property. Code relying on the
  setter firing as a change notification will silently stop being notified.

### Core
- **`Object.is_class()`** (GH-118582): Parameter type changed `String` → `StringName`.
  Compatibility preserved at all levels.

### Physics (2D)
- **`PhysicsServer2D.body_set_shape_as_one_way_collision()`** (GH-104736): Gains an optional
  `direction` parameter. Compatible at all levels.
- **`PhysicsServer2DExtension._body_set_shape_as_one_way_collision()`** (GH-104736): The
  `direction` parameter is **required** on the virtual method — a hard break with no
  compatibility shim. Only affects custom physics server extensions.

### Control / UI
- **`Control.accessibility_live`** (GH-116839): Property type changed from
  `DisplayServer.AccessibilityLiveMode` to `AccessibilityServer.AccessibilityLiveMode`.
  Breaks C# binary and source compatibility; GDScript is unaffected at the call site.
- **`RichTextLabel.add_image()` / `update_image()`** (GH-112617): `width`/`height` changed
  `int` → `float`; `width_in_percent`/`height_in_percent` renamed to `width_unit`/`height_unit`
  and retyped to `RichTextLabel.ImageUnit`. GDScript-compatible for the numeric change;
  the renames are a source break in every language.

### Audio
- **`AudioEffectSpectrumAnalyzer.tap_back_pos`** (GH-114355): Property removed. Fully
  incompatible, no replacement documented.

### Rendering
- **HDR/SDR output**: Updates to HDR/SDR output pipeline. Clearcoat materials may render differently.

### Platform
- **Android**: Export presets, splash screens may need updates.
- **XR**: Action maps may have changed — review XR export presets.

### GDExtension
- **Recompilation required**: All C++ GDExtensions must be recompiled against 4.7 headers.

> **Not a breaking change**: `Control.offset_transform_*` is a *new feature* in 4.7, not a
> change to how existing anchored layouts resolve. An earlier revision of this file
> described it as breaking; that framing came from a secondary blog and is not in the
> official migration guide. See `current-best-practices.md`.

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

**No migration backlog exists.** The project already runs on 4.7.1, and a grep of the 22
project `.gd` files (2026-08-15) found zero uses of `RichTextLabel`, `add_image`,
`accessibility_live`, `Object.is_class()`, or any one-way-collision API. The test suite
passes 52/52 on this engine. Everything below is therefore an **authoring rule for new
code**, not a list of things to go fix.

Ordered by how likely each is to bite the code we are about to write.

**Will bite:**
- **Typed return inheritance** (GH-115763): This project enforces static typing everywhere,
  so overrides of typed-return methods are common. gdUnit4 treats GDScript warnings as
  errors during test discovery, so a missing explicit `return` fails the whole suite at
  compile time rather than in one test.
- **`RichTextLabel` image units** (GH-112617): `design/ux/hud.md` is the active work.
  Any HUD code calling `add_image()` must use `width_unit`/`height_unit` with
  `RichTextLabel.ImageUnit`, not the old `*_in_percent` booleans.

**Worth knowing:**
- **`Control.accessibility_live`** (GH-116839): The enum moved namespaces. GDScript call
  sites are unaffected, but any HUD accessibility metadata written against the old
  `DisplayServer.` path needs the `AccessibilityServer.` prefix.
- **Packed array setter** (GH-113228): Only matters if a system relies on a packed array
  property setter firing as a change signal.

**No impact:**
- **GL Compatibility renderer**: HDR and clearcoat changes primarily affect Forward+/Mobile.
- **Jolt Physics (3D)**: Already configured — no Bullet migration needed. This is a 2D
  project; 2D physics still uses Godot's built-in engine.
- **`PhysicsServer2DExtension`**: Hard break, but only for custom physics server extensions.
  This project has none.
- **No GDExtensions**: No recompilation concerns.
- **Audio spectrum analyzer**: Not used.
