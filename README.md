# Warptux

![Image handcrafted by me!](assets/1-tuxwarp-logo.png)

**Warptux is a small project for installing and connecting the official Cloudflare WARP client on Linux.**

Please note: This is not an official Cloudflare project, and it does not come with support or guarantee that it will work on every Linux distribution or release.

## What it does

The Bash script:

1. Identifies the Linux distribution and package family.
2. Adds Cloudflare’s official package repository and installs the WARP client.
3. Starts the WARP service.
4. Registers the device if it does not appear to be registered.
5. Connects to WARP and checks that the connection is working.

The installer is intended for Ubuntu and Ubuntu-based distributions, Debian, Fedora, RHEL, and CentOS. Support for derivatives depends on whether the system identifies its base distribution and release in a way the script can use. Cloudflare’s repository may not provide packages for every release or architecture.

## What it does not do

This project is deliberately limited in scope. It does **not** install or configure WireGuard directly, manage custom routing rules, configure SOCKS proxies, or enroll a device into a Cloudflare Zero Trust organization. It is intended for the standard consumer WARP client.

## Before you run it

The installer requires:

- A supported Linux distribution using `APT` or `DNF/YUM`.
- `systemd`.
- Root privileges.
- An internet connection to reach your distribution’s package repositories and Cloudflare’s package repository.

**The script connects WARP when installation finishes.** This changes how the device’s internet traffic is routed. Review the script before running it, especially on a remote server or a machine with existing VPN, firewall, or network-routing configuration.

## Usage

Clone or download this repository, review `warp.sh`, then run:

```bash
sudo bash ./warp.sh
```

To display the script’s usage information:
```bash 
sudo bash ./warp.sh --help
```
 
Afterward, you can check the client status with:
```bash 
sudo warp-cli status
```
For other client-management commands, refer to [Cloudflare’s Linux WARP documentation](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/download/#linux:~:text=Linux).

---
## Open source and contributions
The installer script is distributed under the GPL License. The license applies to this project’s code; Cloudflare’s WARP client, service, and infrastructure remain subject to their own terms and licenses. This is a small project. Suggestions are welcome. Please include your distribution name and version, relevant error output, and the command you ran when reporting an issue. Do not include private keys, account credentials, or other secrets.
## Disclaimer
Use this project at your own risk. It modifies system package sources, installs software, starts a system service, and connects a VPN-like network client. The project is provided “as is,” without warranties or guarantees of support. Warptux is not affiliated with, authorized by, or endorsed by Cloudflare. Cloudflare and WARP are trademarks of their respective owners.
