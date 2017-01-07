# crop.lua

Crop the current video in a visual manner. UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping and handles additional properties (pan, zoom), there are other subtleties.

Press `c` to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.
You can use a binding such as `d vf del -1` to undo the last crop.

# encode.lua

Make an extract of the currently playing video using `ffmpeg`. Press the binding once to set the beginning of the extract. Press a second time to set the end and start encoding.
This script defines two commands that you can bind like so:
```
e script-message-to encode set_timestamp $container $only_active_tracks $preserve_filters $codec
alt+e script-message-to encode clear_timestamp
```

The first command takes four arguments:
`$container` (string): the output container, so webm/mkv/mp4/...
`$only_active_tracks` (true/false): if true, only encode the currently active tracks. For example, mute the player / hide the subtitles if you don't want audio/subs to be part of the extract.
`$preserve_filters` (true/false): whether to preserve some of the currently applied filters (crop, rotate, flip and mirror) into the extract. This is pretty useful combined with crop.lua.
`$codec` (string): additional parameters, anything supported by ffmpeg goes

Some `input.conf` examples:
Encode a webm for your favorite imageboard:
```
e script-message-to encode set_timestamp webm false true "-an -sn -c:v libvpx -crf 10"
```
Slice a video without reencoding:
```
e script-message-to encode set_timestamp mkv false false "-map 0 -c copy"
```

# drag-to-pan.lua

Pans the current video or image along with cursor movement as long as a button is pressed.

You can change the binding from `MOUSE_BTN0` to whatever you want, it doesn't even have to be a mouse button.
The default binding clashes with the window dragging feature, you can either set `window-dragging=no` in your config or change the binding.

Quick diagonal movement looks shitty because setting the `video-pan-*` property triggers a full pipeline or something, to be determined.

# seek-to.lua

Seek to an absolute position in the current video.

Toggle with `ctrl+t`. Move the current cursor position with `left`, `right`. Change the number currently selected with the number keys (duh). Press `enter` to seek to the entered position.

I may add history in the future.

# filters.lua

Some not-very-useful helper commands for handling filters and what not.
