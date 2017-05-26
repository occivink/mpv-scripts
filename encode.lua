local start_timestamp = nil
local utils = require "mp.utils"
local options = require "mp.options"

local o = {
    -- if true, the ffmpeg process will be detached and we won't know if it
    -- succeeded or not and we can stop mpv at any time
    -- if false, we know the result of calling ffmpeg, but we can only encode
    -- one extract at a time and mpv will block on exit
    detached = false,
}
options.read_options(o)

function append_table(lhs, rhs)
    for i = 1,#rhs do
        lhs[#lhs+1] = rhs[i]
    end
    return lhs
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function get_output_string(dir, format, input, from, to)
    local res = utils.readdir(dir)
    local files = {}
    for _, f in ipairs(res) do
        files[f] = true
    end
    local output = format
    output = string.gsub(output, "$f", input)
    output = string.gsub(output, "$s", seconds_to_time_string(from, true))
    output = string.gsub(output, "$e", seconds_to_time_string(to, true))
    output = string.gsub(output, "$d", seconds_to_time_string(to-from, true))
    if not string.find(output, "$n") then
        if not files[output] then
            return output
        else
            return nil
        end
    end
    local i = 1
    while true do
        local potential_name = string.gsub(output, "$n", tostring(i))
        if not files[potential_name] then
            return potential_name
        end
        i = i + 1
    end
end

function get_video_filters_string()
    local filters = {}
    local vf_table = mp.get_property_native("vf")
    for _, vf in ipairs(vf_table) do
        local name = vf["name"]
        local filter
        if name == "crop" then
            local p = vf["params"]
            filter = string.format("crop=%d:%d:%d:%d", p["w"], p["h"], p["x"], p["y"])
        elseif name == "mirror" then
            filter = "hflip"
        elseif name == "flip" then
            filter = "vflip"
        elseif name == "rotate" then
            local rotation = tonumber(vf["params"]["angle"])
            -- rotate is NOT the filter we want here
            if rotation == 90 then
                filter = string.format("transpose=clock")
            elseif rotation == 180 then
                filter = string.format("transpose=clock,transpose=clock")
            elseif rotation == 270 then
                filter = string.format("transpose=cclock")
            end
        end
        filters[#filters + 1] = filter
    end
    return table.concat(filters, ",")
end

function get_active_tracks()
    local tracks = mp.get_property_native("track-list")
    local accepted = {
        video = true,
        audio = not mp.get_property_bool("mute"),
        sub = mp.get_property_bool("sub-visibility")
    }
    local active_tracks = {}
    for _, track in ipairs(tracks) do
        if track["selected"] and accepted[track["type"]] then
            active_tracks[#active_tracks + 1] = string.format("0:%d", track["ff-index"])
        end
    end
    return active_tracks
end

function seconds_to_time_string(seconds, full)
    local ret = string.format("%02d:%02d.%03d"
        , math.floor(seconds / 60) % 60
        , math.floor(seconds) % 60
        , seconds * 1000 % 1000
    )
    if full or seconds > 3600 then
        ret = string.format("%d:%s", math.floor(seconds / 3600), ret)
    end
    return ret
end

function start_encoding(path, from, to, settings)
    local filename = mp.get_property("filename/no-ext") or "encode"

    local args = {
        "ffmpeg",
        "-loglevel", "panic", "-hide_banner", --stfu ffmpeg
        "-i", path,
        "-ss", seconds_to_time_string(from, false),
        "-to", seconds_to_time_string(to, false)
    }

    -- map currently playing channels
    if settings.only_active_tracks == "true" then
        for _, t in ipairs(get_active_tracks()) do
            args = append_table(args, { "-map", t })
        end
    else
        args = append_table(args, { "-map", "0" })
    end

    -- apply some of the video filters currently in the chain
    if settings.preserve_filters == "true" then
        local video_filters = get_video_filters_string()
        if video_filters ~= "" then
            args = append_table(args, {
                "-filter:v", video_filters,
            })
        end
    end

    -- split the user-passed settings on whitespace
    for token in string.gmatch(settings.codec, "[^%s]+") do
        args[#args + 1] = token
    end

    -- path of the output
    local directory = settings.output_directory
    if directory == "" then
        directory, _ = utils.split_path(path)
    end
    output = string.format("%s.%s", settings.output_format, settings.container)
    local output = get_output_string(directory, output, filename, from, to)
    if not output then
        mp.osd_message("Invalid filename")
        return
    end
    args[#args + 1] = utils.join_path(directory, output)

    print(table.concat(args, " "))
    if o.detached then
        utils.subprocess_detached({ args = args })
    else
        local res = utils.subprocess({ args = args, max_size = 0, cancellable = false })
        if res.status == 0 then
            mp.osd_message("Finished encoding succesfully")
        else
            mp.osd_message("Failed to encode, check the log")
        end
    end
end

function set_timestamp(container, only_active_tracks, preserve_filters, codec, output_directory, output_format)
    local path = mp.get_property("path")
    if not path then
        mp.osd_message("No file currently playing")
        return
    end
    if not file_exists(path) then
        mp.osd_message("Cannot encode streams")
        return
    end

    if start_timestamp == nil then
        start_timestamp = mp.get_property_number("time-pos")
        mp.osd_message("Encoding from " .. seconds_to_time_string(start_timestamp, false))
    else
        local current_timestamp = mp.get_property_number("time-pos")
        if current_timestamp <= start_timestamp then
            mp.osd_message("Second timestamp cannot be before the first")
            return
        end
        mp.osd_message(string.format("Started encoding from %s to %s"
            , seconds_to_time_string(start_timestamp, false)
            , seconds_to_time_string(current_timestamp, false)
        ))
        local settings = {
            container = container,
            only_active_tracks = only_active_tracks,
            preserve_filters = preserve_filters,
            codec = codec,
            output_directory = output_path or "",
            output_format = output_format or "$f_$n"
        }
        start_encoding(path, start_timestamp, current_timestamp, settings)
        start_timestamp = nil
    end
end

mp.add_key_binding(nil, "set_timestamp", set_timestamp)
mp.add_key_binding(nil, "clear_timestamp", function() start_timestamp = nil end)
