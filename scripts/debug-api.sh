#!/bin/bash
#
# debug-api.sh — Enable/disable remote debugging for the API pod on EKS
#
# HOW IT WORKS:
#
# "enable" mode:
#   1. Scales the deployment to 1 replica (consistent debug target)
#   2. Patches the container command to: node --inspect=0.0.0.0:9229 dist/index.js
#      - --inspect enables V8's debug server (Chrome DevTools Protocol over WebSocket)
#      - 0.0.0.0 binds to all interfaces so kubectl port-forward can reach it
#      - Port 9229 is the conventional Node.js debug port
#   3. Waits for the new pod to be ready
#   4. Starts kubectl port-forward on port 9229
#      - This creates a tunnel: localhost:9229 -> pod:9229
#      - VS Code connects to localhost:9229 and speaks CDP to the V8 inspector
#
# "disable" mode:
#   1. Removes the command override (pod goes back to normal CMD from Dockerfile)
#   2. Scales back to 2 replicas
#   3. Kills any running port-forward
#
# USAGE:
#   ./scripts/debug-api.sh enable    # Start debug session
#   ./scripts/debug-api.sh disable   # End debug session
#

NAMESPACE="industrynight"
DEPLOYMENT="industrynight-api"
CONTAINER="api"

case "$1" in
  enable)
    echo "=== Enabling debug mode ==="

    # Step 1: Scale to 1 replica for consistent debugging
    echo "[1/4] Scaling to 1 replica..."
    kubectl scale deployment/$DEPLOYMENT -n $NAMESPACE --replicas=1

    # Step 2: Patch the container command to enable --inspect
    # This overrides the Dockerfile CMD with our debug command.
    # The JSON patch targets the first container in the pod spec.
    echo "[2/4] Patching deployment with --inspect flag..."
    kubectl patch deployment/$DEPLOYMENT -n $NAMESPACE --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/command",
        "value": ["node", "--inspect=0.0.0.0:9229", "dist/index.js"]
      }
    ]'

    # Step 3: Wait for the new pod to roll out
    # The patch triggers a rolling update — k8s creates a new pod with the
    # patched command and terminates the old one.
    echo "[3/4] Waiting for rollout..."
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=60s

    # Step 4: Port-forward the debug port
    # Get the pod name (there's only 1 replica now)
    POD=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o jsonpath='{.items[0].metadata.name}')
    echo "[4/4] Port-forwarding 9229 from pod/$POD..."
    echo ""
    echo "=== Debug session ready ==="
    echo "Pod:  $POD"
    echo "Port: localhost:9229"
    echo ""
    echo "In VS Code: Run 'Attach to EKS' debug configuration"
    echo "Press Ctrl+C to stop port-forwarding (debug stays enabled until you run 'disable')"
    echo ""
    kubectl port-forward pod/$POD 9229:9229 -n $NAMESPACE
    ;;

  disable)
    echo "=== Disabling debug mode ==="

    # Kill any existing port-forward for 9229
    pkill -f "port-forward.*9229" 2>/dev/null && echo "Stopped port-forward" || echo "No port-forward running"

    # Remove the command override by setting it to null
    # This reverts to the Dockerfile's CMD ["node", "dist/index.js"]
    echo "Removing --inspect patch..."
    kubectl patch deployment/$DEPLOYMENT -n $NAMESPACE --type='json' -p='[
      {
        "op": "remove",
        "path": "/spec/template/spec/containers/0/command"
      }
    ]'

    # Scale back to 2 replicas
    echo "Scaling back to 2 replicas..."
    kubectl scale deployment/$DEPLOYMENT -n $NAMESPACE --replicas=2

    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=60s
    echo ""
    echo "=== Debug mode disabled, normal operation restored ==="
    ;;

  *)
    echo "Usage: $0 {enable|disable}"
    echo ""
    echo "  enable   - Scale to 1 replica, add --inspect, port-forward 9229"
    echo "  disable  - Remove --inspect, scale back to 2 replicas"
    exit 1
    ;;
esac
