# Foreword

These scripts are completely independent. Some of them work together nicely (e.g. `crop.lua` and `encode.lua`) but that's it. Just copy whichever scripts you're interested in to your `scripts/` directory (see [here](https://mpv.io/manual/master/#lua-scripting) for installation instructions).  

## Bindings

None of these scripts come with default bindings. Instead, you're encouraged to set your own in `input.conf`. As an example, this is the relevant part of mine:
```
#crop.lua
c script-message-to crop start-crop
#encode.lua
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10 -b:v 1000k"
E script-message-to encode set_timestamp mkv false false "-map 0 -c copy"
alt+e script-message-to encode clear_timestamp
#drag-to-pan.lua
#this binding is special because we need to monitor up and down events for this key
MOUSE_BTN0 script-binding drag_to_pan/start-pan
#seek-to.lua
t script-message-to seek_to toggle-seeker
#filters.lua
r script-message-to filters rotate 90
alt+r script-message-to filters rotate -90
h script-message-to filters toggle flip
v script-message-to filters toggle mirror
d script-message-to filters remove-last-filter
D script-message-to filters clear-filters
alt+d script-message-to filters undo-filter-removal
```

# crop.lua

Crop the current video in a visual manner. UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping and is aware of some properties like pan or zoom, there are other subtleties.

Press the binding to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.  
You can use a binding such as `d vf del -1` to undo the last crop.

# encode.lua

Make an extract of the currently playing video using `ffmpeg`. Press the binding once to set the beginning of the extract. Press a second time to set the end and start encoding.  
This script defines two commands that you can bind in your `input.conf` like so:
```
e script-message-to encode set_timestamp $container $only_active_tracks $preserve_filters $codec
alt+e script-message-to encode clear_timestamp
```

The first command takes four arguments:  
`$container` [string]: the output container, so webm/mkv/mp4/...  
`$only_active_tracks` [true/false]: if true, only encode the currently active tracks. For example, mute the player / hide the subtitles if you don't want audio / subs to be part of the extract.  
`$preserve_filters` [true/false]: whether to preserve some of the filters (crop, rotate, flip and mirror) from the current filter chain into the extract. This is pretty useful combined with crop.lua. Note that you cannot copy video streams and apply filters at the same time.  
`$codec` [string]: additional parameters, anything supported by ffmpeg goes.  

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

The following two settings can be tweaked in your `lua-settings/encode.conf`:
```
# run ffmpeg detached from mpv
detached=[yes/no]
# use the current working directory for the output
use_current_working_dir=[yes/no]
```
Both parameters are explained more in details in `encode.lua`.

# drag-to-pan.lua

Pan the current video or image with the cursor.

The script is intended to be used with a mouse binding, such as `MOUSE_BTN0` but you can use whatever.
Note that `MOUSE_BTN0` clashes with the window dragging feature, you can set `window-dragging=no` to prevent that.

Quick diagonal movement looks shitty because setting the `video-pan-*` property triggers a full pipeline or something. There's not much we can do about this script-side.

# seek-to.lua

Seek to an absolute position in the current video by typing its timestamp.

Toggle with whatever binding you chose. Move the current cursor position with <kbd>←</kbd> and <kbd>→</kbd>,  Change the number currently selected with the number keys (duh). Press <kbd>Enter</kbd> to seek to the entered position.
Holds an internal history for timestamps that have been previously navigated, accessible with <kbd>↑</kbd> and <kbd>↓</kbd>.

# filters.lua

Some not-very-useful helper commands for handling filters with undo capability.
