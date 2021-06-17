local opts = {
    mode = "hard", -- can be "hard" or "soft". If hard, apply a crop filter, if soft zoom + pan. Or a bonus "delogo" mode
    draw_shade = true,
    shade_opacity = "77",
    draw_frame = false,
    frame_border_width = 2,
    frame_border_color = "EEEEEE",
    draw_crosshair = true,
    draw_text = true,
    mouse_support = true,
    coarse_movement = 30,
    left_coarse = "LEFT",
    right_coarse = "RIGHT",
    up_coarse = "UP",
    down_coarse = "DOWN",
    fine_movement = 1,
    left_fine = "ALT+LEFT",
    right_fine = "ALT+RIGHT",
    up_fine = "ALT+UP",
    down_fine = "ALT+DOWN",
    accept = "ENTER,MOUSE_BTN0",
    cancel = "ESC",
}
(require 'mp.options').read_options(opts)

function split(input)
    local ret = {}
    for str in string.gmatch(input, "([^,]+)") do
        ret[#ret + 1] = str
    end
    return ret
end
local msg = require 'mp.msg'

opts.accept = split(opts.accept)
opts.cancel = split(opts.cancel)
function mode_ok(mode)
    return mode == "soft" or mode == "hard" or mode == "delogo"
end
if not mode_ok(opts.mode) then
    msg.error("Invalid mode value: " .. opts.mode)
    return
end

local assdraw = require 'mp.assdraw'
local active = false
local active_mode = "" -- same possible values as opts.mode
local needs_drawing = false
local crop_first_corner = nil -- in normalized video space
local crop_cursor = {
    x = 0,
    y = 0
}

function redraw()
    needs_drawing = true
end

function sort_corners(c1, c2)
    local r1, r2 = {}, {}
    if c1.x < c2.x then r1.x, r2.x = c1.x, c2.x else r1.x, r2.x = c2.x, c1.x end
    if c1.y < c2.y then r1.y, r2.y = c1.y, c2.y else r1.y, r2.y = c2.y, c1.y end
    return r1, r2
end

function clamp(low, value, high)
    if value <= low then
        return low
    elseif value >= high then
        return high
    else
        return value
    end
end

function clamp_point(top_left, point, bottom_right)
    return {
        x = clamp(top_left.x, point.x, bottom_right.x),
        y = clamp(top_left.y, point.y, bottom_right.y)
    }
end

function screen_to_video_norm(point, dim)
    return {
        x = (point.x - dim.ml) / (dim.w - dim.ml - dim.mr),
        y = (point.y - dim.mt) / (dim.h - dim.mt - dim.mb)
    }
end

function video_norm_to_screen(point, dim)
    return {
        x = math.floor(point.x * (dim.w - dim.ml - dim.mr) + dim.ml + 0.5),
        y = math.floor(point.y * (dim.h - dim.mt - dim.mb) + dim.mt + 0.5)
    }
end

function position_to_ensure_ratio(moving, fixed, ratio)
    -- corners are in screen coordinates
    local x = moving.x
    local y = moving.y
    if math.abs(x - fixed.x) < ratio * math.abs(y - fixed.y) then
        local is_left = x < fixed.x and -1 or 1
        x = fixed.x + is_left * math.abs(y - fixed.y) * ratio
    else
        local is_up = y < fixed.y and -1 or 1
        y = fixed.y + is_up * math.abs(x - fixed.x) / ratio
    end
    return {
        x = x,
        y = y,
    }
end

function draw_shade(ass, unshaded, window)
    ass:new_event()
    ass:pos(0, 0)
    ass:append("{\\an7}")
    ass:append("{\\bord0}")
    ass:append("{\\shad0}")
    ass:append("{\\c&H000000&}")
    ass:append("{\\1a&H" .. opts.shade_opacity .. "}")
    ass:append("{\\2a&HFF}")
    ass:append("{\\3a&HFF}")
    ass:append("{\\4a&HFF}")
    local c1, c2 = unshaded.top_left, unshaded.bottom_right
    local v = window
    --          c1.x   c2.x
    --     +-----+------------+
    --     |     |     ur     |
    -- c1.y| ul  +-------+----+
    --     |     |       |    |
    -- c2.y+-----+-------+ lr |
    --     |     ll      |    |
    --     +-------------+----+
    ass:draw_start()
    ass:rect_cw(v.top_left.x, v.top_left.y, c1.x, c2.y) -- ul
    ass:rect_cw(c1.x, v.top_left.y, v.bottom_right.x, c1.y) -- ur
    ass:rect_cw(v.top_left.x, c2.y, c2.x, v.bottom_right.y) -- ll
    ass:rect_cw(c2.x, c1.y, v.bottom_right.x, v.bottom_right.y) -- lr
    ass:draw_stop()
    -- also possible to draw a rect over the whole video
    -- and \iclip it in the middle, but seemingy slower
end

function draw_frame(ass, frame)
    ass:new_event()
    ass:pos(0, 0)
    ass:append("{\\an7}")
    ass:append("{\\bord0}")
    ass:append("{\\shad0}")
    ass:append("{\\c&H" .. opts.frame_border_color .. "&}")
    ass:append("{\\1a&H00&}")
    ass:append("{\\2a&HFF&}")
    ass:append("{\\3a&HFF&}")
    ass:append("{\\4a&HFF&}")
    local c1, c2 = frame.top_left, frame.bottom_right
    local b = opts.frame_border_width
    ass:draw_start()
    ass:rect_cw(c1.x, c1.y - b, c2.x + b, c1.y)
    ass:rect_cw(c2.x, c1.y, c2.x + b, c2.y + b)
    ass:rect_cw(c1.x - b, c2.y, c2.x, c2.y + b)
    ass:rect_cw(c1.x - b, c1.y - b, c1.x, c2.y)
    ass:draw_stop()
end

function draw_crosshair(ass, center, window_size)
    ass:new_event()
    ass:pos(0, 0)
    ass:append("{\\an7}")
    ass:append("{\\bord0}")
    ass:append("{\\shad0}")
    ass:append("{\\c&HBBBBBB&}")
    ass:append("{\\1a&H00&}")
    ass:append("{\\2a&HFF&}")
    ass:append("{\\3a&HFF&}")
    ass:append("{\\4a&HFF&}")
    ass:draw_start()
    ass:rect_cw(center.x - 0.5, 0, center.x + 0.5, window_size.h)
    ass:rect_cw(0, center.y - 0.5, window_size.w, center.y + 0.5)
    ass:draw_stop()
end

function draw_position_text(ass, text, position, window_size, offset)
    ass:new_event()
    local align = 1
    local ofx = 1
    local ofy = -1
    if position.x > window_size.w / 2 then
        align = align + 2
        ofx = -1
    end
    if position.y < window_size.h / 2 then
        align = align + 6
        ofy = 1
    end
    ass:append("{\\an"..align.."}")
    ass:append("{\\fs26}")
    ass:append("{\\bord1.5}")
    ass:pos(ofx*offset + position.x, ofy*offset + position.y)
    ass:append(text)
end

function draw_crop_zone()
    if needs_drawing then
        local dim = mp.get_property_native("osd-dimensions")
        if not dim then
            cancel_crop()
            return
        end

        local cursor = {
            x = crop_cursor.x,
            y = crop_cursor.y,
        }
        if active_mode == "soft" then
            if crop_first_corner then
                cursor = position_to_ensure_ratio(cursor, video_norm_to_screen(crop_first_corner, dim), dim.w / dim.h)
            end
        elseif active_mode == "hard" or active_mode == "delogo" then
            cursor = clamp_point({ x = dim.ml, y = dim.mt }, cursor, { x = dim.w - dim.mr, y = dim.h - dim.mb })
        end
        local ass = assdraw.ass_new()

        if crop_first_corner and (opts.draw_shade or opts.draw_frame) then
            local first_corner = video_norm_to_screen(crop_first_corner, dim)
            local frame = {}
            frame.top_left, frame.bottom_right = sort_corners(first_corner, cursor)
            -- don't draw shade over non-visible video parts
            if opts.draw_shade then
                local window = {
                    top_left = { x = 0, y = 0 },
                    bottom_right = { x = dim.w, y = dim.h },
                }
                draw_shade(ass, frame, window)
            end
            if opts.draw_frame then
                draw_frame(ass, frame)
            end
        end


        if opts.draw_crosshair then
            draw_crosshair(ass, cursor, { w = dim.w, h = dim.h })
        end

        if opts.draw_text then
            local vop = mp.get_property_native("video-out-params")
            if vop then
                local cursor_norm = screen_to_video_norm(cursor, dim)
                local text = string.format("%d, %d", cursor_norm.x * vop.w, cursor_norm.y * vop.h)
                if crop_first_corner then
                    text = string.format("%s (%dx%d)", text,
                        math.abs((cursor_norm.x - crop_first_corner.x) * vop.w ),
                        math.abs((cursor_norm.y - crop_first_corner.y) * vop.h )
                    )
                end
                draw_position_text(ass, text, cursor, { w = dim.w, h = dim.h }, 6)
            end
        end

        mp.set_osd_ass(dim.w, dim.h, ass.text)
        needs_drawing = false
    end
end

function crop_video(x, y, w, h, dim)
    if active_mode == "soft" then
        local dim = mp.get_property_native("osd-dimensions")
        if not dim then return end

        local zoom = mp.get_property_number("video-zoom")
        local newZoom2 = math.log(dim.w * (2 ^ zoom) / (dim.w - dim.ml - dim.mr) / w) / math.log(2)
        local newZoom1 = math.log(dim.h * (2 ^ zoom) / (dim.h - dim.mt - dim.mb) / h) / math.log(2)
        mp.set_property("video-zoom", (newZoom1 + newZoom2) / 2) -- they should be ~ the same, but let's not play favorites
        mp.set_property("video-pan-x", 0.5 - (x + w / 2))
        mp.set_property("video-pan-y", 0.5 - (y + h / 2))
    elseif active_mode == "hard" or active_mode == "delogo" then
        local vop = mp.get_property_native("video-out-params")
        local vf_table = mp.get_property_native("vf")
        local x = math.floor(x * vop.w)
        local y = math.floor(y * vop.h)
        local w = math.floor(w * vop.w)
        local h = math.floor(h * vop.h)
        if active_mode == "delogo" then
            -- delogo is a little special and needs some padding to function
            w = math.min(vop.w - 1, w)
            h = math.min(vop.h - 1, h)
            x = math.max(1, x)
            y = math.max(1, y)
            if x + w == vop.w then w = w - 1 end
            if y + h == vop.h then h = h - 1 end
        end
        vf_table[#vf_table + 1] = {
            name=(active_mode == "hard") and "crop" or "delogo",
            params= { x = tostring(x), y = tostring(y), w = tostring(w), h = tostring(h) }
        }
        mp.set_property_native("vf", vf_table)
    end
end

function update_crop_zone_state()
    local dim = mp.get_property_native("osd-dimensions")
    if not dim then
        cancel_crop()
        return
    end
    local corner
    if active_mode == "soft" then
        if crop_first_corner then
            corner = position_to_ensure_ratio(crop_cursor, video_norm_to_screen(crop_first_corner, dim), dim.w / dim.h)
        else
            corner = crop_cursor
        end
    elseif active_mode == "hard" or active_mode == "delogo" then
        corner = clamp_point({ x = dim.ml, y = dim.mt }, crop_cursor, { x = dim.w - dim.mr, y = dim.h - dim.mb })
    end
    local corner_video = screen_to_video_norm(corner, dim)
    if crop_first_corner == nil then
        crop_first_corner = corner_video
        redraw()
    else
        local c1, c2 = sort_corners(crop_first_corner, corner_video)
        crop_video(c1.x, c1.y, c2.x - c1.x, c2.y - c1.y)
        cancel_crop()
    end
end

local bindings = {}
local bindings_repeat = {}

function cancel_crop()
    crop_first_corner = nil
    for key, _ in pairs(bindings) do
        mp.remove_key_binding("crop-"..key)
    end
    for key, _ in pairs(bindings_repeat) do
        mp.remove_key_binding("crop-"..key)
    end
    mp.unobserve_property(redraw)
    mp.unregister_idle(draw_crop_zone)
    mp.set_osd_ass(1280, 720, '')
    active = false
end

function start_crop(mode)
    if active then return end
    if not mp.get_property_native("osd-dimensions") then return end
    if mode and not mode_ok(mode) then
        msg.error("Invalid mode value: " .. mode)
        return
    end
    local mode_maybe = mode or opts.mode
    if mode_maybe ~= 'soft' then
        local hwdec = mp.get_property("hwdec-current")
        if hwdec and hwdec ~= "no" and not string.find(hwdec, "-copy$") then
            msg.error("Cannot crop with hardware decoding active (see manual)")
            return
        end
    end
    active = true
    active_mode = mode_maybe

    if opts.mouse_support then
        crop_cursor.x, crop_cursor.y = mp.get_mouse_pos()
    end
    redraw()
    for key, func in pairs(bindings) do
        mp.add_forced_key_binding(key, "crop-"..key, func)
    end
    for key, func in pairs(bindings_repeat) do
        mp.add_forced_key_binding(key, "crop-"..key, func, { repeatable = true })
    end
    mp.register_idle(draw_crop_zone)
    mp.observe_property("osd-dimensions", nil, redraw)
end

function toggle_crop(mode)
    if mode and not mode_ok(mode) then
        msg.error("Invalid mode value: " .. mode)
    end
    local toggle_mode = mode or opts.mode
    if toggle_mode == "soft" then return end -- can't toggle soft mode

    local remove_filter = function()
        local to_remove = (toggle_mode == "hard") and "crop" or "delogo"
        local vf_table = mp.get_property_native("vf")
        if #vf_table > 0 then
            for i = #vf_table, 1, -1 do
                if vf_table[i].name == to_remove then
                    for j = i, #vf_table-1 do
                        vf_table[j] = vf_table[j+1]
                    end
                    vf_table[#vf_table] = nil
                    mp.set_property_native("vf", vf_table)
                    return true
                end
            end
        end
        return false
    end
    if not remove_filter() then
        start_crop(mode)
    end
end

-- bindings
if opts.mouse_support then
    bindings["MOUSE_MOVE"] = function() crop_cursor.x, crop_cursor.y = mp.get_mouse_pos(); redraw() end
end
for _, key in ipairs(opts.accept) do
    bindings[key] = update_crop_zone_state
end
for _, key in ipairs(opts.cancel) do
    bindings[key] = cancel_crop
end
function movement_func(move_x, move_y)
    return function()
        crop_cursor.x = crop_cursor.x + move_x
        crop_cursor.y = crop_cursor.y + move_y
        redraw()
    end
end
bindings_repeat[opts.left_coarse]  = movement_func(-opts.coarse_movement, 0)
bindings_repeat[opts.right_coarse] = movement_func(opts.coarse_movement, 0)
bindings_repeat[opts.up_coarse]    = movement_func(0, -opts.coarse_movement)
bindings_repeat[opts.down_coarse]  = movement_func(0, opts.coarse_movement)
bindings_repeat[opts.left_fine]    = movement_func(-opts.fine_movement, 0)
bindings_repeat[opts.right_fine]   = movement_func(opts.fine_movement, 0)
bindings_repeat[opts.up_fine]      = movement_func(0, -opts.fine_movement)
bindings_repeat[opts.down_fine]    = movement_func(0, opts.fine_movement)


mp.add_key_binding(nil, "start-crop", start_crop)
mp.add_key_binding(nil, "toggle-crop", toggle_crop)
