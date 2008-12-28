#!/usr/bin/env lua
-- Example showing how to remove callbacks
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
-- Copyright 2008 Ali Polatel <polatel@gmail.com>
-- Distributed under the terms of the GNU General Public License v2

require "fics"

client = fics.client:new{}

-- Login
client:register_callback("login", function (client)
    print"Sending login"
    client:send"guest"
    end)
client:register_callback("press_return", function (client, line, handle)
    print("Logging in with handle '" .. handle .. "'")
    client:send""
    end)

-- client:register_callback() returns a callback index.
-- This index can be used to remove the callback.
cindex = client:register_callback("tell",
    function (client, line, handle)
        client:send("tell " .. handle .. " hey how are you doing today? :)")
    end)
client:register_callback("tell",
    function (client, line, handle, tags, message)
        if string.find(message, "^remove") then
            if client:remove_callback(cindex) then
                client:send("tell " .. handle .. " callback removed")
            else
                client:send("tell " .. handle .. " problem removing callback")
            end
        end
    end)

-- Connect
status, errmsg = client:connect()
if status == nil then error(errmsg) end

-- Start the loop
client:loop()

