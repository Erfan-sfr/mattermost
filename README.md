# Mattermost Docker Installer

A powerful interactive script for automated Mattermost installation on Linux servers using Docker and Docker Compose.

## 🚀 Features

- **Automatic Docker Installation**: Install and configure Docker Engine and Docker Compose if missing
- **Multi-Distribution Support**: Compatible with Ubuntu 22.04+, CentOS/RHEL, Fedora
- **Free SSL**: HTTPS support with Caddy and Let's Encrypt
- **PostgreSQL Database**: Automatic PostgreSQL 16 setup and configuration
- **Easy Configuration**: Interactive interface for initial settings
- **Automatic Firewall Management**: Automatically open required ports

## 📋 Prerequisites

- A Linux server with root or sudo access
- Minimum 2GB RAM
- Minimum 10GB free disk space
- Internet connection

## 🛠️ Installation

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/Erfan-sfr/mattermost/main/install-mattermost.sh
chmod +x install-mattermost.sh
```

### 2. Run Installation

```bash
sudo bash install-mattermost.sh
```

The script will interactively guide you through the following configurations:

#### Basic Settings
- **Installation Path**: Default `/opt/mattermost`
- **Timezone**: Default `Asia/Tehran`

#### Access Settings
- **Use Domain**: Enable HTTPS with Let's Encrypt
- **Domain**: e.g., `chat.example.com`
- **Admin Email**: For SSL certificates
- **Public Port**: Default `8065`

#### Database Settings
- **PostgreSQL User**: Default `mmuser`
- **Database Name**: Default `mattermost`
- **Password**: Auto-generate or manual entry

#### Mattermost Settings
- **Mattermost Version**: Default `10.5.2`

## 📁 Generated File Structure

After running the script, the following files are created in the installation directory:

```
/opt/mattermost/
├── docker-compose.yml    # Main Docker Compose file
├── .env                  # Environment variables
├── Caddyfile            # Caddy web server config (if using domain)
└── README.md            # This documentation
```

## 🐳 Docker Services

### PostgreSQL
- **Image**: `postgres:16-alpine`
- **Storage Volume**: `db_data`
- **Health Check**: Every 10 seconds

### Mattermost
- **Image**: `mattermost/mattermost-enterprise-edition`
- **Storage Volumes**: Config, data, logs, plugins
- **Port**: `8065`

### Caddy (Optional)
- **Image**: `caddy:2-alpine`
- **Ports**: `80`, `443`
- **SSL**: Automatic with Let's Encrypt

## 🌐 Accessing Mattermost

### With Domain and HTTPS
```
https://chat.example.com
```

### Without Domain (Local IP)
```
http://YOUR_SERVER_IP:8065
```

## 🔧 Service Management

### Check Service Status
```bash
cd /opt/mattermost
docker compose ps
```

### View Logs
```bash
# Mattermost logs
docker compose logs -f mattermost

# PostgreSQL logs
docker compose logs -f postgres

# Caddy logs (if using)
docker compose logs -f caddy
```

### Restart Services
```bash
docker compose restart
```

### Stop Services
```bash
docker compose down
```

### Update Mattermost
```bash
# Edit .env and change version
nano .env

# Re-run with new version
docker compose up -d --pull
```

## 🔒 Firewall Configuration

The script automatically opens the following ports:

- **8065/tcp**: Mattermost
- **80/tcp**: HTTP (if using HTTPS)
- **443/tcp**: HTTPS (if using HTTPS)

### Manual Firewall Setup

#### UFW (Ubuntu)
```bash
sudo ufw allow 8065/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### firewalld (CentOS/RHEL)
```bash
sudo firewall-cmd --permanent --add-port=8065/tcp
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 📊 Backup and Recovery

### Database Backup
```bash
cd /opt/mattermost
docker compose exec postgres pg_dump -U mmuser mattermost > backup.sql
```

### Database Recovery
```bash
docker compose exec -T postgres psql -U mmuser mattermost < backup.sql
```

### File Backup
```bash
tar -czf mattermost-backup.tar.gz /opt/mattermost
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Mattermost Not Accessible
```bash
# Check service status
docker compose ps

# Check logs
docker compose logs mattermost
```

#### 2. SSL Issues
```bash
# Check Caddy logs
docker compose logs caddy

# Check DNS settings
nslookup chat.example.com
```

#### 3. Database Issues
```bash
# Check PostgreSQL connection
docker compose exec postgres pg_isready -U mmuser -d mattermost
```

#### 4. Ports Are Closed
```bash
# Check open ports
sudo netstat -tlnp | grep :8065
```

### Complete Removal
```bash
cd /opt/mattermost
docker compose down -v
cd ..
rm -rf /opt/mattermost
```

## 📝 Environment Variables

The `.env` file contains the following settings:

```bash
TZ=Asia/Tehran                    # Timezone
POSTGRES_USER=mmuser              # PostgreSQL user
POSTGRES_PASSWORD=your_password   # PostgreSQL password
POSTGRES_DB=mattermost            # Database name
MM_SITEURL=https://chat.example.com  # Mattermost site URL
MATTERMOST_IMAGE_TAG=10.5.2       # Mattermost version
DOMAIN=chat.example.com           # Domain
ADMIN_EMAIL=admin@example.com     # Admin email
```

## 🔧 Advanced Configuration

### Change Mattermost Port
```bash
# Edit docker-compose.yml
ports:
  - "8080:8065"  # Change port from 8065 to 8080

# Restart
docker compose up -d
```

### Add Plugins
```bash
# Copy plugin to container
docker cp plugin.tar.gz mm-app:/mattermost/plugins/

# Install plugin in Mattermost
# Through Mattermost admin panel
```

## 🤝 Contributing

To contribute to this project:

1. Fork the repository
2. Create a new branch: `git checkout -b feature/new-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/new-feature`
5. Submit a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

- **GitHub Issues**: [Create a new issue](https://github.com/Erfan-sfr/mattermost/issues)
- **Mattermost Documentation**: [docs.mattermost.com](https://docs.mattermost.com)

## 🔄 Changelog

### v1.0.0
- Initial Mattermost installer script
- Support for Ubuntu 22.04+
- Automatic Docker and PostgreSQL installation
- HTTPS support with Caddy

---

**Note**: This script is designed for production environments. Please perform thorough testing before using in sensitive environments.
