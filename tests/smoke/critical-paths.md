# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing
4. Player can move left and right with smooth acceleration/friction
5. Player can jump (coyote time and jump buffering behave as expected)

## Core Mechanic (Gravity Gardener)

6. Entering a gravity zone flips gravity and rotates the player correctly
7. Vertical gravity flip (orange floor lever) toggles up/down gravity
8. Player walks on walls/ceilings in a flipped chamber without falling
9. Watering a plant (while carrying a bucket) fills its progress meter
10. A fully watered plant unlocks its corresponding goal/door
11. Moving platforms carry the player correctly in any gravity orientation

## Hazards & Fail State

12. Touching a spike hazard kills the player (regardless of gravity orientation)
13. Player death restarts the level and resets watering/bucket state

## Data Integrity

14. Restarting a level clears watering progress, bucket carry and goal-unlock state
    (asserts the observable behaviour, not the mechanism: LS-006 replaces
    reset-in-place with reconstruction and deletes GameManager.reset_level_state)
15. Level transitions preserve the correct plant/watered state per level

## Performance

16. No visible frame rate drops on target hardware (60fps target)
17. No memory growth over 5 minutes of play
