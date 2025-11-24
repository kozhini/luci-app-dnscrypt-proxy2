-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"

m = SimpleForm("dnscrypt-anonymization", translate("DNSCrypt Proxy - Anonymization Routes"),
	translate("Configure how queries are routed through anonymization relays"))

m.submit = translate("Save & Apply")
m.reset = false

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
local helper = "/usr/libexec/dnscrypt-proxy/helper"

-- Check config
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found") .. '</span>'
	return m
end

-- Parse current routes from TOML
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
	
	-- Simple TOML array parser
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

-- Get available relays
local function get_available_relays()
	local relays_str = util.trim(sys.exec(helper .. " list_resolvers relays"))
	local relays = {}
	
	for relay in relays_str:gmatch("[^\n]+") do
		table.insert(relays, relay)
	end
	
	return relays
end

-- Info section
s = m:section(SimpleSection, nil, translate("About Anonymization"))
o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>🔒 What is Anonymization?</strong>
	<p>Anonymization routes your DNS queries through relay servers before reaching the resolver. This prevents the resolver from seeing your real IP address.</p>
	<ul>
		<li><strong>Direct:</strong> You → Resolver (resolver sees your IP)</li>
		<li><strong>Anonymized:</strong> You → Relay → Resolver (resolver only sees relay IP)</li>
	</ul>
	<p><strong>Note:</strong> Anonymization adds latency but significantly improves privacy.</p>
</div>
]]

-- Current routes
local current_routes = parse_routes()
local available_relays = get_available_relays()

s = m:section(SimpleSection, nil, translate("Current Routes"))

if #current_routes == 0 then
	o = s:option(DummyValue, "_no_routes", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No anonymization routes configured. All queries are sent directly.") ..
		'</div>'
else
	o = s:option(DummyValue, "_routes_list", "")
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
						<input type="hidden" name="action" value="delete_route"/>
						<input type="hidden" name="route_index" value="%d"/>
						<input type="submit" class="cbi-button cbi-button-remove" value="%s" 
							onclick="return confirm('%s')"/>
					</form>
				</td>
			</tr>
		]], route.server_name, relays_display, i, translate("Delete"), translate("Delete this route?"))
	end
	
	routes_html = routes_html .. '</tbody></table>'
	o.value = routes_html
end

-- Handle route deletion
local action = luci.http.formvalue("action")
if action == "delete_route" then
	local route_index = tonumber(luci.http.formvalue("route_index"))
	if route_index and route_index > 0 and route_index <= #current_routes then
		table.remove(current_routes, route_index)
		
		-- Save back to TOML
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
		
		m.message = translate("Route deleted successfully")
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "anonymization"))
	end
end

-- Add new route section
s = m:section(SimpleSection, nil, translate("Add New Route"))

if #available_relays == 0 then
	o = s:option(DummyValue, "_no_relays", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No relays available. Please update resolver lists from the Overview page.") ..
		'</div>'
	return m
end

o = s:option(Value, "server_pattern", translate("Server Pattern"),
	translate("Server name or wildcard pattern. Examples: 'cloudflare', 'odoh-*', '*' (all servers)"))
o.placeholder = "odoh-*"
o.rmempty = false

o = s:option(DummyValue, "_pattern_help", "")
o.rawhtml = true
o.value = [[
<div style="margin: 5px 0; padding: 8px; background: #f0f0f0; border-left: 3px solid #666;">
	<strong>Pattern Examples:</strong><br/>
	<code>cloudflare</code> - specific server<br/>
	<code>odoh-*</code> - all ODoH servers<br/>
	<code>*</code> - all servers (use with caution)<br/>
	<code>quad9-*</code> - all Quad9 servers
</div>
]]

-- Relay selection with checkboxes
o = s:option(DummyValue, "_relay_selection", translate("Select Relays"))
o.rawhtml = true

local relay_html = '<div style="max-height: 300px; overflow-y: auto; border: 1px solid #ccc; padding: 10px;">'
relay_html = relay_html .. '<p><em>' .. translate("Select one or more relays for this route:") .. '</em></p>'

-- Group relays
local odoh_relays = {}
local anon_relays = {}
local other_relays = {}

for _, relay in ipairs(available_relays) do
	if relay:match("^odohrelay%-") then
		table.insert(odoh_relays, relay)
	elseif relay:match("^anon%-") then
		table.insert(anon_relays, relay)
	else
		table.insert(other_relays, relay)
	end
end

if #odoh_relays > 0 then
	relay_html = relay_html .. '<fieldset><legend><strong>ODoH Relays</strong></legend>'
	for _, relay in ipairs(odoh_relays) do
		relay_html = relay_html .. string.format(
			'<label style="display:block;"><input type="checkbox" name="relay_%s" value="%s"/> <code>%s</code></label>',
			relay:gsub("[^%w]", "_"), relay, relay)
	end
	relay_html = relay_html .. '</fieldset>'
end

if #anon_relays > 0 then
	relay_html = relay_html .. '<fieldset><legend><strong>Anonymization Relays</strong></legend>'
	for _, relay in ipairs(anon_relays) do
		relay_html = relay_html .. string.format(
			'<label style="display:block;"><input type="checkbox" name="relay_%s" value="%s"/> <code>%s</code></label>',
			relay:gsub("[^%w]", "_"), relay, relay)
	end
	relay_html = relay_html .. '</fieldset>'
end

if #other_relays > 0 then
	relay_html = relay_html .. '<fieldset><legend><strong>Other Relays</strong></legend>'
	for _, relay in ipairs(other_relays) do
		relay_html = relay_html .. string.format(
			'<label style="display:block;"><input type="checkbox" name="relay_%s" value="%s"/> <code>%s</code></label>',
			relay:gsub("[^%w]", "_"), relay, relay)
	end
	relay_html = relay_html .. '</fieldset>'
end

relay_html = relay_html .. '</div>'
o.value = relay_html

-- Quick presets
s = m:section(SimpleSection, nil, translate("Quick Presets"))

o = s:option(DummyValue, "_presets", "")
o.rawhtml = true

local token = luci.dispatcher.build_form_token()
o.value = [[
<div style="margin: 10px 0;">
	<form method="post" style="display: inline-block; margin-right: 10px;">
		<input type="hidden" name="token" value="]] .. token .. [["/>
		<input type="hidden" name="preset_action" value="odoh"/>
		<input type="submit" class="cbi-button cbi-button-apply" value="]] .. translate("Add ODoH Route") .. [["/>
		<p style="margin: 5px 0 0 0;"><em>]] .. translate("Route all ODoH servers through ODoH relays") .. [[</em></p>
	</form>
	
	<form method="post" style="display: inline-block;">
		<input type="hidden" name="token" value="]] .. token .. [["/>
		<input type="hidden" name="preset_action" value="universal"/>
		<input type="submit" class="cbi-button cbi-button-apply" value="]] .. translate("Add Universal Route") .. [["/>
		<p style="margin: 5px 0 0 0;"><em>]] .. translate("Route ALL servers through anonymization relays (may slow down)") .. [[</em></p>
	</form>
</div>
]]

-- Handle presets
local preset_action = luci.http.formvalue("preset_action")
if preset_action == "odoh" then
	table.insert(current_routes, {
		server_name = "odoh-*",
		via = {"odohrelay-*"}
	})
	
	-- Save immediately
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
	
	m.message = translate("ODoH route added successfully!")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "anonymization"))
elseif preset_action == "universal" and #available_relays > 0 then
	table.insert(current_routes, {
		server_name = "*",
		via = {available_relays[1]}
	})
	
	-- Save immediately
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
	
	m.message = translate("Universal route added successfully!")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "anonymization"))
end

-- Form submission handler
function m.handle(self, state, data)
	if state == FORM_VALID then
		-- Collect selected relays
		local selected_relays = {}
		for _, relay in ipairs(available_relays) do
			local field_name = "relay_" .. relay:gsub("[^%w]", "_")
			if luci.http.formvalue(field_name) then
				table.insert(selected_relays, relay)
			end
		end
		
		-- Add new route if pattern and relays provided
		if data.server_pattern and data.server_pattern ~= "" and #selected_relays > 0 then
			table.insert(current_routes, {
				server_name = data.server_pattern,
				via = selected_relays
			})
			
			self.message = translate("New route added successfully!")
		end
		
		-- Convert routes to TOML
		local routes_toml = "routes = [\n"
		if #current_routes > 0 then
			for _, route in ipairs(current_routes) do
				local via_str = "'" .. table.concat(route.via, "', '") .. "'"
				routes_toml = routes_toml .. string.format("  { server_name='%s', via=[%s] },\n", 
					route.server_name, via_str)
			end
		end
		routes_toml = routes_toml .. "]"
		
		-- Update TOML file
		local content = fs.readfile(config_file)
		
		-- Find and replace routes section
		if content:match("routes%s*=%s*%b[]") then
			content = content:gsub("routes%s*=%s*%b[]", routes_toml:gsub("%%", "%%%%"))
		else
			-- Add routes if not present
			content = content:gsub("(%[anonymized_dns%]\n)", "%1\n" .. routes_toml .. "\n")
		end
		
		-- Enable skip_incompatible if routes exist
		if #current_routes > 0 then
			content = content:gsub("(skip_incompatible%s*=%s*)%a+", "%1true")
		end
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = (self.message or translate("Routes saved successfully!"))
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_restart_info", "")
			o.rawhtml = true
			o.value = [[
			<div class="alert-message success">
				<strong>✓ Configuration is valid</strong><br/>
				Restart dnscrypt-proxy to apply changes?<br/><br/>
				<form method="post">
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
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "anonymization"))
end

return m
