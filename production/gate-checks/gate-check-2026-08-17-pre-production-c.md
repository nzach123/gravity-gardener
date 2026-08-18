# Gate Check: Pre-Production → Production

**Date**: 2026-08-17
**Checked by**: `/gate-check pre-production`
**Review mode**: `lean` (`production/review-mode.txt`)
**Prior run**: `gate-check-2026-08-17-pre-production-b.md` — verdict CONCERNS
**Context**: run immediately after closing all five open findings from
`prototypes/gravity-gardener-vertical-slice/REPORT.md`.

---

## Required Artifacts: 8/14 present

| Artifact | Status | Evidence |
|---|---|---|
| Vertical slice + REPORT.md | ✅ | `prototypes/gravity-gardener-vertical-slice/`, verdict PROCEED |
| All Foundation/Core ADRs `Accepted` | ✅ | ADR-0001 … ADR-0012, each status re-parsed individually |
| Control manifest | ✅ | `docs/architecture/control-manifest.md`, version 2026-08-17 |
| Master architecture document | ✅ | `docs/architecture/architecture.md` |
| ≥3 Foundation-layer ADRs | ✅ | ADR-0001, 0002, 0003, 0004, 0005 |
| Architecture traceability index | ✅ | `docs/architecture/requirements-traceability.md` |
| HUD design document | ✅ | `design/ux/hud.md` |
| Interaction pattern library | ✅ | `design/ux/interaction-patterns.md`, P1–P7 |
| All MVP-tier GDDs complete | ⚠️ | 7 GDDs exist. `level-flow.md` and `hazards.md` authored 2026-08-17 and are **pending `/design-review`** |
| Playtest, ≥1 documented session | ⚠️ | 1 session, recorded in `prototypes/`, not `production/playtests/` (which does not exist) |
| **Epics in `production/epics/`** | ❌ | **Directory does not exist** |
| **First sprint plan in `production/sprints/`** | ❌ | **Directory does not exist** |
| **Art bible complete (all 9 sections)** | ❌ | **§5, §6, §7 and §9 read `[To be designed]`** |
| **AD-ART-BIBLE sign-off recorded** | ❌ | **Explicitly "Skipped — Lean review mode"** |
| **UX spec — main menu** | ❌ | `design/ux/` contains only `hud.md` and `interaction-patterns.md` |
| **UX spec — pause menu** | ❌ | Same. QQ-04 records that no pause menu exists at all |
| Entity inventory | ❌ | `design/assets/` does not exist (recommended, not blocking) |

## Quality Checks

- ❌ **Unresolved High-priority open questions in Foundation/Core.** `architecture.md`
  **QQ-03** is live: all 8 levels in `src/scenes/levels/` still use the old one-bucket
  model and **no `O_level` has been computed for any of them**. The `d_exit` amendment
  made to `watering-system.md` §4 today makes this strictly worse — the levels were
  never derived against the old formula, and the formula has now changed.
- ⚠️ **QQ-01 and QQ-06 appear stale rather than open.** `watering-system.md` §6 and
  `suit-oxygen.md` §6 already reference `LevelState`/`OxygenState`, and
  `game-concept.md` now exists. Both should be closed rather than carried into the
  next run.
- ⚠️ **QQ-05 partially closed 2026-08-17.** Spike hazards now have a GDD (`hazards.md`).
  Wall jump and moving platforms remain undocumented.
- ✅ Core loop validated end-to-end by a human: spawn → bucket → gravity flip →
  pour ×2 → goal entry.
- ❓ "Does the core mechanic feel good?" — subjective; not answered this run.

## Vertical Slice Validation

Assessed against the **built artifact**, which has not been rebuilt since the playtest:

| Check | Result |
|---|---|
| A human played the core loop without developer guidance | ⚠️ Partially — the tester had to be told the pour requires a sustained hold |
| The game communicates what to do within the first 2 minutes | ❌ No interact prompts, no gravity-zone visuals, no win feedback |
| No critical fun-blocker bugs | ❌ One recorded — the mirrored control scheme |
| The core mechanic feels good | ❓ Not assessed this run |

**All three failures were closed in *design* on 2026-08-17** — `gravity.md` R11,
the E2/E3/zone-visual re-tier into MVP, and `hud.md` E9. **None were closed in the
build.** The slice was not rebuilt or retested.

## Director Panel

**Skipped by user decision.** Lean mode calls for all four directors, but a director
verdict can only set a *minimum* of CONCERNS or FAIL, and the artifact checks had
already forced FAIL. Deferred to the re-check, when the verdict is genuinely in play.

---

## Blockers

1. **No epics.** Run `/create-epics layer:foundation`, then `layer:core`, then
   `/create-stories [epic-slug]` for each.
2. **No sprint plan.** Run `/sprint-plan new` after epics and stories exist.
3. **Art bible is 5/9 drafted and unsigned.** Run `/art-bible` for §5 (Character
   Design Direction), §6 (Environment Design Language), §7 (UI/HUD Visual Direction)
   and §9 (Reference Direction), then record an AD-ART-BIBLE sign-off.
4. **Two of three required UX specs missing.** Run `/ux-design main-menu` and
   `/ux-design pause-menu`. The pause menu is doubly blocked — QQ-04 notes
   `suit-oxygen.md` §5 requires drain to halt on pause and no pause menu exists.

## Recommendations (not blocking)

- Run `/design-review` on `level-flow.md` and `hazards.md`.
- Copy or link the slice playtest into `production/playtests/`.
- Close QQ-01 and QQ-06 as stale; narrow QQ-05 to wall jump and moving platforms.
- Re-derive `oxygen_capacity` for the 8 existing levels against the amended `O_level`
  (QQ-03) — this is level-migration work and likely its own epic.
- Get a **cold** playtester. `margin` = 0.4 is unvalidated for a player who does not
  know the route, and this is not answerable by an agent-driven run.
- Re-estimate MVP and Vertical Slice. Three scope changes landed today (legibility
  re-tier, hazards, multi-room) and all three were flagged rather than costed.

---

## Verdict: **FAIL**

Nothing found in this run was caused by the five findings closed today — that work
closed five gaps and opened none. The gate fails on artifacts that were never created:
no epics, no sprints, an art bible half-drafted with sign-off skipped, and no UX specs
for two of three required screens.

**Chain-of-Verification**: 5 questions checked, 4 answered by re-reading files — ADR
statuses re-parsed individually, art-bible §5–§9 read directly, `design/ux/` listed,
`architecture.md` Open Questions re-read. **Verdict unchanged.** One item was softened
deliberately: `level-flow.md` and `hazards.md` being unreviewed is recorded as a
recommendation rather than a blocker, because `/design-review` is a fast follow.

---

## Work completed immediately before this run (2026-08-17)

All five open findings from the vertical slice REPORT.md were closed. Full detail in
`production/session-state/active.md`.

| # | Finding | Outcome |
|---|---|---|
| 1 | Control scheme undecided | `gravity.md` **R11** — screen-relative input, unconditional. **The mirrored controls were a slice implementation gap, not the design** — ADR-0007 D7.4 already specified the mapping and the slice never implemented it |
| 2 | Legibility treated as polish | **3 of 4 items were already fully designed** and sat in the wrong scope tier. Re-tiered into MVP. New GDD `level-flow.md` + `hud.md` E9 cover the one genuine gap (win feedback) |
| 3 | Oxygen budget | **Framed backwards — the budget is ~2.6× too generous.** `O_level` derives to ≈32 s against the authored 90, corroborated by the human run (25 s elapsed × 1.4 ≈ 35 s). Exposed and fixed a formula gap: `O_level` omitted the run to the exit (`d_exit`) |
| 4 | Core fantasy gap | **Both tester asks already existed, undocumented.** New GDD `hazards.md`; MVP raised to multi-room. Recorded three code defects: `inc_hazard_dmg` misnomer, horizontal-only hazard mounting, BUG-0001's inert kill areas |
| 5 | Control-manifest update | Four Core Layer rules added — per-frame zone-trigger evaluation and screen-relative input, plus their two forbidden counterparts |

### Open items carried forward

1. ⚠️ **ADR-0007 D7.4 conflicts with `gravity.md` R11** — D7.4 gates the screen-relative
   mapping on `camera_rotation_enabled`; R11 holds unconditionally. The one genuine
   architecture consequence of that work, and it needs a ruling.
2. ⚠️ `margin` = 0.4 unvalidated for a cold player.
3. ⚠️ Pause during the completion/death sequence — `level-flow.md` §5 takes a stance;
   ADR-0010 owns pause routing and must agree.
4. ⚠️ `complete_hold_duration`, `t_transition` and `min_clearance` all deliberately unset.
5. ⚠️ `V-HAZARD-MASK` and `V-HAZARD-SPAWN` validation checks proposed in `hazards.md` §6,
   owned by ADR-0003, not yet written.
6. ⚠️ MVP and Vertical Slice timelines not re-derived after three scope changes.
