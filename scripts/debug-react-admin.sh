#!/bin/bash
# scripts/debug-react-admin.sh
# Same as run-react-admin.sh but with Node.js inspector enabled
# Usage: ./scripts/debug-react-admin.sh [--env dev|prod]

export NODE_OPTIONS='--inspect'
echo "Node.js inspector enabled — attach at chrome://inspect or use VS Code debugger"
"$(dirname "${BASH_SOURCE[0]}")/run-react-admin.sh" "$@"
