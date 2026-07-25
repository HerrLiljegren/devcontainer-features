#!/bin/bash
set -e

source dev-container-features-test-lib

check "bootstrap repairs remapped state ownership" bash -c \
    'sudo chown -R root:root /workbench-state &&
     /usr/local/bin/workbench-on-create &&
     test -w /workbench-state'

reportResults
