-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

m = Map("dnscrypt-proxy2", translate("DNSCrypt Proxy - ODoH Settings"),
	translate("Oblivious DoH (ODoH) provides enhanced privacy by routing queries through relays."))

-- Check if config file exists
local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
if not fs.access(config_file) then
	m.message = translate("Error: Configuration file not found. Please install dnscrypt-proxy2 first.")
	return m
end

-- ODoH Status
s = m:section(TypedSection, "dnscrypt-proxy2")
s.anonymous = true
s.addremove = false

o = s:option(Flag, "odoh_servers", translate("Enable ODoH Servers"),
	translate("Allow using Oblivious DoH servers for enhanced privacy"))
o.rmempty = false
o.default = "0"

o = s:option(Flag, "require_dnssec", translate("Require DNSSEC"),
	translate("Only use servers that support DNSSEC validation"))
o.rmempty = false
o.default = "1"

o = s:option(Flag, "require_nolog", translate("Require No Logging"),
	translate("Only use servers that don't log queries"))
o.rmempty = false
o.default = "1"

o = s:option(Flag, "require_nofilter", translate("Require No Filtering"),
	translate("Only use servers that don't filter content"))
o.rmempty = false
o.default = "1"

-- Anonymized DNS Settings
s = m:section(TypedSection, "anonymized_dns", translate("Anonymization Settings"),
	translate("Configure how ODoH queries are routed through relays"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable Anonymization"),
	translate("Route queries through relays for enhanced privacy"))
o.rmempty = false
o.default = "0"

o = s:option(Flag, "skip_incompatible", translate("Skip Incompatible"),
	translate("Ignore servers that don't support anonymization"))
o.rmempty = false
o.default = "1"

-- ODoH Routes
s = m:section(TypedSection, "anonymized_route", translate("Anonymization Routes"),
	translate("Configure which servers use which relays. You can use wildcards (*) for pattern matching."))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"

o = s:option(Value, "server_name", translate("Server Pattern"),
	translate("Server name or pattern (e.g., 'odoh-*' or 'odoh-crypto-sx')"))
o.rmempty = false
o.placeholder = "odoh-*"

o = s:option(DynamicList, "via", translate("Via Relays"),
	translate("List of relay names or patterns to use for this server"))
o.rmempty = false
o.placeholder = "odohrelay-*"

-- ODoH Sources
s = m:section(TypedSection, "source", translate("ODoH Resolver Sources"),
	translate("Configure sources for ODoH servers and relays"))
s.anonymous = false
s.addremove = true
s.template = "cbi/tblsection"

o = s:option(Value, "urls", translate("Source URLs"),
	translate("URLs to fetch resolver lists from (comma-separated)"))
o.rmempty = false
o.placeholder = "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md"

o = s:option(Value, "cache_file", translate("Cache Filename"),
	translate("Local filename for cached resolver list"))
o.rmempty = false
o.placeholder = "odoh-servers.md"

o = s:option(Value, "minisign_key", translate("Minisign Public Key"),
	translate("Public key for verifying resolver list signatures"))
o.rmempty = false
o.default = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"

o = s:option(Value, "refresh_delay", translate("Refresh Delay (hours)"),
	translate("How often to refresh resolver lists"))
o.rmempty = false
o.default = "72"
o.datatype = "uinteger"

-- Quick Setup
s = m:section(SimpleSection, nil, translate("Quick Setup"))

o = s:option(DummyValue, "_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<h4>]] .. translate("What is ODoH?") .. [[</h4>
	<p>]] .. translate("Oblivious DoH (ODoH) is a privacy-enhanced DNS protocol that routes your queries through a relay server, preventing the DNS resolver from seeing your IP address.") .. [[</p>
	<ul>
		<li>]] .. translate("Your query is encrypted and sent to a relay") .. [[</li>
		<li>]] .. translate("The relay forwards it to the ODoH server (without seeing the content)") .. [[</li>
		<li>]] .. translate("The ODoH server resolves the query (without seeing your IP)") .. [[</li>
		<li>]] .. translate("The response is sent back through the relay to you") .. [[</li>
	</ul>
	<h4>]] .. translate("Recommended Configuration:") .. [[</h4>
	<ol>
		<li>]] .. translate("Enable 'ODoH Servers' option above") .. [[</li>
		<li>]] .. translate("Enable 'Anonymization' and 'Skip Incompatible'") .. [[</li>
		<li>]] .. translate("Add a route: server_name='odoh-*', via=['odohrelay-*']") .. [[</li>
		<li>]] .. translate("Add ODoH sources (see default configuration below)") .. [[</li>
		<li>]] .. translate("Save and restart the service") .. [[</li>
	</ol>
</div>
]]

o = s:option(Button, "_apply_defaults", translate("Apply Default ODoH Configuration"))
o.inputstyle = "apply"
o.description = translate("This will add default ODoH servers, relays, and routes to your configuration")

function o.write(self, section)
	-- Add default ODoH server source
	local uci = require "luci.model.uci".cursor()
	
	if not uci:get("dnscrypt-proxy2", "odoh_servers") then
		local sid = uci:add("dnscrypt-proxy2", "source")
		uci:set("dnscrypt-proxy2", sid, "urls", 
			"https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md")
		uci:set("dnscrypt-proxy2", sid, "cache_file", "odoh-servers.md")
		uci:set("dnscrypt-proxy2", sid, "minisign_key", 
			"RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3")
		uci:set("dnscrypt-proxy2", sid, "refresh_delay", "72")
	end
	
	-- Add default ODoH relay source
	if not uci:get("dnscrypt-proxy2", "odoh_relays") then
		local sid = uci:add("dnscrypt-proxy2", "source")
		uci:set("dnscrypt-proxy2", sid, "urls", 
			"https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-relays.md")
		uci:set("dnscrypt-proxy2", sid, "cache_file", "odoh-relays.md")
		uci:set("dnscrypt-proxy2", sid, "minisign_key", 
			"RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3")
		uci:set("dnscrypt-proxy2", sid, "refresh_delay", "72")
	end
	
	-- Add default anonymization route
	local found_route = false
	uci:foreach("dnscrypt-proxy2", "anonymized_route", function(s)
		if s.server_name == "odoh-*" then
			found_route = true
			return false
		end
	end)
	
	if not found_route then
		local sid = uci:add("dnscrypt-proxy2", "anonymized_route")
		uci:set("dnscrypt-proxy2", sid, "server_name", "odoh-*")
		uci:set("dnscrypt-proxy2", sid, "via", {"odohrelay-*"})
	end
	
	uci:commit("dnscrypt-proxy2")
	
	m.message = translate("Default ODoH configuration applied. Please review and save.")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh"))
end

-- Available ODoH Servers
s = m:section(SimpleSection, nil, translate("Available ODoH Servers"))

local helper = "/usr/libexec/dnscrypt-proxy/helper"
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
			o.value = o.value .. "<li>" .. util.pcdata(server) .. "</li>"
		end
		o.value = o.value .. "</ul>"
	else
		o.value = '<em>' .. translate("No ODoH servers available. Click 'Update Resolver Lists' on the Overview page.") .. '</em>'
	end
else
	o.value = '<em>' .. translate("No ODoH servers available. Click 'Update Resolver Lists' on the Overview page.") .. '</em>'
end

return m
