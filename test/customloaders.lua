#!/usr/bin/env lua
-- Custom package loaders to make the tests work fine.
-- vim: set et sts=4 sw=4 ts=4 fdm=marker:

-- Function that strips module components i.e.:
-- chess.bitboard -> bitboard and can be loaded from a bitboard.so
-- which doesn't have to be in a directory named chess/
-- reference: http://lua-users.org/wiki/BinaryModulesLoader
function stripping_binary_load(modulename)
    local errmsg = ""
    -- Find DLL
    local symbolname = string.gsub(modulename, "%.", "_")
    local modulepath = string.match(modulename, "[^%.]+$")
    for path in string.gmatch(package.cpath, "([^;]+)") do
        local filename = string.gsub(path, "%?", modulepath)
        local file = io.open(filename, "rb")
        if file then
            file:close()
            -- Load and return the module loader
            local loader,msg = package.loadlib(filename, "luaopen_"..symbolname)
            if not loader then
                error("error loading module '" .. modulename .. "' from file '" ..
                    path .. "':\n\t" .. msg, 3)
            end
            return loader
        end
        errmsg = errmsg .. "\n\tno file '" .. filename .. "' (checked with custom loader)"
    end
    return errmsg
end

-- Same for lua modules.
-- reference: http://lua-users.org/wiki/LuaModulesLoader
function stripping_load(modulename)
    local errmsg = ""
    -- Find source
    print(modulename)
    local modulepath = string.match(modulename, "[^%.]+$")
    for path in string.gmatch(package.path, "([^;]+)") do
        local filename = string.gsub(path, "%?", modulepath)
        local file = io.open(filename, "rb")
        if file then
            file:close()
            -- Compile and return the module
            return assert(loadfile(filename))
        end
        errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
    end
    return errmsg
end

-- Install the loaders
table.insert(package.loaders, 2, stripping_load)
table.insert(package.loaders, 3, stripping_binary_load)
