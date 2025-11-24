-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("dnscrypt-filters", translate("DNSCrypt Proxy - Filtering Rules"),
	translate("Configure domain and IP filtering lists"))

m.submit = translate("Save")
m.reset = translate("Reset")

local base_dir = "/etc/dnscrypt-proxy2"

-- Check if directory exists
if not fs.access(base_dir) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration directory not found") .. '</span>'
	return m
end

-- Info section
s = m:section(SimpleSection, nil, translate("About Filtering"))
o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>ℹ️ Filtering Options:</strong>
	<ul>
		<li><strong>Blocked Names:</strong> Domain blacklist (e.g., ads, tracking, malware)</li>
		<li><strong>Allowed Names:</strong> Domain whitelist (bypasses blocking)</li>
		<li><strong>Blocked IPs:</strong> IP address blacklist</li>
		<li><strong>Cloaking Rules:</strong> Custom DNS responses (domain → IP mapping)</li>
		<li><strong>Forwarding Rules:</strong> Route specific domains to specific DNS servers</li>
	</ul>
	<p><strong>Format:</strong> One entry per line. Lines starting with # are comments.</p>
</div>
]]

-- Blocked Names
s = m:section(SimpleSection, nil, translate("Blocked Names"))
o = s:option(TextValue, "blocked_names")
o.rows = 10
o.wrap = "off"
o.description = translate("Block queries for these domain names. One domain per line. Supports wildcards: *.example.com")

local blocked_file = base_dir .. "/blocked-names.txt"
function o.cfgvalue(self, section)
	if fs.access(blocked_file) then
		return fs.readfile(blocked_file)
	end
	return "# Blocked domains - one per line\n# Example:\n# ads.example.com\n# *.tracker.com\n"
end

function o.write(self, section, value)
	if value then
		fs.writefile(blocked_file, value:gsub("\r\n", "\n"))
	end
end

-- Allowed Names
s = m:section(SimpleSection, nil, translate("Allowed Names (Whitelist)"))
o = s:option(TextValue, "allowed_names")
o.rows = 10
o.wrap = "off"
o.description = translate("Whitelist - these domains bypass all blocking rules")

local allowed_file = base_dir .. "/allowed-names.txt"
function o.cfgvalue(self, section)
	if fs.access(allowed_file) then
		return fs.readfile(allowed_file)
	end
	return "# Allowed domains (whitelist)\n# Example:\n# important.example.com\n"
end

function o.write(self, section, value)
	if value then
		fs.writefile(allowed_file, value:gsub("\r\n", "\n"))
	end
end

-- Blocked IPs
s = m:section(SimpleSection, nil, translate("Blocked IP Addresses"))
o = s:option(TextValue, "blocked_ips")
o.rows = 10
o.wrap = "off"
o.description = translate("Block responses containing these IP addresses or ranges")

local blocked_ips_file = base_dir .. "/blocked-ips.txt"
function o.cfgvalue(self, section)
	if fs.access(blocked_ips_file) then
		return fs.readfile(blocked_ips_file)
	end
	return "# Blocked IPs - one per line\n# Supports CIDR notation\n# Example:\n# 192.168.1.100\n# 10.0.0.0/8\n"
end

function o.write(self, section, value)
	if value then
		fs.writefile(blocked_ips_file, value:gsub("\r\n", "\n"))
	end
end

-- Cloaking Rules
s = m:section(SimpleSection, nil, translate("Cloaking Rules"))
o = s:option(TextValue, "cloaking_rules")
o.rows = 10
o.wrap = "off"
o.description = translate("Map domains to specific IP addresses. Format: domain IP")

local cloaking_file = base_dir .. "/cloaking-rules.txt"
function o.cfgvalue(self, section)
	if fs.access(cloaking_file) then
		return fs.readfile(cloaking_file)
	end
	return "# Cloaking rules - custom DNS responses\n# Format: domain IP\n# Example:\n# router.local 192.168.1.1\n# nas.local 192.168.1.100\n"
end

function o.write(self, section, value)
	if value then
		fs.writefile(cloaking_file, value:gsub("\r\n", "\n"))
	end
end

-- Forwarding Rules
s = m:section(SimpleSection, nil, translate("Forwarding Rules"))
o = s:option(TextValue, "forwarding_rules")
o.rows = 10
o.wrap = "off"
o.description = translate("Forward specific domains to specific DNS servers. Format: domain server_ip[:port]")

local forwarding_file = base_dir .. "/forwarding-rules.txt"
function o.cfgvalue(self, section)
	if fs.access(forwarding_file) then
		return fs.readfile(forwarding_file)
	end
	return "# Forwarding rules - route domains to specific DNS\n# Format: domain server_ip[:port]\n# Example:\n# local.lan 192.168.1.1\n# company.internal 10.0.0.1:53\n"
end

function o.write(self, section, value)
	if value then
		fs.writefile(forwarding_file, value:gsub("\r\n", "\n"))
	end
end

-- Update TOML to enable filters
function m.handle(self, state, data)
	if state == FORM_VALID then
		local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
		if fs.access(config_file) then
			local content = fs.readfile(config_file)
			
			-- Enable filter sections in TOML
			local filters_config = {
				{section = "blocked_names", file = "blocked_names_file = '/etc/dnscrypt-proxy2/blocked-names.txt'"},
				{section = "allowed_names", file = "allowed_names_file = '/etc/dnscrypt-proxy2/allowed-names.txt'"},
				{section = "blocked_ips", file = "blocked_ips_file = '/etc/dnscrypt-proxy2/blocked-ips.txt'"},
				{section = "cloaking_rules", file = "cloaking_rules_file = '/etc/dnscrypt-proxy2/cloaking-rules.txt'"},
				{section = "forwarding_rules", file = "forwarding_rules_file = '/etc/dnscrypt-proxy2/forwarding-rules.txt'"}
			}
			
			for _, filter in ipairs(filters_config) do
				-- Uncomment filter lines
				content = content:gsub("\n# (" .. filter.file .. ")", "\n%1")
			end
			
			fs.writefile(config_file, content)
		end
		
		self.message = translate("Filter rules saved. Restart service to apply changes.")
		
		-- Offer restart
		s = self:section(SimpleSection)
		o = s:option(DummyValue, "_restart_info", "")
		o.rawhtml = true
		o.value = [[
		<form method="post" action="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "filters") .. [[">
			<input type="hidden" name="action" value="restart"/>
			<input type="submit" class="cbi-button cbi-button-apply" value="]] .. translate("Restart Service") .. [["/>
		</form>
		]]
	end
	return true
end

-- Handle restart
local action = luci.http.formvalue("action")
if action == "restart" then
	sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
	m.message = translate("Service restarted")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "filters"))
end

return m
