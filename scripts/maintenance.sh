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
#   ./scripts/maintenance.sh on     # Enable maintenance mode
#   ./scripts/maintenance.sh off    # Disable maintenance mode
#   ./scripts/maintenance.sh status # Check current state
#

NAMESPACE="industrynight"
INGRESS="industrynight-api"

case "$1" in
  on)
    echo "=== Enabling maintenance mode ==="

    # The ALB ingress controller supports a "fixed-response" action.
    # When this annotation is present, the ALB returns the specified
    # response directly — no backend pods are contacted.
    kubectl annotate ingress/$INGRESS -n $NAMESPACE --overwrite \
      "alb.ingress.kubernetes.io/actions.fixed-response"='{"type":"fixed-response","fixedResponseConfig":{"contentType":"application/json","statusCode":"503","messageBody":"{\"status\":\"maintenance\",\"message\":\"Industry Night is undergoing scheduled maintenance. Please try again shortly.\"}"}}'

    # Swap the backend to use the fixed-response action
    # We do this by patching the ingress path's backend to use the action
    kubectl patch ingress/$INGRESS -n $NAMESPACE --type='json' -p='[
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
    echo "=== Maintenance mode ENABLED ==="
    echo "All requests will receive 503 with maintenance message."
    echo "Run './scripts/maintenance.sh off' to restore normal traffic."
    ;;

  off)
    echo "=== Disabling maintenance mode ==="

    # Restore the original backend service
    kubectl patch ingress/$INGRESS -n $NAMESPACE --type='json' -p='[
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
    kubectl annotate ingress/$INGRESS -n $NAMESPACE \
      "alb.ingress.kubernetes.io/actions.fixed-response"-

    echo ""
    echo "=== Maintenance mode DISABLED ==="
    echo "Traffic is flowing to API pods normally."
    ;;

  status)
    ANNOTATION=$(kubectl get ingress/$INGRESS -n $NAMESPACE -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.fixed-response}' 2>/dev/null)
    if [ -n "$ANNOTATION" ]; then
      echo "Maintenance mode: ON"
      echo "Response: $ANNOTATION"
    else
      echo "Maintenance mode: OFF"
    fi
    ;;

  *)
    echo "Usage: $0 {on|off|status}"
    echo ""
    echo "  on      - Return 503 maintenance JSON to all requests"
    echo "  off     - Resume normal API traffic"
    echo "  status  - Check if maintenance mode is active"
    exit 1
    ;;
esac
