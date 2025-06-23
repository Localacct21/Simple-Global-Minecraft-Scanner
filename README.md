# 🚀 Simple Global Minecraft Scanner

Jump into the world of Minecraft network exploration with this lightweight, easy-to-use shell script. Harness the power of Masscan to scan the entire public IPv4 address space for active Minecraft servers (default port 25565), then use Nmap and Netcat (nc) for optional verification and banner grabbing.

---

## 🎯 Features

- **Global Scanning**: Uses Masscan to probe all IPv4 addresses for Minecraft servers.
- **Timestamped Output**: Automatically names result files by date/time under `global_minecraft_scan/`.
- **Configurable**: Adjust scan rate, port, and output via command-line flags.
- **Verification Tools**: Optionally verify server status with Nmap or grab banners with Netcat.
- **Bash-Only**: No external dependencies outside Masscan, Nmap, and Netcat.

---

## 📋 Prerequisites

- **Masscan** (https://github.com/robertdavidgraham/masscan) installed and in your `PATH`.
- **Nmap** (https://nmap.org/) for detailed service checks (optional).
- **Netcat** (`nc`) for banner grabbing (optional).
- **Bash** 4.0+

---

## ⚙️ Installation

```bash
# Clone this repository
git clone git@github.com:Localacct21/Simple-Global-Minecraft-Scanner.git
cd Simple-Global-Minecraft-Scanner

# Make the scanner executable
chmod +x global_minecraft_scanner.sh
```

---

## 🚀 Usage

```bash
# Run a full IPv4 scan at 1000 packets/sec
./global_minecraft_scanner.sh

# Specify a custom rate, port, or output file
./global_minecraft_scanner.sh -r 5000 -p 25565 -o my_custom_output.txt
```

All scan output will be stored in the `global_minecraft_scan/` folder as `masscan_global_<YYYYMMDD_HHMMSS>.txt`, unless overridden.

---

## 🔍 Verification & Banner Grabbing

After scanning, you can verify hosts or grab server versions:

```bash
# Use Nmap to perform a TCP banner grab
nmap -p 25565 --script minecraft-server-protocol <IP>

# Use Netcat to grab the first Minecraft handshake packet
nc <IP> 25565 | head -c 256
```

---

## 🛠️ Script Options

- `-r RATE`    Packets per second (default: 1000)
- `-p PORT`    Target port (default: 25565)
- `-o FILE`    Custom output filename (overrides timestamped name)
- `-h`         Show help message

---

## 📝 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
