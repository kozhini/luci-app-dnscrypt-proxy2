-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"
local dispatcher = require "luci.dispatcher"

m = SimpleForm("dnscrypt-odoh", translate("DNSCrypt Proxy - ODoH Management"),
	translate("Complete ODoH configuration: servers, relays, and anonymization routes"))

m.submit = translate("Save & Apply")
m.reset = translate("Reset")

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
local helper = "/usr/libexec/dnscrypt-proxy/helper"

-- Check if config file exists
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found. Please install dnscrypt-proxy2 first.") .. '</span>'
	return m
end

-- Helper function to get TOML value
local function get_bool_setting(key)
	local val = util.trim(sys.exec(string.format("%s get_toml_value %s", helper, key)))
	return (val == "true") and "1" or "0"
end

-- Parse routes from TOML
local function parse_routes()
	local content = fs.readfile(config_file)
	if not content then return {} end
	
	local anon_section = content:match("%[anonymized_dns%](.-)%[")
	if not anon_section then
		anon_section = content:match("%[anonymized_dns%](.*)$")
	end
	
	if not anon_section then return {} end
	
	local routes_str = anon_section:match("routes%s*=%s*(%b[])")
	if not routes_str then return {} end
	
	local routes = {}
	for route in routes_str:gmatch("{[^}]+}") do
		local server = route:match("server_name%s*=%s*['\"]([^'\"]+)['\"]")
		local via_str = route:match("via%s*=%s*(%b[])")
		
		if server and via_str then
			local via_list = {}
			for relay in via_str:gmatch("['\"]([^'\"]+)['\"]") do
				table.insert(via_list, relay)
			end
			
			if #via_list > 0 then
				table.insert(routes, {
					server_name = server,
					via = via_list
				})
			end
		end
	end
	
	return routes
end

-- Get available servers/relays
local function get_servers_and_relays()
	local odoh_servers = {}
	local odoh_relays = {}
	
	-- Parse ODoH servers
	local servers_str = util.trim(sys.exec(helper .. " list_resolvers odoh"))
	for server in servers_str:gmatch("[^\n]+") do
		table.insert(odoh_servers, server)
	end
	
	-- Parse relays
	local relays_str = util.trim(sys.exec(helper .. " list_resolvers relays"))
	for relay in relays_str:gmatch("[^\n]+") do
		if relay:match("^odohrelay%-") then
			table.insert(odoh_relays, relay)
		end
	end
	
	return odoh_servers, odoh_relays
end

-- Info section
s = m:section(SimpleSection, nil, translate("About ODoH"))
o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<h4>🔒 Oblivious DoH (ODoH) Privacy Enhancement</h4>
	<p>ODoH routes queries through relay servers, preventing DNS resolvers from seeing your IP address.</p>
	<strong>How it works:</strong>
	<ol>
		<li>Your query → Relay (relay doesn't see content)</li>
		<li>Relay → ODoH Server (server doesn't see your IP)</li>
		<li>Response returns via relay</li>
	</ol>
</div>
]]

-- Current Status
s = m:section(SimpleSection, nil, translate("Current Status"))

local odoh_enabled = get_bool_setting("odoh_servers")
local skip_incompatible = get_bool_setting("skip_incompatible")
local current_routes = parse_routes()

o = s:option(DummyValue, "_current_status", "")
o.rawhtml = true

local status_html = string.format([[
<table class="table">
	<tr><th>Setting</th><th>Status</th></tr>
	<tr>
		<td>ODoH Servers</td>
		<td><strong style="color: %s">%s</strong></td>
	</tr>
	<tr>
		<td>Skip Incompatible</td>
		<td><strong style="color: %s">%s</strong></td>
	</tr>
	<tr>
		<td>Anonymization Routes</td>
		<td><strong>%d configured</strong></td>
	</tr>
</table>
]], 
	odoh_enabled == "1" and "green" or "red",
	odoh_enabled == "1" and "Enabled" or "Disabled",
	skip_incompatible == "1" and "green" or "gray",
	skip_incompatible == "1" and "Yes" or "No",
	#current_routes
)

o.value = status_html

-- Basic Settings
s = m:section(SimpleSection, nil, translate("Basic ODoH Settings"))

o = s:option(Flag, "odoh_servers", translate("Enable ODoH Servers"))
o.description = translate("Use Oblivious DoH servers for enhanced privacy")
o.default = odoh_enabled
o.rmempty = false

o = s:option(Flag, "skip_incompatible", translate("Skip Incompatible Servers"))
o.description = translate("Ignore servers that don't support anonymization/ODoH")
o.default = skip_incompatible
o.rmempty = false

-- Server Selection
local odoh_servers, odoh_relays = get_servers_and_relays()

s = m:section(SimpleSection, nil, translate("ODoH Server Selection"))

if #odoh_servers == 0 then
	o = s:option(DummyValue, "_no_servers", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No ODoH servers available. Update resolver lists from Overview page.") ..
		'</div>'
else
	o = s:option(DummyValue, "_server_selection_info", "")
	o.rawhtml = true
	o.value = string.format([[
<div class="alert-message info">
	<strong>ℹ️ Server Selection:</strong><br/>
	Found <strong>%d ODoH servers</strong>. To select specific servers, use the 
	<a href="%s">Resolvers</a> page, or leave empty to use all available ODoH servers.
</div>
]], #odoh_servers, luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "resolvers"))
	
	o = s:option(DummyValue, "_available_servers", translate("Available ODoH Servers"))
	o.rawhtml = true
	local server_list = "<ul style='max-height: 200px; overflow-y: auto; border: 1px solid #ddd; padding: 10px;'>"
	for _, server in ipairs(odoh_servers) do
		server_list = server_list .. "<li><code>" .. util.pcdata(server) .. "</code></li>"
	end
	server_list = server_list .. "</ul>"
	o.value = server_list
end

-- Anonymization Routes Management
s = m:section(SimpleSection, nil, translate("Anonymization Routes"))

o = s:option(DummyValue, "_routes_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>📋 Routes:</strong> Define which ODoH servers use which relays.<br/>
	<strong>Wildcards:</strong> Use <code>odoh-*</code> to match all ODoH servers, <code>odohrelay-*</code> for all relays.
</div>
]]

-- Display current routes
if #current_routes > 0 then
	o = s:option(DummyValue, "_current_routes", translate("Current Routes"))
	o.rawhtml = true
	
	local routes_html = '<table class="table"><thead><tr><th>' .. translate("Server Pattern") .. 
		'</th><th>' .. translate("Via Relays") .. '</th><th>' .. translate("Actions") .. '</th></tr></thead><tbody>'
	
	for i, route in ipairs(current_routes) do
		local relays_display = table.concat(route.via, ", ")
		routes_html = routes_html .. string.format([[
			<tr>
				<td><code>%s</code></td>
				<td><code>%s</code></td>
				<td>
					<form method="post" style="display:inline;">
						<input type="hidden" name="token" value="%s"/>
						<input type="hidden" name="action" value="delete_route"/>
						<input type="hidden" name="route_index" value="%d"/>
						<input type="submit" class="cbi-button cbi-button-remove" value="%s" 
							onclick="return confirm('%s')"/>
					</form>
				</td>
			</tr>
		]], route.server_name, relays_display, 
		    luci.dispatcher.build_form_token(), i, 
		    translate("Delete"), translate("Delete this route?"))
	end
	
	routes_html = routes_html .. '</tbody></table>'
	o.value = routes_html
else
	o = s:option(DummyValue, "_no_routes", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No routes configured. ODoH queries will go directly (no anonymization).") ..
		'</div>'
end

-- Add new route
s = m:section(SimpleSection, nil, translate("Add New Route"))

if #odoh_relays == 0 then
	o = s:option(DummyValue, "_no_relays", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No ODoH relays available. Update resolver lists from Overview page.") ..
		'</div>'
else
	o = s:option(Value, "new_route_server", translate("Server Pattern"),
		translate("Server name or wildcard. Examples: 'odoh-cloudflare', 'odoh-*'"))
	o.placeholder = "odoh-*"
	o.rmempty = true
	
	o = s:option(DummyValue, "_relay_selection", translate("Select Relays"))
	o.rawhtml = true
	
	local relay_html = '<div style="max-height: 250px; overflow-y: auto; border: 1px solid #ccc; padding: 10px;">'
	relay_html = relay_html .. '<p><em>' .. translate("Select one or more relays:") .. '</em></p>'
	
	for _, relay in ipairs(odoh_relays) do
		relay_html = relay_html .. string.format(
			'<label style="display:block;"><input type="checkbox" name="relay_%s" value="%s"/> <code>%s</code></label>',
			relay:gsub("[^%w]", "_"), relay, relay)
	end
	
	relay_html = relay_html .. '</div>'
	o.value = relay_html
end

-- Quick presets
s = m:section(SimpleSection, nil, translate("Quick Setup"))

o = s:option(DummyValue, "_quick_setup", "")
o.rawhtml = true

local token = luci.dispatcher.build_form_token()

o.value = string.format([[
<div style="margin: 10px 0;">
	<form method="post" style="display: inline-block; margin-right: 10px;">
		<input type="hidden" name="token" value="%s"/>
		<input type="hidden" name="preset_action" value="wildcard"/>
		<input type="submit" class="cbi-button cbi-button-apply" value="%s"/>
		<p style="margin: 5px 0 0 0;"><em>%s</em></p>
	</form>
	
	<form method="post" style="display: inline-block;">
		<input type="hidden" name="token" value="%s"/>
		<input type="hidden" name="preset_action" value="enable_sources"/>
		<input type="submit" class="cbi-button cbi-button-apply" value="%s"/>
		<p style="margin: 5px 0 0 0;"><em>%s</em></p>
	</form>
</div>
]], token, translate("Add Wildcard Route"), translate("Route all ODoH servers through all ODoH relays"),
    token, translate("Enable ODoH Sources"), translate("Uncomment ODoH sources in TOML"))

-- Handle preset actions
local preset_action = luci.http.formvalue("preset_action")
if preset_action == "wildcard" then
	table.insert(current_routes, {
		server_name = "odoh-*",
		via = {"odohrelay-*"}
	})
	
	local routes_toml = "routes = [\n"
	for _, route in ipairs(current_routes) do
		local via_str = "'" .. table.concat(route.via, "', '") .. "'"
		routes_toml = routes_toml .. string.format("  { server_name='%s', via=[%s] },\n", 
			route.server_name, via_str)
	end
	routes_toml = routes_toml .. "]"
	
	local content = fs.readfile(config_file)
	if content:match("routes%s*=%s*%b[]") then
		content = content:gsub("routes%s*=%s*%b[]", routes_toml:gsub("%%", "%%%%"))
	else
		content = content:gsub("(%[anonymized_dns%]\n)", "%1\n" .. routes_toml .. "\n")
	end
	
	fs.writefile(config_file .. ".backup", fs.readfile(config_file))
	fs.writefile(config_file, content)
	
	m.message = translate("Wildcard route added!")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
	
elseif preset_action == "enable_sources" then
	local content = fs.readfile(config_file)
	
	-- Enable ODoH sources
	content = content:gsub("(odoh_servers%s*=%s*)%a+", "%1true")
	content = content:gsub("\n# (%[sources%.'odoh%-servers'%])", "\n%1")
	content = content:gsub("\n# (urls = %[.-'odoh%-servers%.md')", "\n%1")
	content = content:gsub("\n# (cache_file = 'odoh%-servers%.md')", "\n%1")
	content = content:gsub("\n# (minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3')", "\n%1")
	
	content = content:gsub("\n# (%[sources%.'odoh%-relays'%])", "\n%1")
	content = content:gsub("\n# (urls = %[.-'odoh%-relays%.md')", "\n%1")
	content = content:gsub("\n# (cache_file = 'odoh%-relays%.md')", "\n%1")
	
	fs.writefile(config_file .. ".backup", fs.readfile(config_file))
	fs.writefile(config_file, content)
	
	m.message = translate("ODoH sources enabled! Restart service to download lists.")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
end

-- Handle route deletion
local action = luci.http.formvalue("action")
if action == "delete_route" then
	local route_index = tonumber(luci.http.formvalue("route_index"))
	if route_index and route_index > 0 and route_index <= #current_routes then
		table.remove(current_routes, route_index)
		
		local routes_toml = "routes = [\n"
		for _, route in ipairs(current_routes) do
			local via_str = "'" .. table.concat(route.via, "', '") .. "'"
			routes_toml = routes_toml .. string.format("  { server_name='%s', via=[%s] },\n", 
				route.server_name, via_str)
		end
		routes_toml = routes_toml .. "]\n"
		
		local content = fs.readfile(config_file)
		content = content:gsub("routes%s*=%s*%b[]", routes_toml:gsub("%%", "%%%%"))
		
		fs.writefile(config_file .. ".backup", fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		m.message = translate("Route deleted!")
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
	end
end

-- Form submission handler
function m.handle(self, state, data)
	if state == FORM_VALID then
		local content = fs.readfile(config_file)
		
		-- Update boolean values
		local function update_bool(key, value)
			local bool_val = (value == "1") and "true" or "false"
			content = content:gsub(
				"(" .. key .. "%s*=%s*)%a+",
				"%1" .. bool_val
			)
		end
		
		update_bool("odoh_servers", data.odoh_servers or "0")
		
		-- Update skip_incompatible in [anonymized_dns] section
		local anon_section = content:match("(%[anonymized_dns%].-)%[")
		if not anon_section then
			anon_section = content:match("(%[anonymized_dns%].*)$")
		end
		
		if anon_section then
			local bool_val = (data.skip_incompatible == "1") and "true" or "false"
			local new_section = anon_section:gsub(
				"(skip_incompatible%s*=%s*)%a+",
				"%1" .. bool_val
			)
			content = content:gsub("%[anonymized_dns%].-%[", new_section .. "[")
		end
		
		-- Add new route if provided
		if data.new_route_server and data.new_route_server ~= "" then
			local selected_relays = {}
			for _, relay in ipairs(odoh_relays) do
				local field_name = "relay_" .. relay:gsub("[^%w]", "_")
				if luci.http.formvalue(field_name) then
					table.insert(selected_relays, relay)
				end
			end
			
			if #selected_relays > 0 then
				table.insert(current_routes, {
					server_name = data.new_route_server,
					via = selected_relays
				})
				
				local routes_toml = "routes = [\n"
				for _, route in ipairs(current_routes) do
					local via_str = "'" .. table.concat(route.via, "', '") .. "'"
					routes_toml = routes_toml .. string.format("  { server_name='%s', via=[%s] },\n", 
						route.server_name, via_str)
				end
				routes_toml = routes_toml .. "]"
				
				if content:match("routes%s*=%s*%b[]") then
					content = content:gsub("routes%s*=%s*%b[]", routes_toml:gsub("%%", "%%%%"))
				else
					content = content:gsub("(%[anonymized_dns%]\n)", "%1\n" .. routes_toml .. "\n")
				end
				
				self.message = translate("New route added!")
			end
		end
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = (self.message or translate("Configuration saved successfully!"))
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_restart_info", "")
			o.rawhtml = true
			o.value = [[
			<div class="alert-message success">
				<strong>✓ Configuration is valid</strong><br/>
				Restart dnscrypt-proxy to apply changes?<br/><br/>
				<form method="post" action="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh") .. [[">
					<input type="hidden" name="token" value="]] .. luci.dispatcher.build_form_token() .. [["/>
					<input type="hidden" name="action" value="restart"/>
					<input type="submit" class="cbi-button cbi-button-apply" value="Restart Service"/>
				</form>
			</div>
			]]
		else
			self.errmessage = translate("Configuration validation failed! Restoring backup...")
			fs.writefile(config_file, fs.readfile(config_file .. ".backup"))
		end
	end
	return true
end

-- Handle restart
if action == "restart" then
	sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
	m.message = translate("Service restarted")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
end

return m
