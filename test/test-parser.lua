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

--- Unit tests for LuaFics parser.

require("lunit")
require("fics")

module("test-parser", package.seeall, lunit.testcase)

function test_prompt_login()
    c = fics.client:new{}
    c.send_ivars = false

    local called = false

    c:register_callback("login", function (client) called = true end)
    c:parseline("login: ")

    assert(called == true, "parsing login failed")
end

function test_prompt_password()
    c = fics.client:new{}

    local called = false

    c:register_callback("password", function (client) called = true end)
    c:parseline("password: ")

    assert(called == true, "parsing password failed")
end

function test_prompt_server()
    c = fics.client:new{}

    local called = false

    c:register_callback("prompt", function (client) called = true end)
    c:parseline("fics% ")

    assert(called == true, "parsing prompt failed")
end

function test_handle_too_short()
    c = fics.client:new{}

    local called = false

    c:register_callback("handle_too_short", function (client) called = true end)
    c:parseline("A name should be at least three characters long. Please try again.")

    assert(called == true, "parsing handle_too_short failed")
end

function test_handle_too_long()
    c = fics.client:new{}

    local called = false

    c:register_callback("handle_too_long", function (client) called = true end)
    c:parseline("Sorry, names may be at most 17 characters long. Please try again.")

    assert(called == true, "parsing handle_too_long failed")
end

function test_handle_not_registered()
    c = fics.client:new{}

    local called = false
    local phandle

    c:register_callback("handle_not_registered", function (client, handle)
        called = true
        phandle = handle
        end)
    c:parseline("\"tsot\" is not a registered name RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing handle_not_registered failed")
    assert(phandle == "tsot", "handle_not_registered failed to grab handle")
end

function test_invalid_password()
    c = fics.client:new{}

    local called = false

    c:register_callback("password_invalid", function (client) called = true end)
    c:parseline("**** Invalid password! **** RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing password_invalid failed")
end

function test_session_start()
    c = fics.client:new{}

    local called = false
    local phandle, ptags

    c:register_callback("session_start", function (client, handle, tags)
        called = true
        phandle = handle
        ptags = tags
        end)
    c:parseline("**** Starting FICS session as blindTal(B)(CA)(*)(SR)")

    assert(called == true, "parsing session_start failed")
    assert(phandle == "blindTal", "session_start failed to grab handle")
    assert(ptags[1] == "B", "session_start failed to grab tags[1]")
    assert(ptags[2] == "CA", "session_start failed to grab tags[2]")
    assert(ptags[3] == "*", "session_start failed to grab tags[3]")
    assert(ptags[4] == "SR", "session_start failed to grab tags[4]")
end

function test_news()
    c = fics.client:new{}

    local called = false
    local pno, pdate, psubject

    c:register_callback("news", function (client, no, date, subject)
        called = true
        pno = no
        pdate = date
        psubject = subject
        end)
    c:parseline("1309 (Thu, Mar 27) FICS user hits 200,000 lightning games!")

    assert(called == true, "parsing news failed")
    assert(pno == 1309, "news failed to grab no")
    assert(pdate == "Thu, Mar 27", "news failed to grab date")
    assert(psubject == "FICS user hits 200,000 lightning games!",
        "news failed to grab subject")
end

function test_messages()
    c = fics.client:new{}

    local called = false
    local ptotal, punread

    c:register_callback("messages", function (client, total, unread)
        called = true
        ptotal = total
        punread = unread
        end)
    c:parseline("You have 10 messages (5 unread)")

    assert(called == true, "parsing messages failed")
    assert(ptotal == 10, "messages failed to grab total")
    assert(punread == 5, "messages failed to grab unread")
end

function test_notify_include()
    c = fics.client:new{}

    local called = false
    local phandles

    c:register_callback("notify_include", function (client, handles)
        called = true
        phandles = handles
        end)
    c:parseline("Present company includes: foo bar baz.")

    assert(called == true, "parsing notify_include failed")
    assert(phandles[1] == "foo", "notify_include failed to grab handle[1]")
    assert(phandles[2] == "bar", "notify_include failed to grab handle[2]")
    assert(phandles[3] == "baz", "notify_include failed to grab handle[3]")
end

function test_notify_note()
    c = fics.client:new{}

    local called = false
    local phandles

    c:register_callback("notify_note", function (client, handles)
        called = true
        phandles = handles
        end)
    c:parseline("Your arrival was noted by: foo bar baz.")

    assert(called == true, "parsing notify_note failed")
    assert(phandles[1] == "foo", "notify_note failed to grab handle[1]")
    assert(phandles[2] == "bar", "notify_note failed to grab handle[2]")
    assert(phandles[3] == "baz", "notify_note failed to grab handle[3]")
end

function test_notify_arrive1()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_arrive", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has arrived and isn't on your notify list.")

    assert(called == true, "parsing notify_arrive failed")
    assert(phandle == "foo", "notify_arrive failed to grab handle")
    assert(pinlist == false, "notify_arrive failed to grab inlist")
end

function test_notify_arrive2()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_arrive", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has arrived RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing notify_arrive failed")
    assert(phandle == "foo", "notify_arrive failed to grab handle")
    assert(pinlist == true, "notify_arrive failed to grab inlist")
end

function test_notify_depart1()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_depart", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has departed and isn't on your notify list.")

    assert(called == true, "parsing notify_depart failed")
    assert(phandle == "foo", "notify_depart failed to grab handle")
    assert(pinlist == false, "notify_depart failed to grab inlist")
end

function test_notify_depart2()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_depart", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has departed RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing notify_depart failed")
    assert(phandle == "foo", "notify_depart failed to grab handle")
    assert(pinlist == true, "notify_depart failed to grab inlist")
end

function test_tell()
    c = fics.client:new{}

    local called = false
    local phandle, ptags, pmessage

    c:register_callback("tell", function (client, handle, tags, message)
        called = true
        phandle = handle
        ptags = tags
        pmessage = message
        end)
    c:parseline("foo(CA)(SR)(TM) tells you: foo is oof")

    assert(called == true, "parsing tell failed")
    assert(phandle == "foo", "tell failed to grab handle")
    assert(ptags[1] == "CA", "tell failed to grab tags[1]")
    assert(ptags[2] == "SR", "tell failed to grab tags[2]")
    assert(ptags[3] == "TM", "tell failed to grab tags[3]")
    assert(pmessage == "foo is oof", "tell failed to grab message")
end

function test_chantell()
    c = fics.client:new{}

    local called = false
    local phandle, ptags, pchannel, pmessage

    c:register_callback("chantell", function (client, handle, tags, channel, message)
        called = true
        phandle = handle
        ptags = tags
        pchannel = channel
        pmessage = message
        end)
    c:parseline("foo(CA)(SR)(TM)(85): foo is oof")

    assert(called == true, "parsing chantell failed")
    assert(phandle == "foo", "chantell failed to grab handle")
    assert(ptags[1] == "CA", "chantell failed to grab tags[1]")
    assert(ptags[2] == "SR", "chantell failed to grab tags[2]")
    assert(ptags[3] == "TM", "chantell failed to grab tags[3]")
    assert(pchannel == 85, "chantell failed to grab channel")
    assert(pmessage == "foo is oof", "chantell failed to grab message")
end

function test_qtell()
    c = fics.client:new{}

    local called = false
    local pmessage

    c:register_callback("qtell", function (client, message)
        called = true
        pmessage = message
        end)
    c:parseline(":foo is oof")

    assert(called == true, "parsing qtell failed")
    assert(pmessage == "foo is oof", "qtell failed to grab message")
end

function test_it()
    c = fics.client:new{}

    local called = false
    local phandle, ptags, pmessage

    c:register_callback("it", function (client, handle, tags, message)
        called = true
        phandle = handle
        ptags = tags
        pmessage = message
        end)
    c:parseline("--> foo(CA)(SR)(TM)> foo is oof")

    assert(called == true, "parsing it failed")
    assert(phandle == "foo", "it failed to grab handle")
    assert(ptags[1] == "CA", "it failed to grab tags[1]")
    assert(ptags[2] == "SR", "it failed to grab tags[2]")
    assert(ptags[3] == "TM", "it failed to grab tags[3]")
    assert(pmessage == "> foo is oof", "it failed to grab message")
end

function test_shout()
    c = fics.client:new{}

    local called = false
    local phandle, ptags, pmessage

    c:register_callback("shout", function (client, handle, tags, message)
        called = true
        phandle = handle
        ptags = tags
        pmessage = message
        end)
    c:parseline("foo(CA)(SR)(TM) shouts: foo is oof")

    assert(called == true, "parsing shout failed")
    assert(phandle == "foo", "shout failed to grab handle")
    assert(ptags[1] == "CA", "shout failed to grab tags[1]")
    assert(ptags[2] == "SR", "shout failed to grab tags[2]")
    assert(ptags[3] == "TM", "shout failed to grab tags[3]")
    assert(pmessage == "foo is oof", "shout failed to grab message")
end

function test_cshout()
    c = fics.client:new{}

    local called = false
    local phandle, ptags, pmessage

    c:register_callback("cshout", function (client, handle, tags, message)
        called = true
        phandle = handle
        ptags = tags
        pmessage = message
        end)
    c:parseline("foo(CA)(SR)(TM) c-shouts: foo is oof")

    assert(called == true, "parsing cshout failed")
    assert(phandle == "foo", "cshout failed to grab handle")
    assert(ptags[1] == "CA", "cshout failed to grab tags[1]")
    assert(ptags[2] == "SR", "cshout failed to grab tags[2]")
    assert(ptags[3] == "TM", "cshout failed to grab tags[3]")
    assert(pmessage == "foo is oof", "cshout failed to grab message")
end

function test_announcement()
    c = fics.client:new{}

    local called = false
    local phandle, pmessage

    c:register_callback("announcement", function (client, handle, message)
        called = true
        phandle = handle
        pmessage = message
        end)
    c:parseline(" **ANNOUNCEMENT** from foo: can has cheeseburger?")

    assert(called == true, "parsing announcement failed")
    assert(phandle == "foo", "announcement failed to grab handle")
    assert(pmessage == "can has cheeseburger?", "announcement failed to grab message")
end

function test_challenge_unrated()
    c = fics.client:new{}

    local called = false
    local p1, p2, pgame

    c:register_callback("challenge", function (client, player1, player2, game)
        called = true
        p1 = player1
        p2 = player2
        pgame = game
        end)
    c:parseline("Challenge: foo (666) bar (----) unrated blitz 3 0.")

    assert(called == true, "parsing unrated challenge failed")
    assert(p1.handle == "foo", "challenge failed to parse player1.handle")
    assert(p1.rating == "666", "challenge failed to parse player1.rating")
    assert(p1.colour == nil, "challenge failed to parse player1.colour")
    assert(p2.handle == "bar", "challenge failed to parse player2.handle")
    assert(p2.rating == "----", "challenge failed to parse player2.rating")
    assert(pgame.update == false, "challenge failed to parse game.update")
    assert(pgame.type == "blitz", "challenge failed to parse game.type")
    assert(pgame.wtype == nil, "challenge failed to parse game.wtype")
    assert(pgame.rated == false, "challenge failed to parse game.rated")
    assert(pgame.time == 3, "challenge failed to parse game.time")
    assert(pgame.inc == 0, "challenge failed to parse game.inc")
    assert(pgame.issued == false, "challenge failed to parse game.issued")
end

function test_challenge_updated()
    c = fics.client:new{}

    local called = false
    local p1, p2, pgame

    c:register_callback("challenge", function (client, player1, player2, game)
        called = true
        p1 = player1
        p2 = player2
        pgame = game
        end)
    c:parseline("foo updates the match request.")
    c:parseline("Challenge: foo (666) bar (----) unrated blitz 3 0.")

    assert(called == true, "parsing updated challenge failed")
    assert(pgame.update == true, "challenge failed to parse game.update")
end

function test_challenge_issued()
    c = fics.client:new{}

    local called = false
    local p1, p2, pgame

    c:register_callback("challenge", function (client, player1, player2, game)
        called = true
        p1 = player1
        p2 = player2
        pgame = game
        end)
    c:parseline("Issuing: foo (666) bar (----) unrated blitz 3 0.")

    assert(called == true, "parsing issued challenge failed")
    assert(pgame.issued == true, "challenge failed to parse game.issued")
end

function test_challenge_colour()
    c = fics.client:new{}

    local called = false
    local p1, p2, pgame

    c:register_callback("challenge", function (client, player1, player2, game)
        called = true
        p1 = player1
        p2 = player2
        pgame = game
        end)
    c:parseline("Challenge: foo (666) [white] bar (----) unrated blitz 3 0.")

    assert(called == true, "parsing updated challenge failed")
    assert(p1.colour == "white", "challenge failed to parse player1.colour")
end

function test_challenge_rated()
    c = fics.client:new{}

    local called = false
    local p1, p2, pgame

    c:register_callback("challenge", function (client, player1, player2, game)
        called = true
        p1 = player1
        p2 = player2
        pgame = game
        end)
    c:parseline("Challenge: foo (666) [white] bar (----) rated blitz 3 0.")
    c:parseline("Your blitz rating will change:  Win: +2006,  Draw: +1810,  Loss: -1600")
    c:parseline("Your new RD will be 265.5")

    assert(called == true, "parsing rated challenge failed")
    assert(pgame.win == 2006, "challenge failed to parse game.win")
    assert(pgame.draw == 1810, "challenge failed to parse game.draw")
    assert(pgame.loss == -1600, "challenge failed to parse game.loss")
    assert(pgame.newrd == 265.5, "challenge failed to parse game.newrd")
end

function test_partner()
    c = fics.client:new{}

    local called = false
    local phandle

    c:register_callback("partner", function (client, handle)
        called = true
        phandle = handle
        end)
    c:parseline("foo offers to be your bughouse partner")

    assert(called == true, "parsing partner failed")
    assert(phandle == "foo", "partner failed to parse handle")
end

function test_style12()
    c = fics.client:new{}

    local called = false
    local pmatch

    c:register_callback("style12", function (client, match)
        called = true
        pmatch = match
        end)
    c:parseline("<12> " ..
        "rnbqkbnr " ..
        "pp-ppppp " ..
        "-------- " ..
        "--p----- " ..
        "----P--- " ..
        "-------- " ..
        "PPPP-PPP " ..
        "RNBQKBNR " ..
        "W 2 1 1 1 1 0 20 foo bar -1 2 12 39 39 120 120 2 P/c7-c5 (0:00) c5 1 1 0")

    assert(called == true, "parsing style12 failed")
    assert(pmatch.rank8 == "rnbqkbnr", "style12 failed to parse match.rank8")
    assert(pmatch.rank7 == "pp-ppppp", "style12 failed to parse match.rank7")
    assert(pmatch.rank6 == "--------", "style12 failed to parse match.rank6")
    assert(pmatch.rank5 == "--p-----", "style12 failed to parse match.rank5")
    assert(pmatch.rank4 == "----P---", "style12 failed to parse match.rank4")
    assert(pmatch.rank3 == "--------", "style12 failed to parse match.rank3")
    assert(pmatch.rank2 == "PPPP-PPP", "style12 failed to parse match.rank2")
    assert(pmatch.rank1 == "RNBQKBNR", "style12 failed to parse match.rank1")
    assert(pmatch.tomove == "W", "style12 failed to parse match.tomove")
    assert(pmatch.doublepawn == 2, "style12 failed to parse match.doublepawn")
    assert(pmatch.wcastle == true, "style12 failed to parse match.wcastle")
    assert(pmatch.wlcastle == true, "style12 failed to parse match.wlcastle")
    assert(pmatch.bcastle == true, "style12 failed to parse match.bcastle")
    assert(pmatch.blcastle == true, "style12 failed to parse match.blcastle")
    assert(pmatch.lastirr == 0, "style12 failed to parse match.lastirr")
    assert(pmatch.gameno == 20, "style12 failed to parse match.gameno")
    assert(pmatch.wname == "foo", "style12 failed to parse match.wname")
    assert(pmatch.bname == "bar", "style12 failed to parse match.bname")
    assert(pmatch.relation == -1, "style12 failed to parse match.relation")
    assert(pmatch.itime == 2, "style12 failed to parse match.itime")
    assert(pmatch.inc == 12, "style12 failed to parse match.inc")
    assert(pmatch.wstrength == 39, "style12 failed to parse match.wstrength")
    assert(pmatch.bstrength == 39, "style12 failed to parse match.bstrength")
    assert(pmatch.wtime == 120, "style12 failed to parse match.wtime")
    assert(pmatch.btime == 120, "style12 failed to parse match.btime")
    assert(pmatch.moveno == 2, "style12 failed to parse match.moveno")
    assert(pmatch.llastmove == "P/c7-c5", "style12 failed to parse match.llastmove")
    assert(pmatch.lastmin == 0, "style12 failed to parse match.lastmin")
    assert(pmatch.lastsec == 0, "style12 failed to parse match.lastsec")
    assert(pmatch.lastmove == "c5", "style12 failed to parse match.lastmove")
    assert(pmatch.flip == true, "style12 failed to parse match.flip")
end

function test_style12_ms()
    c = fics.client:new{}
    c.ivars[fics.IV_MS] = true

    local called = false
    local pmatch

    c:register_callback("style12", function (client, match)
        called = true
        pmatch = match
        end)
    c:parseline("<12> " ..
        "rnbqkb-r " ..
        "pp--pp-p " ..
        "---p-np- " ..
        "-------- " ..
        "---NP--- " ..
        "--N----- " ..
        "PPP--PPP " ..
        "R-BQKB-R " ..
        "W -1 1 1 1 1 0 73 thespiritofTAL Spiritstoy -1 3 0 38 38 171836 170896 6 P/g7-g6 (0:03.184) g6 1 1 0")

    assert(called == true, "parsing style12 failed")
    assert(pmatch.lastmin == 0, "style12 failed to parse match.lastmin")
    assert(pmatch.lastsec == 3, "style12 failed to parse match.lastmove")
    assert(pmatch.lastms == 184, "style12 failed to parse match.lastms")
end

