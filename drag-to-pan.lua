local needs_adjusting = false
local video_dimensions = {}
local video_pan_origin = {}
local mouse_pos_origin = {}

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
    if keep_aspect then
        local unscaled = mp.get_property_native("video-unscaled")
        local panscan = mp.get_property_number("panscan")
        local window_w, window_h = mp.get_osd_size()

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
            return dst_end - dst_start
        end
        local zoom = mp.get_property_number("video-zoom")

        local align_x = mp.get_property_number("video-align-x")
        local pan_x = mp.get_property_number("video-pan-x")
        video_dimensions.w = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)

        local align_y = mp.get_property_number("video-align-y")
        local pan_y = mp.get_property_number("video-pan-y")
        video_dimensions.h = split_scaling(window_h,  scaled_height, zoom, align_y, pan_y)
    else
        video_dimensions.w = window_w
        video_dimensions.h = window_h
    end
end

function drag_to_pan_idle()
    if needs_adjusting then
        local mX, mY = mp.get_mouse_pos()
        mp.set_property_number("video-pan-x", video_pan_origin.x + (mX - mouse_pos_origin.x) / video_dimensions.w)
        mp.set_property_number("video-pan-y", video_pan_origin.y + (mY - mouse_pos_origin.y) / video_dimensions.h)
        needs_adjusting = false
    end
end

function drag_to_pan_handler(table)
    if table["event"] == "down" then
        v = mp.get_property("video")
        if not v or v == "" or v == "no" then return end
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
        if (opts.do_not_move_if_all_visible and window_w < video_dimensions.w) then
            mp.set_property_number("video-pan-x", x * (video_dimensions.w - window_w + 2 * opts.margin) / (2 * (video_dimensions.w)))
        elseif mp.get_property_number("video-pan-x") then
            mp.get_property_number("video-pan-x", 0)
        end
        if (opts.do_not_move_if_all_visible and window_h < video_dimensions.h) then
            mp.set_property_number("video-pan-y", y * (video_dimensions.h - window_h + 2 * opts.margin) / (2 * (video_dimensions.h)))
        elseif mp.get_property_number("video-pan-x") then
            mp.get_property_number("video-pan-x", 0)
        end
        needs_adjusting = false
    end
end

function pan_follows_cursor_handler(table)
    if table["event"] == "down" then
        v = mp.get_property("video")
        if not v or v == "" or v == "no" then return end
        compute_video_dimensions()
        mp.register_idle(pan_follows_cursor_idle)
        mp.add_forced_key_binding("mouse_move", "pan-follows-cursor-idle", function() needs_adjusting = true end)
    elseif table["event"] == "up" then
        mp.remove_key_binding("pan-follows-cursor-idle")
        mp.unregister_idle(pan_follows_cursor_idle)
        needs_adjusting = false
    end
end

mp.add_key_binding(nil, "drag-to-pan", drag_to_pan_handler, {complex = true})
mp.add_key_binding(nil, "pan-follows-cursor", pan_follows_cursor_handler, {complex = true})
