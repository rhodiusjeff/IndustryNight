#!/bin/bash
#
# pf-db.sh — Manage kubectl port-forward tunnel to RDS via the db-proxy pod
#
# WHY THIS EXISTS:
#   Database admin scripts (db-reset.js, db-scrub-user.js, seed-admin.js) each
#   manage their own port-forward internally. But for ad-hoc work — running psql,
#   resetting admin credentials, inspecting data — you need a persistent tunnel
#   without running a full script.
#
#   This script starts, stops, and checks that tunnel.
#
# HOW IT WORKS:
#   The db-proxy pod runs socat, forwarding TCP to the RDS endpoint on port 5432.
#   kubectl port-forward creates a local tunnel: localhost:5432 → pod:5432 → RDS.
#
# USAGE:
#   ./scripts/pf-db.sh start    # Open tunnel (runs in background)
#   ./scripts/pf-db.sh stop     # Close tunnel
#   ./scripts/pf-db.sh status   # Is the tunnel open?
#

NAMESPACE="industrynight"
AWS_PROFILE="industrynight-admin"
LOCAL_PORT=5432
PID_FILE="/tmp/industrynight-pf-db.pid"

case "$1" in
  start)
    # Kill anything already occupying the port
    lsof -ti :$LOCAL_PORT 2>/dev/null | xargs kill 2>/dev/null || true
    sleep 1

    echo "Starting port-forward: localhost:$LOCAL_PORT → db-proxy → RDS..."
    AWS_PROFILE=$AWS_PROFILE kubectl port-forward pod/db-proxy $LOCAL_PORT:5432 \
      -n $NAMESPACE &>/dev/null &
    PF_PID=$!
    echo $PF_PID > "$PID_FILE"

    # Wait for port to become reachable (up to 15s)
    attempts=0
    while ! nc -z localhost $LOCAL_PORT 2>/dev/null; do
      sleep 1
      attempts=$((attempts + 1))
      if [[ $attempts -ge 15 ]]; then
        echo "Error: tunnel did not become ready after 15s"
        echo "Check that the EKS cluster is running and db-proxy pod exists:"
        echo "  AWS_PROFILE=$AWS_PROFILE kubectl get pod/db-proxy -n $NAMESPACE"
        kill $PF_PID 2>/dev/null
        rm -f "$PID_FILE"
        exit 1
      fi
    done

    echo "Tunnel ready (PID $PF_PID)"
    echo ""
    echo "  localhost:$LOCAL_PORT → RDS"
    echo ""
    echo "Run './scripts/pf-db.sh stop' when done."
    ;;

  stop)
    if [[ -f "$PID_FILE" ]]; then
      PF_PID=$(cat "$PID_FILE")
      kill "$PF_PID" 2>/dev/null \
        && echo "Stopped port-forward (PID $PF_PID)" \
        || echo "Process $PF_PID already gone"
      rm -f "$PID_FILE"
    fi
    # Also catch any strays
    pkill -f "port-forward.*db-proxy" 2>/dev/null || true
    lsof -ti :$LOCAL_PORT 2>/dev/null | xargs kill 2>/dev/null || true
    echo "Port $LOCAL_PORT is free."
    ;;

  status)
    if nc -z localhost $LOCAL_PORT 2>/dev/null; then
      if [[ -f "$PID_FILE" ]]; then
        PF_PID=$(cat "$PID_FILE")
        echo "OPEN  localhost:$LOCAL_PORT → RDS  (PID $PF_PID)"
      else
        echo "OPEN  localhost:$LOCAL_PORT → RDS  (PID unknown — started externally)"
      fi
    else
      echo "CLOSED  (nothing listening on localhost:$LOCAL_PORT)"
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|status}"
    echo ""
    echo "  start    Open tunnel: localhost:$LOCAL_PORT → db-proxy → RDS"
    echo "  stop     Close tunnel and free port $LOCAL_PORT"
    echo "  status   Check whether the tunnel is open"
    exit 1
    ;;
esac
