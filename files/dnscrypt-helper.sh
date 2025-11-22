#!/bin/sh
#
# DNSCrypt Proxy Helper Script
# Provides utility functions for LuCI interface
#

CONFIG_FILE="/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
CACHE_DIR="/var/lib/dnscrypt-proxy"

# Parse TOML value (simple parser for basic values)
get_toml_value() {
	local key="$1"
	local file="${2:-$CONFIG_FILE}"
	
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
			cache_files="relays.md"
			;;
		*)
			cache_files="public-resolvers.md odoh-servers.md relays.md"
			;;
	esac
	
	for file in $cache_files; do
		if [ -f "$CACHE_DIR/$file" ]; then
			# Extract server names from markdown
			grep "^##[[:space:]]" "$CACHE_DIR/$file" | sed 's/^##[[:space:]]*//'
		fi
	done
}

# Validate configuration
validate_config() {
	/usr/sbin/dnscrypt-proxy -config "$CONFIG_FILE" -check >/dev/null 2>&1
	echo $?
}

# Get service status
get_status() {
	if /etc/init.d/dnscrypt-proxy2 running >/dev/null 2>&1; then
		echo "running"
	else
		echo "stopped"
	fi
}

# Reload resolver lists
reload_sources() {
	# Force resolver list update
	rm -f "$CACHE_DIR"/*.md "$CACHE_DIR"/*.minisig
	
	# Restart service to trigger download
	/etc/init.d/dnscrypt-proxy2 restart
	
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
	local cache_file="$CACHE_DIR/public-resolvers.md"
	
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
	fi
}

# Get statistics from log
get_stats() {
	local log_file=$(get_toml_value "log_file" | sed 's/"//g')
	
	if [ -f "$log_file" ]; then
		echo "{"
		echo "  \"queries_total\": $(grep -c "Forwarding" "$log_file" 2>/dev/null || echo 0),"
		echo "  \"queries_blocked\": $(grep -c "Blocked" "$log_file" 2>/dev/null || echo 0),"
		echo "  \"log_size\": $(stat -c%s "$log_file" 2>/dev/null || echo 0)"
		echo "}"
	else
		echo "{\"error\": \"Log file not found\"}"
	fi
}

# Test resolver
test_resolver() {
	local server="$1"
	local test_domain="${2:-cloudflare.com}"
	
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
	list_resolvers)
		list_resolvers "$2"
		;;
	validate_config)
		validate_config
		;;
	get_status)
		get_status
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
	*)
		echo "Usage: $0 {get_toml_value|get_server_names|list_resolvers|validate_config|get_status|reload_sources|export_odoh_config|...}"
		exit 1
		;;
esac
