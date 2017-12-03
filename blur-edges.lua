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
    local blur = string.format("boxblur=lr=%i:lp=%i", opts.blur_radius, opts.blur_power)
    
    local split = "[vid1] split=3 [a] [v] [b]"

    local crop_format = "crop=%s:%s:%s:%s"

    local stack_direction, crop_1, crop_2
    if  ww/wh > video_aspect then
        local blur_width = math.floor(((ww/wh)*height/par-width)/2)
        crop_1 = string.format(crop_format, blur_width, height, "0", "0")
        crop_2 = string.format(crop_format, blur_width, height, width - blur_width, "0")
        stack_direction = "hstack"
    else
        local blur_height = math.floor(((wh/ww)*width*par-height)/2)
        crop_1 = string.format(crop_format, width, blur_height, "0", "0")
        crop_2 = string.format(crop_format, width, blur_height, "0", height - blur_height)
        stack_direction = "vstack"
    end
    zone_1 = string.format("[a] %s,%s [a_fin]", crop_1, blur)
    zone_2 = string.format("[b] %s,%s [b_fin]", crop_2, blur)

    local par_fix = ""
    if par ~= 1 then
       par_fix = ",setsar=ratio=" .. tostring(par) .. ":max=10000"
    end

    stack = string.format("[a_fin] [v] [b_fin] %s=3%s [vo]", stack_direction, par_fix)
    filter = string.format("%s;%s;%s;%s", split, zone_1, zone_2, stack)
    set_lavfi_complex(filter)
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
