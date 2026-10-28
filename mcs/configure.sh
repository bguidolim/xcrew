#!/bin/sh
# mcs's configureProject step. `xcrew setup` reads the MCS_RESOLVED_* prompt answers itself.
exec "$(dirname "$0")/../bin/xcrew" setup
