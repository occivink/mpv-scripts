local options = require 'mp.options'

local opts = {
    blur_radius = 10,
    blur_power = 10,
    auto_apply = true,
    mode = "all",
    reapply_delay = 0.5,
}
options.read_options(opts)

local applied = false

function set_lavfi_complex(filter)
    local force_window = mp.get_property("force-window")
    mp.set_property("force-window", "yes")
    if not filter then
        mp.set_property("lavfi-complex", "")
        mp.set_property("vid", "1")
    else
        mp.set_property("vid", "no")
        mp.set_property("lavfi-complex", filter)
    end
    mp.set_property("force-window", force_window)
end

function set_blur()
    if not mp.get_property("video-out-params") then return end
    local video_aspect = mp.get_property_number("video-aspect")
    local ww, wh = mp.get_osd_size()

    if math.abs(ww/wh - video_aspect) < 0.05 then return end
    if opts.mode == "horizontal" and ww/wh < video_aspect then return end
    if opts.mode == "vertical" and ww/wh > video_aspect then return end

    local par = mp.get_property_number("video-params/par")
    local height = mp.get_property_number("video-params/h")
    local width = mp.get_property_number("video-params/w")
    
    local split = "[vid1] split=3 [a] [v] [b]"
    local crop_format = "crop=%s:%s:%s:%s"

    local stack_direction, crop_1, crop_2, blur_size
    if  ww/wh > video_aspect then
        blur_size = math.floor(((ww/wh)*height/par-width)/2)
        crop_1 = string.format(crop_format, blur_size, height, "0", "0")
        crop_2 = string.format(crop_format, blur_size, height, width - blur_size, "0")
        stack_direction = "h"
    else
        blur_size = math.floor(((wh/ww)*width*par-height)/2)
        crop_1 = string.format(crop_format, width, blur_size, "0", "0")
        crop_2 = string.format(crop_format, width, blur_size, "0", height - blur_size)
        stack_direction = "v"
    end
    if blur_size < 2 then return end
    local lr = math.min(opts.blur_radius, math.floor(blur_size/2)-1)
    local cr = math.min(opts.blur_radius, math.floor(blur_size/4)-1)
    local blur = string.format("boxblur=lr=%i:lp=%i:cr=%i:cp=%i",
        lr, opts.blur_power, cr, opts.blur_power)

    zone_1 = string.format("[a] %s,%s [a_fin]", crop_1, blur)
    zone_2 = string.format("[b] %s,%s [b_fin]", crop_2, blur)

    local par_fix = ""
    if par ~= 1 then
       par_fix = ",setsar=ratio=" .. tostring(par) .. ":max=10000"
    end

    stack = string.format("[a_fin] [v] [b_fin] %sstack=3%s [vo]", stack_direction, par_fix)
    filter = string.format("%s;%s;%s;%s", split, zone_1, zone_2, stack)
    set_lavfi_complex(filter)
    applied = true
end

function unset_blur()
    set_lavfi_complex()
    applied = false
end

local timer = nil
function reapply_blur()
    unset_blur()
    if timer then
        timer:kill()
    end
    timer = mp.add_timeout(opts.reapply_delay, set_blur)
end

if opts.auto_apply then
    mp.observe_property("osd-width", "native", reapply_blur)
    mp.observe_property("osd-height", "native", reapply_blur)
end

mp.add_key_binding(nil, "toggle-blur", toggle_blur)
