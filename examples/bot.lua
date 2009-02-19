#!/usr/bin/env lua
-- A simple bot for FICS using LuaFics
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
-- Copyright 2008 Ali Polatel <polatel@itu.edu.tr>
-- Distributed under the terms of the GNU General Public License v2

require "fics"

bot = fics.client:new{ timeseal=true }
bot.ivars[fics.IV_SHOWSERVER] = true
bot.ivars[fics.IV_SEEKCA] = true

bot:register_callback("login", function (client)
    print "* Sending username"
    return client:send("HANDLE")
    end)
bot:register_callback("password", function (client)
    print "* Sending password"
    return client:send("PASSWORD")
    end)
bot:register_callback("session_start", function (client)
    print "* Session started"
    client:send("set interface lbot v" .. _VERSION, " (LuaFics v" .. fics._VERSION .. ")")
    end)
bot:register_callback("tell", function (client, line, handle, tags, message)
    print("* Received tell from " .. handle .. ": " .. message)
    return client:send("tell " .. handle .. " what's up?")
    end)

status, errmsg = bot:connect()
if status == nil then error(errmsg) end

status, errmsg = bot:loop()
if status == nil and errormsg ~= "closed" then
    error(errormsg)
else
    print "* Connection closed"
end

