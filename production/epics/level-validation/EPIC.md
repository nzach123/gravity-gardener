# Epic: Level Load Validation

> **Layer**: Foundation
> **GDD**: design/gdd/watering-system.md · design/gdd/suit-oxygen.md · design/gdd/physics-props.md
> **Architecture Module**: `LevelValidation` (`RefCounted`, static)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories level-validation`

## Overview

A level that violates its own authored contract must fail loudly at load, not
silently produce an unsolvable room. `LevelValidation` is a static, tree-free
checker. It reads authored scene data only — `LevelRoot` exports, plants, buckets
and props — and returns the list of violations. Six rules are coded. The two that
matter most are the bucket-sum rule (`buckets_total` must equal the sum of every
plant `buckets_required` value, or the level cannot be finished) and the
oxygen-capacity rule (a capacity of zero or less means instant death on spawn).
Because `PackedScene.instantiate()` populates `@export` values without running
`_ready()`, every level can be instantiated, validated and freed with no
`SceneTree`. That is what makes the whole rule set testable in headless CI.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Level load validation contract | Static tree-free `validate(level) -> PackedStringArray`; six coded rules; violations reported with `push_error()` | LOW |

LOW for this ADR. The project rates HIGH overall on post-4.3 physics and rendering
churn, none of which this decision touches. Its three load-bearing Core claims
(E1–E3) were verified against `scene/resources/packed_scene.cpp` and the live class
reference on 2026-08-14.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-watering-008 | buckets_total == sum of buckets_required, validated at load | ADR-0003 ✅ |
| TR-watering-015 | Load logs an error on bucket-sum mismatch | ADR-0003 ✅ |
| TR-oxygen-008 | Load logs an error when oxygen_capacity <= 0 | ADR-0003 ✅ |
| TR-props-007 | Prop count is budgeted and flagged at load | ADR-0003 ✅ (gated — see Risks) |

## Risks

| Risk | Status | How this epic handles it |
|---|---|---|
| **`V-PROP-BUDGET` cannot be implemented until ADR-0006 lands.** It reads `props_per_level_budget`, which lives in the `PropTuning` resource that ADR-0006 owns. This is the stated Ordering Note of ADR-0003. | **Blocked on the `tuning-resources` epic** | Implement **five of the six rules** now. Leave the sixth specified, with its named constant in place. Schedule the `tuning-resources` epic first, or accept that TR-props-007 closes late. Migration Plan step 8 of ADR-0003 and step 6 of ADR-0006 are the same action seen from two sides — do the closure once, not twice. |
| **The 4.7 verification method carries a recorded caveat.** No literal `4.7` git tag is fetchable, so E1–E3 were checked against 4.3-stable source plus the live class reference. | Accepted, recorded openly in ADR-0003 | Core-domain behaviour records no breaking change across 4.4 → 4.7. Treat E1–E3 as settled and **do not re-search them**. If an E-claim fails in practice, that is a finding against the ADR, not a story-level workaround. |
| **`assert()` compiles out in release exports; `push_error()` does not.** A violation reported only by `assert()` would vanish from the shipped build. | Known, verified 2026-08-14 | Report every violation with `push_error()`. Use `assert()` only as an extra debug-build stop, never as the only reporting path. |
| **Debug-only gating could hide a real authoring error from QA.** | Design constraint | Follow the stated reporting policy of ADR-0003 exactly. Do not add extra `OS.is_debug_build()` gating to the six rules. |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- Five of the six rules pass in headless CI against every level scene, and `V-PROP-BUDGET` is specified with its constant in place
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories level-validation` to break this epic into implementable stories.
