# Pi-hole Installer

This script automates the installation of Pi-hole on a Raspberry Pi.

It performs the following steps:
1.  Checks that you are running as root.
2.  Runs a full system update (`apt update && apt upgrade`) to prevent dependency issues.
3.  Provides a critical interactive warning about the **Static IP** requirement.
4.  Gives a specific hardware warning for **Raspberry Pi Zero** users.
5.  Calls the official Pi-hole installer to handle the core setup.
6.  Provides a clear post-install summary of your next steps (router config).

## How to Run

From the main project directory:

```sh
cd pihole
chmod +x install_pihole.sh
sudo ./install_pihole.sh