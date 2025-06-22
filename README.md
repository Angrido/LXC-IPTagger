# 📦 LXC IPTagger

A simple 🔧 Bash script for Proxmox VE that automatically tags your LXC containers with their current private IPv4 address (e.g., `192.168.x.x`) in the LXC config file.

---

## ✨ Features

- 🔍 Detects the primary private IPv4 address of each running LXC container
- 🏷️ Writes it as a `tag` in `/etc/pve/lxc/<vmid>.conf`
- 🔁 Updates the tag if the IP has changed
- ➕ Adds the IP if it was not present
- 🔐 Clean, dependency-free (pure Bash)
- 🤖 Ready to run manually or via cron

---

## ⚙️ Requirements

- Proxmox VE system
- Bash shell
- Root privileges (required to access and edit container config files)

---

## 📥 Installation

Download this repository:

```bash
curl -o lxc-iptagger.sh https://raw.githubusercontent.com/Angrido/LXC-IPTagger/main/lxc-iptagger.sh
cd lxc-iptagger
chmod +x lxc-iptagger.sh
````

(Optional) Move the script to your system PATH:

```bash
sudo mv lxc-iptagger.sh /usr/local/bin/lxc-iptagger
```

---

## 🚀 Usage

Run the script with root privileges:

```bash
sudo lxc-iptagger
```

Example output:

```
🔍 Processing VMID: 101
ℹ️  VMID 101 already tagged with IP 192.168.1.100

🔍 Processing VMID: 102
🔁 VMID 102 IP tag updated from 192.168.1.101 to 192.168.1.150

🔍 Processing VMID: 103
➕ VMID 103 tagged with new IP 192.168.1.200
```

---

## ⏱️ Automate with cron

To run the script automatically, add it to the root user’s crontab:

```bash
sudo crontab -e
```

Add this line to update tags every 10 minutes:

```cron
*/10 * * * * /usr/local/bin/lxc-iptagger
```

---

## 🧾 Result in LXC config

Example content of `/etc/pve/lxc/103.conf`:

```ini
tags: web,192.168.1.200
```

---

## 📌 Notes

* Only running containers are processed
* Only private IPv4 addresses (192.168.x.x, 10.x.x.x, 172.16–31.x.x) are considered
* Only one IP per container is tagged (the first private IP found)
* If the tag already matches the IP, nothing is changed
* Other existing tags are preserved

---

## 🪪 License

MIT License. See [LICENSE](LICENSE) file for details.

