#!/bin/bash

# n8n Docker + Cloudflare Tunnel Auto Installer with API Key
# Version: 4.0 - API Key Edition for Telegram Bot Integration
# Support for remote VPS installation via API

set -euo pipefail

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_docker() { echo -e "${CYAN}🐳 $1${NC}"; }

# Global variables
IS_ROOT=false
N8N_DIR="/opt/n8n"
COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
CF_CONFIG_DIR="/opt/cloudflare"
CF_CONFIG_FILE="$CF_CONFIG_DIR/config.yml"
INSTALL_LOG="/tmp/n8n_install.log"

# API Configuration
CF_API_TOKEN=""
CF_ZONE_ID=""
CF_ACCOUNT_ID=""
TUNNEL_TOKEN=""

# Installation parameters (can be passed as arguments)
VPS_IP=""
SUBDOMAIN=""
DOMAIN=""
N8N_USER="admin"
N8N_PASS=""
USE_POSTGRES=false
POSTGRES_PASS="n8n123"
TELEGRAM_MODE=false

# Function to write to install log
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Installation failed. Check log: $INSTALL_LOG"
        log_to_file "ERROR: Installation failed with exit code $?"
        # Stop containers if they were started
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        fi
    fi
}
trap cleanup EXIT

# === HELP FUNCTION ===
show_help() {
    cat << EOF
n8n Docker + Cloudflare Tunnel Auto Installer v4.0

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --cf-api-token TOKEN    Cloudflare API Token (required)
    --cf-zone-id ID         Cloudflare Zone ID (required) 
    --cf-account-id ID      Cloudflare Account ID (required)
    --subdomain NAME        Subdomain for n8n (required)
    --domain NAME           Domain name (required)
    --n8n-user USER         n8n username (default: admin)
    --n8n-pass PASS         n8n password (required)
    --postgres              Use PostgreSQL instead of SQLite
    --postgres-pass PASS    PostgreSQL password (default: n8n123)
    --telegram-mode         Enable Telegram bot mode (silent install)
    --help                  Show this help

TELEGRAM BOT MODE:
    All parameters must be provided via command line arguments.
    No interactive prompts will be shown.

EXAMPLES:
    # Interactive mode
    $0

    # Telegram bot mode
    $0 --telegram-mode --cf-api-token "your_token" --cf-zone-id "zone_id" \\
       --cf-account-id "account_id" --subdomain "n8n" --domain "example.com" \\
       --n8n-pass "secure123"

CLOUDFLARE API TOKEN REQUIREMENTS:
    Token must have these permissions:
    - Zone:Zone:Read
    - Zone:DNS:Edit
    - Account:Cloudflare Tunnel:Edit

EOF
}

# === PARSE ARGUMENTS ===
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cf-api-token)
                CF_API_TOKEN="$2"
                shift 2
                ;;
            --cf-zone-id)
                CF_ZONE_ID="$2"
                shift 2
                ;;
            --cf-account-id)
                CF_ACCOUNT_ID="$2"
                shift 2
                ;;
            --subdomain)
                SUBDOMAIN="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --n8n-user)
                N8N_USER="$2"
                shift 2
                ;;
            --n8n-pass)
                N8N_PASS="$2"
                shift 2
                ;;
            --postgres)
                USE_POSTGRES=true
                shift
                ;;
            --postgres-pass)
                POSTGRES_PASS="$2"
                shift 2
                ;;
            --telegram-mode)
                TELEGRAM_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# === VALIDATION FUNCTIONS ===
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Domain format tidak valid: $domain"
        return 1
    fi
}

validate_subdomain() {
    local subdomain="$1"
    if [[ ! "$subdomain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]]; then
        log_error "Subdomain format tidak valid: $subdomain"
        return 1
    fi
}

validate_password() {
    local password="$1"
    if [ ${#password} -lt 8 ]; then
        log_error "Password minimal 8 karakter"
        return 1
    fi
}

# === CLOUDFLARE API FUNCTIONS ===
test_cf_api_token() {
    log_info "Validating Cloudflare API Token..."
    log_to_file "Testing Cloudflare API Token"
    
    # Test API token by getting user info
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    
    if [ "$success" = "true" ]; then
        log_success "Cloudflare API Token valid"
        log_to_file "SUCCESS: API Token validation passed"
        return 0
    else
        log_error "Cloudflare API Token tidak valid atau expired"
        log_error "Response: $response"
        log_to_file "ERROR: API Token validation failed - $response"
        
        if [ "$TELEGRAM_MODE" = false ]; then
            echo ""
            log_warning "Cara membuat Cloudflare API Token:"
            echo "1. Login ke https://dash.cloudflare.com/profile/api-tokens"
            echo "2. Klik 'Create Token'"
            echo "3. Pilih 'Custom token'"
            echo "4. Permissions yang dibutuhkan:"
            echo "   - Zone:Zone:Read"
            echo "   - Zone:DNS:Edit"
            echo "   - Account:Cloudflare Tunnel:Edit"
            echo "5. Zone Resources: Include - All zones"
            echo "6. Account Resources: Include - All accounts"
            echo ""
        fi
        return 1
    fi
}

validate_zone_id() {
    log_info "Validating Zone ID untuk domain: $DOMAIN"
    log_to_file "Validating Zone ID: $CF_ZONE_ID for domain: $DOMAIN"
    
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    local zone_name=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$success" = "true" ] && [ "$zone_name" = "$DOMAIN" ]; then
        log_success "Zone ID valid untuk domain $DOMAIN"
        log_to_file "SUCCESS: Zone ID validation passed for $DOMAIN"
        return 0
    else
        log_error "Zone ID tidak valid atau tidak sesuai dengan domain $DOMAIN"
        log_error "Expected domain: $DOMAIN, Found: $zone_name"
        log_to_file "ERROR: Zone ID validation failed - Expected: $DOMAIN, Found: $zone_name"
        return 1
    fi
}

get_account_id() {
    log_info "Getting Account ID..."
    log_to_file "Retrieving Account ID"
    
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    
    if [ "$success" = "true" ]; then
        # Get first account ID
        CF_ACCOUNT_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CF_ACCOUNT_ID" ]; then
            log_success "Account ID retrieved: $CF_ACCOUNT_ID"
            log_to_file "SUCCESS: Account ID retrieved: $CF_ACCOUNT_ID"
            return 0
        fi
    fi
    
    log_error "Gagal mendapatkan Account ID"
    log_to_file "ERROR: Failed to get Account ID - $response"
    return 1
}

# === USER INPUT FUNCTIONS ===
get_interactive_input() {
    if [ "$TELEGRAM_MODE" = true ]; then
        return 0
    fi
    
    log_info "Mengumpulkan informasi konfigurasi..."
    
    # Cloudflare API Token
    if [ -z "$CF_API_TOKEN" ]; then
        echo ""
        log_warning "Cloudflare API Token diperlukan untuk instalasi otomatis"
        echo "Cara membuat token: https://dash.cloudflare.com/profile/api-tokens"
        echo ""
        while true; do
            read -s -p "🔑 Masukkan Cloudflare API Token: " CF_API_TOKEN
            echo
            if [ -n "$CF_API_TOKEN" ] && test_cf_api_token; then
                break
            fi
        done
    fi
    
    # Get Account ID if not provided
    if [ -z "$CF_ACCOUNT_ID" ]; then
        get_account_id
    fi
    
    # Domain
    if [ -z "$DOMAIN" ]; then
        while true; do
            read -p "🌐 Domain Cloudflare (contoh: example.com): " DOMAIN
            if validate_domain "$DOMAIN"; then
                break
            fi
        done
    fi
    
    # Zone ID
    if [ -z "$CF_ZONE_ID" ]; then
        log_info "Mencari Zone ID untuk domain $DOMAIN..."
        
        local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json")
        
        CF_ZONE_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -z "$CF_ZONE_ID" ]; then
            log_error "Tidak dapat menemukan Zone ID untuk domain $DOMAIN"
            log_error "Pastikan domain sudah ditambahkan ke akun Cloudflare"
            exit 1
        else
            log_success "Zone ID ditemukan: $CF_ZONE_ID"
        fi
    fi
    
    # Validate Zone ID
    if ! validate_zone_id; then
        exit 1
    fi
    
    # Subdomain
    if [ -z "$SUBDOMAIN" ]; then
        while true; do
            read -p "📛 Subdomain untuk n8n (contoh: n8n): " SUBDOMAIN
            if validate_subdomain "$SUBDOMAIN"; then
                break
            fi
        done
    fi
    
    # n8n credentials
    if [ -z "$N8N_USER" ]; then
        read -p "👤 Username n8n (default: admin): " N8N_USER
        N8N_USER=${N8N_USER:-admin}
    fi
    
    if [ -z "$N8N_PASS" ]; then
        while true; do
            read -s -p "🔑 Password n8n (min 8 karakter): " N8N_PASS
            echo
            if validate_password "$N8N_PASS"; then
                read -s -p "🔁 Konfirmasi password: " N8N_PASS2
                echo
                if [ "$N8N_PASS" = "$N8N_PASS2" ]; then
                    break
                else
                    log_error "Password tidak cocok. Coba lagi."
                fi
            fi
        done
    fi
    
    # Database choice
    if [ "$USE_POSTGRES" = false ]; then
        echo ""
        echo -e "${CYAN}🗄️  Database Options:${NC}"
        echo "1. SQLite (Ringan, single file)"
        echo "2. PostgreSQL (Robust, production-ready)"
        read -p "Pilih database (1-2, default: 1): " DB_CHOICE
        DB_CHOICE=${DB_CHOICE:-1}
        
        if [ "$DB_CHOICE" = "2" ]; then
            USE_POSTGRES=true
            read -p "📊 PostgreSQL password (default: n8n123): " POSTGRES_PASS
            POSTGRES_PASS=${POSTGRES_PASS:-n8n123}
        fi
    fi
    
    FULL_HOSTNAME="$SUBDOMAIN.$DOMAIN"
    log_success "Konfigurasi selesai untuk: $FULL_HOSTNAME"
}

validate_required_params() {
    local missing_params=()
    
    if [ -z "$CF_API_TOKEN" ]; then
        missing_params+=("--cf-api-token")
    fi
    
    if [ -z "$CF_ZONE_ID" ]; then
        missing_params+=("--cf-zone-id")
    fi
    
    if [ -z "$CF_ACCOUNT_ID" ]; then
        missing_params+=("--cf-account-id")
    fi
    
    if [ -z "$SUBDOMAIN" ]; then
        missing_params+=("--subdomain")
    fi
    
    if [ -z "$DOMAIN" ]; then
        missing_params+=("--domain")
    fi
    
    if [ -z "$N8N_PASS" ]; then
        missing_params+=("--n8n-pass")
    fi
    
    if [ ${#missing_params[@]} -gt 0 ]; then
        log_error "Parameter yang diperlukan hilang: ${missing_params[*]}"
        if [ "$TELEGRAM_MODE" = true ]; then
            log_error "Telegram mode memerlukan semua parameter"
        fi
        show_help
        exit 1
    fi
    
    # Validate parameters
    if ! validate_domain "$DOMAIN"; then
        exit 1
    fi
    
    if ! validate_subdomain "$SUBDOMAIN"; then
        exit 1
    fi
    
    if ! validate_password "$N8N_PASS"; then
        exit 1
    fi
    
    FULL_HOSTNAME="$SUBDOMAIN.$DOMAIN"
}

# === SYSTEM CHECKS ===
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root user. Sudo commands will be skipped."
        IS_ROOT=true
    else
        IS_ROOT=false
        # Check if user has sudo privileges
        if ! sudo -n true 2>/dev/null; then
            log_error "User tidak memiliki akses sudo. Jalankan: sudo usermod -aG sudo $USER"
            exit 1
        fi
    fi
}

check_system() {
    log_info "Memeriksa sistem requirements..."
    log_to_file "System requirements check started"
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Sistem operasi tidak didukung"
        log_to_file "ERROR: Unsupported OS"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        log_error "Arsitektur $ARCH tidak didukung. Hanya x86_64 yang didukung."
        log_to_file "ERROR: Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Check available space (minimum 2GB for Docker)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then # 2GB in KB
        log_warning "Ruang disk kurang dari 2GB. Instalasi mungkin gagal."
        log_to_file "WARNING: Low disk space: ${AVAILABLE_SPACE}KB"
    fi
    
    # Check memory (minimum 1GB)
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        log_warning "RAM kurang dari 1GB. Performa mungkin lambat."
        log_to_file "WARNING: Low memory: ${TOTAL_MEM}MB"
    fi
    
    log_success "Sistem requirements OK"
    log_to_file "SUCCESS: System requirements check passed"
}

# === INSTALL DOCKER ===
install_docker() {
    log_docker "Menginstall Docker dan Docker Compose..."
    log_to_file "Docker installation started"
    
    # Check if Docker already installed
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker sudah terinstall"
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            log_info "Memulai Docker service..."
            if [ "$IS_ROOT" = true ]; then
                systemctl start docker
                systemctl enable docker
            else
                sudo systemctl start docker
                sudo systemctl enable docker
            fi
        fi
    else
        # Install Docker
        log_info "Menginstall Docker..."
        
        # Update package list
        if [ "$IS_ROOT" = true ]; then
            apt update -qq
            apt install -y ca-certificates curl gnupg lsb-release
        else
            sudo apt update -qq
            sudo apt install -y ca-certificates curl gnupg lsb-release
        fi
        
        # Add Docker GPG key
        if [ "$IS_ROOT" = true ]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update -qq
            apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        else
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update -qq
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        fi
        
        # Start and enable Docker
        if [ "$IS_ROOT" = true ]; then
            systemctl start docker
            systemctl enable docker
        else
            sudo systemctl start docker
            sudo systemctl enable docker
            # Add user to docker group
            sudo usermod -aG docker "$USER"
            log_warning "User ditambahkan ke docker group. Mungkin perlu logout/login atau reboot."
        fi
    fi
    
    # Install docker-compose (standalone) if not available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_info "Menginstall Docker Compose..."
        if [ "$IS_ROOT" = true ]; then
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        else
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
    
    # Verify Docker installation
    if ! docker --version >/dev/null 2>&1; then
        log_error "Gagal menginstall Docker"
        log_to_file "ERROR: Docker installation failed"
        exit 1
    fi
    
    if ! docker-compose --version >/dev/null 2>&1; then
        log_error "Gagal menginstall Docker Compose"
        log_to_file "ERROR: Docker Compose installation failed"
        exit 1
    fi
    
    log_success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1) berhasil diinstall"
    log_success "Docker Compose $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1) berhasil diinstall"
    log_to_file "SUCCESS: Docker and Docker Compose installed"
}

# === INSTALL CLOUDFLARED ===
install_cloudflared() {
    log_info "Menginstall Cloudflare Tunnel..."
    log_to_file "Cloudflared installation started"
    
    # Check if cloudflared already installed
    if command -v cloudflared >/dev/null 2>&1; then
        log_success "Cloudflared sudah terinstall"
        log_to_file "SUCCESS: Cloudflared already installed"
        return
    fi
    
    # Download and install cloudflared
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" -O cloudflared.deb
    
    if [ ! -f cloudflared.deb ]; then
        log_error "Gagal download cloudflared"
        log_to_file "ERROR: Failed to download cloudflared"
        exit 1
    fi
    
    if [ "$IS_ROOT" = true ]; then
        dpkg -i cloudflared.deb
    else
        sudo dpkg -i cloudflared.deb
    fi
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if ! command -v cloudflared >/dev/null 2>&1; then
        log_error "Gagal menginstall cloudflared"
        log_to_file "ERROR: Cloudflared installation failed"
        exit 1
    fi
    
    log_success "Cloudflared berhasil diinstall"
    log_to_file "SUCCESS: Cloudflared installed"
}

# === SETUP N8N DIRECTORY ===
setup_n8n_docker() {
    log_docker "Menyiapkan konfigurasi n8n Docker..."
    log_to_file "Setting up n8n Docker configuration"
    
    # Create n8n directory
    if [ "$IS_ROOT" = true ]; then
        mkdir -p "$N8N_DIR"
        mkdir -p "$CF_CONFIG_DIR"
    else
        sudo mkdir -p "$N8N_DIR"
        sudo mkdir -p "$CF_CONFIG_DIR"
        sudo chown -R "$USER:$USER" "$N8N_DIR"
        sudo chown -R "$USER:$USER" "$CF_CONFIG_DIR"
    fi
    
    log_success "Konfigurasi n8n Docker selesai"
    log_to_file "SUCCESS: n8n Docker configuration completed"
}

# === CREATE DOCKER COMPOSE FILE ===
create_docker_compose() {
    log_docker "Membuat Docker Compose configuration..."
    log_to_file "Creating Docker Compose file"
    
    if [ "$USE_POSTGRES" = true ]; then
        # Docker Compose with PostgreSQL
        COMPOSE_CONTENT="version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: $POSTGRES_PASS
    volumes:
      - postgres_storage:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U n8n -d n8n']
      interval: 5s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-app
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n
      DB_POSTGRESDB_PASSWORD: $POSTGRES_PASS
      N8N_BASIC_AUTH_ACTIVE: 'true'
      N8N_BASIC_AUTH_USER: $N8N_USER
      N8N_BASIC_AUTH_PASSWORD: $N8N_PASS
      WEBHOOK_URL: https://$FULL_HOSTNAME/
      GENERIC_TIMEZONE: Asia/Jakarta
    ports:
      - '5678:5678'
    volumes:
      - n8n_storage:/home/node/.n8n

volumes:
  postgres_storage:
  n8n_storage:"
    else
        # Docker Compose with SQLite
        COMPOSE_CONTENT="version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-app
    restart: unless-stopped
    environment:
      N8N_BASIC_AUTH_ACTIVE: 'true'
      N8N_BASIC_AUTH_USER: $N8N_USER
      N8N_BASIC_AUTH_PASSWORD: $N8N_PASS
      WEBHOOK_URL: https://$FULL_HOSTNAME/
      GENERIC_TIMEZONE: Asia/Jakarta
    ports:
      - '5678:5678'
    volumes:
      - n8n_storage:/home/node/.n8n

volumes:
  n8n_storage:"
    fi
    
    echo "$COMPOSE_CONTENT" > "$COMPOSE_FILE"
    
    log_success "Docker Compose file berhasil dibuat"
    log_to_file "SUCCESS: Docker Compose file created"
}

# === START N8N DOCKER CONTAINERS ===
start_n8n_docker() {
    log_docker "Memulai n8n Docker containers..."
    log_to_file "Starting n8n Docker containers"
    
    cd "$N8N_DIR"
    
    # Pull latest images
    log_info "Downloading n8n Docker images..."
    docker-compose pull
    
    # Start containers
    log_info "Starting containers..."
    docker-compose up -d
    
    # Wait for containers to start
    log_info "Menunggu containers startup..."
    sleep 30
    
    # Check if containers are running
    if ! docker ps | grep -q "n8n-app"; then
        log_error "Gagal memulai n8n container"
        log_to_file "ERROR: Failed to start n8n container"
        echo "Container status:"
        docker ps -a | grep n8n
        echo ""
        echo "Container logs:"
        docker logs n8n-app 2>&1 | tail -20
        exit 1
    fi
    
    # Wait for n8n to be ready
    log_info "Menunggu n8n siap menerima koneksi..."
    for i in {1..20}; do
        if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
            log_success "n8n Docker containers berhasil berjalan"
            log_to_file "SUCCESS: n8n containers running and responding"
            return
        fi
        log_info "Menunggu n8n response... ($i/20)"
        sleep 10
    done
    
    log_warning "n8n mungkin masih loading. Checking container status..."
    docker ps | grep n8n
    docker logs n8n-app 2>&1 | tail -10
}

# === CREATE CLOUDFLARE TUNNEL WITH API ===
create_tunnel_with_api() {
    log_info "Membuat Cloudflare Tunnel dengan API..."
    log_to_file "Creating Cloudflare Tunnel with API"
    
    TUNNEL_NAME="n8n-api-$(date +%Y%m%d-%H%M%S)"
    TUNNEL_SECRET=$(openssl rand -base64 32)
    
    # Create tunnel via API
    local tunnel_data=$(cat <<EOF
{
  "name": "$TUNNEL_NAME",
  "tunnel_secret": "$TUNNEL_SECRET"
}
EOF
)
    
    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$tunnel_data")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    
    if [ "$success" = "true" ]; then
        TUNNEL_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        log_success "Tunnel berhasil dibuat: $TUNNEL_NAME (ID: $TUNNEL_ID)"
        log_to_file "SUCCESS: Tunnel created: $TUNNEL_NAME (ID: $TUNNEL_ID)"
    else
        log_error "Gagal membuat tunnel via API"
        log_error "Response: $response"
        log_to_file "ERROR: Failed to create tunnel via API - $response"
        exit 1
    fi
}

# === CONFIGURE TUNNEL WITH TOKEN ===
configure_tunnel_with_token() {
    log_info "Mengkonfigurasi tunnel dengan token..."
    log_to_file "Configuring tunnel with token"
    
    # Generate tunnel token for the tunnel
    local token_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$token_response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    
    if [ "$success" = "true" ]; then
        TUNNEL_TOKEN=$(echo "$token_response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        log_success "Tunnel token berhasil didapat"
        log_to_file "SUCCESS: Tunnel token retrieved"
    else
        log_error "Gagal mendapatkan tunnel token"
        log_error "Response: $token_response"
        log_to_file "ERROR: Failed to get tunnel token - $token_response"
        exit 1
    fi
    
    # Create cloudflared configuration
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /etc/cloudflared
        tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: $FULL_HOSTNAME
    service: http://localhost:5678
    originRequest:
      noTLSVerify: true
      httpHostHeader: $FULL_HOSTNAME
  - service: http_status:404
EOF
    else
        sudo mkdir -p /etc/cloudflared
        sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: $FULL_HOSTNAME
    service: http://localhost:5678
    originRequest:
      noTLSVerify: true
      httpHostHeader: $FULL_HOSTNAME
  - service: http_status:404
EOF
    fi
    
    # Create credentials file
    local credentials=$(cat <<EOF
{
  "AccountTag": "$CF_ACCOUNT_ID",
  "TunnelSecret": "$TUNNEL_SECRET",
  "TunnelID": "$TUNNEL_ID"
}
EOF
)
    
    if [ "$IS_ROOT" = true ]; then
        echo "$credentials" > /etc/cloudflared/credentials.json
        chmod 600 /etc/cloudflared/credentials.json
    else
        echo "$credentials" | sudo tee /etc/cloudflared/credentials.json > /dev/null
        sudo chmod 600 /etc/cloudflared/credentials.json
    fi
    
    log_success "Tunnel dikonfigurasi dengan credentials"
    log_to_file "SUCCESS: Tunnel configured with credentials"
}

# === SETUP CLOUDFLARED SERVICE ===
setup_cloudflared_service() {
    log_info "Mengatur layanan cloudflared..."
    log_to_file "Setting up cloudflared service"
    
    # Install and enable service
    if [ "$IS_ROOT" = true ]; then
        cloudflared service install
        systemctl enable cloudflared
        systemctl start cloudflared
    else
        sudo cloudflared service install
        sudo systemctl enable cloudflared
        sudo systemctl start cloudflared
    fi
    
    # Wait for service to start
    sleep 10
    
    # Check service status
    if [ "$IS_ROOT" = true ]; then
        if ! systemctl is-active --quiet cloudflared; then
            log_warning "Cloudflared service tidak berjalan, mencoba restart..."
            systemctl restart cloudflared
            sleep 10
            
            if ! systemctl is-active --quiet cloudflared; then
                log_error "Gagal memulai cloudflared service"
                journalctl -u cloudflared --no-pager -l --lines 20
                log_to_file "ERROR: Cloudflared service failed to start"
                exit 1
            fi
        fi
    else
        if ! sudo systemctl is-active --quiet cloudflared; then
            log_warning "Cloudflared service tidak berjalan, mencoba restart..."
            sudo systemctl restart cloudflared
            sleep 10
            
            if ! sudo systemctl is-active --quiet cloudflared; then
                log_error "Gagal memulai cloudflared service"
                sudo journalctl -u cloudflared --no-pager -l --lines 20
                log_to_file "ERROR: Cloudflared service failed to start"
                exit 1
            fi
        fi
    fi
    
    log_success "Cloudflared service berjalan"
    log_to_file "SUCCESS: Cloudflared service running"
}

# === CREATE DNS RECORD WITH API ===
create_dns_record_api() {
    log_info "Membuat DNS record untuk $FULL_HOSTNAME via API..."
    log_to_file "Creating DNS record for $FULL_HOSTNAME via API"
    
    # Create DNS record
    local dns_data=$(cat <<EOF
{
  "type": "CNAME",
  "name": "$SUBDOMAIN",
  "content": "$TUNNEL_ID.cfargotunnel.com",
  "ttl": 1,
  "proxied": true
}
EOF
)
    
    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$dns_data")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    
    if [ "$success" = "true" ]; then
        log_success "DNS record berhasil dibuat: $FULL_HOSTNAME"
        log_to_file "SUCCESS: DNS record created: $FULL_HOSTNAME"
    else
        local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        
        # Check if record already exists
        if echo "$response" | grep -q "already exists"; then
            log_warning "DNS record sudah ada untuk $FULL_HOSTNAME"
            log_to_file "WARNING: DNS record already exists for $FULL_HOSTNAME"
        else
            log_error "Gagal membuat DNS record: $error_msg"
            log_error "Response: $response"
            log_to_file "ERROR: Failed to create DNS record - $error_msg"
            exit 1
        fi
    fi
}

# === HEALTH CHECK ===
health_check() {
    log_info "Melakukan health check..."
    log_to_file "Performing health check"
    
    # Wait for services to stabilize
    log_info "Menunggu layanan stabilisasi..."
    sleep 20
    
    # Check Docker containers
    cd "$N8N_DIR"
    if ! docker ps | grep -q "n8n-app.*Up"; then
        log_error "n8n Docker container tidak berjalan dengan baik"
        log_to_file "ERROR: n8n Docker container not running properly"
        echo "Container status:"
        docker ps -a | grep n8n
        echo ""
        echo "Recent logs:"
        docker logs n8n-app 2>&1 | tail -20
        exit 1
    fi
    
    # Check cloudflared status
    if [ "$IS_ROOT" = true ]; then
        if ! systemctl is-active --quiet cloudflared; then
            log_error "Cloudflared tidak berjalan dengan baik"
            log_to_file "ERROR: Cloudflared not running properly"
            journalctl -u cloudflared --no-pager -l --lines 20
            exit 1
        fi
    else
        if ! sudo systemctl is-active --quiet cloudflared; then
            log_error "Cloudflared tidak berjalan dengan baik"
            log_to_file "ERROR: Cloudflared not running properly"
            sudo journalctl -u cloudflared --no-pager -l --lines 20
            exit 1
        fi
    fi
    
    # Test local n8n endpoint
    if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
        log_success "n8n endpoint lokal merespons dengan baik"
        log_to_file "SUCCESS: Local n8n endpoint responding"
    else
        log_warning "n8n endpoint lokal tidak merespons, mungkin masih loading..."
        log_to_file "WARNING: Local n8n endpoint not responding"
    fi
    
    log_success "Health check passed"
    log_to_file "SUCCESS: Health check completed"
}

# === CREATE MANAGEMENT SCRIPTS ===
create_management_scripts() {
    log_info "Membuat management scripts..."
    log_to_file "Creating management scripts"
    
    # Create start script
    cat > "$N8N_DIR/start.sh" <<EOF
#!/bin/bash
cd "$N8N_DIR"
docker-compose up -d
echo "n8n Docker containers started"
EOF
    
    # Create stop script
    cat > "$N8N_DIR/stop.sh" <<EOF
#!/bin/bash
cd "$N8N_DIR"
docker-compose down
echo "n8n Docker containers stopped"
EOF
    
    # Create restart script
    cat > "$N8N_DIR/restart.sh" <<EOF
#!/bin/bash
cd "$N8N_DIR"
docker-compose restart
echo "n8n Docker containers restarted"
EOF
    
    # Create logs script
    cat > "$N8N_DIR/logs.sh" <<EOF
#!/bin/bash
cd "$N8N_DIR"
docker-compose logs -f
EOF
    
    # Create status script
    cat > "$N8N_DIR/status.sh" <<EOF
#!/bin/bash
echo "=== Docker Containers ==="
docker ps | grep n8n

echo ""
echo "=== Cloudflared Service ==="
systemctl status cloudflared --no-pager -l

echo ""
echo "=== n8n Health Check ==="
curl -s -I http://localhost:5678 | head -1

echo ""
echo "=== Tunnel Status ==="
cloudflared tunnel list | grep "$TUNNEL_ID"
EOF
    
    # Create backup script
    cat > "$N8N_DIR/backup.sh" <<EOF
#!/bin/bash
BACKUP_DIR="/backup/n8n-\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$BACKUP_DIR"

# Backup Docker volumes
docker run --rm -v n8n_storage:/source -v "\$BACKUP_DIR":/backup alpine tar czf /backup/n8n_data.tar.gz -C /source .

if [ "$USE_POSTGRES" = true ]; then
    # Backup PostgreSQL
    docker exec n8n-postgres pg_dump -U n8n n8n > "\$BACKUP_DIR/postgres_backup.sql"
    docker run --rm -v postgres_storage:/source -v "\$BACKUP_DIR":/backup alpine tar czf /backup/postgres_data.tar.gz -C /source .
fi

# Backup configurations
cp -r /etc/cloudflared "\$BACKUP_DIR/cloudflared_config"
cp "$COMPOSE_FILE" "\$BACKUP_DIR/"

echo "Backup created at: \$BACKUP_DIR"
EOF
    
    # Make scripts executable
    chmod +x "$N8N_DIR"/*.sh
    
    log_success "Management scripts dibuat di $N8N_DIR"
    log_to_file "SUCCESS: Management scripts created"
}

# === MAIN EXECUTION ===
main() {
    echo -e "${PURPLE}🚀🐳 n8n DOCKER AUTO INSTALLER v4.0 - API Edition${NC}"
    echo -e "${CYAN}📦 Lightweight Docker-based Setup with Cloudflare API${NC}"
    echo ""
    
    log_to_file "=== n8n Installation Started ==="
    log_to_file "Version: 4.0 - API Edition"
    log_to_file "Mode: $([ "$TELEGRAM_MODE" = true ] && echo "Telegram Bot" || echo "Interactive")"
    
    if [ "$TELEGRAM_MODE" = true ]; then
        log_info "🤖 Running in Telegram Bot Mode"
        validate_required_params
        
        # Test API parameters
        if ! test_cf_api_token; then
            exit 1
        fi
        
        if ! validate_zone_id; then
            exit 1
        fi
    else
        log_info "👨‍💻 Running in Interactive Mode"
        get_interactive_input
    fi
    
    # System checks
    check_root
    check_system
    
    # Installation steps
    install_docker
    install_cloudflared
    setup_n8n_docker
    create_docker_compose
    start_n8n_docker
    create_tunnel_with_api
    configure_tunnel_with_token
    setup_cloudflared_service
    create_dns_record_api
    health_check
    create_management_scripts
    
    # Show final information
    echo ""
    echo -e "${PURPLE}🎉🐳 n8n DOCKER INSTALLATION COMPLETE! 🎉🐳${NC}"
    echo -e "${GREEN}🔗 Access URL: https://$FULL_HOSTNAME${NC}"
    echo -e "${GREEN}👤 Username: $N8N_USER${NC}"
    echo -e "${GREEN}🔑 Password: $N8N_PASS${NC}"
    echo ""
    echo -e "${CYAN}📦 Docker Information:${NC}"
    echo -e "${CYAN}   • Container: n8n-app${NC}"
    if [ "$USE_POSTGRES" = true ]; then
        echo -e "${CYAN}   • Database: PostgreSQL (n8n-postgres)${NC}"
    else
        echo -e "${CYAN}   • Database: SQLite${NC}"
    fi
    echo -e "${CYAN}   • Data Path: $N8N_DIR${NC}"
    echo ""
    echo -e "${BLUE}🌐 Tunnel Information:${NC}"
    echo -e "${BLUE}   • Tunnel ID: $TUNNEL_ID${NC}"
    echo -e "${BLUE}   • Tunnel Name: $TUNNEL_NAME${NC}"
    echo -e "${BLUE}   • Domain: $DOMAIN${NC}"
    echo -e "${BLUE}   • Full URL: https://$FULL_HOSTNAME${NC}"
    echo ""
    echo -e "${YELLOW}⚡ API Features:${NC}"
    echo -e "${YELLOW}   • Automated DNS management${NC}"
    echo -e "${YELLOW}   • Token-based authentication${NC}"
    echo -e "${YELLOW}   • Telegram bot integration ready${NC}"
    echo -e "${YELLOW}   • Remote VPS deployment capable${NC}"
    echo ""
    echo -e "${CYAN}🔧 Management Commands:${NC}"
    echo -e "${CYAN}   • Start: $N8N_DIR/start.sh${NC}"
    echo -e "${CYAN}   • Stop: $N8N_DIR/stop.sh${NC}"
    echo -e "${CYAN}   • Restart: $N8N_DIR/restart.sh${NC}"
    echo -e "${CYAN}   • Logs: $N8N_DIR/logs.sh${NC}"
    echo -e "${CYAN}   • Status: $N8N_DIR/status.sh${NC}"
    echo -e "${CYAN}   • Backup: $N8N_DIR/backup.sh${NC}"
    echo ""
    echo -e "${GREEN}📝 Installation Log: $INSTALL_LOG${NC}"
    
    log_to_file "=== Installation Completed Successfully ==="
    log_to_file "URL: https://$FULL_HOSTNAME"
    log_to_file "Username: $N8N_USER"
    log_to_file "Tunnel ID: $TUNNEL_ID"
    
    if [ "$TELEGRAM_MODE" = true ]; then
        # Output for telegram bot (structured format)
        echo "INSTALL_SUCCESS"
        echo "URL:https://$FULL_HOSTNAME"
        echo "USERNAME:$N8N_USER"
        echo "PASSWORD:$N8N_PASS"
        echo "TUNNEL_ID:$TUNNEL_ID"
        echo "DOMAIN:$DOMAIN"
    fi
}

# Parse arguments first
parse_arguments "$@"

# Run main function
main
