/* Bitboard module for LuaChess.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
 *  based in part upon GNU Chess 5.0 which is
 *  Copyright (c) 1999-2002 Free Software Foundation, Inc.
 *
 * This file is part of LuaChess. LuaChess is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License
 * version 2, as published by the Free Software Foundation.

 * LuaChess is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.

 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <errno.h>
#include <stdio.h> /* for snprintf */
#include <stdlib.h> /* for strtoull */
#include <string.h> /* for strerror */

#include "lua.h"
#include "lauxlib.h"

#include "bitboard.h"

#define NBITS 16
static unsigned char lz_array[65536];

/* Prototypes */
LUALIB_API int luaopen_chess_bitboard(lua_State *L);

/*  Creates the lz_array. This array is used when the position of the leading
 *  non-zero bit is required.  The convention used is that the leftmost bit is
 *  considered as position 0 and the rightmost bit position 63.
 */
static void init_lz_array(void) {
   int i, j, s, n;

   s = n = 1;
   for (i = 0; i < NBITS; i++)
   {
      for (j = s; j < s + n; j++)
         lz_array[j] = NBITS - 1 - i;
      s += n;
      n += n;
   }
}

/* Returns the leading bit in a bitboard.
 * Leftmost bit is 0 and rightmost bit is 63.
 * Thanks to Robert Hyatt for this algorithm.
 */
static inline unsigned char leadz(U64 b) {
  if (b >> 48) return lz_array[b >> 48];
  if (b >> 32) return lz_array[b >> 32] + 16;
  if (b >> 16) return lz_array[b >> 16] + 32;
  return lz_array[b] + 48;
}

#define trailz(b) (leadz ((b) & ((~b) + 1)))

/* Initialization and display */
static int bitboard_new(lua_State *L) {
    U64 *bb;
#ifdef HAVE_STRTOULL
    int base, type;

    /* Accept strings as argument as well as integers and use strtoull() */
    type = lua_type(L, 1);
    switch (type) {
        case LUA_TNUMBER:
        case LUA_TSTRING:
            bb = (U64 *)lua_newuserdata(L, sizeof(U64));
            luaL_getmetatable(L, BITBOARD_T);
            lua_setmetatable(L, -2);
            if (LUA_TNUMBER == type)
                *bb = (U64) lua_tonumber(L, 1);
            else {
                base = (lua_isnumber(L, 2)) ? lua_tointeger(L, 2) : STRTOULL_DEFAULT_BASE;

                errno = 0;
                *bb = strtoull(lua_tostring(L, 1), NULL, base);
                if (0 != errno) {
                    /* Pop the userdata, push nil and error message */
                    lua_pop(L, 1);
                    lua_pushnil(L);
                    lua_pushstring(L, strerror(errno));
                    return 2;
                }
            }
            break;
        default:
            return luaL_argerror(L, 1, "integer or string expected");
    }
#else
    double n;

    n = luaL_checknumber(L, 1);
    bb = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);
    *bb = (U64) n;
#endif
    return 1;
}

#ifdef HAVE_SNPRINTF
#define BITBOARD_MAX 4096 /* for snprintf */
static int bitboard_tostring(lua_State *L) {
    char bbstr[BITBOARD_MAX];
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    snprintf(bbstr, BITBOARD_MAX, "bitboard: 0x%018llx", *bb);
    lua_pushstring(L, bbstr);
    return 1;
}
#endif

/* Copying */
static int bitboard_copy(lua_State *L) {
    U64 *bb, *ret;

    bb = luaL_checkudata(L, 1, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb;
    return 1;
}

/* Setting, testing bits  */
static int bitboard_setbit(lua_State *L) {
    int ind, sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    for (ind = 2; !lua_isnone(L, ind); ind++) {
        sq = luaL_checkinteger(L, ind);
        if (sq < 0 || sq > 63)
            return luaL_argerror(L, ind, "invalid square");
        *bb |= (1ULL << sq);
    }
    return 0;
}

static int bitboard_clrbit(lua_State *L) {
    int ind, sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    for (ind = 2; !lua_isnone(L, ind); ind++) {
        sq = luaL_checkinteger(L, ind);
        if (sq < 0 || sq > 63)
            return luaL_argerror(L, ind, "invalid square");
        *bb &= ~(1ULL << sq);
    }
    return 0;
}

static int bitboard_tglbit(lua_State *L) {
    int ind, sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    for (ind = 2; !lua_isnone(L, ind); ind++) {
        sq = luaL_checkinteger(L, ind);
        if (sq < 0 || sq > 63)
            return luaL_argerror(L, ind, "invalid square");
        *bb ^= (1ULL << sq);
    }
    return 0;
}

static int bitboard_tstbit(lua_State *L) {
    int sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    sq = luaL_checkinteger(L, 2);

    if (sq < 0 || sq > 63)
        return luaL_argerror(L, 2, "invalid square");

    if ((*bb & (1ULL << sq)) == 0)
        lua_pushboolean(L, 0);
    else
        lua_pushboolean(L, 1);
    return 1;
}

/* Functions suffixed 63 treat the leftmost bit as position 0
 * and rightmost bit as position 63
 */
static int bitboard_setbit63(lua_State *L) {
    int ind, sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    for (ind = 2; !lua_isnone(L, ind); ind++) {
        sq = luaL_checkinteger(L, ind);
        if (sq < 0 || sq > 63)
            return luaL_argerror(L, ind, "invalid square");
        *bb |= (1ULL << 63) >> sq;
    }
    return 0;
}

static int bitboard_clrbit63(lua_State *L) {
    int ind, sq;
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    for (ind = 2; !lua_isnone(L, ind); ind++) {
        sq = luaL_checkinteger(L, ind);
        if (sq < 0 || sq > 63)
            return luaL_argerror(L, ind, "invalid square");
        *bb &= ~((1ULL << 63) >> sq);
    }
    return 0;
}

/* Equality testing */
static int bitboard_eq(lua_State *L) {
    U64 *bb1, *bb2;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    if (*bb1 == *bb2)
        lua_pushboolean(L, 1);
    else
        lua_pushboolean(L, 0);
    return 1;
}

static int bitboard_lt(lua_State *L) {
    U64 *bb1, *bb2;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    if (*bb1 < *bb2)
        lua_pushboolean(L, 1);
    else
        lua_pushboolean(L, 0);
    return 1;
}

static int bitboard_le(lua_State *L) {
    U64 *bb1, *bb2;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    if (*bb1 <= *bb2)
        lua_pushboolean(L, 1);
    else
        lua_pushboolean(L, 0);
    return 1;
}

/* Arithmetic operations on bitboards.
 * + is bitwise or
 * - is bitwise and
 * % is bitwise xor
 * * is left shift
 * / is right shift
 * unary - is bitwise NOT
 */
static int bitboard_or(lua_State *L) {
    U64 *bb1, *bb2, *ret;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb1 | *bb2;
    return 1;
}

static int bitboard_and(lua_State *L) {
    U64 *bb1, *bb2, *ret;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb1 & *bb2;
    return 1;
}

static int bitboard_xor(lua_State *L) {
    U64 *bb1, *bb2, *ret;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bb2 = luaL_checkudata(L, 2, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb1 ^ *bb2;
    return 1;
}

static int bitboard_lshift(lua_State *L) {
    int bit;
    U64 *bb1, *ret;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bit = luaL_checkinteger(L, 2);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb1 << bit;
    return 1;
}

static int bitboard_rshift(lua_State *L) {
    int bit;
    U64 *bb1, *ret;

    bb1 = luaL_checkudata(L, 1, BITBOARD_T);
    bit = luaL_checkinteger(L, 2);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = *bb1 >> bit;
    return 1;
}

static int bitboard_not(lua_State *L) {
    U64 *bb, *ret;

    bb = luaL_checkudata(L, 1, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    *ret = ~(*bb);
    return 1;
}

/* Miscallenous functions */
static int bitboard_leadz(lua_State *L) {
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    lua_pushinteger(L, leadz(*bb));
    return 1;
}

static int bitboard_trailz(lua_State *L) {
    U64 *bb;

    bb = luaL_checkudata(L, 1, BITBOARD_T);
    lua_pushinteger(L, trailz(*bb));
    return 1;
}

static const struct luaL_reg bblib_global[] = {
    {"bb", bitboard_new},
    {NULL, NULL}
};

static const struct luaL_reg bblib_bitboard[] = {
    {"__eq", bitboard_eq},
    {"__lt", bitboard_lt},
    {"__le", bitboard_le},
    {"__add", bitboard_or},
    {"__sub", bitboard_and},
    {"__mul", bitboard_lshift},
    {"__div", bitboard_rshift},
    {"__mod", bitboard_xor},
    {"__unm", bitboard_not},
#ifdef HAVE_SNPRINTF
    {"__tostring", bitboard_tostring},
#endif
    {"copy", bitboard_copy},
    {"setbit", bitboard_setbit},
    {"setbit63", bitboard_setbit63},
    {"clrbit", bitboard_clrbit},
    {"clrbit63", bitboard_clrbit63},
    {"tglbit", bitboard_tglbit},
    {"tstbit", bitboard_tstbit},
    {"leadz", bitboard_leadz},
    {"trailz", bitboard_trailz},
    {NULL, NULL}
};

LUALIB_API int luaopen_chess_bitboard(lua_State *L) {
    init_lz_array();
    luaL_register(L, "chess.bitboard", bblib_global);

    luaL_newmetatable(L, BITBOARD_T);
    luaL_register(L, NULL, bblib_bitboard);
    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2); /* push the metatable */
    lua_settable(L, -3); /* metatable.__index = metatable */

    /* Push version */
    lua_pushliteral(L, "_VERSION");
    lua_pushstring(L, PACKAGE_NAME "-" VERSION);
    lua_settable(L, -3);

    return 1;
}

