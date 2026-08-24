# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7.1
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Game
2D Platformer where the player can change gravity, must collect water and water his plants before running out of oxygen

## Agent
this project is using Godot engine, use a Godot agent to ensure accurate context.

## Model Orchestration Policy

This policy applies to every session. It sets which model does which work.

### Opus 5 -- orchestrator (main session)

- Opus 5 at high effort owns the main session. It owns requirements,
  judgment, integration, and final verification.
- Opus 5 does not run large builds inline. For a bounded, difficult
  implementation, Opus 5 writes the spec, dispatches an Opus 5 executor
  subagent, and verifies the result.
- Opus 5 stays at requirements, judgment, and integration. An executor
  that converges fast on an approved spec is correct behavior. It is
  not a defect.
- Brief a subagent on five items only: the exact delta, the scope, the
  output, the stopping condition, and the exclusions.

### Opus 5 -- executor (put these lines in every executor prompt)

- Deliver the requested scope. Stop before unasked work.
- Correct an immaterial slip silently. Report a correction only when it
  changes a number, a conclusion, or a decision.
- Do not replace grounding or fresh retrieval with confidence or
  self-review.

### Sonnet 5 -- fan-out worker

- Dispatch Sonnet 5 freely for fan-out that needs per-item judgment:
  blind reader panels, audits, and workspace sweeps.
- Give it an exact brief, a defined output, and a stopping condition.
- Complete the exact requested deliverable and stop. Do not audit the
  surrounding system. Do not report adjacent issues. Do not recommend
  extra improvements.
- A request to diagnose or to report does not authorize a fix. A
  one-file request does not authorize related changes.
- Do not create subagents. Do not delegate.

### Haiku -- mechanical worker

- Haiku agents do bounded mechanical reads and transforms.
- Give an exact brief. Require a compact return. Do not delegate again.
- Return extracted key numbers and paths. Do not return raw dumps.

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

##Lang

always use the /asd-ste100 skill
