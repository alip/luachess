/* Utilities for ITelnet.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>
 * depends on ngboard's timesealplus which is:
 * Copyright (c) 2006 Bruce Horn
 *
 * This file is part of LuaFics. LuaFics is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License
 * version 2, as published by the Free Software Foundation.

 * LuaFics is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.

 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>

#include <lua.h>
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 501
#include <lauxlib.h>
#endif

#define MODNAME "iutils"
#define VERSION "0.01"

static int l_set_echo(lua_State *L) {
    int ret, state;
    struct termios pios;
    int infd;

    infd = fileno(stdin);
    memset(&pios, 0, sizeof(pios));

    ret = tcgetattr(infd, &pios);
    if (ret < 0) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, "tcgetattr");
        return 2;
    }

    state = lua_toboolean(L, 1);
    if (state)
        pios.c_lflag |= ECHO;
    else
        pios.c_lflag &= ~ECHO;

    ret = tcsetattr(infd, TCSADRAIN, &pios);
    lua_pushinteger(L, ret);
    return 1;
}

static int l_unblock_stdin(lua_State *L) {
    if (fcntl(fileno(stdin), F_SETFL, O_NONBLOCK) == -1) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    lua_pushboolean(L, 1);
    return 1;
}

static const luaL_reg R[] = {
    {"unblock_stdin",       l_unblock_stdin},
    {"set_echo",            l_set_echo},
    {NULL,                  NULL}
};

LUALIB_API int luaopen_iutils(lua_State *L) {
    luaL_openlib(L, MODNAME, R, 0);

    lua_pushliteral(L, "_VERSION");
    lua_pushstring(L, VERSION);
    lua_settable(L, -3);

    return 1;
}

