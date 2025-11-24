-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("dnscrypt-logs", translate("DNSCrypt Proxy - Logs"))
m.reset = false
m.submit = false

-- Main log file
s = m:section(SimpleSection, nil, translate("Service Log"))

local log_file = "/var/log/dnscrypt-proxy.log"

-- Log controls
s = m:section(SimpleSection)

o = s:option(DummyValue, "_controls", "")
o.rawhtml = true

local controls = [[
<div style="margin-bottom: 15px;">
	<form method="post" style="display: inline;">
		<input type="hidden" name="action" value="refresh"/>
		<input type="submit" class="cbi-button cbi-button-reload" value="]] .. translate("Refresh") .. [["/>
	</form>
	
	<form method="post" style="display: inline; margin-left: 10px;">
		<input type="hidden" name="action" value="clear"/>
		<input type="submit" class="cbi-button cbi-button-reset" value="]] .. translate("Clear Log") .. [[" 
			onclick="return confirm(']] .. translate("Clear log file?") .. [[')"/>
	</form>
	
	<form method="post" style="display: inline; margin-left: 10px;">
		<input type="hidden" name="action" value="download"/>
		<input type="submit" class="cbi-button cbi-button-save" value="]] .. translate("Download") .. [["/>
	</form>
	
	<label style="margin-left: 15px;">
		]] .. translate("Lines:") .. [[
		<select name="lines" onchange="this.form.submit()">
			<option value="50">50</option>
			<option value="100" selected>100</option>
			<option value="250">250</option>
			<option value="500">500</option>
			<option value="1000">1000</option>
		</select>
	</label>
</div>
]]

o.value = controls

-- Log content
o = s:option(DummyValue, "_log", "")
o.rawhtml = true

local action = luci.http.formvalue("action")
local lines = luci.http.formvalue("lines") or "100"

if action == "clear" then
	fs.writefile(log_file, "")
	m.message = translate("Log cleared")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "logs"))
elseif action == "download" then
	if fs.access(log_file) then
		luci.http.header("Content-Disposition", "attachment; filename=dnscrypt-proxy.log")
		luci.http.prepare_content("text/plain")
		luci.http.write(fs.readfile(log_file))
	end
	return
end

local log_content = ""
if fs.access(log_file) then
	log_content = sys.exec(string.format("tail -n %s %s 2>/dev/null", lines, log_file))
	
	if log_content == "" then
		log_content = translate("Log file is empty")
	end
else
	log_content = translate("Log file not found")
end

o.value = '<pre style="background: #f5f5f5; padding: 10px; border: 1px solid #ccc; overflow: auto; max-height: 600px; font-family: monospace; font-size: 12px;">' ..
	log_content:gsub("<", "&lt;"):gsub(">", "&gt;") .. '</pre>'

-- Query log (if enabled)
s = m:section(SimpleSection, nil, translate("Query Log"))

local query_log_file = "/var/log/dnscrypt-proxy-queries.log"

if fs.access(query_log_file) then
	o = s:option(DummyValue, "_query_controls", "")
	o.rawhtml = true
	o.value = [[
	<form method="post" style="display: inline;">
		<input type="hidden" name="action" value="download_queries"/>
		<input type="submit" class="cbi-button cbi-button-save" value="]] .. translate("Download Query Log") .. [["/>
	</form>
	]]
	
	if action == "download_queries" then
		luci.http.header("Content-Disposition", "attachment; filename=dnscrypt-proxy-queries.log")
		luci.http.prepare_content("text/plain")
		luci.http.write(fs.readfile(query_log_file))
		return
	end
	
	o = s:option(DummyValue, "_query_log", "")
	o.rawhtml = true
	
	local query_content = sys.exec(string.format("tail -n 50 %s 2>/dev/null", query_log_file))
	o.value = '<pre style="background: #f5f5f5; padding: 10px; border: 1px solid #ccc; overflow: auto; max-height: 400px; font-family: monospace; font-size: 12px;">' ..
		query_content:gsub("<", "&lt;"):gsub(">", "&gt;") .. '</pre>'
else
	o = s:option(DummyValue, "_query_disabled", "")
	o.rawhtml = true
	o.value = '<em>' .. translate("Query logging is not enabled. Enable it in the TOML configuration under [query_log] section.") .. '</em>'
end

-- Statistics
s = m:section(SimpleSection, nil, translate("Log Statistics"))

if fs.access(log_file) then
	local total_lines = tonumber(sys.exec("wc -l < " .. log_file):gsub("%s+", "")) or 0
	local file_size = fs.stat(log_file, "size") or 0
	
	local errors = tonumber(sys.exec("grep -c 'ERROR' " .. log_file .. " 2>/dev/null"):gsub("%s+", "")) or 0
	local warnings = tonumber(sys.exec("grep -c 'WARNING' " .. log_file .. " 2>/dev/null"):gsub("%s+", "")) or 0
	
	o = s:option(DummyValue, "_stats", "")
	o.rawhtml = true
	o.value = string.format([[
	<table class="table">
		<tr><th>%s</th><td>%s</td></tr>
		<tr><th>%s</th><td>%.2f MB</td></tr>
		<tr><th>%s</th><td><span style="color: red;">%d</span></td></tr>
		<tr><th>%s</th><td><span style="color: orange;">%d</span></td></tr>
	</table>
	]], 
	translate("Total Lines"), total_lines,
	translate("File Size"), file_size / 1024 / 1024,
	translate("Errors"), errors,
	translate("Warnings"), warnings)
end

-- Log level control
s = m:section(SimpleSection, nil, translate("Log Level Configuration"))

o = s:option(DummyValue, "_level_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>Log Levels:</strong><br/>
	0=FATAL, 1=ERROR, 2=WARNING, 3=NOTICE, 4=INFO, 5=DEBUG, 6=TRACE<br/>
	<em>Change log_level in TOML editor. Recommended: 2 (WARNING) for production, 4 (INFO) for troubleshooting.</em>
</div>
]]

return m
