# Vertical Slice: Gravity Gardener

## Hypothesis

A player, starting from nothing, can experience the core fantasy — terraforming
a dying room by routing single-use water buckets through a gravity-flip puzzle
while a non-refilling, geometry-derived oxygen budget counts down — within
3–5 minutes, without developer guidance. And this loop can be built fully
compliant with ADR-0001 through ADR-0010 and `control-manifest.md` at a pace
that gives the project real production-velocity data.

Full scope and rationale: `production/session-state/active.md`.

## How to Run

This slice is its own Godot project (isolated from the repo root project to
avoid `class_name` collisions with `src/` — `Player`, `Bucket`, `Plant`, `Goal`,
`GravityZone`, and the five `Player*Component` classes are all declared in
both). Open or run
`prototypes/gravity-gardener-vertical-slice/project.godot` directly; it does
not use the repo's `project.godot`.

```
Godot_v4.7.1-stable_win64_console.exe --path prototypes/gravity-gardener-vertical-slice
```

Controls: A/D move, Space jump, E interact (pick up bucket / pour), Shift crouch (unused this slice).

## Status

In progress — Phase 4 (implement) of the `/vertical-slice` workflow.

## Findings

Not yet concluded — populated at Phase 5 (playtest debrief) / Phase 6 (`REPORT.md`).
