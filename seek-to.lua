local assdraw = require 'mp.assdraw'
local active = false
local current_time = {}
for i = 1, 9 do
    current_time[i] = 0
end
local cursor_position = 1
local time_scale = {60*60*10, 60*60, 60*10, 60, 10, 1, 0.1, 0.01, 0.001}

local ass_begin = mp.get_property("osd-ass-cc/0")
local ass_end = mp.get_property("osd-ass-cc/1")

-- timer to redraw periodically the message
-- to avoid leaving bindings when the seeker disappears for whatever reason
-- pretty hacky tbh
local timer = nil
local timer_duration = 3

function show_seeker()
    local prepend_char = { '', '', ':', '', ':', '', '.', '', ''}
    local str = ''
    for i = 1, 9 do
        str = str .. prepend_char[i]
        if i == cursor_position then
            str = str .. '{\\b1}' .. current_time[i] .. '{\\r}'
        else
            str = str .. current_time[i]
        end
    end
    mp.osd_message("Seek to: " .. ass_begin .. str .. ass_end, timer_duration)
end

function change_number(i)
    -- can't set above 60 minutes or seconds
    if (cursor_position == 3 or cursor_position == 5) and i >= 6 then
        return
    end
    current_time[cursor_position] = i
    shift_cursor(false)
end

function shift_cursor(left)
    if left then
        cursor_position = math.max(1, cursor_position - 1)
    else
        cursor_position = math.min(cursor_position + 1, 9)
    end
end

function current_time_as_sec()
    local sec = 0
    for i = 1, 9 do
        sec = sec + time_scale[i] * current_time[i]
    end
    return sec
end

function seek_to()
    mp.set_property_number("time-pos", current_time_as_sec())
    for i = 1, 9 do
        current_time[i] = 0
    end
end

function backspace()
    if cursor_position ~= 9 or current_time[9] == 0 then
        shift_cursor(true)
    end
    current_time[cursor_position] = 0
end

function set_active()
    if not mp.get_property("seekable") then return end
    -- find duration of the video and set cursor position accordingly
    local duration = mp.get_property_number("duration")
    if duration ~= nil then
        for i = 1, 9 do
            if duration > time_scale[i] then
                cursor_position = i
                break
            end
        end
    end
    for i = 0, 9 do
        mp.add_forced_key_binding(tostring(i), "seek-to-"..i, function() change_number(i) show_seeker() end)
    end
    mp.add_forced_key_binding("LEFT", "seek-to-LEFT", function() shift_cursor(true) show_seeker() end)
    mp.add_forced_key_binding("RIGHT", "seek-to-RIGHT", function() shift_cursor(false) show_seeker() end)
    mp.add_forced_key_binding("BS", "seek-to-BACKSPACE", function() backspace() show_seeker() end)
    mp.add_forced_key_binding("ESC", "seek-to-ESC", set_inactive)
    mp.add_forced_key_binding("ENTER", "seek-to-ENTER", function() seek_to() set_inactive() end)
    show_seeker()
    timer = mp.add_periodic_timer(timer_duration, show_seeker)
    active = true
end

function set_inactive()
    local sX, sY = mp.get_osd_size()
    mp.osd_message("")
    for i = 0, 9 do
        mp.remove_key_binding("seek-to-"..i)
    end
    mp.remove_key_binding("seek-to-LEFT")
    mp.remove_key_binding("seek-to-RIGHT")
    mp.remove_key_binding("seek-to-BACKSPACE")
    mp.remove_key_binding("seek-to-ESC")
    mp.remove_key_binding("seek-to-ENTER")
    timer:kill()
    active = false
end

mp.add_key_binding(nil, "toggle-seeker", function() if active then set_inactive() else set_active() end end)

