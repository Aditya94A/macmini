# macmini — Home Server Projects

Mac Mini (Apple M4, macOS, 192.168.1.218) running self-hosted services.

---

## Network Topology

```
Internet
    │
    ▼
[ BE400 Router ]  192.168.0.1   pw: 123aditya
    │  LAN: 192.168.0.x
    │  ├── IoT / cameras (192.168.0.123, 192.168.0.39)
    │  ├── Kanchan's iPhone (192.168.0.25)
    │  └── AX12 WAN port (192.168.0.238)
    ▼
[ ArcherAX12 Router ]  192.168.1.1   pw: 123aditya
    │  LAN: 192.168.1.x
    │  ├── Mac Mini (192.168.1.218)  ← this machine
    │  ├── Aditya's iPhone (192.168.1.205)
    │  └── Windows PC (192.168.1.142)
```

---

## Mac Mini Access

```bash
ssh adi@192.168.1.218        # password: 123aditya!@#
```

---

## Running Services

| Service | URL | Credentials |
|---|---|---|
| Frigate NVR | http://192.168.1.218:5000 | admin / 65f9a26e8ef69783f973927885682569 |
| AdGuard Home | http://192.168.1.218:3000 | admin / 123aditya!@# |

---

## Projects

### 1. Frigate NVR (`frigate/`)

Network video recorder for 2 cameras. Runs in Docker via Colima.

**Cameras:**
- `front` — 192.168.0.123 (rtsp://AdiCam99:123aditya123@192.168.0.123/stream1+stream2)
- `back` — 192.168.0.39 (rtsp://AdiCam99:123aditya123@192.168.0.39/stream1+stream2)

**Stream strategy:** stream2 (640×360) for detect, stream1 (2.5K) for high-res review via go2rtc

**Storage:** `~/frigate-data/` on Mac Mini (not in repo)
- 7-day rolling recordings (motion segments), 14-day event clips
- ~0.7 GB/day at 360p recording

**Deploy/update:**
```bash
bash frigate/deploy.sh
```

---

### 2. AdGuard Home (native, not Docker)

Network-wide DNS ad-blocker for both subnets. Installed at `/Applications/AdGuardHome/`.

**DNS routing:**
- AX12 devices (192.168.1.x) → DNS direct to 192.168.1.218:53
- BE400 devices (192.168.0.x) → DNS to 192.168.0.238:53 → port-forwarded to 192.168.1.218:53

**Active blocklist:** OISD Small (57k rules, low false-positive rate)

**Manage via API:**
```bash
# Check status
curl -s -u admin:'123aditya!@#' http://192.168.1.218:3000/control/status

# Start/stop/restart
sudo /Applications/AdGuardHome/AdGuardHome -s start|stop|restart

# View logs
sudo tail -f /var/log/AdGuardHome.stdout.log
```

---

## Fresh Setup (from scratch)

### Prerequisites on Mac Mini

```bash
# Install Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Colima + Docker
brew install colima docker docker-compose
colima start --cpu 4 --memory 4 --disk 60
mkdir -p ~/.docker/cli-plugins
ln -sf /opt/homebrew/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose
echo '{"cliPluginsExtraDirs":["/opt/homebrew/lib/docker/cli-plugins"]}' > ~/.docker/config.json

# Storage dirs
mkdir -p ~/frigate-data/{recordings,clips,cache}
mkdir -p ~/projects
```

### Clone this repo

```bash
cd ~/projects
git clone https://github.com/Aditya94A/macmini.git
```

### Deploy Frigate

```bash
cd ~/projects/macmini
bash frigate/deploy.sh
# UI → http://192.168.1.218:5000
```

### Install AdGuard Home

```bash
# Install
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sudo sh -s -- -v

# Fix RunAtLoad so it starts on boot
sudo sed -i '' 's/<key>RunAtLoad<\/key><false\/>/<key>RunAtLoad<\/key><true\/>/' /Library/LaunchDaemons/AdGuardHome.plist

# Approve through macOS firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/AdGuardHome/AdGuardHome
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/AdGuardHome/AdGuardHome

# Create sudo helper for boot script
echo '#!/bin/bash' > ~/.adg_helper.sh
echo "echo '123aditya!@#'" >> ~/.adg_helper.sh
chmod 700 ~/.adg_helper.sh
```

Complete AdGuard setup wizard at http://192.168.1.218:3000 — or via API:
```bash
# Complete wizard (use port 5335 first if port 53 is busy, then fix later)
curl -s -X POST http://localhost:3000/control/install/configure \
  -H 'Content-Type: application/json' \
  -d '{"web":{"port":3000,"ip":"0.0.0.0"},"dns":{"port":53,"ip":"0.0.0.0"},"username":"admin","password":"123aditya!@#"}'

# Configure upstream DNS + blocklist
curl -s -u admin:'123aditya!@#' -X POST http://localhost:3000/control/dns_config \
  -H 'Content-Type: application/json' \
  -d '{"upstream_dns":["https://dns.cloudflare.com/dns-query","tls://1.1.1.1"],"bootstrap_dns":["1.1.1.1","8.8.8.8"]}'

curl -s -u admin:'123aditya!@#' -X POST http://localhost:3000/control/filtering/add_url \
  -H 'Content-Type: application/json' \
  -d '{"name":"OISD Small","url":"https://small.oisd.nl/domainswild","whitelist":false}'

curl -s -u admin:'123aditya!@#' -X POST http://localhost:3000/control/filtering/config \
  -H 'Content-Type: application/json' \
  -d '{"enabled":true,"interval":24}'
```

### Router Config (one-time, manual)

**AX12 (http://192.168.1.1):**
1. Advanced → Network → Internet → DNS: `192.168.1.218` / `1.1.1.1`
2. Advanced → NAT Forwarding → Port Forwarding → Add:
   - `AdGuard-UDP`: ext 53 → 192.168.1.218:53, UDP
   - `AdGuard-TCP`: ext 53 → 192.168.1.218:53, TCP
3. Advanced → Network → LAN → DHCP Server → DNS1: `192.168.1.218`, DNS2: `1.1.1.1`

**BE400 (http://192.168.0.1):**
4. Advanced → Network → Internet → DNS: `192.168.0.238` / `1.1.1.1`
5. Advanced → Network → LAN → DHCP Server → DNS1: `192.168.0.238`, DNS2: `1.1.1.1`

### Auto-start on Boot

```bash
# Register Colima LaunchAgent (run once from Mac Mini GUI terminal)
launchctl load -w ~/Library/LaunchAgents/com.colima.start.plist
```

The `start-services.sh` script (triggered by the LaunchAgent) handles:
1. AdGuard Home (must start before Colima to win port 53)
2. FrigateDetector (optional CoreML accelerator)
3. Colima (Docker runtime)
4. Frigate (via docker compose)

---

## Rollback

**AdGuard off:**
```bash
sudo /Applications/AdGuardHome/AdGuardHome -s stop
# Then restore router DNS to 1.1.1.1 on both routers
```

**Frigate off:**
```bash
export DOCKER_HOST='unix:///Users/adi/.colima/default/docker.sock'
cd ~/projects/frigate && docker compose down
```
