# RaspberryPi-Pi-hole-Installer 🛡️

Turn any Raspberry Pi (Zero 2 W, 3, 4, 5) into a network-wide ad blocker with Pi-hole in just 5 minutes. This project uses a robust wrapper script to automate the entire installation process, making it incredibly simple to protect your entire network from ads and trackers.

> **If you find this project helpful, please consider giving it a ⭐ star on GitHub!** It helps others discover it and shows your appreciation for the work. Also, please like the video and **[subscribe to the channel](https://www.youtube.com/@ravis1ngh)**. It helps us create more content like this.

The goal of this project is to simplify the official Pi-hole installation by adding crucial pre-flight checks and helpful guidance, especially for headless setups like the Pi Zero.

| The Typical, Manual Way (15+ Mins) | The New, Automated Way (5 Mins!) |
| :---: | :---: |
| **[Link to Old Video Coming Soon!]** <br> *(Placeholder for a video showing the normal install)* | **[Link to New Video Coming Soon!]** <br> *(Placeholder for your new, faster video)* |

---

### ✨ Features

* **🚀 5-Minute Setup:** Go from a fresh Raspberry Pi OS to a fully functional ad-blocking DNS server in minutes.
* **🤖 Fully Automated Prep:** The script handles system updates, root privilege checks, and other pre-flight steps.
* **✅ Smart Interactive Checks:**
    * **Static IP Warning:** Interactively stops and warns you that a static IP is **required** before you start.
    * **Pi Zero Hardware:** Provides specific warnings and advice for Pi Zero users.
    * **USB LAN Ready:** Works perfectly with USB LAN adapters (just plug it in before running!).
* **⚙️ Uses the Official Installer:** This script is a "wrapper" that prepares your system and then calls the **official, robust Pi-hole installer** to handle the core setup, ensuring you have the most stable and secure installation.
* **💡 Clear Post-Install Guidance:** Finishes with a clear, final reminder of the most critical step—configuring your router.

---

### Hardware Requirements

* **Raspberry Pi:** A Pi Zero 2 W, 3, 4, or 5 is recommended.
* **MicroSD Card:** A quality card with at least 8GB.
* **Power Supply:** The official power supply for your Pi model.
* **Network Connection:**
    * For Pi 3/4/5: The built-in Ethernet port.
    * For Pi Zero: An **OTG cable** and a **USB LAN Adapter** (strongly recommended over Wi-Fi for a stable DNS).

---

### 🚀 Quick Start Installation

After installing Raspberry Pi OS Lite and connecting to your Pi via SSH, run this single command. It will download the installer script and automatically begin the guided setup.

```bash
curl -sSL [https://raw.githubusercontent.com/YourUsername/pi-bootstrap/main/pihole/install_pihole.sh](https://raw.githubusercontent.com/YourUsername/pi-bootstrap/main/pihole/install_pihole.sh) | sudo bash