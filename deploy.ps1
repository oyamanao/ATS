<#
.SYNOPSIS
    Single-Click Deployment Script for ATS (Cheat-Proof Indoor Attendance System)
.DESCRIPTION
    Initializes environment configuration, builds and launches the complete Docker Compose stack,
    verifies database and backend health checks, and displays active endpoints.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Cheat-Proof Indoor Attendance System (ATS) Deployer    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check/Initialize Environment File
$rootDir = $PSScriptRoot
$envFile = Join-Path $rootDir ".env"
$envExample = Join-Path $rootDir ".env.example"

if (-not (Test-Path $envFile)) {
    Write-Host "[+] Creating .env from .env.example..." -ForegroundColor Yellow
    Copy-Item -Path $envExample -Destination $envFile
    Write-Host "[OK] .env initialized with default local parameters." -ForegroundColor Green
} else {
    Write-Host "[OK] Existing .env detected." -ForegroundColor Green
}

# 2. Verify Docker Engine
Write-Host "[+] Verifying Docker daemon..." -ForegroundColor Yellow
try {
    $null = docker info 2>&1
    Write-Host "[OK] Docker daemon is running." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running. Please start Docker Desktop and rerun." -ForegroundColor Red
    exit 1
}

# 3. Build & Launch Docker Compose Stack
Write-Host "[+] Building and launching ATS Docker Compose stack..." -ForegroundColor Yellow
Set-Location -Path $rootDir
docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker compose failed to start services." -ForegroundColor Red
    exit 1
}

# 4. Wait for Services & Health Check
Write-Host "[+] Waiting for services to become healthy..." -ForegroundColor Yellow
$maxRetries = 30
$retry = 0
$isHealthy = $false

while ($retry -lt $maxRetries -and -not $isHealthy) {
    Start-Sleep -Seconds 2
    $retry++
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3000/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.status -eq "ok") {
            $isHealthy = $true
        }
    } catch {
        # Retry until available
    }
    Write-Host -NoNewline "."
}

Write-Host ""

if ($isHealthy) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  ATS FULL STACK DEPLOYED SUCCESSFULLY!                  " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Teacher Projector Screen:  http://localhost:3000/teacher/display?classId=CS101" -ForegroundColor Cyan
    Write-Host "  Backend API Server:        http://localhost:3000" -ForegroundColor Cyan
    Write-Host "  Supabase Unified Gateway:  http://localhost:8000" -ForegroundColor Cyan
    Write-Host "  GoTrue Auth Endpoint:      http://localhost:8000/auth/v1" -ForegroundColor Cyan
    Write-Host "  PostgREST Database API:    http://localhost:8000/rest/v1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Check container logs anytime with: docker compose logs -f" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "[WARNING] Backend health probe timed out. Inspecting container logs:" -ForegroundColor Yellow
    docker compose ps
    docker compose logs --tail=20
}
