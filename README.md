# 🚀 n8n Auto Installer with Cloudflare Tunnel

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Tunnel-orange.svg)](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
[![n8n](https://img.shields.io/badge/n8n-Latest-brightgreen.svg)](https://n8n.io/)

> **One-click n8n automation installer with Docker + Cloudflare Tunnel for secure HTTPS access**

## ⚡ Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tigrilminnada/auto-install-n8n/refs/heads/master/install.sh | bash
```

## 📋 Prerequisites

### 1. Server Requirements
- **OS**: Ubuntu 18.04+ or Debian 10+
- **RAM**: 1GB minimum (2GB recommended)
- **Storage**: 1GB free space
- **Access**: Root or sudo privileges

### 2. Cloudflare Domain Setup

#### Step 1: Add Domain to Cloudflare
1. Login to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Click **"Add a Site"**
3. Enter your domain (e.g., `yourdomain.com`)
4. Choose **Free Plan**
5. Update nameservers at your domain registrar:
   ```
   nameserver1.cloudflare.com
   nameserver2.cloudflare.com
   ```
6. Wait for DNS propagation (5-60 minutes)

#### Step 2: Verify Domain Status
- Domain status should show **"Active"** in Cloudflare dashboard
- SSL/TLS mode should be **"Full"** or **"Full (strict)"**

#### Step 3: Prepare Subdomain
- Choose subdomain for n8n (e.g., `automation`, `n8n`, `workflows`)
- Don't create DNS record manually - installer will handle this

## 🛠️ Installation Process

The installer will automatically:

1. **Check system requirements**
2. **Install Docker & Docker Compose**
3. **Install Cloudflare Tunnel (cloudflared)**
4. **Prompt for configuration**:
   - Subdomain name
   - Admin username/password
   - Database choice (SQLite/PostgreSQL)
5. **Authenticate with Cloudflare** (opens browser)
6. **Select your domain** from available list
7. **Create and configure tunnel**
8. **Start n8n containers**
9. **Create DNS record automatically**

## 📊 What You'll Get

### Access Information
- **URL**: `https://[subdomain].[yourdomain].com`
- **Username**: Your chosen admin username
- **Password**: Your chosen admin password

### Installed Components
- **n8n**: Latest version in Docker container
- **Database**: SQLite (default) or PostgreSQL
- **Cloudflare Tunnel**: Secure HTTPS access
- **Management Scripts**: Start/stop/backup tools

## 🔧 Management Commands

```bash
# Navigate to n8n directory
cd /opt/n8n

# Container management
./start.sh     # Start containers
./stop.sh      # Stop containers  
./restart.sh   # Restart containers
./logs.sh      # View logs
./backup.sh    # Create backup

# Check status
docker ps --filter name=n8n
sudo systemctl status cloudflared
```

## ⚠️ Troubleshooting

### Common Issues

**Domain not available during installation:**
- Verify domain is added to Cloudflare
- Check domain status is "Active"
- Ensure you have admin access to the domain

**Browser doesn't open for Cloudflare auth:**
```bash
# Run on server with GUI or copy the auth URL to local browser
cloudflared tunnel login
```

**Permission denied errors:**
```bash
sudo usermod -aG docker $USER
# Logout and login again
```

**Containers won't start:**
```bash
# Check logs
docker logs n8n-app
```

## 🚀 Features

- ✅ **One-click installation** - Fully automated setup
- 🐳 **Docker containers** - Lightweight and portable
- 🔒 **HTTPS by default** - Cloudflare SSL termination
- 🔐 **Built-in authentication** - Username/password protection
- 📦 **Auto-restart** - Containers restart on reboot
- 🛡️ **No port exposure** - Secure tunnel connection
- 🗄️ **Database choice** - SQLite or PostgreSQL
- 📋 **Management tools** - Easy backup and maintenance

## 🆘 Support

- **Issues**: [GitHub Repository](https://github.com/tigrilminnada/auto-install-n8n/issues)
- **n8n Docs**: [docs.n8n.io](https://docs.n8n.io/)
- **Cloudflare Tunnel**: [Cloudflare Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

<<<<<<< HEAD
**Transform your workflows with automated n8n deployment**
=======
**Transform your workflows with automated n8n deployment**
>>>>>>> 2c35008dcd0f150093bf2d9748e894cd53b26b6c
