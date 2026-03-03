#!/bin/bash
set -euo pipefail

# coop.sh — COOP Controller
#
# Continuity of Operations Plan for Industry Night
#
# Commands:
#   teardown   Export data, then tear down EKS + RDS (keeps S3, ECR, R53, ACM, Secrets)
#   rebuild    Recreate EKS + RDS, run migrations, optionally import data
#   status     Show status of all AWS resources
#   export     Export database to local backups/
#   import     Import database from a backup directory
#
# Usage:
#   ./scripts/coop/coop.sh teardown [--yes]
#   ./scripts/coop/coop.sh rebuild [--import backups/YYYY-MM-DD_HHMMSS] [--yes]
#   ./scripts/coop/coop.sh status
#   ./scripts/coop/coop.sh export [--yes]
#   ./scripts/coop/coop.sh import <backup-dir> [--full|--tables] [--run-migrations] [--yes]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

print_banner() {
  echo -e "${BOLD}"
  echo "============================================"
  echo "  Industry Night COOP System"
  echo "  Continuity of Operations Plan"
  echo "============================================"
  echo -e "${NC}"
}

print_usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  teardown              Export data, then tear down EKS cluster + RDS database"
  echo "  rebuild               Recreate EKS + RDS infrastructure and deploy API"
  echo "  status                Show status of all AWS resources"
  echo "  export                Export database to backups/"
  echo "  import <dir>          Import database from backup directory"
  echo ""
  echo "Options:"
  echo "  --yes                 Skip confirmation prompts"
  echo "  --import <dir>        (rebuild) Import data from backup after rebuild"
  echo "  --full                (import) Use pg_restore from full dump (default)"
  echo "  --tables              (import) Use per-table INSERT scripts"
  echo "  --run-migrations      (import) Run migrations before importing"
  echo "  --skip-rds-snapshot   (teardown) Skip creating RDS final snapshot"
  echo ""
  echo "Examples:"
  echo "  $0 teardown"
  echo "  $0 teardown --yes"
  echo "  $0 rebuild"
  echo "  $0 rebuild --import backups/2026-02-25_143000"
  echo "  $0 status"
  echo "  $0 export"
  echo "  $0 import backups/2026-02-25_143000 --full"
  echo "  $0 import backups/2026-02-25_143000 --tables --run-migrations"
}

COMMAND="${1:-}"

case "$COMMAND" in
  teardown)
    print_banner
    shift

    # Separate export args from teardown args
    EXPORT_ARGS=()
    TEARDOWN_ARGS=()
    for arg in "$@"; do
      case $arg in
        --yes) EXPORT_ARGS+=("$arg"); TEARDOWN_ARGS+=("$arg") ;;
        --skip-rds-snapshot) TEARDOWN_ARGS+=("$arg") ;;
        *) TEARDOWN_ARGS+=("$arg") ;;
      esac
    done

    # Run export first, then teardown
    "$SCRIPT_DIR/db-export.sh" "${EXPORT_ARGS[@]+"${EXPORT_ARGS[@]}"}"
    echo ""
    "$SCRIPT_DIR/infra-teardown.sh" "${TEARDOWN_ARGS[@]+"${TEARDOWN_ARGS[@]}"}"

    echo ""
    log_success "COOP teardown complete."
    log_info "Preserved: S3, ECR, Route 53, ACM, Secrets Manager."
    log_info "Estimated monthly cost: ~\$2-5"
    ;;

  rebuild)
    print_banner
    shift

    # Parse --import flag separately, pass rest through
    IMPORT_DIR=""
    PASSTHROUGH_ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --import)
          IMPORT_DIR="$2"
          shift 2
          ;;
        *)
          PASSTHROUGH_ARGS+=("$1")
          shift
          ;;
      esac
    done

    "$SCRIPT_DIR/infra-rebuild.sh" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"

    if [[ -n "$IMPORT_DIR" ]]; then
      echo ""
      "$SCRIPT_DIR/db-import.sh" "$IMPORT_DIR" --full "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
    fi

    echo ""
    log_success "COOP rebuild complete."
    ;;

  status)
    print_banner
    "$SCRIPT_DIR/infra-status.sh"
    ;;

  export)
    print_banner
    shift
    "$SCRIPT_DIR/db-export.sh" "$@"
    ;;

  import)
    print_banner
    shift
    if [[ $# -lt 1 ]]; then
      log_error "Import requires a backup directory path."
      echo ""
      echo "Usage: $0 import <backup-dir> [--full|--tables] [--run-migrations] [--yes]"
      echo ""
      # List available backups
      if [[ -d "$PROJECT_ROOT/$BACKUPS_DIR" ]]; then
        echo "Available backups:"
        for dir in "$PROJECT_ROOT/$BACKUPS_DIR"/*/; do
          [[ -d "$dir" ]] || continue
          DIRNAME=$(basename "$dir")
          if [[ -f "$dir/metadata.json" ]]; then
            TS=$(python3 -c "import json; m=json.load(open('$dir/metadata.json')); print(m.get('timestamp',''))" 2>/dev/null || echo "")
            echo "  $BACKUPS_DIR/$DIRNAME  ($TS)"
          else
            echo "  $BACKUPS_DIR/$DIRNAME"
          fi
        done
      fi
      exit 1
    fi
    "$SCRIPT_DIR/db-import.sh" "$@"
    ;;

  help|--help|-h)
    print_banner
    print_usage
    ;;

  *)
    print_banner
    if [[ -n "$COMMAND" ]]; then
      log_error "Unknown command: $COMMAND"
      echo ""
    fi
    print_usage
    exit 1
    ;;
esac
