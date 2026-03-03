#!/usr/bin/env bash
# =============================================================================
# Local Deployment Script for Flask CI/CD Demo
# Usage:
#   ./scripts/deploy-local.sh                  # Deploy with Docker Compose
#   ./scripts/deploy-local.sh --minikube       # Deploy to Minikube
#   ./scripts/deploy-local.sh --pull <tag>     # Pull image from Docker Hub then deploy
# =============================================================================

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BOLD}${BLUE}=== $* ===${NC}\n"; }

# ── Defaults ───────────────────────────────────────────────────────────────────
DEPLOY_MINIKUBE=false
PULL_IMAGE=false
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Parse Arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minikube) DEPLOY_MINIKUBE=true; shift ;;
    --pull)     PULL_IMAGE=true; IMAGE_TAG="${2:-latest}"; shift 2 ;;
    --tag)      IMAGE_TAG="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--minikube] [--pull <tag>] [--tag <tag>]"
      exit 0 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Prereq Checks ─────────────────────────────────────────────────────────────
check_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "$1 is not installed. Please install it first."
    return 1
  fi
  log_info "$1 found: $(command -v "$1")"
}

log_section "Checking Prerequisites"
check_command docker
check_command docker compose 2>/dev/null || check_command "docker-compose"

if $DEPLOY_MINIKUBE; then
  check_command minikube
  check_command kubectl
fi

# ── Pull Image (optional) ──────────────────────────────────────────────────────
if $PULL_IMAGE; then
  if [[ -z "$DOCKER_USERNAME" ]]; then
    log_error "DOCKER_USERNAME env variable is required when using --pull"
    log_info  "  export DOCKER_USERNAME=your-dockerhub-username"
    exit 1
  fi
  log_section "Pulling Docker Image"
  docker pull "${DOCKER_USERNAME}/flask-cicd-app:${IMAGE_TAG}"
fi

# ── Docker Compose Deployment ─────────────────────────────────────────────────
if ! $DEPLOY_MINIKUBE; then
  log_section "Deploying with Docker Compose"
  cd "$PROJECT_DIR"

  # Tear down any existing stack first
  docker compose down --remove-orphans 2>/dev/null || true

  # Build fresh if we are NOT pulling a remote image
  if ! $PULL_IMAGE; then
    log_info "Building image from source..."
    docker compose build --no-cache
  fi

  # Start the app service
  docker compose up -d app

  log_info "Waiting for container to be healthy..."
  RETRIES=15
  until docker compose exec app python -c \
      "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" \
      &>/dev/null || [[ $RETRIES -eq 0 ]]; do
    RETRIES=$((RETRIES - 1))
    sleep 2
  done

  if [[ $RETRIES -eq 0 ]]; then
    log_error "Container did not become healthy in time."
    docker compose logs app
    exit 1
  fi

  log_info "Container is healthy."
  echo ""
  log_section "Deployment Successful"
  echo -e "  ${GREEN}App URL   :${NC}  http://localhost:5000"
  echo -e "  ${GREEN}Health    :${NC}  http://localhost:5000/health"
  echo -e "  ${GREEN}API Info  :${NC}  http://localhost:5000/api/info"
  echo ""
  log_info "To stop: docker compose down"
  exit 0
fi

# ── Minikube Deployment ───────────────────────────────────────────────────────
log_section "Deploying to Minikube"
cd "$PROJECT_DIR"

# Start Minikube if not running
if ! minikube status | grep -q "Running"; then
  log_info "Starting Minikube..."
  minikube start --driver=docker --cpus=2 --memory=2048
else
  log_info "Minikube is already running."
fi

# Patch the image name in deployment.yaml if DOCKER_USERNAME is set
K8S_DEPLOYMENT="$PROJECT_DIR/k8s/deployment.yaml"
if [[ -n "$DOCKER_USERNAME" ]]; then
  log_info "Patching image reference in deployment.yaml..."
  sed -i.bak \
    "s|YOUR_DOCKERHUB_USERNAME/flask-cicd-app:latest|${DOCKER_USERNAME}/flask-cicd-app:${IMAGE_TAG}|g" \
    "$K8S_DEPLOYMENT"
fi

log_info "Applying Kubernetes manifests..."
kubectl apply -f "$PROJECT_DIR/k8s/"

log_info "Waiting for rollout to complete..."
kubectl rollout status deployment/flask-cicd-app --timeout=120s

log_section "Deployment Successful"
SERVICE_URL=$(minikube service flask-cicd-service --url 2>/dev/null || echo "Run: minikube service flask-cicd-service --url")
echo -e "  ${GREEN}App URL  :${NC}  $SERVICE_URL"
echo ""
log_info "To open in browser: minikube service flask-cicd-service"
log_info "To view pods      : kubectl get pods -l app=flask-cicd-app"
log_info "To view logs      : kubectl logs -l app=flask-cicd-app -f"
