/* Timeseal module for Lua.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 * Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>
 * depends on ngboard's timesealplus which is:
 * Copyright (c) 2006 Bruce Horn
 * Distributed under the terms of the GNU General Public License v2
 */

#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <pwd.h>
#include <time.h>
#include <unistd.h>

#include <lua.h>
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 501
#include <lauxlib.h>
#endif

#include "timeseal.h"

static int l_encode(lua_State *L) {
    const char *str;
    char *buf;
    long int timestamp;
    size_t size;

    struct timeval tv;
    int added, len, padding;
    int i, j;
    int encode_offset;

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

    if (gettimeofday(&tv, NULL) == -1) {
        /* Push nil and error message */
        free(buf);
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    timestamp = (tv.tv_sec % 10000) * 1000 + tv.tv_usec / 1000;

    added = snprintf(buf + size, BUF_SIZE - size, "%c%ld%c", (char)24, timestamp, (char)25);
    if (0 >= added) {
        /* Push nil and error message */
        free(buf);
        lua_pushnil(L);
        lua_pushstring(L, "snprintf");
        return 2;
    }

    len = size + added;
    padding = 11 - ((len - 1) % 12);

    if (!random_initialized) {
        srandom(clock());
        random_initialized = 1;
    }

    while (padding > 0) {
        int r = random(); /* Fill with random padding */
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

    j = encode_offset = random() % ENCODELEN;

    for (i = 0; i < len; i++) {
        buf[i] |= (char)0x80;
        buf[i] ^= ENCODESTR[j];
        buf[i] -= 32;
        j++;
        if (j >= ENCODELEN) j = 0;
    }
    buf[len++] = (char)128 | encode_offset;
    buf[len++] = (char)10;
    buf[len] = '\0';

    lua_pushstring(L, buf);
    free(buf);
    return 1;
}

/* Return timeseal initialization string */
static int l_init_string(lua_State *L) {
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
        lua_pushstring(L, "insufficient memory");
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

LUALIB_API int luaopen_timeseal(lua_State *L) {
    luaL_openlib(L, MODNAME, R, 0);

    lua_pushliteral(L, "_VERSION");
    lua_pushliteral(L, VERSION);
    lua_settable(L, -3);

    return 1;
}

