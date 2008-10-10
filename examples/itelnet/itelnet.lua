#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
--[[
  Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>

  This file is part of LuaFics. LuaFics is free software; you can redistribute
  it and/or modify it under the terms of the GNU General Public License version
  2, as published by the Free Software Foundation.

  LuaFics is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
  Place, Suite 330, Boston, MA  02111-1307  USA
--]]

--- ITelnet, a timeseal replacement with support for hooks.

require("lfs")
require("fics")
require("iutils")

-- Configuration
USE_TIMESEAL = true
TIMESTAMP_FORMAT = "%H%M%S"
SEND_PROMPT = false
BLOCK_ISET = true
BLOCK_SET_INTERFACE = true

if table.maxn(arg) ~= 2 then
    io.stderr:write("Usage: " .. arg[0] .. " host port\n")
    os.exit(1)
else
    host = arg[1]
    port = arg[2]
end

client = fics.client:new{ timeseal = USE_TIMESEAL }
client.ivars[fics.IV_STARTPOS] = true
-- Xboard needs IV_MS set to true and Eboard needs it set to false.
client.ivars[fics.IV_MS] = false

function log(...)
    io.stderr:write("> " .. os.date(TIMESTAMP_FORMAT) .. " " .. table.concat(arg) .. "\n")
end

local SENDING_PASSWORD = false

--{{{ Callbacks
client:register_callback("line", function (client, group, line)
    if group == "login" then
        if not client._ivars_sent then
            -- Workaround to not confuse xboard while LuaFics sends interface
            -- variables.
            return
        else
            io.write(line)
        end
    elseif group == "password" then
        io.write(line)
    elseif not SEND_PROMPT and group == "prompt" then
        return
    else
        io.write(line .. "\n")
    end
    io.flush()
    end)
client:register_callback("password", function(client, line)
    SENDING_PASSWORD = true
    end)
--}}}
--{{{ Hooks
--- mkdir dir if it doesn't exist.
function xmkdir(dir)
    if not lfs.attributes(dir) then
        status, errmsg = lfs.mkdir(dir)
        if status == nil then
            error(errmsg)
        end
    end

    return true
end

configdir = nil
hookdir = nil

function prepare_user_dirs()
    if os.getenv("ITELNET_DIR") then
        configdir = os.getenv("ITELNET_DIR")
        hookdir = configdir .. "/hooks"
    elseif os.getenv("HOME") then
        configdir = os.getenv("HOME") .. "/.itelnet"
        hookdir = configdir .. "/hooks"
    else
        error("Neither ITELNET_DIR nor HOME is set")
    end

    xmkdir(configdir)
    xmkdir(hookdir)
end

function register_user_hooks(client)
    for entry in lfs.dir(hookdir) do
        if string.find(entry ,"hook_.*%.lua$") then
            local hook = hookdir .. "/" .. entry
            local hookname, cbfunc = dofile(hook)

            assert(type(hookname) == "string",
                "The first value returned by hook " .. entry .. " is not a string")
            assert(type(cbfunc) == "function" or type(cbfunc) == "thread",
                "The second value return by hook " .. entry .. " is neither a function nor a coroutine.")

            client:register_callback(hookname, cbfunc)
            log("Registered " .. entry .. " to group " .. hookname .. ".")
        end
    end
end
--}}}

prepare_user_dirs()
register_user_hooks(client)

client:connect(host, port)
iutils.unblock_stdin()

client.sock:settimeout(1)

while true do
    if SENDING_PASSWORD then
        iutils.set_echo(false)
    else
        iutils.set_echo(true)
        SENDING_PASSWORD = false
    end
    line = io.read()
    if line ~= nil then
        if (not BLOCK_ISET or not string.match(line, "^%$?iset")) and
            (not BLOCK_SET_INTERFACE or not string.match(line, "^%$?set interface")) then
            _, errmsg = client:send(line)
            if errmsg ~= nil then error(errmsg) end
        end
    end

    status, errmsg = client:loop(1)
    if status == nil then
        if errormsg ~= "closed" then
            error(errormsg)
        else
            log("Connection closed")
            os.exit()
        end
    end
end

