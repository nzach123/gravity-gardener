# CI-1 — Live-Fire Verification of the Four ADR Guards

> **Date**: 2026-08-25
> **Sprint**: 2 (row CI-1) — closes Sprint 1 rows **CLR-005** and **TUN-006**
> **Repository**: `nzach123/gravity-gardener` (public)
> **Scratch branch**: `ci-1-live-fire`, cut from `vertical-slice` at `037de8a`
> **Pull request**: #1, `ci-1-live-fire` → `development`, opened to fire the
>   workflow only. **Never merged.**
> **Workflow**: `.github/workflows/tests.yml`

## What this proves

Before today, `.github/workflows/tests.yml` **had never executed once**. Four
ADR guard steps and a gdUnit4 test step were committed, reviewed and recorded as
satisfied on the strength of local greps alone. This document records the first
four executions of that workflow, including one in which every guard was made to
fail on purpose.

## Why a scratch branch was not enough

The workflow triggers on `push` to `development`/`main` and on `pull_request`
targeting them. **Pushing a scratch branch on its own does not fire it.** This
repository has no `main` branch at all — not local, not remote; `origin/HEAD`
resolves to `origin/development`. There is no `gh` CLI on the development
machine, so opening the pull request was a browser action by the developer.

Once PR #1 existed, every subsequent push to `ci-1-live-fire` re-fired the
workflow automatically as a `synchronize` event. That is what made four runs
practical.

## The runs

| Run | Tree | Conclusion | What it established |
|---|---|---|---|
| [#1](https://github.com/nzach123/gravity-gardener/actions/runs/32890797221) | clean | **Failure** | Guards and tests both ran; the job died at the reporting step. Not a guard failure. |
| [#2](https://github.com/nzach123/gravity-gardener/actions/runs/32891245226) | clean, permissions fixed | **Success** | First passing run in the workflow's history. The baseline. |
| [#3](https://github.com/nzach123/gravity-gardener/actions/runs/32891882277) | five violations planted | **Failure** | **All four guards fired in one run**, each naming its ADR clause. |
| [#4](https://github.com/nzach123/gravity-gardener/actions/runs/32892127469) | reverted | **Success** | Clean again; tree byte-identical to run #2. |

Run #4's tree was confirmed identical to run #2's by `git diff 037de8a HEAD`,
which returned empty.

## Two workflow defects found and fixed before the live fire

Both were found by running the thing, and neither was visible to local greps.

### 1. The first failure hid every later one, and skipped the tests

GitHub Actions aborts a job at the first failing step. With the guards ordered
D4.6 → V6 → V7 → V8 → GdUnit4, a single D4.6 violation would fail the job and
**the other three guards and the entire test suite would never run**. Five
violations would have needed five separate runs.

CLR-005 AC-4 was already ticked and reads: *"The step runs before or alongside
the existing GdUnit4 test step, so a violation is caught in the same CI run as
everything else."* That was not true of the workflow as written.

Fixed in `afcff1b`: each guard carries an `id` and `continue-on-error: true`, and
a final **ADR guard gate** step reads the four `outcome` values and sets the
job's exit code. Every guard and the test suite now run on every push, and one
run reports all four.

### 2. The reporter could not publish results

Run #1 failed with:

```
HttpError: Resource not accessible by integration
https://docs.github.com/rest/checks/runs#create-a-check-run
```

`MikeSchulze/gdUnit4-action@v1` runs `dorny/test-reporter` internally, which
creates a check run. `GITHUB_TOKEN` cannot do that without `checks: write`.
Every guard and every test had passed; only the reporting step failed.

Fixed in `037de8a` with an explicit top-level `permissions:` block granting
`contents: read` and `checks: write`. This cannot work for a pull request from a
**fork**, where `GITHUB_TOKEN` is read-only regardless. Same-repo PRs and pushes,
which is all this project uses, are fine.

A suggested alternative — adding `fail-on-error: false` — was rejected twice
over: there is no `dorny/test-reporter` step in this workflow to add it to, and
it would have hidden the failure rather than fixing it, leaving test results
still absent from the PR.

## The planted violations and what caught them

All five were planted in one commit, `d5f1caa`, and reverted in `4d16a26`.

| # | Violation | Location | Guard that caught it | Message printed |
|---|---|---|---|---|
| 1 | `set_collision_mask_value(5, true)` | `src/scripts/player.gd` | ADR-0004 D4.6 | "collision layers/masks are authored data and must not be mutated at runtime" |
| 2 | `res://src/resources/tuning/prop_tuning.tres` literal | `src/scripts/player.gd` | ADR-0006 D6.3 (V6) | "a tuning resource path literal is permitted only in src/scripts/tuning/" |
| 3 | `Tuning.PROP.prop_gravity_scale = 1.5` | `src/scripts/player.gd` | ADR-0006 D6.5 (V7) | "a tuning resource must not be assigned to or duplicated at runtime" |
| 4 | `Tuning.PROP.duplicate()` | `src/scripts/player.gd` | ADR-0006 D6.5 (V7) | as above — same step, same run |
| 5 | a `gravity_tuning.gd` file | `src/scripts/tuning/` | ADR-0006 D6.7 (V8) | "no GravityTuning script or resource. ADR-0001 part 7 keeps the jump constants on Player" |

Run #3 produced eight annotations: one per guard naming its ADR clause, plus
four from the gate step reporting each outcome by name.

V8 fired on **both** of its halves — the content grep matched the token in the
file's doc comment, and `find src -iname '*gravity*tuning*'` matched the file
name. The second half is the load-bearing one, since a `gravity_tuning.tres`
can exist with no occurrence of the token inside it.

### How the probe was kept from contaminating the result

So that a red *guard* could never be mistaken for a red *suite*:

- The violations sat in a function, `_ci_live_fire_probe()`, that **is never
  called**. Nothing mutated a collision mask or a tuning resource at runtime.
- `_dup` was typed `Resource`, not `PropTuning`. `duplicate()` returns
  `Resource`, and the narrower type is a static type error — a parse failure
  that would have broken gdUnit4 discovery wholesale.
- Both locals were underscore-prefixed, so GDScript raised no unused-variable
  warning. gdUnit4 treats warnings as errors at discovery.
- The V8 file declared **no `class_name`**, so it tripped the CI guard without
  also tripping the local suite's `test_no_gravity_tuning_class_is_registered`,
  which is a different guard testing a different thing.

The local suite was run with the violations in place and returned
**178/178, 0 failures, exit 0**, confirming the isolation held.

## Finding: V7's assignment arm cannot be violated by compiling code

This is the substantive discovery of the exercise, and it was invisible to every
local grep run before today.

The first attempt to plant violation #3 as executable code failed to compile:

```
Parse Error: Cannot assign a new value to a constant.
	at res://src/scripts/player.gd:209
```

`Tuning.PROP` is declared `const PROP: PropTuning = preload(...)`, and GDScript
4.7.1 statically rejects assigning to a property reached through it. All three of
`WATERING`, `OXYGEN` and `PROP` are `const`. **The literal shape V7's assignment
arm greps for therefore cannot exist in a codebase that compiles.**

Measured behaviour, verified rather than assumed:

| Form | Compiles? | V7 grep matches? |
|---|---|---|
| `Tuning.PROP.prop_gravity_scale = 1.5` | **No** — parse error | Yes |
| `# Tuning.PROP.prop_gravity_scale = 1.5` | Yes | Yes |
| `Tuning.PROP.duplicate()` | Yes | Yes |
| `_alias.prop_gravity_scale = 1.5`, after `var _alias: PropTuning = Tuning.PROP` | Yes | **No** |

Two consequences:

1. **The assignment arm is a text tripwire, not a behavioural guard.** It can
   only ever fire on a comment or a string literal. That is exactly the standing
   already recorded for **V1**, which "has never been seen red and cannot be"
   because the wrong-script route fails statically before any test runs. Violation
   #3 was therefore planted as a comment — a form the guards deliberately do not
   exclude, per the D4.6 step's own note that a commented token is "a deliberate,
   cheap false positive".
2. **The route that can actually mutate a tuning resource is the one V7 misses.**
   ADR-0006 already admits the alias gap in a comment on the V7 step. What is new
   is that the arm's *executable* target is impossible, so the alias is not one
   gap among several — it is the only reachable one.

**Recommendation: flag, do not amend.** ADR-0006 is Accepted and its V7 step
already documents itself as partial and enforced "by review and grep, not by
structure". Nothing here contradicts the ADR; it sharpens a limitation the ADR
already states. Reopening an Accepted ADR to record a narrower version of its own
caveat is not worth the churn. This document is the record.

## Open items this run surfaced — none blocking

1. **`.github/` does not exist on `development`.** The workflow lives only on
   feature branches. For a same-repo pull request GitHub runs the workflow from
   the *head* branch, which is why these four runs happened at all — but the
   guards will never run on a push to `development` until this reaches it. The
   guards are proven; their reach is not.
2. **The CI test step has no `-c` equivalent.** The local runner takes `-c` to
   continue past the first failing test; without it a red run under-reports.
   `MikeSchulze/gdUnit4-action@v1` is configured with no such option here, so a
   red CI suite may report only its first failure. Not in CLR-005's or TUN-006's
   acceptance criteria. Tech-debt item.
3. **Node.js 20 deprecation warning.** `actions/checkout@v4` and
   `actions/upload-artifact@v4` are being forced onto Node 24. A warning, not a
   failure. Tech-debt item.

## Cleanup

- PR #1 is to be **closed unmerged**; branch `ci-1-live-fire` deleted.
- Commits `afcff1b` (guard gate) and `037de8a` (permissions) are real fixes and
  live on `vertical-slice`. They are **not** probe artifacts and must be kept.
- Commits `d5f1caa` (violations) and `4d16a26` (revert) exist only on
  `ci-1-live-fire` and must never reach `vertical-slice` or `development`.
