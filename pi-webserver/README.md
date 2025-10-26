# WordPress Cloudflare Tunnel Installer for Raspberry Pi

A complete, automated installer that sets up WordPress with Cloudflare Tunnel on your Raspberry Pi - making your local WordPress site accessible globally without port forwarding or dynamic DNS!

## 🎯 What This Script Does

This installer automatically configures:
- ✅ **Apache2** Web Server
- ✅ **MariaDB** Database
- ✅ **PHP 8.1+** with all WordPress requirements
- ✅ **WordPress** (latest version)
- ✅ **Cloudflare Tunnel** (secure public access without exposing your IP)

## 📋 Prerequisites

### Hardware Requirements
- **Recommended:** Raspberry Pi 3, 4, or 5 (with Ethernet port)
- **Minimum:** Raspberry Pi Zero 2W (works but slower)
- **OS:** Raspberry Pi OS (Debian-based)
- **Storage:** 8GB+ SD card
- **Internet:** Stable connection (Ethernet preferred)

### Before Running the Script

#### 1. **Get a Domain Name**
Purchase a domain from any registrar:
- GoDaddy
- Namecheap
- Hostinger
- Cloudflare Registrar
- Any other domain provider

#### 2. **Create a Cloudflare Account**
1. Go to [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
2. Create a free account (no credit card required)
3. Verify your email address

#### 3. **Add Your Domain to Cloudflare**
1. Log into Cloudflare Dashboard
2. Click **"Add a Site"**
3. Enter your domain name (e.g., `example.com`)
4. Select the **Free Plan**
5. Click **"Continue"**

#### 4. **Update Your Domain Nameservers**
Cloudflare will provide you with 2 nameservers (something like):
```
nameserver1.cloudflare.com
nameserver2.cloudflare.com
```

**Update nameservers at your domain registrar:**

<details>
<summary><b>GoDaddy</b></summary>

1. Log into GoDaddy
2. Go to **My Products** → **Domains**
3. Click on your domain
4. Scroll to **Nameservers** section
5. Click **"Change"**
6. Select **"Custom"**
7. Enter Cloudflare's nameservers
8. Save changes
</details>

<details>
<summary><b>Namecheap</b></summary>

1. Log into Namecheap
2. Go to **Domain List**
3. Click **"Manage"** next to your domain
4. Find **Nameservers** section
5. Select **"Custom DNS"**
6. Enter Cloudflare's nameservers
7. Save changes
</details>

<details>
<summary><b>Hostinger</b></summary>

1. Log into Hostinger
2. Go to **Domains**
3. Click on your domain
4. Find **DNS/Nameservers** section
5. Click **"Change Nameservers"**
6. Enter Cloudflare's nameservers
7. Save changes
</details>

**⏰ Wait Time:** Nameserver propagation can take 2-24 hours (usually 2-4 hours)

#### 5. **Verify Domain in Cloudflare**
1. Return to Cloudflare Dashboard
2. Wait for the status to change from "Pending" to "Active"
3. You'll receive an email when your domain is active

## 🚀 Installation

### Step 1: Connect to Your Raspberry Pi

**Option A: Using Termius (Recommended for Mobile)**
1. Download Termius app:
   - **Android:** [Google Play Store](https://play.google.com/store/apps/details?id=com.server.auditor.ssh.client)
   - **iOS:** [App Store](https://apps.apple.com/app/termius/id549039908)
2. Add a new host:
   - **Hostname:** Your Pi's IP address (find it with `hostname -I`)
   - **Username:** `pi` (or your username)
   - **Password:** Your Pi's password
3. Connect to your Pi

**Option B: Using Terminal (Mac/Linux) or PuTTY (Windows)**

**Mac/Linux:**
```bash
ssh pi@YOUR_PI_IP_ADDRESS
```

**Windows:**
1. Download [PuTTY](https://www.putty.org/)
2. Enter your Pi's IP address
3. Click "Open" and login

### Step 2: Download and Run the Installer

Copy and paste these commands one at a time:

```bash
wget https://raw.githubusercontent.com/Techposts/Raspberry-Pi-WebServer/main/Scripts/PiWebServer_v2.sh && chmod +x PiWebServer_v2.sh && sudo ./PiWebServer_v2.sh
```

### Step 3: Follow the Prompts

1. **Enter your domain name** when prompted (e.g., `example.com`)
2. **Authenticate with Cloudflare:**
   - A browser window will open (or you'll get a URL)
   - Log into your Cloudflare account
   - Authorize the connection
3. **Wait for installation** (5-10 minutes)

### Step 4: Configure Cloudflare SSL

After installation completes:

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain
3. Navigate to **SSL/TLS** section
4. Set encryption mode to **"Full"** or **"Flexible"**
5. Enable **"Always Use HTTPS"** under SSL/TLS → Edge Certificates

### Step 5: Complete WordPress Setup

1. Wait 2-5 minutes for DNS propagation
2. Visit `https://yourdomain.com`
3. Follow the WordPress installation wizard:
   - Choose your language
   - Enter site title and admin credentials
   - Click "Install WordPress"

## 🎉 You're Done!

Your WordPress site is now live and accessible globally at `https://yourdomain.com`!

## 📁 Important File Locations

After installation, you'll find a complete summary at:
```bash
cat /root/installation_summary.txt
```

Key locations:
- **WordPress files:** `/var/www/html/`
- **Database credentials:** `/root/.mysql_root_password`
- **Tunnel config:** `~/.cloudflared/config.yml`
- **Installation log:** `/var/log/wordpress-cloudflare-installer.log`

## 🛠️ Useful Commands

```bash
# Check tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# Restart tunnel
sudo systemctl restart cloudflared

# List all tunnels
cloudflared tunnel list

# Restart Apache
sudo systemctl restart apache2

# Restart database
sudo systemctl restart mariadb
```

## 🔒 Security Recommendations

After installation:

1. **Install security plugins:**
   - Wordfence Security
   - UpdraftPlus (for backups)
   - Limit Login Attempts

2. **Update regularly:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Change default passwords:**
   - WordPress admin password
   - Database passwords (stored in `/root/installation_summary.txt`)

4. **Enable Cloudflare security features:**
   - Go to Security → Settings
   - Set Security Level to "Medium" or "High"
   - Enable "Browser Integrity Check"

## ❓ Troubleshooting

### Site not loading after installation?
1. **Check DNS propagation:** Use [DNS Checker](https://dnschecker.org/)
2. **Verify tunnel is running:** `sudo systemctl status cloudflared`
3. **Check Cloudflare SSL settings:** Should be "Full" or "Flexible"

### Tunnel connection issues?
```bash
# Check tunnel logs
sudo journalctl -u cloudflared -n 50

# Restart tunnel
sudo systemctl restart cloudflared

# Verify tunnel is registered
cloudflared tunnel list
```

### Apache not starting?
```bash
# Check Apache status
sudo systemctl status apache2

# View error logs
sudo tail -f /var/log/apache2/error.log
```

### Database connection errors?
```bash
# Check MariaDB status
sudo systemctl status mariadb

# Test database connection
mysql -u wpuser -p wordpress
```

## 🎥 Video Tutorial

Watch the complete video tutorial: [Coming Soon - Link to YouTube Video]

## 💡 Features

- ✅ **Zero configuration** - Just enter your domain and go!
- ✅ **No port forwarding** - Works behind any router/firewall
- ✅ **Free Cloudflare CDN** - Fast global access
- ✅ **Automatic SSL** - Secure HTTPS by default
- ✅ **DDoS protection** - Cloudflare's security included
- ✅ **Multiple domains** - Add more domains to existing tunnel
- ✅ **Complete backups** - Automatic backup of existing installations

## 🤝 Contributing

Found a bug or want to contribute? Feel free to:
- Open an issue
- Submit a pull request
- Share your feedback

## 📄 License

This project is open source and available under the MIT License.

## ⭐ Support

If this helped you, please:
- ⭐ Star this repository
- 👍 Like the YouTube video
- 📢 Share with others
- 💬 Comment with your success story!

## 📞 Need Help?

- **GitHub Issues:** [Open an issue](https://github.com/YOUR_GITHUB_USERNAME/wordpress-cloudflare-pi/issues)
- **YouTube Comments:** Comment on the video
- **Cloudflare Docs:** [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

**Made with ❤️ for the Raspberry Pi community**

Transform your Raspberry Pi into a powerful web server in minutes! 🚀