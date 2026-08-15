# Gate Check: Technical Setup → Pre-Production

- **Date**: 2026-08-15
- **Checked by**: `/gate-check pre-production`
- **Review mode**: `lean` (`production/review-mode.txt`)
- **Branch / commit**: `claude-refactor` @ `0a02de0` — working tree clean
- **Verdict**: **FAIL**

> Sessions 13 and 14 are committed as of `0a02de0`. Any "UNCOMMITTED" header in
> `production/session-state/active.md` predating this report is stale.

---

## Required Artifacts — 9 of 13 present

| | Artifact | Evidence |
|---|---|---|
| ✅ | Engine chosen | `CLAUDE.md:8` — Godot 4.7.1, not `[CHOOSE]` |
| ⚠️ | Technical preferences configured | `.claude/docs/technical-preferences.md` populated, but 3 stale placeholders — see Concerns |
| ❌ | Art bible §1–4 | **MISSING** — `design/art/` does not exist |
| ✅ | ≥3 Foundation ADRs | 6 ADRs in `docs/architecture/`, **all `Accepted` 2026-08-15** |
| ✅ | Engine reference docs | `docs/engine-reference/godot/` — `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/{core,physics-2d,ui-control}.md` |
| ✅ | `tests/unit/` + `tests/integration/` | Both exist (`integration/` is empty) |
| ✅ | CI test workflow | `.github/workflows/tests.yml` |
| ✅ | Example test file | 3 suites — **52/52 pass, 0 errors, 0 failures, exit 0**, executed during this gate |
| ✅ | `docs/architecture/architecture.md` | 44 KB, complete |
| ❌ | `docs/architecture/requirements-traceability.md` | **MISSING** — no file of any similar name repo-wide |
| ✅ | `/architecture-review` report | `docs/architecture/architecture-review-2026-08-15.md` (verdict CONCERNS) |
| ❌ | `design/accessibility-requirements.md` | **MISSING** |
| ❌ | `design/ux/interaction-patterns.md` | **MISSING** |

**Absence verified by repo-wide search**, not by checking one path. A `find` for
`*art-bible*`, `*accessibilit*`, `*interaction-pattern*` and `*traceab*` across the
whole tree (excluding `.claude/skills/` and `.claude/docs/templates/`) matched exactly
one file: `.claude/agents/accessibility-specialist.md`, which is an agent definition.
No alternate-named equivalent of any of the four exists.

---

## Quality Checks — 6 of 10 passing

| | Check | Result |
|---|---|---|
| ✅ | ADR dependency graph acyclic | 0001→∅, 0002→∅, 0003→{0001, 0002}, 0004→∅, 0005→0002, 0006→∅. No cycle. |
| ✅ | All ADRs have an Engine Compatibility section | 6 / 6, each with a Knowledge Risk rating |
| ✅ | All ADRs have a GDD Requirements Addressed section | 6 / 6 |
| ✅ | No deprecated API usage | Every row of `deprecated-apis.md` (`add_image`, `update_image`, `AccessibilityLiveMode`, `tap_back_pos`, Bullet) grepped against all 6 ADRs, `architecture.md` and `hud.md`. **Zero hits.** |
| ✅ | HIGH RISK engine domains addressed | `architecture.md:29–62` closes Control offset transforms HIGH→LOW with sourced verification; Jolt / AreaLight3D / HDR / stencil correctly ruled N/A for a GL-Compatibility 2D game |
| ✅ | Naming conventions + performance budgets set | `technical-preferences.md` — 60 FPS / 16.6 ms / <500 draw calls / 512 MB |
| ❌ | Accessibility tier defined | No file, no tier. Undefined is explicitly not acceptable at this gate |
| ❌ | Traceability matrix has zero Foundation gaps | **Unverifiable — the matrix does not exist.** See blocker 4 |
| ⚠️ | Architecture covers rendering / input / state management | State management ✅ (ADR-0002, ADR-0005). Input has no ADR — assigned to ADR-0007, unwritten. Rendering is 2D GL-Compat, effectively N/A |
| ⚠️ | All ADRs agree on engine version | All six stamp "4.7"; the project pins **4.7.1**. Internally consistent, and a deliberate session-13 call (4.7.1 is in the 4.7 series) — imprecise rather than wrong |

---

## Blockers

### 1. No art bible

`design/art/art-bible.md` is a required artifact at this gate, and the *next* gate
(Pre-Production → Production) needs all 9 sections plus an AD-ART-BIBLE sign-off.

Two dependencies to expect when `/art-bible` runs:

- **QQ-06** — there is no `game-concept.md` and no pillars document, so the Visual
  Identity Anchor has no upstream source to derive from.
- The **NES palette** constraint (`hud.md` U8.15 — `docs/Pallete/nes-aesprite-1x.png`,
  56 colours) is project-wide and currently parked in a HUD document. It belongs in the
  art bible. Raised as session 8's Q4 and open ever since.

**Fix**: `/art-bible` (sections 1–4 satisfy this gate).

### 2. No accessibility requirements document

Fails both the artifact check and the "accessibility tier is defined" quality check.
`hud.md` **H24** is still recorded as blocked on a text-size option that no tier exists
to mandate.

**Path decided during this gate**: `design/accessibility-requirements.md` — the location
named by this skill, by `/ux-review`, and by `hud.md` Q1.
**Owed edit**: `design/CLAUDE.md:36` currently says `design/ux/accessibility-requirements.md`
and must be corrected to match, or the next reviewer reports the file missing either way.
This ambiguity was first flagged as session 9's advisory finding 7.

**Fix**: `/ux-design` — creates this file and the pattern library in one pass.

### 3. No interaction pattern library

`design/ux/interaction-patterns.md` is required "even if minimal". `hud.md` invented
**three** new interaction patterns with no library to hold them — recorded as session 8's
Q5 and unaddressed since.

**Fix**: `/ux-design patterns`.

### 4. No traceability index — and no baseline underneath it

`docs/architecture/requirements-traceability.md` is absent. This is the one blocker that
is not merely a missing file.

The 52-requirement TR baseline **has never been written**. `architecture.md:9` and
`systems-index.md:58` both describe it as extracted and mapped; every occurrence of a TR
ID in the repo is a citation, and the table itself does not exist. The 2026-08-15
architecture review *reconstructed* the allocation (13/18/12/9 = 52, no gaps or overlaps)
and found **22 covered / 28 gaps**, but only **7 of 52 IDs are confirmed verbatim — 45 are
inferred**.

Writing the traceability index on top of inferred IDs would make those inferences the
anchor every future story cites. `tr-registry.yaml` was offered and **declined on
2026-08-15**; that decision is what now blocks this gate.

**Fix**: decide `tr-registry.yaml` first, then author `requirements-traceability.md`.

---

## Concerns — not blocking this gate

### `architecture.md` Document Status is stale and now contradicts six Accepted ADRs

| Location | Says | Reality |
|---|---|---|
| `:10` | "ADRs Referenced: none exist — 12 required" | 6 written, all Accepted |
| `## ADR Audit` | "**No ADRs exist**, so there is nothing to audit" | 6 exist and were audited by this gate |
| `### Traceability coverage` | "**0 of 52 requirements covered. 52 gaps.**" | 22 covered per the 2026-08-15 review |

### Two 🔴 defects tracked since session 7 are FIXED — record this

Neither session 12 nor session 14 noticed. Verified against disk during this gate:

- **Prop layer/mask** now reads `collision_layer = 8 (PROP)` / `collision_mask = 9
  (WORLD | PROP)` at `architecture.md:711`, matching ADR-0004 D4.1/D4.3. The old
  `PROP(4)` / `WORLD(1)|PROP(4)` text is gone — copying it no longer authors the retired
  bit 3.
- **A2-01 is closed.** `LevelState` at `architecture.md:509+` now declares `_buckets_total`,
  `_buckets_consumed`, `_goal_unlocked`, `_level_complete` as backing fields behind
  getters, not plain `var`. This was the prior review's one blocking finding.

### Still stale in `architecture.md`

- `:81`, `:96`, `:169` — `CollisionLayerRegistry`; ADR-0004 **D4.4** renames it `CollisionLayers`.
- `:108` — HUD row still lists "carry indicator" as a HUD responsibility. This is session
  14's **advisory finding 1**, and it is owed to `/propagate-design-change`, not a hand
  edit — it is stale in the exact document ADR-0010 will be written from.
- `PhysicsProps` vs `PropBody` naming split (`:68`, `:109`, `:212`, `:220`, `:364`) —
  pre-existing, flagged since session 5.

### `technical-preferences.md` placeholders are stale

- `:60` — "Architecture Decisions Log: *No ADRs yet — use /architecture-decision*". Six
  ADRs are Accepted.
- `:50` — "Forbidden Patterns: *None configured yet*". `docs/registry/architecture.yaml`
  carries **27** `forbidden_patterns` entries.
- `:55` — "Allowed Libraries / Addons: *None configured yet*". gdUnit4 is in use.

### `production/stage.txt` says `Concept`

Wrong regardless of this verdict — the project is in Technical Setup. The gate skill only
writes this file on PASS, so it is left untouched.

### Carried open items, unchanged by this gate

- **ADR-0006 T4** — `@export_range` constrains the inspector only. Documentation only,
  never executed. ADR-0006 Migration Plan step 5 must run it.
- **ADR-0001 Verification Required #2** — a default-space gravity write in
  `_physics_process` reaching every `RigidBody2D` in the same step. `gravity.md` **AC12**
  rests on it.
- **C7** — two discharged verification items still live in the registry.
- **C3 / C8** — obligations ADR-0009 inherits.
- **Q17** — Z2 has the same occlusion problem Z1's fix closed; scoped out on purpose in
  session 14. Needs a decision before ADR-0010.
- **QQ-05** — wall jump, moving platforms and spike hazards are implemented with no GDD,
  no TR IDs and no ADR coverage.
- `src/` remains completely untouched across all 14 sessions. **BUG-0001** (dead
  out-of-bounds kill plane) is still Open.

### Director Panel — not run

Lean mode calls for all four directors (CD / TD / PR / AD PHASE-GATE). Session rules bar
unrequested subagents — the standing convention since the 2026-08-15 architecture review,
recorded there as a known gap. It does not change the outcome: a director can only lower a
verdict, and the artifact checks already fail. Worth running before the *next* gate, where
AD-PHASE-GATE gates the art bible sign-off directly.

---

## Chain-of-Verification

**5 questions checked — verdict unchanged.**

1. *Have I accurately separated hard blockers from strong recommendations?* — Yes. All four
   blockers are named Required Artifacts in the gate definition; two (accessibility,
   traceability) are additionally named quality checks.
2. **[TOOL ACTION]** *Are the four artifacts genuinely absent, or present under another
   name?* — Repo-wide `find` across four name patterns. Genuinely absent.
3. **[TOOL ACTION]** *Are there PASS items I was too lenient about?* — Re-read
   `technical-preferences.md`: three stale placeholders found, downgrading that artifact
   from ✅ to ⚠️. Re-read `architecture.md:505–522` and `:676–715`: the two 🔴 defects are
   fixed, which moves in the *other* direction. Verdict unaffected either way.
4. *Am I missing additional blockers?* — The test suite was executed rather than assumed
   (52/52, exit 0), and the ADR dependency graph was built from the actual "Depends On"
   rows rather than from the session-state summary. No new blocker surfaced.
5. *Is the failure resolvable, or does it indicate a deeper design problem?* — Resolvable.
   The architecture tier is in good shape; the gap is entirely in the art and UX
   foundation layer, which was deferred while ADR work ran ahead of it. Only blocker 4
   requires a decision rather than a document.

---

## Verdict: FAIL

Four required artifacts are missing and one of them — the accessibility tier — is a named
quality gate in its own right. Nothing found here is a design problem. The architecture
tier is genuinely healthy: six Accepted ADRs, an acyclic dependency graph, engine-validated
with no deprecated API use, and a green 52/52 suite.

### Minimal path to PASS — three actions

1. `/art-bible` — sections 1–4 satisfy this gate.
2. `/ux-design` — produces `design/accessibility-requirements.md` **and**
   `design/ux/interaction-patterns.md`. Correct `design/CLAUDE.md:36` to the decided path
   in the same pass.
3. Decide `tr-registry.yaml`, then author `docs/architecture/requirements-traceability.md`.

### Not blocked by any of the above

**ADR-0007** (player component contract) — 5 gravity + 2 watering requirements, owns
`TR-watering-014` (AC1), and `watering-system.md` names it as the one to write first. Then
ADR-0008, then ADR-0009.
