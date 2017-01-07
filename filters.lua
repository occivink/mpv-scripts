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

function toggle_filter(filter)
    local vf_table = mp.get_property_native("vf")
    if #vf_table ~= 0 and vf_table[#vf_table]["name"] == filter then
        vf_table[#vf_table] = nil
    else
        vf_table[#vf_table + 1] = { name = filter }
    end
    mp.set_property_native("vf", vf_table)
end

function remove_last_filter()
    local vf_table = mp.get_property_native("vf")
    vf_table[#vf_table] = nil
    mp.set_property_native("vf", vf_table)
end

function clear_filters()
    mp.set_property_native("vf", {})
end

mp.add_key_binding("r", "clock_rotate", function() rotate(90) end)
mp.add_key_binding("alt+r", "counter_clock_rotate", function () rotate(-90) end)

mp.add_key_binding("h", "toggle_flip", function() toggle_filter("flip") end)
mp.add_key_binding("v", "toggle_mirror", function() toggle_filter("mirror") end)

mp.add_key_binding("D", "clear_filters", clear_filters)
mp.add_key_binding("d", "remove_last_filter", remove_last_filter)
