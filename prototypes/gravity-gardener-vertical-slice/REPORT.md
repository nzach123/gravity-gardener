# Vertical Slice Report: Gravity Gardener

> **Date**: 2026-08-17 – 2026-08-18
> **Slice Duration**: 3 build days (sessions 27–29), full ADR-compliant slice per user's "extended timeline" choice — not the skill's default 1–3 week guideline
> **Target Scope**: 3–5 minutes of polished, continuous gameplay
> **Source GDD**: design/gdd/game-concept.md

---

## Validation Question

Does a player, starting from nothing, experience the core fantasy — terraforming a
dying room by routing single-use water buckets through a gravity-flip puzzle while a
non-refilling, geometry-derived oxygen budget counts down — within 3–5 minutes,
without developer guidance? And can we build one such loop, fully compliant with the
governing ADRs and `control-manifest.md`, at a pace that gives us real
production-velocity data?

---

## Scope Built

**Systems included** (9 governing ADRs):
- `GravityAuthority` autoload — world-state gravity, zone-driven flips (ADR-0001)
- `LevelState`/`OxygenState` as injected `RefCounted` objects, `LevelRoot`-owned (ADR-0002)
- `LevelValidation.validate()` at load (ADR-0003)
- Collision layer allocation (ADR-0004)
- Frame-priority ordering + `level_complete` write-once latch (ADR-0005)
- `WateringTuning`/`OxygenTuning` resources via `Tuning` const holder (ADR-0006)
- Player component contract, fixed physics step order (ADR-0007)
- `OxygenDrain` (ADR-0008)
- Bucket pickup/carry/pour via `PlayerWateringComponent`, including the spent-jug
  throw (ADR-0009, ADR-0012)
- Minimal HUD: oxygen readout only (`suit-oxygen.md` R7)

**Explicitly out of scope**: physics props (ADR-0011), settings system, full HUD
(contextual prompts, level tally, pause menu polish), audio, onboarding, wall jump
(no GDD).

**Art/audio quality level:** Placeholder — plain `Polygon2D`/`ColorRect` primitives
stand in for sprites throughout; no audio.
**Shortcuts taken deliberately:** gdUnit4 automated tests skipped for this slice
(played-build validation only, per user's session-28 decision).
**What was cut from original scope:** Nothing beyond the ADRs listed above as
out-of-scope from the start.

---

## Build Velocity Log

| Day | Completed |
|-----|-----------|
| Day 1 | All Foundation + Core + Feature(-0012) + minimal-Presentation **scripts** written against `control-manifest.md` (14 `.gd` files). No scenes, no test run yet. |
| Day 2 | Blocker found and resolved: `src/` and the slice both declared the same global `class_name`s (10 collisions) — gave the slice its own isolated `project.godot`. All `.tscn` files hand-authored, one level built. Headless import (23/23 classes clean) and a 120-frame headless run both clean. |
| Day 3 | Godot MCP tooling diagnosed and fixed (two separate MCP servers, one needed its addon copied into the isolated slice project — see below). Full agent-driven played run via live input simulation: movement, bucket pickup, gravity-flip, oxygen drain/death/reload all confirmed working. Human playtest surfaced a real goal-completion bug (entry-timing race in `goal.gd`); diagnosed, fixed, and verified via both a full agent-driven replay and the human's own completed run. Phase 5 debrief conducted. Verdict: **PROCEED**. |

**Total elapsed:** 3 focused sessions for one complete ADR-compliant core loop
(movement + gravity flip + watering + oxygen + goal), matching all 9 governing ADRs.
**Velocity estimate:** ~1 day to author all scripts for a system set this size
(5 components + 2 autoloads + 4 interactable actors + state/validation layer),
~1 day to wire scenes/scenes-level and pass headless validation, ~1 day to get a
truly played, human-verified loop (including finding and fixing one real bug). For
sprint planning: roughly 3 focused days per single-mechanic-complete, ADR-compliant
vertical loop at this quality bar.

---

## Playtest Results

| Attribute | Value |
|-----------|-------|
| Total sessions | 1 human playtest session (with a real bug found and fixed mid-session), plus 2 agent-driven MCP played-through passes used for pipeline/diagnostic validation |
| Internal testers | 1 (project owner) |
| External testers | 0 |
| Avg session length | Not separately timed — the human session ran long due to live debugging, not core-loop friction alone |
| Time to first meaningful action | Fast, qualitatively — tester reported it was "right when I picked up the bucket and into the gravity zone," i.e., the very first mechanic beat, not buried behind setup |

---

## Observations

**Where testers succeeded without guidance:**
- Found and picked up the first bucket, and reached the gravity zone, without prompting.
- Once told the pour mechanic requires a sustained hold, completed both pours correctly.

**Where testers were confused or stuck:**
- **Mirrored ("inverted") controls when upside-down.** By design, "right" stays tied
  to the character's own right hand (the sprite visually rotates 180° to match), so
  the same key sends the player the opposite way on screen after a gravity flip. The
  tester explicitly disliked this in practice — a real feel finding, not a bug.
- **Gravity zones are completely invisible.** `GravityZone.tscn` has a collision
  shape and a script but zero visual representation. The tester didn't know where
  the zone was until they stumbled into it.
- **No interact prompts anywhere.** Bucket pickup, plant pour, and goal entry all
  require guessing to press E; there is no on-screen cue at any of them.
- **No level-complete feedback.** The only observable effect of winning is that the
  O2 counter silently stops decreasing — no win-screen, no transition, nothing else.
  This made a *real* bug (see below) much harder to diagnose, because a working
  completion and a broken one looked identical to the player.
- **A real goal-completion bug**, found only because of live human play: `goal.gd`'s
  win-trigger originally fired only on the `body_entered` *signal edge*, so if the
  player was already standing in the goal zone (or didn't produce a clean exit+entry)
  at the moment it unlocked, the win never triggered. Fixed by tracking
  overlap state continuously and checking the unlock condition every frame instead
  of only at the entry signal. Verified via a full agent-driven replay
  (`level_complete` confirmed `true`) and independently by the human tester's own
  completed run.

**Emotional reactions observed:**
- Explicit, unprompted dislike of the inverted controls ("I did not like the
  inverted controls when moving upside down").
- Explicit statement that the core fantasy is not yet landing: "needs more agency
  and danger" — specifically, more navigational complexity ("ways to navigate and
  get lost") and more failure modes beyond oxygen depletion ("hazards that can kill,
  harm the player"). The single-room, single-path level with one failure condition
  doesn't yet deliver the intended tension.

---

## Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Time to first meaningful action | Fast (no fixed target set) | Immediate — first mechanic beat (bucket + gravity zone) |
| Session length | 3–5 min continuous | Longer, dominated by live debugging of a real bug, not core-loop friction |
| Critical fun blockers found | 0 | 1 — mirrored control scheme disliked by the tester |
| Pipeline blockers found | 0 | 1 game bug (goal-completion race, fixed and verified) + 1 tooling gotcha (MCP input-simulation server needed its addon copied into the isolated slice project to be usable at all — see Lessons Learned) |
| Architecture surprises | 0 | 0 — all 9 governing ADRs held up as designed; the one real bug was an implementation gap in `goal.gd`, not an architectural flaw |

**Feel assessment:**
- Movement, friction/accel, and jump tuning felt responsive in both agent-driven and
  human testing — no complaints raised about core movement feel.
- The gravity flip mechanic itself (the sprite rotating to match, `up_direction`/
  `right_dir` recomputing cleanly) worked exactly as designed, but the *control
  consequence* of that design (mirrored input) was explicitly disliked.
- The 5-second pour has **zero real-time feedback** — no progress bar, no partial
  color change — only a payoff at the exact moment of completion (plant color jump +
  bucket throw). This reads as "nothing happening" for the full duration of every pour.
- **Correction to a Phase 4 (pre-human-playtest) finding**: the agent's own earlier
  MCP-driven exploration never completed a full loop before oxygen ran out, and that
  was reported as "oxygen_capacity=90 is too tight." The human's actual playthrough
  reached the goal with **65/90 oxygen remaining (72%)** — the budget is not tight
  for a player who knows the route; the earlier finding was an artifact of the
  agent's own slow, stall-heavy exploration pace, not representative of real human
  pacing. Whether it's tight for a genuinely new player without route knowledge is
  still an open question that would benefit from more tester data.

---

## Recommendation: PROCEED

The tester's explicit verdict was "proceed — the loop is working," and the evidence
supports it: a human completed the full spawn → bucket pickup → gravity-flip
traversal → pour ×2 → goal-entry cycle end-to-end, all 9 governing ADRs are
implemented and functioning as designed in a real played build (not just headless),
and the one real bug found during play was diagnosed and fixed within the same
session with both agent-driven and human verification. The core mechanical loop is
sound. What the slice also surfaced — and what PROCEED does not paper over — is that
the *feel* and *legibility* of that loop need real work before Production: the
mirrored control scheme was disliked, critical interaction points have zero visual
affordance (invisible gravity zones, no interact prompts, no win feedback), and the
tester does not yet feel the intended fantasy of agency-under-danger from a
single-room, single-failure-mode level.

---

## If Proceeding

**Production requirements** (what must change from slice to production):
- Resolve the control-scheme concern: get an explicit design decision on
  gravity-relative vs. screen-relative controls (`gravity.md` currently doesn't
  address this) before more levels are built around either assumption.
- Give gravity zones a visual representation in the world geometry — they cannot
  ship invisible.
- Add interact prompts (context UI) at buckets, plants, and the goal.
- Add real-time pour progress feedback (a fill bar or equivalent), not just an
  end-of-hold payoff.
- Add level-complete feedback (a win screen or transition) — the current
  "oxygen silently stops draining" is not sufficient signal, and it actively
  obscured the real bug found this session.
- Re-derive `oxygen_capacity` from a clean, non-debugging human speedrun of the
  route, now that we have one real data point (65/90 remaining) rather than a guess.
- Address the tester's core-fantasy gap directly: more navigational complexity than
  a single room, and at least one failure mode beyond oxygen depletion.

**Architecture adjustments needed:**
- None of the 9 governing ADRs require rework — they held up under real play.
- Worth a control-manifest note (not a new ADR): a win/unlock condition gated on a
  raw `body_entered`/`body_exited` signal edge is a silent-failure trap if the
  unlock state can change while the body is already inside the area. The fix pattern
  (track overlap as state, evaluate the unlock condition every frame) should be the
  documented default for any future "enter this zone to trigger X" mechanic.

**Sprint velocity estimate based on slice data:**
- ~3 focused days per single-mechanic-complete, ADR-compliant vertical loop
  (scripts day, scene-wiring day, played-validation-and-bugfix day). Use this against
  the project's 30–45 day MVP estimate to sanity-check how many comparable systems
  remain.

**Scope adjustments from original design:**
- Feedback/legibility work (prompts, zone visibility, win state, pour progress) was
  treated as pure polish when scoping this slice's minimal HUD. The playtest shows
  it is not polish — its absence directly caused confusion and made a real bug
  indistinguishable from working-as-intended. Budget it as core-loop work, not
  late-stage polish, in Production planning.

**Performance targets:** Not measured this slice — placeholder primitive art is
trivially within budget; revisit once production-quality assets are in.

**Playtest note:** Run `/playtest-report` to structure additional session data
before running `/gate-check pre-production`. Only one internal tester has played
this slice; more sessions (ideally with someone who hasn't seen the build) would
substantially strengthen confidence in the oxygen-budget correction and the
core-fantasy gap noted above.

**Next steps:**
1. `/gate-check pre-production` — formally advance to Production
2. `/create-epics layer:foundation` — plan Foundation layer epics
3. `/create-epics layer:core` — plan Core layer epics
4. `/sprint-plan` — use velocity data from this report in the estimate

---

## Lessons Learned

- **What assumptions were broken by building to near-production quality?** That a
  "minimal HUD, placeholder art" scope decision could stay purely cosmetic. It
  couldn't — the complete absence of interact prompts, zone visibility, and
  win-state feedback actively blocked the player's understanding of a fully working
  loop, and separately made a genuine bug much harder to isolate (a working
  completion and a broken one were visually identical).
- **What surprised us about the pipeline or architecture?** Nothing about the 9
  ADRs themselves — they implemented cleanly and held up under real play. The
  surprise was in tooling: getting a genuinely *played* (input-driven, not just
  headless) test running required copying a Godot editor plugin into the
  deliberately-isolated slice project and launching a second editor instance, plus
  working around an unrelated Windows audio-driver issue that intermittently broke
  the live debug bridge during the session.
- **What would we change about the slice scope if we ran this again?** Include
  interact prompts and a win-state signal from the start, even at placeholder
  quality — they are cheap enough to build in an afternoon and their absence cost
  real debugging time and tester confusion this session. Also: get one *cold* human
  playtest (no developer in the room, no live debugging) before calling any bug
  "confirmed" — the agent's own played-through exploration produced a materially
  wrong finding (oxygen too tight) that only a human run corrected.

---

> *Vertical slice code location: `prototypes/gravity-gardener-vertical-slice/`*
> *This code is reference material only. Production implementation is written from scratch.*
> *Never import or refactor this code into production.*
