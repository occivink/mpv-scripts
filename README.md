# Foreword

These scripts are completely independent. Some of them work together nicely (e.g. `crop.lua` and `encode.lua`) but that's it. Just copy whichever scripts you're interested in to your `scripts/` directory (see [here](https://mpv.io/manual/master/#lua-scripting) for installation instructions).  

## Bindings

None of these scripts come with default bindings. Instead, you're encouraged to set your own in `input.conf`. See below for my own bindings as a sample.

# crop.lua

Crop the current video in a visual manner. UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping and is aware of some properties like pan or zoom, there are other subtleties.

Press the binding to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.  
You can use a binding such as `d vf del -1` to undo the last crop.

# encode.lua

Make an extract of the currently playing video using `ffmpeg`. Press the binding once to set the beginning of the extract. Press a second time to set the end and start encoding.  
This script defines two commands that you can bind in your `input.conf` like so:
```
e script-message-to encode set_timestamp $container $only_active_tracks $preserve_filters $codec $output_directory $output_format
alt+e script-message-to encode clear_timestamp
```

The first command takes six arguments:  
`$container` [string]: the output container, so webm/mkv/mp4/...  
`$only_active_tracks` [true/false]: if true, only encode the currently active tracks. For example, mute the player / hide the subtitles if you don't want audio / subs to be part of the extract.  
`$preserve_filters` [true/false]: whether to preserve some of the filters (crop, rotate, flip and mirror) from the current filter chain into the extract. This is pretty useful combined with crop.lua. Note that you cannot copy video streams and apply filters at the same time.  
`$codec` [string]: additional parameters, anything supported by ffmpeg goes.  
`$output_directory` [string, optional]: the path of the created extract. Empty means the same directory as the input. Relative paths are relative to mpv's working directory, absolute ones work like you would expect.  
`$output_format` [string, optional]: format of the output filename. Does basic interpolation on the following variables: $f, $s, $e, $d, $n which respectively represent input filename, start timestamp, end timestamp, duration and an incrementing number in case of conflicts. Default is `$f_$n`. The extension is automatically appended.  

## Examples

Encode a webm for your favorite imageboard:
```
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10 -b:v 1000k"
```
Slice a video without reencoding (the extract will be snapped to keyframes, watch out):
```
e script-message-to encode set_timestamp mkv false false "-map 0 -c copy"
```

## Static configuration

The following setting can be tweaked in your `lua-settings/encode.conf`:
```
# if yes, the ffmpeg process will be detached and we won't know if it
# succeeded or not and we can stop mpv at any time
# if no, we know the result of calling ffmpeg, but we can only encode
# one extract at a time and mpv will block on exit
detached=[yes/no]
```

# drag-to-pan.lua

Pan the current video or image with the cursor.

The script is intended to be used with a mouse binding, such as `MOUSE_BTN0` but you can use whatever.
Note that `MOUSE_BTN0` clashes with the window dragging feature, you can set `window-dragging=no` to prevent that.

Quick diagonal movement looks shitty because setting the `video-pan-*` property triggers a full pipeline or something. There's not much we can do about this script-side.

# seek-to.lua

Seek to an absolute position in the current video by typing its timestamp.

Toggle with whatever binding you chose. Move the current cursor position with <kbd>←</kbd> and <kbd>→</kbd>,  Change the number currently selected with the number keys (duh). Press <kbd>Enter</kbd> to seek to the entered position.
Holds an internal history for timestamps that have been previously navigated, accessible with <kbd>↑</kbd> and <kbd>↓</kbd>.

# misc.lua

Some commands that are too simple to warrant their own script. See example bindings.

| command | argument(s) | effect |
| --- | --- | --- |
| rotate | [90/-90] | append a "rotate" filter to the filter chain, clockwise or counter-clockwise |
| toggle-filter | [flip/mirror/...] | toggle the specified filter |
| clear-filters |  | clear all filters from the chain and push them on the undo stack |
| remove-last-filter |  | remove the last filter from the chain and push it on the undo stack |
| undo-filter-removal |  | pops the top filter from the undo stack back into the filter chain |
| align | [-1..1] [-1..1] | visually align the video to the window |
| ab-loop | [jump/set/clear] [a/b] | manipulate the timestamps of the ab-loop feature |

# Sample input.conf

```
# crop.lua
c script-message-to crop start-crop

# encode.lua
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10 -b:v 1000k" "./"
E script-message-to encode set_timestamp mkv false false "-c copy" "./"
alt+e script-message-to encode clear_timestamp

# drag-to-pan.lua
# this binding is special because we need to monitor up and down events for this key
MOUSE_BTN0 script-binding drag_to_pan/start-pan

# seek-to.lua
t script-message-to seek_to toggle-seeker

# misc.lua
r     script-message-to misc rotate 90
alt+r script-message-to misc rotate -90
h     script-message-to misc toggle flip
v     script-message-to misc toggle mirror
d     script-message-to misc remove-last-filter
D     script-message-to misc clear-filters
alt+d script-message-to misc undo-filter-removal

shift+ctrl+left  script-message-to misc align 1 ""
shift+ctrl+right script-message-to misc align -1 ""
shift+ctrl+up    script-message-to misc align "" 1
shift+ctrl+down  script-message-to misc align "" -1

k     script-message-to misc ab-loop jump a
l     script-message-to misc ab-loop jump b
K     script-message-to misc ab-loop set a
L     script-message-to misc ab-loop set b
alt+k script-message-to misc ab-loop clear a
alt+l script-message-to misc ab-loop clear b
```

