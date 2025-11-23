-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("dnscrypt-proxy", translate("DNSCrypt Proxy - Overview"))
m.reset = false
m.submit = false

-- Service Status
s = m:section(SimpleSection, nil, translate("Service Status"))

local running = (sys.call("pidof dnscrypt-proxy >/dev/null") == 0)
local status_text = running and translate("Running") or translate("Stopped")
local status_color = running and "green" or "red"

o = s:option(DummyValue, "_status", translate("Status"))
o.rawhtml = true
o.value = string.format('<strong style="color: %s">%s</strong>', status_color, status_text)

if running then
	local pid = sys.exec("pidof dnscrypt-proxy"):match("%d+")
	o = s:option(DummyValue, "_pid", translate("PID"))
	o.value = pid
	
	-- Get memory usage
	if pid then
		local mem = sys.exec(string.format("cat /proc/%s/status | grep VmRSS | awk '{print $2}'", pid)):gsub("%s+", "")
		if mem and mem ~= "" then
			o = s:option(DummyValue, "_memory", translate("Memory Usage"))
			o.value = string.format("%.2f MB", tonumber(mem) / 1024)
		end
	end
end

-- Service Control
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

-- Configuration Info
s = m:section(SimpleSection, nil, translate("Configuration"))

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"
if fs.access(config_file) then
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	
	o = s:option(DummyValue, "_listen", translate("Listen Addresses"))
	o.value = sys.exec(helper .. " get_listen_addresses"):gsub("%s+", "")
	
	o = s:option(DummyValue, "_servers", translate("Server Names"))
	o.value = sys.exec(helper .. " get_server_names"):gsub("%s+", "")
	
	local odoh = sys.exec(helper .. " is_odoh_enabled"):gsub("%s+", "")
	o = s:option(DummyValue, "_odoh", translate("ODoH Enabled"))
	o.value = (odoh == "1") and translate("Yes") or translate("No")
	
	-- Validate configuration
	o = s:option(Button, "_validate", translate("Validate Configuration"))
	o.inputstyle = "reload"
	function o.write()
		local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		if code == 0 then
			m.message = translate("Configuration is valid")
		else
			m.errmessage = translate("Configuration has errors")
		end
	end
else
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. translate("Configuration file not found") .. '</span>'
end

-- Statistics
s = m:section(SimpleSection, nil, translate("Statistics"))

local log_file = "/var/log/dnscrypt-proxy.log"
if fs.access(log_file) then
	local queries = tonumber(sys.exec(string.format("grep -c 'Forwarding' %s 2>/dev/null", log_file)):gsub("%s+", "")) or 0
	local blocked = tonumber(sys.exec(string.format("grep -c 'Blocked' %s 2>/dev/null", log_file)):gsub("%s+", "")) or 0
	
	o = s:option(DummyValue, "_queries", translate("Total Queries"))
	o.value = queries
	
	o = s:option(DummyValue, "_blocked", translate("Blocked Queries"))
	o.value = blocked
	
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

local cache_dir = "/var/lib/dnscrypt-proxy"
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

o = s:option(Button, "_reload_sources", translate("Update Resolver Lists"))
o.inputstyle = "reload"
function o.write()
	sys.call("/usr/libexec/dnscrypt-proxy/helper reload_sources >/dev/null 2>&1 &")
	m.message = translate("Resolver lists update started. This may take a minute...")
end

-- Quick Links
s = m:section(SimpleSection, nil, translate("Quick Links"))

o = s:option(DummyValue, "_links", "")
o.rawhtml = true
o.value = [[
<ul>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "protocols") .. [[">]] .. translate("Protocol Settings") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "odoh") .. [[">]] .. translate("ODoH Configuration") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "toml") .. [[">]] .. translate("Advanced TOML Editor") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "resolvers") .. [[">]] .. translate("Resolver Management") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "filters") .. [[">]] .. translate("Filtering Rules") .. [[</a></li>
	<li><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. [[">]] .. translate("View Logs") .. [[</a></li>
</ul>
]]

return m
