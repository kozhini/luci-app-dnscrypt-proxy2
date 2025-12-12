-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

m = SimpleForm("dnscrypt-protocols", translate("DNSCrypt Proxy - Protocol Settings"),
	translate("Configure which DNS protocols to use and their settings."))

m.submit = translate("Save & Apply")
m.reset = translate("Reset")

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"

-- Check if config file exists
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found") .. '</span>'
	return m
end

-- Parse current values from TOML
local helper = "/usr/libexec/dnscrypt-proxy/helper"
local function get_bool_setting(key)
	local val = util.trim(sys.exec(string.format("%s get_toml_value %s", helper, key)))
	return (val == "true") and "1" or "0"
end

-- Protocol Selection
s = m:section(SimpleSection, nil, translate("Supported Protocols"))

o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>ℹ️ About DNS Protocols:</strong>
	<ul>
		<li><strong>DNSCrypt</strong> - Encrypted DNS using the DNSCrypt protocol (fastest)</li>
		<li><strong>DNS-over-HTTPS (DoH)</strong> - DNS queries over HTTPS (HTTP/2 or HTTP/3)</li>
		<li><strong>Oblivious DoH (ODoH)</strong> - Privacy-enhanced DoH with relays (see ODoH Settings)</li>
	</ul>
	Enable the protocols you want to use. DNSCrypt Proxy will automatically select the fastest available servers.
</div>
]]

-- Current configuration display
s = m:section(SimpleSection, nil, translate("Current Configuration"))

local dnscrypt_enabled = get_bool_setting("dnscrypt_servers")
local doh_enabled = get_bool_setting("doh_servers")
local odoh_enabled = get_bool_setting("odoh_servers")

o = s:option(DummyValue, "_current", "")
o.rawhtml = true
local status_html = "<table class='table'>"
status_html = status_html .. "<tr><th>Protocol</th><th>Status</th></tr>"
status_html = status_html .. string.format("<tr><td>DNSCrypt</td><td><strong style='color:%s'>%s</strong></td></tr>", 
	dnscrypt_enabled == "1" and "green" or "red",
	dnscrypt_enabled == "1" and "Enabled" or "Disabled")
status_html = status_html .. string.format("<tr><td>DNS-over-HTTPS (DoH)</td><td><strong style='color:%s'>%s</strong></td></tr>", 
	doh_enabled == "1" and "green" or "red",
	doh_enabled == "1" and "Enabled" or "Disabled")
status_html = status_html .. string.format("<tr><td>Oblivious DoH (ODoH)</td><td><strong style='color:%s'>%s</strong></td></tr>", 
	odoh_enabled == "1" and "green" or "red",
	odoh_enabled == "1" and "Enabled" or "Disabled")
status_html = status_html .. "</table>"
o.value = status_html

-- Edit section
s = m:section(SimpleSection, nil, translate("Protocol Configuration"))

o = s:option(Flag, "dnscrypt_servers", translate("Enable DNSCrypt Protocol"))
o.description = translate("Use servers implementing the DNSCrypt protocol. Fast and efficient.")
o.default = dnscrypt_enabled
o.rmempty = false

o = s:option(Flag, "doh_servers", translate("Enable DNS-over-HTTPS (DoH)"))
o.description = translate("Use servers implementing DNS-over-HTTPS. Works through firewalls that block DNS.")
o.default = doh_enabled
o.rmempty = false

o = s:option(Flag, "http3", translate("Enable HTTP/3 (QUIC) for DoH"))
o.description = translate("Use HTTP/3 (QUIC) transport for DoH servers. Requires DoH to be enabled.")
o.default = get_bool_setting("http3")
o.rmempty = false
o:depends("doh_servers", "1")

o = s:option(Flag, "odoh_servers", translate("Enable Oblivious DoH (ODoH)"))
o.description = translate("Use Oblivious DoH for enhanced privacy. See ODoH Settings page for relay configuration.")
o.default = odoh_enabled
o.rmempty = false

-- Network settings
s = m:section(SimpleSection, nil, translate("Network Settings"))

o = s:option(Flag, "force_tcp", translate("Force TCP"))
o.description = translate("Always use TCP to connect to upstream servers. Slower but more reliable through some firewalls.")
o.default = get_bool_setting("force_tcp")
o.rmempty = false

o = s:option(Value, "timeout", translate("Query Timeout (ms)"))
o.description = translate("How long to wait for a DNS query response, in milliseconds.")
o.default = "5000"
o.datatype = "range(1000, 30000)"
o.placeholder = "5000"

o = s:option(Value, "keepalive", translate("Keepalive (seconds)"))
o.description = translate("Keepalive for HTTP (HTTPS, HTTP/2) queries, in seconds.")
o.default = "30"
o.datatype = "range(5, 300)"
o.placeholder = "30"

-- IPv4/IPv6
s = m:section(SimpleSection, nil, translate("IP Version Settings"))

o = s:option(Flag, "ipv4_servers", translate("Use IPv4 Servers"))
o.description = translate("Use servers reachable over IPv4.")
o.default = get_bool_setting("ipv4_servers")
o.rmempty = false

o = s:option(Flag, "ipv6_servers", translate("Use IPv6 Servers"))
o.description = translate("Use servers reachable over IPv6.")
o.default = get_bool_setting("ipv6_servers")
o.rmempty = false

o = s:option(Flag, "block_ipv6", translate("Block IPv6 Queries"))
o.description = translate("Immediately respond to IPv6-related queries (AAAA) with an empty response.")
o.default = get_bool_setting("block_ipv6")
o.rmempty = false

-- Proxy settings
s = m:section(SimpleSection, nil, translate("Proxy Settings"))

o = s:option(Value, "proxy", translate("SOCKS Proxy"))
o.description = translate("Route all connections through a SOCKS proxy. Example: socks5://127.0.0.1:9050")
o.placeholder = "socks5://127.0.0.1:9050"
o.rmempty = true

o = s:option(DummyValue, "_proxy_note", "")
o.rawhtml = true
o.value = '<em style="color: #666;">Note: If using Tor, you must also enable "Force TCP" above since Tor doesn\'t support UDP.</em>'

o = s:option(Value, "http_proxy", translate("HTTP/HTTPS Proxy"))
o.description = translate("HTTP/HTTPS proxy for DoH servers only. Example: http://127.0.0.1:8888")
o.placeholder = "http://127.0.0.1:8888"
o.rmempty = true

-- Handle form submission
function m.handle(self, state, data)
	if state == FORM_VALID then
		-- Read current TOML
		local content = fs.readfile(config_file) or ""
		
		-- Update boolean values
		local function update_bool(key, value)
			local bool_val = (value == "1") and "true" or "false"
			content = content:gsub(
				"(" .. key .. "%s*=%s*)%a+",
				"%1" .. bool_val
			)
		end
		
		-- Update numeric values
		local function update_numeric(key, value)
			if value and value ~= "" then
				content = content:gsub(
					"(" .. key .. "%s*=%s*)%d+",
					"%1" .. value
				)
			end
		end
		
		-- Update string values
		local function update_string(key, value)
			if value and value ~= "" then
				content = content:gsub(
					"(" .. key .. "%s*=%s*)['\"].-['\"]",
					"%1'" .. value .. "'"
				)
			else
				-- Comment out if empty
				content = content:gsub(
					"\n(" .. key .. "%s*=.-)\n",
					"\n# %1\n"
				)
			end
		end
		
		-- Apply updates
		update_bool("dnscrypt_servers", data.dnscrypt_servers or "0")
		update_bool("doh_servers", data.doh_servers or "0")
		update_bool("http3", data.http3 or "0")
		update_bool("odoh_servers", data.odoh_servers or "0")
		update_bool("force_tcp", data.force_tcp or "0")
		update_bool("ipv4_servers", data.ipv4_servers or "0")
		update_bool("ipv6_servers", data.ipv6_servers or "0")
		update_bool("block_ipv6", data.block_ipv6 or "0")
		
		update_numeric("timeout", data.timeout)
		update_numeric("keepalive", data.keepalive)
		
		update_string("proxy", data.proxy)
		update_string("http_proxy", data.http_proxy)
		
		-- Backup and save
		local backup_file = config_file .. ".backup"
		fs.writefile(backup_file, fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = translate("Configuration saved successfully!")
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(Button, "_do_restart", translate("Restart Service Now"))
			o.inputstyle = "apply"
			function o.write()
				sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
				luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
			end
		else
			self.errmessage = translate("Configuration saved but validation failed! Restoring backup...")
			fs.writefile(config_file, fs.readfile(backup_file))
		end
		
		return true
	end
	return true
end

-- Help section
s = m:section(SimpleSection, nil, translate("Protocol Information"))

o = s:option(DummyValue, "_help", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<h4>📚 Protocol Comparison</h4>
	<table class="table">
		<tr>
			<th>Protocol</th>
			<th>Speed</th>
			<th>Privacy</th>
			<th>Firewall Bypass</th>
		</tr>
		<tr>
			<td><strong>DNSCrypt</strong></td>
			<td>★★★★★ Fastest</td>
			<td>★★★★☆ Good</td>
			<td>★★☆☆☆ May be blocked</td>
		</tr>
		<tr>
			<td><strong>DoH</strong></td>
			<td>★★★★☆ Fast</td>
			<td>★★★★☆ Good</td>
			<td>★★★★★ Works everywhere</td>
		</tr>
		<tr>
			<td><strong>DoH (HTTP/3)</strong></td>
			<td>★★★★★ Very Fast</td>
			<td>★★★★☆ Good</td>
			<td>★★★★★ Works everywhere</td>
		</tr>
		<tr>
			<td><strong>ODoH</strong></td>
			<td>★★★☆☆ Slower</td>
			<td>★★★★★ Excellent</td>
			<td>★★★★★ Works everywhere</td>
		</tr>
	</table>
	
	<h4>💡 Recommendations</h4>
	<ul>
		<li><strong>Best privacy:</strong> Enable ODoH only (configure relays in ODoH Settings)</li>
		<li><strong>Best performance:</strong> Enable DNSCrypt + DoH (automatic fallback)</li>
		<li><strong>Restricted networks:</strong> Enable DoH only (works through firewalls)</li>
		<li><strong>Balanced:</strong> Enable all protocols (default)</li>
	</ul>
</div>
]]

return m
