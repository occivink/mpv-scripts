# Bindings

None of these scripts come with a default binding. Instead, you're encouraged to set your own in `input.conf`. As an example, this is the relevant part of mine:
```
#crop.lua
c script-message-to crop start-crop
#encode.lua
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10 -b:v 1000k"
E script-message-to encode set_timestamp mkv false false "-map 0 -c copy"
alt+e script-message-to encode clear_timestamp
#drag-to-pan.lua
MOUSE_BTN0 script-binding drag_to_pan/start-pan
#seek-to.lua
t script-message-to seek_to toggle-seeker
#filters.lua
r script-binding filter/rotate 90
alt+r script-message-to filters rotate -90
h script-message-to filters toggle flip
v script-message-to filters toggle mirror
D script-message-to filters clear-filters
d script-message-to filters remove-last-filter
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
`$container` (string): the output container, so webm/mkv/mp4/...  
`$only_active_tracks` (true/false): if true, only encode the currently active tracks. For example, mute the player / hide the subtitles if you don't want audio/subs to be part of the extract.  
`$preserve_filters` (true/false): whether to preserve some of the currently applied filters (crop, rotate, flip and mirror) into the extract. This is pretty useful combined with crop.lua. Note that you can not copy streams with the filters.  
`$codec` (string): additional parameters, anything supported by ffmpeg goes  

## Examples:

Encode a webm for your favorite imageboard:
```
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10 -b:v 1000k"
```
Slice a video without reencoding:
```
e script-message-to encode set_timestamp mkv false false "-map 0 -c copy"
```

# drag-to-pan.lua

Pan the current video or image with the cursor.

The script is intended to be used with a mouse binding, such as `MOUSE_BTN0` but you can use whatever.
Note that `MOUSE_BTN0` clashes with the window dragging feature, you can set `window-dragging=no` to prevent that.

Quick diagonal movement looks shitty because setting the `video-pan-*` property triggers a full pipeline or something, to be determined.

# seek-to.lua

Seek to an absolute position in the current video by typing its timestamp.

Toggle with whatever binding you chose. Move the current cursor position with `<-`, `->`. Change the number currently selected with the number keys (duh). Press `enter` to seek to the entered position.

# filters.lua

Some not-very-useful helper commands for handling filters and what not.
