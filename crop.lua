local assdraw = require 'mp.assdraw'
local needs_drawing = false
local crop_first_corner = nil

function sort_corners(c1, c2)
    local r1, r2 = {}, {}
    if c1.x < c2.x then r1.x, r2.x = c1.x, c2.x else r1.x, r2.x = c2.x, c1.x end
    if c1.y < c2.y then r1.y, r2.y = c1.y, c2.y else r1.y, r2.y = c2.y, c1.y end
    return r1, r2
end

function draw_shadow(ass, top_left_corner, bottom_right_corner, window_size)
    ass:new_event()
    ass:pos(0, 0)
    ass:append('{\\bord0}')
    ass:append('{\\shad0}')
    ass:append('{\\c&H000000&}')
    ass:append('{\\alpha&H77}')
    local c1, c2 = top_left_corner, bottom_right_corner
    --     0   c1.x    c2.x   wx
    -- 0   +-----+------------+
    --     |     |     ur     |
    -- c1.y| ul  +-------+----+
    --     |     |       |    |
    -- c2.y+-----+-------+ lr |
    --     |     ll      |    |
    -- wy  +-------------+----+
    ass:draw_start()
    ass:rect_cw(0, 0, c1.x, c2.y)                         -- ul
    ass:rect_cw(c1.x, 0, window_size.w, c1.y)             -- ur
    ass:rect_cw(0, c2.y, c2.x, window_size.h)             -- ll
    ass:rect_cw(c2.x, c1.y, window_size.w, window_size.h) -- lr
    ass:draw_stop()
    -- also possible to draw a rect over the whole video
    -- and \iclip it in the middle, but seemingy slower
end

function draw_crosshair(ass, center, window_size)
    ass:new_event()
    ass:append('{\\bord0}')
    ass:append('{\\shad0}')
    ass:append('{\\c&HBBBBBB&}')
    ass:append('{\\alpha&H00&}')
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(center.x-0.5, 0, center.x+0.5, window_size.h)
    ass:rect_cw(0, center.y-0.5, window_size.w, center.y+0.5)
    ass:draw_stop()
end

function draw_position_text(ass, position, window_size, offset)
    ass:new_event()
    local align = 1
    local ofx = 1
    local ofy = -1
    if position.x > window_size.w/2 then
        align = align + 2
        ofx = -1
    end
    if position.y < window_size.h/2 then
        align = align + 6
        ofy = 1
    end
    ass:append('{\\an'..align..'}')
    ass:append('{\\fs26}')
    ass:append('{\\bord1.5}')
    ass:pos(ofx*offset+position.x, ofy*offset+position.y)
    ass:append(position.x..', '..position.y)
end

function draw_crop_zone()
    if needs_drawing then
        local crop_second_corner = {}
        crop_second_corner.x, crop_second_corner.y = mp.get_mouse_pos()
        local window_size = {}
        window_size.w, window_size.h = mp.get_osd_size()

        local ass = assdraw.ass_new()
        if crop_first_corner ~= nil then
            local c1, c2 = sort_corners(crop_first_corner, crop_second_corner)
            draw_shadow(ass, c1, c2, window_size)
        end
        draw_crosshair(ass, crop_second_corner, window_size)
        draw_position_text(ass, crop_second_corner, window_size, 6)

        mp.set_osd_ass(window_size.w, window_size.h, ass.text)
        needs_drawing = false
    end
end

function crop_video(x, y, w, h)
    local vf_table = mp.get_property_native("vf")
    -- modify existing crop if found
    local crop_index = #vf_table+1
    for i = 1, #vf_table do
        if vf_table[i]["name"] == "crop" then
            crop_index = i
            -- take into account the previous offset
            x = x + vf_table[i]["params"]["x"]
            y = y + vf_table[i]["params"]["y"]
            break
        end
    end
    vf_table[crop_index] = { name="crop", params={ x=tostring(x), y=tostring(y), w=tostring(w), h=tostring(h) } }
    mp.set_property_native("vf", vf_table)
end

function update_crop_zone_state()
    local cursor_pos = {}
    cursor_pos.x, cursor_pos.y = mp.get_mouse_pos()
    if crop_first_corner == nil then
        crop_first_corner = cursor_pos
    else
        local c1, c2 = sort_corners(crop_first_corner, cursor_pos)
        crop_video(c1.x, c1.y, c2.x-c1.x, c2.y-c1.y)
        cancel_crop()
    end
end

function start_crop()
    if not mp.get_property("filename") then return end
    needs_drawing = true
    mp.add_forced_key_binding("mouse_move", "crop-mouse-moved", function() needs_drawing = true end)
    mp.add_forced_key_binding("MOUSE_BTN0", "crop-mouse-click", update_crop_zone_state)
    mp.add_forced_key_binding("ESC", "crop-esc", cancel_crop)
end

function cancel_crop()
    needs_drawing = false
    crop_first_corner = nil
    mp.remove_key_binding("crop-mouse-moved")
    mp.remove_key_binding("crop-mouse-click")
    mp.remove_key_binding("crop-esc")
    mp.set_osd_ass(1280, 720, '')
end

function undo_crop()
    local vf_table = mp.get_property_native("vf")
    for i = 1, #vf_table do
        if vf_table[i]["name"] == "crop" then
            vf_table[i] = nil
            mp.set_property_native("vf", vf_table)
            break
        end
    end
end

mp.register_idle(draw_crop_zone)
mp.add_key_binding("c", "start-crop", start_crop)
mp.add_key_binding("alt+c", "cancel-crop", undo_crop)
