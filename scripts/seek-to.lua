local assdraw = require 'mp.assdraw'
local active = false
local cursor_position = 1
local time_scale = {60*60*10, 60*60, 60*10, 60, 10, 1, 0.1, 0.01, 0.001}

local ass_begin = mp.get_property("osd-ass-cc/0")
local ass_end = mp.get_property("osd-ass-cc/1")

local history = { {} }
for i = 1, 9 do
    history[1][i] = 0
end
local history_position = 1

-- timer to redraw periodically the message
-- to avoid leaving bindings when the seeker disappears for whatever reason
-- pretty hacky tbh
local timer = nil
local timer_duration = 3

function show_seeker()
    local prepend_char = {'','',':','',':','','.','',''}
    local str = ''
    for i = 1, 9 do
        str = str .. prepend_char[i]
        if i == cursor_position then
            str = str .. '{\\b1}' .. history[history_position][i] .. '{\\r}'
        else
            str = str .. history[history_position][i]
        end
    end
    mp.osd_message("Seek to: " .. ass_begin .. str .. ass_end, timer_duration)
end

function copy_history_to_last()
    if history_position ~= #history then
        for i = 1, 9 do
            history[#history][i] = history[history_position][i]
        end
        history_position = #history
    end
end

function change_number(i)
    -- can't set above 60 minutes or seconds
    if (cursor_position == 3 or cursor_position == 5) and i >= 6 then
        return
    end
    if history[history_position][cursor_position] ~= i then
        copy_history_to_last()
        history[#history][cursor_position] = i
    end
    shift_cursor(false)
end

function shift_cursor(left)
    if left then
        cursor_position = math.max(1, cursor_position - 1)
    else
        cursor_position = math.min(cursor_position + 1, 9)
    end
end

function current_time_as_sec(time)
    local sec = 0
    for i = 1, 9 do
        sec = sec + time_scale[i] * time[i]
    end
    return sec
end

function time_equal(lhs, rhs)
    for i = 1, 9 do
        if lhs[i] ~= rhs[i] then
            return false
        end
    end
    return true
end

function seek_to()
    copy_history_to_last()
    mp.commandv("osd-bar", "seek", current_time_as_sec(history[history_position]), "absolute")
    --deduplicate consecutive timestamps
    if #history == 1 or not time_equal(history[history_position], history[#history - 1]) then
        history[#history + 1] = {}
        history_position = #history
    end
    for i = 1, 9 do
        history[#history][i] = 0
    end
end

function backspace()
    if cursor_position ~= 9 or current_time[9] == 0 then
        shift_cursor(true)
    end
    if history[history_position][cursor_position] ~= 0 then
        copy_history_to_last()
        history[#history][cursor_position] = 0
    end
end

function history_move(up)
    if up then
        history_position = math.max(1, history_position - 1)
    else
        history_position = math.min(history_position + 1, #history)
    end
end

local key_mappings = {
    LEFT  = function() shift_cursor(true) show_seeker() end,
    RIGHT = function() shift_cursor(false) show_seeker() end,
    UP    = function() history_move(true) show_seeker() end,
    DOWN  = function() history_move(false) show_seeker() end,
    BS    = function() backspace() show_seeker() end,
    ESC   = function() set_inactive() end,
    ENTER = function() seek_to() set_inactive() end
}
for i = 0, 9 do
    local func = function() change_number(i) show_seeker() end
    key_mappings[string.format("KP%d", i)] = func
    key_mappings[string.format("%d", i)] = func
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
    active = false
end

mp.add_key_binding(nil, "toggle-seeker", function() if active then set_inactive() else set_active() end end)

