local options = require 'mp.options'

local opts = {
    blur_radius = 10,
    blur_power = 10,
    auto_apply = false,
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
    if applied then return end
    local video_aspect = mp.get_property_number("video-aspect")
    local ww, wh = mp.get_osd_size()
    if ww/wh < video_aspect + 0.01 then return end
    
    local split = "[vid1] split=3 [left] [v] [right]"
    local blur = string.format("boxblur=lr=%i:lp=%i", opts.blur_radius, opts.blur_power)
    
    local width = string.format("((%i/%i)*ih-iw)/2", ww, wh)
    local crop_format = "crop=%s:ih:%s:0"
    local crop_left = string.format(crop_format, width, "0")
    local crop_right = string.format(crop_format, width, "iw-"..width)

    local left = string.format("[left] %s,%s [left_fin]", crop_left, blur)
    local right = string.format("[right] %s,%s [right_fin]", crop_right, blur)
    
    local stack = "[left_fin] [v] [right_fin] hstack=3 [vo]"
    set_lavfi_complex(string.format("%s;%s;%s;%s", split, left, right, stack))
    applied = true
end

function unset_blur()
    if not applied then return end
    set_lavfi_complex()
    applied = false
end

function toggle_blur()
    if applied then
        unset_blur()
    else
        set_blur()
    end
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
