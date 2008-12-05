/* Utilities for LuaFics.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2008 Ali Polatel <polatel@gmail.com>
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

#ifndef LUAFICS_GUARD_FICSUTILS_H
#define LUAFICS_GUARD_FICSUTILS_H 1

#define MODNAME "ficsutils"
#define VERSION "0.02"

#define BUF_SIZE 8192
#define TIMESTAMP_SIZE 64

/* Encryption strings used by FICS */
#define MAGICGSTR "^%[G%]"
#define GRESPONSE "\0029"

static char ENCODESTR[] = "Timestamp (FICS) v1.0 - programmed by Henrik Gram.";
static int ENCODELEN = sizeof(ENCODESTR)/sizeof(ENCODESTR[0]) - 1; /* sizeof includes trailing \0 */

static char FILLER[] = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
static int FILLERLEN = sizeof(FILLER)/sizeof(FILLER[0]) - 1;

static int random_initialized = 0;

/* Prototypes */
static int l_ts_encode(lua_State *L);
static int l_ts_init_string(lua_State *L);
static int l_titles_totable(lua_State *L);
LUALIB_API int luaopen_ficsutils(lua_State *L);

static const luaL_reg R[] = {
    {"ts_encode",          l_ts_encode},
    {"ts_init_string",     l_ts_init_string},
    {"titles_totable",     l_titles_totable},
    {NULL,              NULL}
};

#endif /* LUAFICS_GUARD_FICSUTILS_H */

