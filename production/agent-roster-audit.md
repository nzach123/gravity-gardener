# Agent & Skill Roster Audit — Gravity Gardener

- **Date**: 2026-08-18
- **Stage**: Pre-Production (vertical-slice)
- **Scope**: Audit of all available Claude Code subagents and skills against the
  project's GDD (`design/gdd/`), technical preferences, and stated non-goals
  (`design/gdd/game-concept.md`).
- **Basis**: GDD covers gravity, hazards, level-flow, physics-props, suit-oxygen,
  watering-system only. `game-concept.md` explicitly disclaims combat, narrative,
  multiplayer/networking, live-ops, and monetization as of this date. Engine is
  Godot 4.7.1 / GDScript only (no C#, no GDExtension in use).

## Decision

Keep / Deprecate / Remove per system-level recommendation below. Deprecated items
are not deleted — they're deferred to a later project stage (Production/Polish/
Release) where they become relevant without needing re-evaluation. Removed items
are out of scope for this game's design and engine.

## Agents

| Agent | Decision | Rationale |
|---|---|---|
| accessibility-specialist | KEEP | `design/accessibility-requirements.md` sets a Standard WCAG-AA commitment. |
| ai-programmer | REMOVE | No enemies/AI — hazards are static per `hazards.md`. |
| analytics-engineer | REMOVE | No telemetry/A-B infra planned pre-launch. |
| art-director | KEEP | Owns the completed art bible. |
| audio-director | KEEP | Planned, unstarted department lead. |
| claude, claude-code-guide, Explore, general-purpose, Plan, statusline-setup | KEEP | Infra, not game-domain-scoped. |
| community-manager | DEPRECATE | No player base yet; revisit at Release. |
| creative-director | KEEP | Required binding decision-maker. |
| devops-engineer | KEEP | Owns CI/build and the gdUnit4 test command. |
| economy-designer | REMOVE | No resource economy/loot in GDD. |
| engine-programmer | DEPRECATE | Not building custom engine internals; godot-specialist covers this. |
| game-designer | KEEP | Owns core mechanics/GDDs. |
| gameplay-programmer | KEEP | Implements mechanics in GDScript. |
| godot_developer_generalist | DEPRECATE | Overlaps godot-specialist/godot-gdscript-specialist — consolidate. |
| godot-csharp-specialist | REMOVE | GDScript-only project. |
| godot-gdextension-specialist | DEPRECATE | No native extensions in use. |
| godot-gdscript-specialist | KEEP | Required by technical-preferences.md. |
| godot-shader-specialist | KEEP | Required for .gdshader/VisualShader work. |
| godot-specialist | KEEP | Primary engine specialist, required. |
| lead-programmer | KEEP | Owns code review/architecture translation. |
| level-designer | KEEP | Owns level-flow.md/hazards.md. |
| live-ops-designer | REMOVE | No live-ops/seasons/retention in GDD. |
| localization-lead | DEPRECATE | Single-language, keyboard-only PC target today. |
| narrative-director | KEEP | Kept as a dependency of `team-level` (reversed from initial REMOVE). |
| network-programmer | REMOVE | No multiplayer/networking (explicit in game-concept.md). |
| performance-analyst | KEEP | Enforces defined FPS/memory budgets. |
| producer | KEEP | Primary coordination agent, required. |
| prototyper | KEEP | Already used for the vertical-slice build. |
| qa-lead, qa-tester | KEEP | Test strategy and active bug tracking. |
| release-manager | DEPRECATE | No store/cert work at this stage. |
| security-engineer | DEPRECATE | No networking/accounts/anti-cheat surface yet. |
| sound-designer | KEEP | Produces SFX specs. |
| systems-designer | KEEP | Owns gravity/oxygen/watering formulas. |
| technical-artist | KEEP | VFX/shader-to-engine pipeline; some overlap with godot-shader-specialist flagged. |
| technical-director | KEEP | Required binding technical decision-maker. |
| tools-programmer | DEPRECATE | godot-ai/godot MCP servers already cover tooling needs. |
| ue-blueprint-specialist, ue-gas-specialist, ue-replication-specialist, ue-umg-specialist | REMOVE | Unreal Engine, not the project's engine. |
| ui-programmer | KEEP | Implements completed menu/HUD UX specs. |
| unity-addressables-specialist, unity-dots-specialist, unity-shader-specialist, unity-specialist, unity-ui-specialist | REMOVE | Unity, not the project's engine. |
| unreal-specialist | REMOVE | Unreal, not the project's engine. |
| ux-designer | KEEP | Authored menu/HUD UX and accessibility docs. |
| world-builder | KEEP | Kept as a dependency of `team-level` (reversed from initial REMOVE). |
| writer | REMOVE | No dialogue/lore/item-description content planned. |

**Final tally**: 26 KEEP, 10 DEPRECATE, 19 REMOVE.

## Skills

| Skill | Decision | Rationale |
|---|---|---|
| asd-ste | KEEP | Mandated by CLAUDE.md. |
| find-skills, help, start, onboard, update-config, keybindings-help, fewer-permission-prompts, loop, schedule, skill-improve, skill-test, artifact-design, artifact-diagramming, artifact-capabilities, claude-api, run, init | KEEP | Claude Code infra/meta, independent of game scope. |
| grill-me, grilling | KEEP | Overlapping pair — recommend consolidating to one. |
| adopt | DEPRECATE | Project already actively maintained. |
| architecture-decision, architecture-review, create-architecture, create-control-manifest | KEEP | Active ADR/architecture pipeline (14 accepted ADRs). |
| art-bible | KEEP | Maintenance path for the completed art bible. |
| asset-audit, asset-spec | KEEP | Applicable to the art/asset pipeline. |
| balance-check, quick-design | KEEP | Used for gravity/oxygen/watering tuning. |
| brainstorm | DEPRECATE | Concept phase closed. |
| bug-report, bug-triage | KEEP | Actively used; one open bug on record. |
| changelog, patch-notes | DEPRECATE | No shipped build/patch cadence yet. |
| code-review, simplify | KEEP | Core dev-quality skills. |
| consistency-check, propagate-design-change | KEEP | Used to resolve prior doc conflicts (D7.4/R11). |
| content-audit | KEEP | Tracks planned vs. built content. |
| create-epics, create-stories, dev-story, story-readiness, story-done | KEEP | Core production/implementation loop. |
| day-one-patch, hotfix, launch-checklist, release-checklist, soak-test | DEPRECATE | Release/live-service-stage skills; not shipped yet. |
| design-review, design-system, review-all-gdds | KEEP | Active GDD authoring/QA pipeline. |
| estimate, sprint-plan, sprint-status, retrospective, milestone-review, tech-debt | KEEP | Lightweight production tracking, fits solo/small team. |
| gate-check, project-stage-detect | KEEP | Used for the pre-production gate. |
| localize | DEPRECATE | No i18n scope; single-language, keyboard-only PC. |
| map-systems | KEEP | Already used for the systems index. |
| perf-profile | KEEP | Enforces FPS/memory budgets. |
| playtest-report | KEEP | Used for the vertical-slice PROCEED verdict. |
| prototype, vertical-slice | KEEP | Stage-defining skills; already run this cycle. |
| qa-plan, smoke-check, test-evidence-review, test-helpers, test-setup, regression-suite | KEEP | Active gdUnit4-based QA pipeline. |
| reverse-document | DEPRECATE | Niche, occasional use. |
| scope-check | KEEP | Directly applicable — this audit is an instance of its use. |
| security-audit, security-review | DEPRECATE | No networking/multiplayer/public release surface yet. |
| setup-engine | KEEP | Already used to pin Godot 4.7.1. |
| test-flakiness | DEPRECATE | Polish-phase concern; suite too small now. |
| ux-design, ux-review | KEEP | Active — produced HUD/menu UX specs. |
| team-audio | KEEP | Wraps in-scope agents. |
| team-combat | REMOVE | No combat system exists or is planned. |
| team-level | KEEP | Dependencies (narrative-director, world-builder) kept per decision above. |
| team-live-ops | REMOVE | Depends on live-ops-designer, economy-designer (both REMOVE). |
| team-narrative | REMOVE | Still depends on writer (REMOVE); no narrative feature planned. |
| team-polish | KEEP | Future Polish-phase dept team, low cost to retain. |
| team-qa, team-ui | KEEP | Active QA and UI pipelines. |
| team-release | DEPRECATE | Depends on release-manager (DEPRECATE). |
| design (Claude Design canvas) | DEPRECATE | Optional mockup tool; UX work already covered. |
| dataviz | REMOVE | No dashboards/analytics surfaces in this game. |
| claude-in-chrome | REMOVE | Irrelevant to a native Godot desktop build. |

**Final tally**: ~62 KEEP, ~18 DEPRECATE, ~6 REMOVE.

## Notes

- Deprecated ≠ deleted — nothing was removed from disk as part of this audit; this
  document is a record of the decision only.
- Two overlaps flagged for future consolidation, not acted on: `godot_developer_generalist`
  vs. `godot-specialist`/`godot-gdscript-specialist`; `grill-me` vs. `grilling`.
- Revisit this audit at the Production→Polish and Polish→Release gate checks, since
  several DEPRECATE items (release-manager, security-engineer, localization-lead,
  release/launch skills) become relevant as the project advances stage.
