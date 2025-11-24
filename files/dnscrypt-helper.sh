#!/bin/sh
#
# DNSCrypt Proxy Helper Script
# Provides utility functions for LuCI interface
#

CONFIG_FILE="/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
CACHE_DIR="/var/lib/dnscrypt-proxy"
INIT_SCRIPT="/etc/init.d/dnscrypt-proxy2"

# Parse TOML value (simple parser for basic values)
get_toml_value() {
	local key="$1"
	local file="${2:-$CONFIG_FILE}"
	
	if [ ! -f "$file" ]; then
		echo ""
		return 1
	fi
	
	grep "^${key}[[:space:]]*=" "$file" | head -n1 | sed 's/^[^=]*=[[:space:]]*//; s/"//g; s/'"'"'//g'
}

# Get server names as JSON array
get_server_names() {
	local servers=$(get_toml_value "server_names")
	echo "$servers"
}

# Get listen addresses
get_listen_addresses() {
	local addrs=$(get_toml_value "listen_addresses")
	echo "$addrs"
}

# Check if ODoH is enabled
is_odoh_enabled() {
	local odoh=$(get_toml_value "odoh_servers")
	[ "$odoh" = "true" ] && echo "1" || echo "0"
}

# Check if anonymization is enabled
is_anonymization_enabled() {
	local anon=$(get_toml_value "skip_incompatible")
	[ "$anon" = "true" ] && echo "1" || echo "0"
}

# Get protocol status
get_protocol_status() {
	local dnscrypt=$(get_toml_value "dnscrypt_servers")
	local doh=$(get_toml_value "doh_servers")
	local odoh=$(get_toml_value "odoh_servers")
	
	echo "{"
	echo "  \"dnscrypt\": $([ "$dnscrypt" = "true" ] && echo "true" || echo "false"),"
	echo "  \"doh\": $([ "$doh" = "true" ] && echo "true" || echo "false"),"
	echo "  \"odoh\": $([ "$odoh" = "true" ] && echo "true" || echo "false")"
	echo "}"
}

# List available resolvers from cache
list_resolvers() {
	local type="${1:-all}"
	local cache_files=""
	
	case "$type" in
		dnscrypt)
			cache_files="public-resolvers.md"
			;;
		doh)
			cache_files="public-resolvers.md"
			;;
		odoh)
			cache_files="odoh-servers.md"
			;;
		relays)
			cache_files="relays.md odoh-relays.md"
			;;
		*)
			cache_files="public-resolvers.md odoh-servers.md relays.md odoh-relays.md"
			;;
	esac
	
	for file in $cache_files; do
		if [ -f "$CACHE_DIR/$file" ]; then
			# Extract server names from markdown
			grep "^##[[:space:]]" "$CACHE_DIR/$file" | sed 's/^##[[:space:]]*//'
		fi
	done
}

# Count resolvers in cache
count_resolvers() {
	local type="${1:-all}"
	list_resolvers "$type" | wc -l
}

# Validate configuration
validate_config() {
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "2"
		return 2
	fi
	
	if [ ! -x "/usr/sbin/dnscrypt-proxy" ]; then
		echo "3"
		return 3
	fi
	
	/usr/sbin/dnscrypt-proxy -config "$CONFIG_FILE" -check >/dev/null 2>&1
	local ret=$?
	echo "$ret"
	return $ret
}

# Get service status
get_status() {
	if [ ! -x "$INIT_SCRIPT" ]; then
		echo "unavailable"
		return 1
	fi
	
	if "$INIT_SCRIPT" running >/dev/null 2>&1; then
		echo "running"
	else
		echo "stopped"
	fi
}

# Get service info (JSON)
get_service_info() {
	local status=$(get_status)
	local pid=$(pidof dnscrypt-proxy 2>/dev/null)
	local uptime=0
	
	if [ -n "$pid" ] && [ -f "/proc/$pid/stat" ]; then
		local starttime=$(awk '{print $22}' /proc/$pid/stat)
		local hz=100
		local sys_uptime=$(awk '{print $1}' /proc/uptime)
		uptime=$(awk -v st="$starttime" -v hz="$hz" -v su="$sys_uptime" 'BEGIN{printf "%.0f", su - (st/hz)}')
	fi
	
	echo "{"
	echo "  \"status\": \"$status\","
	echo "  \"pid\": ${pid:-0},"
	echo "  \"uptime\": $uptime"
	echo "}"
}

# Reload resolver lists
reload_sources() {
	# Force resolver list update
	rm -f "$CACHE_DIR"/*.md "$CACHE_DIR"/*.minisig 2>/dev/null
	
	# Check if service is available
	if [ ! -x "$INIT_SCRIPT" ]; then
		echo "error"
		return 1
	fi
	
	# Restart service to trigger download
	"$INIT_SCRIPT" restart >/dev/null 2>&1
	
	# Wait for cache files
	local timeout=30
	while [ $timeout -gt 0 ]; do
		if [ -f "$CACHE_DIR/public-resolvers.md" ]; then
			echo "success"
			return 0
		fi
		sleep 1
		timeout=$((timeout - 1))
	done
	
	echo "timeout"
	return 1
}

# Get resolver details by name
get_resolver_info() {
	local name="$1"
	local cache_files="$CACHE_DIR/public-resolvers.md $CACHE_DIR/odoh-servers.md"
	
	for cache_file in $cache_files; do
		if [ -f "$cache_file" ]; then
			awk -v name="$name" '
				/^## / { 
					current=$0; 
					sub(/^## /, "", current); 
					printing=(current==name) 
				}
				printing && /^##/ && !/^## / { exit }
				printing { print }
			' "$cache_file"
			
			# If found, exit
			[ $? -eq 0 ] && return 0
		fi
	done
}

# Get statistics from log
get_stats() {
	local log_file=$(get_toml_value "log_file" | sed 's/"//g; s/'"'"'//g')
	
	if [ -z "$log_file" ]; then
		log_file="/var/log/dnscrypt-proxy.log"
	fi
	
	if [ -f "$log_file" ]; then
		local queries=$(grep -c "Forwarding" "$log_file" 2>/dev/null || echo 0)
		local blocked=$(grep -c "Blocked" "$log_file" 2>/dev/null || echo 0)
		local size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
		
		echo "{"
		echo "  \"queries_total\": $queries,"
		echo "  \"queries_blocked\": $blocked,"
		echo "  \"log_size\": $size"
		echo "}"
	else
		echo "{\"error\": \"Log file not found\"}"
	fi
}

# Test resolver
test_resolver() {
	local server="$1"
	local test_domain="${2:-cloudflare.com}"
	
	if [ ! -x "/usr/sbin/dnscrypt-proxy" ]; then
		echo "Error: dnscrypt-proxy binary not found"
		return 1
	fi
	
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "Error: configuration file not found"
		return 1
	fi
	
	/usr/sbin/dnscrypt-proxy \
		-config "$CONFIG_FILE" \
		-resolve "$test_domain" \
		-server "$server" 2>&1
}

# Export ODoH configuration snippet
export_odoh_config() {
	cat <<-'EOF'
	# ODoH Configuration
	odoh_servers = true
	
	[anonymized_dns]
	routes = [
	  { server_name='odoh-*', via=['odohrelay-*'] }
	]
	skip_incompatible = true
	
	[sources.odoh-servers]
	urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md']
	cache_file = 'odoh-servers.md'
	minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
	refresh_delay = 72
	
	[sources.odoh-relays]
	urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-relays.md']
	cache_file = 'odoh-relays.md'
	minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
	refresh_delay = 72
	EOF
}

# Check system requirements
check_requirements() {
	local missing=""
	
	[ ! -f "$CONFIG_FILE" ] && missing="$missing config"
	[ ! -x "/usr/sbin/dnscrypt-proxy" ] && missing="$missing binary"
	[ ! -x "$INIT_SCRIPT" ] && missing="$missing init-script"
	[ ! -d "$CACHE_DIR" ] && missing="$missing cache-dir"
	
	if [ -n "$missing" ]; then
		echo "missing:$missing"
		return 1
	fi
	
	echo "ok"
	return 0
}

# Main command dispatcher
case "$1" in
	get_toml_value)
		get_toml_value "$2" "$3"
		;;
	get_server_names)
		get_server_names
		;;
	get_listen_addresses)
		get_listen_addresses
		;;
	is_odoh_enabled)
		is_odoh_enabled
		;;
	is_anonymization_enabled)
		is_anonymization_enabled
		;;
	get_protocol_status)
		get_protocol_status
		;;
	list_resolvers)
		list_resolvers "$2"
		;;
	count_resolvers)
		count_resolvers "$2"
		;;
	validate_config)
		validate_config
		;;
	get_status)
		get_status
		;;
	get_service_info)
		get_service_info
		;;
	reload_sources)
		reload_sources
		;;
	get_resolver_info)
		get_resolver_info "$2"
		;;
	get_stats)
		get_stats
		;;
	test_resolver)
		test_resolver "$2" "$3"
		;;
	export_odoh_config)
		export_odoh_config
		;;
	check_requirements)
		check_requirements
		;;
	*)
		echo "Usage: $0 {get_toml_value|get_server_names|list_resolvers|validate_config|get_status|reload_sources|check_requirements|...}"
		exit 1
		;;
esac
