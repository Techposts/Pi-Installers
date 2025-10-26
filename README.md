# Pi-Installers: Automated Scripts for Raspberry Pi 🤖

A collection of simple, robust, and interactive scripts to set up popular services on any Raspberry Pi (Zero 2 W, 3, 4, 5) in minutes.

> **If you find this project helpful, please consider giving it a ⭐ star on GitHub!** It helps others discover it and shows your appreciation. Also, please like the videos and **[subscribe to the channel](https://www.youtube.com/@ravis1ngh)**. It helps us create more content like this.

### Why This Project?

Setting up services like Pi-hole or a Web Server on a Raspberry Pi can be a complex and time-consuming process of manual commands, configuration edits, and troubleshooting. These scripts automate the entire process, making it accessible to everyone, regardless of skill level.

| The Old, Manual Way (Hours of work) | The New, Automated Way (5 Minutes!) |
| :---: | :---: |
| 😫 Manually update the OS | ✅ **Script does it for you** |
| 🤯 Hunt for dependencies | ✅ **Script installs them all** |
| 😵‍💫 Edit config files via `nano` | ✅ **Script gives you simple prompts** |
| 😭 Troubleshoot common errors | ✅ **Script handles checks for you** |
| ⏳ Spend an hour or more... | 🚀 **Be done in 5 minutes!** |

---

### ✨ Features

* **🚀 5-Minute Setup:** Go from a fresh Raspberry Pi OS to a fully functional service in minutes.
* **🤖 Fully Automated:** Scripts handle system updates, dependency installation, and configuration.
* **✅ Smart & Interactive:** Scripts ask you simple questions instead of making you edit config files.
* **🛠️ Robust Pre-Checks:** Scripts run checks (like for root access) to prevent common errors before they happen.
* **💡 Clear Guidance:** Provides clear instructions, warnings (e.g., for Pi Zero users), and post-install steps.

---

### 🚀 Quick Start Installation

Choose the service you want to install and run its one-line command in your Raspberry Pi's SSH terminal.

#### 🛡️ Pi-hole (Network-Wide Ad Blocker)

Installs the Pi-hole ad blocker. This wrapper script handles system updates, provides crucial static IP warnings, and then launches the official Pi-hole installer.

```sh
wget https://raw.githubusercontent.com/Techposts/Pi-Installers/main/pi-hole/install_pihole.sh && chmod +x install_pihole.sh && sudo ./install_pihole.sh
```

* **See the full `README`:** **[pi-hole/README.md](./pi-hole)**
* **Watch the tutorial:** *(Link to your new Pi-hole video)*

---

#### 🌐 Web Server (WordPress, etc.)

Installs a complete web server (LAMP/LEMP stack) ready to host a website like WordPress.
*(Note: Update the path to your web server script when ready)*

```sh
wget https://raw.githubusercontent.com/Techposts/Pi-Installers/main/web-server/PiWebServer_v2.sh && chmod +x PiWebServer_v2.sh && sudo ./PiWebServer_v2.sh
```

* **See the full `README`:** **[web-server/README.md](./web-server)**
* **Watch the tutorial:** *(Link to your new Web Server video)*

---

#### 📻 AirPlay Audio Receiver

*(Placeholder: You can add your AirPlay installer here to keep all your scripts in one place!)*

```sh
# Add your one-line command for AirPlay here
```

* **See the full `README`:** **[airplay/README.md](./airplay)**
* **Watch the tutorial:** *(Link to your AirPlay video)*

---

### ❤️ Support the Project

If these installers saved you time and frustration, please consider showing your support!

* **⭐ Star the Repository:** Starring this project on GitHub is a great way to show your appreciation and helps others find it.
* **👍 Like & Subscribe:** If you came from a video tutorial, please **like the video** and **[subscribe to the channel](https://www.youtube.com/@ravis1ngh)**. It helps us create more content like this.

---

### License

This project is licensed under the MIT License. See the `LICENSE` file for details.