#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-click installer for the Flask CI/CD Demo
#
# Supports: macOS (Homebrew) and Ubuntu/Debian (apt)
#
# Usage:
#   chmod +x setup.sh && ./setup.sh
#   ./setup.sh --no-minikube       # skip Minikube install
#   ./setup.sh --run               # install AND start the app immediately
# =============================================================================

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BOLD}${BLUE}==============================${NC}"; \
                echo -e "${BOLD}${BLUE}  $*${NC}"; \
                echo -e "${BOLD}${BLUE}==============================${NC}\n"; }

# ── Flags ─────────────────────────────────────────────────────────────────────
INSTALL_MINIKUBE=true
RUN_APP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-minikube) INSTALL_MINIKUBE=false; shift ;;
    --run)         RUN_APP=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--no-minikube] [--run]"
      exit 0 ;;
    *) log_error "Unknown flag: $1"; exit 1 ;;
  esac
done

# ── Detect OS ─────────────────────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/redhat-release ]]; then
    echo "redhat"
  else
    echo "unknown"
  fi
}
OS=$(detect_os)
log_info "Detected OS: $OS"

# ── Helper: install a package if missing ──────────────────────────────────────
ensure_installed() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    log_info "$cmd already installed ($(command -v "$cmd"))"
    return
  fi
  log_info "Installing $pkg..."
  case "$OS" in
    macos)  brew install "$pkg" ;;
    debian) sudo apt-get install -y "$pkg" ;;
    *)      log_warn "Cannot auto-install $pkg on $OS. Please install it manually." ;;
  esac
}

# ── 1. Homebrew (macOS only) ──────────────────────────────────────────────────
log_section "Step 1 — Package Manager"
if [[ "$OS" == "macos" ]] && ! command -v brew &>/dev/null; then
  log_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ── 2. Docker ─────────────────────────────────────────────────────────────────
log_section "Step 2 — Docker"
if ! command -v docker &>/dev/null; then
  case "$OS" in
    macos)
      log_info "Installing Docker Desktop via Homebrew..."
      brew install --cask docker
      log_warn "Please open Docker Desktop from Applications and wait until it is running, then re-run this script."
      exit 0
      ;;
    debian)
      log_info "Installing Docker Engine..."
      sudo apt-get update -y
      sudo apt-get install -y ca-certificates curl gnupg lsb-release
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -y
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo usermod -aG docker "$USER"
      log_warn "Log out and back in for the docker group change to take effect."
      ;;
    *)
      log_error "Please install Docker manually: https://docs.docker.com/engine/install/"
      exit 1 ;;
  esac
else
  log_info "Docker already installed: $(docker --version)"
fi

# ── 3. Docker Compose ─────────────────────────────────────────────────────────
log_section "Step 3 — Docker Compose"
if docker compose version &>/dev/null 2>&1; then
  log_info "docker compose (plugin): $(docker compose version)"
elif command -v docker-compose &>/dev/null; then
  log_info "docker-compose (standalone): $(docker-compose --version)"
else
  case "$OS" in
    macos)  log_info "Docker Desktop includes Compose — no action needed." ;;
    debian)
      sudo apt-get install -y docker-compose-plugin 2>/dev/null || \
      sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
        -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
      ;;
  esac
fi

# ── 4. Python 3 ───────────────────────────────────────────────────────────────
log_section "Step 4 — Python 3"
if ! command -v python3 &>/dev/null; then
  case "$OS" in
    macos)  brew install python ;;
    debian) sudo apt-get install -y python3 python3-pip ;;
  esac
else
  log_info "Python already installed: $(python3 --version)"
fi

# ── 5. Minikube & kubectl (optional) ─────────────────────────────────────────
if $INSTALL_MINIKUBE; then
  log_section "Step 5 — Minikube & kubectl"
  if ! command -v minikube &>/dev/null; then
    case "$OS" in
      macos)  brew install minikube ;;
      debian)
        curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        ;;
    esac
  else
    log_info "Minikube already installed: $(minikube version --short)"
  fi

  if ! command -v kubectl &>/dev/null; then
    case "$OS" in
      macos)  brew install kubectl ;;
      debian)
        KUBECTL_VER=$(curl -Ls https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl"
        sudo install kubectl /usr/local/bin/kubectl && rm kubectl
        ;;
    esac
  else
    log_info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
  fi
fi

# ── 6. Python dependencies ────────────────────────────────────────────────────
log_section "Step 6 — Python Dependencies"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
  log_info "Installing from requirements.txt..."
  pip3 install --quiet --upgrade pip
  pip3 install --quiet -r "$SCRIPT_DIR/requirements.txt"
  log_info "Python dependencies installed."
else
  log_warn "requirements.txt not found — skipping pip install."
fi

# ── 7. .env file ─────────────────────────────────────────────────────────────
log_section "Step 7 — Environment Config"
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
  log_warn ".env created from .env.example"
  log_warn "Please edit .env and set your DOCKER_USERNAME before pushing images."
else
  log_info ".env already exists."
fi

# ── 8. Run the app (optional) ─────────────────────────────────────────────────
if $RUN_APP; then
  log_section "Step 8 — Starting App"
  cd "$SCRIPT_DIR"
  docker compose up -d app
  log_info "App is running at http://localhost:5000"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
log_section "Setup Complete"
echo -e "  ${GREEN}Next steps:${NC}"
echo ""
echo -e "  1. Edit ${YELLOW}.env${NC} and set your DOCKER_USERNAME"
echo -e "  2. Run the app:          ${YELLOW}make up${NC}          (or  docker compose up -d app)"
echo -e "  3. Run tests:            ${YELLOW}make test${NC}"
echo -e "  4. Build Docker image:   ${YELLOW}make build DOCKER_USERNAME=you${NC}"
echo -e "  5. Deploy to Minikube:   ${YELLOW}make deploy-minikube DOCKER_USERNAME=you${NC}"
echo ""
echo -e "  Full command reference:  ${YELLOW}make help${NC}"
echo ""
