-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("dnscrypt-logs", translate("DNSCrypt Proxy - Logs"),
	translate("View and manage DNSCrypt Proxy logs"))

m.reset = false
m.submit = false

local helper = "/usr/libexec/dnscrypt-proxy/helper"
local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"

-- Parse log file path from TOML
local function get_log_file()
	if not fs.access(config_file) then
		return "/var/log/dnscrypt-proxy.log"
	end
	
	local content = fs.readfile(config_file)
	local log_path = content:match("log_file%s*=%s*['\"]([^'\"]+)['\"]")
	return log_path or "/var/log/dnscrypt-proxy.log"
end

local log_file = get_log_file()

-- Service status
s = m:section(SimpleSection, nil, translate("Service Status"))

local running = (sys.call("pidof dnscrypt-proxy >/dev/null") == 0)
local status_text = running and translate("Running") or translate("Stopped")
local status_color = running and "green" or "red"

o = s:option(DummyValue, "_status", translate("Status"))
o.rawhtml = true
o.value = string.format('<strong style="color: %s">%s</strong>', status_color, status_text)

-- Log statistics
s = m:section(SimpleSection, nil, translate("Log Statistics"))

if fs.access(log_file) then
	local log_size = fs.stat(log_file, "size") or 0
	local mtime = fs.stat(log_file, "mtime")
	
	o = s:option(DummyValue, "_log_file", translate("Log File"))
	o.value = log_file
	
	o = s:option(DummyValue, "_log_size", translate("Size"))
	o.value = string.format("%.2f MB", log_size / 1024 / 1024)
	
	if mtime then
		local age = os.time() - mtime
		local age_str
		if age < 60 then
			age_str = string.format("%d seconds ago", age)
		elseif age < 3600 then
			age_str = string.format("%d minutes ago", math.floor(age / 60))
		elseif age < 86400 then
			age_str = string.format("%d hours ago", math.floor(age / 3600))
		else
			age_str = string.format("%d days ago", math.floor(age / 86400))
		end
		
		o = s:option(DummyValue, "_last_modified", translate("Last Modified"))
		o.value = age_str
	end
	
	-- Query statistics
	local queries = tonumber(sys.exec(string.format("grep -c 'Forwarding' %s 2>/dev/null || echo 0", log_file)):gsub("%s+", "")) or 0
	local blocked = tonumber(sys.exec(string.format("grep -c 'Blocked' %s 2>/dev/null || echo 0", log_file)):gsub("%s+", "")) or 0
	local errors = tonumber(sys.exec(string.format("grep -c 'ERROR' %s 2>/dev/null || echo 0", log_file)):gsub("%s+", "")) or 0
	
	o = s:option(DummyValue, "_queries", translate("Total Queries"))
	o.value = tostring(queries)
	
	o = s:option(DummyValue, "_blocked", translate("Blocked Queries"))
	o.value = tostring(blocked)
	
	if queries > 0 then
		o = s:option(DummyValue, "_block_rate", translate("Block Rate"))
		o.value = string.format("%.2f%%", (blocked / queries) * 100)
	end
	
	o = s:option(DummyValue, "_errors", translate("Errors"))
	o.value = tostring(errors)
else
	o = s:option(DummyValue, "_no_log", "")
	o.rawhtml = true
	o.value = '<div class="alert-message warning">' ..
		translate("Log file not found:") .. " " .. log_file ..
		'</div>'
end

-- Log viewing options
s = m:section(SimpleSection, nil, translate("View Logs"))

o = s:option(Button, "_view_last", translate("Show Last 100 Lines"))
o.inputstyle = "apply"
function o.write()
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. "?action=view_last&lines=100")
end

o = s:option(Button, "_view_errors", translate("Show Errors Only"))
o.inputstyle = "apply"
function o.write()
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. "?action=view_errors")
end

o = s:option(Button, "_view_blocked", translate("Show Blocked Queries"))
o.inputstyle = "apply"
function o.write()
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs") .. "?action=view_blocked")
end

o = s:option(Button, "_clear_log", translate("Clear Log"))
o.inputstyle = "reset"
function o.write()
	if fs.access(log_file) then
		fs.writefile(log_file, "")
		sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
		m.message = translate("Log cleared and service restarted")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs"))
end

-- Handle log viewing
local action = luci.http.formvalue("action")
local log_content = ""

if action == "view_last" and fs.access(log_file) then
	local lines = tonumber(luci.http.formvalue("lines")) or 100
	log_content = sys.exec(string.format("tail -n %d %s 2>/dev/null", lines, log_file))
	m.description = string.format(translate("Showing last %d lines"), lines)
	
elseif action == "view_errors" and fs.access(log_file) then
	log_content = sys.exec(string.format("grep -i 'error\\|warning\\|fail' %s 2>/dev/null | tail -n 500", log_file))
	m.description = translate("Showing errors and warnings (last 500)")
	
elseif action == "view_blocked" and fs.access(log_file) then
	log_content = sys.exec(string.format("grep -i 'blocked' %s 2>/dev/null | tail -n 500", log_file))
	m.description = translate("Showing blocked queries (last 500)")
end

-- Display log content
if log_content and log_content ~= "" then
	s = m:section(SimpleSection, nil, translate("Log Content"))
	
	o = s:option(DummyValue, "_log_content", "")
	o.rawhtml = true
	
	-- Colorize log levels
	log_content = log_content:gsub("(ERROR[^\n]*)", '<span style="color: red; font-weight: bold;">%1</span>')
	log_content = log_content:gsub("(WARNING[^\n]*)", '<span style="color: orange; font-weight: bold;">%1</span>')
	log_content = log_content:gsub("(Blocked[^\n]*)", '<span style="color: blue;">%1</span>')
	log_content = log_content:gsub("(Forwarding[^\n]*)", '<span style="color: green;">%1</span>')
	
	o.value = '<pre style="background: #f5f5f5; padding: 10px; border: 1px solid #ddd; overflow: auto; max-height: 600px; font-size: 12px; font-family: monospace;">' ..
		log_content .. '</pre>'
end

-- Log configuration
s = m:section(SimpleSection, nil, translate("Log Settings"))

o = s:option(DummyValue, "_log_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>ℹ️ Log Configuration:</strong>
	<p>To change log settings (log level, log file path, syslog), edit the TOML configuration:</p>
	<ul>
		<li><code>log_level</code> - 0 (Fatal) to 6 (Trace)</li>
		<li><code>log_file</code> - Path to log file</li>
		<li><code>use_syslog</code> - Send logs to syslog instead of file</li>
	</ul>
	<p><a href="]] .. luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "toml") .. [[">Edit TOML Configuration →</a></p>
</div>
]]

-- Real-time log viewing tip
s = m:section(SimpleSection, nil, translate("Real-time Monitoring"))

o = s:option(DummyValue, "_realtime_tip", "")
o.rawhtml = true
o.value = string.format([[
<div class="alert-message info">
	<strong>💡 Tip:</strong> For real-time log monitoring, use SSH:<br/>
	<code>tail -f %s</code>
</div>
]], log_file)

return m
