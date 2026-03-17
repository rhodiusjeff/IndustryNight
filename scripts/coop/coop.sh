#!/bin/bash
set -euo pipefail

# coop.sh — COOP Controller
#
# Continuity of Operations Plan for Industry Night
#
# Commands:
#   teardown   Export data, then tear down EKS + RDS (keeps S3, ECR, R53, ACM, Secrets)
#   rebuild    Recreate EKS + RDS, run migrations, optionally import data
#   upgrade    In-place sequential EKS Kubernetes version upgrade (no teardown)
#   status     Show status of all AWS resources
#   export     Export database to local backups/
#   import     Import database from a backup directory
#
# Usage:
#   ./scripts/coop/coop.sh [--env dev|prod] teardown [--yes]
#   ./scripts/coop/coop.sh [--env dev|prod] rebuild [--import backups/...] [--yes]
#   ./scripts/coop/coop.sh [--env dev|prod] upgrade [--dry-run] [--yes]
#   ./scripts/coop/coop.sh [--env dev|prod] status
#   ./scripts/coop/coop.sh [--env dev|prod] export [--yes]
#   ./scripts/coop/coop.sh [--env dev|prod] import <backup-dir> [--full|--tables] [--yes]
#
# Default environment: dev (use --env prod for production)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Parse --env flag from all args
parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

print_banner() {
  local env_color
  if [[ "$ENV_NAME" == "prod" ]]; then
    env_color=$RED
  else
    env_color=$CYAN
  fi
  echo -e "${BOLD}"
  echo "============================================"
  echo "  Industry Night COOP System"
  ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
  echo -e "  Environment: ${env_color}${ENV_UPPER}${NC}${BOLD} ($ENV_LABEL)"
  echo "============================================"
  echo -e "${NC}"
}

print_usage() {
  echo "Usage: $0 [--env dev|prod] <command> [options]"
  echo ""
  echo "Commands:"
  echo "  teardown              Export data, then tear down EKS cluster + RDS database"
  echo "  rebuild               Recreate EKS + RDS infrastructure and deploy API"
  echo "  upgrade               In-place sequential EKS Kubernetes version upgrade (no teardown)"
  echo "  status                Show status of all AWS resources"
  echo "  export                Export database to backups/"
  echo "  import <dir>          Import database from backup directory"
  echo ""
  echo "Options:"
  echo "  --env dev|prod        Target environment (default: dev)"
  echo "  --yes                 Skip confirmation prompts"
  echo "  --import <dir>        (rebuild) Import data from backup after rebuild"
  echo "  --full                (import) Use pg_restore from full dump (default)"
  echo "  --tables              (import) Use per-table INSERT scripts"
  echo "  --run-migrations      (import) Run migrations before importing"
  echo "  --skip-rds-snapshot   (teardown) Skip creating RDS final snapshot"
  echo "  --dry-run             (upgrade) Show what would be done without making changes"
  echo ""
  echo "Examples:"
  echo "  $0 teardown                                    # Teardown dev (default)"
  echo "  $0 --env prod teardown --yes                   # Teardown production"
  echo "  $0 rebuild                                     # Rebuild dev (creates cluster at K8s 1.35)"
  echo "  $0 rebuild --import backups/dev/2026-03-01_120000"
  echo "  $0 upgrade                                     # Upgrade dev cluster in-place to K8s 1.35"
  echo "  $0 --env prod upgrade --dry-run                # Preview prod upgrade path"
  echo "  $0 status                                      # Dev status"
  echo "  $0 --env prod status                           # Production status"
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
    "$SCRIPT_DIR/db-export.sh" --env "$IN_ENV" "${EXPORT_ARGS[@]+"${EXPORT_ARGS[@]}"}"
    echo ""
    "$SCRIPT_DIR/infra-teardown.sh" --env "$IN_ENV" "${TEARDOWN_ARGS[@]+"${TEARDOWN_ARGS[@]}"}"

    echo ""
    log_success "COOP teardown complete ($ENV_NAME)."
    log_info "Preserved: S3, ECR, Route 53, ACM, Secrets Manager."
    log_info "Estimated monthly cost: ~\$2-5"
    ;;

  rebuild)
    print_banner
    shift

    # Parse --import flag separately, pass rest through
    IMPORT_DIR=""
    REBUILD_ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --import)
          IMPORT_DIR="$2"
          shift 2
          ;;
        *)
          REBUILD_ARGS+=("$1")
          shift
          ;;
      esac
    done

    "$SCRIPT_DIR/infra-rebuild.sh" --env "$IN_ENV" "${REBUILD_ARGS[@]+"${REBUILD_ARGS[@]}"}"

    if [[ -n "$IMPORT_DIR" ]]; then
      echo ""
      "$SCRIPT_DIR/db-import.sh" --env "$IN_ENV" "$IMPORT_DIR" --full "${REBUILD_ARGS[@]+"${REBUILD_ARGS[@]}"}"
    fi

    echo ""
    log_success "COOP rebuild complete ($ENV_NAME)."
    ;;

  status)
    print_banner
    "$SCRIPT_DIR/infra-status.sh" --env "$IN_ENV"
    ;;

  upgrade)
    print_banner
    shift
    "$SCRIPT_DIR/eks-upgrade.sh" --env "$IN_ENV" "$@"
    ;;

  export)
    print_banner
    shift
    "$SCRIPT_DIR/db-export.sh" --env "$IN_ENV" "$@"
    ;;

  import)
    print_banner
    shift
    if [[ $# -lt 1 ]]; then
      log_error "Import requires a backup directory path."
      echo ""
      echo "Usage: $0 [--env dev|prod] import <backup-dir> [--full|--tables] [--run-migrations] [--yes]"
      echo ""
      # List available backups for this environment
      if [[ -d "$BACKUPS_PATH" ]]; then
        echo "Available backups ($ENV_NAME):"
        for dir in "$BACKUPS_PATH"/*/; do
          [[ -d "$dir" ]] || continue
          DIRNAME=$(basename "$dir")
          if [[ -f "$dir/metadata.json" ]]; then
            TS=$(python3 -c "import json; m=json.load(open('$dir/metadata.json')); print(m.get('timestamp',''))" 2>/dev/null || echo "")
            echo "  $BACKUPS_DIR/$BACKUPS_SUBDIR/$DIRNAME  ($TS)"
          else
            echo "  $BACKUPS_DIR/$BACKUPS_SUBDIR/$DIRNAME"
          fi
        done
      fi
      exit 1
    fi
    "$SCRIPT_DIR/db-import.sh" --env "$IN_ENV" "$@"
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
