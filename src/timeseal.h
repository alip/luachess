/* Timeseal module for Lua.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 * Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>
 * depends on ngboard's timesealplus which is:
 * Copyright (c) 2006 Bruce Horn
 * Distributed under the terms of the GNU General Public License v2
 */

#define MODNAME "timeseal"
#define VERSION "0.01"

#define BUF_SIZE 8192
#define TIMESTAMP_SIZE 64

/* Encryption strings used by FICS */
static char ENCODESTR[] = "Timestamp (FICS) v1.0 - programmed by Henrik Gram.";
static int ENCODELEN = sizeof(ENCODESTR)/sizeof(ENCODESTR[0]) - 1; /* sizeof includes trailing \0 */
/* static char MAGICGSTR[] = "\n\r[G]\n\r";
static int MAGICGLEN = sizeof(MAGICGSTR)/sizeof(MAGICGSTR[0]) - 1;

static char GRESPONSE[] = "\0029";
static int GRESPONSELEN = sizeof(GRESPONSE)/sizeof(GRESPONSE[0]) -1; */

static char FILLER[] = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
static int FILLERLEN = sizeof(FILLER)/sizeof(FILLER[0]) - 1;

static int random_initialized = 0;

/* Prototypes */
static int l_encode(lua_State *L);
static int l_init_string(lua_State *L);
LUALIB_API int luaopen_timeseal(lua_State *L);

static const luaL_reg R[] = {
    {"encode",          l_encode},
    {"init_string",     l_init_string},
    {NULL,              NULL}
};

