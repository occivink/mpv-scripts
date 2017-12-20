local needs_adjusting = false
local video_dimensions = {
    top_left = { x = 0, y = 0 },
    bottom_right = { x = 0, y = 0 },
    size = { w = 0, h = 0 },
}
local video_pan_origin = { x = 0, y = 0 }
local mouse_pos_origin = { x = 0, y = 0 }
local zoom_origin = 0
local zoom_increment = 0

local opts = {
    margin = 50,
    do_not_move_if_all_visible = true,
}
local options = require 'mp.options'
options.read_options(opts)

function compute_video_dimensions()
    -- this function is very much ripped from video/out/aspect.c in mpv's source
    local keep_aspect = mp.get_property_bool("keepaspect")
    local video_params = mp.get_property_native("video-out-params")
    local w = video_params["w"]
    local h = video_params["h"]
    local dw = video_params["dw"]
    local dh = video_params["dh"]
    if mp.get_property_number("video-rotate") % 180 == 90 then
        w, h = h,w
        dw, dh = dh, dw
    end
    local window_w, window_h = mp.get_osd_size()
    if keep_aspect then
        local unscaled = mp.get_property_native("video-unscaled")
        local panscan = mp.get_property_number("panscan")

        local fwidth = window_w
        local fheight = math.floor(window_w / dw * dh)
        if fheight > window_h or fheight < h then
            local tmpw = math.floor(window_h / dh * dw)
            if tmpw <= window_w then
                fheight = window_h
                fwidth = tmpw
            end
        end
        local vo_panscan_area = window_h - fheight
        local f_w = fwidth / fheight
        local f_h = 1
        if vo_panscan_area == 0 then
            vo_panscan_area = window_h - fwidth
            f_w = 1
            f_h = fheight / fwidth
        end
        if unscaled or unscaled == "downscale-big" then
            vo_panscan_area = 0
            if unscaled or (dw <= window_w and dh <= window_h) then
                fwidth = dw
                fheight = dh
            end
        end

        local scaled_width = fwidth + math.floor(vo_panscan_area * panscan * f_w)
        local scaled_height = fheight + math.floor(vo_panscan_area * panscan * f_h)

        local split_scaling = function (dst_size, scaled_src_size, zoom, align, pan)
            scaled_src_size = math.floor(scaled_src_size * 2 ^ zoom)
            align = (align + 1) / 2
            local dst_start = math.floor((dst_size - scaled_src_size) * align + pan * scaled_src_size)
            if dst_start < 0 then
                --account for C int cast truncating as opposed to flooring
                dst_start = dst_start + 1
            end
            local dst_end = dst_start + scaled_src_size;
            if dst_start >= dst_end then
                dst_start = 0
                dst_end = 1
            end
            return dst_start, dst_end
        end
        local zoom = mp.get_property_number("video-zoom")

        local align_x = mp.get_property_number("video-align-x")
        local pan_x = mp.get_property_number("video-pan-x")
        video_dimensions.top_left.x, video_dimensions.bottom_right.x = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)

        local align_y = mp.get_property_number("video-align-y")
        local pan_y = mp.get_property_number("video-pan-y")
        video_dimensions.top_left.y, video_dimensions.bottom_right.y = split_scaling(window_h,  scaled_height, zoom, align_y, pan_y)
    else
        video_dimensions.top_left.x = 0
        video_dimensions.bottom_right.x = window_w
        video_dimensions.top_left.y = 0
        video_dimensions.bottom_right.y = window_h
    end
    video_dimensions.size.w = video_dimensions.bottom_right.x - video_dimensions.top_left.x
    video_dimensions.size.h = video_dimensions.bottom_right.y - video_dimensions.top_left.y
end

function drag_to_pan_idle()
    if needs_adjusting then
        local mX, mY = mp.get_mouse_pos()
        local pX = video_pan_origin.x + (mX - mouse_pos_origin.x) / video_dimensions.size.w
        local pY = video_pan_origin.y + (mY - mouse_pos_origin.y) / video_dimensions.size.h
        mp.command("no-osd set video-pan-x " .. pX .. "; no-osd set video-pan-y " .. pY)
        needs_adjusting = false
    end
end

function drag_to_pan_handler(table)
    if table["event"] == "down" then
        if not mp.get_property("video-out-params", nil) then return end
        compute_video_dimensions()
        mp.register_idle(drag_to_pan_idle)
        mouse_pos_origin.x, mouse_pos_origin.y = mp.get_mouse_pos()
        video_pan_origin.x = mp.get_property("video-pan-x")
        video_pan_origin.y = mp.get_property("video-pan-y")
        mp.add_forced_key_binding("mouse_move", "drag-to-pan-idle", function() needs_adjusting = true end)
    elseif table["event"] == "up" then
        mp.remove_key_binding("drag-to-pan-idle")
        mp.unregister_idle(drag_to_pan_idle)
        needs_adjusting = false
    end
end

function pan_follows_cursor_idle()
    if needs_adjusting then
        local mX, mY = mp.get_mouse_pos()
        local window_w, window_h = mp.get_osd_size()
        local x = math.min(1, math.max(- 2 * mX / window_w + 1, -1))
        local y = math.min(1, math.max(- 2 * mY / window_h + 1, -1))
        local command = ""
        if (opts.do_not_move_if_all_visible and window_w < video_dimensions.size.w) then
            command = command .. "no-osd set video-pan-x " .. x * (video_dimensions.size.w - window_w + 2 * opts.margin) / (2 * video_dimensions.size.w) .. ";"
        elseif mp.get_property_number("video-pan-x") ~= 0 then
            command = command .. "no-osd set video-pan-x " .. "0;"
        end
        if (opts.do_not_move_if_all_visible and window_h < video_dimensions.size.h) then
            command = command .. "no-osd set video-pan-y " .. y * (video_dimensions.size.h - window_h + 2 * opts.margin) / (2 * video_dimensions.size.h) .. ";"
        elseif mp.get_property_number("video-pan-y") ~= 0 then
            command = command .. "no-osd set video-pan-y " .. "0;"
        end
        if command ~= "" then
            mp.command(command)
        end
        needs_adjusting = false
    end
end

function pan_follows_cursor_handler(table)
    if table["event"] == "down" then
        if not mp.get_property("video-out-params", nil) then return end
        compute_video_dimensions()
        mp.register_idle(pan_follows_cursor_idle)
        mp.add_forced_key_binding("mouse_move", "pan-follows-cursor-idle", function() needs_adjusting = true end)
    elseif table["event"] == "up" then
        mp.remove_key_binding("pan-follows-cursor-idle")
        mp.unregister_idle(pan_follows_cursor_idle)
        needs_adjusting = false
    end
end

function cursor_centric_zoom_idle()
    if needs_adjusting then
        -- the size in pixels of the (in|de)crement
        local diffHeight = (2 ^ zoom_increment - 1) * video_dimensions.size.h
        local diffWidth  = (2 ^ zoom_increment - 1) * video_dimensions.size.w

        -- how far (in percentage of the video size) from the middle the cursor is
        local rx = (video_dimensions.top_left.x + video_dimensions.size.w / 2 - mouse_pos_origin.x) / (video_dimensions.size.w / 2)
        local ry = (video_dimensions.top_left.y + video_dimensions.size.h / 2 - mouse_pos_origin.y) / (video_dimensions.size.h / 2)

        local newPanX = (video_pan_origin.x * video_dimensions.size.w + rx * diffWidth / 2) / (video_dimensions.size.w + diffWidth)
        local newPanY = (video_pan_origin.y * video_dimensions.size.h + ry * diffHeight / 2) / (video_dimensions.size.h + diffHeight)
        mp.command("no-osd set video-zoom " .. zoom_origin + zoom_increment .. "; no-osd set video-pan-x " .. newPanX .. "; no-osd set video-pan-y " .. newPanY)
        needs_adjusting = false
    end
end

function cursor_centric_zoom_handler(arg)
    local arg_num = tonumber(arg)
    if not arg_num or arg_num == 0 then return end
    if not mp.get_property("video-out-params", nil) then return end
    if zoom_increment == 0 then
        compute_video_dimensions()
        mouse_pos_origin.x, mouse_pos_origin.y = mp.get_mouse_pos()
        video_pan_origin.x = mp.get_property("video-pan-x")
        video_pan_origin.y = mp.get_property("video-pan-y")
        zoom_origin = mp.get_property("video-zoom")
        mp.register_idle(cursor_centric_zoom_idle)
        mp.add_forced_key_binding("mouse_move", "cursor-centric-zoom-stop", cursor_centric_zoom_stop)
    end
    zoom_increment = zoom_increment + arg_num
    needs_adjusting = true
end

function cursor_centric_zoom_stop()
    mp.unregister_idle(cursor_centric_zoom_idle)
    mp.remove_key_binding("cursor-centric-zoom-stop")
    needs_adjusting = false
    zoom_increment = 0
end

mp.add_key_binding(nil, "drag-to-pan", drag_to_pan_handler, {complex = true})
mp.add_key_binding(nil, "pan-follows-cursor", pan_follows_cursor_handler, {complex = true})
mp.add_key_binding(nil, "cursor-centric-zoom", cursor_centric_zoom_handler)
