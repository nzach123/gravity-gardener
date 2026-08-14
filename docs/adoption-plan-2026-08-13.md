# Adoption Plan

> **Generated**: 2026-08-13
> **Project phase**: Pre-Production (contested — see Step 1)
> **Engine**: Godot 4.7 (configured, reference library complete)
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

**Scope note**: This project has no planning artifacts in the wrong format — it
has no planning artifacts at all. Every gap below is an existence gap. The code
is the only source of truth, so `/reverse-document` does the heavy lifting here,
not the retrofit commands `/adopt` normally recommends.

---

## Step 1: Fix Blocking Gaps

### 1a. stage.txt overstates actual project state

`production/stage.txt` reads `Pre-Production`, but the phase has zero GDDs,
zero ADRs, and zero stories. Stage-aware skills (`/gate-check`, `/sprint-plan`,
`/story-readiness`) will assume those artifacts exist and return empty or
misleading results rather than failing loudly.

The prototype code is genuinely Pre-Production-grade; the *documentation* is at
Concept. Stage should track the artifact trail, not the code maturity, because
that is what the skills read.

**Fix**: Set `production/stage.txt` to `Concept`. Re-advance it via
`/gate-check` once GDDs exist, so the value is earned rather than asserted.
**Time**: 2 min
- [ ] stage.txt reset to `Concept`

---

## Step 2: Fix High-Priority Gaps

### 2a. No GDDs exist (`design/gdd/` absent)

`/create-epics`, `/create-stories`, `/review-all-gdds`, and `/consistency-check`
all read from `design/gdd/`. None can run. This is the root blocker for the
entire production pipeline.

Systems visible in code that warrant a GDD:
- Gravity manipulation (2-axis flips, zones, smoothing)
- Watering / plant restoration loop
- Jump system (GDC-style math, coyote time, buffer, wall jump)
- Hazards and lives (spikes, respawn)
- Doors / goals / level progression

**Fix**: `/reverse-document` — generates design docs from implementation.
Start with gravity (most complex, most tuning constants already registered).
**Time**: 2–3 sessions
- [ ] design/gdd/game-concept.md
- [ ] design/gdd/systems-index.md
- [ ] design/gdd/gravity.md
- [ ] design/gdd/watering.md
- [ ] design/gdd/jump.md
- [ ] design/gdd/hazards.md
- [ ] design/gdd/progression.md

### 2b. No ADRs exist (`docs/architecture/` absent)

The component refactor encoded real architectural decisions — composition over
inheritance, signal-based component communication, preserved execution order —
but none are recorded. `/story-readiness` has no ADR to check against.

**Fix**: `/create-architecture` first (produces the Required ADR list), then
`/architecture-decision` per entry. `docs/player-refactor-tech-plan.md` already
contains most of the reasoning for the component ADR — mine it, don't rewrite it.
**Time**: 1–2 sessions
- [ ] docs/architecture/ created
- [ ] Master architecture document written
- [ ] ADR: component-based player architecture
- [ ] ADR: gravity zone / 2-axis flip model
- [ ] ADR: remaining entries from Required ADR list

### 2c. tr-registry.yaml missing

No stable requirement IDs, so stories cannot be traced to GDD requirements and
staleness tracking is blind.

**Fix**: `/architecture-review` bootstraps it. Must run *after* 2a and 2b —
it reads GDDs and ADR Status fields.
**Time**: 1 session
- [ ] docs/architecture/tr-registry.yaml created

### 2d. control-manifest.md missing

No layer rules for programmers, so generated stories carry no architectural
guardrails.

**Fix**: `/create-control-manifest`. Run after ADRs are Accepted.
**Time**: 30 min
- [ ] docs/architecture/control-manifest.md created

---

## Step 3: Bootstrap Infrastructure

Ordering matters — each step reads the output of the previous one.

### 3a. Register existing requirements
`/architecture-review` — bootstraps tr-registry.yaml from GDDs and ADRs.
**Time**: 1 session
- [ ] tr-registry.yaml created

### 3b. Create control manifest
`/create-control-manifest`
**Time**: 30 min
- [ ] control-manifest.md created

### 3c. Create sprint tracking file
`/sprint-plan update`
**Time**: 5 min
- [ ] production/sprint-status.yaml created

### 3d. Set authoritative project stage
`/gate-check Concept` — advances stage.txt only if the gate actually passes.
**Time**: 5 min
- [ ] production/stage.txt written by gate-check, not by hand

---

## Step 4: Medium-Priority Gaps

### 4a. Entity registry sources point at code, not GDDs

All 20 entries in `design/registry/entities.yaml` use `source: src/scripts/*.gd`.
The registry contract expects `source:` to name the authoritative GDD. Because no
GDD owns any entity, `/consistency-check` and `/review-all-gdds` have nothing to
cross-check and will report clean regardless of actual drift.

This was a sensible adaptation for a code-first project — it is only a problem
once GDDs exist and the two can disagree.

**Fix**: After Step 2a, repoint each `source:` to its owning GDD and move the
`.gd` path into `referenced_by`.
**Time**: 30 min
- [ ] All 20 entries repointed to GDD sources

### 4b. Duplicate `bucket` entry in entity registry

`design/registry/entities.yaml:126` and `:215` both define `bucket` with
identical fields, violating the registry's own "do not create a duplicate entry"
rule. Grep-based lookups will return two hits and skills may read whichever
comes first.

**Fix**: Delete the second occurrence (line 215). Verify no distinct fields are
lost before removing.
**Time**: 5 min
- [ ] Duplicate removed, single `bucket` entry remains

### 4c. sprint-status.yaml missing
`/sprint-status` falls back to markdown parsing, which is lossy.
**Fix**: `/sprint-plan update`
**Time**: 5 min
- [ ] production/sprint-status.yaml created

### 4d. architecture-traceability.md missing
No persistent GDD-requirement-to-ADR matrix; coverage must be recomputed each run.
**Fix**: Produced by `/architecture-review`.
**Time**: included in 3a
- [ ] docs/architecture/architecture-traceability.md created

---

## Step 5: Optional Improvements

### 5a. Promote existing refactor docs into ADRs

`docs/player-refactor-plan.md` and `docs/player-refactor-tech-plan.md` contain
genuine architectural reasoning — preserved external contracts, component APIs,
execution order, data flow, a regression checklist — but sit outside any path
the template's skills search. They are the best raw material you have for ADRs.

**Fix**: Cite them as source material during Step 2b rather than rewriting from
scratch. Leave the originals in place.
**Time**: folded into 2b
- [ ] Refactor docs referenced by at least one ADR

### 5b. Empty test directories

`tests/integration/` and `tests/evidence/` exist but are empty. Per the testing
standards, Integration stories need integration tests or documented playtests
(BLOCKING gate), and Visual/Feel stories need screenshot evidence (ADVISORY).
Existing unit coverage (gamemanager, gravity component, gravity vector) is a
real head start.

**Fix**: `/qa-plan` once stories exist, to determine what is actually required.
**Time**: 1 session
- [ ] Integration test coverage decided
- [ ] Evidence workflow established

---

## What to Expect from Existing Stories

No stories exist, so nothing is at risk of regeneration. When stories are
created after Steps 2 and 3, they will carry TR-IDs and manifest version stamps
from the start — you get the full safety net without any retrofit debt.

---

## Re-run

Run `/adopt` again after completing Step 3 to verify blocking and high gaps are
resolved. The new run reflects current state and does not diff against this one.
