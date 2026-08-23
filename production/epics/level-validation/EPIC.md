# Epic: Level Load Validation

> **Layer**: Foundation
> **GDD**: design/gdd/watering-system.md · design/gdd/suit-oxygen.md · design/gdd/physics-props.md
> **Architecture Module**: `LevelValidation` (`RefCounted`, static)
> **Status**: Ready
> **Stories**: 6 stories — see the table below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Validation scaffold — type-scan discovery and `count_buckets()`](story-001-validation-scaffold-and-discovery.md) | Logic | Ready | ADR-0003 |
| 002 | [`V-BUCKET-SUM` and `V-PLANT-MIN`](story-002-bucket-sum-and-plant-min-rules.md) | Logic | Ready | ADR-0003, ADR-0009 |
| 003 | [`V-OXY-CAP` and `V-GRAV-EXPORT`](story-003-oxygen-capacity-and-gravity-export-rules.md) | Logic | Ready | ADR-0003, ADR-0001, ADR-0002 |
| 004 | [`V-WIRING` over a required-consumer table](story-004-wiring-rule-required-consumer-table.md) | Logic | Ready | ADR-0003, ADR-0002, ADR-0010, ADR-0011 |
| 005 | [Wire `validate()` into `LevelRoot._ready()` at step (a)](story-005-wire-validation-into-level-root-ready.md) | Integration | **Blocked** — `level-state` epic | ADR-0003, ADR-0002 |
| 006 | [`V-PROP-BUDGET` and `V-BOUNDS`](story-006-prop-budget-and-bounds-rules.md) | Logic | **Blocked** — `tuning-resources` epic + `PropBody` | ADR-0003, ADR-0011, ADR-0006 |

Take 001 first; 002 and 003 are independent of each other and may follow in either
order; 004 needs all three. Both blocks are scheduling, not design — every governing
ADR is Accepted.

## Corrections to this epic, found at story creation (2026-08-23)

The epic text above predates ADR-0010 and ADR-0011 reaching **Accepted**. Two
statements in it are now stale. The stories follow the corrected position; this note
records why they diverge from the prose above.

**1. The rule set is seven rules, not six.** ADR-0011 D11.7 adds `V-BOUNDS`
(`level_bounds` resolves, and every `PropBody` starts inside its extent). The control
manifest v2026-08-17 already records this — *"Six validation rules (extended to seven
by ADR-0011)"*. `V-BOUNDS` is implemented in story 006 alongside `V-PROP-BUDGET`,
because both need `class_name PropBody`.

**2. The `V-WIRING` required-consumer set has doubled, from two rows to four.**
ADR-0003 D3.3 states that a consumer is required when its owning ADR is Accepted:

| Export | Owning ADR | Required per D3.3's rule | ADR-0003's printed table |
|---|---|---|---|
| `player` | ADR-0002 | Yes | Yes |
| `goal` | ADR-0002 | Yes | Yes |
| `hud` | ADR-0010 (Accepted) | **Yes** | says *"No — admitted when ADR-0010 is Accepted"* |
| `level_bounds` | ADR-0011 (Accepted) | **Yes** | absent |

ADR-0010 D10.9 and ADR-0011 D11.7 both state the promotion explicitly, and ADR-0011's
Related Decisions section already records that ADR-0003 owes the `level_bounds` row.
This is doc lag inside ADR-0003's printed prose, not a conflict between decisions —
D3.3's own admission rule resolves it. **Story 004 implements four rows.** A doc-only
amendment to ADR-0003 D3.3 is owed and is flagged at `/story-done`; no ADR is reopened
by these stories.

This raises the level migration epic's cost: all 8 levels must now author and wire a
HUD *and* a `LevelBounds` `Area2D`. ADR-0010 §Consequences already names those two as
that epic's largest cost.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- Five of the six rules pass in headless CI against every level scene, and `V-PROP-BUDGET` is specified with its constant in place
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories level-validation` to break this epic into implementable stories.
