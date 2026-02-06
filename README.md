# Paqet-Tunnel-Manager | [📄 فارسی](README.fa.md)

Management script for **paqet**: a raw socket, KCP-based tunnel designed for firewall/DPI bypass. Supports **Kharej (external) server** and **Iran client (entry point)** configurations.


---

## Table of Contents

* [Quick Start](#quick-start)
* [Installation Steps](#installation-steps)

  * [Step 1: Setup Server (Kharej – VPN Server)](#step-1-setup-server-kharej--vpn-server)
  * [Step 2: Setup Server (Iran – Client/Entry Point)](#step-2-setup-server-iran--cliententry-point)
* [Advanced Configuration (KCP Modes)](#advanced-configuration-kcp-modes)
* [Network Optimization (Optional)](#network-optimization-optional)
* [Included Tools](#included-tools)
* [Troubleshooting: Paqet Installation Issues](#troubleshooting-paqet-installation-issues)
* [Need Help](#%EF%B8%8F-need-help)
* [Requirements](#requirements)
* [Script Screenshots](#-script-screenshots)
* [License](#license)
* [Credits](#credits)

---

## Quick Start

Run the script on **both servers** as **root**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```

Select **option 0**, then **option 1** to install prerequisites.

---

## Installation Steps

### Step 1: Setup Server (Kharej – VPN Server)

Run the script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```

#### Configuration Steps

1. **Select option 2** (Kharej)
2. **Enter a custom name** for the tunnel between the two servers
3. **Press Enter** *(automatic)*
4. **Press Enter** *(automatic)*
5. **Press Enter** *(automatic)*
6. **Specify the port** used between the two servers (e.g. `555`)
7. **Save the generated secret key**, then press **`Y`** to continue
8. **Select option 1 or..**
9. **conn value** → Number of KCP connections
10. **MTU** → Usually 1350 is fine (press Enter)
11. **Select option 2**
12. **Enter V2Ray / OpenVPN port(s)**
    Single: `555` — Multiple: `555,666,777`

---

### Step 2: Setup Server (Iran – Client/Entry Point)

#### Configuration Steps

1. **Select option 3** (Iran)
2. **Enter the Kharej server IP**
3. **Specify the port** used between the two servers (e.g. `555`)
4. **Enter the secret key** generated on the Kharej server
5. **Enter a custom name** for the tunnel between the two servers
6. **Press Enter** *(automatic)*
7. **Press Enter** *(automatic)*
8. **Press Enter** *(automatic)*
9. **Select option 1 or..**
10. **conn value** → Number of KCP connections
11. **MTU** → Usually 1350 is fine (press Enter)
12. **Select option 2**
13. **Enter V2Ray / OpenVPN port(s)**
    Single: `555` — Multiple: `555,666,777`

---

## Advanced Configuration (KCP Modes)

In **Step 8 (Kharej server)** and **Step 9 (Iran server)**, you can choose different configuration modes.

### KCP Modes

0. **normal** – Normal speed, normal latency, low resource usage
1. **fast** – Balanced speed, low latency, normal resource usage
2. **fast2** – High speed, lower latency, moderate resource usage
3. **fast3** – Maximum speed, very low latency, high CPU usage
4. **manual** – Advanced manual configuration

> **Recommendation:**
> Based on feedback from current users, **option 1 (fast)** provides the best overall experience for most setups.
> If your **Iran server has network or resource limitations**, test different modes to determine which works best.
> If you have sufficient **experience and technical knowledge**, use **manual mode** to fully customize all settings.

---

## Network Optimization (Optional)

Run the script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```

Select **option 7**, then choose one of the following:

1. **BBR** – TCP congestion control optimizer *(recommended for external servers)*
2. **DNS Finder** – Find the best DNS servers for Iran *(recommended for Iran servers)*
3. **Mirror Selector** – Find the fastest APT repository mirror *(recommended for Iran servers)*

---

## Included Tools

* **[BBR – TCP Congestion Control Optimizer](https://github.com/teddysun/across/)**
* **[IranDNSFinder – Finds and configures optimal DNS servers](https://github.com/alinezamifar/IranDNSFinder)**
* **[DetectUbuntuMirror – Selects the fastest APT mirror (Ubuntu/Debian only)](https://github.com/alinezamifar/DetectUbuntuMirror)**

---

## Troubleshooting: Paqet Installation Issues

If Paqet fails to install automatically during configuration
(e.g., you see **"Failed to install Paqet"** or the script gets stuck when adding a new config in **Server/Kharej** or **Client/Iran** mode), follow these steps:

1. **Manually download the Paqet binary**

   Visit the official releases page:
   [https://github.com/hanselime/paqet/releases](https://github.com/hanselime/paqet/releases)

   * Choose the **latest release** (e.g., `v1.0.0-alpha.13` or newer).
   * Download the file matching your server architecture:

     * `paqet-linux-amd64-*.tar.gz` → x86_64 / amd64
     * `paqet-linux-arm64-*.tar.gz` → aarch64 / arm64

2. **Place the downloaded file in this folder:**

```bash
/root/paqet/
```

If the folder does not exist, create it first:

```bash
mkdir -p /root/paqet
```

3. **Run the manager script again**

The script will automatically detect the file inside `/root/paqet/`, extract it, and complete the installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```

---

## ⚠️ Need Help?

If you encounter any issues, contact me on Telegram:

**[@behzad_developer](https://t.me/behzad_developer)**

I am usually online and will assist you as soon as possible.

---

## Requirements

* Linux server (Ubuntu, Debian, CentOS, etc.)
* Root access
* `libpcap-dev`
* `iptables`
* `paqet`

---

## 📸 Script Screenshots

<details>
<summary>Main Menu</summary>
<br>
<img src="images/Main_Menu.png" width="800">
</details>

<details>
<summary>Install Paqet</summary>
<br>
<img src="images/Install_paqet.png" width="800">
</details>

<details>
<summary>List Services</summary>
<br>
<img src="images/List_Services.png" width="800">
</details>

<details>
<summary>Manage Service</summary>
<br>
<img src="images/Manage_Service.png" width="800">
</details>

<details>
<summary>Optimize Server</summary>
<br>
<img src="images/Optimize_Server.png" width="800">
</details>

---

## License

This project is licensed under the **MIT License**.

---

## 💖 Support / Donate

If you are using **Paqet-Tunnel-Manager** and want to support the development of this project, you can contribute via:

<details>
<summary>💰 Crypto</summary>
<br>

* **Tron (TRC20):**
  `TFYnorJt5gvejLwR8XQdjep1krS9Zw8pz3`

</details>

> Any contribution, big or small, helps keep the project alive and motivates further development. 🙏

---

## Credits

* **[paqet](https://github.com/hanselime/paqet)** – Raw packet tunneling library by hanselime
