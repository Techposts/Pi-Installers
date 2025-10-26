# 🚀 Pi-Installers

A collection of simple, interactive shell scripts to automate the setup of common services on a Raspberry Pi. Easily install Pi-hole, an AirPlay receiver, a web server, and more with just one command.

These scripts are designed to be run on a fresh install of Raspberry Pi OS Lite.

---

## Scripts Available

* **[Pi-hole](./pihole)**
    * Installs the Pi-hole network-wide ad blocker.
    * Includes pre-flight checks and warnings for Pi Zero users.

* **[AirPlay Receiver](./airplay)**
    * (Your description here)

* **[Web Host (LAMP/LEMP)](./web-host)**
    * (Your description here)

---

## How to Use

1.  Clone this repository to your Pi:
    ```sh
    git clone [https://github.com/YourUsername/pi-bootstrap.git](https://github.com/YourUsername/pi-bootstrap.git)
    ```

2.  Navigate to the script you want to use:
    ```sh
    cd pi-bootstrap/pihole
    ```

3.  Make the script executable:
    ```sh
    chmod +x install_pihole.sh
    ```

4.  Run the script with `sudo`:
    ```sh
    sudo ./install_pihole.sh
    ```

---

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.