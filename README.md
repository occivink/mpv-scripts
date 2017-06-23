# Foreword

These scripts are completely independent. Some of them work together nicely (e.g. `crop.lua` and `encode.lua`) but that's it. Just copy whichever scripts you're interested in to your `scripts/` directory (see [here](https://mpv.io/manual/master/#lua-scripting) for installation instructions).  

See [this video](https://vimeo.com/222879214) for a quick overview of what some of these scripts do.  

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
e script-message-to encode set_timestamp $PROFILE
alt+e script-message-to encode clear_timestamp
```

$PROFILE refers to a `lua-settings/$PROFILE.conf` file. A profile may define the following variables:

```
# the container of the output, so webm/mkv/mp4/...
# empty by default
container=

# if yes, only encode the currently active tracks
# for example, mute the player / hide the subtitles if you don't want audio / subs to be part of the extract
# no by default
only_active_tracks=no

# whether to preserve some of the applied filters (crop, rotate, flip and mirror) into the extract
# this is pretty useful in combination with crop.lua
# note that you cannot copy video streams and apply filters at the same time
# yes by default
preserve_filters=yes

# apply another filter after the ones from the previous option if any 
# empty by default
append_filter=

# additional parameters passed to ffmpeg
# empty by default
codec=

# format of the output filename
# Does basic interpolation on the following variables: $f, $s, $e, $d, $p, $n which respectively represent 
# input filename, start timestamp, end timestamp, duration, profile name and an incrementing number in case of conflicts
# $f_$n by default
output_format=$f_$n

# the directory in which to create the extract
# empty means the same directory as the input file
# relative paths are relative to mpv's working directory, absolute ones work like you would expect
# empty by default
output_directory=

# if yes, the ffmpeg process will run detached from mpv and we won't know if it succeeded or not
# if no, we know the result of calling ffmpeg, but we can only encode one extract at a time and mpv will block on exit
# yes by default
detached=yes

# if yes, print the ffmpeg call before executing it
# yes by default
print=yes
```

## Examples

Profile for making webms your favorite imageboard: `~/.config/mpv/lua-settings/encode_webm.conf`:
```
container=webm
only_active_tracks=no
preserve_filters=yes
# downscale if the extract has more pixels than 960x540
append_filter=scale=2*trunc(iw/max(1\,sqrt((iw*ih)/(960*540)))/2):-2
# if somebody knows a better way to coerce the vp8 encoder into producing non-garbage I'd like to know
codec=-an -sn -c:v libvpx -crf 10 -b:v 1000k
output_directory=~/webms/
```
Profile for slicing a video without reencoding it `~/.config/mpv/lua-settings/encode_slice.conf`:
```
container=mkv
only_active_tracks=no
preserve_filters=no
codec=-c copy
```
Relevant `~/.config/mpv/input.conf`:
```
e script-message-to encode set_timestamp encode_webm
E script-message-to encode set_timestamp encode_slice
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
e script-message-to encode set_timestamp encode_webm
E script-message-to encode set_timestamp encode_slice
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

