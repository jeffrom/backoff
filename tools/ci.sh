#!/bin/bash
set -uxo pipefail

# script to run ci tasks

mix dogma
dogma_res=$?

mix credo --strict
credo_res=$?

mix test
test_res=$?

mix dialyzer --halt-exit-status
dialyzer_res=$?


if [[ $dogma_res != 0 || $credo_res != 0 || $test_res != 0 || $dialyzer_res != 0 ]]; then
    exit 1
fi
