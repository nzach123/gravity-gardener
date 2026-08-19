# Epic: Tuning Resources

> **Layer**: Foundation
> **GDD**: design/gdd/watering-system.md §7 · design/gdd/suit-oxygen.md §7 · design/gdd/physics-props.md §7
> **Architecture Module**: `WateringTuning` · `OxygenTuning` · `PropTuning` · `Tuning` accessor
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories tuning-resources`

## Overview

Gameplay values must be data-driven, never hardcoded. This epic creates three
custom `Resource` types — `WateringTuning`, `OxygenTuning` and `PropTuning` — each
with a matching `.tres` file holding the GDD default values, plus a `Tuning`
accessor that exposes them as typed `preload()`ed constants. Because `preload()`
resolves at script-load time with no `SceneTree` involvement, and because the
engine resource cache returns the same instance for the same path, tuning values
are reachable from a headless test that never adds a node to a tree. This is
greenfield work: a grep across `src/` for every knob name returns zero matches,
because none of the three consuming systems is built yet. There is nothing to
migrate — only to create.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Tuning resource strategy | Three `Resource` subclasses with `@export_range` knobs, three `.tres` files, and a `Tuning` accessor holding typed `preload()`ed constants | **HIGH** |

**This is the only Foundation epic that rates HIGH, and the rating is at the
project level, not the decision level.** No `modules/core.md` engine reference
exists — `modules/` holds only `physics-2d.md` and `ui-control.md` — so the
`Resource` / `preload` / `@export_range` domain has no curated snapshot to check
against. No post-cutoff API is used, and facts T1–T3 were verified at the
2026-08-14 specialist gate. T4 was not.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-watering-013 | carry and throw_* knobs live in WateringTuning | ADR-0006 ✅ |
| TR-oxygen-011 | drain_rate and threshold_* live in OxygenTuning | ADR-0006 ✅ |
| TR-props-009 | Prop knobs and defaults | ADR-0006 ✅ |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **T4 was verified from documentation only and never executed.** The claim: `@export_range` constrains the inspector but does **not** clamp or reject a value loaded from a hand-edited `.tres`. The specialist began building an isolated project against the pinned 4.7.1 binary and did not finish. | **OPEN — the headline risk of this epic** | Migration Plan step 5 of ADR-0006 says this is where T4 gets closed. **Execute it against the real 4.7.1 binary.** Until then, treat every `@export_range` as an inspector hint, not a validator. If a knob must be clamped, clamp it in code. |
| **HIGH engine-risk domain with no in-repo reference.** | Standing gap | Verify any uncertain `Resource`-system API against the official 4.7 docs before writing code, per `VERSION.md`. Do not answer from training data — training coverage stops at roughly 4.3. |
| **GH#73615 — a `preload()`ed resource can resolve non-null yet be the wrong type.** | Known | Validation V1 must assert `is PropTuning`, not merely non-null. This is stated as load-bearing in Migration Plan step 5. |
| **`resource_local_to_scene` must be `false` on all three `.tres` files** (D6.9). If true, each scene gets its own copy and tuning silently stops being global. | Known, checked at creation | Migration Plan step 3 requires verifying this at file creation, together with inspector slider behaviour. |
| **gdUnit4 treats GDScript warnings as errors at test discovery** — one warning fails the entire suite. | Known | All four new scripts must be warning-clean, including the unused-`class_name` and shadowing checks. Same caveat that applied to `collision_layers.gd`. |
| **This epic unblocks `V-PROP-BUDGET` in the `level-validation` epic.** | Cross-epic dependency | Migration Plan step 6 of ADR-0006 closes `V-PROP-BUDGET` and removes the "BLOCKED on ADR-0006" note from the ADR-0003 registry entry and Ordering Note. Step 8 of ADR-0003 is the same action. Do it once. |
| **No consumer work is owed by this epic.** | Scope boundary | ADR-0008 / ADR-0009 / ADR-0011 / ADR-0012 adopt `Tuning.*` as they land. Do not pull consumer code into this epic. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- V1–V4 and V9 pass as headless gdUnit4 tests before any consumer depends on this
- **T4 is executed against the pinned 4.7.1 binary and its result is recorded in ADR-0006**
- `V-PROP-BUDGET` is closed in `LevelValidation`, and the "BLOCKED on ADR-0006" note is removed from ADR-0003
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories tuning-resources` to break this epic into implementable stories.
