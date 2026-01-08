# Mattermost Docker Installer

یک اسکریپت تعاملی و قدرتمند برای نصب خودکار Mattermost روی سرورهای لینوکس با استفاده از Docker و Docker Compose.

## 🚀 ویژگی‌ها

- **نصب خودکار Docker**: نصب و پیکربندی Docker Engine و Docker Compose در صورت عدم وجود
- **پشتیبانی از چندین توزیع**: سازگار با Ubuntu 22.04+, CentOS/RHEL, Fedora
- **SSL رایگان**: پشتیبانی از HTTPS با استفاده از Caddy و Let's Encrypt
- **پایگاه داده PostgreSQL**: نصب و پیکربندی خودکار PostgreSQL 16
- **پیکربندی آسان**: رابط کاربری تعاملی برای تنظیمات اولیه
- **مدیریت خودکار فایروال**: باز کردن خودکار پورت‌های مورد نیاز

## 📋 پیش‌نیازها

- یک سرور لینوکس با دسترسی root یا sudo
- حداقل 2GB RAM
- حداقل 10GB فضای دیسک آزاد
- اتصال به اینترنت

## 🛠️ نصب و راه‌اندازی

### ۱. دانلود اسکریپت

```bash
curl -O https://raw.githubusercontent.com/Erfan-sfr/mattermost/main/install-mattermost.sh
chmod +x install-mattermost.sh
```

### ۲. اجرای نصب

```bash
sudo bash install-mattermost.sh
```

اسکریپت به صورت تعاملی شما را برای تنظیمات زیر راهنمایی می‌کند:

#### تنظیمات اصلی
- **مسیر نصب**: پیش‌فرض `/opt/mattermost`
- **منطقه زمانی**: پیش‌فرض `Asia/Tehran`

#### تنظیمات دسترسی
- **استفاده از دامنه**: فعال‌سازی HTTPS با Let's Encrypt
- **دامنه**: مثلاً `chat.example.com`
- **ایمیل مدیر**: برای گواهی SSL
- **پورت عمومی**: پیش‌فرض `8065`

#### تنظیمات پایگاه داده
- **کاربر PostgreSQL**: پیش‌فرض `mmuser`
- **نام پایگاه داده**: پیش‌فرض `mattermost`
- **رمز عبور**: تولید خودکار یا ورود دستی

#### تنظیمات Mattermost
- **نسخه Mattermost**: پیش‌فرض `10.5.2`

## 📁 ساختار فایل‌های تولید شده

پس از اجرای اسکریپت، فایل‌های زیر در مسیر نصب ایجاد می‌شوند:

```
/opt/mattermost/
├── docker-compose.yml    # فایل اصلی Docker Compose
├── .env                  # متغیرهای محیطی
├── Caddyfile            # تنظیمات وب سرور Caddy (در صورت استفاده از دامنه)
└── README.md            # این فایل راهنما
```

## 🐳 سرویس‌های Docker

### PostgreSQL
- **ایمیج**: `postgres:16-alpine`
- **حجم ذخیره‌سازی**: `db_data`
- **بررسی سلامت**: هر 10 ثانیه

### Mattermost
- **ایمیج**: `mattermost/mattermost-enterprise-edition`
- **حجم‌های ذخیره‌سازی**: تنظیمات، داده‌ها، لاگ‌ها، پلاگین‌ها
- **پورت**: `8065`

### Caddy (اختیاری)
- **ایمیج**: `caddy:2-alpine`
- **پورت‌ها**: `80`, `443`
- **SSL**: خودکار با Let's Encrypt

## 🌐 دسترسی به Mattermost

### با دامنه و HTTPS
```
https://chat.example.com
```

### بدون دامنه (IP محلی)
```
http://YOUR_SERVER_IP:8065
```

## 🔧 مدیریت سرویس‌ها

### مشاهده وضعیت سرویس‌ها
```bash
cd /opt/mattermost
docker compose ps
```

### مشاهده لاگ‌ها
```bash
# لاگ Mattermost
docker compose logs -f mattermost

# لاگ PostgreSQL
docker compose logs -f postgres

# لاگ Caddy (در صورت استفاده)
docker compose logs -f caddy
```

### راه‌اندازی مجدد
```bash
docker compose restart
```

### توقف سرویس‌ها
```bash
docker compose down
```

### بروزرسانی Mattermost
```bash
# ویرایش .env و تغییر نسخه
nano .env

# اجرای مجدد با نسخه جدید
docker compose up -d --pull
```

## 🔒 پیکربندی فایروال

اسکریپت به صورت خودکار پورت‌های زیر را باز می‌کند:

- **8065/tcp**: Mattermost
- **80/tcp**: HTTP (در صورت استفاده از HTTPS)
- **443/tcp**: HTTPS (در صورت استفاده از HTTPS)

### تنظیم دستی فایروال

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

## 📊 پشتیبان‌گیری

### پشتیبان‌گیری از پایگاه داده
```bash
cd /opt/mattermost
docker compose exec postgres pg_dump -U mmuser mattermost > backup.sql
```

### بازیابی پایگاه داده
```bash
docker compose exec -T postgres psql -U mmuser mattermost < backup.sql
```

### پشتیبان‌گیری از فایل‌ها
```bash
tar -czf mattermost-backup.tar.gz /opt/mattermost
```

## 🛠️ عیب‌یابی

### مشکلات رایج

#### ۱. Mattermost در دسترس نیست
```bash
# بررسی وضعیت سرویس‌ها
docker compose ps

# بررسی لاگ‌ها
docker compose logs mattermost
```

#### ۲. مشکلات SSL
```bash
# بررسی لاگ‌های Caddy
docker compose logs caddy

# بررسی تنظیمات DNS
nslookup chat.example.com
```

#### ۳. مشکلات پایگاه داده
```bash
# بررسی اتصال به PostgreSQL
docker compose exec postgres pg_isready -U mmuser -d mattermost
```

#### ۴. پورت‌ها بسته هستند
```bash
# بررسی پورت‌های باز
sudo netstat -tlnp | grep :8065
```

### حذف کامل نصب
```bash
cd /opt/mattermost
docker compose down -v
cd ..
rm -rf /opt/mattermost
```

## 📝 متغیرهای محیطی

فایل `.env` شامل تنظیمات زیر است:

```bash
TZ=Asia/Tehran                    # منطقه زمانی
POSTGRES_USER=mmuser              # کاربر PostgreSQL
POSTGRES_PASSWORD=your_password   # رمز عبور PostgreSQL
POSTGRES_DB=mattermost            # نام پایگاه داده
MM_SITEURL=https://chat.example.com  # آدرس سایت Mattermost
MATTERMOST_IMAGE_TAG=10.5.2       # نسخه Mattermost
DOMAIN=chat.example.com           # دامنه
ADMIN_EMAIL=admin@example.com     # ایمیل مدیر
```

## 🔧 پیکربندی پیشرفته

### تغییر پورت Mattermost
```bash
# ویرایش docker-compose.yml
ports:
  - "8080:8065"  # تغییر پورت از 8065 به 8080

# راه‌اندازی مجدد
docker compose up -d
```

### اضافه کردن پلاگین‌ها
```bash
# کپی پلاگین به کانتینر
docker cp plugin.tar.gz mm-app:/mattermost/plugins/

# نصب پلاگین در Mattermost
# از طریق پنل مدیریت Mattermost
```

## 🤝 مشارکت

برای مشارکت در این پروژه:

1. Fork کنید
2. شاخه جدید بسازید: `git checkout -b feature/new-feature`
3. تغییرات را commit کنید: `git commit -am 'Add new feature'`
4. Push کنید: `git push origin feature/new-feature`
5. Pull Request ایجاد کنید

## 📄 مجوز

این پروژه تحت مجوز MIT منتشر شده است.

## 🆘 پشتیبانی

- **GitHub Issues**: [ایجاد Issue جدید](https://github.com/Erfan-sfr/mattermost/issues)
- **مستندات Mattermost**: [docs.mattermost.com](https://docs.mattermost.com)

## 🔄 تاریخچه تغییرات

### v1.0.0
- نسخه اولیه اسکریپت نصب Mattermost
- پشتیبانی از Ubuntu 22.04+
- نصب خودکار Docker و PostgreSQL
- پشتیبانی از HTTPS با Caddy

---

**توجه**: این اسکریپت برای محیط‌های تولید (Production) طراحی شده است. لطفاً قبل از استفاده در محیط‌های حساس، تست کامل انجام دهید.
