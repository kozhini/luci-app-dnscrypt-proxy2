-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

m = SimpleForm("dnscrypt-proxy", translate("DNSCrypt Proxy - Overview"))
m.submit = translate("Save & Apply")
m.reset = false

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
local helper = "/usr/libexec/dnscrypt-proxy/helper"

-- Handle action requests before form rendering
local action = luci.http.formvalue("action")
if action == "validate" then
	local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
	if code == 0 then
		m.message = translate("✓ Configuration is valid")
	else
		m.errmessage = translate("✗ Configuration has errors")
	end
elseif action == "reload_sources" then
	sys.call(helper .. " reload_sources >/dev/null 2>&1 &")
	m.message = translate("✓ Resolver lists update started (1-2 min)")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
end

-- Service Status Section
s = m:section(SimpleSection, nil, translate("Service Status"))

local running = (sys.call("pidof dnscrypt-proxy >/dev/null") == 0)
local status_text = running and translate("Running") or translate("Stopped")
local status_color = running and "green" or "red"

o = s:option(DummyValue, "_status", translate("Status"))
o.rawhtml = true
o.value = string.format('<strong style="color: %s">%s</strong>', status_color, status_text)

if running then
	local pid = sys.exec("pidof dnscrypt-proxy"):match("%d+")
	if pid then
		o = s:option(DummyValue, "_pid", translate("PID"))
		o.value = pid
		
		local mem = sys.exec(string.format("cat /proc/%s/status 2>/dev/null | grep VmRSS | awk '{print $2}'", pid)):gsub("%s+", "")
		if mem and mem ~= "" and tonumber(mem) then
			o = s:option(DummyValue, "_memory", translate("Memory Usage"))
			o.value = string.format("%.2f MB", tonumber(mem) / 1024)
		end
	end
end

-- Service Control Buttons
o = s:option(Button, "_start", translate("Start"))
o.inputstyle = "apply"
o.disabled = running
function o.write()
	sys.call("/etc/init.d/dnscrypt-proxy2 start >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
end

o = s:option(Button, "_stop", translate("Stop"))
o.inputstyle = "reset"
o.disabled = not running
function o.write()
	sys.call("/etc/init.d/dnscrypt-proxy2 stop >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
end

o = s:option(Button, "_restart", translate("Restart"))
o.inputstyle = "reload"
o.disabled = not running
function o.write()
	sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
end

-- Basic Configuration Section
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found") .. '</span>'
	return m
end

s = m:section(SimpleSection, nil, translate("Basic Configuration"))

-- Parse TOML helper function
local function parse_toml_array(content, key)
	-- Match single-line array
	local single = content:match(key .. "%s*=%s*(%b[])")
	if single then
		local items = {}
		for item in single:gmatch("'([^']+)'") do
			table.insert(items, item)
		end
		for item in single:gmatch('"([^"]+)"') do
			table.insert(items, item)
		end
		return items
	end
	
	-- Match multi-line array with comments
	local pattern = key .. "%s*=%s*%[(.-)%]"
	local array_str = content:match(pattern)
	
	if array_str then
		local items = {}
		-- Remove comments and extract quoted strings
		for line in array_str:gmatch("[^\n]+") do
			-- Remove inline comments
			line = line:gsub("#.-$", "")
			-- Extract quoted strings
			for item in line:gmatch("'([^']+)'") do
				table.insert(items, item)
			end
			for item in line:gmatch('"([^"]+)"') do
				table.insert(items, item)
			end
		end
		return items
	end
	
	return {}
end

local content = fs.readfile(config_file)

-- Listen Addresses
o = s:option(DynamicList, "listen_addresses", translate("Listen Addresses"),
	translate("Local addresses where DNSCrypt proxy will listen for DNS queries"))
o.placeholder = "127.0.0.1:53"
o.rmempty = false

local current_addrs = parse_toml_array(content, "listen_addresses")
function o.cfgvalue(self, section)
	return current_addrs
end

o = s:option(DummyValue, "_listen_help", "")
o.rawhtml = true
o.value = [[
<div style="margin: 5px 0; padding: 8px; background: #f0f0f0; border-left: 3px solid #5bc0de;">
	<strong>💡 Examples:</strong><br/>
	• <code>127.0.0.1:53</code> - IPv4 localhost<br/>
	• <code>[::1]:53</code> - IPv6 localhost<br/>
	• <code>0.0.0.0:53</code> - All interfaces (LAN access)<br/>
	• <code>192.168.1.1:53</code> - Specific IP
</div>
]]

-- Server Selection
s = m:section(SimpleSection, nil, translate("Server Selection"))

o = s:option(DummyValue, "_server_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>🌐 DNS Servers:</strong> Select specific servers or leave empty for automatic selection.
</div>
]]

-- Get available resolvers
local cache_dir = "/var/lib/dnscrypt-proxy"
local available_servers = {}

if fs.access(cache_dir .. "/public-resolvers.md") then
	local resolvers_md = fs.readfile(cache_dir .. "/public-resolvers.md")
	if resolvers_md then
		for server in resolvers_md:gmatch("\n## ([^\n]+)") do
			table.insert(available_servers, {name = server, type = "DNSCrypt/DoH"})
		end
	end
end

if fs.access(cache_dir .. "/odoh-servers.md") then
	local odoh_md = fs.readfile(cache_dir .. "/odoh-servers.md")
	if odoh_md then
		for server in odoh_md:gmatch("\n## ([^\n]+)") do
			table.insert(available_servers, {name = server, type = "ODoH"})
		end
	end
end

local current_servers = parse_toml_array(content, "server_names")

if #available_servers > 0 then
	o = s:option(DynamicList, "server_names", translate("DNS Servers"),
		translate("Select specific servers or leave empty for automatic selection"))
	o.placeholder = translate("Leave empty for auto-selection")
	
	for _, srv in ipairs(available_servers) do
		o:value(srv.name, srv.name .. " (" .. srv.type .. ")")
	end
	
	function o.cfgvalue(self, section)
		return current_servers
	end
	
	o = s:option(DummyValue, "_current_servers", translate("Currently Selected"))
	if #current_servers > 0 then
		local display_list = {}
		for i, srv in ipairs(current_servers) do
			if i <= 3 then
				table.insert(display_list, srv)
			end
		end
		local display = table.concat(display_list, ", ")
		if #current_servers > 3 then
			display = display .. " (+" .. (#current_servers - 3) .. " more)"
		end
		o.value = string.format("%d servers: %s", #current_servers, display)
	else
		o.value = translate("Auto-selection (all available)")
	end
else
	o = s:option(DummyValue, "_no_servers", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No servers in cache. Click 'Update Resolver Lists' below.") ..
		'</div>'
end

-- Quick toggles
s = m:section(SimpleSection, nil, translate("Quick Settings"))

local function get_bool(key)
	return content:match(key .. "%s*=%s*true") and "1" or "0"
end

o = s:option(Flag, "require_dnssec", translate("Require DNSSEC"),
	translate("Only use servers that support DNSSEC"))
o.default = get_bool("require_dnssec")
o.rmempty = false

o = s:option(Flag, "require_nolog", translate("Require No Logging"),
	translate("Only use servers that don't log queries"))
o.default = get_bool("require_nolog")
o.rmempty = false

o = s:option(Flag, "require_nofilter", translate("Require No Filtering"),
	translate("Only use servers without content filtering"))
o.default = get_bool("require_nofilter")
o.rmempty = false

-- Statistics
s = m:section(SimpleSection, nil, translate("Statistics"))

local log_file = "/var/log/dnscrypt-proxy.log"
if fs.access(log_file) then
	local queries = tonumber(sys.exec(string.format("grep -c 'Forwarding' %s 2>/dev/null || echo 0", log_file)):gsub("%s+", "")) or 0
	local blocked = tonumber(sys.exec(string.format("grep -c 'Blocked' %s 2>/dev/null || echo 0", log_file)):gsub("%s+", "")) or 0
	
	o = s:option(DummyValue, "_queries", translate("Total Queries"))
	o.value = tostring(queries)
	
	o = s:option(DummyValue, "_blocked", translate("Blocked Queries"))
	o.value = tostring(blocked)
	
	if queries > 0 then
		o = s:option(DummyValue, "_block_rate", translate("Block Rate"))
		o.value = string.format("%.2f%%", (blocked / queries) * 100)
	end
	
	local log_size = fs.stat(log_file, "size") or 0
	o = s:option(DummyValue, "_log_size", translate("Log Size"))
	o.value = string.format("%.2f MB", log_size / 1024 / 1024)
end

-- Resolver Sources
s = m:section(SimpleSection, nil, translate("Resolver Sources"))

local sources = {
	{name = "public-resolvers.md", desc = "Public Resolvers"},
	{name = "relays.md", desc = "Anonymization Relays"},
	{name = "odoh-servers.md", desc = "ODoH Servers"},
	{name = "odoh-relays.md", desc = "ODoH Relays"}
}

for _, src in ipairs(sources) do
	local path = cache_dir .. "/" .. src.name
	if fs.access(path) then
		local mtime = fs.stat(path, "mtime")
		if mtime then
			local age = os.time() - mtime
			local age_str
			
			if age < 3600 then
				age_str = string.format("%d min ago", math.floor(age / 60))
			elseif age < 86400 then
				age_str = string.format("%d hours ago", math.floor(age / 3600))
			else
				age_str = string.format("%d days ago", math.floor(age / 86400))
			end
			
			o = s:option(DummyValue, "_src_" .. src.name, translate(src.desc))
			o.value = age_str
		end
	end
end

-- Action buttons with proper CSRF token
o = s:option(DummyValue, "_action_buttons", "")
o.rawhtml = true

local token = luci.dispatcher.build_form_token()
local current_url = luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview")

o.value = string.format([[
<div style="margin: 10px 0;">
	<form method="post" action="%s" style="display: inline-block; margin-right: 10px;">
		<input type="hidden" name="token" value="%s"/>
		<input type="hidden" name="action" value="validate"/>
		<input type="submit" class="cbi-button cbi-button-reload" value="%s"/>
	</form>
	
	<form method="post" action="%s" style="display: inline-block;">
		<input type="hidden" name="token" value="%s"/>
		<input type="hidden" name="action" value="reload_sources"/>
		<input type="submit" class="cbi-button cbi-button-reload" value="%s"/>
	</form>
</div>
]], current_url, token, translate("Validate Configuration"),
    current_url, token, translate("Update Resolver Lists"))

-- Form submission handler
function m.handle(self, state, data)
	if state == FORM_VALID then
		local new_content = content
		
		-- Update listen_addresses
		if data.listen_addresses then
			local addrs = type(data.listen_addresses) == "table" and data.listen_addresses or {data.listen_addresses}
			local addr_str = "listen_addresses = ['" .. table.concat(addrs, "', '") .. "']"
			new_content = new_content:gsub("listen_addresses%s*=%s*%b[]", addr_str)
		end
		
		-- Update server_names
		if data.server_names then
			local servers = type(data.server_names) == "table" and data.server_names or {data.server_names}
			
			local server_str
			if #servers == 0 then
				server_str = "server_names = []"
			else
				-- Preserve multi-line formatting
				server_str = "server_names = [\n"
				for i, srv in ipairs(servers) do
					server_str = server_str .. "  '" .. srv .. "'"
					if i < #servers then
						server_str = server_str .. ","
					end
					server_str = server_str .. "\n"
				end
				server_str = server_str .. "]"
			end
			
			-- Match multi-line or single-line arrays
			local pattern = "server_names%s*=%s*%b[]"
			new_content = new_content:gsub(pattern, function(match)
				return server_str
			end)
		end
		
		-- Update boolean flags
		local function update_bool(key, value)
			local bool_val = (value == "1") and "true" or "false"
			new_content = new_content:gsub(key .. "%s*=%s*%a+", key .. " = " .. bool_val)
		end
		
		update_bool("require_dnssec", data.require_dnssec or "0")
		update_bool("require_nolog", data.require_nolog or "0")
		update_bool("require_nofilter", data.require_nofilter or "0")
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", content)
		fs.writefile(config_file, new_content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = translate("✓ Configuration saved successfully!")
			
			-- Add restart button
			s = self:section(SimpleSection)
			o = s:option(Button, "_do_restart", translate("Restart Service Now"))
			o.inputstyle = "apply"
			function o.write()
				sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
				luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
			end
		else
			self.errmessage = translate("✗ Validation failed! Restoring backup...")
			fs.writefile(config_file, content)
		end
	end
	return true
end

-- Quick Links
s = m:section(SimpleSection, nil, translate("Advanced Configuration"))

o = s:option(DummyValue, "_links", "")
o.rawhtml = true
o.value = [[
<ul style="columns: 2; -webkit-columns: 2; -moz-columns: 2;">
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "protocols") .. [[">Protocol Settings</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh") .. [[">ODoH Configuration</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "resolvers") .. [[">Resolver Management</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "filters") .. [[">Filtering Rules</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. [[">View Logs</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "toml") .. [[">Edit TOML</a></li>
</ul>
]]

return m
