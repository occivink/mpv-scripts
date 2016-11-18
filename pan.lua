local needs_adjusting = false

function adjust_pan()
    if needs_adjusting then
        local mX, mY = mp.get_mouse_pos()
        mp.set_property_number("video-pan-x", vpX+(mX-oX)/iW)
        mp.set_property_number("video-pan-y", vpY+(mY-oY)/iH)
        needs_adjusting = false
    end
end

function click_handler(table)
    if table["event"] == "down" then
        if not mp.get_property("filename") then return end
        oX, oY = mp.get_mouse_pos()
        iW = mp.get_property("width")
        iH = mp.get_property("height")
        vpX = mp.get_property("video-pan-x")
        vpY = mp.get_property("video-pan-y")
        mp.add_forced_key_binding("mouse_move", "drag-to-pan", function () needs_adjusting = true end)
    elseif table["event"] == "up" then
        mp.remove_key_binding("drag-to-pan")
        needs_adjusting = false
    end
end

mp.register_idle(adjust_pan)
mp.add_key_binding("MOUSE_BTN0", "start-pan", click_handler, {complex=true})
