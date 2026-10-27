#!/usr/bin/env bash
# =============================================================================
# Single-Click Deployment Script for ATS (Cheat-Proof Indoor Attendance System)
# =============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================================${NC}"
echo -e "${CYAN}  Cheat-Proof Indoor Attendance System (ATS) Deployer    ${NC}"
echo -e "${CYAN}==========================================================${NC}\n"

# 1. Check/Initialize Environment File
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
    echo -e "${YELLOW}[+] Creating .env from .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}[OK] .env initialized with default local parameters.${NC}"
else
    echo -e "${GREEN}[OK] Existing .env detected.${NC}"
fi

# 2. Verify Docker Engine
echo -e "${YELLOW}[+] Verifying Docker daemon...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] Docker is not running. Please start Docker and rerun.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Docker daemon is running.${NC}"

# 3. Build & Launch Docker Compose Stack
echo -e "${YELLOW}[+] Building and launching ATS Docker Compose stack...${NC}"
docker compose up -d --build

# 4. Wait for Services & Health Check
echo -e "${YELLOW}[+] Waiting for backend service to become healthy...${NC}"
MAX_RETRIES=30
RETRY=0
IS_HEALTHY=false

while [ $RETRY -lt $MAX_RETRIES ] && [ "$IS_HEALTHY" = false ]; do
    sleep 2
    RETRY=$((RETRY + 1))
    if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
        IS_HEALTHY=true
    fi
    echo -n "."
done

echo ""

if [ "$IS_HEALTHY" = true ]; then
    echo -e "\n${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  ATS FULL STACK DEPLOYED SUCCESSFULLY!                  ${NC}"
    echo -e "${GREEN}==========================================================${NC}\n"
    echo -e "  Teacher Projector Screen:  ${CYAN}http://localhost:3000/teacher/display?classId=CS101${NC}"
    echo -e "  Backend API Server:        ${CYAN}http://localhost:3000${NC}"
    echo -e "  Supabase Unified Gateway:  ${CYAN}http://localhost:8000${NC}"
    echo -e "  GoTrue Auth Endpoint:      ${CYAN}http://localhost:8000/auth/v1${NC}"
    echo -e "  PostgREST Database API:    ${CYAN}http://localhost:8000/rest/v1${NC}\n"
    echo -e "Check container logs anytime with: docker compose logs -f\n"
else
    echo -e "${YELLOW}[WARNING] Backend health probe timed out. Current container status:${NC}"
    docker compose ps
    docker compose logs --tail=20
fi
