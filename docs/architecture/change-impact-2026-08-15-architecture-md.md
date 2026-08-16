# Change Impact — `architecture.md` reconciliation (session 18)

**Date**: 2026-08-15
**Trigger**: `/propagate-design-change docs/architecture/architecture.md`, run on the
recommendation of `docs/architecture/architecture-review-2026-08-15-b.md`'s "New
finding 1" and HANDOFF.md's standing item 4.
**Resolution**: 13 edits written directly to `docs/architecture/architecture.md`, in
place. No ADR changed. No other file touched by this change.

---

## Premise inversion — read this before reusing this pattern

`/propagate-design-change` is built for GDD → ADR drift: a GDD is revised, and the
skill finds which ADRs now assume something the GDD no longer says. That shape does
not fit here.

`architecture.md` carries **no uncommitted diff and no revision since `0a02de0`**
(before ADR-0007 existed). There was nothing to `git diff`. The drift ran the other
direction: **ADR-0007 changed** (written and Accepted, `896ec56`) while
`architecture.md` — the document ADR-0007's own decisions should have been
propagated back into — never followed. This is the same inversion session 11
recorded for `hud.md`/`watering-system.md`: the artifact needing correction is not
the one that has git history to diff. ADR-0007's Decision section was treated as
the source of truth; `architecture.md`'s prose as the stale target.

`review-mode.txt` is `lean` — Phase 6b (TD-CHANGE-IMPACT gate) was skipped, same as
every prior run of this skill on this project.

---

## Change Summary

**Changed sections** (13 edits, 3 categories):

- **Category A — pre-existing staleness**, unrelated to ADR-0007, flagged every
  session since it first came up (HANDOFF.md item 4's "3 no-ADR assertions plus the
  `:108` carry-indicator row"):
  - A1 (`:10`) — "ADRs Referenced: none exist" → 7 of 12 exist, all Accepted
  - A2 (`:16-18`) — sign-off condition 1 struck through and resolved, matching the
    existing convention already used for conditions 2/3
  - A3/A4 (`:721-728`) — "No ADRs exist" / "recorded only in this document" →
    corrected, points at `/architecture-review`'s latest pass
  - A5 (`:730-738`) — "0 of 52 covered" → 28/52, table rebuilt from
    `tr-registry.yaml`'s canonical `coverage:` block (28 covered / 22 gap / 1
    parked / 1 implemented)
  - A6 (`:108`) — HUD row's "carry indicator" duty dropped (resolved diegetic,
    session 11)

- **Category B — new staleness from ADR-0007**, matching the review's "New finding 1":
  - B1 (`:757`, `:759`) — `TR-watering-002` moved from ADR-0007's row to ADR-0009's
    row in the Required ADRs table, matching `tr-registry.yaml`'s `corrected:` entry
  - B2 (`:192`) — `PlayerGravityComponent`'s Core Layer row narrowed to D7.2's actual
    surface (`initialize()`/`jump_velocity`/`apply_gravity()`); no signal consumption
  - B3 (`:474-493`) — `GravityAuthority` API block gains `apply_camera_relative_axis`
    (D7.4)
  - B4 (`:219-221`, `:364`) — dependency diagram and signal table both stop showing
    `PlayerGravityComponent` as a `gravity_changed` consumer; D7.1 replaces that with
    an unconditional live read inside `Player`

- **Category C — new staleness found independently** while reading the Frame Update
  Path diagram (not in the review's list of 4):
  - C1/C2/C3 (`:290-317`) — the `Player` block of the frame-update diagram showed a
    deleted method (`update_derived_dirs()`), an early `return` on the watering
    branch that would have skipped mid-pour visuals (`watering-system.md` AC9) —
    **the exact defect shape ADR-0007's own TD-ADR review caught and rejected in its
    own draft** — and a carry-speed multiplier no component implements yet. Rewritten
    to match D7.3's actual 8-step order, with an amendment note in the doc's own
    established style (matching the ADR-0005 note already above this diagram)

**Unchanged sections**: System Layer Map ASCII block, Binding layer/ownership
decision prose (D1–D7), Data Flow persistence path, Initialisation order,
Architecture Principles (P1–P5), Open Questions. None of these referenced anything
ADR-0007 touched.

---

## Impact Analysis

No ADR required a status change. `architecture.md` was the sole document out of
sync; ADR-0007 (Accepted) and `tr-registry.yaml` (already corrected, session 18
earlier in this session) were both already accurate and served as the sources this
correction was checked against.

| Document | Status | Action |
|---|---|---|
| `architecture.md` | Was stale in 13 places | ✅ Corrected in place, 11 `Edit` calls |
| ADR-0001–0007 | Still Valid | No change — `architecture.md` was wrong, not them |
| `tr-registry.yaml` | Still Valid | Already corrected earlier this session (`TR-oxygen-006` owner decision) |
| `requirements-traceability.md` | Still Valid | Already regenerated earlier this session |

---

## Resolution

User approved the full 13-edit draft as one changeset (single-file scope:
`architecture.md` only). Written in 11 `Edit` calls, non-destructively — every
correction either strikes through and annotates (matching the doc's own
"~~old~~ **Resolved**" convention) or replaces table cells/diagram lines with an
inline note explaining the source ADR, rather than silently deleting prior text.

---

## Follow-up

- **HANDOFF.md item 4** ("`/propagate-design-change` for `architecture.md`") is now
  closed. Update the next handoff to reflect this.
- No new ADRs need to be written as a result of this change.
- `architecture-review-2026-08-15-b.md`'s "New finding 1" is now resolved; its other
  finding (`GravityAuthority.reset_to()` prop gravity question) is untouched by this
  change and remains open.
- Nothing in this changeset is committed to git. `docs/architecture/architecture.md`,
  `tr-registry.yaml`, `requirements-traceability.md`,
  `architecture-review-2026-08-15-b.md`, and this file are all uncommitted as of
  session 18's end.

**Verdict: COMPLETE** — change impact report saved.
