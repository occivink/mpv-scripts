# Foreword

These scripts are completely independent. Some of them work together nicely (e.g. `scripts/crop.lua` and `scripts/encode.lua`) but that's it. Just copy whichever scripts you're interested in to your `scripts/` directory (see [here](https://mpv.io/manual/master/#lua-scripting) for installation instructions).  

[![demo](https://i.vimeocdn.com/filter/overlay?src0=https%3A%2F%2Fi.vimeocdn.com%2Fvideo%2F641523401_1280x720.jpg&src1=https%3A%2F%2Ff.vimeocdn.com%2Fimages_v6%2Fshare%2Fplay_icon_overlay.png)](https://vimeo.com/222879214)

## Bindings

None of these scripts come with default bindings. Instead, you should set your own in `input.conf`, see the example in this repo.

# crop.lua

Crop the current video in a visual manner. 

UX largely inspired by [this script](https://github.com/aidanholm/mpv-easycrop), code is original. The main difference is that this script supports recursively cropping and is aware of some properties like pan or zoom, there are other subtleties.

Press the binding to enter crop mode. Click once to define the first corner of the cropped zone, click a second time to define the second corner.  

Note that [hardware decoding is in general not compatible with filters](https://mpv.io/manual/master/#options-hwdec), and will therefore not work with this script.

# encode.lua

**You need ffmpeg in your PATH (or in the same folder as mpv) for this script to work.**

Make an extract of the video currently playing using `ffmpeg`. 

Press the configured binding to set the beginning of the extract. Then, press ENTER to set the end and start encoding.

By default, the script creates a webm compatible with certain imageboards. You can create different profiles depending on the type of encode you want to create. In particular, you can change the codecs used, which tracks are active and the filters to apply. 

See `script-opts/encode_webm.conf` for the default options and a description of them. `script-opts/encode_slice.conf` contains another example profile. 

# seek-to.lua

Seek to an absolute position in the current video by typing its timestamp.

Toggle with whatever binding you chose. Move the current cursor position with <kbd>←</kbd> and <kbd>→</kbd>,  Change the number currently selected with the number keys (duh). Press <kbd>Enter</kbd> to seek to the entered position.
Holds an internal history for timestamps that have been previously navigated, accessible with <kbd>↑</kbd> and <kbd>↓</kbd>.

# blacklist-extensions.lua

Automatically remove playlist entries by extension according to a black/whitelist. Useful when opening directories with mpv.

The script doesn't do anything by default, you need to copy `script-opts/blacklist_extensions.conf` and modify it to your liking.

# blur-edges.lua

Fills the black bars on the side of a video with a blurred copy of its edges.

The script defines a `toggle-blur` command that you can bind.  
It can be configured via `script-opts/blur_edges.conf`.

# misc.lua

Some commands that are too simple to warrant their own script. Have a look at the source in case you're curious.  
