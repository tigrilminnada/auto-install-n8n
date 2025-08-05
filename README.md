# n8n Docker + Cloudflare Tunnel Auto Installer

Skrip instalasi otomatis untuk n8n menggunakan Docker dan Cloudflare Tunnel pada VPS Ubuntu/Debian. Tersedia 2 versi script untuk kebutuhan yang berbeda.

## 🔧 Dua Versi Script

### 📱 **install-api.sh** - Version 4.0 (API Mode)
**Untuk Telegram Bot & Remote Installation**
- ✅ Mode non-interaktif menggunakan Cloudflare API
- ✅ Parameter melalui command line
- ✅ Cocok untuk integrasi Telegram bot
- ✅ Instalasi remote tanpa browser
- ✅ Automasi penuh dengan API token

### 🖥️ **install.sh** - Version 3.0 (Interactive Mode)
**Untuk Setup Manual & Guided Installation**
- ✅ Mode interaktif dengan browser login
- ✅ Guided step-by-step installation
- ✅ Login manual ke Cloudflare via browser
- ✅ Cocok untuk first-time setup
- ✅ Pemilihan domain secara interaktif

## 📋 Fitur Umum

- ✅ Instalasi otomatis n8n dengan Docker
- ✅ Integrasi Cloudflare Tunnel untuk akses publik yang aman
- ✅ Dukungan database SQLite dan PostgreSQL
- ✅ SSL otomatis melalui Cloudflare
- ✅ Validasi sistem dan dependency secara otomatis
- ✅ Logging lengkap untuk debugging

## 🛠️ Requirements

### VPS Requirements
- **OS**: Ubuntu 18.04+ atau Debian 10+
- **RAM**: Minimal 1GB (Recommended 2GB+)
- **Storage**: Minimal 2GB free space
- **Architecture**: x86_64 (amd64)
- **Network**: Akses internet untuk download dependency

### Cloudflare Requirements

**Untuk install-api.sh (API Mode):**
- Akun Cloudflare dengan domain yang sudah dikonfigurasi
- Cloudflare API Token dengan permissions:
  - `Zone:Zone:Read`
  - `Zone:DNS:Edit`
  - `Account:Cloudflare Tunnel:Edit`
- Zone ID dan Account ID dari dashboard Cloudflare

**Untuk install.sh (Interactive Mode):**
- Akun Cloudflare dengan domain yang sudah dikonfigurasi
- Browser untuk login ke Cloudflare
- Akses internet untuk proses login

## 🚀 Quick Start

**Pilih versi script sesuai kebutuhan:**

### Versi 1: install-api.sh (API Mode - Recommended untuk Telegram Bot)

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Download script API version
wget https://raw.githubusercontent.com/tigrilminnada/auto-install-n8n/main/install-api.sh
chmod +x install-api.sh
```

### Versi 2: install.sh (Interactive Mode - Recommended untuk Manual Setup)

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Download script interactive version
wget https://raw.githubusercontent.com/tigrilminnada/auto-install-n8n/main/install.sh
chmod +x install.sh
```

### 2. Cara Membuat Cloudflare API Token (Untuk install-api.sh)

**⚠️ Hanya diperlukan untuk install-api.sh (API Mode)**

1. Login ke [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Klik **"Create Token"**
3. Pilih **"Custom token"**
4. Konfigurasi permissions:
   - **Zone** → **Zone** → **Read**
   - **Zone** → **DNS** → **Edit**
   - **Account** → **Cloudflare Tunnel** → **Edit**
5. **Zone Resources**: Include → All zones
6. **Account Resources**: Include → All accounts
7. Klik **"Continue to summary"** → **"Create Token"**
8. Salin token yang dihasilkan

### 3. Mendapatkan Zone ID dan Account ID (Untuk install-api.sh)

**⚠️ Hanya diperlukan untuk install-api.sh (API Mode)**

#### Zone ID:
1. Buka domain di Cloudflare Dashboard
2. Di sidebar kanan, salin **Zone ID**

#### Account ID:
1. Di Cloudflare Dashboard, klik domain Anda
2. Di sidebar kanan, salin **Account ID**

Atau gunakan API:
```bash
# Get Zone ID
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=example.com" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"

# Get Account ID
curl -X GET "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"
```

## 📖 Cara Penggunaan

## 🔵 Metode 1: install-api.sh (API Mode)

### Mode Interaktif (Guided Setup)

```bash
sudo ./install-api.sh
```

Script akan meminta input secara interaktif:
- Cloudflare API Token
- Zone ID dan Account ID
- Domain dan subdomain
- Username dan password n8n
- Pilihan database (SQLite/PostgreSQL)

### Mode Non-Interaktif (Telegram Bot / Automation)

```bash
sudo ./install-api.sh \
  --telegram-mode \
  --cf-api-token "your_cloudflare_api_token" \
  --cf-zone-id "your_zone_id" \
  --cf-account-id "your_account_id" \
  --subdomain "n8n" \
  --domain "example.com" \
  --n8n-pass "secure_password_123"
```

#### Parameter Opsional untuk API Mode:

```bash
# Dengan PostgreSQL
sudo ./install-api.sh \
  --telegram-mode \
  --cf-api-token "your_token" \
  --cf-zone-id "your_zone_id" \
  --cf-account-id "your_account_id" \
  --subdomain "n8n" \
  --domain "example.com" \
  --n8n-pass "secure_password_123" \
  --postgres \
  --postgres-pass "db_password_123" \
  --n8n-user "administrator"
```

## 🟢 Metode 2: install.sh (Interactive Mode)

### Setup Manual dengan Browser Login

```bash
sudo ./install.sh
```

Script akan melakukan:
1. **Input konfigurasi** - subdomain, username, password n8n
2. **Browser login** - membuka browser untuk login ke Cloudflare
3. **Pemilihan domain** - pilih domain yang sudah terdaftar di Cloudflare
4. **Instalasi otomatis** - setup Docker, tunnel, dan DNS

**Keuntungan Interactive Mode:**
- ✅ Tidak perlu API token manual
- ✅ Login langsung via browser (lebih mudah)
- ✅ Pemilihan domain otomatis dari akun Cloudflare
- ✅ Setup pertama kali yang user-friendly

## 📚 Parameter Lengkap (install-api.sh)

**⚠️ Parameter ini hanya untuk install-api.sh (API Mode)**

| Parameter | Required | Default | Deskripsi |
|-----------|----------|---------|-----------|
| `--cf-api-token` | ✅ | - | Cloudflare API Token |
| `--cf-zone-id` | ✅ | - | Cloudflare Zone ID |
| `--cf-account-id` | ✅ | - | Cloudflare Account ID |
| `--subdomain` | ✅ | - | Subdomain untuk n8n (misal: n8n) |
| `--domain` | ✅ | - | Domain utama (misal: example.com) |
| `--n8n-pass` | ✅ | - | Password n8n (minimal 8 karakter) |
| `--n8n-user` | ❌ | admin | Username n8n |
| `--postgres` | ❌ | false | Gunakan PostgreSQL |
| `--postgres-pass` | ❌ | n8n123 | Password PostgreSQL |
| `--telegram-mode` | ❌ | false | Mode non-interaktif |

## 📋 Parameter install.sh (Interactive Mode)

**install.sh tidak memerlukan parameter command line.** Semua konfigurasi dilakukan secara interaktif:

1. **Subdomain** - Input manual saat script berjalan
2. **Username n8n** - Input manual (default: admin)
3. **Password n8n** - Input manual dengan konfirmasi
4. **Database** - Pilihan SQLite atau PostgreSQL
5. **Domain** - Dipilih dari list domain Cloudflare setelah login

## 🔧 Troubleshooting

### Memeriksa Status Service

```bash
# Status Docker containers
docker ps
docker logs n8n-app

# Status Cloudflare Tunnel
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f

# Memeriksa koneksi n8n
curl -I http://localhost:5678
curl -I https://your-subdomain.your-domain.com
```

### Log Files

```bash
# Installation log
cat /tmp/n8n_install.log

# Docker logs
docker logs n8n-app
docker logs n8n-postgres  # jika menggunakan PostgreSQL
```

### Common Issues

#### 1. "Permission denied" saat menjalankan script
```bash
# Untuk API version
chmod +x install-api.sh
sudo ./install-api.sh

# Untuk Interactive version
chmod +x install.sh
sudo ./install.sh
```

#### 2. Docker tidak bisa start setelah instalasi
```bash
# Restart Docker
sudo systemctl restart docker

# Jika masih error, coba logout/login atau reboot
sudo reboot
```

#### 3. Cloudflare Tunnel tidak terhubung
```bash
# Restart cloudflared
sudo systemctl restart cloudflared

# Check konfigurasi
sudo cat /etc/cloudflared/config.yml
```

#### 4. n8n tidak bisa diakses dari internet
- Pastikan DNS record sudah terbuat di Cloudflare
- Check apakah port 5678 accessible: `curl http://localhost:5678`
- Verify Cloudflare Tunnel status: `sudo cloudflared tunnel list`

#### 5. Issues khusus install-api.sh (API Mode)
```bash
# Test API token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"

# Check Zone ID validity
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"
```

#### 6. Issues khusus install.sh (Interactive Mode)
- **Browser tidak bisa dibuka**: Pastikan VPS memiliki GUI atau gunakan X11 forwarding
- **Domain tidak muncul**: Pastikan domain sudah ditambahkan ke akun Cloudflare
- **Login gagal**: Coba manual: `cloudflared tunnel login`

### Reset Installation

```bash
# Stop semua services
sudo systemctl stop cloudflared
docker-compose -f /opt/n8n/docker-compose.yml down

# Hapus data (HATI-HATI: Ini akan menghapus semua data n8n!)
sudo rm -rf /opt/n8n
sudo rm -rf /etc/cloudflared

# Uninstall cloudflared service
sudo cloudflared service uninstall
```

## 📝 Post-Installation

### Akses n8n
Setelah instalasi selesai, akses n8n melalui:
- **URL**: https://your-subdomain.your-domain.com
- **Username**: sesuai yang diset (default: admin)
- **Password**: sesuai yang diset saat instalasi

### Backup Data

```bash
# Backup volume n8n
docker run --rm -v n8n_storage:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup PostgreSQL (jika digunakan)
docker exec n8n-postgres pg_dump -U n8n n8n > n8n-db-backup-$(date +%Y%m%d).sql
```

### Update n8n

```bash
cd /opt/n8n
docker-compose pull
docker-compose up -d
```

## 🔒 Security Best Practices

1. **Gunakan password yang kuat** untuk n8n dan database
2. **Aktifkan 2FA** di akun Cloudflare
3. **Backup reguler** data n8n
4. **Monitor log** untuk aktivitas mencurigakan
5. **Update reguler** n8n dan sistem VPS

## 🆘 Support

Jika mengalami masalah:

### Untuk install-api.sh (API Mode):
1. **Check log file**: `/tmp/n8n_install.log`
2. **Verify API token**: Test dengan curl command
3. **Check Zone ID dan Account ID**: Pastikan sesuai dengan domain
4. **Verify system requirements** terpenuhi

### Untuk install.sh (Interactive Mode):
1. **Check Docker status**: `docker ps` dan `docker logs n8n-app`
2. **Check Cloudflare login**: `cloudflared tunnel list`
3. **Check browser access**: Pastikan browser bisa dibuka
4. **Verify domain ownership**: Pastikan domain sudah di Cloudflare

### General Support:
1. **Check network connectivity** ke Cloudflare
2. **Verify system requirements** terpenuhi
3. **Check ports**: 5678 untuk n8n, 443 untuk HTTPS

## 🔄 Kapan Menggunakan Script Mana?

### Gunakan **install-api.sh** jika:
- ✅ Integrasi dengan Telegram bot
- ✅ Instalasi remote/automation
- ✅ Multiple deployment
- ✅ Server headless (tanpa GUI)
- ✅ CI/CD pipeline

### Gunakan **install.sh** jika:
- ✅ Setup manual pertama kali
- ✅ Learning purpose
- ✅ VPS dengan GUI/desktop
- ✅ Ingin guided installation
- ✅ Tidak ingin repot dengan API token

## 📜 License

Script ini dibuat untuk kemudahan instalasi n8n dengan Cloudflare Tunnel. Gunakan dengan tanggung jawab sendiri.

---

**Created with ❤️ for n8n automation enthusiasts**
