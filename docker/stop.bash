#!/usr/bin/env bash

set -euxo pipefail

if [[ ! -f run/cleanup.bash ]]; then
	exit
fi

set +e
source /dev/stdin <<<$(tac run/cleanup.bash)
