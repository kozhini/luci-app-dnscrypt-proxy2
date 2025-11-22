-- Copyright (C) 2025 luci-app-dnscrypt-proxy2
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.dnscrypt-proxy", package.seeall)

local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local jsonc = require "luci.jsonc"

function index()
	if not fs.access("/etc/config/dnscrypt-proxy2") and 
	   not fs.access("/etc/dnscrypt-proxy2/dnscrypt-proxy.toml") then
		return
	end

	entry({"admin", "services", "dnscrypt-proxy"}, 
		alias("admin", "services", "dnscrypt-proxy", "overview"), 
		_("DNSCrypt Proxy"), 60)
	
	entry({"admin", "services", "dnscrypt-proxy", "overview"}, 
		cbi("dnscrypt-proxy/overview"), 
		_("Overview"), 10).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "config"}, 
		cbi("dnscrypt-proxy/config"), 
		_("Configuration"), 20).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "toml"}, 
		cbi("dnscrypt-proxy/toml"), 
		_("Edit TOML"), 30).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "resolvers"}, 
		cbi("dnscrypt-proxy/resolvers"), 
		_("Resolvers"), 40).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "odoh"}, 
		cbi("dnscrypt-proxy/odoh"), 
		_("ODoH Settings"), 50).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "filters"}, 
		cbi("dnscrypt-proxy/filters"), 
		_("Filters"), 60).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "logs"}, 
		cbi("dnscrypt-proxy/logs"), 
		_("Logs"), 70).leaf = true
	
	-- API endpoints
	entry({"admin", "services", "dnscrypt-proxy", "status"}, 
		call("action_status")).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "reload_sources"}, 
		call("action_reload_sources")).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "test_resolver"}, 
		call("action_test_resolver")).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "validate"}, 
		call("action_validate")).leaf = true
	
	entry({"admin", "services", "dnscrypt-proxy", "stats"}, 
		call("action_stats")).leaf = true
end

function action_status()
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local status = sys.exec(helper .. " get_status"):gsub("%s+", "")
	local pid = tonumber(sys.exec("pidof dnscrypt-proxy 2>/dev/null") or "0")
	
	local result = {
		running = (status == "running"),
		pid = pid,
		uptime = get_uptime(pid)
	}
	
	http.prepare_content("application/json")
	http.write_json(result)
end

function action_reload_sources()
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local result = sys.exec(helper .. " reload_sources"):gsub("%s+", "")
	
	http.prepare_content("application/json")
	http.write_json({
		success = (result == "success"),
		message = result
	})
end

function action_test_resolver()
	local server = http.formvalue("server")
	local domain = http.formvalue("domain") or "cloudflare.com"
	
	if not server or server == "" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			error = "Server name required"
		})
		return
	end
	
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local output = sys.exec(string.format("%s test_resolver '%s' '%s'", 
		helper, server, domain))
	
	http.prepare_content("application/json")
	http.write_json({
		success = true,
		output = output
	})
end

function action_validate()
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local code = tonumber(sys.exec(helper .. " validate_config"):gsub("%s+", ""))
	
	http.prepare_content("application/json")
	http.write_json({
		valid = (code == 0),
		code = code
	})
end

function action_stats()
	local helper = "/usr/libexec/dnscrypt-proxy/helper"
	local json_str = sys.exec(helper .. " get_stats")
	local stats = jsonc.parse(json_str)
	
	http.prepare_content("application/json")
	http.write_json(stats or {error = "Failed to parse stats"})
end

function get_uptime(pid)
	if not pid or pid == 0 then
		return 0
	end
	
	local stat_file = "/proc/" .. pid .. "/stat"
	if not fs.access(stat_file) then
		return 0
	end
	
	local stat = fs.readfile(stat_file)
	if not stat then
		return 0
	end
	
	-- Parse start time from /proc/pid/stat
	local starttime = stat:match("%d+%s+%b()%s+%S+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
	if not starttime then
		return 0
	end
	
	-- Get system uptime
	local uptime_str = fs.readfile("/proc/uptime")
	if not uptime_str then
		return 0
	end
	
	local sys_uptime = tonumber(uptime_str:match("^([%d%.]+)"))
	if not sys_uptime then
		return 0
	end
	
	-- Calculate process uptime
	local clock_ticks = 100  -- USER_HZ, typically 100
	local process_start = tonumber(starttime) / clock_ticks
	local uptime = sys_uptime - process_start
	
	return math.floor(uptime)
end
