# Gate Check: Technical Setup → Pre-Production

- **Date**: 2026-08-17
- **Checked by**: `/gate-check pre-production`
- **Review mode**: `lean` (`production/review-mode.txt`)
- **Branch**: `claude-refactor`
- **Prior run**: `production/gate-checks/gate-check-2026-08-16-pre-production-b.md` (2026-08-16, **FAIL**, 1 blocker)
- **Verdict**: **CONCERNS**

This is a next-day re-run after the prior run's sole blocker — `design/art/art-bible.md`
Sections 1–4 unwritten — was closed. Sections 1–4 (Visual Identity Statement, Mood &
Atmosphere, Shape Language, Color System) were authored 2026-08-17, and Section 1.3
explicitly resolves the Creative Director's Pillar 1 / MVP physics-props Concern from
the prior run (camera tween + player-sprite rotation stand in as the MVP-tier proof
mechanism; physics props deferred to Vertical-Slice tier; `game-concept.md` left unedited).

---

## Required Artifacts — 13 of 13 present

All artifacts from the 2026-08-16-b run remain present. The one gap — art bible
Sections 1–4 — is now closed:

| | Artifact | Evidence |
|---|---|---|
| ✅ | Art bible §1–4 (Visual Identity Foundation) | **Closed.** `design/art/art-bible.md` §1–4 authored 2026-08-17 with real content — Visual Identity Statement, Mood & Atmosphere (7 states), Shape Language, Color System with colorblind-safety table. §1.3 resolves the Pillar 1/MVP tension. Verified directly by AD-PHASE-GATE against `main.gd` and `player_visual_component.gd`. |
| ⚠️ | Technical preferences configured | Naming conventions and performance budgets are set (satisfies the named check). Forbidden Patterns / Allowed Libraries / ADR Log sections still read "None configured yet" despite 36 forbidden patterns and 12 Accepted ADRs existing elsewhere — TD flags this as actively misleading, not just incomplete, since this file auto-loads into every agent's context via CLAUDE.md. Unchanged since 2026-08-15. |
| ✅ | All other artifacts (engine, ADRs, engine reference, tests dir, CI workflow, example tests, architecture.md, requirements-traceability.md, `/architecture-review` report, accessibility-requirements.md, interaction-patterns.md) | Unchanged from 2026-08-16-b — no `src/` changes since (git diff --stat confirms only `.md`/`.yaml` docs touched), so the 52/52 live test result still stands and was not re-run. |

---

## Director Panel Assessment

**Creative Director: CONCERNS**
The art bible's §1.3 mechanism argument is sound — camera tween + continuous sprite rotation genuinely deliver "the room moving, not an icon." But `game-concept.md`'s Pillar 1 text still names the camera as the counterexample to legibility ("not a camera trick"), while the art bible now nominates the camera as the primary proof — an unresolved wording collision between the higher-authority pillar document and the art bible. Recommends a one-line amendment to Pillar 1 distinguishing "world-reorientation (camera + character + eventually props)" from "a HUD readout" before the pillar text gains further binding force. Not a blocker for Pre-Production entry. Also flagged (non-blocking): Section 8 not yet re-checked against §1–4; MVP/Vertical Slice timelines still TBD; "session" scope (one level vs. several) still undecided.

**Technical Director: CONCERNS**
Independently re-verified `architecture.md`, `docs/registry/architecture.yaml`, and `technical-preferences.md` directly. Foundation layer is complete (ADR-0001–0006 Accepted, no Foundation module lacking a decision). Coverage arithmetic checks out (49+0+1+2=52, zero unassigned gaps). Performance budgets are realistic and documented. New finding: `technical-preferences.md`'s Forbidden Patterns/Allowed Libraries/ADR Log placeholders are not just incomplete but actively contradict the registry (36 patterns, 12 ADRs exist), and this file is always-loaded into agent context — recommends fixing as a Pre-Production entry condition. Also flagged: only one system (`prop_gravity`) has a per-system performance budget allocation; ADR-0010's per-frame projection call has none. Carried forward: "4.7" vs "4.7.1" ADR version stamps; empty `tests/integration/`; budgets unmeasured against a baseline.

**Producer: CONCERNS**
Verified repo state directly: 18 `.gd`/18 `.tscn`, `production/stage.txt` still reads "Concept", `tests/integration/` empty, 2 of 18 scripts covered, no sprint/milestone/risk-register artifacts (expected — these are Pre-Production work, not preconditions). No carried Concern rises to a blocker. Flagged: the ADR-0004 migration touching all 18 scenes has no regression safety net, and should get characterization tests before the migration in Sprint 1; only the Full Vision tier has a timeline, MVP/Vertical Slice are still TBD and block realistic capacity planning; the Standard accessibility tier's required settings system (remapping, one-hand presets, text scaling) has no owning ADR or GDD — the largest hidden cost in the plan; ADR-0011/0012 already bind physics props and jug throw, both of which §1.3 just deferred to Vertical-Slice tier — architecture effort is ahead of the MVP tier it's meant to serve.

**Art Director: READY**
Sections 1–4 are real, substantive content, not placeholders. Section 1.3's resolution was verified against the actual implementation (`main.gd`'s `_rotate_camera_to_gravity()`, `player_visual_component.gd`'s continuous `lerp_angle`) — the claims match the code exactly, not a deferred promise. Sections 2–4 trace consistently back to Section 1's principles and the three GDD pillars. Sections 5–7 and 9 remaining undesigned is expected and out of scope for this gate. Closes the 2026-08-16 NOT READY finding cleanly.

**Escalation applied**: No director returned NOT READY, so the verdict floor is **CONCERNS** (three CONCERNS, one READY) rather than FAIL.

---

## Blockers

None. All required artifacts are present; no director returned NOT READY.

---

## Concerns — not blocking this gate

- **Pillar 1 wording collision** — `game-concept.md`'s Pillar 1 clause names the camera as a legibility counterexample; the art bible's §1.3 now relies on the camera as the primary MVP-tier proof mechanism. Recommend a one-line pillar amendment distinguishing world-reorientation from a HUD readout (CD).
- **`technical-preferences.md` placeholders are actively misleading**, not just blank — states "None configured yet" for Forbidden Patterns/Allowed Libraries/ADR Log while 36 patterns and 12 Accepted ADRs exist in the registry, and this file auto-loads into every agent's context (TD).
- **Migration has no regression safety net** — the ADR-0004 collision-layer change touches all 18 scenes with only 2 of 18 scripts unit-tested; `tests/integration/` remains empty (PR, TD).
- **MVP/Vertical Slice timelines are still TBD** — only the Full Vision tier ("1–3 months, solo") has an estimate, and it predates all 12 ADRs (PR).
- **Standard accessibility tier's settings system is unowned** — remapping, one-hand presets, and text scaling have no ADR or GDD (PR).
- **ADR-0011/0012 (physics props, jug throw) are ahead of the MVP tier** — both are now explicitly Vertical-Slice-tier per art-bible §1.3, but already have binding architecture (PR).
- **Per-system performance budget allocation is thin** — only `prop_gravity` has one; ADR-0010's per-frame projection call does not (TD).
- **ADR version stamps read "4.7" not "4.7.1"** — imprecise, unchanged since 2026-08-15 (TD).
- **`production/stage.txt` still reads "Concept"** — expected, since this gate has not returned PASS (PR).
- Section 8 (Asset Standards) has not yet been re-checked against the newly-authored Sections 1–4 (CD).
- "Session" scope (one level vs. several) remains undecided in `game-concept.md` (CD).

---

## Chain-of-Verification

**5 questions checked — verdict unchanged (CONCERNS).**

1. *Could any listed Concern be elevated to a blocker given current state?* — Checked the TD finding that `technical-preferences.md` actively contradicts the registry. The gate's named quality check ("naming conventions and performance budgets set") is satisfied by content that does exist; the contradiction sits in adjacent sections the check doesn't name. Not elevated.
2. *Is the concern resolvable within the next phase, or does it compound?* — All listed Concerns are Sprint-1-sized fixes (a pillar wording edit, a doc correction, adding characterization tests, per-tier re-estimation) — resolvable, not compounding.
3. *Did I soften any FAIL condition into a CONCERNS?* — No. No director returned NOT READY at any point in this run; the escalation rule was applied mechanically.
4. **[TOOL ACTION]** *Are there artifacts I didn't check that could reveal additional blockers?* — The four directors independently re-read `architecture.md`, `docs/registry/architecture.yaml`, `.claude/docs/technical-preferences.md`, `design/art/art-bible.md`, `game-concept.md`, and cross-verified art-bible claims against `main.gd`/`player_visual_component.gd` directly rather than trusting this session's briefing. No hidden gaps surfaced.
5. **[TOOL ACTION]** *Do all the Concerns together create a blocking problem even if each is minor alone?* — Re-read the Producer's own conclusion directly: "No carried Concern rises to a blocker... each is Pre-Production work, not a Pre-Production precondition." Cross-checked against the other three directors' language — none of the eleven listed Concerns names a required artifact or named quality check as unmet. Confirmed: no combination effect.

---

## Verdict: CONCERNS

### Not blocked

13 of 13 required artifacts are present. All four directors returned READY or CONCERNS — none returned NOT READY. The prior run's sole blocker (art bible Sections 1–4) is closed with verified, code-accurate content.

### Recommended before or during early Pre-Production (not gating)

1. Amend Pillar 1's clause in `game-concept.md` to distinguish world-reorientation (camera/character/props) from a HUD readout, closing the CD's wording-collision finding.
2. Correct `.claude/docs/technical-preferences.md`'s Forbidden Patterns / Allowed Libraries / ADR Log sections to reflect the 36 patterns and 12 ADRs that already exist elsewhere.
3. Add characterization tests ahead of the ADR-0004 migration epic, given the empty `tests/integration/` and 2-of-18 unit coverage.
4. Re-estimate MVP and Vertical Slice tier timelines now that all 12 ADRs exist.

Per this gate's own rule, `production/stage.txt` is not updated — the verdict is CONCERNS, not PASS.
