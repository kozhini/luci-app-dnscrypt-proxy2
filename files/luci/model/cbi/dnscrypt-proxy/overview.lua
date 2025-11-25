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
		if mem and mem ~= "" then
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
	
	-- Match multi-line array
	local multi_start = content:match(key .. "%s*=%s*%[\n")
	if multi_start then
		local start_pos = content:find(key .. "%s*=%s*%[")
		local bracket_count = 1
		local end_pos = start_pos
		
		for i = start_pos + 1, #content do
			local char = content:sub(i, i)
			if char == '[' then
				bracket_count = bracket_count + 1
			elseif char == ']' then
				bracket_count = bracket_count - 1
				if bracket_count == 0 then
					end_pos = i
					break
				end
			end
		end
		
		local array_content = content:sub(start_pos, end_pos)
		local items = {}
		for item in array_content:gmatch("'([^']+)'") do
			table.insert(items, item)
		end
		for item in array_content:gmatch('"([^"]+)"') do
			table.insert(items, item)
		end
		return items
	end
	
	return {}
end

-- Listen Addresses
o = s:option(DynamicList, "listen_addresses", translate("Listen Addresses"),
	translate("Local addresses where DNSCrypt proxy will listen for DNS queries. Default: 127.0.0.1:53"))
o.placeholder = "127.0.0.1:53"
o.rmempty = false

local content = fs.readfile(config_file)
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
	• <code>192.168.1.1:53</code> - Specific interface
</div>
]]

-- Server Selection
s = m:section(SimpleSection, nil, translate("Server Selection"))

o = s:option(DummyValue, "_server_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>🌐 DNS Servers:</strong> Select specific servers or leave empty for automatic selection based on speed and reliability.
</div>
]]

-- Get available resolvers
local cache_dir = "/var/lib/dnscrypt-proxy"
local available_servers = {}

-- Parse public resolvers
if fs.access(cache_dir .. "/public-resolvers.md") then
	local resolvers_md = fs.readfile(cache_dir .. "/public-resolvers.md")
	for server in resolvers_md:gmatch("\n## ([^\n]+)") do
		table.insert(available_servers, {name = server, type = "DNSCrypt/DoH"})
	end
end

-- Parse ODoH servers
if fs.access(cache_dir .. "/odoh-servers.md") then
	local odoh_md = fs.readfile(cache_dir .. "/odoh-servers.md")
	for server in odoh_md:gmatch("\n## ([^\n]+)") do
		table.insert(available_servers, {name = server, type = "ODoH"})
	end
end

local current_servers = parse_toml_array(content, "server_names")

if #available_servers > 0 then
	o = s:option(DynamicList, "server_names", translate("DNS Servers"),
		translate("Select specific servers or leave empty for automatic selection"))
	o.placeholder = translate("Leave empty for auto-selection")
	
	-- Create dropdown with available servers
	for _, srv in ipairs(available_servers) do
		o:value(srv.name, srv.name .. " (" .. srv.type .. ")")
	end
	
	function o.cfgvalue(self, section)
		return current_servers
	end
	
	-- Current selection display
	o = s:option(DummyValue, "_current_servers", translate("Currently Selected"))
	if #current_servers > 0 then
		o.value = string.format("%d servers: %s", #current_servers, table.concat(current_servers, ", "))
	else
		o.value = translate("Auto-selection (all available servers)")
	end
else
	o = s:option(DummyValue, "_no_servers", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No servers available in cache. Click 'Update Resolver Lists' below.") ..
		'</div>'
end

-- Quick toggles
s = m:section(SimpleSection, nil, translate("Quick Settings"))

local function get_bool(key)
	return content:match(key .. "%s*=%s*true") and "1" or "0"
end

o = s:option(Flag, "require_dnssec", translate("Require DNSSEC"),
	translate("Only use servers that support DNSSEC validation"))
o.default = get_bool("require_dnssec")

o = s:option(Flag, "require_nolog", translate("Require No Logging"),
	translate("Only use servers that don't log queries"))
o.default = get_bool("require_nolog")

o = s:option(Flag, "require_nofilter", translate("Require No Filtering"),
	translate("Only use servers without content filtering"))
o.default = get_bool("require_nofilter")

-- Statistics
s = m:section(SimpleSection, nil, translate("Statistics"))

local log_file = "/var/log/dnscrypt-proxy.log"
if fs.access(log_file) then
	local queries = tonumber(sys.exec(string.format("grep -c 'Forwarding' %s 2>/dev/null", log_file)):gsub("%s+", "")) or 0
	local blocked = tonumber(sys.exec(string.format("grep -c 'Blocked' %s 2>/dev/null", log_file)):gsub("%s+", "")) or 0
	
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
		local age = os.time() - mtime
		local age_str
		
		if age < 3600 then
			age_str = string.format("%d minutes ago", math.floor(age / 60))
		elseif age < 86400 then
			age_str = string.format("%d hours ago", math.floor(age / 3600))
		else
			age_str = string.format("%d days ago", math.floor(age / 86400))
		end
		
		o = s:option(DummyValue, "_src_" .. src.name, translate(src.desc))
		o.value = string.format("Last updated: %s", age_str)
	end
end

-- Actions
o = s:option(DummyValue, "_actions", "")
o.rawhtml = true
o.value = [[
<form method="post" style="display:inline; margin-right: 10px;">
	<input type="hidden" name="token" value="]] .. luci.dispatcher.build_form_token() .. [["/>
	<input type="hidden" name="action" value="validate"/>
	<input type="submit" class="cbi-button cbi-button-reload" value="]] .. translate("Validate Configuration") .. [["/>
</form>

<form method="post" style="display:inline;">
	<input type="hidden" name="token" value="]] .. luci.dispatcher.build_form_token() .. [["/>
	<input type="hidden" name="action" value="reload_sources"/>
	<input type="submit" class="cbi-button cbi-button-reload" value="]] .. translate("Update Resolver Lists") .. [["/>
</form>
<p><em>]] .. translate("Updating resolver lists will restart the service") .. [[</em></p>
]]

-- Handle actions
local action = luci.http.formvalue("action")
if action == "validate" then
	local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
	if code == 0 then
		m.message = translate("✓ Configuration is valid")
	else
		m.errmessage = translate("✗ Configuration has errors")
	end
elseif action == "reload_sources" then
	sys.call("/usr/libexec/dnscrypt-proxy/helper reload_sources >/dev/null 2>&1 &")
	m.message = translate("✓ Resolver lists update started (may take 1-2 minutes)")
end

-- Form submission handler
function m.handle(self, state, data)
	if state == FORM_VALID then
		local new_content = content
		
		-- Update listen_addresses
		if data.listen_addresses then
			local addrs = {}
			if type(data.listen_addresses) == "table" then
				addrs = data.listen_addresses
			else
				addrs = {data.listen_addresses}
			end
			
			local addr_str = "listen_addresses = ['" .. table.concat(addrs, "', '") .. "']"
			new_content = new_content:gsub("listen_addresses%s*=%s*%b[]", addr_str)
		end
		
		-- Update server_names
		if data.server_names then
			local servers = {}
			if type(data.server_names) == "table" then
				servers = data.server_names
			else
				servers = {data.server_names}
			end
			
			local server_str
			if #servers == 0 then
				server_str = "server_names = []"
			else
				-- Preserve formatting with one server per line
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
			
			-- Match both single and multi-line arrays
			new_content = new_content:gsub("server_names%s*=%s*%b[]", server_str)
		end
		
		-- Update boolean flags
		local function update_bool(key, value)
			local bool_val = (value == "1") and "true" or "false"
			new_content = new_content:gsub(key .. "%s*=%s*%a+", key .. " = " .. bool_val)
		end
		
		update_bool("require_dnssec", data.require_dnssec)
		update_bool("require_nolog", data.require_nolog)
		update_bool("require_nofilter", data.require_nofilter)
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", content)
		fs.writefile(config_file, new_content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = translate("✓ Configuration saved successfully!")
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_restart_offer", "")
			o.rawhtml = true
			o.value = [[
			<div class="alert-message success">
				<strong>]] .. translate("Configuration is valid") .. [[</strong><br/>
				]] .. translate("Restart service to apply changes?") .. [[<br/><br/>
				<form method="post">
					<input type="hidden" name="token" value="]] .. luci.dispatcher.build_form_token() .. [["/>
					<input type="hidden" name="action" value="restart"/>
					<input type="submit" class="cbi-button cbi-button-apply" value="]] .. translate("Restart Now") .. [["/>
				</form>
			</div>
			]]
		else
			self.errmessage = translate("✗ Configuration validation failed! Restoring backup...")
			fs.writefile(config_file, content)
		end
	end
	return true
end

-- Handle restart
if action == "restart" then
	sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
	m.message = translate("✓ Service restarted")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
end

-- Quick Links
s = m:section(SimpleSection, nil, translate("Advanced Configuration"))

o = s:option(DummyValue, "_links", "")
o.rawhtml = true
o.value = [[
<ul style="columns: 2; -webkit-columns: 2; -moz-columns: 2;">
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "protocols") .. [[">]] .. translate("Protocol Settings") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh") .. [[">]] .. translate("ODoH Configuration") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "resolvers") .. [[">]] .. translate("Resolver Management") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "filters") .. [[">]] .. translate("Filtering Rules") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. [[">]] .. translate("View Logs") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "toml") .. [[">]] .. translate("Edit TOML Directly") .. [[</a></li>
</ul>
]]

return m
