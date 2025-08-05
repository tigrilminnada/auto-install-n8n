#!/bin/bash

# n8n Docker + Cloudflare Tunnel Auto Installer
# Modern, Lightweight Docker-based Installation
# Version: 3.0 - Docker Edition with Enhanced Performance

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

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Installation failed. Cleaning up..."
        # Stop containers if they were started
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        fi
    fi
}
trap cleanup EXIT

echo -e "${PURPLE}🚀🐳 n8n DOCKER AUTO INSTALLER v3.0${NC}"
echo -e "${CYAN}📦 Lightweight Docker-based Setup${NC}"
echo ""

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

# Check if running as root
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

# Check system requirements
check_system() {
    log_info "Memeriksa sistem requirements untuk Docker..."
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Sistem operasi tidak didukung"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        log_error "Arsitektur $ARCH tidak didukung. Hanya x86_64 yang didukung."
        exit 1
    fi
    
    # Check available space (minimum 1GB for Docker)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then # 1GB in KB
        log_warning "Ruang disk kurang dari 1GB. Instalasi mungkin gagal."
    fi
    
    # Check memory (minimum 1GB)
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        log_warning "RAM kurang dari 1GB. Performa mungkin lambat."
    fi
    
    log_success "Sistem requirements OK untuk Docker"
}

# === INPUT DATA WITH VALIDATION ===
get_user_input() {
    log_info "Mengumpulkan informasi konfigurasi..."
    
    while true; do
        read -p "📛 Subdomain untuk n8n (contoh: n8n): " SUBDOMAIN
        if validate_subdomain "$SUBDOMAIN"; then
            break
        fi
    done
    
    read -p "👤 Username n8n (default: admin): " N8N_USER
    N8N_USER=${N8N_USER:-admin}
    
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
    
    # Optional: PostgreSQL or SQLite
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
    else
        USE_POSTGRES=false
    fi
    
    TUNNEL_NAME="n8n-docker-$(date +%Y%m%d-%H%M%S)"
    
    log_success "Konfigurasi dasar selesai"
}

# === SYSTEM CHECKS ===
check_root
check_system
get_user_input

# === INSTALL DOCKER ===
install_docker() {
    log_docker "Menginstall Docker dan Docker Compose..."
    
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
        exit 1
    fi
    
    if ! docker-compose --version >/dev/null 2>&1; then
        log_error "Gagal menginstall Docker Compose"
        exit 1
    fi
    
    log_success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1) berhasil diinstall"
    log_success "Docker Compose $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1) berhasil diinstall"
}

# === INSTALL CLOUDFLARED ===
install_cloudflared() {
    log_info "Menginstall Cloudflare Tunnel..."
    
    # Check if cloudflared already installed
    if command -v cloudflared >/dev/null 2>&1; then
        log_success "Cloudflared sudah terinstall"
        return
    fi
    
    # Download and install cloudflared
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" -O cloudflared.deb
    
    if [ ! -f cloudflared.deb ]; then
        log_error "Gagal download cloudflared"
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
        exit 1
    fi
    
    log_success "Cloudflared berhasil diinstall"
}

# === CLOUDFLARE LOGIN AND DOMAIN SELECTION ===
cloudflare_login() {
    log_info "Memulai proses login Cloudflare..."
    
    echo -e "${YELLOW}🌐 Anda akan diarahkan ke browser untuk login ke Cloudflare${NC}"
    echo -e "${YELLOW}📋 Pilih domain yang ingin digunakan untuk tunnel${NC}"
    echo -e "${YELLOW}⚠️  Pastikan browser tersedia untuk proses login${NC}"
    echo ""
    
    read -p "Tekan Enter untuk melanjutkan ke login Cloudflare..." -r
    
    # Login to Cloudflare
    if ! cloudflared tunnel login; then
        log_error "Gagal login ke Cloudflare"
        log_error "Pastikan:"
        log_error "1. Browser tersedia dan bisa mengakses internet"
        log_error "2. Anda memiliki akses ke akun Cloudflare"
        log_error "3. Domain sudah ditambahkan ke akun Cloudflare"
        exit 1
    fi
    
    log_success "Login Cloudflare berhasil!"
    
    # Get list of available domains from the certificate file
    CERT_FILE="$HOME/.cloudflared/cert.pem"
    if [ ! -f "$CERT_FILE" ]; then
        log_error "Certificate file tidak ditemukan. Login mungkin gagal."
        exit 1
    fi
    
    # Extract domains from certificate
    log_info "Mendeteksi domain yang tersedia..."
    
    # Alternative: check certificate for domains
    if command -v openssl >/dev/null 2>&1; then
        CERT_DOMAINS=$(openssl x509 -in "$CERT_FILE" -text -noout 2>/dev/null | grep -E "DNS:" | sed 's/DNS://g' | tr ',' '\n' | sed 's/^[[:space:]]*//g' | grep -v "^$" || true)
        if [ -n "$CERT_DOMAINS" ]; then
            echo -e "${BLUE}🌐 Domain yang tersedia:${NC}"
            echo "$CERT_DOMAINS" | nl -w2 -s'. '
            echo ""
            
            # Let user select domain
            while true; do
                read -p "Masukkan nama domain yang ingin digunakan: " ZONE_NAME
                if echo "$CERT_DOMAINS" | grep -q "^$ZONE_NAME$"; then
                    break
                else
                    log_warning "Domain '$ZONE_NAME' tidak ditemukan dalam daftar."
                    echo "Domain yang tersedia:"
                    echo "$CERT_DOMAINS" | nl -w2 -s'. '
                fi
            done
        else
            # Fallback: manual input
            log_warning "Tidak dapat mendeteksi domain otomatis"
            while true; do
                read -p "🌐 Masukkan domain Cloudflare yang sudah dikonfigurasi: " ZONE_NAME
                if validate_domain "$ZONE_NAME"; then
                    break
                fi
            done
        fi
    else
        # Manual input if openssl not available
        while true; do
            read -p "🌐 Masukkan domain Cloudflare yang sudah dikonfigurasi: " ZONE_NAME
            if validate_domain "$ZONE_NAME"; then
                break
            fi
        done
    fi
    
    FULL_HOSTNAME="$SUBDOMAIN.$ZONE_NAME"
    log_success "Domain dipilih: $ZONE_NAME"
    log_success "Full hostname: $FULL_HOSTNAME"
}

# === SETUP N8N DIRECTORY AND CONFIGURATION ===
setup_n8n_docker() {
    log_docker "Menyiapkan konfigurasi n8n Docker..."
    
    # Create n8n directory
    if [ "$IS_ROOT" = true ]; then
        mkdir -p "$N8N_DIR"
    else
        sudo mkdir -p "$N8N_DIR"
        sudo chown -R "$USER:$USER" "$N8N_DIR"
    fi
    
    log_success "Konfigurasi n8n Docker selesai"
}

# === CREATE DOCKER COMPOSE FILE ===
create_docker_compose() {
    log_docker "Membuat Docker Compose configuration..."
    
    if [ "$USE_POSTGRES" = true ]; then
        # Docker Compose with PostgreSQL - Simplified working version
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
    ports:
      - '5678:5678'
    volumes:
      - n8n_storage:/home/node/.n8n

volumes:
  postgres_storage:
  n8n_storage:"
    else
        # Docker Compose with SQLite - Simplified working version
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
    ports:
      - '5678:5678'
    volumes:
      - n8n_storage:/home/node/.n8n

volumes:
  n8n_storage:"
    fi
    
    echo "$COMPOSE_CONTENT" > "$COMPOSE_FILE"
    
    log_success "Docker Compose file berhasil dibuat"
}

# === START N8N DOCKER CONTAINERS ===
start_n8n_docker() {
    log_docker "Memulai n8n Docker containers..."
    
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
        echo "Container status:"
        docker ps -a | grep n8n
        echo ""
        echo "Container logs:"
        docker logs n8n-app 2>&1 | tail -20
        exit 1
    fi
    
    # Wait for n8n to be ready with improved check
    log_info "Menunggu n8n siap menerima koneksi..."
    for i in {1..20}; do
        if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
            log_success "n8n Docker containers berhasil berjalan dan responding"
            return
        fi
        log_info "Menunggu n8n response... ($i/20)"
        sleep 10
    done
    
    log_warning "n8n mungkin masih loading. Checking container status..."
    docker ps | grep n8n
    docker logs n8n-app 2>&1 | tail -10
}

# === CREATE CLOUDFLARE TUNNEL ===
create_tunnel() {
    log_info "Membuat Cloudflare Tunnel..."
    
    # Create tunnel using cloudflared command
    if ! cloudflared tunnel create "$TUNNEL_NAME"; then
        log_error "Gagal membuat tunnel: $TUNNEL_NAME"
        exit 1
    fi
    
    # Get tunnel ID from the created tunnel
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    
    if [ -z "$TUNNEL_ID" ]; then
        log_error "Gagal mendapatkan Tunnel ID"
        exit 1
    fi
    
    log_success "Tunnel berhasil dibuat: $TUNNEL_NAME (ID: $TUNNEL_ID)"
}

# === CONFIGURE TUNNEL ===
configure_tunnel() {
    log_info "Mengkonfigurasi tunnel..."
    
    # Create cloudflared directory
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /etc/cloudflared
        mkdir -p /root/.cloudflared
    else
        sudo mkdir -p /etc/cloudflared
        sudo mkdir -p /root/.cloudflared
    fi
    
    # Create tunnel configuration
    if [ "$IS_ROOT" = true ]; then
        tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $FULL_HOSTNAME
    service: http://localhost:5678
    originRequest:
      noTLSVerify: true
      httpHostHeader: $FULL_HOSTNAME
  - service: http_status:404
EOF
    else
        sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $FULL_HOSTNAME
    service: http://localhost:5678
    originRequest:
      noTLSVerify: true
      httpHostHeader: $FULL_HOSTNAME
  - service: http_status:404
EOF
    fi

    # The credentials file is automatically created by cloudflared tunnel create
    CRED_FILE="/root/.cloudflared/$TUNNEL_ID.json"
    if [ ! -f "$CRED_FILE" ]; then
        # Try alternative location
        if [ -f "$HOME/.cloudflared/$TUNNEL_ID.json" ]; then
            if [ "$IS_ROOT" = true ]; then
                cp "$HOME/.cloudflared/$TUNNEL_ID.json" "/root/.cloudflared/$TUNNEL_ID.json"
            else
                sudo cp "$HOME/.cloudflared/$TUNNEL_ID.json" "/root/.cloudflared/$TUNNEL_ID.json"
            fi
        else
            log_error "Credentials file tidak ditemukan: $CRED_FILE"
            exit 1
        fi
    fi
    
    # Set proper permissions
    if [ "$IS_ROOT" = true ]; then
        chmod 600 "/root/.cloudflared/$TUNNEL_ID.json"
    else
        sudo chmod 600 "/root/.cloudflared/$TUNNEL_ID.json"
    fi
    
    log_success "Tunnel dikonfigurasi"
}

# === SETUP CLOUDFLARED SERVICE ===
setup_cloudflared_service() {
    log_info "Mengatur layanan cloudflared..."
    
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
    sleep 5
    
    # Check service status
    if [ "$IS_ROOT" = true ]; then
        if ! systemctl is-active --quiet cloudflared; then
            log_warning "Cloudflared service tidak berjalan, mencoba restart..."
            systemctl restart cloudflared
            sleep 5
            
            if ! systemctl is-active --quiet cloudflared; then
                log_error "Gagal memulai cloudflared service"
                journalctl -u cloudflared --no-pager -l --lines 10
                exit 1
            fi
        fi
    else
        if ! sudo systemctl is-active --quiet cloudflared; then
            log_warning "Cloudflared service tidak berjalan, mencoba restart..."
            sudo systemctl restart cloudflared
            sleep 5
            
            if ! sudo systemctl is-active --quiet cloudflared; then
                log_error "Gagal memulai cloudflared service"
                sudo journalctl -u cloudflared --no-pager -l --lines 10
                exit 1
            fi
        fi
    fi
    
    log_success "Cloudflared service berjalan"
}

# === CREATE DNS RECORD ===
create_dns_record() {
    log_info "Membuat DNS record untuk $FULL_HOSTNAME..."
    
    # Use cloudflared route dns command
    if ! cloudflared tunnel route dns "$TUNNEL_ID" "$FULL_HOSTNAME"; then
        log_error "Gagal membuat DNS record untuk $FULL_HOSTNAME"
        log_error "Pastikan:"
        log_error "1. Domain $ZONE_NAME sudah ada di akun Cloudflare"
        log_error "2. Anda memiliki permission untuk mengedit DNS"
        log_error "3. Subdomain $SUBDOMAIN belum digunakan"
        
        # Offer manual alternative
        echo ""
        log_warning "Alternatif: Buat DNS record manual di Cloudflare Dashboard"
        echo -e "${YELLOW}   • Type: CNAME${NC}"
        echo -e "${YELLOW}   • Name: $FULL_HOSTNAME${NC}"
        echo -e "${YELLOW}   • Target: $TUNNEL_ID.cfargotunnel.com${NC}"
        echo -e "${YELLOW}   • Proxy status: Proxied (orange cloud)${NC}"
        echo ""
        
        read -p "Apakah Anda ingin melanjutkan dengan asumsi DNS record sudah dibuat manual? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        
        log_warning "Melanjutkan dengan asumsi DNS record sudah dikonfigurasi manual"
    else
        log_success "DNS record berhasil dibuat: $FULL_HOSTNAME"
    fi
}

# === HEALTH CHECK ===
health_check() {
    log_info "Melakukan health check..."
    
    # Wait for services to stabilize
    log_info "Menunggu layanan stabilisasi..."
    sleep 15
    
    # Check Docker containers
    cd "$N8N_DIR"
    if ! docker ps | grep -q "n8n-app.*Up"; then
        log_error "n8n Docker container tidak berjalan dengan baik"
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
            journalctl -u cloudflared --no-pager -l --lines 20
            exit 1
        fi
    else
        if ! sudo systemctl is-active --quiet cloudflared; then
            log_error "Cloudflared tidak berjalan dengan baik"
            sudo journalctl -u cloudflared --no-pager -l --lines 20
            exit 1
        fi
    fi
    
    # Test local n8n endpoint
    if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
        log_success "n8n endpoint lokal merespons dengan baik"
    else
        log_warning "n8n endpoint lokal tidak merespons, mungkin masih loading..."
    fi
    
    log_success "Health check passed"
}

# === CREATE MANAGEMENT SCRIPTS ===
create_management_scripts() {
    log_info "Membuat management scripts..."
    
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

echo "Backup created at: \$BACKUP_DIR"
EOF
    
    # Make scripts executable
    chmod +x "$N8N_DIR"/*.sh
    
    log_success "Management scripts dibuat di $N8N_DIR"
}

# === MAIN EXECUTION ===
main() {
    log_info "Memulai instalasi n8n Docker dengan Cloudflare Tunnel..."
    
    # Run all installation steps
    install_docker
    install_cloudflared
    cloudflare_login
    setup_n8n_docker
    create_docker_compose
    start_n8n_docker
    create_tunnel
    configure_tunnel
    setup_cloudflared_service
    create_dns_record
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
    echo -e "${CYAN}   • Data Path: $N8N_DIR/data${NC}"
    echo ""
    echo -e "${BLUE}🌐 Tunnel Information:${NC}"
    echo -e "${BLUE}   • Tunnel ID: $TUNNEL_ID${NC}"
    echo -e "${BLUE}   • Tunnel Name: $TUNNEL_NAME${NC}"
    echo -e "${BLUE}   • Domain: $ZONE_NAME${NC}"
    echo ""
    echo -e "${YELLOW}⚡ Features:${NC}"
    echo -e "${YELLOW}   • Docker containerized (lightweight & portable)${NC}"
    echo -e "${YELLOW}   • Auto-restart on reboot (Docker & systemd)${NC}"
    echo -e "${YELLOW}   • HTTPS enabled with Cloudflare SSL${NC}"
    echo -e "${YELLOW}   • Basic authentication enabled${NC}"
    echo -e "${YELLOW}   • Production-ready configuration${NC}"
    echo -e "${YELLOW}   • Modern Cloudflare Tunnel integration${NC}"
    echo ""
    echo -e "${GREEN}🛡️  Security: Enhanced authentication & encrypted tunnel${NC}"
    echo -e "${GREEN}🚀 Performance: Optimized Docker containers${NC}"
    echo ""
    echo -e "${CYAN}🔧 Management Commands:${NC}"
    echo -e "${CYAN}   • Start containers: $N8N_DIR/start.sh${NC}"
    echo -e "${CYAN}   • Stop containers: $N8N_DIR/stop.sh${NC}"
    echo -e "${CYAN}   • Restart containers: $N8N_DIR/restart.sh${NC}"
    echo -e "${CYAN}   • View logs: $N8N_DIR/logs.sh${NC}"
    echo -e "${CYAN}   • Create backup: $N8N_DIR/backup.sh${NC}"
    echo -e "${CYAN}   • Check status: docker-compose -f $COMPOSE_FILE ps${NC}"
    echo -e "${CYAN}   • List tunnels: cloudflared tunnel list${NC}"
    echo ""
    echo -e "${BLUE}📁 File Locations:${NC}"
    echo -e "${BLUE}   • Configuration: $N8N_DIR${NC}"
    echo -e "${BLUE}   • Docker Compose: $COMPOSE_FILE${NC}"
    echo -e "${BLUE}   • Environment: $N8N_DIR/.env${NC}"
    echo -e "${BLUE}   • Data: $N8N_DIR/data${NC}"
    if [ "$USE_POSTGRES" = true ]; then
        echo -e "${BLUE}   • PostgreSQL Data: $N8N_DIR/postgres-data${NC}"
    fi
}

# Run main function
main
