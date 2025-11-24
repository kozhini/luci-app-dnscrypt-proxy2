-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"

m = SimpleForm("dnscrypt-resolvers", translate("DNSCrypt Proxy - Resolver Management"),
	translate("Select DNS resolvers with protocol filtering and detailed information"))

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

-- Parse resolvers with full details from JSON
local function parse_resolvers_json()
	local json_str = sys.exec(helper .. " parse_all_resolvers")
	local resolvers = jsonc.parse(json_str)
	return resolvers or {}
end

-- Get current server_names from TOML
local function get_current_servers()
	local servers_str = util.trim(sys.exec(helper .. " get_server_names"))
	
	if servers_str == "[]" or servers_str == "" then
		return {}
	end
	
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
		server_list = server_list .. "<li><code>" .. server .. "</code></li>"
	end
	o.value = '<div class="alert-message info"><strong>' ..
		translate("Currently selected:") .. ' ' .. server_count .. ' ' .. translate("servers") ..
		'</strong><ul>' .. server_list .. '</ul></div>'
end

-- Resolver selection with filters
s = m:section(SimpleSection, nil, translate("Available Resolvers"))

local resolvers = parse_resolvers_json()

if #resolvers == 0 then
	o = s:option(DummyValue, "_no_resolvers", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("No resolvers found in cache. Please update resolver lists from the Overview page.") ..
		'</div>'
	return m
end

-- Count by protocol
local protocol_counts = {DNSCrypt = 0, DoH = 0, ODoH = 0, Unknown = 0}
for _, resolver in ipairs(resolvers) do
	local proto = resolver.protocol or "Unknown"
	protocol_counts[proto] = (protocol_counts[proto] or 0) + 1
end

-- Filter controls
o = s:option(DummyValue, "_filter_controls", "")
o.rawhtml = true
o.value = string.format([[
<div class="alert-message info">
	<strong>]] .. translate("Total resolvers available:") .. [[ %d</strong><br/>
	]] .. translate("Select servers individually or leave empty for automatic selection.") .. [[
</div>

<style>
.protocol-badge {
	display: inline-block;
	padding: 2px 6px;
	margin: 2px;
	border-radius: 3px;
	font-size: 11px;
	font-weight: bold;
	color: white;
}
.badge-dnscrypt { background: #5cb85c; }
.badge-doh { background: #5bc0de; }
.badge-odoh { background: #f0ad4e; }
.badge-dnssec { background: #337ab7; }
.badge-nolog { background: #31b0d5; }
.badge-nofilter { background: #449d44; }
.badge-ipv6 { background: #777; }
</style>

<script type="text/javascript">
var allResolvers = [];
var filteredResolvers = [];

function initResolvers() {
	var rows = document.querySelectorAll('.resolver-row');
	rows.forEach(function(row) {
		allResolvers.push({
			row: row,
			protocol: row.getAttribute('data-protocol'),
			dnssec: row.getAttribute('data-dnssec') === 'true',
			nolog: row.getAttribute('data-nolog') === 'true',
			nofilter: row.getAttribute('data-nofilter') === 'true',
			name: row.getAttribute('data-name')
		});
	});
	filterResolvers();
}

function filterResolvers() {
	var search = document.getElementById('resolver_search').value.toLowerCase();
	var protocol = document.getElementById('protocol_filter').value;
	var requireDnssec = document.getElementById('filter_dnssec').checked;
	var requireNolog = document.getElementById('filter_nolog').checked;
	var requireNofilter = document.getElementById('filter_nofilter').checked;
	
	var visibleCount = 0;
	
	allResolvers.forEach(function(item) {
		var visible = true;
		
		// Text search
		if (search && !item.name.toLowerCase().includes(search)) {
			visible = false;
		}
		
		// Protocol filter
		if (protocol !== 'all' && item.protocol !== protocol) {
			visible = false;
		}
		
		// Property filters
		if (requireDnssec && !item.dnssec) visible = false;
		if (requireNolog && !item.nolog) visible = false;
		if (requireNofilter && !item.nofilter) visible = false;
		
		item.row.style.display = visible ? '' : 'none';
		if (visible) visibleCount++;
	});
	
	document.getElementById('visible_count').innerText = visibleCount;
}

function selectAll(checked) {
	var checkboxes = document.querySelectorAll('input[name^="resolver_"]');
	checkboxes.forEach(function(cb) {
		if (cb.parentElement.parentElement.style.display !== 'none') {
			cb.checked = checked;
		}
	});
}

window.onload = initResolvers;
</script>

<div style="background: #f9f9f9; padding: 10px; border: 1px solid #ddd; margin: 10px 0;">
	<div style="margin-bottom: 10px;">
		<strong>]] .. translate("Search:") .. [[</strong>
		<input type="text" id="resolver_search" placeholder="]] .. translate("Type to search...") .. [[" 
			onkeyup="filterResolvers()" style="width: 250px; padding: 5px; margin-right: 15px;"/>
		
		<strong>]] .. translate("Protocol:") .. [[</strong>
		<select id="protocol_filter" onchange="filterResolvers()" style="padding: 5px;">
			<option value="all">]] .. translate("All") .. [[ (%d)</option>
			<option value="DNSCrypt">DNSCrypt (%d)</option>
			<option value="DoH">DoH (%d)</option>
			<option value="ODoH">ODoH (%d)</option>
		</select>
	</div>
	
	<div style="margin-bottom: 10px;">
		<strong>]] .. translate("Requirements:") .. [[</strong>
		<label style="margin-left: 10px;">
			<input type="checkbox" id="filter_dnssec" onchange="filterResolvers()"/> DNSSEC
		</label>
		<label style="margin-left: 10px;">
			<input type="checkbox" id="filter_nolog" onchange="filterResolvers()"/> No Logging
		</label>
		<label style="margin-left: 10px;">
			<input type="checkbox" id="filter_nofilter" onchange="filterResolvers()"/> No Filtering
		</label>
	</div>
	
	<div>
		<button type="button" onclick="selectAll(true)" class="cbi-button">]] .. translate("Select All Visible") .. [[</button>
		<button type="button" onclick="selectAll(false)" class="cbi-button">]] .. translate("Clear All") .. [[</button>
		<span style="margin-left: 15px;">]] .. translate("Showing:") .. [[ <strong id="visible_count">%d</strong></span>
	</div>
</div>
]], #resolvers, #resolvers, 
   protocol_counts.DNSCrypt, protocol_counts.DoH, protocol_counts.ODoH, #resolvers)

-- Resolver table with details
o = s:option(DummyValue, "_resolver_list", "")
o.rawhtml = true

local table_html = [[
<div style="max-height: 600px; overflow-y: auto; border: 1px solid #ccc;">
<table class="table" style="width: 100%;">
	<thead>
		<tr>
			<th style="width: 40px;">]] .. translate("Select") .. [[</th>
			<th style="width: 200px;">]] .. translate("Name") .. [[</th>
			<th>]] .. translate("Description") .. [[</th>
			<th style="width: 150px;">]] .. translate("Properties") .. [[</th>
		</tr>
	</thead>
	<tbody>
]]

for i, resolver in ipairs(resolvers) do
	local checked = current_servers[resolver.name] and 'checked="checked"' or ''
	local desc = resolver.description or translate("No description")
	local protocol = resolver.protocol or "Unknown"
	
	-- Build badges
	local badges = ""
	
	-- Protocol badge
	local proto_class = "protocol-badge"
	if protocol == "DNSCrypt" then
		proto_class = proto_class .. " badge-dnscrypt"
	elseif protocol == "DoH" then
		proto_class = proto_class .. " badge-doh"
	elseif protocol == "ODoH" then
		proto_class = proto_class .. " badge-odoh"
	end
	badges = badges .. string.format('<span class="%s">%s</span>', proto_class, protocol)
	
	-- Property badges
	if resolver.dnssec then
		badges = badges .. '<span class="protocol-badge badge-dnssec">DNSSEC</span>'
	end
	if resolver.nolog then
		badges = badges .. '<span class="protocol-badge badge-nolog">NoLog</span>'
	end
	if resolver.nofilter then
		badges = badges .. '<span class="protocol-badge badge-nofilter">NoFilter</span>'
	end
	if resolver.ipv6 then
		badges = badges .. '<span class="protocol-badge badge-ipv6">IPv6</span>'
	end
	
	table_html = table_html .. string.format([[
		<tr class="resolver-row" data-name="%s" data-protocol="%s" 
		    data-dnssec="%s" data-nolog="%s" data-nofilter="%s">
			<td><input type="checkbox" name="resolver_%d" value="%s" %s/></td>
			<td><strong>%s</strong></td>
			<td style="font-size: 12px;">%s</td>
			<td>%s</td>
		</tr>
	]], resolver.name, protocol,
	    tostring(resolver.dnssec == true), tostring(resolver.nolog == true), 
	    tostring(resolver.nofilter == true),
	    i, resolver.name, checked, resolver.name, desc, badges)
end

table_html = table_html .. [[
	</tbody>
</table>
</div>
]]

o.value = table_html

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
				<input type="hidden" name="token" value="]] .. luci.dispatcher.build_form_token() .. [["/>
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
