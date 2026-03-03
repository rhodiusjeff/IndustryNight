#!/bin/bash
#
# maintenance.sh — Toggle API maintenance mode via ALB fixed-response
#
# HOW IT WORKS:
#
# "on" mode:
#   1. Patches the ingress with an ALB "actions" annotation
#   2. The ALB returns a fixed 503 JSON response to ALL requests
#   3. No traffic reaches the pods — the ALB handles it at the edge
#   4. Mobile apps receive: {"status":"maintenance","message":"..."}
#
# "off" mode:
#   1. Removes the actions annotation
#   2. ALB resumes normal routing to pods
#
# This is separate from db-reset.js so you can use it independently
# (e.g., during deploys, infrastructure changes, etc.)
#
# USAGE:
#   ./scripts/maintenance.sh [--env dev|prod] on     # Enable maintenance mode
#   ./scripts/maintenance.sh [--env dev|prod] off    # Disable maintenance mode
#   ./scripts/maintenance.sh [--env dev|prod] status # Check current state
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

INGRESS="$K8S_DEPLOYMENT"

case "${1:-}" in
  on)
    echo "=== Enabling maintenance mode ($ENV_NAME) ==="

    # The ALB ingress controller supports a "fixed-response" action.
    # When this annotation is present, the ALB returns the specified
    # response directly — no backend pods are contacted.
    kube_cmd annotate ingress/$INGRESS -n $K8S_NAMESPACE --overwrite \
      "alb.ingress.kubernetes.io/actions.fixed-response"='{"type":"fixed-response","fixedResponseConfig":{"contentType":"application/json","statusCode":"503","messageBody":"{\"status\":\"maintenance\",\"message\":\"Industry Night is undergoing scheduled maintenance. Please try again shortly.\"}"}}'

    # Swap the backend to use the fixed-response action
    # We do this by patching the ingress path's backend to use the action
    kube_cmd patch ingress/$INGRESS -n $K8S_NAMESPACE --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/rules/0/http/paths/0/backend",
        "value": {
          "service": {
            "name": "fixed-response",
            "port": {
              "name": "use-annotation"
            }
          }
        }
      }
    ]'

    echo ""
    echo "=== Maintenance mode ENABLED ($ENV_NAME) ==="
    echo "All requests will receive 503 with maintenance message."
    echo "Run './scripts/maintenance.sh --env $ENV_NAME off' to restore normal traffic."
    ;;

  off)
    echo "=== Disabling maintenance mode ($ENV_NAME) ==="

    # Restore the original backend service
    kube_cmd patch ingress/$INGRESS -n $K8S_NAMESPACE --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/rules/0/http/paths/0/backend",
        "value": {
          "service": {
            "name": "industrynight-api",
            "port": {
              "number": 80
            }
          }
        }
      }
    ]'

    # Remove the fixed-response annotation
    kube_cmd annotate ingress/$INGRESS -n $K8S_NAMESPACE \
      "alb.ingress.kubernetes.io/actions.fixed-response"-

    echo ""
    echo "=== Maintenance mode DISABLED ($ENV_NAME) ==="
    echo "Traffic is flowing to API pods normally."
    ;;

  status)
    ANNOTATION=$(kube_cmd get ingress/$INGRESS -n $K8S_NAMESPACE -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.fixed-response}' 2>/dev/null)
    if [ -n "$ANNOTATION" ]; then
      echo "Maintenance mode ($ENV_NAME): ON"
      echo "Response: $ANNOTATION"
    else
      echo "Maintenance mode ($ENV_NAME): OFF"
    fi
    ;;

  *)
    echo "Usage: $0 [--env dev|prod] {on|off|status}"
    echo ""
    echo "  on      - Return 503 maintenance JSON to all requests"
    echo "  off     - Resume normal API traffic"
    echo "  status  - Check if maintenance mode is active"
    exit 1
    ;;
esac
