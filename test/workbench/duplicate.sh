#!/bin/bash
set -e

source dev-container-features-test-lib

check "user bootstrap is idempotent" /usr/local/bin/workbench-on-create

reportResults
