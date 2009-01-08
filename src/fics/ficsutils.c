/* Utilities for LuaChess.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2008, 2009 Ali Polatel <polatel@gmail.com>
 * depends on ngboard's timesealplus which is:
 * Copyright (c) 2006 Bruce Horn
 *
 * This file is part of LuaChess. LuaChess is free software; you can
 * redistribute it and/or modify it under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.

 * LuaChess is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.

 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <stdlib.h>

#include "config.h"

#include <errno.h>
#include <string.h> /* strerror() */

#include <sys/time.h> /* gettimeofday() */
#include <time.h>

#include <sys/types.h>
#include <unistd.h> /* geteuid() */
#include <pwd.h> /*  getpwuid() */
#include <sys/utsname.h> /* uname() */

#include "lua.h"
#include "lauxlib.h"

#define BUF_SIZE 8192
#define TIMESTAMP_SIZE 64

/* Encryption strings used by FICS */
#define TIMESEAL_MAGICGSTR "^%[G%]"
#define TIMESEAL_GRESPONSE "\0029"

#define ENCODESTR "Timestamp (FICS) v1.0 - programmed by Henrik Gram."
#define ENCODELEN 50

#define FILLER  "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
#define FILLERLEN 62

static int timeseal_encode(lua_State *L) {
    const char *str;
    char *buf;
    long int timestamp;
    size_t size;

    struct timeval tv;
    int added, len, padding;
    int i, j;
    int encode_offset;

    /* Support for testing */
    int testing = lua_toboolean(L, 2);

    str = luaL_checkstring(L, 1);
    size = lua_strlen(L, 1);

    buf = (char *) malloc(BUF_SIZE * sizeof(char));
    if (buf == NULL) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, "malloc");
        return 2;
    }
    strncpy(buf, str, size);

    if (!testing) {
        if (gettimeofday(&tv, NULL) == -1) {
            /* Push nil and error message */
            free(buf);
            lua_pushnil(L);
            lua_pushstring(L, strerror(errno));
            return 2;
        }
        timestamp = (tv.tv_sec % 10000) * 1000 + tv.tv_usec / 1000;
    }
    else
        timestamp = 0;

    added = snprintf(buf + size, BUF_SIZE - size, "%c%ld%c",
                        (char)24, timestamp, (char)25);
    if (0 >= added) {
        /* Push nil and error message */
        free(buf);
        lua_pushnil(L);
        lua_pushstring(L, "snprintf");
        return 2;
    }

    len = size + added;
    padding = 11 - ((len - 1) % 12);

    while (padding > 0) {
        /* Fill with random padding */
        int r = testing ? 0 : rand();
        r %= FILLERLEN;
        buf[len++] = FILLER[r];
        padding--;
    }

    /* Shuffle bytes */
    for (i = 0; i < len; i += 12) {
        char tmp = buf[i + 11];
        buf[i + 11] = buf[i];
        buf[i] = tmp;
        char tmp2 = buf[i + 9];
        buf[i + 9] = buf[i + 2];
        buf[i + 2] = tmp2;
        char tmp3 = buf[i + 7];
        buf[i + 7] = buf[i + 4];
        buf[i + 4] = tmp3;
    }

    if (testing)
        j = encode_offset = 0;
    else
        j = encode_offset = rand() % ENCODELEN;

    for (i = 0; i < len; i++) {
        buf[i] |= (char)0x80;
        buf[i] ^= ENCODESTR[j];
        buf[i] -= 32;
        j++;
        if (j >= ENCODELEN) j = 0;
    }
    buf[len++] = (char)128 | encode_offset;
    buf[len++] = (char)10;

    lua_pushlstring(L, buf, len);
    free(buf);
    return 1;
}

/* Return timeseal initialization string */
static int timeseal_init_string(lua_State *L) {
    struct utsname un;
    uid_t euid;
    struct passwd *pwd;
    char *buf;
    int len;

    if (uname(&un) == -1) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    euid = geteuid();

    /* getpwuid() needs errno to be set to 0 before the call */
    errno = 0;
    pwd = getpwuid(euid);
    if (pwd == NULL) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    buf = (char *) malloc(BUF_SIZE * sizeof(char));
    if (buf == NULL) {
        /* Push nil and error message */
        lua_pushnil(L);
        lua_pushstring(L, "malloc");
        return 2;
    }

    len = snprintf(buf, BUF_SIZE, "TIMESTAMP|%s|%s %s %s %s %s|", pwd->pw_name,
            un.sysname, un.nodename, un.release, un.version, un.machine);
    if (0 >= len) {
        /* Push nil and error message */
        free(buf);
        lua_pushnil(L);
        lua_pushstring(L, "snprintf");
        return 2;
    }

    lua_pushstring(L, buf);
    free(buf);
    return 1;
}

static int titles_totable(lua_State *L) {
    int index, titles;

#define TITLE_UNREGISTERED 0x01
#define TITLE_COMPUTER 0x02
#define TITLE_GM 0x04
#define TITLE_IM 0x08
#define TITLE_FM 0x10
#define TITLE_WGM 0x20
#define TITLE_WIM 0x40
#define TITLE_WFM 0x80

    titles = luaL_checkinteger(L, 1);

    index = 1;
    lua_newtable(L);

    if ((titles & TITLE_UNREGISTERED) == TITLE_UNREGISTERED) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "U");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_COMPUTER) == TITLE_COMPUTER) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "C");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_GM) == TITLE_GM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "GM");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_IM) == TITLE_IM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "IM");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_FM) == TITLE_FM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "FM");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_WGM) == TITLE_WGM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "WGM");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_WIM) == TITLE_WIM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "WIM");
        lua_settable(L, -3);
        index++;
    }
    if ((titles & TITLE_WFM) == TITLE_WFM) {
        lua_pushinteger(L, index);
        lua_pushstring(L, "WFM");
        lua_settable(L, -3);
    }
    return 1;
}

static const luaL_reg ficsutils_global[] = {
    {"timeseal_encode",          timeseal_encode},
    {"timeseal_init_string",     timeseal_init_string},
    {"titles_totable",           titles_totable},
    {NULL,              NULL}
};

LUALIB_API int luaopen_ficsutils(lua_State *L) {
    srand(clock());
    luaL_register(L, "ficsutils", ficsutils_global);

    lua_pushliteral(L, "_VERSION");
    lua_pushstring(L, PACKAGE_NAME "-" VERSION);
    lua_settable(L, -3);

    lua_pushliteral(L, "TIMESEAL_MAGICGSTR");
    lua_pushstring(L, TIMESEAL_MAGICGSTR);
    lua_settable(L, -3);

    lua_pushliteral(L, "TIMESEAL_GRESPONSE");
    lua_pushstring(L, TIMESEAL_GRESPONSE);
    lua_settable(L, -3);

    return 1;
}
