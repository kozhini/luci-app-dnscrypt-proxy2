# DNSCrypt Proxy LuCI Support for OpenWrt

[![Build Status](https://github.com/kozhini/luci-app-dnscrypt-proxy2/workflows/Build%20luci-app-dnscrypt-proxy2%20for%20OpenWrt/ImmortalWrt/badge.svg)](https://github.com/kozhini/luci-app-dnscrypt-proxy2/actions)

LuCI web interface for [DNSCrypt Proxy Version 2][DNSCRYPTV2] on OpenWrt/ImmortalWrt routers.

## Features

- 🎯 **Full DNS Privacy**: DNSCrypt and DNS-over-HTTPS (DoH) protocol support
- 🔧 **Complete Configuration**: Web UI for all dnscrypt-proxy2 options
- 📋 **Resolver Management**: Browse, filter and manage DNS resolvers
- 🔒 **Security Features**: DNSSEC validation, domain/IP blocking lists
- 🚀 **Performance**: Caching, load balancing, connection reuse
- 🌐 **Resolver Lists**: Auto-update from official dnscrypt.info sources

## Requirements

### Minimum OpenWrt/ImmortalWrt versions:
- **OpenWrt**: 21.02+ (tested on 23.05, 24.10)
- **ImmortalWrt**: 21.02+

### Dependencies (auto-installed):
- `dnscrypt-proxy2` - Main daemon package
- `luci-compat` - **Required for Lua-based LuCI apps on OpenWrt 19.07+**
- `luci-lib-ip` - IP address library
- `minisign` - Optional, for custom resolver list signing

## Installation

### Method 1: Pre-built IPK packages (Recommended)

Download from [Releases](https://github.com/kozhini/luci-app-dnscrypt-proxy2/releases) page:

```bash
# Install all packages
opkg update
opkg install dnscrypt-proxy2_*.ipk
opkg install luci-app-dnscrypt-proxy2_*.ipk
opkg install minisign_*.ipk  # optional

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### Method 2: Build from source

#### Prerequisites

Install dependencies on Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y build-essential gawk git python3 \
    python3-setuptools rsync unzip wget xz-utils zstd
```

#### Download OpenWrt SDK

```bash
# For OpenWrt 24.10, mediatek/filogic target
wget https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/openwrt-sdk-24.10.0-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.xz

# Extract SDK
tar -xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*/
```

#### Build Package

```bash
# Update feeds
./scripts/feeds update -a

# Install dependencies
./scripts/feeds install dnscrypt-proxy2 minisign luci-compat luci-lib-ip

# Clone this repository
git clone https://github.com/kozhini/luci-app-dnscrypt-proxy2.git package/luci-app-dnscrypt-proxy2

# Select package in menuconfig
make menuconfig
# Navigate to: LuCI -> 3. Applications -> luci-app-dnscrypt-proxy2
# Enable with <Y> or <M>

# Compile
make package/luci-app-dnscrypt-proxy2/compile V=s

# Find built packages
find bin/ -name "*dnscrypt*.ipk"
```

### Method 3: Automated GitHub Actions build

Fork this repository and use GitHub Actions workflow to build for your target:

1. Go to **Actions** tab
2. Select **"Build luci-app-dnscrypt-proxy2"** workflow
3. Click **"Run workflow"**
4. Select your options:
   - Firmware type: OpenWrt or ImmortalWrt
   - Version: 24.10.0, 23.05.5, SNAPSHOT, etc.
   - Target/Subtarget/Architecture for your device
5. Download built packages from Release assets

## Configuration

### Access Web Interface

After installation, navigate to:
- **LuCI** → **Services** → **DNSCrypt Proxy**

### Quick Start

1. **Overview Tab**: 
   - Enable DNSCrypt Proxy service
   - Set listening address (default: `127.0.0.1:5335`)

2. **Resolvers Tab**:
   - Browse available DNS resolvers
   - Filter by country, protocol, features
   - Select resolvers for use

3. **Configure dnsmasq** (to use DNSCrypt):
   ```bash
   # Network → DHCP and DNS → DNS forwardings
   # Add: 127.0.0.1#5335
   
   # Or via CLI:
   uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5335'
   uci commit dhcp
   /etc/init.d/dnsmasq restart
   ```

4. **Verify**:
   - Check logs in **Services** → **DNSCrypt Proxy** → **Log**
   - Test DNS: `nslookup google.com 127.0.0.1 -port=5335`

## Advanced Features

### Resolver Lists

Update resolver lists from official sources:
- `public-resolvers` - Public DoH/DNSCrypt servers
- `onion-services` - Tor network DNS
- `opennic` - Alternative DNS root

### Filtering

- **Domain blocking**: Block ads, malware, tracking domains
- **IP blocking**: Block responses from malicious IP ranges
- **Whitelists**: Allow specific domains through filters
- **Cloaking**: Return custom IPs for specific domains

### Load Balancing

Automatically select fastest servers using strategies:
- `p2` (default) - Select 2 fastest, prefer first
- `ph` - Random among half fastest servers
- `first` - Always use first working server
- `random` - Random selection

## Troubleshooting

### Service won't start

```bash
# Check logs
logread | grep dnscrypt

# Test configuration
dnscrypt-proxy -config /var/etc/dnscrypt-proxy-ns1.conf -check
```

### No resolvers available

```bash
# Force update resolver lists
/etc/init.d/dnscrypt-proxy_resolvers update public-resolvers

# Check cache directory
ls -la /usr/share/dnscrypt-proxy/
```

### LuCI interface not appearing

```bash
# Clear LuCI cache
rm -rf /tmp/luci-*

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## Compatibility Notes

### OpenWrt 24.10+
✅ Fully supported with `luci-compat` dependency

### OpenWrt 23.05
✅ Fully supported

### OpenWrt 22.03
✅ Supported (may need manual `luci-compat` installation)

### OpenWrt 21.02 and older
⚠️ May work but not tested. Consider upgrading.

## Links

- [DNSCrypt Proxy Official](https://github.com/DNSCrypt/dnscrypt-proxy)
- [Public Resolvers List](https://dnscrypt.info/public-servers)
- [OpenWrt Documentation](https://openwrt.org/docs/start)
- [Report Issues](https://github.com/kozhini/luci-app-dnscrypt-proxy2/issues)

## License

GPLv3 - See [LICENSE](LICENSE) file

## Credits

- Original author: peter-tank
- Current maintainer: kozhini
- Based on: [DNSCrypt Proxy](https://github.com/DNSCrypt/dnscrypt-proxy) by Frank Denis

---

**⚠️ Security Note**: This package disables SSL certificate verification in some wget operations for compatibility. For production use, consider implementing proper certificate validation.
