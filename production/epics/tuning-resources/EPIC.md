# Epic: Tuning Resources

> **Layer**: Foundation
> **GDD**: design/gdd/watering-system.md §7 · design/gdd/suit-oxygen.md §7 · design/gdd/physics-props.md §7
> **Architecture Module**: `WateringTuning` · `OxygenTuning` · `PropTuning` · `Tuning` accessor
> **Status**: Ready
> **Stories**: 6 — see the table below

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
2026-08-14 specialist gate. T4 was executed separately on 2026-08-24, by story 001.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-watering-013 | carry and throw_* knobs live in WateringTuning | ADR-0006 ✅ |
| TR-oxygen-011 | drain_rate and threshold_* live in OxygenTuning | ADR-0006 ✅ |
| TR-props-009 | Prop knobs and defaults | ADR-0006 ✅ |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **T4 was verified from documentation only and never executed.** The claim: `@export_range` constrains the inspector but does **not** clamp or reject a value loaded from a hand-edited `.tres`. | **CLOSED 2026-08-24 — the claim held** | Story 001 executed it against `4.7.1.stable.official.a13da4feb`. Out-of-range values load intact: no clamp, no rejection, no fallback to the default. The rule for implementers does not change — treat every `@export_range` as an inspector hint, not a validator. If a knob must be clamped, clamp it in code. Evidence: `production/qa/evidence/t4-export-range-clamp-spike.md`. |
| **HIGH engine-risk domain with no in-repo reference.** | Standing gap | Verify any uncertain `Resource`-system API against the official 4.7 docs before writing code, per `VERSION.md`. Do not answer from training data — training coverage stops at roughly 4.3. |
| **GH#73615 — a `preload()`ed resource can resolve non-null yet be the wrong type.** | Known | Validation V1 must assert `is PropTuning`, not merely non-null. This is stated as load-bearing in Migration Plan step 5. |
| **`resource_local_to_scene` must be `false` on all three `.tres` files** (D6.9). If true, each scene gets its own copy and tuning silently stops being global. | Known, checked at creation | Migration Plan step 3 requires verifying this at file creation, together with inspector slider behaviour. |
| **gdUnit4 treats GDScript warnings as errors at test discovery** — one warning fails the entire suite. | Known | All four new scripts must be warning-clean, including the unused-`class_name` and shadowing checks. Same caveat that applied to `collision_layers.gd`. |
| **This epic unblocks `V-PROP-BUDGET` in the `level-validation` epic.** | Cross-epic dependency | Migration Plan step 6 of ADR-0006 closes `V-PROP-BUDGET` and removes the "BLOCKED on ADR-0006" note from the ADR-0003 registry entry and Ordering Note. Step 8 of ADR-0003 is the same action. Do it once. |
| **No consumer work is owed by this epic.** | Scope boundary | ADR-0008 / ADR-0009 / ADR-0011 / ADR-0012 adopt `Tuning.*` as they land. Do not pull consumer code into this epic. |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [T4 spike — does `@export_range` clamp a hand-edited `.tres`?](story-001-t4-export-range-clamp-spike.md) | Integration | Complete | ADR-0006 |
| 002 | [Create the three tuning `Resource` scripts](story-002-create-tuning-resource-scripts.md) | Config/Data | Ready | ADR-0006 |
| 003 | [Author the three tuning `.tres` files at GDD defaults](story-003-author-tuning-tres-files.md) | Config/Data | Ready | ADR-0006 |
| 004 | [Create the `Tuning` const accessor](story-004-create-tuning-accessor.md) | Logic | Ready | ADR-0006 |
| 005 | [Headless gdUnit4 validation suite — V1–V4 and V9](story-005-tuning-validation-suite.md) | Logic | Ready | ADR-0006 |
| 006 | [CI greps for V6, V7 and V8](story-006-ci-greps-for-tuning-bans.md) | Logic | Ready | ADR-0006 |

Build order is 001 → 002 → 003 → 004 → 005 → 006. Each story's
`Depends on:` field states what must be DONE before it starts.

### Not a story in this epic

**Closing `V-PROP-BUDGET` and removing the "BLOCKED on ADR-0006" note** appears in
this epic's Definition of Done, but it is **owned by the `level-validation` epic**
(sprint task **LV-2**). ADR-0006 Migration Plan step 6 and ADR-0003 Migration Plan
step 8 are the same action, and `sprint-1.md` requires it to be done once, not twice.
No story is created here for it.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- V1–V4 and V9 pass as headless gdUnit4 tests before any consumer depends on this
- ~~**T4 is executed against the pinned 4.7.1 binary and its result is recorded in ADR-0006**~~ — done 2026-08-24
- `V-PROP-BUDGET` is closed in `LevelValidation`, and the "BLOCKED on ADR-0006" note is removed from ADR-0003
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories tuning-resources` to break this epic into implementable stories.
