# Story 005: Restart reset is structural, and runtime spawning is banned

> **Epic**: Physics Props
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S (1-2 hours — this story mostly *proves* a property rather than building one)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/physics-props.md` (R6, AC8, §5)
**Requirement**: `TR-props-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Physics prop body, lifetime and speed cap
**Governing ADRs**: ADR-0011 (primary, D11.4) · ADR-0002 (secondary — supplies the
reconstruction restart that makes D11.4 structural)
**ADR Decision Summary**: ADR-0011 adds **no reset pass**, because ADR-0002 part 2
already made restart *reconstruction*: `restart_level()` is `reload_current_scene()`
alone, which frees the level scene and builds a fresh one from the authored `.tscn`.
Authored transforms come back because the nodes holding them are new. That guarantee
holds on exactly one condition, which D11.4 makes explicit: **props are authored scene
children only** — no prop may be spawned at runtime, pooled, respawned, or persisted
across a scene reload.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `reload_current_scene()` is pre-4.4 API, unchanged through 4.7. Note
the project's probed Godot 4.7.1 semantics for freed objects: a freed `Object` compares
`== null` as **true**, and `as` on one errors. Any post-restart assertion that walks a
pre-restart reference list must account for that.

**Control Manifest Rules (this layer)**:
- Required: "No prop may be spawned, pooled, respawned, or persisted at runtime — props
  are authored scene children only; restart correctness depends on it." — source:
  ADR-0011 (D11.4)
- Forbidden: "Never spawn, pool, respawn, or persist any `PropBody` at runtime." —
  source: ADR-0011 (`runtime_prop_instantiation`)
- Required: "`unregister_prop()` MUST be called from `PropBody._exit_tree()`" — this is
  what keeps the registry correct across a reload. — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/physics-props.md` R6 and AC8, and ADR-0011 D11.4 / V9, scoped to
this story:*

- [ ] After a restart, **every** `PropBody` global transform equals its authored value,
      following a flip that scattered them (V9). Position and rotation both.
- [ ] No reset method, reset pass, or transform-restoring code is added anywhere. The
      property comes from ADR-0002's reconstruction and from nothing else.
- [ ] `GravityAuthority`'s prop registry is correct after a restart — it holds the new
      scene's props and no stale entries from the freed one.
- [ ] A CI grep step rejects runtime prop instantiation: no `PropBody.new()`,
      no `preload`/`load` of `prop_body.tscn` followed by `instantiate()`, and no
      `add_child()` of a `PropBody` outside a `.tscn`.
- [ ] The grep is wired into the same CI job as the existing ADR-0006 tuning-ban greps,
      and fails the build rather than warning.
- [ ] `runtime_prop_instantiation` is registered as a forbidden pattern in
      `docs/registry/architecture.yaml` with ADR-0011 as its owning ADR.
- [ ] The test file is warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0011 D11.4:*

**This story writes very little code, and that is the point.** R6 and AC8 are satisfied
by object lifetime, not by a function. The work here is (a) proving that with V9, and
(b) installing the guard that keeps it true.

> **Props are authored scene children only.** No prop may be spawned at runtime, pooled,
> respawned, or persisted across a scene reload.

A runtime-spawned prop has no authored transform to return to, so R6 would stop being a
property of object lifetime and start being a reset function somebody has to maintain —
the exact failure ADR-0002 was written to remove.

**Be honest about how strong the guard is.** ADR-0011 assesses it plainly: this is
enforced by review and grep, not by structure — the same weakness ADR-0004 D4.6 admits
about its own runtime-mutation ban. The grep is therefore load-bearing, and it should be
written to catch the *shapes* a future author would actually reach for, not just the
literal string `PropBody.new()`.

**Precedent for the CI step**: `collision-layer-registry` story 005 added CI greps for
the ADR-0006 tuning bans (commit `2e7d1b5`). Match that job's structure and failure
behaviour rather than inventing a second mechanism.

**The cost this ban buys, recorded so nobody re-litigates it casually.** Any future
feature that wants a breakable crate spawning debris, or a prop dropped by an event,
needs a **new decision** first — not an exception. ADR-0011 lists this under Consequences
→ Negative as a deliberate cost paid for a structural R6.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: out-of-bounds freeing. A freed prop and a restarted level are different
  lifetimes — do not merge the two tests.
- **Story 003**: the `reset_to()` space write. That story asserts the *space*; this one
  asserts *transforms*.
- **ADR-0002's restart path itself.** `restart_level()` and `reload_current_scene()`
  belong to the `level-outcomes` epic. This story consumes that behaviour and adds
  nothing to it.
- **Prop content authoring.** V9 runs against a test fixture, not against a furnished
  level — prop content is deferred to Vertical-Slice tier by `art-bible.md` §1.3.

---

## QA Test Cases

*Derived from ADR-0011 V9 and D11.4. The developer implements against these — do not
invent new test cases during implementation.*

- **AC-1** (V9): scattered props return to authored transforms
  - Given: a fixture level with several `PropBody` instances at known authored transforms
  - When: a gravity flip scatters them to demonstrably different positions, then the
    level restarts via `reload_current_scene()`
  - Then: every prop's `global_transform` equals its authored value
  - Edge cases: assert **rotation as well as position** — a flip tumbles props, and a
    position-only assertion passes on a half-broken restart; capture the scattered
    positions and assert they actually differed from the authored ones before the
    restart, otherwise the test can pass without ever having scattered anything

- **AC-2**: the registry survives the reload cleanly
  - Given: the fixture, restarted
  - When: the new scene has finished `_ready()`
  - Then: the registry count equals the authored prop count — no stale entries, no
    doubled entries
  - Edge cases: a freed `Object` compares `== null` as **true** in Godot 4.7.1, so assert
    the registry's count and the identity of its members, not merely that no entry is
    null

- **AC-3**: no reset code was added
  - Given: the repository diff for this story
  - When: it is reviewed
  - Then: it contains no method that writes a `PropBody` transform, and no
    `reset()`-shaped prop function
  - Edge cases: this is a review assertion. If a reset pass appears, the story has solved
    the wrong problem — the restart property must come from ADR-0002's reconstruction

- **AC-4**: the CI grep rejects runtime instantiation
  - Given: a scratch branch with a deliberate `PropBody` instantiation added at runtime
  - When: CI runs
  - Then: the build fails, naming `runtime_prop_instantiation`
  - Edge cases: test at least three shapes — `PropBody.new()`, a `load()`/`instantiate()`
    pair on `prop_body.tscn`, and an `add_child()` of an instantiated prop scene. A grep
    that catches only the first is close to useless, since it is the least likely form a
    real author would write

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/physics/prop_restart_reset_test.gd` — must
exist and pass (BLOCKING per `.claude/docs/coding-standards.md`)

Additionally: the CI grep step must be present and demonstrated failing on a deliberate
violation, and `runtime_prop_instantiation` must be registered in
`docs/registry/architecture.yaml`.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`PropBody`); `gravity-authority` story 007 (the registry);
  `level-outcomes` epic for `restart_level()` / `reload_current_scene()`
- **Unlocks**: None — this is the last correctness story in the epic. Story 006 is a
  measurement and a decision, and does not depend on this one
