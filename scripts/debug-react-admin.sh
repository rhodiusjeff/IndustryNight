#!/bin/bash
set -euo pipefail

export NODE_OPTIONS='--inspect'
"$(dirname "${BASH_SOURCE[0]}")/run-react-admin.sh" "$@"
