## CI-1 LIVE-FIRE PROBE - DELIBERATE ADR-0006 D6.7 (V8) VIOLATION.
##
## This file MUST NOT EXIST. It is created only so the V8 guard has a file
## name to catch, and it is deleted in the very next commit.
##
## No class_name on purpose: the D6.7 ban is on the FILE, and registering a
## GravityTuning class would also trip the local suite's
## test_no_gravity_tuning_class_is_registered, which is a different guard.
extends Resource
