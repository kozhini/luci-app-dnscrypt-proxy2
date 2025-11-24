-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"

m = SimpleForm("dnscrypt-resolvers", translate("DNSCrypt Proxy - Resolver Management"),
	translate("Select DNS resolvers and configure anonymization relays"))

m.submit = translate("Save & Apply")
m.reset = false

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
local cache_dir = "/var/lib/dnscrypt-proxy"

-- Check config
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found") .. '</span>'
	return m
end

-- Parse resolver lists from cache
local function parse_resolver_list(cache_file)
	local resolvers = {}
	local file_path = cache_dir .. "/" .. cache_file
	
	if not fs.access(file_path) then
		return resolvers
	end
	
	local content = fs.readfile(file_path)
	if not content then return resolvers end
	
	local current = {}
	for line in content:gmatch("[^\r\n]+") do
		if line:match("^##%s+(.+)") then
			-- New resolver
			if current.name then
				table.insert(resolvers, current)
			end
			current = {name = line:match("^##%s+(.+)")}
		elseif current.name then
			-- Parse properties
			if line:match("^sdns://") then
				current.stamp = line
			elseif line:match("^Description:") then
				current.description = line:match("^Description:%s*(.+)") or ""
			elseif line:match("^Location:") then
				current.location = line:match("^Location:%s*(.+)") or ""
			end
		end
	end
	
	if current.name then
		table.insert(resolvers, current)
	end
	
	return resolvers
end

-- Get current server_names from TOML
local function get_current_servers()
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local servers_str = util.trim(sys.exec(helper .. " get_server_names"))
	
	if servers_str == "[]" or servers_str == "" then
		return {}
	end
	
	-- Parse array format ['server1', 'server2']
	local servers = {}
	for server in servers_str:gmatch("'([^']+)'") do
		servers[server] = true
	end
	
	return servers
end

-- Info section
s = m:section(SimpleSection, nil, translate("Current Configuration"))

local current_servers = get_current_servers()
local server_count = 0
for _ in pairs(current_servers) do server_count = server_count + 1 end

o = s:option(DummyValue, "_current", "")
o.rawhtml = true

if server_count == 0 then
	o.value = '<div class="alert-message info"><strong>' .. 
		translate("No servers selected - using all available servers (automatic selection)") .. 
		'</strong></div>'
else
	local server_list = ""
	for server, _ in pairs(current_servers) do
		server_list = server_list .. "<li>" .. server .. "</li>"
	end
	o.value = '<div class="alert-message info"><strong>' ..
		translate("Currently selected:") .. ' ' .. server_count .. ' ' .. translate("servers") ..
		'</strong><ul>' .. server_list .. '</ul></div>'
end

-- Resolver selection
s = m:section(SimpleSection, nil, translate("Available Resolvers"))

local resolvers = parse_resolver_list("public-resolvers.md")

if #resolvers == 0 then
	o = s:option(DummyValue, "_no_resolvers", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No resolvers found in cache. Please update resolver lists from the Overview page.") ..
		'</div>'
	return m
end

-- Filter controls
o = s:option(DummyValue, "_filter_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>]] .. translate("Total resolvers available:") .. [[ ]] .. #resolvers .. [[</strong><br/>
	]] .. translate("Select servers individually or leave empty for automatic selection.") .. [[
</div>
<script type="text/javascript">
function filterResolvers() {
	var search = document.getElementById('resolver_search').value.toLowerCase();
	var rows = document.querySelectorAll('.resolver-row');
	
	rows.forEach(function(row) {
		var text = row.textContent.toLowerCase();
		row.style.display = text.includes(search) ? '' : 'none';
	});
}

function selectAll(checked) {
	var checkboxes = document.querySelectorAll('input[name^="resolver_"]');
	checkboxes.forEach(function(cb) {
		if (cb.parentElement.parentElement.style.display !== 'none') {
			cb.checked = checked;
		}
	});
}
</script>
<div style="margin: 10px 0;">
	<input type="text" id="resolver_search" placeholder="]] .. translate("Search resolvers...") .. [[" 
		onkeyup="filterResolvers()" style="width: 300px; padding: 5px;"/>
	<button type="button" onclick="selectAll(true)" class="cbi-button">]] .. translate("Select All") .. [[</button>
	<button type="button" onclick="selectAll(false)" class="cbi-button">]] .. translate("Clear All") .. [[</button>
</div>
]]

-- Resolver table
o = s:option(DummyValue, "_resolver_list", "")
o.rawhtml = true

local table_html = [[
<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc;">
<table class="table" style="width: 100%;">
	<thead>
		<tr>
			<th style="width: 50px;">]] .. translate("Select") .. [[</th>
			<th>]] .. translate("Name") .. [[</th>
			<th>]] .. translate("Description") .. [[</th>
			<th>]] .. translate("Location") .. [[</th>
		</tr>
	</thead>
	<tbody>
]]

for i, resolver in ipairs(resolvers) do
	local checked = current_servers[resolver.name] and 'checked="checked"' or ''
	local desc = resolver.description or translate("No description")
	local loc = resolver.location or translate("Unknown")
	
	table_html = table_html .. string.format([[
		<tr class="resolver-row">
			<td><input type="checkbox" name="resolver_%d" value="%s" %s/></td>
			<td><strong>%s</strong></td>
			<td>%s</td>
			<td>%s</td>
		</tr>
	]], i, resolver.name, checked, resolver.name, desc, loc)
end

table_html = table_html .. [[
	</tbody>
</table>
</div>
]]

o.value = table_html

-- Relay selection (for anonymization)
s = m:section(SimpleSection, nil, translate("Anonymization Relays"))

local relays = parse_resolver_list("relays.md")

if #relays > 0 then
	o = s:option(DummyValue, "_relay_info", "")
	o.rawhtml = true
	o.value = '<div class="alert-message info">' ..
		translate("Relays available:") .. ' ' .. #relays .. '<br/>' ..
		translate("Configure relay routes in the ODoH Settings page.") ..
		'</div>'
	
	-- Show relay list
	o = s:option(DummyValue, "_relay_list", "")
	o.rawhtml = true
	
	local relay_html = "<ul>"
	for _, relay in ipairs(relays) do
		relay_html = relay_html .. "<li><strong>" .. relay.name .. "</strong> - " .. 
			(relay.location or translate("Unknown location")) .. "</li>"
	end
	relay_html = relay_html .. "</ul>"
	
	o.value = relay_html
else
	o = s:option(DummyValue, "_no_relays", "")
	o.rawhtml = true
	o.value = '<em>' .. translate("No relays found. Update resolver lists if you need anonymization.") .. '</em>'
end

-- Handle form submission
function m.handle(self, state, data)
	if state == FORM_VALID then
		-- Collect selected servers
		local selected = {}
		for i = 1, #resolvers do
			local field = luci.http.formvalue("resolver_" .. i)
			if field then
				table.insert(selected, field)
			end
		end
		
		-- Update TOML
		local content = fs.readfile(config_file)
		local server_list_str
		
		if #selected == 0 then
			server_list_str = "[]"
		else
			server_list_str = "['" .. table.concat(selected, "', '") .. "']"
		end
		
		-- Replace server_names line
		content = content:gsub(
			"server_names%s*=%s*%b[]",
			"server_names = " .. server_list_str
		)
		
		-- Backup and save
		fs.writefile(config_file .. ".backup", fs.readfile(config_file))
		fs.writefile(config_file, content)
		
		-- Validate
		local helper = "/usr/libexec/dnscrypt-proxy/helper"
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if code == 0 then
			if #selected == 0 then
				self.message = translate("Configuration saved. Using automatic server selection.")
			else
				self.message = translate("Configuration saved.") .. " " .. 
					translate("Selected") .. ": " .. #selected .. " " .. translate("servers")
			end
			
			-- Offer restart
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_restart", "")
			o.rawhtml = true
			o.value = [[
			<form method="post">
				<input type="hidden" name="action" value="restart"/>
				<input type="submit" class="cbi-button cbi-button-apply" value="]] .. translate("Restart Service") .. [["/>
			</form>
			]]
		else
			self.errmessage = translate("Configuration error. Restoring backup...")
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
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "resolvers"))
end

return m
