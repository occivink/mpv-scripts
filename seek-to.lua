local assdraw = require 'mp.assdraw'
local active = false
local current_time = {}
for i = 1, 9 do
    current_time[i] = 0
end
local cursor_position = 1
local time_scale = {60*60*10, 60*60, 60*10, 60, 10, 1, 0.1, 0.01, 0.001}

function show_seeker()
    local ass = assdraw.ass_new()
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
    ass:new_event()
    ass:pos(20,20)
    ass:append("Seek to: "..str)
    local sX, sY = mp.get_osd_size()
    mp.set_osd_ass(sX, sY, ass.text)
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
    show_seeker()
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
    set_inactive()
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
        mp.add_forced_key_binding(tostring(i), "seek-to-"..i, function() change_number(i) end)
    end
    mp.add_forced_key_binding("LEFT", "seek-to-LEFT", function() shift_cursor(true) end)
    mp.add_forced_key_binding("RIGHT", "seek-to-RIGHT", function() shift_cursor(false) end)
    mp.add_forced_key_binding("ESC", "seek-to-ESC", set_inactive)
    mp.add_forced_key_binding("ENTER", "seek-to-ENTER", seek_to)
    show_seeker()
    active = true
end

function set_inactive()
    local sX, sY = mp.get_osd_size()
    mp.set_osd_ass(sX, sY, '')
    for i = 0, 9 do
        mp.remove_key_binding("seek-to-"..i)
    end
    mp.remove_key_binding("seek-to-LEFT")
    mp.remove_key_binding("seek-to-RIGHT")
    mp.remove_key_binding("seek-to-ESC")
    mp.remove_key_binding("seek-to-ENTER")
    active = false
end

mp.add_key_binding("Ctrl+t", "toggle-seeker", function() if active then set_inactive() else set_active() end end)

