local assdraw = require 'mp.assdraw'
local needs_drawing = false
local crop_zone_coords = {}

function draw_crop_zone()
    if needs_drawing then
        local mx, my = mp.get_mouse_pos()
        local ox, oy = mp.get_osd_size()
        local ass = assdraw.ass_new()
        if #crop_zone_coords == 1 then
            ass:new_event()
            ass:pos(0, 0)
            ass:append('{\\bord0}')
            ass:append('{\\shad0}')
            ass:append('{\\c&H000000&}')
            ass:append('{\\alpha&H77}')
            corner = crop_zone_coords[1]
            local x1, x2, y1, y2
            if corner.x < mx then
                x1, x2 = corner.x, mx
            else 
                x1, x2 = mx, corner.x
            end
            if corner.y < my then
                y1, y2 = corner.y, my
            else 
                y1, y2 = my, corner.y
            end
            --   0     x1      x2   ox
            -- 0 +-----+------------+
            --   |     |     ur     |
            -- y1| ul  +-------+----+
            --   |     |       |    |
            -- y2+-----+-------+ lr |
            --   |     ll      |    |
            -- oy+-------------+----+
            ass:draw_start()
            ass:rect_cw(0, 0, x1, y2)   -- ul
            ass:rect_cw(x1, 0, ox, y1)  -- ur
            ass:rect_cw(0, y2, x2, oy)  -- ll
            ass:rect_cw(x2, y1, ox, oy) -- lr
            ass:draw_stop()
            -- also possible to draw a rect over the whole video
            -- and \iclip it in the middle, but seemingy slower
        end
        ass:new_event()
        ass:append('{\\bord0}')
        ass:append('{\\shad0}')
        ass:append('{\\c&H555555&}')
        ass:append('{\\alpha&H00&}')
        ass:pos(0, 0)
        ass:draw_start()
        ass:rect_cw(mx-0.5, 0, mx+0.5, oy)
        ass:rect_cw(0, my-0.5, ox, my+0.5)
        ass:draw_stop()
        ass:new_event()
        local align = 1
        local offset = 5
        local ofx = 1
        local ofy = -1
        if mx > ox/2 then
            align = align + 2
            ofx = -1
        end
        if my < oy/2 then
            align = align + 6
            ofy = 1
        end
        ass:append('{\\an'..align..'}')
        ass:append('{\\fs26}')
        ass:append('{\\bord1.5}')
        ass:pos(ofx*offset+mx, ofy*offset+my)
        ass:append(mx..', '..my)
        mp.set_osd_ass(ox, oy, ass.text)
        needs_drawing = false
    end
end

function crop_video()

end

function update_crop_zone_state()
    local z = {}
    z.x, z.y = mp.get_mouse_pos()
    crop_zone_coords[#crop_zone_coords+1] = z
    if #crop_zone_coords == 2 then
        cancel_crop()
        crop_zone_coords = {}
        needs_drawing = false
    end
end

function start_crop()
    needs_drawing = true
    mp.add_key_binding("mouse_move", "crop-mouse-moved", function () needs_drawing = true end)
    mp.add_key_binding("MOUSE_BTN0", "crop-mouse-click", update_crop_zone_state)
end

function cancel_crop()
    mp.remove_key_binding("crop-mouse-moved")
    mp.remove_key_binding("crop-mouse-click")
    mp.set_osd_ass(1280, 720, '')
end

mp.register_idle(draw_crop_zone)
mp.add_key_binding("d", "start-crop", start_crop)
mp.add_key_binding("alt+d", "cancel-crop", cancel_crop)
