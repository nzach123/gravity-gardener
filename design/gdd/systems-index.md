# Systems Index

Master index of all design documents. Update whenever a GDD is added or its status
changes, per `design/CLAUDE.md`.

**Design order:** Foundation → Core → Feature → Presentation → Polish

---

## Designed systems

| System | File | Tier | Status | Depends on |
|---|---|---|---|---|
| Gravity | [`gravity.md`](gravity.md) | Foundation | Reverse-documented, amended | — |
| Watering | [`watering-system.md`](watering-system.md) | Core | Complete draft | `gravity.md`, `suit-oxygen.md`, `physics-props.md` |
| Suit Oxygen | [`suit-oxygen.md`](suit-oxygen.md) | Core | Complete draft | `watering-system.md` |
| Physics Props | [`physics-props.md`](physics-props.md) | Presentation | Complete draft | `gravity.md` |

### Dependency graph

```
gravity.md  (Foundation)
   ├── watering-system.md  ←──────┐  (Core)
   │        │                     │
   │        └──→ suit-oxygen.md ──┘  (Core, mutual)
   │
   └── physics-props.md            (Presentation)
```

`watering-system.md` and `suit-oxygen.md` are **mutually dependent by design**:
watering's bucket layout produces `t_level`, which sets oxygen's `oxygen_capacity`;
oxygen's drain is what gives watering's pour lock a cost.

`physics-props.md` is a **pure consumer** — it reads the gravity vector and affects
nothing. No other document owes it a reciprocal entry.

---

## Cross-document invariants

Rules that span more than one document. Breaking one of these breaks a guarantee
another system relies on.

| Invariant | Owner | Guarded by |
|---|---|---|
| Jump velocity is fixed; only zone gravity changes jump height | `gravity.md` R5 | `watering-system.md` AC1 == `gravity.md` AC11 (one test, both docs) |
| One global gravity vector — no per-body or per-region gravity | `gravity.md` R9 | Keeps `zone_priority` (R8) parked rather than blocking |
| `buckets_total == Σ buckets_required` per level | `watering-system.md` R8 | Load-time validation, AC7 |
| `oxygen_capacity` is derived from bucket layout, never guessed | `suit-oxygen.md` R6 | Level authoring discipline |
| Props never affect level solvability | `physics-props.md` R1 | Collision layer, AC1 / AC2 |

---

## Architecture

`docs/architecture/architecture.md` (v1.0, 2026-08-13) translates all four GDDs
above into a technical blueprint. It extracts a 52-requirement baseline
(`TR-gravity-*`, `TR-watering-*`, `TR-oxygen-*`, `TR-props-*`), maps every system
to a layer, and lists the 12 ADRs required before implementation.

### Pending GDD amendments

Architecture decisions that contradict what these documents currently say. Resolve
via `/propagate-design-change` once the relevant ADR is accepted — **do not edit
the GDDs ahead of the ADR**.

| GDD | Section | Amendment needed | Driver |
|---|---|---|---|
| `watering-system.md` | §6 Code | Ownership moves from `GameManager` to an injectable `LevelState` | ADR-0002 (D2) |
| `suit-oxygen.md` | §6 | Ownership moves from `GameManager` to an injectable `OxygenState` | ADR-0002 (D2) |
| `gravity.md` | §5 Edge Cases | Init-order hazard **stays** and gains an explicit guard requirement; do not delete it | ADR-0001 (D7) |
| `gravity.md` | §3 / §7 | Levels gain `default_gravity_direction` / `_multiplier`; gravity now survives scene reload and must be reset | ADR-0001 (D6) |
| `physics-props.md` | §3 R3 | Props receive gravity via default-space physics, not by subscribing individually | ADR-0001 (D3) |

### New requirement with no GDD home

`level_complete` — the flag that lets `watering-system.md` AC13 (pour + zero
oxygen → death) and `suit-oxygen.md` AC8 (airlock + zero oxygen → completion)
coexist. Without it the two criteria directly contradict each other. Currently
specified only in the architecture document; needs an owner in one of the two
GDDs.

## Implemented but undocumented

Systems that exist in code with no GDD. Listed so the gap is visible, not to imply
each one needs a document.

| System | Code | Note |
|---|---|---|
| Wall jump | `player_wall_jump_component.gd` | Traversal mechanic, undocumented |
| Moving platforms | `moving_platform.gd` | Level element, undocumented |
| Spike hazards | `spike_hazard.gd` | Shares the restart path with oxygen death |
| Level flow / progression | `main.gd`, `goal.gd` | 8 levels, `change_scene_to_packed` chain |
| Start menu | `start_menu.gd` | No pause menu exists — required by `suit-oxygen.md` §5 |

---

## Designed but not built

| Requirement | Source | Note |
|---|---|---|
| HUD | `suit-oxygen.md` R7, `watering-system.md` §6, `design/ux/hud.md` | Oxygen readout, contextual watering prompts, and the level tally. **Carry state is diegetic — not a HUD element** (§6 amended 2026-08-15). **No HUD scene exists** |
| Physics props | `physics-props.md` | No props exist in any level |
| Bucket economy | `watering-system.md` | All 8 levels use the old one-bucket / many-plants model |
| Oxygen budgets | `suit-oxygen.md` R6 | `O_level` not yet computed for any level |

---

## Not yet designed

`game-concept.md` was written 2026-08-15 via `/reverse-document`, sourced from
the four GDDs below plus `src/`, to unblock the art bible gate. It carries
several ⚠ TBD sections (session structure, retention systems, comparable
titles) not yet confirmed by the user. `game-pillars.md` as a standalone
document still does not exist — the three pillars currently live only inside
`game-concept.md`.

**Settings system** — the long-tracked gap first noted against `hud.md`'s
declined-scope table and reconfirmed by the 2026-08-17 `/gate-check
pre-production` re-run's Producer gate as "the largest hidden cost in the
plan." `accessibility-requirements.md` specifies full input remapping, the
two one-hand presets, and 1×/2× text scaling in detail, but no GDD or ADR
owns *how* any of it is built, and no menu system exists in `src/` at all.
Scoped (not authored) 2026-08-17, session 28:

- **GDD**: `design/gdd/settings-system.md` (Presentation tier). In scope:
  the settings screen itself; full remapping of the 5 existing actions
  (`move_left`, `move_right`, `jump`, `interact`, `crouch`) with
  duplicate-binding prevention and cross-restart persistence; the two
  one-hand presets as pre-filled, further-editable remap sets; 1×/2× text
  scaling. Out of scope for this GDD: the `drain_rate` difficulty slider,
  the reduced-motion toggle (blocked on the unowned camera-rotation
  decouple — `TR-gravity-010`, `accessibility-requirements.md` A7), audio
  controls (no audio system exists), and screen-reader support.
- **ADR** (next number: **ADR-0013**): decides runtime InputMap remapping
  and capture, the persistence mechanism (likely a `ConfigFile` at
  `user://`), where live settings state lives (a new autoload, parallel to
  `GameManager`), how one-hand presets compose with remapping, and how
  text-scale threads into `hud.md`'s rendering. This would be the project's
  first Control-based menu and would set the pattern for any future menu.

Full section-by-section authoring of both documents is deferred to a
dedicated future session per `design/CLAUDE.md`'s incremental-authoring
rule.
