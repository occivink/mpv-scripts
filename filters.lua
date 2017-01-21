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

mp.add_key_binding(nil, "rotate", rotate)
mp.add_key_binding(nil, "toggle", toggle)
mp.add_key_binding(nil, "clear-filters", clear_filters)
mp.add_key_binding(nil, "remove-last-filter", remove_last_filter)
mp.add_key_binding(nil, "undo-filter-removal", undo_filter_removal)
