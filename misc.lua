function rotate(inc)
    if (360 + inc) % 90 ~= 0 then
        return
    end
    local vf_table = mp.get_property_native("vf")
    local previous_angle = 0
    local rotation_index = #vf_table + 1
    if #vf_table ~= 0 and vf_table[#vf_table]["name"] == "rotate" then
        rotation_index = #vf_table
        previous_angle = vf_table[#vf_table]["params"]["angle"]
    end
    local new_angle = (previous_angle + 360 + inc) % 360
    if new_angle == 0 then
        vf_table[rotation_index] = nil
    else
        vf_table[rotation_index] = {
            name = "rotate",
            params = { angle = tostring(new_angle) }
        }
    end
    mp.set_property_native("vf", vf_table)
end

function toggle(filter)
    local vf_table = mp.get_property_native("vf")
    if #vf_table ~= 0 and vf_table[#vf_table]["name"] == filter then
        vf_table[#vf_table] = nil
    else
        vf_table[#vf_table + 1] = { name = filter }
    end
    mp.set_property_native("vf", vf_table)
end

local filters_undo_stack = {}

function remove_last_filter()
    local vf_table = mp.get_property_native("vf")
    if #vf_table == 0 then
        return
    end
    filters_undo_stack[#filters_undo_stack + 1] = vf_table[#vf_table]
    vf_table[#vf_table] = nil
    mp.set_property_native("vf", vf_table)
end

function undo_filter_removal()
    if #filters_undo_stack == 0 then
        return
    end
    local vf_table = mp.get_property_native("vf")
    vf_table[#vf_table + 1] = filters_undo_stack[#filters_undo_stack]
    filters_undo_stack[#filters_undo_stack] = nil
    mp.set_property_native("vf", vf_table)
end

function clear_filters()
    local vf_table = mp.get_property_native("vf")
    if #vf_table == 0 then
        return
    end
    for i = 1, #vf_table do
        filters_undo_stack[#filters_undo_stack + 1] = vf_table[#vf_table + 1 - i]
    end
    mp.set_property_native("vf", {})
end

function compute_video_dimensions()
    -- this function is very much ripped from video/out/aspect.c in mpv's source
    local keep_aspect = mp.get_property_bool("keepaspect")
    local video_params = mp.get_property_native("video-out-params")
    local w = video_params["w"]
    local h = video_params["h"]
    local dw = video_params["dw"]
    local dh = video_params["dh"]
    local video_w, video_h
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
        video_w = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)

        local align_y = mp.get_property_number("video-align-y")
        local pan_y = mp.get_property_number("video-pan-y")
        video_h = split_scaling(window_h,  scaled_height, zoom, align_y, pan_y)
    else
        video_w = window_w
        video_h = window_h
    end
    return video_w, video_h
end

function align(x, y)
    local video_w, video_h = compute_video_dimensions()
    local window_w, window_h = mp.get_osd_size()
    local x,y = tonumber(x), tonumber(y)
    if x then
        mp.set_property_number("video-pan-x", x * (video_w - window_w) / (2 * video_w))
    end
    if y then
        mp.set_property_number("video-pan-y", y * (video_h - window_h) / (2 * video_h))
    end
end

function ab_loop(operation, timestamp)
    if not mp.get_property("seekable") then return end
    if timestamp ~= "a" and timestamp ~= "b" then return end
    timestamp = "ab-loop-" .. timestamp
    if operation == "set" then
        mp.set_property_number(timestamp, mp.get_property_number("time-pos"))
    elseif operation == "jump" then
        local t = tonumber(mp.get_property(timestamp))
        if t then mp.set_property_number("time-pos", t) end
    elseif operation == "clear" then
        mp.set_property(timestamp, "no")
    end
end

mp.add_key_binding(nil, "rotate", rotate)
mp.add_key_binding(nil, "toggle-filter", toggle)
mp.add_key_binding(nil, "clear-filters", clear_filters)
mp.add_key_binding(nil, "remove-last-filter", remove_last_filter)
mp.add_key_binding(nil, "undo-filter-removal", undo_filter_removal)
mp.add_key_binding(nil, "align", align)
mp.add_key_binding(nil, "ab-loop", ab_loop)

