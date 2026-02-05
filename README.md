# Paqet-Tunnel-Manager
Management script for paqet: raw socket KCP-based tunnel for firewall/DPI bypass. Supports kharej server and Iran client configurations.

## Quick Start

# Install prerequisites (Run on both servers (as root))
Run the script to install the prerequisites
Press option 0 and then option 1 to install the prerequisites
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```

##Installation Steps
# Step 1: Setup Server (Kharej – VPN Server)
Run the script:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
````
### Configuration Steps
1. **Select option 2** (Kharej)
2. **Enter a custom name** for the tunnel between the two servers
3. **Press Enter** *(automatic)*
4. **Press Enter** *(automatic)*
5. **Press Enter** *(automatic)*
6. **Specify the port** used between the two servers (e.g. `555`)
7. **Save the generated secret key**, then press **`Y`** to continue
8. **Select option 1**
9. **Select option 2**
10. **Enter V2Ray / OpenVPN port(s)**
    Single: `555` — Multiple: `555,666,777`

# Step 2: Setup Server (Iran – Client(Entry Point))
### Configuration Steps
1. **Select option 3** (Iran)
2. **Enter the Kharej server IP**
3. **Specify the port** used between the two servers (e.g. `555`)
4. **Enter the secret key** generated on the server(Kharej)
5. **Enter a custom name** for the tunnel between the two servers
6. **Press Enter** *(automatic)*
7. **Press Enter** *(automatic)*
8. **Press Enter** *(automatic)*
9. **Select option 1**
10. **Select option 2**
11. **Enter V2Ray / OpenVPN port(s)**
    Single: `555` — Multiple: `555,666,777`

## Advanced Configuration (KCP Modes)
In **Step 8 (External server)** and **Step 9 (Iran server)**, you can choose different configuration modes.

### KCP Modes
0. **normal** – Normal speed, normal latency, low resource usage  
1. **fast** – Balanced speed, low latency, normal resource usage  
2. **fast2** – High speed, lower latency, moderate resource usage  
3. **fast3** – Maximum speed, very low latency, high CPU usage  
4. **manual** – Advanced manual configuration

> **Recommendation:**  
> Based on feedback from current users, **option 1 (fast)** provides the best overall experience for most setups.
If your **Iran server has network or resource limitations**, it is recommended to test different modes to determine which one works best for your environment.
If you have sufficient **experience and technical knowledge**, you can use **manual mode** to fully customize all settings.

## Network Optimization (Optional)
Run the script:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
````

Select **option 7**, then choose one of the following:
1. **BBR** – TCP congestion control optimizer *(recommended for external servers)*
2. **DNS Finder** – Find the best DNS servers for Iran *(recommended for Iran servers)*
3. **Mirror Selector** – Find the fastest APT repository mirror *(recommended for Iran servers)*

### Included Tools
- **[BBR – TCP Congestion Control Optimizer](https://github.com/teddysun/across/)**
- **[IranDNSFinder – Finds and configures optimal DNS servers](https://github.com/alinezamifar/IranDNSFinder)**
- **[DetectUbuntuMirror – Selects the fastest APT mirror (Ubuntu/Debian only)](https://github.com/alinezamifar/DetectUbuntuMirror)**




## Troubleshooting: Paqet Installation Issues

If Paqet fails to install automatically during configuration  
(i.e., you see "Failed to install Paqet" or the script gets stuck when adding a new config in **Server/Kharej** or **Client/Iran** mode), follow these steps:

1. **Manually download the Paqet binary**  

   Visit the official releases page:  
   [https://github.com/hanselime/paqet/releases](https://github.com/hanselime/paqet/releases)

   - Choose the **latest release** (e.g., `v1.0.0-alpha.13` or newer — always pick the most recent).  
   - Download the file that matches your server architecture:

     - `paqet-linux-amd64-*.tar.gz` → for most 64-bit servers (x86_64 / amd64)  
     - `paqet-linux-arm64-*.tar.gz` → for ARM-based servers (aarch64 / arm64)

2. **Place the downloaded file in this folder:**  

   ```bash
   /root/paqet/
   ````

If the folder doesn't exist, create it first:

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

If you encounter any issues, **contact me on Telegram**:
**[@behzad_developer](https://t.me/behzad_developer)**

I am usually online and will assist you as soon as possible.
 
## Requirements
- Linux server (Ubuntu, Debian, CentOS, etc.)
- Root access
- `libpcap-dev`
- `iptables`
- `paqet`

## License
This project is licensed under the **MIT License**.

## Credits
- **[paqet](https://github.com/hanselime/paqet)** – Raw packet tunneling library by hanselime
