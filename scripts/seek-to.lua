local assdraw = require 'mp.assdraw'
local active = false
local mode = "time"
local time_scale = { 60*60*10, 60*60, 60*10, 60, 10, 1 }

local ass_begin = mp.get_property("osd-ass-cc/0")
local ass_end = mp.get_property("osd-ass-cc/1")

local history = {
    ["time"] = {},
    ["percent"] = {}
}
local histpos = false
local edit = ""

-- timer to redraw periodically the message
-- to avoid leaving bindings when the seeker disappears for whatever reason
-- pretty hacky tbh
local timer = nil
local timer_duration = 3

function format(time)
    if mode == "percent" then
        return (#time == 0 and '0' or '')..tostring(time)..'%'
    elseif mode == "time" then
        local s = time
        for i = 1, 6 - #s do
            s = '0'..s
        end
        return string.sub(s, 1, 2)..':'..string.sub(s, 3, 4)..':'..string.sub(s, 5, 6)
    end
end

function show_seeker()
    time = histpos and history[mode][histpos] or edit
    mp.osd_message("Seek to: "..ass_begin..format(time)..ass_end, timer_duration)
end

function edithist()
    if histpos then
        edit = history[mode][histpos]
        histpos = false
    end
end

function change_number(i)
    if i == 0 and #edit == 0 then
        return
    end
    if mode == "time" and #edit >= 6 then
        return
    end
    edit = edit..tostring(i)
end

function time_as_sec(time)
    local sec = 0
    for i = 1, #time do
        sec = sec + (tonumber(string.sub(time, i, i)) * time_scale[#time_scale - (#time - i)])
    end
    return sec
end

function seek_to()
    if mode == "percent" then
        local d = mp.get_property_number("duration")
        mp.commandv("osd-bar", "seek", (tonumber(edit) / 100) * d, "absolute")
    elseif mode == "time" then
        mp.commandv("osd-bar", "seek", time_as_sec(edit), "absolute")
    end
    --deduplicate historical timestamps
    for i = #history[mode], 1, -1 do
        if history[mode][i] == edit then
            table.remove(history[mode], i)
        end
    end
    table.insert(history[mode], edit)
end

function backspace()
    edit = string.sub(edit, 1, #(edit) - 1)
end

function history_move(up)
    if not histpos and up then histpos = #history[mode] goto ret end
    if not histpos then goto ret end
    if up then
        histpos = math.max(1, histpos - 1)
    else
        if histpos == #history[mode] then histpos = false goto ret end
        histpos = math.min(histpos + 1, #history[mode])
    end
    ::ret::
    print('History:')
    for i = 1, #history[mode] do
        print('  '..(i == histpos and '*' or ' ')..(mode == "percent" and '%' or 'T')..' '..history[mode][i])
    end
end

local key_mappings = {
    BS    = function() edithist() backspace() show_seeker() end,
    ESC   = function() set_inactive() end,
    ENTER = function() edithist() seek_to() set_inactive() end,
    UP    = function() history_move(true) show_seeker() end,
    DOWN  = function() history_move(false) show_seeker() end
}

for i = 0, 9 do
    local func = function() change_number(i) show_seeker() end
    key_mappings[string.format("KP%d", i)] = func
    key_mappings[string.format("%d", i)] = func
end

function set_active()
    edit = ""
    if not mp.get_property("seekable") then return end
    for key, func in pairs(key_mappings) do
        mp.add_forced_key_binding(key, "seek-to-"..key, func)
    end
    show_seeker()
    timer = mp.add_periodic_timer(timer_duration, show_seeker)
    active = true
end

function set_inactive()
    mp.osd_message("")
    for key, _ in pairs(key_mappings) do
        mp.remove_key_binding("seek-to-"..key)
    end
    timer:kill()
    histpos = false
    active = false
end

mp.add_key_binding(nil, "toggle-seeker", function() if active then set_inactive() else mode = "time" set_active() end end)
mp.add_key_binding(nil, "toggle-seeker-percent", function() if active then set_inactive() else mode = "percent" set_active() end end)
