# Tech Debt Register

Advisory items accepted at story close. Each entry names the story it came from
so the debt can be traced back to the decision that accepted it.

## Open

- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): AC-9 evidence document not created. The inspector screenshot of
  `Direction Ease Rate` needs the windowed editor, which is unavailable in this
  environment. Expected at
  `production/qa/evidence/gravity-authority-autoload-evidence.md`. The export is
  already verified structurally by
  `tests/unit/gravity/gravity_authority_contract_test.gd::test_direction_ease_rate_is_an_exported_property_defaulting_to_32`,
  so this is confirmation rather than detection — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`
- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): `reset_to()` has no test for a non-positive multiplier and no test
  for a near-zero direction. Both cases reach the same `_accepts()` branch that
  `set_gravity()` already covers, so the guard is exercised but the second entry
  point is not. Add `test_reset_to_rejects_zero_and_negative_multipliers` and
  `test_reset_to_with_a_near_zero_direction_is_also_rejected` — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`
- **2026-08-24** (Story 001: Create the GravityAuthority scene autoload and its
  guards): the comment above `_accepts()` in
  `src/scripts/autoloads/gravity_authority.gd` (line 131) says the guard uses
  `push_error()`, but the direction and multiplier branches use
  `push_warning()`. The behaviour is correct and inside the control-manifest
  rule, which scopes `push_error()` to bind/initialize guards. The comment is
  what needs correcting, not the code — tracked from
  `production/epics/gravity-authority/story-001-gravity-authority-autoload-and-guards.md`

## Closed

*(none yet)*
