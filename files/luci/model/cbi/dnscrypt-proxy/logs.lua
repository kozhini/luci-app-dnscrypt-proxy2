-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

m = SimpleForm("dnscrypt-odoh", translate("DNSCrypt Proxy - ODoH Settings"),
	translate("Oblivious DoH (ODoH) provides enhanced privacy by routing queries through relays."))

m.submit = translate("Save & Apply")
m.reset = translate("Reset")

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"

-- Check if config file exists
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found. Please install dnscrypt-proxy2 first.") .. '</span>'
	return m
end

-- Helper function to get TOML value
local helper = "/usr/libexec/dnscrypt-proxy/helper"
local function get_bool_setting(key)
	local val = util.trim(sys.exec(string.format("%s get_toml_value %s", helper, key)))
	return (val == "true") and "1" or "0"
end

-- Info section
s = m:section(SimpleSection, nil, translate("What is ODoH?"))
o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<h4>🔒 Oblivious DoH (ODoH) Privacy Enhancement</h4>
	<p>ODoH is a privacy-enhanced DNS protocol that routes your queries through a relay server, preventing the DNS resolver from seeing your IP address.</p>
	<ul>
		<li><strong>Step 1:</strong> Your query is encrypted and sent to a relay</li>
		<li><strong>Step 2:</strong> The relay forwards it to the ODoH server (without seeing the content)</li>
		<li><strong>Step 3:</strong> The ODoH server resolves the query (without seeing your IP)</li>
		<li><strong>Step 4:</strong> The response is sent back through the relay to you</li>
	</ul>
	<p><strong>Result:</strong> Neither the relay nor the ODoH server can correlate your IP with your queries.</p>
</div>
]]

-- Current Status
s = m:section(SimpleSection, nil, translate("Current Configuration"))

local odoh_enabled = get_bool_setting("odoh_servers")
local skip_incompatible = get_bool_setting("skip_incompatible")

o = s:option(DummyValue, "_current_status", "")
o.rawhtml = true

local status_html = string.format([[
<table class="table">
	<tr>
		<th>ODoH Servers</th>
		<td><strong style="color: %s">%s</strong></td>
	</tr>
	<tr>
		<th>Skip Incompatible</th>
		<td><strong style="color: %s">%s</strong></td>
	</tr>
</table>
]], 
	odoh_enabled == "1" and "green" or "red",
	odoh_enabled == "1" and "Enabled" or "Disabled",
	skip_incompatible == "1" and "green" or "gray",
	skip_incompatible == "1" and "Yes" or "No"
)

o.value = status_html

-- ODoH Configuration
s = m:section(SimpleSection, nil, translate("ODoH Configuration"))

o = s:option(Flag, "odoh_servers", translate("Enable ODoH Servers"))
o.description = translate("Allow using Oblivious DoH servers for enhanced privacy")
o.default = odoh_enabled
o.rmempty = false

o = s:option(Flag, "skip_incompatible", translate("Skip Incompatible Servers"))
o.description = translate("Ignore servers that don't support anonymization/ODoH")
o.default = skip_incompatible
o.rmempty = false

-- Anonymization Routes (TOML editing)
s = m:section(SimpleSection, nil, translate("Anonymization Routes"))

o = s:option(DummyValue, "_routes_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>📋 Route Configuration:</strong><br/>
	Routes define which servers use which relays. Edit the TOML configuration below to add routes.<br/>
	<strong>Example:</strong> <code>routes = [ { server_name='odoh-*', via=['odohrelay-*'] } ]</code>
</div>
]]

o = s:option(TextValue, "anonymized_routes")
o.rows = 8
o.wrap = "off"
o.description = translate("Configure anonymization routes in TOML format. One route per line or as array.")

-- Read current routes from TOML
function o.cfgvalue(self, section)
	local content = fs.readfile(config_file)
	if not content then return "" end
	
	-- Extract [anonymized_dns] section
	local anon_section = content:match("%[anonymized_dns%](.-)%[")
	if not anon_section then
		anon_section = content:match("%[anonymized_dns%](.*)$")
	end
	
	if anon_section then
		-- Extract routes
		local routes = anon_section:match("routes%s*=%s*(%b[])")
		if routes then
			return "routes = " .. routes
		end
	end
	
	return "# No routes configured\n# Example:\n# routes = [\n#   { server_name='odoh-*', via=['odohrelay-*'] }\n# ]"
end

function o.write(self, section, value)
	-- Store for later processing in handle()
	m.anonymized_routes_value = value
end

-- ODoH Sources Configuration
s = m:section(SimpleSection, nil, translate("ODoH Resolver Sources"))

o = s:option(DummyValue, "_sources_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>📦 Resolver Sources:</strong><br/>
	Configure URLs for ODoH server and relay lists. These will be downloaded and cached locally.
</div>
]]

-- Quick Setup Button
o = s:option(Button, "_apply_defaults", translate("Apply Default ODoH Configuration"))
o.inputstyle = "apply"
o.description = translate("This will add default ODoH sources and a wildcard route to your configuration")

function o.write(self, section)
	local content = fs.readfile(config_file)
	if not content then return end
	
	-- Enable ODoH
	content = content:gsub("(odoh_servers%s*=%s*)%a+", "%1true")
	content = content:gsub("(skip_incompatible%s*=%s*)%a+", "%1true")
	
	-- Uncomment ODoH sources
	content = content:gsub("\n# (%[sources%.'odoh%-servers'%])", "\n%1")
	content = content:gsub("\n# (urls = %[.-'odoh%-servers%.md')", "\n%1")
	content = content:gsub("\n# (cache_file = 'odoh%-servers%.md')", "\n%1")
	content = content:gsub("\n# (minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3')", "\n%1")
	
	content = content:gsub("\n# (%[sources%.'odoh%-relays'%])", "\n%1")
	content = content:gsub("\n# (urls = %[.-'odoh%-relays%.md')", "\n%1")
	content = content:gsub("\n# (cache_file = 'odoh%-relays%.md')", "\n%1")
	
	-- Add default route if not exists
	if not content:match("routes%s*=%s*%[") then
		local anon_section = content:match("(%[anonymized_dns%][^\n]*\n)")
		if anon_section then
			local new_section = anon_section .. "\nroutes = [\n  { server_name='odoh-*', via=['odohrelay-*'] }\n]\n"
			content = content:gsub("%[anonymized_dns%][^\n]*\n", new_section)
		end
	end
	
	-- Backup and save
	fs.writefile(config_file .. ".backup", fs.readfile(config_file))
	fs.writefile(config_file, content)
	
	m.message = translate("Default ODoH configuration applied. Review and save to apply changes.")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
end

-- Available ODoH Servers
s = m:section(SimpleSection, nil, translate("Available ODoH Servers"))

local servers = util.trim(sys.exec(helper .. " list_resolvers odoh"))

o = s:option(DummyValue, "_servers", "")
o.rawhtml = true

if servers and servers ~= "" then
	local server_list = {}
	for server in servers:gmatch("[^\n]+") do
		table.insert(server_list, server)
	end
	
	if #server_list > 0 then
		o.value = "<ul>"
		for _, server in ipairs(server_list) do
			o.value = o.value .. "<li><code>" .. util.pcdata(server) .. "</code></li>"
		end
		o.value = o.value .. "</ul>"
	else
		o.value = '<em>' .. translate("No ODoH servers available. Click 'Update Resolver Lists' on the Overview page.") .. '</em>'
	end
else
	o.value = '<em>' .. translate("No ODoH servers available. Update resolver lists from the Overview page.") .. '</em>'
end

-- Available Relays
s = m:section(SimpleSection, nil, translate("Available ODoH Relays"))

local relays = util.trim(sys.exec(helper .. " list_resolvers relays"))

o = s:option(DummyValue, "_relays", "")
o.rawhtml = true

if relays and relays ~= "" then
	local relay_list = {}
	for relay in relays:gmatch("[^\n]+") do
		if relay:match("^odohrelay%-") or relay:match("relay") then
			table.insert(relay_list, relay)
		end
	end
	
	if #relay_list > 0 then
		o.value = "<ul>"
		for _, relay in ipairs(relay_list) do
			o.value = o.value .. "<li><code>" .. util.pcdata(relay) .. "</code></li>"
		end
		o.value = o.value .. "</ul>"
	else
		o.value = '<em>' .. translate("No ODoH relays found.") .. '</em>'
	end
else
	o.value = '<em>' .. translate("No relays available. Update resolver lists from the Overview page.") .. '</em>'
end

-- Handle form submission
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
		
		update_bool("odoh_servers", data.odoh_servers)
		
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
		
		-- Update routes if provided
		if self.anonymized_routes_value and self.anonymized_routes_value ~= "" then
			local routes_text = self.anonymized_routes_value
			
			-- Find and replace [anonymized_dns] section
			local pattern = "(%[anonymized_dns%]\n).-(\nskip_incompatible)"
			local replacement = "%1\n" .. routes_text .. "\n%2"
			
			if content:match(pattern) then
				content = content:gsub(pattern, replacement)
			else
				-- Add routes if section doesn't have them
				content = content:gsub(
					"(%[anonymized_dns%]\n)",
					"%1\n" .. routes_text .. "\n"
				)
			end
		end
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		-- Validate
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			self.message = translate("ODoH configuration saved successfully!")
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_restart_info", "")
			o.rawhtml = true
			o.value = [[
			<div class="alert-message success">
				<strong>✓ Configuration is valid</strong><br/>
				Restart dnscrypt-proxy to apply changes?<br/><br/>
				<form method="post">
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
local action = luci.http.formvalue("action")
if action == "restart" then
	sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
	m.message = translate("Service restarted")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
end

return m
