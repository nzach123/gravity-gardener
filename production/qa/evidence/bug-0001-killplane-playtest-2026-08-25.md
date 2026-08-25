# Playtest Evidence — BUG-0001 kill plane, and the CLR-003 deletion smoke check

**Date**: 2026-08-25
**Build**: branch `vertical-slice`, `eccd804`
**Platform**: PC / Godot 4.7.1-stable, GL Compatibility
**Tester / sign-off**: nzach123 (developer)
**Covers**: CLR-002 AC-5 (all three checks), CLR-003 AC-5 items 3-4

---

## Why this had to be human

Both criteria were held open all sprint because no agent can close them.
CLR-002 AC-5 is a live behaviour change — a fall that previously stranded the
player now restarts the level, and levels 05 and 06 had only ever been played
with the kill plane dead. CLR-003 AC-5 items 3-4 are feel and motion checks.
Agent playtests misjudge pacing and feel, so neither was signed off from one.

## Result

**PASS.** The developer played through and reported that everything looks
correct.

### CLR-002 AC-5

| # | Check | Result |
|---|---|---|
| 1 | Level 05: fall out of bounds — level restarts cleanly, no stranding, no double restart, no stuck camera | PASS |
| 2 | Level 06: same | PASS |
| 3 | Neither level has an in-bounds spot where the kill plane fires unexpectedly (R2) | PASS |

### CLR-003 AC-5

| # | Check | Result |
|---|---|---|
| 3 | The moving platform still animates along its configured path, unchanged | PASS |
| 4 | The player scene runs in a level: movement, jump and gravity flip behave as before | PASS |

Items 1 and 2 of CLR-003 AC-5 name the **editor console** specifically
(`player.tscn` / `moving_platform.tscn` open with zero script errors and zero
warnings). They were not verified by that method — the windowed editor
segfaults on this machine. They are covered instead by the headless probe
recorded in `production/qa/evidence/editor-facts-probe-2026-08-25.md`, plus the
fact that this play session loaded both scenes at runtime without error. See
the METHOD SUBSTITUTED annotation in the story.

## Scope of this record

This document records what the developer reported, at the granularity they
reported it: a full play-through in which everything behaved correctly. It does
not claim per-step observations that were not separately reported. The three
CLR-002 checks are listed individually because the story enumerates them
individually and the developer's confirmation was given against that
enumeration.

## Consequences

- **BUG-0001 closes.** It was S2-Major and Open. The sprint DoD forbids closing
  a sprint with an open S2, so this was the sprint's critical path.
- CLR-002 and CLR-003 can move from `review` to `done`.

## Related

- `production/qa/bugs/BUG-0001.md`
- `production/epics/collision-layer-registry/story-002-fix-bug-0001-kill-plane-masks.md`
- `production/epics/collision-layer-registry/story-003-remove-dead-collision-configuration.md`
- `docs/architecture/adr-0004-collision-layer-allocation.md` — defect 1, Migration Plan step 3
