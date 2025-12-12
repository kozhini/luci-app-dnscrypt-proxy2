-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("dnscrypt-toml", translate("DNSCrypt Proxy - TOML Editor"),
	translate("Direct edit of dnscrypt-proxy.toml configuration file. Advanced users only!"))

m.submit = translate("Save & Validate")
m.reset = translate("Reset")

local config_file = "/etc/dnscrypt-proxy2/dnscrypt-proxy.toml"

-- Check if file exists
if not fs.access(config_file) then
	s = m:section(SimpleSection)
	o = s:option(DummyValue, "_error", translate("Error"))
	o.rawhtml = true
	o.value = '<span style="color: red">' .. 
		translate("Configuration file not found:") .. " " .. config_file .. 
		'</span><br/>' ..
		translate("Please install dnscrypt-proxy2 package first.")
	return m
end

-- Warning
s = m:section(SimpleSection)
o = s:option(DummyValue, "_warning", "")
o.rawhtml = true
o.value = [[
<div class="alert-message warning">
	<strong>⚠️ ]] .. translate("Warning") .. [[:</strong><br/>
	]] .. translate("This is a direct editor for the TOML configuration file. Incorrect syntax will prevent dnscrypt-proxy from starting.") .. [[<br/>
	]] .. translate("It is recommended to use the simplified configuration pages for basic settings.") .. [[<br/>
	]] .. translate("Always validate your configuration before restarting the service.") .. [[
</div>
]]

-- Editor section
s = m:section(SimpleSection, nil, translate("Configuration File: ") .. config_file)

-- Backup info
local backup_file = config_file .. ".backup"
if fs.access(backup_file) then
	local mtime = fs.stat(backup_file, "mtime")
	local backup_age = os.difftime(os.time(), mtime)
	local age_str
	
	if backup_age < 3600 then
		age_str = string.format("%d minutes ago", math.floor(backup_age / 60))
	elseif backup_age < 86400 then
		age_str = string.format("%d hours ago", math.floor(backup_age / 3600))
	else
		age_str = string.format("%d days ago", math.floor(backup_age / 86400))
	end
	
	o = s:option(DummyValue, "_backup_info", translate("Last Backup"))
	o.value = age_str
end

-- TOML content editor
o = s:option(TextValue, "_content", "")
o.rows = 35
o.wrap = "off"
o.rmempty = false

function o.cfgvalue(self, section)
	return fs.readfile(config_file) or ""
end

function o.write(self, section, value)
	if value then
		-- Create backup
		local backup_file = config_file .. ".backup"
		local current = fs.readfile(config_file)
		if current then
			fs.writefile(backup_file, current)
		end
		
		-- Write new content
		fs.writefile(config_file, value:gsub("\r\n", "\n"))
	end
end

-- Validation section
s = m:section(SimpleSection, nil, translate("Validation & Testing"))

o = s:option(DummyValue, "_validate_info", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	]] .. translate("After saving, the configuration will be automatically validated.") .. [[<br/>
	]] .. translate("If validation fails, your changes will be saved but you should fix the errors before restarting the service.") .. [[
</div>
]]

-- Handle form submission
function m.handle(self, state, data)
	if state == FORM_VALID then
		-- Validate configuration
		local helper = "/usr/libexec/dnscrypt-proxy/helper"
		local valid_code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
		
		if valid_code == 0 then
			self.message = translate("Configuration saved and validated successfully!")
			
			-- Ask if user wants to restart service
			s = self:section(SimpleSection)
			o = s:option(Button, "_do_restart", translate("Restart Service Now"))
			o.inputstyle = "apply"
			function o.write()
				sys.call("/etc/init.d/dnscrypt-proxy2 restart >/dev/null 2>&1")
				luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "overview"))
			end
		else
			self.errmessage = translate("Configuration saved but validation failed!") .. 
				" " .. translate("Please check the syntax and try again.")
			
			-- Show validation output
			local validation_output = sys.exec("/usr/sbin/dnscrypt-proxy -config " .. 
				config_file .. " -check 2>&1")
			
			s = self:section(SimpleSection)
			o = s:option(DummyValue, "_validation_output", translate("Validation Output"))
			o.rawhtml = true
			o.value = '<pre style="background: #f5f5f5; padding: 10px; border: 1px solid #ddd; overflow: auto;">' ..
				validation_output .. '</pre>'
			
			-- Offer to restore backup
			if fs.access(config_file .. ".backup") then
				s = self:section(SimpleSection)
				o = s:option(Button, "_do_restore", translate("Restore Backup"))
				o.inputstyle = "reset"
				function o.write()
					local backup_content = fs.readfile(config_file .. ".backup")
					fs.writefile(config_file, backup_content)
					m.message = translate("Configuration restored from backup")
					luci.http.redirect(luci.dispatcher.build_url("admin", "services", "dnscrypt-proxy", "toml"))
				end
			end
		end
		
		return true
	end
	return true
end

-- Syntax highlighting hint
s = m:section(SimpleSection)
o = s:option(DummyValue, "_syntax_help", "")
o.rawhtml = true
o.value = [[
<div class="alert-message info">
	<strong>💡 ]] .. translate("Syntax Tips") .. [[:</strong>
	<ul>
		<li>]] .. translate("Strings must be in quotes: listen_addresses = ['127.0.0.1:53']") .. [[</li>
		<li>]] .. translate("Booleans are lowercase: require_dnssec = true") .. [[</li>
		<li>]] .. translate("Comments start with #") .. [[</li>
		<li>]] .. translate("Sections start with [section_name]") .. [[</li>
		<li>]] .. translate("Lists use square brackets: server_names = ['server1', 'server2']") .. [[</li>
	</ul>
	<p>]] .. translate("Documentation:") .. [[ <a href="https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Configuration" target="_blank">DNSCrypt Proxy Wiki</a></p>
</div>
]]

return m
