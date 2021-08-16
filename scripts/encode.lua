local utils = require "mp.utils"
local msg = require "mp.msg"
local options = require "mp.options"

local ON_WINDOWS = (package.config:sub(1,1) ~= "/")

local start_timestamp = nil
local profile_start = ""

-- implementation detail of the osd message
local timer = nil
local timer_duration = 2

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

function get_extension(path)
    local candidate = string.match(path, "%.([^.]+)$")
    if candidate then
        for _, ext in ipairs({ "mkv", "webm", "mp4", "avi" }) do
            if candidate == ext then
                return candidate
            end
        end
    end
    return "mkv"
end

function get_output_string(dir, format, input, extension, title, from, to, profile)
    local res = utils.readdir(dir)
    if not res then
        return nil
    end
    local files = {}
    for _, f in ipairs(res) do
        files[f] = true
    end
    local output = format
    output = string.gsub(output, "$f", function() return input end)
    output = string.gsub(output, "$t", function() return title end)
    output = string.gsub(output, "$s", function() return seconds_to_time_string(from, true) end)
    output = string.gsub(output, "$e", function() return seconds_to_time_string(to, true) end)
    output = string.gsub(output, "$d", function() return seconds_to_time_string(to-from, true) end)
    output = string.gsub(output, "$x", function() return extension end)
    output = string.gsub(output, "$p", function() return profile end)
    if ON_WINDOWS then
        output = string.gsub(output, "[/\\|<>?:\"*]", "_")
    end
    if not string.find(output, "$n") then
        return files[output] and nil or output
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

function get_video_filters()
    local filters = {}
    for _, vf in ipairs(mp.get_property_native("vf")) do
        local name = vf["name"]
        name = string.gsub(name, '^lavfi%-', '')
        local filter
        if name == "crop" then
            local p = vf["params"]
            filter = string.format("crop=%d:%d:%d:%d", p.w, p.h, p.x, p.y)
        elseif name == "mirror" then
            filter = "hflip"
        elseif name == "flip" then
            filter = "vflip"
        elseif name == "rotate" then
            local rotation = vf["params"]["angle"]
            -- rotate is NOT the filter we want here
            if rotation == "90" then
                filter = "transpose=clock"
            elseif rotation == "180" then
                filter = "transpose=clock,transpose=clock"
            elseif rotation == "270" then
                filter = "transpose=cclock"
            end
        end
        filters[#filters + 1] = filter
    end
    return filters
end

function get_input_info(default_path, only_active)
    local accepted = {
        video = true,
        audio = not mp.get_property_bool("mute"),
        sub = mp.get_property_bool("sub-visibility")
    }
    local ret = {}
    for _, track in ipairs(mp.get_property_native("track-list")) do
        local track_path = track["external-filename"] or default_path
        if not only_active or (track["selected"] and accepted[track["type"]]) then
            local tracks = ret[track_path]
            if not tracks then
                ret[track_path] = { track["ff-index"] }
            else
                tracks[#tracks + 1] = track["ff-index"]
            end
        end
    end
    return ret
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

function start_encoding(from, to, settings)
    local args = {
        settings.ffmpeg_command,
        "-loglevel", "panic", "-hide_banner",
    }
    local append_args = function(table) args = append_table(args, table) end

    local path = mp.get_property("path")
    local is_stream = not file_exists(path)
    if is_stream then
        path = mp.get_property("stream-path")
    end

    local track_args = {}
    local start = seconds_to_time_string(from, false)
    local input_index = 0
    for input_path, tracks in pairs(get_input_info(path, settings.only_active_tracks)) do
       append_args({
            "-ss", start,
            "-i", input_path,
        })
        if settings.only_active_tracks then
            for _, track_index in ipairs(tracks) do
                track_args = append_table(track_args, { "-map", string.format("%d:%d", input_index, track_index)})
            end
        else
            track_args = append_table(track_args, { "-map", tostring(input_index)})
        end
        input_index = input_index + 1
    end

    append_args({"-to", tostring(to-from)})
    append_args(track_args)

    -- apply some of the video filters currently in the chain
    local filters = {}
    if settings.preserve_filters then
        filters = get_video_filters()
    end
    if settings.append_filter ~= "" then
        filters[#filters + 1] = settings.append_filter
    end
    if #filters > 0 then
        append_args({ "-filter:v", table.concat(filters, ",") })
    end

    -- split the user-passed settings on whitespace
    for token in string.gmatch(settings.codec, "[^%s]+") do
        args[#args + 1] = token
    end

    -- path of the output
    local output_directory = settings.output_directory
    if output_directory == "" then
        if is_stream then
            output_directory = "."
        else
            output_directory, _ = utils.split_path(path)
        end
    else
        output_directory = string.gsub(output_directory, "^~", os.getenv("HOME") or "~")
    end
    local input_name = mp.get_property("filename/no-ext") or "encode"
    local title = mp.get_property("media-title")
    local extension = get_extension(path)
    local output_name = get_output_string(output_directory, settings.output_format, input_name, extension, title, from, to, settings.profile)
    if not output_name then
        mp.osd_message("Invalid path " .. output_directory)
        return
    end
    args[#args + 1] = utils.join_path(output_directory, output_name)

    if settings.print then
        local o = ""
        -- fuck this is ugly
        for i = 1, #args do
            local fmt = ""
            if i == 1 then
                fmt = "%s%s"
            elseif i >= 2 and i <= 4 then
                fmt = "%s"
            elseif args[i-1] == "-i" or i == #args or args[i-1] == "-filter:v" then
                fmt = "%s '%s'"
            else
                fmt = "%s %s"
            end
            o = string.format(fmt, o, args[i])
        end
        print(o)
    end
    if settings.detached then
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

function clear_timestamp()
    timer:kill()
    start_timestamp = nil
    profile_start = ""
    mp.remove_key_binding("encode-ESC")
    mp.remove_key_binding("encode-ENTER")
    mp.osd_message("", 0)
end

function set_timestamp(profile)
    if not mp.get_property("path") then
        mp.osd_message("No file currently playing")
        return
    end
    if not mp.get_property_bool("seekable") then
        mp.osd_message("Cannot encode non-seekable media")
        return
    end

    if not start_timestamp or profile ~= profile_start then
        profile_start = profile
        start_timestamp = mp.get_property_number("time-pos")
        local msg = function()
            mp.osd_message(
                string.format("encode [%s]: waiting for end timestamp", profile or "default"),
                timer_duration
            )
        end
        msg()
        timer = mp.add_periodic_timer(timer_duration, msg)
        mp.add_forced_key_binding("ESC", "encode-ESC", clear_timestamp)
        mp.add_forced_key_binding("ENTER", "encode-ENTER", function() set_timestamp(profile) end)
    else
        local from = start_timestamp
        local to = mp.get_property_number("time-pos")
        if to <= from then
            mp.osd_message("Second timestamp cannot be before the first", timer_duration)
            timer:kill()
            timer:resume()
            return
        end
        clear_timestamp()
        mp.osd_message(string.format("Encoding from %s to %s"
            , seconds_to_time_string(from, false)
            , seconds_to_time_string(to, false)
        ), timer_duration)
        -- include the current frame into the extract
        local fps = mp.get_property_number("container-fps") or 30
        to = to + 1 / fps / 2
        local settings = {
            detached = true,
            container = "",
            only_active_tracks = false,
            preserve_filters = true,
            append_filter = "",
            codec = "-an -sn -c:v libvpx -crf 10 -b:v 1000k",
            output_format = "$f_$n.webm",
            output_directory = "",
            ffmpeg_command = "ffmpeg",
            print = true,
        }
        if profile then
            options.read_options(settings, profile)
            if settings.container ~= "" then
                msg.warn("The 'container' setting is deprecated, use 'output_format' now")
                settings.output_format = settings.output_format .. "." .. settings.container
            end
            settings.profile = profile
        else
            settings.profile = "default"
        end
        start_encoding(from, to, settings)
    end
end

mp.add_key_binding(nil, "set-timestamp", set_timestamp)
