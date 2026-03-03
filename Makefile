# =============================================================================
# Makefile — one-click commands for the Flask CI/CD Demo project
# Usage:  make <target>
#         DOCKER_USERNAME=yourname make build push
# =============================================================================

DOCKER_USERNAME ?= changeme
IMAGE_NAME      := flask-cicd-app
IMAGE_TAG       ?= latest
FULL_IMAGE      := $(DOCKER_USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: help install test lint build run stop push deploy-minikube clean logs \
        setup-minikube

# ── Default: print help ───────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Flask CI/CD Demo — available targets"
	@echo ""
	@echo "  Setup"
	@echo "    make install          Install Python dependencies locally"
	@echo ""
	@echo "  Development"
	@echo "    make test             Run unit tests with coverage"
	@echo "    make lint             Lint source code with flake8"
	@echo "    make run              Start app locally (Python)"
	@echo "    make dev              Start app with Docker (hot-reload)"
	@echo ""
	@echo "  Docker"
	@echo "    make build            Build production Docker image"
	@echo "    make build-dev        Build development Docker image"
	@echo "    make push             Push image to Docker Hub"
	@echo "    make up               Start with docker compose"
	@echo "    make down             Stop docker compose stack"
	@echo "    make logs             Tail container logs"
	@echo ""
	@echo "  Kubernetes"
	@echo "    make setup-minikube   Start Minikube cluster"
	@echo "    make deploy-minikube  Deploy app to Minikube"
	@echo "    make k8s-status       Show pod / service status"
	@echo "    make k8s-delete       Remove app from Minikube"
	@echo ""
	@echo "  Misc"
	@echo "    make clean            Remove containers, images, and caches"
	@echo ""

# ── Install ───────────────────────────────────────────────────────────────────
install:
	pip install --upgrade pip
	pip install -r requirements.txt
	pip install flake8 black

# ── Tests & Linting ───────────────────────────────────────────────────────────
test:
	pytest tests/ -v --cov=src --cov-report=term-missing

lint:
	flake8 src/ --count --max-line-length=120 --statistics

# ── Local run (no Docker) ─────────────────────────────────────────────────────
run:
	FLASK_DEBUG=false python src/app.py

dev:
	docker compose --profile development up dev

# ── Docker ────────────────────────────────────────────────────────────────────
build:
	docker build --target production -t $(FULL_IMAGE) .

build-dev:
	docker build -f Dockerfile.dev -t $(IMAGE_NAME):dev .

push:
	docker push $(FULL_IMAGE)

up:
	docker compose up -d app

down:
	docker compose down --remove-orphans

logs:
	docker compose logs -f app

# ── Kubernetes / Minikube ─────────────────────────────────────────────────────
setup-minikube:
	minikube start --driver=docker --cpus=2 --memory=2048

deploy-minikube:
	@if [ "$(DOCKER_USERNAME)" = "changeme" ]; then \
	  echo ""; \
	  echo "  ERROR: set your Docker Hub username first:"; \
	  echo "    make deploy-minikube DOCKER_USERNAME=your-username"; \
	  echo ""; \
	  exit 1; \
	fi
	sed -i.bak "s|YOUR_DOCKERHUB_USERNAME|$(DOCKER_USERNAME)|g" k8s/deployment.yaml
	kubectl apply -f k8s/
	kubectl rollout status deployment/flask-cicd-app
	minikube service flask-cicd-service --url

k8s-status:
	@echo "\n-- Pods --"
	kubectl get pods -l app=flask-cicd-app
	@echo "\n-- Services --"
	kubectl get svc flask-cicd-service

k8s-delete:
	kubectl delete -f k8s/ --ignore-not-found

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	docker compose down --rmi local --volumes --remove-orphans 2>/dev/null || true
	docker image rm -f $(FULL_IMAGE) $(IMAGE_NAME):dev 2>/dev/null || true
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	rm -f coverage.xml .coverage 2>/dev/null || true
