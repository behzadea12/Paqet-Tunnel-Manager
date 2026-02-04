# Paqet-Tunnel-Manager
Management script for paqet: raw socket KCP-based tunnel for firewall/DPI bypass. Supports kharej server and Iran client configurations.

## Quick Start

# Install prerequisites
```bash
sudo apt update
sudo apt remove golang-go
sudo add-apt-repository ppa:longsleep/golang-backports -y
sudo apt update
sudo apt install golang-1.25-go
sudo ln -sf /usr/lib/go-1.25/bin/go /usr/bin/go
go version
```
If that doesn't work use this:
```bash
sudo rm -rf /usr/local/go
sudo rm -f /usr/bin/go  /usr/bin/gofmt
cd /tmp
wget https://go.dev/dl/go1.25.6.linux-amd64.tar.gz
# wget https://go.dev/dl/go1.25.6.linux-arm64.tar.gz
sudo tar -C /usr/local -xzf go1.25.6.linux-amd64.tar.gz
sudo ln -sf /usr/local/go/bin/go /usr/bin/go
sudo ln -sf /usr/local/go/bin/gofmt /usr/bin/gofmt
go version
```

# Run on both servers (as root)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
```
First option 1
Then config(2-3)


## Troubleshooting: Paqet Installation Issues

If Paqet fails to install automatically during configuration  
(i.e. you see "Failed to install Paqet" or the script gets stuck when adding a new config in **Server/Kharej** or **Client/Iran** mode), follow these simple steps:

1. **Manually download the Paqet binary**  

   Visit the official releases page:  
   https://github.com/hanselime/paqet/releases

   - Choose the **latest release** (currently `v1.0.0-alpha.13` or newer — always pick the most recent one).  
   - Download the file that matches your server architecture:

     - `paqet-linux-amd64-*.tar.gz` → for most 64-bit servers (x86_64 / amd64)  
     - `paqet-linux-arm64-*.tar.gz` → for ARM-based servers (aarch64 / arm64)

2. **Place the downloaded file in this exact folder**  

   Move or copy the `.tar.gz` file to:

   ```bash
   /root/paqet/
   ```
   If the folder doesn't exist, create it first:
   ```bash
    mkdir -p /root/paqet
   ```

3. Run the manager script again
   The script will automatically detect the file inside /root/paqet/, use it instead of trying to download again, extract it, and complete the installation.
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh)
   ```


If there is any problem, send a message to my Telegram ID:
@behzad_developer
